INCLUDE "defines.inc"
INCLUDE "dungeon.inc"
INCLUDE "entity.inc"
INCLUDE "hardware.inc"
INCLUDE "item.inc"

; The dungeon renderer is hard-coded to use these 4 metatiles to draw floors and
; walls. Additional tiles should follow these metatiles.
; For example, stairs, which use an ID of 2, should be placed at $90.
RSSET $80
DEF BLANK_METATILE_ID RB 4
DEF STANDALONE_METATILE_ID RB 4
DEF TERMINAL_METATILE_ID RB 4
DEF FULL_METATILE_ID RB 4
DEF EXIT_METATILE_ID RB 4
DEF ITEM_METATILE_ID RB 4 * 4

SECTION "Init dungeon", ROM0
; Switch to the dungeon state.
; @clobbers: bank
InitDungeon::
	; Value init
	ld hl, wActiveDungeon
	ld a, BANK(xForest)
	ld [hli], a
	ld a, LOW(xForest)
	ld [hli], a
	ld a, HIGH(xForest)
	ld [hli], a

	; Null init
	xor a, a
	ld c, SIZEOF("dungeon BSS")
	ld hl, STARTOF("dungeon BSS")
	call MemSetSmall

	; Null out all entities.
	ld hl, wEntity0
	ld b, NB_ENTITIES
.clearEntities
	ld [hl], a
	inc h
	dec b
	jr nz, .clearEntities

	lb bc, BANK(xLuvui), 5
	ld de, xLuvui
	ld h, HIGH(wEntity0)
	call SpawnEntity
	ld l, LOW(wEntity0_Moves)
	ld a, BANK(xBite)
	ld [hli], a
	ld a, LOW(xBite)
	ld [hli], a
	ld a, HIGH(xBite)
	ld [hli], a

	lb bc, BANK(xAris), 5
	ld de, xAris
	ld h, HIGH(wEntity1)
	call SpawnEntity
	ld l, LOW(wEntity0_Moves)
	ld a, BANK(xBite)
	ld [hli], a
	ld a, LOW(xBite)
	ld [hli], a
	ld a, HIGH(xBite)
	ld [hli], a

	ld a, 1
	ld [wDungeonCurrentFloor], a
	; Draw debug map
	call DungeonGenerateFloor
; Re-initializes some aspects of the dungeon, such as rendering the map.
; @clobbers: bank
SwitchToDungeonState::
	ld a, GAMESTATE_DUNGEON
	ld [wGameState], a
	xor a, a
	ld [wIsDungeonFading], a

	call InitUI

	ld h, HIGH(wEntity0)
.loop
	ld l, LOW(wEntity0_Bank)
	ld a, [hli]
	and a, a
	call nz, LoadEntityGraphics
.next
	inc h
	ld a, h
	cp a, HIGH(wEntity0) + NB_ENTITIES
	jp nz, .loop

	; Load the active dungeon.
	ld hl, wActiveDungeon
	ld a, [hli]
	rst SwapBank
	; Deref pointer
	ld a, [hli]
	ld h, [hl]
	ld l, a
	push hl
		; Deref tileset
		ASSERT Dungeon_Tileset == 0
		ld a, [hli]
		ld h, [hl]
		ld l, a
		ld bc, 20 * 16
		ld de, $8000 + BLANK_METATILE_ID * 16
		call VRAMCopy
	pop hl

	ld a, 20
	ld [wFadeSteps], a
	ld a, $80 + 20 * 4
	ld [wFadeAmount], a
	ld a, -4
	ld [wFadeDelta], a

	; Deref palette if on CGB
	ldh a, [hSystem]
	and a, a
	jp z, .skipCGB
		; Set palettes
		ld a, %11111111
		ld [wBGPaletteMask], a
		ld a, %11111111
		ld [wOBJPaletteMask], a

		ASSERT Dungeon_Palette == 2
		inc hl
		inc hl
		ld a, [hli]
		ld h, [hl]
		ld l, a

		push hl
		ld c, 3
		ld de, wBGPaletteBuffer + 3 * 12
		call MemCopySmall
		pop hl

		push hl
		ld c, 3
		ld de, wBGPaletteBuffer + 4 * 12
		call MemCopySmall
		pop hl

		push hl
		ld c, 3
		ld de, wBGPaletteBuffer + 5 * 12
		call MemCopySmall
		pop hl

		push hl
		ld c, 3
		ld de, wBGPaletteBuffer + 6 * 12
		call MemCopySmall
		pop hl

		; Load first 3 palettes
		ld c, 3 * 12
		ld de, wBGPaletteBuffer
		call MemCopySmall

		ld hl, wActiveDungeon + 1
		ld a, [hli]
		ld h, [hl]
		ld l, a
		inc hl
		inc hl
		inc hl
		inc hl
		ASSERT Dungeon_Items == 4
		; Push each item onto the stack :)
		ld b, DUNGEON_ITEM_COUNT
	.pushItems
		ld a, [hli]
		push af
		ld a, [hli]
		ld e, a
		ld a, [hli]
		ld d, a
		push de
		dec b
		jr nz, .pushItems

	.color
		; Now pop each in order and load their palettes and graphics
		ld b, DUNGEON_ITEM_COUNT
		ld de, wBGPaletteBuffer + 6 * 12 + 3
	.copyItemColor
		pop hl
		pop af
		rst SwapBank
		ASSERT Item_Palette == 0
		ld a, [hli]
		ld h, [hl]
		ld l, a
		ld c, 9
		call MemCopySmall
		ld a, e
		sub a, 21
		ld e, a
		ld a, d
		sbc a, 0
		ld d, a
		dec b
		jr nz, .copyItemColor
