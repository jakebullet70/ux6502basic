# Keywords and their cost in bytes

All keywords of the `sim` build, done and planned, with the bytes each feature adds to the
image. Measured on 2026-10-06 at commit a84799c; `UCASE$` and `LCASE$` added since.

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
| sim image, $C000-$ED0E (without the 12-byte sim65 header) | 11605 |
| of which RAM variables of `handle_io.s` (`IORAM` segment) | 634 |
| ROM space in `sim.cfg` ($C000 + $3F00) | 16128 |
| free | 4523 |
| new keywords (all items in "New keywords" below) | 1427 |
| speed-ups and internals (all items in "Internals" below) | 731 |
| CBM BASIC 2 (`cbmbasic2.bin`), for comparison | 8670 |

CBM BASIC 2 leaves screen, keyboard and file I/O to the KERNAL ROM. The sim image holds its own
I/O layer (`handle_io.s`), so the two sizes do not compare one to one.

Segments of the sim image:

| Segment | Bytes |
|---|---|
| VECTORS (dispatch tables) | 165 |
| KEYWORDS (keyword names) | 314 |
| ERROR (error messages) | 249 |
| CODE | 7773 |
| CHRGET | 29 |
| INIT | 354 |
| EXTRA (sim I/O and most of our additions) | 2087 |
| IORAM | 634 |

## Keyword table

The sim build has 91 tokens, $80-$DA. Inserting a keyword shifts the tokens after it, so saved
tokenized programs are only valid for the build that wrote them.

