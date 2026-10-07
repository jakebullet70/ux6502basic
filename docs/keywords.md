# Keywords and their cost in bytes

All keywords of the `sim` build, done and planned, with the bytes each feature adds to the
image. Measured on 2026-10-06 at commit a84799c; `UCASE$`, `LCASE$`, `TEXTAT`, the shared CHR$ stub, `CONTINUE`, the single `?UNMATCHED BLOCK` error, `?FILE MODE`, the shared `?FILE` prefix, `POS(1)`, labels, the removal of `SPC(` names without keyword crunching (also at the start of a name) and `PAUSE` since.

## How the costs are measured

Each feature has a `CONFIG_` flag in `src/defines_sim.s`. The cost of a feature is the size of
the normal sim image minus the size of a build with only that flag turned off. That covers the
keyword table entry, the dispatch address and the code. Costs are measured one flag at a time,
so features that share code may not add up exactly. Planned costs are estimates.

To measure again: copy `src/` to a scratch folder, comment out one flag in `defines_sim.s`,
build with `ca65 -D sim msbasic.s` and `ld65 -C sim.cfg`, and compare the `.bin` sizes.

## Totals

| Item | Bytes |
|---|---|
| sim image, $C000-$EEBD (without the 12-byte sim65 header) | 11966 |
| of which RAM variables of `handle_io.s` (`IORAM` segment) | 634 |
| ROM space in `sim.cfg` ($C000 + $3F00) | 16128 |
| free | 4162 |
| new keywords (all items in "New keywords" below) | 1775 |
| speed-ups and internals (all items in "Internals" below) | 774 |
| CBM BASIC 2 (`cbmbasic2.bin`), for comparison | 8670 |

CBM BASIC 2 leaves screen, keyboard and file I/O to the KERNAL ROM. The sim image holds its own
I/O layer (`handle_io.s`), so the two sizes do not compare one to one.

Segments of the sim image:

| Segment | Bytes |
|---|---|
| VECTORS (dispatch tables) | 171 |
| KEYWORDS (keyword names) | 329 |
| ERROR (error messages) | 249 |
| CODE | 7863 |
| CHRGET | 29 |
| INIT | 354 |
| EXTRA (sim I/O and most of our additions) | 2337 |
| IORAM | 634 |

## Keyword table

The sim build has 93 tokens, $80-$DC. Inserting a keyword shifts the tokens after it, so saved
tokenized programs are only valid for the build that wrote them.

