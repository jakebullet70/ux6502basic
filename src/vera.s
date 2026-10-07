; VPEEK function and VPOKE statement (CONFIG_VERA), like on the X16.

; ----------------------------------------------------------------------------
; "VPEEK" FUNCTION: VPEEK(BANK, ADDR), 0 <= BANK <= 255, 0 <= ADDR <= 65535
; RETURNS THE BYTE AT ADDR IN VIDEO MEMORY BANK BANK. THE TARGET PRIMITIVE
; K_VPEEK DOES THE READ (SIM: A STUB THAT GIVES 0). LINNUM IS KEPT, SO
; VPOKE B,A,VPEEK(B,C) WORKS. CALLED FROM FRM_ELEMENT WITH THE TOKEN IN A.
; ----------------------------------------------------------------------------
VPEEK:
        lda     LINNUM+1
        pha
        lda     LINNUM
        pha
        jsr     CHRGET
        jsr     CHKOPN
        jsr     GETBYT		; X = bank
        txa
        pha
        jsr     CHKCOM
        jsr     FRMNUM
        jsr     GETADR		; LINNUM = address
        jsr     CHKCLS
        pla			; bank
        jsr     K_VPEEK
        tay
        pla
        sta     LINNUM
        pla
        sta     LINNUM+1
        jmp     SNGFLT

; ----------------------------------------------------------------------------
; "VPOKE" STATEMENT: VPOKE BANK, ADDR, N, 0 <= BANK, N <= 255
; STORES N AT ADDR IN VIDEO MEMORY BANK BANK. THE TARGET PRIMITIVE K_VPOKE
; DOES THE WRITE (SIM: A STUB THAT DOES NOTHING).
; ----------------------------------------------------------------------------
VPOKE:
        jsr     GETBYT		; X = bank
        txa
        pha
        jsr     CHKCOM
        jsr     GTNUM		; LINNUM = address, X = N
        pla			; bank
        jmp     K_VPOKE
