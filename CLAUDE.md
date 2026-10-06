# BASIC-M6502

Microsoft BASIC for 6502 (1978 source, `m6502.asm`, DEC MACRO-10 syntax). Goal: build, run and
test it with ca65, then extend it for new hardware (Commander X16 with a new KERNAL).

## Rules

- `m6502.asm` is frozen history. Do not edit it. Work goes into `src/` (ca65).
- CPU is NMOS 6502 only. No 65C02 opcodes. See `docs/asm/6502-notes.md`.
- `m6502.asm` is about 50k tokens. Never read it whole; grep, then read line ranges.
- Use `git mv` / `git rm` for tracked files.

## Tools (not on PATH)

- ca65/ld65/sim65 V2.19: `C:\8bitProgramming\cc65\bin\`
- make: `C:\8bitProgramming\make-4.4.1\bin\make.exe`
- Python: `C:\Users\Admin\AppData\Local\Programs\Python\Python313\python.exe`
- VICE 3.8 (`xpet` for the PET check): `C:\8bitProgramming\GTK3VICE-3.8-win32\`
- x16emu: `C:\8bitProgramming\x16emu\x16emu.exe`

## Layout

- `src/`: ca65 sources, forked from mist64/msbasic (2-clause BSD, see `src/README-msbasic.md`).
  One `msbasic.s` builds every target; `-D <target>` picks it, `<target>.cfg` sets the memory map.
- `Makefile` (run in Git Bash): `make all`, `make <target>`, `make verify` (byte-compare with the
  original ROM dumps; prints only mismatches), `make clean`. Output goes to `build/`.

- `docs/asm/`: 6502 notes (NMOS rules, ca65) and the 65C02 instruction reference.
- `docs/x16/`: Commander X16 reference manual (KERNAL, memory map, VERA, ...).
- `ref/msbasic/` (git-ignored): mist64/msbasic ca65 port, commit 2a0bc2f, with original ROM
  dumps in `orig/`. Clone: `git clone https://github.com/mist64/msbasic.git ref/msbasic`.
  Its kb9, cbmbasic1, applesoft and osi builds match `orig/` byte for byte with our ca65.
