# ux6502basic

Microsoft BASIC for the 6502, brought forward from its 1978 source. This code is an exersize at the moment, maybe something will happen in the future.

The code is a fork of [mist64/msbasic](https://github.com/mist64/msbasic), a ca65 version of the
original source. It is NMOS 6502 code only, with no 65C02 opcodes.

**Status:** early work. BASIC runs headless under sim65 and passes its tests. The X16 target and
its kernal do not exist yet.

## What is new

Compared to Commodore BASIC 2:

- Block `IF c THEN` / `ELSE` / `END IF`, with `ELSE IF` chains.
- `DO` / `LOOP` / `EXIT [DO]`.
- No `LET` keyword (`A=1` still works).
- Keywords and variable names may be typed in lowercase.
- File I/O by name: `OPEN lf,"name"[,mode]` (0 read, 1 write, 2 append), `CLOSE`, `PRINT#`,
  `INPUT#`, `GET#`, `CMD` and `ST`, on top of four primitives: open, close, read and write.
- 80-character input lines with backspace, for an 80x60 screen.
- `SYS address` calls machine code.

Example:

```basic
10 OPEN 1,"DATA.TXT",1
20 FOR I=1 TO 3: PRINT#1,I*I: NEXT
30 CLOSE 1
40 OPEN 1,"DATA.TXT"
50 DO
60 INPUT#1,N
70 IF N>4 THEN
80 PRINT N;"IS BIG"
90 ELSE
100 PRINT N
110 END IF
120 IF ST THEN EXIT
130 LOOP
140 CLOSE 1
```

## Build

You need [cc65](https://cc65.github.io/) (ca65, ld65 and sim65), GNU make and Python 3.

```sh
make all      # build every target into build/
make test     # run the BASIC test programs under sim65
make verify   # compare cbmbasic1 and cbmbasic2 with the original ROM dumps
make run      # start the sim build interactively
```

`make verify` needs the original ROM dumps from mist64/msbasic:

```sh
git clone https://github.com/mist64/msbasic.git ref/msbasic
```

## Targets

- `sim`: headless build for sim65, with the console on stdin and stdout. This is where new
  features are developed and tested.
- `cbmbasic1`, `cbmbasic2`: Commodore PET BASIC 1 and 2. They still build byte for byte equal to
  the original ROMs, which checks that changes to the shared sources do not break the old code.
  `make pet` runs BASIC 2 in the VICE PET emulator.

## Layout

- `m6502.asm`: the original 1978 Microsoft source (MACRO-10 syntax). It is kept as history and
  is not edited.
- `src/`: the ca65 sources. `msbasic.s` builds every target; `make` passes `-D <target>`.
- `tests/`: each `NAME.bas` is typed into the sim build and its output is compared with
  `NAME.out`.
- `docs/changes.md`: every change made to the msbasic sources, and why.
- `docs/`: 6502 notes and design notes.

## Licenses and credits

- `m6502.asm`: Microsoft Corporation, MIT license (`LICENSE-microsoft`). Microsoft's notes on
  the source are in `docs/README-microsoft.md`.
- `src/`: Michael Steil and the msbasic contributors, 2-clause BSD (`LICENSE`,
  `src/README-msbasic.md`). Our changes use the same license.

This project is not affiliated with Microsoft or Commodore.
