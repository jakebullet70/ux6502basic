; sim65 target: headless build for tests.
; Console and files go through sim65 paravirtualization calls (handle_io.s,
; sim_extra.s); the console is fd 0 (stdin) and fd 1 (stdout). EOF on stdin
; exits sim65 with code 0.

; configuration
CONFIG_2C := 1

CONFIG_SCRTCH_ORDER := 2
CONFIG_FILE := 1 ; PRINT#, INPUT#, GET#, CMD, OPEN, CLOSE, SYS
CONFIG_HANDLE_IO := 1 ; files and console through handles (handle_io.s)
CONFIG_BLOCK := 1 ; block IF/ELSE/END IF, DO/LOOP (block.s); needs CONFIG_HANDLE_IO
CONFIG_NO_LET := 1 ; no LET keyword (A=1 still works); keeps the keyword table small
CONFIG_KW16 := 1 ; tokenizer and LIST walk the keyword table with KW_PTR (any length)
CONFIG_FAST_FIN := 1 ; FIN reads digits as an integer and floats it once
CONFIG_INSTR := 1 ; INSTR([start,] a$, b$) function

; zero page
ZP_START1 := $00
ZP_START2 := $0D
ZP_START3 := $5B
ZP_START4 := $66 ; w65c816sxb uses $65, which overlaps Z14

;extra ZP variables
USR              := $000A
SIM_CSP          := $00F0 ; cc65 C stack pointer used by sim65 paravirt calls
CURDVC           := $00F2 ; current logical file, 0 = console
Z96              := $00F3 ; ST, status of the last file read
BLK_DEPTH        := $00F4 ; block.s scan: nesting depth
BLK_LAST         := $00F5 ; block.s scan: last token on the line
BLK_MODE         := $00F6 ; block.s scan: TOKEN_ELSE, 0 or TOKEN_LOOP
KW_PTR           := $00F7 ; 2 bytes: keyword table pointer (CONFIG_KW16)

; constants
STACK_TOP        := $FA ; as CBM2: $01FD-$01FF are in front of INPUTBUFFER
SPACE_FOR_GOSUB  := $33
WIDTH            := 80 ; X16 text screen is 80x60
WIDTH2           := 70 ; last comma tab stop, as BASIC derives it for width 80

; memory layout: BASIC lives at $C000, RAM below it
INPUTBUFFER      := $0200 ; as on CBM machines; frees zero page
LINE_MAX         := 80 ; longest typed line, one X16 screen row
RAMSTART2        := $0400
SIM_RAMTOP       := $C0 ; memory size scan stops at this page

; console handles (host stdin and stdout)
K_STDIN          := 0
K_STDOUT         := 1

; sim65 paravirtualization entry points
SIM_PV_OPEN      := $FFF4
SIM_PV_CLOSE     := $FFF5
SIM_PV_READ      := $FFF6
SIM_PV_WRITE     := $FFF7
SIM_PV_ARGS      := $FFF8
SIM_ARGS_TOP     := $0400 ; command-line args are copied below this
SIM_PV_EXIT      := $FFF9

SAVE:
LOAD:
        rts