.skipCGB
	ld hl, wActiveDungeon
	ld a, [hli]
	rst SwapBank
	ld a, [hli]
	ld h, [hl]
	ld l, a
	inc hl
	inc hl
	inc hl
	inc hl
	ASSERT Dungeon_Items == 4
	; Push each item onto the stack :)
	ld b, DUNGEON_ITEM_COUNT
.pushItems2
	ld a, [hli]
	push af
	ld a, [hli]
	ld e, a
	ld a, [hli]
	ld d, a
	push de
	dec b
	jr nz, .pushItems2

.items
	; And finally, copy the graphics
	ld b, DUNGEON_ITEM_COUNT
	ld de, $8000 + (ITEM_METATILE_ID + 3 * 4) * 16
.copyItemGfx
	pop hl
	pop af
	rst SwapBank
	inc hl
	inc hl
	ASSERT Item_Graphics == 2
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ld c, 16 * 4
	call VRAMCopySmall
	ld a, e
	sub a, 128
	ld e, a
	ld a, d
	sbc a, 0
	ld d, a
	dec b
	jr nz, .copyItemGfx

	; Initialize previous health
	ld hl, wPreviousHealth
	ld de, wEntity0_Bank
	ld a, [de]
	and a, a
	jr z, :+
	ld e, LOW(wEntity0_Health)
	ld a, [de]
	inc e
	ld [hli], a
	ld a, [de]
	ld [hli], a
:
	ld de, wEntity1_Bank
	ld a, [de]
	and a, a
	jr z, :+
	ld e, LOW(wEntity0_Health)
	ld a, [de]
	inc e
	ld [hli], a
	ld a, [de]
	ld [hli], a
:
	ld a, BANK(xFocusCamera)
	rst SwapBank
	call xFocusCamera
	ld a, [wDungeonCameraX + 1]
	ld [wLastDungeonCameraX], a
	ld a, [wDungeonCameraY + 1]
	ld [wLastDungeonCameraY], a
	ld a, BANK(xUpdateScroll)
	rst SwapBank
	call xUpdateScroll
	ld a, BANK(xDrawDungeon)
	rst SwapBank
	jp xDrawDungeon

SECTION "Dungeon State", ROM0
DungeonState::
	; If fading out, do nothing but animate entities and wait for the fade to
	; complete.
	ld a, [wIsDungeonFading]
	and a, a
	jr z, .notFading
	ld a, [wFadeSteps]
	and a, a
	jr nz, .dungeonRendering
		ld hl, wDungeonFadeCallback
		ld a, [hli]
		ld h, [hl]
		ld l, a
		jp hl
.notFading
	ld hl, wEntityAnimation.pointer
	ld a, [hli]
	or a, [hl]
	jr nz, .playAnimation
		bankcall xMoveEntities
		call ProcessEntities
		jr :+
