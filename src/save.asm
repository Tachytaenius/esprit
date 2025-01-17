include "config.inc"
include "defines.inc"
include "entity.inc"
include "hardware.inc"
include "item.inc"

; Since the size of the Saved section can't be known until link time,
; the space allocated in SRAM must be hard-coded.
; This also means that (so long as this value doesn't change) save files will always be located at the same address.
def SAVE_VERSION = 0
def SAVE_FILE_SIZE = $1000
def SAVE_VERIFICATION_STRING equs "This is an Esprit save file. Do not edit this string.\n"
def SAVE_VERIFICATION_STRING_LEN = strlen("{SAVE_VERIFICATION_STRING}")

section "Get Flag", rom0
; @param c: flag id
; @return a: flag mask
; @return hl: flag pointer
; @clobbers b
GetFlag::
	ld a, c
	and a, 7 ; Get only the bits in A
	call GetBitA
	srl c
	srl c
	srl c
	ld b, 0
	ld hl, wFlags
	add hl, bc
	ret

; Ideally this would be a section fragment, but we want control over the ordering of anything in the save file.
; This is important if any changes to the format are made.
; Instead, a section union is used so that new versions can reorder the section while update code is still aware of the old addresses.
section union "Save Version 0", wram0
wFile:
; This area contains a working copy of the currently loaded save file.
; When the player saves/loads, all variables in this section are copied to/from SRAM.

; Verifies that a valid save file is present.
wVerificationString: ds SAVE_VERIFICATION_STRING_LEN
; If the save file is out of date, update code will run in succession to bootstrap the file up to the current version.
wVersion: db
wFlags:: ds 256 / 8
; Where on the map the player is standing.
wActiveMapNode:: ds 3
; What side of a scene the player should start out on.
wMapLastDirectionMoved:: db
	dstruct EntityBase, wPlayerData
	dstruct EntityBase, wPartnerData
wInventory::
	ds 3 * INVENTORY_SIZE
.end::

wActiveMenuPalette:: ds 3
wActiveMenuTheme:: ds 3

wQuicksave::
.isPresent:: db
.floorSeed:: dl
.floor:: db
.dungeon:: farptr
.player:: ds sizeof_Entity
.partner:: ds sizeof_Entity
.end

wFile_end:

; Hard-code the save file to be at a constant address so that it doesn't move between versions.
section "Save File", sram[$A000]
sFile: ds wFile_end - wFile

section "Save File Functions", rom0
; Verifies that the currently loaded save file is valid.
; @return z if value, nz if not.
xVerifySaveFile::
	ld hl, xInitialFile.verificationString
	ld de, wVerificationString
	ld c, SAVE_VERIFICATION_STRING_LEN
.strcmp
	ld a, [de]
	cp a, [hl]
	ret nz ; Fail
	dec c
	ret z ; Pass
	inc de
	inc hl
	jr .strcmp

; Re-initializes the save file.
xInitializeSaveFile::
	ld de, wFile
	ld hl, xInitialFile
	ld bc, sizeof("Save Version {d:SAVE_VERSION}")
	jp MemCopy

; Write the save file to SRAM.
; This is executed each time the world map is entered.
xCommitQuicksave::
	db LD_A_PREFIX
xCommitSaveFile::
	xor a, a
	ld [wQuicksave.isPresent], a

	ld de, sFile
	ld hl, wFile
.skip
	ld bc, sizeof("Save Version {d:SAVE_VERSION}")

	;di
	;ld a, CART_SRAM_ENABLE
	;ld [rRAMG], a

	call MemCopy

	;xor a, a
	;ld [rRAMG], a
	;reti
	ret

xLoadSaveFile::
	ld de, wFile
	ld hl, sFile
	call xCommitSaveFile.skip

	ld a, [wVersion]
	ld b, a
	ld a, SAVE_VERSION
	cp a, b
	ret z
	jr nc, :+
		; If the ROM is out of date, invalidate the save file.
		xor a, a
		ld [wVerificationString], a
		ret
	:
	todo

xInitialFile:
.verificationString db "{SAVE_VERIFICATION_STRING}"
.version db SAVE_VERSION
.flags
	for i, 256 / 8
		db FLAG_VALUE_{d:i}
	endr
.activeMapNode farptr FIRST_NODE
.mapLastDirectionMoved db LEFT
.playerData
	farptr xLuvui
	db INIT_LEVEL
	dw 0
	db 0
.partnerData
	farptr xAris
	db INIT_LEVEL + 1
	dw 0
	db 0
.inventory
	; Fill the inventory with default items
	; if a comma is present anywhere, this is a list.
	if strin("{INIT_INVENTORY}", ",")
		if strsub("{INIT_INVENTORY}", strlen("{INIT_INVENTORY}")) != ","
			redef INIT_INVENTORY equs "{INIT_INVENTORY},"
		endc
		for idx, 8
			if !strin("{INIT_INVENTORY}", ",")
				break
			endc
			def item equs strsub("{INIT_INVENTORY}", 1, strin("{INIT_INVENTORY}", ",") - 1)
			db bank(item)
			dw item
			purge item
			redef INIT_INVENTORY equs strsub("{INIT_INVENTORY}", strin("{INIT_INVENTORY}", ",") + 1)
		endr
		rept 8 - idx
			db bank(null)
			dw null
		endr
	; otherwise, it's a fill.
	else
		rept INVENTORY_SIZE
			db bank(INIT_INVENTORY)
			dw INIT_INVENTORY
		endr
	endc
.menuPalette farptr PinkMenuPalette
.menuTheme farptr PawprintMenuTheme

.quicksave ds wQuicksave.end - wQuicksave, 0
assert sizeof("Save Version {d:SAVE_VERSION}") == @ - xInitialFile
