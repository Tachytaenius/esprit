INCLUDE "bank.inc"
INCLUDE "defines.inc"
INCLUDE "hardware.inc"
INCLUDE "optimize.inc"
INCLUDE "text.inc"
INCLUDE "vdef.inc"

DEF POPUP_SPEED EQU 8

    dregion vHUD, 0, 28, 20, 4, $9C00
    dregion vTextbox, 1, 29, 18, 3, $9C00
    dregion vAttackWindow, 0, 0, 10, 5, $9C00
    dregion vAttackText, 2, 1, 8, 4, $9C00
    dtile_section $9010
    dtile vTextboxTiles, vTextbox_Width * vTextbox_Height
    dtile vAttackTiles, vAttackText_Width * vAttackText_Height
    dtile vUIFrameTop
    dtile vUIFrameLeft
    dtile vUIFrameRight
    dtile vUIFrameLeftCorner
    dtile vUIFrameRightCorner
    dtile vUIArrowUp
    dtile vUIArrowRight
    dtile vUIArrowDown
    dtile vUIArrowLeft

SECTION "User interface graphics", ROMX
xUIFrame:
    INCBIN "res/ui/hud_frame.2bpp"
.end
xUIArrows:
    INCBIN "res/ui/arrows.2bpp"
.end
xUIPalette:
    rgb_lim 31, 20, 31
    rgb_lim 31, 3, 31
    rgb_lim 16, 0, 16
    rgb 0, 0, 0

SECTION "Initialize user interface", ROM0
InitUI::
    ld a, [hCurrentBank]
    push af

    ld a, BANK(xUIFrame)
    rst SwapBank
    ld c, xUIFrame.end - xUIFrame
    ld de, vUIFrameTop
    ld hl, xUIFrame
    call VRAMCopySmall
    ld c, xUIArrows.end - xUIArrows
    ld de, vUIArrowUp
    ld hl, xUIArrows
    call VRAMCopySmall

    lb bc, idof_vUIFrameTop, vHUD_Width - 2
    ld hl, vHUD + 1
    call VRAMSetSmall
:       ldh a, [rSTAT]
        and a, STATF_BUSY
        jr nz, :-
    ; 17.75 safe cycles.
    ld a, idof_vUIFrameRightCorner ; 2
    ld [vHUD + vHUD_Width - 1], a ; 5
    ASSERT idof_vUIFrameRightCorner - 1 == idof_vUIFrameLeftCorner
    dec a ; 6
    ld [vHUD], a ; 9
    ASSERT idof_vUIFrameLeftCorner - 1 == idof_vUIFrameRight
    dec a ; 10
    ld [vHUD + vHUD_Width - 1 + 32], a ; 13
    ld [vHUD + vHUD_Width - 1 + 64], a ; 16
:       ldh a, [rSTAT]
        and a, STATF_BUSY
        jr nz, :-
    ; 17.75 safe cycles.
    ld a, idof_vUIFrameRight ; 2
    ld [vHUD + vHUD_Width - 1 + 96], a ; 5
    ASSERT idof_vUIFrameRight - 1 == idof_vUIFrameLeft
    dec a ; 6
    ld [vHUD + 32], a ; 9
    ld [vHUD + 64], a ; 12
    ld [vHUD + 96], a ; 15

    ld a, LOW(ShowTextBox)
    ld [wSTATTarget], a
    ld a, HIGH(ShowTextBox)
    ld [wSTATTarget + 1], a

    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_WINON | LCDCF_WIN9C00
    ldh [hShadowLCDC], a
    ld a, 144 - 32 - 1
    ldh [rLYC], a
    ; Hide the window offscreen.
    ld a, SCRN_X
    ldh [hShadowWX], a
    ld a, SCRN_Y
    ldh [hShadowWY], a

    ldh a, [hSystem]
    and a, a
    jr z, .skipCGB
        ; Load to the 7th palette.
        ld c, 4 * 3
        ld de, wBGPaletteBuffer + 4 * 3 * 7
        ld hl, xUIPalette
        call MemCopySmall

        ld a, 1
        ldh [rVBK], a
        ld d, 7
        ld bc, $400
        ld hl, $9C00
        call VRAMSet
        xor a, a
        ldh [rVBK], a
.skipCGB

    pop af
    jp SwapBank

SECTION "Print HUD", ROM0
; @param b:  Bank of string
; @param hl: String to print
PrintHUD::
    ldh a, [hCurrentBank]
    push af
    push bc
    ; Draw move names
    ld a, BANK(xTextInit)
    rst SwapBank
    ld a, vTextbox_Width * 8
    lb bc, idof_vTextboxTiles, idof_vTextboxTiles + vTextbox_Width * vTextbox_Height
    lb de, vTextbox_Height, HIGH(vTextboxTiles) & $F0
    call xTextInit

    xor a, a
    ld [wTextLetterDelay], a

    pop bc
    ld a, 1
    call PrintVWFText

    lb de, vTextbox_Width, vTextbox_Height
    ld hl, vTextbox
    bankcall xTextDefineBox
    call ReaderClear
    call TextClear
    call PrintVWFChar
    call DrawVWFChars

    pop af
    rst SwapBank
    ret