.playAnimation
		bankcall xUpdateAnimation
:

.dungeonRendering
	; Scroll the map after moving entities.
	bankcall xHandleMapScroll
	bankcall xFocusCamera
	bankcall xUpdateScroll

	; Render entities after scrolling.
	bankcall xRenderEntities
	call UpdateEntityGraphics

	ld a, [wPrintString]
	and a, a
	call nz, DrawPrintString

	ld hl, wPreviousHealth
	ld de, wEntity0_Bank
	ld a, [de]
	and a, a
	jr z, :+
	ld e, LOW(wEntity0_Health)
	ld a, [de]
	inc e
	cp a, [hl]
	jr nz, .updateStatus
	inc hl
	ld a, [de]
	inc e
	cp a, [hl]
	jr nz, .updateStatus
	inc hl
:
	ld de, wEntity1_Bank
	ld a, [de]
	and a, a
	jr z, .skipUpdateStatus
	ld e, LOW(wEntity0_Health)
	ld a, [de]
	inc e
	cp a, [hl]
	jr nz, .updateStatus
	inc hl
	ld a, [de]
	cp a, [hl]
	jr z, .skipUpdateStatus
.updateStatus
	call DrawStatusBar
	; Update health cache
	ld hl, wPreviousHealth
	ld de, wEntity0_Bank
	ld a, [de]
	and a, a
	jr z, :+
	ld e, LOW(wEntity0_Health)
	ld a, [de]
	inc e
	ld [hli], a
	ld a, [de]
	ld [hli], a
:
	ld de, wEntity1_Bank
	ld a, [de]
	and a, a
	jr z, :+
	ld e, LOW(wEntity0_Health)
	ld a, [de]
	inc e
	ld [hli], a
	ld a, [de]
	ld [hli], a
:
.skipUpdateStatus

	jp UpdateAttackWindow

OpenPauseMenu::
	ld b, BANK(xPauseMenu)
	ld de, xPauseMenu
	call AddMenu
	ld a, GAMESTATE_MENU
	ld [wGameState], a
	xor a, a
	ld [wSTATTarget], a
	ld [wSTATTarget + 1], a
	ret

SECTION "Get Item", ROM0
; Get a dungeon item given an index in b
; @param b: Item ID
; @return b: Item bank
; @return hl: Item pointer
; @clobbers bank
GetDungeonItem::
	ld hl, wActiveDungeon
	ld a, [hli]
	rst SwapBank
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ASSERT Dungeon_Items == 4
	inc hl
	inc hl
	inc hl
	inc hl
	ld a, b
	add a, b
	add a, b
	add a, l
	ld l, a
	adc a, h
	sub a, l
	ld h, a
	ld a, [hli]
	ld b, a
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ret

SECTION "Focus Camera", ROMX
xFocusCamera::
	ld bc, wEntity0_SpriteY
	ld a, [bc]
	inc c
	ld l, a
	ld a, [bc]
	inc c
	ld h, a
	ld de, (SCRN_Y - 32) / -2 << 4
	add hl, de
	bit 7, h
	jr nz, :+
	ld a, h
	cp a, 64 - 9
	jr nc, :+
	ld a, l
	ld [wDungeonCameraY], a
	ld a, h
	ld [wDungeonCameraY + 1], a
:   ld a, [bc]
	inc c
	ld l, a
	ld a, [bc]
	inc c
	ld h, a
	ld de, (SCRN_X - 24) / -2 << 4
	add hl, de
	bit 7, h
	ret nz
	ld a, h
	cp a, 64 - 10
	ret nc
	ld a, l
	ld [wDungeonCameraX], a
	ld a, h
	ld [wDungeonCameraX + 1], a
	ret

SECTION "Generate Floor", ROM0
; Generate a new floor
; @clobbers bank
DungeonGenerateFloor::
	ld a, TILE_WALL
	ld bc, DUNGEON_WIDTH * DUNGEON_HEIGHT
	ld hl, wDungeonMap
	call MemSet
	ld hl, wEntity{d:NB_ALLIES}
	xor a, a
	ld b, NB_ENEMIES
