; PAUSE statement (CONFIG_PAUSE), like SLEEP on the X16.

; ----------------------------------------------------------------------------
; "PAUSE" STATEMENT: PAUSE [N], 0 <= N <= 65535
; WAITS N+1 JIFFIES (1/60 S), SO PAUSE AND PAUSE 0 WAIT FOR THE NEXT ONE AND
; PAUSE 60 WAITS ABOUT A SECOND. K_JIFFY IS THE TARGET PRIMITIVE THAT WAITS
; FOR ONE JIFFY (SIM: A BUSY LOOP; NEW KERNAL: THE NEXT VSYNC). ISCNTC RUNS
; EVERY JIFFY, SO THE BREAK KEY STOPS A LONG PAUSE.
; ----------------------------------------------------------------------------
PAUSE:
        php
        ldy     #$00
        sty     LINNUM
        sty     LINNUM+1
        plp			; Z from CHRGOT: no argument
        beq     L_PAUSE1
        jsr     FRMNUM
        jsr     GETADR
L_PAUSE1:
        jsr     K_JIFFY
        jsr     ISCNTC
        lda     LINNUM
        bne     L_PAUSE2
        lda     LINNUM+1
        beq     L_PAUSE3
        dec     LINNUM+1
L_PAUSE2:
        dec     LINNUM
        jmp     L_PAUSE1
L_PAUSE3:
        rts
