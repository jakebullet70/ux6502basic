; Labels (CONFIG_LABELS): GOTO name, GOSUB name, ON x GOTO/GOSUB name,...,
; RESTORE name, RUN name.

; ----------------------------------------------------------------------------
; A LABEL IS A NAME AND A COLON AT THE START OF A LINE: "100 MAIN:". THE NAME
; STARTS WITH A LETTER; LETTERS, DIGITS AND KEYWORDS MAY FOLLOW ("MYPRINT" IS
; STORED AS MY,PRINT TOKEN). ALL CHARACTERS COUNT. A NAME THAT STARTS WITH A
; KEYWORD ("TOTAL" = TO,TAL) DOES NOT WORK, BECAUSE THE LINE THEN STARTS WITH A
; STATEMENT.
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; FIND THE LINE WHOSE LABEL IS THE NAME AT TXTPTR
; RETURNS LOWTR = START OF THAT LINE, CARRY SET; ?UNDEF'D STATEMENT IF NONE.
; INDEX = TXTPTR-4, SO (INDEX),Y AND (LOWTR),Y BOTH REACH CHARACTER Y-4 OF THE
; NAME AND OF THE LINE TEXT (BEHIND THE LINK AND THE LINE NUMBER).
; ----------------------------------------------------------------------------
LABEL_FIND:
        lda     TXTPTR
        sec
        sbc     #$04
        sta     INDEX
        lda     TXTPTR+1
        sbc     #$00
        sta     INDEX+1
        ldy     #$03
L_LF1:
        iny			; name ends at ":" or below "0"
        lda     (INDEX),y
        cmp     #':'
        beq     L_LF2
        cmp     #'0'
        bcs     L_LF1
L_LF2:
        sty     CHARAC		; offset of the ":" behind the name
        ldx     TXTTAB+1
        lda     TXTTAB
        ldy     #$01
L_LF3:
        sta     LOWTR
        stx     LOWTR+1
        lda     (LOWTR),y	; Y = 1: high byte of the link, 0 at the end
        beq     L_LF6
        tax
        ldy     CHARAC
        lda     (LOWTR),y
        cmp     #':'
        bne     L_LF5
L_LF4:
        dey			; compare the name from its end
        cpy     #$03
        beq     L_LF7		; all equal, carry set
        lda     (LOWTR),y
        cmp     (INDEX),y
        beq     L_LF4
L_LF5:
        ldy     #$00		; next line: A = low byte, X = high byte
        lda     (LOWTR),y
        iny
        bne     L_LF3		; always
L_LF6:
        jmp     UNDERR
L_LF7:
        rts

; ----------------------------------------------------------------------------
; A STATEMENT THAT STARTS WITH A LETTER IS AN ASSIGNMENT OR A LABEL. A LABEL
; REACHES ":" BEFORE ANY "=" TOKEN AND ANY CHARACTER BELOW "0" ($ % ( SPACE
; QUOTE END OF LINE). THE LABEL IS SKIPPED.
; ----------------------------------------------------------------------------
LABEL_SKIP:
        ldy     #$00
L_LS1:
        iny
        lda     (TXTPTR),y
        cmp     #TOKEN_EQUAL
        beq     L_LS2
        cmp     #':'
        beq     L_LS3
        bcs     L_LS1		; letters, tokens
        cmp     #'0'
        bcs     L_LS1		; digits
L_LS2:
        jmp     LET
L_LS3:
        jmp     ADDON		; TXTPTR to the ":"

; ----------------------------------------------------------------------------
; ON: SKIP ONE LINE NUMBER OR LABEL OF THE LIST, UP TO "," OR THE END
; ----------------------------------------------------------------------------
LABEL_ONSKIP:
        cmp     #','
        beq     L_LO1
        jsr     CHRGET
        bne     LABEL_ONSKIP
L_LO1:
        rts

; ----------------------------------------------------------------------------
; "RESTORE" [NAME]
; ----------------------------------------------------------------------------
RESTORE_STMT:
        bne     L_RS0
        jmp     RESTORE
L_RS0:
        jsr     LABEL_FIND
        lda     LOWTR		; DATPTR = the end of the line before
        sbc     #$01
        ldy     LOWTR+1
        bcs     L_RS1
        dey
L_RS1:
        jsr     SETDA
        jmp     DATA		; TXTPTR past the name
