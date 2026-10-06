# BASIC-M6502

Microsoft BASIC for 6502 (1978 source, `m6502.asm`, DEC MACRO-10 syntax). Goal: build, run and
test it with ca65, then extend it for new hardware (Commander X16 with a new KERNAL).

## Rules

- `m6502.asm` is frozen history. Do not edit it. Work goes into `src/` (ca65).
- CPU is NMOS 6502 only. No 65C02 opcodes. See `docs/asm/6502-notes.md`.
- `m6502.asm` is about 50k tokens. Never read it whole; grep, then read line ranges.
- Use `git mv` / `git rm` for tracked files.
- Log every change to `src/` (what and why) in `docs/changes.md`, in the same commit.

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
- `sim` target (our addition): headless build for sim65. Files `defines_sim.s`, `sim_extra.s`,
  `sim_iscntc.s`, `sim.cfg`. BASIC at $C000; console on fd 0/1 via sim65 paravirt calls. Any argument
  after the program (`sim65 build/sim.bin echo`) echoes input so stdout is a session transcript
  (for tests; an interactive console echoes by itself). EOF on stdin exits with code 0.
  Keywords and variable names may be typed in lowercase (tokenizer folds them; strings, REM and
  DATA keep their case). Cold start skips the
  MEMORY SIZE? and TERMINAL WIDTH? prompts (RAM is scanned; width is 80, like the X16 80x60
  screen). `make run` starts it interactively.
  Run with `sim65 -x <cycles>` in scripts so a hang cannot block.
- `make pet` starts xpet (3032) with our BASIC 2 ROM (first 8K of `cbmbasic2.bin`).
  `make pet-check` types a program headless and saves `build/pet.png`.
- Upstream `defines_w65c816sxb.s` has overlapping zero page (`Z14` and `TEMPPT` both at $65,
  so FRE hangs). `defines_sim.s` fixes this with ZP_START4 = $66.

- `docs/changes.md`: log of our changes to the msbasic sources.
- `docs/asm/`: 6502 notes (NMOS rules, ca65) and the 65C02 instruction reference.
- `docs/x16/`: Commander X16 reference manual (KERNAL, memory map, VERA, ...).
- `ref/msbasic/` (git-ignored): mist64/msbasic ca65 port, commit 2a0bc2f, with original ROM
  dumps in `orig/`. Clone: `git clone https://github.com/mist64/msbasic.git ref/msbasic`.
  Its kb9, cbmbasic1, applesoft and osi builds match `orig/` byte for byte with our ca65.
