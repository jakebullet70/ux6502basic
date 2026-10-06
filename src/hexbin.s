; HEX$ and BIN$ functions (CONFIG_HEXBIN).

; ----------------------------------------------------------------------------
; "HEX$" AND "BIN$" FUNCTIONS: HEX$(N), BIN$(N), 0 <= N <= 65535
; N < 256 GIVES 2 HEX OR 8 BINARY DIGITS, ELSE 4 OR 16.
; CALLED FROM UNARY WITH THE ARGUMENT IN FAC; RETURNS A STRING LIKE CHR$
; (DROPS UNARY'S RETURN SO ITS CHKNUM IS SKIPPED).
; ----------------------------------------------------------------------------
HEXSTR:
        lda     #$02		; digits per byte
        ldx     #$04		; bits per digit
        bne     L_RADIX
BINSTR:
        lda     #$08
        ldx     #$01
L_RADIX:
        pha
        txa
        pha
        jsr     CHKNUM
        jsr     GETADR
        lda     LINNUM+1
        pha
        lda     LINNUM
        pha
        tsx
        lda     STACK+4,x	; digits per byte
        ldy     LINNUM+1
        beq     L_RADIX1
        asl     a
L_RADIX1:
        jsr     STRSPA		; may collect garbage; the value is on the stack
        pla
        sta     LINNUM
        pla
        sta     LINNUM+1
        pla
        sta     INDEX		; bits per digit
        pla
        ldy     FAC		; fill from the last digit back
L_RADIX2:
        dey
        lda     LINNUM
        ldx     INDEX
        and     #$0F
        cpx     #$01
        bne     L_RADIX3
        and     #$01
L_RADIX3:
        cmp     #$0A
        bcc     L_RADIX4
        adc     #$06		; carry is set: +7 gives "A"-"F"
L_RADIX4:
        adc     #$30
        sta     (FAC+1),y
L_RADIX5:
        lsr     LINNUM+1
        ror     LINNUM
        dex
        bne     L_RADIX5
        tya
        bne     L_RADIX2
        pla
        pla
        jmp     PUTNEW