.clearEnemies
	ld [hl], a
	inc h
	dec b
	jr nz, .clearEnemies

	ld hl, wActiveDungeon
	ld a, [hli]
	rst SwapBank
	ld a, [hli]
	add a, Dungeon_GenerationType
	ld h, [hl]
	ld l, a
	adc a, h
	sub a, l
	ld h, a
	ld a, [hl]
	ld b, a
	add a, b
	add a, b
	add a, LOW(.jumpTable)
	ld l, a
	adc a, HIGH(.jumpTable)
	sub a, l
	ld h, a
	ld a, [hli]
	rst SwapBank
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ld de, wScriptPool
	call ExecuteScript
	ld hl, wActiveDungeon
	ld a, [hli]
	rst SwapBank
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ld bc, Dungeon_ItemsPerFloor
	add hl, bc
	ld b, [hl]

.generateItem
	ld a, BANK(xGenerateItems)
	rst SwapBank
	ld hl, xGenerateItems
	push bc
		call ExecuteScript
	pop bc
	dec b
	jr nz, .generateItem
	ld a, NB_ENEMIES
.spawnEnemies
	push af
	call SpawnEnemy
	pop af
	dec a
	jr nz, .spawnEnemies
	ret

.jumpTable
	ASSERT DUNGEON_TYPE_SCRAPER == 0
	farptr xGenerateScraper
	ASSERT DUNGEON_TYPE_HALLS == 1
	farptr xGenerateHalls

SECTION "Update Scroll", ROMX
xUpdateScroll:
	ld a, [wDungeonCameraX + 1]
	ld b, a
	ld a, [wDungeonCameraX]
	REPT 4
		srl b
		rra
	ENDR
	ldh [hShadowSCX], a
	ld a, [wDungeonCameraY + 1]
	ld b, a
	ld a, [wDungeonCameraY]
	REPT 4
		srl b
		rra
	ENDR
	ldh [hShadowSCY], a
	ret

SECTION "Draw dungeon", ROMX
xDrawDungeon::
	call xGetCurrentVram
	push hl
	; Now find the top-left corner of the map to begin drawing from.
	call xGetCurrentMap
	pop hl

	; Now copy the Dungeon map into VRAM
	; Initialize counters.
	ld a, 10
	ldh [hMapDrawY], a
.drawRow
	ld a, 11
	ld [hMapDrawX], a
	push hl
.drawTile
		push hl
			call xDrawTile
		pop hl
		ld c, 2
		call xVramWrapRight
		ld a, [hMapDrawX]
		dec a
		ld [hMapDrawX], a
		jr nz, .drawTile
	pop hl
	; Go to the next line of the map.
	ld a, 64 - 11
	add a, e
	ld e, a
	adc a, d
	sub a, e
	ld d, a
	ld a, 2 * 32
	call xVramWrapDown
	ld a, [hMapDrawY]
	dec a
	ld [hMapDrawY], a
	jr nz, .drawRow
	ret

xHandleMapScroll:
	ld a, [wDungeonCameraX + 1]
	ld hl, wLastDungeonCameraX
	cp a, [hl]
	jr z, .checkY
	ld [hl], a
	jr nc, .drawRight
	; Draw a column on the left side
	call xGetCurrentVram
	push hl
	call xGetCurrentMap
	pop hl
	jr .drawColumn
.drawRight
	call xGetCurrentVram
	ld c, 20
	call xVramWrapRight
	push hl
	call xGetCurrentMap
	pop hl
	ld a, 10
	add a, e
	ld e, a
	adc a, d
	sub a, e
	ld d, a
.drawColumn
	ld a, 10
	ldh [hMapDrawY], a
.drawColumnLoop
	push hl
	call xDrawTile
	; While xDrawTile usually increments DE for horizontal drawing, we need to
	; add an offset to move vertically.
	ld a, 63
	add a, e
	ld e, a
	adc a, d
	sub a, e
	ld d, a
	pop hl
	ld a, $40
	call xVramWrapDown
	ld a, [hMapDrawY]
	dec a
	ld [hMapDrawY], a
	jr nz, .drawColumnLoop
	ret
.checkY
	ld a, [wDungeonCameraY + 1]
	ASSERT wLastDungeonCameraX + 1 == wLastDungeonCameraY
	inc hl
	cp a, [hl]
	ret z
	ld [hl], a
	jr nc, .drawDown
	; Draw a column on the left side
	call xGetCurrentVram
	push hl
	call xGetCurrentMap
	pop hl
	jr .drawRow
