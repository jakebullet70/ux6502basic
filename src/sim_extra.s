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

; read one character from stdin; preserves X and Y.
; LF ends a line and becomes CR; CR is dropped so CRLF files work.
; Other characters are echoed like a terminal would, so stdout is a full
; session transcript. BASIC prints the newline after the line itself.
MONRDKEY:
        txa
        pha
        tya
        pha
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