SECTION "Attack window", ROM0
UpdateAttackWindow::
    ldh a, [hCurrentBank]
    push af

    ld a, [wShowMoves]
    and a, a
    jp z, .close
.open
    ldh a, [hNewKeys]
    bit PADB_A, a
    jr z, .skipRedraw
        xor a, a
        ld [wWindowBounce], a
:           ld a, [rSTAT]
            and a, STATF_BUSY
            jr nz, :-
        ld a, idof_vUIFrameLeftCorner ; 2
        ld [vAttackWindow], a ; 6
        ld a, idof_vUIFrameLeft ; 8
        ld [vAttackWindow + 32], a ; 12
        ld [vAttackWindow + 64], a ; 16
        lb bc, idof_vUIFrameTop, vAttackWindow_Width + 2
        ld hl, vAttackWindow + 1
        call VRAMSetSmall
        ; We actually have ~7 cycles coming out of this function.
        ld a, idof_vUIFrameLeft ; 2
        ld [vAttackWindow + 128], a ; 6
:           ld a, [rSTAT]
            and a, STATF_BUSY
            jr nz, :-
        ld a, idof_vUIArrowUp ; 2
        ld [vAttackWindow + 1 + 32], a ; 6
        inc a ; 7
        ld [vAttackWindow + 1 + 64], a ; 11
        inc a ; 12
        ld [vAttackWindow + 1 + 96], a ; 16
:           ld a, [rSTAT]
            and a, STATF_BUSY
            jr nz, :-
        ld a, idof_vUIArrowUp ; 2
        ld [vAttackWindow + 1 + 128], a ; 6
        ld a, idof_vUIFrameLeft ; 8
        ld [vAttackWindow + 96], a ; 12

        ; Draw move names
        ld a, BANK(xTextInit)
        rst SwapBank
        ld a, vAttackText_Width * 8
        lb bc, idof_vAttackTiles, idof_vAttackTiles + vAttackText_Width * vAttackText_Height
        lb de, vAttackText_Height, HIGH(vAttackTiles) & $F0
        call xTextInit

        xor a, a
        ld [wTextLetterDelay], a

        ld b, BANK(xDebugAttacks)
        ld hl, xDebugAttacks
        ld a, 1
        call PrintVWFText

        lb de, vAttackText_Width, vAttackText_Height
        ld hl, vAttackText
        bankcall xTextDefineBox
        call PrintVWFChar
        call DrawVWFChars
.skipRedraw
    ld a, [wWindowBounce]
    and a, a
    jr nz, .bounceEffect
    ldh a, [hShadowWX]
    cp a, SCRN_X - vAttackWindow_Width * 8
    jr z, :+
    sub a, POPUP_SPEED
    ldh [hShadowWX], a
    cp a, SCRN_X - vAttackWindow_Width * 8
    jr nz, :+
    ld a, 1
    ld [wWindowBounce], a
:   ld a, SCRN_Y - vAttackWindow_Height * 8 - 32
    ldh [hShadowWY], a
    jp BankReturn
.close
    ld a, SCRN_X
    ldh [hShadowWX], a
    ld a, SCRN_Y
    ldh [hShadowWY], a
    jp BankReturn
.bounceEffect
    cp a, 1
    jr nz, .in
    ldh a, [hShadowWX]
    sub a, POPUP_SPEED / 2
    ldh [hShadowWX], a
    cp a, SCRN_X - vAttackWindow_Width * 8 - 16
    jp nz, BankReturn
    ld [wWindowBounce], a
    jp BankReturn
.in
    ldh a, [hShadowWX]
    add a, POPUP_SPEED / 4
    ldh [hShadowWX], a
    cp a, SCRN_X - vAttackWindow_Width * 8
    jp nz, BankReturn
    xor a, a
    ld [wWindowBounce], a
    jp BankReturn

SECTION "Show text box", ROM0
ShowTextBox:
:   ld a, [rSTAT]
    and a, STATF_BUSY
    jr nz, :-
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BG9C00 | LCDCF_OBJ16
    ldh [rLCDC], a
    xor a, a
    ldh [rSCX], a
    ld a, 256 - 144
    ldh [rSCY], a
    ret

SECTION "Window effect bounce", WRAM0
wWindowBounce: db

SECTION "Debug Text", ROMX
xDebugText: db "Eievui used scratch!<DELAY>",60,"\n"
            db "Dealt 255 damage.<DELAY>",60,"<END>"

SECTION "Debug attacks", ROMX
xDebugAttacks: db "One\nTwo\nThree\nFour<END>"