.drawDown
	call xGetCurrentVram
	ld bc, $20 * 18
	add hl, bc
	ld a, h
	; If the address is still below $9C00, we do not yet need to wrap.
	cp a, $9C
	jr c, :+
	; Otherwise, wrap the address around to the top.
	sub a, $9C - $98
	ld h, a
:   push hl
	ld a, [wDungeonCameraX + 1]
	ld b, a
	ld a, [wDungeonCameraY + 1]
	add a, 9
	ld c, a
	call xGetMapPosition
	pop hl
.drawRow
	ld a, 11
	ldh [hMapDrawY], a
.drawRowLoop
	push hl
	call xDrawTile
	pop hl
	ld c, 2
	call xVramWrapRight
	ld a, [hMapDrawY]
	dec a
	ld [hMapDrawY], a
	jr nz, .drawRowLoop
	ret

; Get the current tilemap address according to the camera positions.
; @clobbers all
xGetCurrentVram:
	; Calculate the VRAM destination by (Camera >> 4) / 16 % 16 * 32
	ld a, [wDungeonCameraY + 1]
	and a, %00001111
	ld e, 0
	srl a
	rr e
	rra
	rr e
	ld d, a
	; hl = (Camera >> 8) & 15 << 4
	ld hl, $9800
	add hl, de ; Add to VRAM
	ld a, [wDungeonCameraX + 1]
	and a, %00001111
	add a, a
	; Now we have the neccessary X index on the tilemap.
	add a, l
	ld l, a
	adc a, h
	sub a, l
	ld h, a
	ret

; @return de: Current map postion
; @clobbers: all
xGetCurrentMap:
	ld a, [wDungeonCameraX + 1]
	ld b, a
	ld a, [wDungeonCameraY + 1]
	ld c, a
; @param b: X position
; @param c: Y position
; @return de: Current map postion
; @clobbers: a, hl
; @preserves: bc
xGetMapPosition::
	; Begin with Y
	ld a, c
	ld l, a
	ld h, 0
	ld de, wDungeonMap
	add hl, hl ; Camera Y * 2
	add hl, hl ; Camera Y * 4
	add hl, hl ; Camera Y * 8
	add hl, hl ; Camera Y * 16
	add hl, hl ; Camera Y * 32
	add hl, hl ; Camera Y * 64
	add hl, de ; wDungeonMap + CameraY * 64
	; Now X
	ld a, b
	; Use this add to move the value to de
	add a, l
	ld e, a
	adc a, h
	sub a, e
	ld d, a
	ret

; Draw a tile pointed to by HL to VRAM at DE. The user is expected to reserve
; HL, but can rely on DE being incremented.
xDrawTile::
	ldh a, [hSystem]
	and a, a
	jr z, :+
	push hl
:
	ld a, [de]
	inc e
	cp a, 1
	jr z, .wall
	and a, a
	ld b, BLANK_METATILE_ID
	jr z, .drawSingle
	; Multiply index by 4 and then offset a bit to accomodate the wall tiles.
	add a, a
	add a, a
	add a, BLANK_METATILE_ID + 8
	ld b, a
.drawSingle
:   ld a, [rSTAT]
	and a, STATF_BUSY
	jr nz, :-
	; After a STAT check, we have 17.75 safe cycles. The following code takes
	; 17 to write a metatile.
	ld a, b
	ld [hli], a
	inc a
	ld [hli], a
	inc a
	ld bc, $20 - 2
	add hl, bc
	ld b, a
:   ld a, [rSTAT]
	and a, STATF_BUSY
	jr nz, :-
	ld a, b
	ld [hli], a
	inc a
	ld [hli], a
	jr .exit

.wall
	; Wall tiles are given special handling.
	dec e ; Tempoarirly undo the previous inc e
	push de
		call xGetMapAbove
	pop de
	cp a, TILE_WALL
	ld b, 0
	jr nz, :+
	ld b, %10
:
	push de
		call xGetMapBelow
	pop de
	inc e
	cp a, TILE_WALL
	ld a, 0
	jr nz, :+
	ld a, 1