| Token | Keyword | | Token | Keyword | | Token | Keyword |
|---|---|---|---|---|---|---|---|
| 80 | END | | 9F | OPEN | | BE | FRE |
| 81 | FOR | | A0 | CLOSE | | BF | POS |
| 82 | NEXT | | A1 | GET | | C0 | SQR |
| 83 | DATA | | A2 | NEW | | C1 | RND |
| 84 | INPUT# | | A3 | **ELSE** | | C2 | LOG |
| 85 | INPUT | | A4 | **DO** | | C3 | EXP |
| 86 | DIM | | A5 | **LOOP** | | C4 | COS |
| 87 | READ | | A6 | **EXIT** | | C5 | SIN |
| 88 | GOTO | | A7 | **TEXTAT** | | C6 | TAN |
| 89 | RUN | | A8 | **PAUSE** | | C7 | ATN |
| 8A | IF | | A9 | TAB( | | C8 | PEEK |
| 8B | RESTORE | | AA | TO | | C9 | **DEEK** |
| 8C | GOSUB | | AB | FN | | CA | LEN |
| 8D | RETURN | | AC | THEN | | CB | STR$ |
| 8E | REM | | AD | NOT | | CC | VAL |
| 8F | STOP | | AE | STEP | | CD | ASC |
| 90 | ON | | AF | + | | CE | CHR$ |
| 91 | WAIT | | B0 | - | | CF | **HEX$** |
| 92 | LOAD (stub) | | B1 | * | | D0 | **BIN$** |
| 93 | SAVE (stub) | | B2 | / | | D1 | **UCASE$** |
| 94 | DEF | | B3 | ^ | | D2 | **LCASE$** |
| 95 | POKE | | B4 | AND | | D3 | LEFT$ |
| 96 | **DOKE** | | B5 | OR | | D4 | RIGHT$ |
| 97 | PRINT# | | B6 | **MOD** | | D5 | MID$ |
| 98 | PRINT | | B7 | > | | D6 | **INSTR** |
| 99 | **CONTINUE** | | B8 | = | | D7 | **RPT$** |
| 9A | CONT | | B9 | < | | D8 | **PI** |
| 9B | LIST | | BA | SGN | | D9 | **XOR** |
| 9C | CLEAR | | BB | INT | | DA | **SHL** |
| 9D | CMD | | BC | ABS | | DB | **SHR** |
| 9E | SYS | | BD | USR | | DC | GO |

Bold keywords are new. The others come from Microsoft BASIC (CBM BASIC 2 set). `LOAD` and `SAVE`
are stubs that do nothing in the sim build. Removed from the CBM set: `LET` (`CONFIG_NO_LET`,
saves 5 bytes; `A=1` still works), `SPC(` (`CONFIG_NO_SPC`, saves 13 bytes; `RPT$(32,n)` does
the same) and `VERIFY` (CBM targets only). `END IF` and `EXIT DO` are
built from existing tokens, so they need no table entries.

## New keywords (done)

| Keywords | Flag | Bytes |
|---|---|---|
| `IF c THEN` / `ELSE` / `END IF`, `DO` / `LOOP` / `EXIT [DO]`, `CONTINUE` | `CONFIG_BLOCK` | 306 |
| labels: `name:` lines, `GOTO`/`GOSUB`/`RUN`/`RESTORE name`, names in `ON` lists (no keyword) | `CONFIG_LABELS` | 126 |
| `TEXTAT x,y,a$ or code[,color]` (ANSI codes in the sim) | `CONFIG_TEXTAT` | 179 |
| `INSTR([start,] a$, b$)` | `CONFIG_INSTR` | 167 |
| `a MOD b` | `CONFIG_MOD` | 160 |
| `$FF`, `%1010` literals (no keyword) | `CONFIG_RADIX_LIT` | 147 |
| integer digit reader that the literals need | `CONFIG_FAST_FIN` | 120 |
| `XOR(a,b)`, `SHL(a,n)`, `SHR(a,n)` | `CONFIG_BITFN` | 128 |
| `RPT$(a$ or code, n)` | `CONFIG_RPT` | 97 |
| `HEX$(n)`, `BIN$(n)` | `CONFIG_HEXBIN` | 108 |
| `UCASE$(a$)`, `LCASE$(a$)` | `CONFIG_CASE` | 70 |
| `DEEK(addr)`, `DOKE addr,n` | `CONFIG_DEEK` | 80 |
| `PAUSE [jiffies]` (like `SLEEP` on the X16; busy loop in the sim) | `CONFIG_PAUSE` | 54 |
| `PEEK` keeps LINNUM, so `DOKE a,PEEK(b)` works | `CONFIG_PEEK_SAVE_LINNUM` | 12 |
| `PI` | `CONFIG_PI` | 21 |
| **Total** | | **1775** |

`CONFIG_FAST_FIN` also makes number parsing faster; `CONFIG_RADIX_LIT` does not build without it.

## Internals (no keywords)

| Feature | Flag | Bytes |
|---|---|---|
| simple variable address cache | `CONFIG_VAR_CACHE` | 358 |
| GOTO/GOSUB target cache | `CONFIG_GOTO_CACHE` | 347 |
| keyword table longer than 256 bytes | `CONFIG_KW16` | 23 |
| safer check in PTRGET | `CONFIG_SAFE_NAMENOTFOUND` | 8 |
| no keyword search inside a name (`BORDER` is not `B`,`OR`,`DER`, `TOTAL` is not `TO`,`TAL`) | `CONFIG_NAME_NOCRUNCH` | 46 |
| `POS(1)` gives the line; a new line clears the column | `CONFIG_POS_LINE` | 10 |
| no `LET` keyword | `CONFIG_NO_LET` | -5 |
| no `SPC(` keyword | `CONFIG_NO_SPC` | -13 |
| **Total** | | **774** |

File I/O (`OPEN`, `CLOSE`, `PRINT#`, `INPUT#`, `GET#`, `CMD`, `SYS`, `ST`) uses the CBM keywords
through `handle_io.s`. Its cost is not listed, because the sim build does not assemble without it.

## Planned keywords (estimates)

In `TODO.md` order. Table bytes are the name plus a 2-byte dispatch address. Code bytes are rough
guesses until the code is written.

| Keywords | TODO | Table | Code (est.) | Total (est.) |
|---|---|---|---|---|
| `MEMCPY`, `MEMSET` (deferred) | 1 | 16 | 90 | 106 |
| `'` as short `REM` (no table entry) | 1 | 0 | 15 | 15 |
| `SUB` / `END SUB`, `CALL`, `LOCAL` | 2B | 18 | 600 | 618 |
| `FUNCTION` / `END FUNCTION` | 2C | 10 | 400 | 410 |
| **Total** | | **44** | **1105** | **1149** |

Real integer math (TODO 3) adds no keywords but a large amount of code; inline assembly (TODO 4)
is still an open design. With the estimates above, about 3000 bytes of the 16128-byte ROM space
would remain.
