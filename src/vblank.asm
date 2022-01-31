INCLUDE "hardware.inc"

SECTION "Wait for VBlank", ROM0
WaitVBlank::
    xor a, a
    ld [wWaitVBlankFlag], a
:   halt
    ld a, [wWaitVBlankFlag]
    and a, a
    jr z, :-
    ret

SECTION "VBlank Interrupt", ROM0[$0040]
    push af
    push bc
    push de
    push hl
    jp VBlank

SECTION "VBlank Handler", ROM0
VBlank:
    ld a, HIGH(wShadowOAM)
    call hOAMDMA
    ldh a, [hShadowSCX]
    ldh [rSCX], a
    ldh a, [hShadowSCY]
    ldh [rSCY], a
    ld a, 1
    ld [wWaitVBlankFlag], a
    pop hl
    pop de
    pop bc
    pop af
    reti

SECTION "Wait VBlank flag", WRAM0
wWaitVBlankFlag: db

SECTION "Shadow scroll registers", HRAM
hShadowSCX:: db
hShadowSCY:: db
