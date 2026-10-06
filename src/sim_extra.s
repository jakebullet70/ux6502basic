.segment "EXTRA"

; ----------------------------------------------------------------------------
; Console I/O for sim65.
; PVRead/PVWrite use the cc65 calling convention: fd and buffer are pushed on
; the C stack at (SIM_CSP), the count is passed in A/X, the result comes back
; in A/X. Every call rebuilds the 4-byte parameter frame in SIMPARM.
; ----------------------------------------------------------------------------

SIMCHAR:
        .res    1
SIMPARM:
        .res    4               ; buf lo, buf hi, fd lo, fd hi

; set up a frame for one byte at SIMCHAR on fd A; returns count 1 in A/X
SIMFRAME:
        sta     SIMPARM+2
        lda     #0
        sta     SIMPARM+3
        lda     #<SIMCHAR
        sta     SIMPARM
        lda     #>SIMCHAR
        sta     SIMPARM+1
        lda     #<SIMPARM
        sta     SIM_CSP
        lda     #>SIMPARM
        sta     SIM_CSP+1
        lda     #1
        ldx     #0
        rts

SIMECHO:
        .byte   $FF             ; $FF: not checked yet, 0: no echo, 1: echo

; Echo is on when sim65 gets any argument after the program file
; ("sim65 sim.bin echo"). An interactive console already echoes what is
; typed; tests feed stdin from a file and want it in the transcript.
; PVArgs copies the arguments below the C stack pointer, so point it at
; free RAM under RAMSTART2 first. It returns argc (program name included).
SIMARGS:
        lda     #<SIM_ARGS_TOP
        sta     SIM_CSP
        lda     #>SIM_ARGS_TOP
        sta     SIM_CSP+1
        lda     #<SIMPARM       ; argv pointer lands here, unused
        ldx     #>SIMPARM
        jsr     SIM_PV_ARGS
        ldy     #0
        cpx     #0
        bne     @echo
        cmp     #2
        bcc     @set
@echo:
        iny
@set:
        sty     SIMECHO
        rts

; read one character from stdin; preserves X and Y.
; LF ends a line and becomes CR; CR is dropped so CRLF files work.
; With echo on, other characters go to stdout like a terminal would, so
; stdout is a full session transcript. BASIC prints the newline itself.
MONRDKEY:
        txa
        pha
        tya
        pha
        bit     SIMECHO
        bpl     @again
        jsr     SIMARGS
@again:
        lda     #0
        jsr     SIMFRAME
        jsr     SIM_PV_READ
        cmp     #1
        bne     @eof
        lda     SIMCHAR
        cmp     #$0D
        beq     @again
        cmp     #$0A
        bne     @echo
        lda     #$0D
        bne     @done
@echo:
        ldy     SIMECHO
        beq     @done
        jsr     MONCOUT
@done:
        sta     SIMCHAR
        pla
        tay
        pla
        tax
        lda     SIMCHAR
        rts
@eof:
        lda     #0
        jmp     SIM_PV_EXIT

; write the character in A to stdout; preserves A, X and Y.
; CR becomes LF; LF is dropped (BASIC sends CR LF).
MONCOUT:
        cmp     #$0A
        beq     @skip
        pha
        sta     SIMCHAR
        txa
        pha
        tya
        pha
        lda     SIMCHAR
        cmp     #$0D
        bne     @out
        lda     #$0A
        sta     SIMCHAR
@out:
        lda     #1
        jsr     SIMFRAME
        jsr     SIM_PV_WRITE
        pla
        tay
        pla
        tax
        pla
@skip:
        rts

; fold a-z in A to A-Z; keeps X and Y. The tokenizer uses it so keywords
; and variable names may be typed in lowercase (strings, REM and DATA stay).
SIM_UPPER:
        cmp     #'a'
        bcc     @keep
        cmp     #'z'+1
        bcs     @keep
        and     #$DF
@keep:
        rts
