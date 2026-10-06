; Block IF / ELSE / END IF (CONFIG_BLOCK).
;
; IF c THEN with nothing after THEN on the line starts a block. A false
; condition skips to the matching ELSE or END IF. ELSE, reached after the
; true part, skips to the matching END IF. END IF itself does nothing (END
; followed by IF, see END in flow1.s). Statements after ELSE on the same
; line run, so ELSE IF c THEN chains blocks; each block needs its own END IF.
; Blocks push nothing on the stack.
;
; The scan works on the tokenized text: a line whose last token (spaces
; skipped) is THEN opens a block, END followed by IF closes one. Text in
; quotes and after REM is skipped.

.segment "EXTRA"

; ----------------------------------------------------------------------------
; "ELSE" STATEMENT: skip to the matching END IF
; ----------------------------------------------------------------------------
ELSE:
        lda     #0		; stop at END IF only
        .byte   $2C

; ----------------------------------------------------------------------------
; False block IF (from IF in flow2.s): skip to the matching ELSE or END IF
; ----------------------------------------------------------------------------
BLK_FALSE:
        lda     #TOKEN_ELSE	; stop at ELSE too
        sta     BLK_MODE
        ldy     #0
        sty     BLK_DEPTH
        sty     BLK_LAST
@loop:
        lda     (TXTPTR),y
        beq     @eol
        cmp     #'"'
        bne     @noquote
@quote:
        iny
        lda     (TXTPTR),y
        beq     @eol
        cmp     #'"'
        bne     @quote
@noquote:
        cmp     #TOKEN_REM
        beq     @rem
        cmp     #' '
        beq     @next
        cmp     BLK_MODE
        beq     @else
        cmp     #TOKEN_IF
        bne     @last
        ldx     BLK_LAST
        cpx     #TOKEN_END
        bne     @last
        ldx     BLK_DEPTH	; END IF
        beq     @found
        dec     BLK_DEPTH
@last:
        sta     BLK_LAST
@next:
        iny
        bne     @loop		; always (a line is shorter than 256 bytes)
@else:
        ldx     BLK_DEPTH
        bne     @last
@found:
        jsr     ADDON		; TXTPTR at the ELSE or IF token
        jsr     CHRGET
        jmp     L288D		; run the rest of the line
@rem:
        sta     BLK_LAST	; IF c THEN REM is a one-line IF
@remloop:
        iny
        lda     (TXTPTR),y
        bne     @remloop
@eol:
        lda     BLK_LAST
        cmp     #TOKEN_THEN
        bne     @line
        inc     BLK_DEPTH	; IF c THEN at the end of a line
@line:
        jsr     ADDON		; TXTPTR at the end of the line
        ldy     #2
        lda     (TXTPTR),y
        beq     @missing	; end of the program
        iny
        lda     (TXTPTR),y
        sta     CURLIN
        iny
        lda     (TXTPTR),y
        sta     CURLIN+1
        lda     #0
        sta     BLK_LAST
        iny
        bne     @loop		; always
@missing:
        ldx     #HIO_ERR_ENDIF
        jmp     HIO_ERROR
