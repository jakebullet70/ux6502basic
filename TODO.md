# TODO

Planned work for ux6502basic. Items are done in order unless noted. Each `src/` change is logged
in `docs/changes.md` and gets a test in `tests/`.

## 1. New functions and literals

HEX$, BIN$, RPT$, MOD, π, and `$` and `%` literals (hex and binary). Then the `XOR`, `SHL` and
`SHR` operators (bitwise, on integers like `AND` and `OR`). Then `DEEK(addr)` and
`DOKE addr,value` (16-bit PEEK and POKE), and `LCASE$` and `UCASE$`. Then `TEXTAT` from
XC-BASIC: `TEXTAT x, y, text or code[, color]` prints at column x, row y without moving the
cursor (a code replaces XC-BASIC's `CHARAT`). Done for the sim with ANSI codes; the new kernal
port must replace the ANSI part with its screen calls.

Then `CONTINUE` in `FOR`/`NEXT` and `DO`/`LOOP` loops: it skips the rest of the body and goes on
with the next pass, through the matching `NEXT` or `LOOP` (the counterpart of `EXIT DO`, in
`block.s`). Done.

Then `'` as a short form of `REM`: `' text` and `PRINT X: ' text` make the rest of the line a
comment.

Then functions that read the cursor position: the column and the line (row). `POS(0)` already
gives the column, but first the sim must reset `POSX` after a new line (it stays at 13, so
`POS(0)` and `TAB(` are wrong). For the line, a new function such as QBasic's `CSRLIN` (no
argument, parsed like `PI`); a cheaper option is one keyword for both, for example `CSR(0)` for
the column and `CSR(1)` for the line, which makes `POS` removable. BASIC does not track the
line, so it comes from the target: the new kernal's screen call, and in the sim an ANSI cursor
report (`ESC[6n`) or a count of the lines printed. `TEXTAT` is the matching way to set the
position.

Deferred: `MEMCPY` and `MEMSET` (block copy and fill). Argument order and overlapping copies are
still to be decided.

## 2. Labels, SUB and FUNCTION

QBasic-style syntax, matching the block `IF` and `DO` already in place. Three phases:

- **A. Labels.** `GOTO name` / `GOSUB name` with `name:` label lines. Reuses the GOTO cache.
  Small change, most of the readability gain.
- **B. SUB.** `SUB name(a,b$)` ... `END SUB`, `CALL name(args)`, `LOCAL v,...`. The first call
  scans for the SUB and caches its address; normal flow skips SUB bodies. Parameters and LOCAL
  use save/restore (old values pushed on entry, restored on exit, like `DEF FN` does for its one
  parameter), so variables never move and the variable cache stays valid. GARBAG must also scan
  the saved string descriptors. Frames and saved values go on a RAM stack, not the 256-byte
  6502 stack.
- **C. FUNCTION.** `FUNCTION name(x)` ... `END FUNCTION` called from expressions. Needs a
  re-entrant statement loop (run until END FUNCTION, then return into FRMEVL) and must keep FAC,
  ARG and the temporary string descriptors intact. Highest risk, so last.

## 3. Real integer math (last)

`%` variables are stored as 16-bit integers but every operation converts them to float and
back. Doing integer arithmetic directly would speed up `A%=A%+1` and similar code. It is a big
change to the expression evaluator for a modest gain, so it comes after the items above.

## 4. Inline assembly with variable passing

Put 6502 code inside a BASIC program and pass BASIC variables in and out, instead of POKEing
bytes and calling SYS. The design is still open: the syntax, where the code is stored or
assembled, and how variables reach the code (registers, a parameter block, or variable
addresses).

## 5. User reference of working commands

There is no user-facing list of what works yet: `CLAUDE.md` names the features briefly for
development, and `docs/changes.md` explains how each change was made. Write a reference
(for example `docs/reference.md`) that lists every statement, function and operator the sim
build supports, with syntax, a short example and its errors, and marks what is new compared
with Microsoft BASIC. Keep it updated with each new feature.

## Parked (long term)

Not scheduled. They need the new kernal's file calls first.

- `CHAIN "name"`: load another program and run it, as a way to split programs that do not fit
  in memory.
- `DIR`: list the files on the disk.
