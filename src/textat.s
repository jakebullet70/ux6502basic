; TEXTAT statement (CONFIG_TEXTAT).

; ----------------------------------------------------------------------------
; "TEXTAT" STATEMENT: TEXTAT X,Y,A$[,C] OR TEXTAT X,Y,CODE[,C]
; PRINTS A$, OR CHR$(CODE), AT COLUMN X, ROW Y (0,0 IS TOP LEFT), IN
; COLOR C IF GIVEN. THE CURSOR AND POS() STAY WHERE THEY WERE.
; THE SIM BUILD SENDS ANSI CODES TO THE CURRENT OUTPUT: ESC 7 (SAVE CURSOR
; AND COLOR), ESC[38;5;CCCm, ESC[YYY;XXXH (1-BASED), THE TEXT, ESC 8
; (RESTORE). THE NEW KERNAL WILL REPLACE THIS WITH ITS OWN SCREEN CALLS.
; ----------------------------------------------------------------------------
TEXTAT:
        jsr     GETBYT		; X = column
        inx			; ANSI counts from 1
        txa
        pha
        jsr     COMBYTE		; X = row
        inx
        txa
        pha
        jsr     CHKCOM
        jsr     FRMEVL
        bit     VALTYP
        bmi     L_TA1
        jsr     L_TACHR		; code: make CHR$(code)
L_TA1:
        lda     FAC_LAST-1	; keep the descriptor address
        pha
        lda     FAC_LAST
        pha
        ldy     #TA_SAVE-TA_TAB	; an error after this leaves only a
        jsr     TA_PUTS		; saved cursor, which is harmless
        jsr     CHRGOT
        beq     L_TA2
        jsr     COMBYTE		; X = color
        ldy     #TA_COL-TA_TAB
        jsr     TA_PUTS
        txa
        jsr     TA_DEC
        lda     #'m'
        jsr     MONCOUT
L_TA2:
        ldy     #TA_POS-TA_TAB
        jsr     TA_PUTS
        pla
        sta     DSCPTR+1
        pla
        sta     DSCPTR
        pla			; row
        jsr     TA_DEC
        lda     #';'
        jsr     MONCOUT
        pla			; column
        jsr     TA_DEC
        lda     #'H'
        jsr     MONCOUT
        lda     DSCPTR
        ldy     DSCPTR+1
        jsr     FRETMP		; A = LEN, INDEX = text
        tax
        beq     L_TA4
        ldy     #$00
L_TA3:
        lda     (INDEX),y
        jsr     MONCOUT
        iny
        dex
        bne     L_TA3
L_TA4:
        ldy     #TA_REST-TA_TAB

; PRINT TA_TAB FROM OFFSET Y UP TO THE 0
TA_PUTS:
        lda     TA_TAB,y
        beq     L_TA5
        jsr     MONCOUT
        iny
        bne     TA_PUTS
L_TA5:
        rts

; CHRSTR DROPS ONE RETURN ADDRESS (UNARY'S), SO IT RETURNS TO OUR CALLER
L_TACHR:
        jsr     CHRSTR

; PRINT A AS THREE DECIMAL DIGITS
TA_DEC:
        ldy     #$00
L_TA6:
        ldx     #'0'-1
        sec
L_TA7:
        inx
        sbc     TA_DIV,y
        bcs     L_TA7
        adc     TA_DIV,y	; carry is clear: add the divisor back
        pha
        txa
        jsr     MONCOUT
        pla
        iny
        cpy     #$02
        bne     L_TA6
        ora     #'0'
        jmp     MONCOUT

TA_DIV:
        .byte   100,10
TA_TAB:
TA_SAVE:
        .byte   $1B,"7",0
TA_COL:
        .byte   $1B,"[38;5;",0
TA_POS:
        .byte   $1B,"[",0
TA_REST:
        .byte   $1B,"8",0
