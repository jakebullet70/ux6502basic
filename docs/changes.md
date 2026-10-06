# Changes to the msbasic sources

This is a log of what we changed in `src/` compared with mist64/msbasic (commit 2a0bc2f), and why.
Add an entry with each fix. Changes to shared files are wrapped in `.ifdef SIM` (or a later
target symbol), so the original targets still build byte for byte (`make verify`).

## sim target (headless sim65 build)

New files: `defines_sim.s`, `sim_extra.s`, `sim_iscntc.s`, `sim.cfg`. The hooks in shared files
are listed below.

- `defines.s`, `extra.s`, `iscntc.s`: include the sim files when ca65 runs with `-D sim`.
- `header.s`: writes the sim65 file header (signature, version 2, CPU 6502, C stack pointer
  `SIM_CSP`, load address $C000, reset address `COLD_START`).
- `init.s`, RAM scan at `L40D7`: in sim65 all 64K is RAM, so the scan stops at page
  `SIM_RAMTOP` ($C0), just below the interpreter.

## Zero-page overlap in the w65c816sxb layout

`defines_sim.s` started as a copy of `defines_w65c816sxb.s`. That layout puts `Z14` and
`TEMPPT` both at $65, so `FRE` hangs. `defines_sim.s` sets `ZP_START4 = $66`. Upstream
`defines_w65c816sxb.s` is unchanged.

## No MEMORY SIZE? or TERMINAL WIDTH? prompt at cold start

- `init.s` (two places): the prompt blocks were `.ifndef CONFIG_CBM_ALL`. They are now
  `.if (!.def(CONFIG_CBM_ALL)) && (!.def(SIM))`.
- Memory: the cold start scans RAM, as it does when you answer the prompt with Return.
- Width: `defines_sim.s` sets `WIDTH = 80` and `WIDTH2 = 70` (the last comma tab stop, the value
  BASIC derives for width 80). The X16 text screen is at most 80x60.
- Pitfall: in ca65, `!` binds more loosely than `&&`. Without the parentheses,
  `.if !.def(A) && !.def(B)` means `!(.def(A) && !.def(B))`, and the prompts come back.

## Echo only when asked

An interactive Windows console echoes typed input itself, so the sim echoed every line twice.
`MONRDKEY` in `sim_extra.s` now echoes only when sim65 gets an argument after the program file
(`sim65 build/sim.bin echo`). The test runner uses that argument, so stdout is a full session
transcript. The check runs on the first key read: `SIMARGS` calls the sim65 `PVArgs` paravirt
call ($FFF8) with the C stack pointer set to `SIM_ARGS_TOP` ($0400), and stores the result in
`SIMECHO`.

Side effect: a piped run without the argument shows blank lines where the input would be.

## Lowercase keywords and variable names

Typed `list` gave `?SYNTAX ERROR`, because the tokenizer only knows uppercase. `program.s`
(`PARSE_INPUT_LINE`) now calls `SIM_UPPER` (in `sim_extra.s`) in two places:

- after the quote and DATA checks: the character is folded and stored back in the input buffer,
  so variable names are saved in uppercase;
- in the keyword lookahead at `L2498`: the next characters are folded before they are compared
  with the keyword table.

Text in quotes, `REM` and `DATA` keeps its case, because those paths skip both calls.

## I/O layer

The interpreter used to call CBM KERNAL routines by name. It now calls neutral entry points, so a
target without the CBM KERNAL can supply its own. `io.s` (included at the end of `defines.s`)
documents each entry point and the register rules the interpreter relies on, and maps them to the
KERNAL for CBM targets:

