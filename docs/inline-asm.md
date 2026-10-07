# Inline assembly: design notes

These notes cover TODO 4: 6502 code inside a BASIC program, with BASIC variables passed in and
out. Nothing here is built yet. All byte counts are estimates, and three design decisions are
still open (see the end).

## Goal

Today machine code is POKEd from `DATA` and started with `SYS`. That works, but the code is hard
to read, and values pass only through memory that the program has to PEEK and POKE. The aim:

```
100 ASM $C000
110   LDA #N
120   STA VARPTR(X)
130   JSR $FFD2
140   RTS
150 END ASM
160 SYS $C000,65
```

## Budget

| Phase | What | Bytes (est.) |
|---|---|---|
| A | `SYS addr[,a[,x[,y]]]` and `VARPTR(v)` | 60-100 |
| B | where the code lives (no code, a rule) | 0 |
| C | assembler in ROM (`ASM` ... `END ASM`) | 1000-1500 |
| C, other option | assembler loaded into RAM from disk | about 10 in ROM (a hook) |

The image has 4072 bytes free. SUB and FUNCTION (TODO 2) are estimated at 580-1030 bytes, and
real integer math (TODO 3) at a large amount. An assembler in ROM would take about a third of
the free space.

## Phase A: pass values to machine code

Phase A is useful without an assembler, and every later phase needs it.

### SYS with registers

`SYS addr[,a[,x[,y]]]`

- Loads A, X and Y from the optional arguments, then calls the code.
- After the `RTS`, stores A, X, Y and the status flags in 4 fixed RAM bytes, so `PEEK` reads
  them (as on the C64). The address of the 4 bytes is set per target.
- Today `SYS` in `handle_io.s` is only `FRMNUM`, `GETADR` and `jmp (LINNUM)`. The register
  arguments reuse `COMBYTE`, so no new parse code is needed.
- Estimate 30-40 bytes.

### VARPTR

`VARPTR(v)` gives the address of a variable's value.

- It reuses `PTRGET`. Estimate 20-30 bytes, plus about 8 for the keyword table entry.
- The value at that address:
  - float: 5 bytes in MS format;
  - `%` integer: 2 bytes, high byte first;
  - string: a 3-byte descriptor (length, then the address, low byte first).
- **A simple variable keeps its address** until `CLR`, `RUN` or a program edit. New simple
  variables go at the end of the simple-variable table and move only the arrays.
- **An array moves** each time a new simple variable is created. Take `VARPTR` of an array
  element after all simple variables exist.

`USR(x)` is already in the sim build. It passes FAC to the code at the `USR` vector and returns
FAC, which covers a single number.

## Phase B: where the code lives

Machine code goes in a RAM area at an address that the program picks, for example above
`MEMSIZ` after lowering it with a `POKE` at the start. Code stored inside the program text is
not an option: the program text moves whenever lines are edited, and an absolute `JMP` inside
it would break.

If SUB and FUNCTION take memory from the top for their RAM stack (see `docs/sub-function.md`),
the code area must not overlap it.

## Phase C: the assembler

### Syntax

- `ASM addr` ... `END ASM`, the same block style as `IF` / `END IF` and `DO` / `LOOP`. `END` is
  already a token, so only `ASM` is a new keyword.
- The other option is the BBC BASIC style `[` ... `]`. It needs no keyword, but `[` and `]` are
  not used anywhere else in this BASIC.
- One instruction per statement; `:` separates statements, as in BASIC.

### How it runs

- The block runs while the program runs. Each instruction writes its bytes from `addr` onward,
  and a program counter (the next address) moves along.
- **Operands are BASIC expressions.** `LDA #N`, `STA VARPTR(X)`, `JSR $FFD2` and `LDA #%1010`
  all work, because the `$` and `%` literals already exist (`radixlit.s`).
- **Labels:** `.L1` sets the BASIC variable `L1` to the current address. A jump to a label
  further down needs two passes, so the program runs the block twice, as in BBC BASIC (for
  example `FOR P=0 TO 1` around it). The first pass gives no error for an unknown label.
