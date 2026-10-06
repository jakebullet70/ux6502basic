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
