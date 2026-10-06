# TODO

Planned work for ux6502basic. Items are done in order unless noted. Each `src/` change is logged
in `docs/changes.md` and gets a test in `tests/`.

## 1. New functions and literals

HEX$, BIN$, RPT$, MOD, π, and `$` and `%` literals (hex and binary).

## 2. Real integer math (last)

`%` variables are stored as 16-bit integers but every operation converts them to float and
back. Doing integer arithmetic directly would speed up `A%=A%+1` and similar code. It is a big
change to the expression evaluator for a modest gain, so it comes after the items above.