- Only 2 characters of a variable name count, so label names collide easily: `.LOOP1` and
  `.LOOP2` are the same label. A label lookup that scans the program text, as `LABEL_FIND`
  does, would let every character count, at about 60-100 extra bytes.

### How the tokenizer sees assembly lines

Assembly lines are tokenized like any other line, so the assembler reads tokens.

- With `CONFIG_NAME_NOCRUNCH`, a keyword with a letter right behind it is not a keyword, and a
  letter right after a letter is stored as it is. So `ORA` and `EOR` stay plain text.
- `AND` is the one 6502 mnemonic that is also a BASIC keyword. It is stored as `TOKEN_AND`,
  and the assembler accepts that token as the `AND` mnemonic.
- `#`, `(`, `)`, `,X` and `,Y` stay plain text.

### Tables and code size

| Part | Bytes (est.) |
|---|---|
| 56 mnemonic names (plain text 168, or packed 5 bits per letter) | 112-168 |
| opcode and addressing-mode tables | about 100 |
| operand parser (`#`, `(zp,X)`, `(zp),Y`, `abs,X`, zero page or absolute) | 300-500 |
| statement dispatch, program counter, byte output | 100-200 |
| labels (`.name`) | 40 |
| two-pass handling (no error on the first pass) | 30 |
| branch offsets and range check | 50 |
| **Total** | **about 750-1100**, with margin **1000-1500** |

### The option of an assembler in RAM

The assembler could be a program loaded from disk into RAM. The ROM then needs only a hook:
`ASM` jumps through a RAM vector that the loaded program sets (about 10 bytes). This costs
almost no ROM, but it needs the new kernal's file calls, and the assembler takes RAM while it
is loaded.

## CONST and typed BYTE / WORD

`CONST` is parked in TODO 4, because `BYTE` and `WORD` declarations belong to this design.

- In an assembler, BYTE and WORD have a real use: they pick zero-page or absolute addressing
  and range-check immediate operands (`LDA #WHITE`).
- A cheap form uses the program text as the symbol table: a `CONST name value` line is found by
  a scan like `LABEL_FIND`. All characters of a name count, and labels, constants and assembly
  labels share one namespace. Estimate 60-100 bytes on top of the assembler.
- Infer the size from the value (below 256 is a BYTE) and keep `WORD` only as an override. That
  drops the `BYTE` keyword.
- `PI` is a keyword, so no constant can be named `PI`.

## Plan

1. Phase A: `SYS` with registers, then `VARPTR`. Each with tests, an entry in
   `docs/changes.md` and its own commit, behind `.ifdef` so `cbmbasic1` and `cbmbasic2` stay
   unchanged.
2. Decide on the assembler after SUB and FUNCTION are built and their real size is known.
3. If the assembler goes in ROM: mnemonic table and one addressing mode first (implied, as
   `RTS`), then immediate, then zero page and absolute, then the indexed and indirect modes,
   then branches and labels. Test each mode against bytes that ca65 produces for the same
   code.

## Open decisions

1. Assembler in ROM, as a program loaded into RAM later, or phase A only?
2. `ASM` / `END ASM` or BBC-style `[` ... `]`?
3. Start now, ahead of `'` as REM and SUB, or keep the TODO order?

Recommendation: build phase A now, because it is cheap and every option needs it. Decide on the
assembler after SUB and FUNCTION show their real cost.

## Ways to save bytes

- `VARPTR` reuses `PTRGET`, and the `SYS` register arguments reuse `COMBYTE`.
- Pack the mnemonic names at 5 bits per letter (saves about 56 bytes; the unpack code costs
  about 20).
- Let BASIC expressions parse every operand; the assembler parses only the addressing-mode
  marks around them.
- Reuse existing error messages (`?SYNTAX ERROR`, `?ILLEGAL QUANTITY`) instead of new text.