| Token | Keyword | | Token | Keyword | | Token | Keyword |
|---|---|---|---|---|---|---|---|
| 80 | END | | 9F | CLOSE | | BE | SQR |
| 81 | FOR | | A0 | GET | | BF | RND |
| 82 | NEXT | | A1 | NEW | | C0 | LOG |
| 83 | DATA | | A2 | **ELSE** | | C1 | EXP |
| 84 | INPUT# | | A3 | **DO** | | C2 | COS |
| 85 | INPUT | | A4 | **LOOP** | | C3 | SIN |
| 86 | DIM | | A5 | **EXIT** | | C4 | TAN |
| 87 | READ | | A6 | TAB( | | C5 | ATN |
| 88 | GOTO | | A7 | TO | | C6 | PEEK |
| 89 | RUN | | A8 | FN | | C7 | **DEEK** |
| 8A | IF | | A9 | SPC( | | C8 | LEN |
| 8B | RESTORE | | AA | THEN | | C9 | STR$ |
| 8C | GOSUB | | AB | NOT | | CA | VAL |
| 8D | RETURN | | AC | STEP | | CB | ASC |
| 8E | REM | | AD | + | | CC | CHR$ |
| 8F | STOP | | AE | - | | CD | **HEX$** |
| 90 | ON | | AF | * | | CE | **BIN$** |
| 91 | WAIT | | B0 | / | | CF | **UCASE$** |
| 92 | LOAD (stub) | | B1 | ^ | | D0 | **LCASE$** |
| 93 | SAVE (stub) | | B2 | AND | | D1 | LEFT$ |
| 94 | DEF | | B3 | OR | | D2 | RIGHT$ |
| 95 | POKE | | B4 | **MOD** | | D3 | MID$ |
| 96 | **DOKE** | | B5 | > | | D4 | **INSTR** |
| 97 | PRINT# | | B6 | = | | D5 | **RPT$** |
| 98 | PRINT | | B7 | < | | D6 | **PI** |
| 99 | CONT | | B8 | SGN | | D7 | **XOR** |
| 9A | LIST | | B9 | INT | | D8 | **SHL** |
| 9B | CLEAR | | BA | ABS | | D9 | **SHR** |
| 9C | CMD | | BB | USR | | DA | GO |
| 9D | SYS | | BC | FRE | |  |  |
| 9E | OPEN | | BD | POS | |  |  |

Bold keywords are new. The others come from Microsoft BASIC (CBM BASIC 2 set). `LOAD` and `SAVE`
are stubs that do nothing in the sim build. Removed from the CBM set: `LET` (`CONFIG_NO_LET`,
saves 5 bytes; `A=1` still works) and `VERIFY` (CBM targets only). `END IF` and `EXIT DO` are
built from existing tokens, so they need no table entries.

## New keywords (done)

| Keywords | Flag | Bytes |
|---|---|---|
| `IF c THEN` / `ELSE` / `END IF`, `DO` / `LOOP` / `EXIT [DO]` | `CONFIG_BLOCK` | 302 |
| `INSTR([start,] a$, b$)` | `CONFIG_INSTR` | 167 |
| `a MOD b` | `CONFIG_MOD` | 160 |
| `$FF`, `%1010` literals (no keyword) | `CONFIG_RADIX_LIT` | 147 |
| integer digit reader that the literals need | `CONFIG_FAST_FIN` | 120 |
| `XOR(a,b)`, `SHL(a,n)`, `SHR(a,n)` | `CONFIG_BITFN` | 128 |
| `RPT$(a$ or code, n)` | `CONFIG_RPT` | 112 |
| `HEX$(n)`, `BIN$(n)` | `CONFIG_HEXBIN` | 108 |
| `UCASE$(a$)`, `LCASE$(a$)` | `CONFIG_CASE` | 70 |
| `DEEK(addr)`, `DOKE addr,n` | `CONFIG_DEEK` | 80 |
| `PEEK` keeps LINNUM, so `DOKE a,PEEK(b)` works | `CONFIG_PEEK_SAVE_LINNUM` | 12 |
| `PI` | `CONFIG_PI` | 21 |
| **Total** | | **1427** |

`CONFIG_FAST_FIN` also makes number parsing faster; `CONFIG_RADIX_LIT` does not build without it.

## Internals (no keywords)

| Feature | Flag | Bytes |
|---|---|---|
| simple variable address cache | `CONFIG_VAR_CACHE` | 358 |
| GOTO/GOSUB target cache | `CONFIG_GOTO_CACHE` | 347 |
| keyword table longer than 256 bytes | `CONFIG_KW16` | 23 |
| safer check in PTRGET | `CONFIG_SAFE_NAMENOTFOUND` | 8 |
| no `LET` keyword | `CONFIG_NO_LET` | -5 |
| **Total** | | **731** |

File I/O (`OPEN`, `CLOSE`, `PRINT#`, `INPUT#`, `GET#`, `CMD`, `SYS`, `ST`) uses the CBM keywords
through `handle_io.s`. Its cost is not listed, because the sim build does not assemble without it.

## Planned keywords (estimates)

In `TODO.md` order. Table bytes are the name plus a 2-byte dispatch address. Code bytes are rough
guesses until the code is written.

| Keywords | TODO | Table | Code (est.) | Total (est.) |
|---|---|---|---|---|
| `CHARAT x,y,code[,color]`, `TEXTAT x,y,text[,color]` | 1 | 16 | 80 | 96 |
| `CONTINUE` (in `FOR`/`NEXT` and `DO`/`LOOP`) | 1 | 10 | 80 | 90 |
| `MEMCPY`, `MEMSET` (deferred) | 1 | 16 | 90 | 106 |
| labels: `GOTO name`, `GOSUB name`, `name:` (no keyword) | 2A | 0 | 150 | 150 |
| `SUB` / `END SUB`, `CALL`, `LOCAL` | 2B | 18 | 600 | 618 |
| `FUNCTION` / `END FUNCTION` | 2C | 10 | 400 | 410 |
| **Total** | | **70** | **1400** | **1470** |

Real integer math (TODO 3) adds no keywords but a large amount of code; inline assembly (TODO 4)
is still an open design. With the estimates above, about 3000 bytes of the 16128-byte ROM space
would remain.
