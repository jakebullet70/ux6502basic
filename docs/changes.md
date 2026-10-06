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
