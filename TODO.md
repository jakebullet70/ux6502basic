# TODO

Planned work for ux6502basic. Items are done in order unless noted. Each `src/` change is logged
in `docs/changes.md` and gets a test in `tests/`.

## 1. Faster variable lookup

PTRGET walks the variable table from the start on every use, so the 25th variable costs much
more than the first. Speed up the search (for example a cache of the last few lookups, or an
index by first letter) without changing the 7-byte variable format.

- Measure with the "Z first of 25" and "Z last of 25" benchmark cases.
- Sim build only, behind a config flag.

## 2. Real integer math (last)

`%` variables are stored as 16-bit integers but every operation converts them to float and
back. Doing integer arithmetic directly would speed up `A%=A%+1` and similar code. It is a big
change to the expression evaluator for a modest gain, so it comes after the items above.
