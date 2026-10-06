; sim65 target: headless build for tests.
; Console I/O goes through sim65 paravirtualization calls on fd 0 (stdin)
; and fd 1 (stdout). EOF on stdin exits sim65 with code 0.

; configuration
CONFIG_2C := 1

CONFIG_SCRTCH_ORDER := 2

; zero page
ZP_START1 := $00
ZP_START2 := $0D
ZP_START3 := $5B
ZP_START4 := $66 ; w65c816sxb uses $65, which overlaps Z14

;extra ZP variables
USR              := $000A
SIM_CSP          := $00F0 ; cc65 C stack pointer used by sim65 paravirt calls

; constants
STACK_TOP        := $FC
SPACE_FOR_GOSUB  := $33
WIDTH            := 80 ; X16 text screen is 80x60
WIDTH2           := 70 ; last comma tab stop, as BASIC derives it for width 80

; memory layout: BASIC lives at $C000, RAM below it
RAMSTART2        := $0400
SIM_RAMTOP       := $C0 ; memory size scan stops at this page

; sim65 paravirtualization entry points
SIM_PV_READ      := $FFF6
SIM_PV_WRITE     := $FFF7
SIM_PV_ARGS      := $FFF8
SIM_ARGS_TOP     := $0400 ; command-line args are copied below this
SIM_PV_EXIT      := $FFF9

SAVE:
LOAD:
        rts