| Layer       | CBM KERNAL | Called from                          |
|-------------|------------|--------------------------------------|
| `IO_CHKIN`  | `CHKIN`    | `input.s` (GET#, INPUT#)             |
| `IO_CHKOUT` | `CHKOUT`   | `misc1.s` (CMD, PRINT#)              |
| `IO_CLRCH`  | `CLRCH`    | `input.s`, `program.s` (ERROR)       |
| `IO_CHRIN`  | `CHRIN`    | `inline.s` (GETLN)                   |
| `IO_CLALL`  | `CLALL`    | `program.s` (RUN, NEW, CLEAR)        |

`MONCOUT`, `MONRDKEY` and `ISCNTC` stay as they are; every target already provides them.

Rules that are not obvious from the KERNAL documentation: `IO_CHKIN` and `IO_CHKOUT` must keep X
(the caller stores it in `CURDVC`), `IO_CHRIN` must keep X (INLIN's buffer index), and `IO_CLRCH`
must keep X (ERROR holds the error number in X).

Other shared-file changes:

- `init.s` (clear `CURDVC`) and `program.s` (`IO_CLALL`): the condition was `CONFIG_CBM_ALL`; it
  is now `CONFIG_FILE`, which is what the code depends on. For the original targets this is the
  same set (only the CBM targets have `CONFIG_FILE`).
- `program.s`: new label `ERROR_PRINTED` after the error message loop, so `handle_io.s` can print
  its own messages and then finish like ERROR.

The labels are aliases of the same addresses, so the CBM builds are unchanged (`make verify`).

## Files in the sim target (handle-based I/O)

`defines_sim.s` now sets `CONFIG_FILE` and `CONFIG_HANDLE_IO`. The sim build has PRINT#, INPUT#,
GET#, CMD, OPEN, CLOSE, SYS and the status variable ST. This is a test bed for the X16 target: the
new X16 kernal also uses Unix-style handles (0 stdin, 1 stdout).

- `handle_io.s` (new, shared by handle-based targets): implements the I/O layer and the OPEN,
  CLOSE and SYS statements on top of four target primitives, `K_OPEN`, `K_CLOSE`, `K_READ` and
  `K_WRITE` (contract at the top of the file). It keeps a table of up to 10 open files (logical
  file number, handle, mode). Its variables are in segment `IORAM`, which the target's `.cfg`
  places in RAM.
- Syntax: `OPEN lf,"name"[,mode]`, with lf 1-255 and mode 0 read (default), 1 write (create or
  truncate), 2 append. There is no device number; on the X16 the kernal picks the driver from the
  name. `CLOSE lf` on a file that is not open is ignored, as on CBM. When the closed file is the
  current input or output (for example after CMD), the console takes over again.
- End of file: files opened for reading are read one byte ahead, so ST gets bit 6 ($40) with the
  last byte, as on CBM machines. Reading past the end returns CR: first with ST = 64 (this ends a
  last line that has no line end), then with ST = 66. Bit 1 makes INPUT# stop (existing code in
  `input.s`).
- Errors: the main error table has only 6 bytes left (offsets are 8 bits), so `handle_io.s` has
  its own table (FILE OPEN, FILE NOT OPEN, FILE NOT FOUND, NOT INPUT FILE, NOT OUTPUT FILE, TOO
  MANY FILES) and prints it the way ERROR does.
- `sim_extra.s`: the console routines became the four primitives, using the sim65 calls PVOpen,
  PVClose, PVRead and PVWrite. Handles are host file descriptors. Every handle converts line ends
  (BASIC CR, host LF). Echo and exit on end of stdin are unchanged and apply only to the console.
- `eval.s`: under `CONFIG_HANDLE_IO`, reading the variable ST gives `Z96` (the status byte). The
  CBM code for TI and ST depends on the KERNAL clock, so it is not reused. ST can still be
  assigned like a normal variable, but reading it always gives the status.
- `print.s` (`OUTSP`): with `CONFIG_FILE`, BASIC prints CRSR RIGHT ($1D) to the screen, for
  example after the INPUT prompt. Handle-based targets print a space.
- `defines_sim.s`: `CURDVC` = $F2, `Z96` = $F3, console handles `K_STDIN` = 0 and
  `K_STDOUT` = 1. `sim.cfg`: segment `IORAM` at the end of the BASIC image (all RAM in sim65).

Known limits:

- INPUT# goes through the console line editor: lines are cut at 80 characters (see below), BS
  and DEL delete, and control characters are dropped.
- GET# converts line ends like text, so binary files cannot be read byte for byte.

## 80-character input line

Typed lines were cut at 71 characters (`cpx #$47` in `inline.s`), the old Microsoft teletype limit,
and the buffer was in zero page. The X16 screen is 80 characters wide.

- `defines_sim.s`: `INPUTBUFFER = $0200`, as on CBM machines. Upstream already supports this
  layout (`CONFIG_NO_INPUTBUFFER_ZP`, `CONFIG_INPUTBUFFER_0200`): the direct-mode test compares the
  high byte of `TXTPTR` with $02, and the bytes at $01FD-$01FF in front of the buffer are used, so
  `STACK_TOP` is $FA as in CBM BASIC 2. `LINE_MAX = 80` is the longest typed line.
- `inline.s`: the sim has its own `INLIN`. It takes up to `LINE_MAX` characters and rings BEL when
  the line is full. BS ($08) and DEL ($7F) delete the last character; `@` and `_` are ordinary
  characters now. Other control characters are dropped. The upstream editing code depends on a
  zero-page buffer, so it cannot be reused.
- `print.s` (`L29B9`): the end of the line is handled as in CBM2 (`.if .def(CBM2) || .def(SIM)`),
  which returns the buffer pointer for a buffer outside zero page.
- Test: `tests/linein.bas` (80-character program line, INPUT and direct lines cut at 80, BS, STOP
  and CONT, strings in direct mode).

## Block IF / ELSE / END IF

msbasic has only the one-line IF. `CONFIG_BLOCK` (set in `defines_sim.s`) adds a block form:

```
IF c THEN
  ...
ELSE
  ...
END IF
```

- `IF c THEN` with nothing after THEN on the line starts a block. A false condition skips to the
  matching ELSE or END IF; ELSE, reached after the true part, skips to the matching END IF.
  Statements after ELSE on its line run, so `ELSE IF c THEN` chains blocks (each needs its own
  END IF) and `ELSE 100` jumps like `THEN 100`. Blocks push nothing on the stack, so GOTO in or
  out of a block is harmless.
- New file `block.s`: the ELSE statement and the forward scan. The scan reads the tokenized text:
  a line whose last token (spaces skipped) is THEN opens a block, END followed by IF closes one,
  text in quotes and after REM is skipped. It keeps `CURLIN` up to date line by line. If the
  program ends first: `?MISSING END IF ERROR`, in the extra error table of `handle_io.s` (so
  `CONFIG_BLOCK` needs `CONFIG_HANDLE_IO`). Zero page: `BLK_DEPTH`, `BLK_LAST`, `BLK_MODE` at
  $F4-$F6.
- `token.s`: new statement token ELSE after NEW (our own token values; programs are text, so
  token numbers need not match other BASICs). `TOKEN_END` and `TOKEN_IF` are now named.
- `flow2.s` (`IF`): after THEN, end of line means a block; a false block calls `BLK_FALSE`.
- `flow1.s` (`END`): END followed by IF is END IF and does nothing. A `jsr CHRGOT` restores the Z
  flag that the rest of END tests (end of statement), which the compare destroys. The label
  `EXEC_CHRGET` marks the `jmp CHRGET` that END IF branches to.
- No new token for END IF: the tokenizer already makes END + IF; `ENDIF` works too.
- Pitfall: keywords are found inside names, so a variable such as `ELSEX` no longer works.
- Size: 159 bytes in the sim build.
- Test: `tests/block.bas`.

## DO / LOOP / EXIT

`CONFIG_BLOCK` also adds a loop without a counter or condition; `IF c THEN EXIT` ends it:

```
DO
  ...
  IF c THEN EXIT
  ...
LOOP
```

- `DO` pushes a 5-byte frame like GOSUB (token, line number, text pointer) and checks the stack
  with `CHKMEM`. `LOOP` finds the frame with `GTFORPNT` (FOR frames above it are dropped, as
  RETURN does), pops it and falls into DO, which pushes it again, so LOOP and DO share code.
- `EXIT [DO]` (the DO is ignored) drops the frame and runs the block scan in a third mode
  (`BLK_MODE` = `TOKEN_LOOP`): DO opens a level unless it follows EXIT, LOOP closes one. The
  statements after the matching LOOP run. IF/THEN and END IF are not counted in this mode, so a
  block IF inside the loop does not disturb it.
- LOOP without a DO frame, or EXIT that finds no LOOP before the end of the program, gives
  `?MISSING DO/LOOP ERROR` (one message for both, to save bytes; for EXIT the line number is the
  last line scanned).
- No count (`DO n`): FOR does counted loops.
- Limits: RETURN inside a DO loop gives RETURN WITHOUT GOSUB; GOTO out of a DO loop leaves its
  frame on the stack (not allowed by rule, not checked); in `EXIT:DO` the DO is taken as part of
  `EXIT DO` by the scan. Keywords are found inside names, so names such as `DONE` no longer work.
- `token.s`: statement tokens DO, LOOP and EXIT after ELSE. The EXIT handler is `BLK_EXIT`,
  because `eval.s` already has a label `EXIT`.
- Size: about 145 bytes in the sim build.
- Test: `tests/do.bas`.

## Keyword table longer than 256 bytes, no LET

With DO, LOOP and EXIT the keyword table grew to 266 bytes. The tokenizer and LIST index it with
Y, so it can hold only 256, and every typed line hung.

- `CONFIG_KW16` (`program.s`): the tokenizer and LIST keep a pointer `KW_PTR` ($F7-$F8) to the
  current keyword and index into it with Y. `KW_INIT` points it at the first keyword, `KW_NEXT`
  skips to the next one. The table can now have any length (tokens still end at $FF). About 21
  bytes.
- `CONFIG_NO_LET` (`token.s`): the LET keyword is gone. Assignment without LET (`A=1`) works as
  before; `LET A=1` is now a syntax error. Saves 5 bytes and one token.

## Only the CBM and sim targets

The upstream targets for other machines (OSI, Apple, KIM-1, KIM BASIC, Microtan, AIM-65, SYM-1,
W65C816SXB) are not ours to support and only slowed every build and check.

- Removed their `defines_*.s`, `*_extra.s`, `*_iscntc.s`, `*_loadsave.s` and `.cfg` files, and
  their branches in `defines.s`, `extra.s`, `iscntc.s` and `program.s`. `loadsave.s` held only
  their includes and is gone too.
- Kept: `cbmbasic1` and `cbmbasic2` (byte-compared with the ROM dumps by `make verify`; BASIC 2
  also runs in xpet), and `sim`.
- The `.ifdef APPLE`, `.ifdef KIM` and similar code inside the shared sources stays. It assembles
  to nothing, and stripping it by hand risks breaking the verified builds.
- Size: no change. The sim build is still 9779 bytes; only the source tree is smaller.

## Faster number reading (FIN)

`tests/bench.py` showed that numeric literals were the most expensive part of a statement:
`A=12345` took about 5900 cycles against 1100 for `A=B`. FIN did a float multiply by 10 and a
float add for every digit, each time the line ran. VAL, INPUT and READ use the same routine.

- `CONFIG_FAST_FIN` (`float.s`, sim only): while FAC (the exponent byte) is 0, the digits go into
  FAC+1..FAC_LAST as an unsigned integer, multiplied by 10 with shifts and one add. `FIN_FLOAT`
  normalizes it into a float once, before the exponent is applied, or earlier if the next digit
  could overflow the integer (high byte $19 or more). From then on the old float code runs.
- Results are bit for bit the same as before: the integer is exact, and the float path also gives
  exact values for integers that fit the mantissa. Checked on 331 literals and their VAL forms.
- Cycles per statement: `A=1` 1525 to 1376, `A=12345` 5883 to 2220, `POKE 1000,1` 6019 to 3696.
- Size: about 120 bytes.
- Test: `tests/numbers.bas`.

## INSTR function

`INSTR([start,] a$, b$)` returns the 1-based position of `b$` in `a$`, searching from `start`
(default 1), or 0 when it is not found.

- `CONFIG_INSTR` (sim only). Code in `instr.s`, included from `extra.s`. The token goes after
  MID$ in `token.s` with no vector entry; `eval.s` catches it before the `UNARY` dispatch, because
  the optional first argument does not fit the `LEFT$`/`RIGHT$`/`MID$` calling form.
- `start` of 0, below 0 or above 255 gives ILLEGAL QUANTITY. A `start` past the end gives 0.
- An empty `b$` returns `start` when `start` <= LEN(a$)+1, else 0 (as in QuickBASIC).
- Both strings are released as temporaries (`b$` first, since it is the newer one), so FRE does
  not drop. The search reads the text after the release; nothing allocates in between.
- Size: 167 bytes.
- Test: `tests/instr.bas`.

## GOTO target cache

GOTO and GOSUB used to search the line list for the target on every jump. Now the result is
remembered, so a repeated jump costs the same however far away the target line is.

- `CONFIG_GOTO_CACHE` (sim only). Code in `gotocache.s`, included from `extra.s`. `GOTO` in
  `flow2.s` jumps to `GOTO_CACHED`; the old code stays as `GOTO_SLOW`. GOSUB, `IF ... THEN
  <line>`, `IF ... GOTO`, ON GOTO/GOSUB and `RUN <line>` all go through `GOTO`, so they all use
  the cache.
- Key: TXTPTR at entry, which points at the first digit of the line number. In a stored program
  that address always leads to the same target. Value: the TXTPTR that `GOTO_SLOW` leaves.
- Direct-mapped, 64 entries; the entry is the key's low byte AND 63. Four 64-byte tables
  (256 bytes) in the `IORAM` segment. An entry whose key high byte is 0 is empty.
- Direct-mode lines are not cached, because the input buffer is reused.
- `CLEARC` (in `program.s`) empties the cache. It runs on NEW, RUN, CLR and after every program
  line is typed, so the cache never points at old text. A future LOAD must also reach `CLEARC`
  (the CBM LOAD does, through `SETPTRS`). A POKE into the program text is not noticed.
- On a miss, `CHRGOT` is called again before `GOTO_SLOW`, because `LINGET` needs the carry flag
  of the first digit and the cache lookup clobbers it.
- Speed (`tests/bench.py`): GOSUB to the next line 1382 to 732 cycles, GOSUB 100 lines on 6900 to
  751 cycles.
- Size: 91 bytes of code plus the 256-byte tables.
- Test: `tests/gotocache.bas` (changed and deleted target lines, inserted lines, ON GOTO/GOSUB,
  IF GOTO, RUN <line>, direct mode, and two GOTOs that share a cache entry).

## Simple variable cache

PTRGET used to search the simple variable table from the start on every use, so a variable made
late cost more than one made early. Now the address of each variable's entry is remembered.

- `CONFIG_VAR_CACHE` (sim only). Code in `varcache.s`, included from `extra.s`. In `var.s`,
  PTRGET calls `VC_FIND` before the search and jumps straight to `SET_VARPNT_AND_YA` on a hit.
  On a miss the old search runs; when it finds the variable (`VC_FOUND`) or makes a new one,
  `VC_STORE` remembers it.
- Key: the two name bytes in VARNAM. Value: the address of the 7-byte entry (LOWTR). A simple
  variable never moves once made: a new one is added at the end of the simple variables and only
  the arrays move up. VARTAB only changes through `SETPTRS`, which runs `CLEARC`, and `CLEARC`
  empties the cache (NEW, RUN, CLR, every program line entry).
- Arrays are not cached; they move whenever a simple variable is made.
- When an undefined variable is read in an expression, BASIC returns zero without making the
  variable. Nothing is cached then.
- Direct-mapped, 64 entries. The index is `(VARNAM+1)*2 + VARNAM`, with bit 5 flipped for
  strings and integers and bit 4 also flipped for integers, AND 63. Single-letter floats get
  entries 1 to 26 and strings and integers mostly land elsewhere. Four 64-byte tables plus
  `VC_IDX` (257 bytes) in the `IORAM` segment. An entry whose first name byte is 0 is empty.
- Speed (`tests/bench.py`): `Z=Z+1` with Z last of 25 variables 4200 to 2744 cycles, `A$=B$`
  1763 to 1363. The first one or two variables in the table get about 25 cycles slower per use,
  because the hash costs about as much as one step of the old search.
- Size: 101 bytes of code plus the 257-byte tables.
- Test: `tests/varcache.bas` (names that share an entry, strings and integers, a new variable made
  after DIM, DEF FN, CLEAR, program edits, NEW).

## HEX$ and BIN$

- `CONFIG_HEXBIN` (sim only). Code in `hexbin.s`, included from `extra.s`. `HEX$(n)` and
  `BIN$(n)` return n in hex or binary, for -65535 <= n <= 65535 (anything else is ILLEGAL
  QUANTITY). A negative n is taken mod 65536, as two's complement, so `HEX$(-1)` is "FFFF" and
  `HEX$(-32768)` is "8000"; this suits `%` variables, which are signed 16-bit. The routine uses
  `QINT` directly instead of `GETADR`, which rejects negative values. A result below 256 gives 2
  hex or 8 binary digits, otherwise 4 or 16, with leading zeros.
- The keywords sit in the function table after `CHR$` and before `LEFT$`, so UNARY parses their
  one argument; this moves the tokens of LEFT$, RIGHT$, MID$, INSTR and GO up by 2. Like `CHR$`,
  the routine drops UNARY's return so its numeric type check is skipped, and it builds the
  string in place with `STRSPA` and `PUTNEW`. The value and digit sizes are kept on the stack
  across `STRSPA`, which can collect garbage.
- Size: 106 bytes.
- Test: `tests/hexbin.bas`.

## RPT$

- `CONFIG_RPT` (sim only). Code in `rpt.s`, included from `extra.s`. `RPT$(a$, n)` returns a$
  repeated n times; `RPT$(c, n)` returns `CHR$(c)` repeated n times. n is 0 to 255, c is 0 to 255
  (else ILLEGAL QUANTITY), and a result longer than 255 characters gives STRING TOO LONG.
- The first argument may be a string or a number, which UNARY cannot parse, so the keyword sits
  after `INSTR` with no table address and `FRM_ELEMENT` sends its token to `RPTSTR` directly, as
  it does for INSTR. This moves the GO token up by 1. A numeric first argument is first turned
  into a one-character temporary string, so both forms share the copy loop. The descriptor
  address and n are kept across `STRSPA` (which can collect garbage), then `FRETMP` reads the
  source text and `MOVSTR1` copies it n times.
- Size: 101 bytes, plus 7 in `FRM_ELEMENT` and the 4-byte keyword.
- Test: `tests/rpt.bas` (both forms, empty results, the 255 limit, errors, and a loop that forces
  garbage collection).

## MOD

- `CONFIG_MOD` (sim only). Code in `mod.s`, included from `extra.s`. `a MOD b` works as in
  QBasic: both operands are rounded to the nearest integer (halves away from zero, so
  `2.5 MOD 2` is 1), the result has the sign of `a` (`-7 MOD 3` is -1), and it has the same
  precedence as `*` and `/`. An operand of 2^31 or more in size gives OVERFLOW, and a right
  operand that rounds to 0 gives DIVISION BY ZERO.
- The keyword sits after `OR`, inside the binary operator range `TOKEN_PLUS`..`TOKEN_GREATER`,
  with a `MATHTBL` entry after `OR` (precedence $7B). This moves the tokens of `>`, `=`, `<` and
  every function up by 1. The hard-coded `MATHTBL` offsets became symbols so they follow the
  table: `adc #$07` in `FRMEVL` is `TOKEN_GREATER-TOKEN_PLUS`, the `ldy #$15/$18/$1B` loads in
  `eval.s` are `MT_NEGOP`, `MT_EQUOP` and `MT_RELOPS` (defined in `token.s`), and
  `MATHTBL+28+1` in the tokenizer is `MATHTBL+MT_RELOPS+2`. The CBM builds are unchanged.
- The remainder comes from a 32-bit shift-and-subtract division on the integer magnitudes
  (`QINT` after adding 0.5), so it is exact for every allowed operand, unlike `a-b*INT(a/b)`
  in floating point.
- Size: 154 bytes, plus the 3-byte table entry and the 3-byte keyword.
- Test: `tests/mod.bas` (signs, rounding, precedence, the 2^31 limit, errors).