:
	or a, b
	; a = %11 where %10 is a tile above and %01 is a tile below.
	; If a is 0, however, this is a static, standalone tile.
	ld b, STANDALONE_METATILE_ID
	jr z, .drawSingle
	ld b, a
	; Now it's time to draw both halves.
	; Start with the top.
:   ld a, [rSTAT]
	and a, STATF_BUSY
	jr nz, :-
	; The following snippet takes at most 13/17 cycles.
	ld a, TERMINAL_METATILE_ID
	; If above us is a tile, switch from TERMINAL to FULL
	bit 1, b
	jr z, :+
	ld a, FULL_METATILE_ID
:   ld [hli], a
	inc a
	ld [hli], a
	; Jump to next row
	ld a, b ; make sure to reserve b
	ld bc, $20 - 2
	add hl, bc
	ld b, a
	; Now draw the bottom.
:   ld a, [rSTAT]
	and a, STATF_BUSY
	jr nz, :-
	; The following snippet takes at most 13/17 cycles.
	ld a, TERMINAL_METATILE_ID + 2
	; If below us is a tile, switch from TERMINAL to FULL
	bit 0, b
	jr z, :+
	ld a, FULL_METATILE_ID + 2
:   ld [hli], a
	inc a
	ld [hli], a
.exit
	ldh a, [hSystem]
	and a, a
	ret z
	; If on CGB, repeat for colors.
	pop hl
	; Switch bank
	ld a, 1
	ldh [rVBK], a
	ld bc, $20 - 2
	; Wait for VRAM.
	; On the CGB, we have twice as much time.
:
	ldh a, [rSTAT]
	and a, STATF_BUSY
	jr nz, :-

	dec e
	ld a, [de]
	inc e
	ld [hli], a
	ld [hli], a
	add hl, bc
	ld [hli], a
	ld [hli], a
	xor a, a
	ldh [rVBK], a
	ret

; Move the VRAM pointer to the right by 16 pixels, wrapping around to the left
; if needed.
; @param  c: Amount to add.
; @param hl: VRAM pointer
; @clobbers: a, b
xVramWrapRight:
	ld a, l
	and a, %11100000 ; Grab the upper bits, which should stay constant.
	ld b, a
	ld a, l
	add a, c
	and a, %00011111
	or a, b
	ld l, a
	ret

; Move the VRAM pointer down by 16 pixels, wrapping around to the top if needed.
; @param  a: Amount to add.
; @param hl: VRAM pointer
; @clobbers: a
xVramWrapDown:
	add a, l
	ld l, a
	adc a, h
	sub a, l
	ld h, a
	; If the address is still below $9C00, we do not yet need to wrap.
	cp a, $9C
	ret c
	; Otherwise, wrap the address around to the top.
	ld h, $98
	ret

xGetMapAbove:
	ld a, e
	sub a, 64
	ld e, a
	jr nc, :+
	dec d
:   ld a, d
	ASSERT LOW(wDungeonMap) == 0
	cp a, HIGH(wDungeonMap)
	jr c, .forceTrue
	ld a, [de]
	ret
.forceTrue
	ld a, 1
	ret

xGetMapBelow:
	ld a, e
	add a, 64
	ld e, a
	adc a, d
	sub a, e
	ld d, a
	ASSERT LOW(wDungeonMap + 64 * 64) == 0
	cp a, HIGH(wDungeonMap + 64 * 64)
	jr nc, .forceTrue
	ld a, [de]
	ret
.forceTrue
	ld a, 1
	ret

SECTION UNION "State variables", WRAM0, ALIGN[8]
; This map uses 4096 bytes of WRAM, but is only ever used in dungeons.
; If more RAM is needed for other game states, it should be unionized with this
; map.
wDungeonMap:: ds DUNGEON_WIDTH * DUNGEON_HEIGHT
wDungeonCameraX:: dw
wDungeonCameraY:: dw
; Only the neccessarily info is saved; the high byte.
wLastDungeonCameraX: db
wLastDungeonCameraY: db
; A far pointer to the current dungeon. Bank, Low, High.
wActiveDungeon:: ds 3
wIsDungeonFading:: db
wDungeonCurrentFloor:: db

wMapgenLoopCounter: db

wDungeonFadeCallback:: dw

wPreviousHealth::
.player dw
.partner dw

SECTION "Map drawing counters", HRAM
hMapDrawX: db
hMapDrawY: db
