;;;=========================================================================;;;
;;; Copyright 2022 Matthew D. Steele <mdsteele@alum.mit.edu>                ;;;
;;;                                                                         ;;;
;;; This file is part of Annalog.                                           ;;;
;;;                                                                         ;;;
;;; Annalog is free software: you can redistribute it and/or modify it      ;;;
;;; under the terms of the GNU General Public License as published by the   ;;;
;;; Free Software Foundation, either version 3 of the License, or (at your  ;;;
;;; option) any later version.                                              ;;;
;;;                                                                         ;;;
;;; Annalog is distributed in the hope that it will be useful, but WITHOUT  ;;;
;;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or   ;;;
;;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License   ;;;
;;; for more details.                                                       ;;;
;;;                                                                         ;;;
;;; You should have received a copy of the GNU General Public License along ;;;
;;; with Annalog.  If not, see <http://www.gnu.org/licenses/>.              ;;;
;;;=========================================================================;;;

.INCLUDE "charmap.inc"
.INCLUDE "devices/flower.inc"
.INCLUDE "flag.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "minimap.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "window.inc"

.IMPORT DataA_Pause_AreaCells_u8_arr2_arr_ptr_0_arr
.IMPORT DataA_Pause_AreaCells_u8_arr2_arr_ptr_1_arr
.IMPORT DataA_Pause_AreaNames_u8_arr_ptr_0_arr
.IMPORT DataA_Pause_AreaNames_u8_arr_ptr_1_arr
.IMPORT DataA_Pause_Minimap_sMarker_arr
.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT Func_ClearRestOfOam
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_CountDeliveredFlowers
.IMPORT Func_FadeInFromBlack
.IMPORT Func_FadeOutToBlack
.IMPORT Func_FillUpperAttributeTable
.IMPORT Func_IsFlagSet
.IMPORT Func_Window_Disable
.IMPORT Main_Explore_FadeIn
.IMPORT Ppu_ChrBgMinimap
.IMPORT Ppu_ChrBgPause
.IMPORT Ppu_ChrObjPause
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Sram_Minimap_u16_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_CameraMinimapCol_u8
.IMPORTZP Zp_CameraMinimapRow_u8
.IMPORTZP Zp_Chr0cBank_u8
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask

;;;=========================================================================;;;

;;; The BG tile ID for an unexplored tile on the minimap.
kTileIdBgMinimapUnexplored = $80

;;; The BG tile ID for the bottom-left tile for all upgrade symbols.  Add 1 to
;;; this to get the the bottom-right tile ID for those symbols.
kTileIdBgUpgradeBottomLeft = $c0
;;; The BG tile ID for the top-left tile of the symbol for RAM upgrades.  Add 1
;;; to this to get the the top-right tile ID for that symbol.
kTileIdBgRamTopLeft        = $c2
;;; The BG tile ID for the top-left tile for the symbol of the first non-RAM
;;; upgrade.  Add 1 to this to get the the top-right tile ID for that symbol,
;;; then add another 1 to get the top-left tile ID for the next upgrade, and so
;;; on.
kTileIdBgRemainingTopLeft  = $c4

;;; The screen pixel positions for the top and left edges of the minimap rect.
kMinimapTopPx  = $28
kMinimapLeftPx = $20

;;; The OBJ tile ID for marking the current area on the minimap.
kTileIdObjMinimapCurrentArea = $02

;;; The OBJ palette numbers for marking the current area and blinking the
;;; current screen on the minimap.
kPaletteObjMinimapCurrentArea   = 0
kPaletteObjMinimapCurrentScreen = 1

;;;=========================================================================;;;

.ZEROPAGE

;;; The current byte offset into DataA_Pause_Minimap_sMarker_arr.
Zp_MinimapMarkerOffset_u8: .res 1

;;; Bit N of this is set if breaker number N (starting at 0) is activated.
.ASSERT kNumBreakerFlags <= 8, error
Zp_ActivatedBreakers_byte: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for when the game is paused.
;;; @prereq Rendering is disabled.
.EXPORT Main_Pause
.PROC Main_Pause
    chr08_bank #<.bank(Ppu_ChrBgMinimap)
    lda #<.bank(Ppu_ChrBgPause)
    sta Zp_Chr0cBank_u8
    chr18_bank #<.bank(Ppu_ChrObjPause)
    jsr_prga FuncA_Pause_Init
_GameLoop:
    jsr_prga FuncA_Pause_DrawObjects
    jsr Func_ClearRestOfOamAndProcessFrame
_CheckForUnause:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start | bJoypad::BButton | bJoypad::AButton
    beq _GameLoop
    jsr Func_FadeOutToBlack
    jmp Main_Explore_FadeIn
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Pause"

;;; The tile ID grid for the minimap (stored in row-major order).
.PROC DataA_Pause_Minimap_u8_arr
:   .incbin "out/data/minimap.map"
    .assert * - :- = kMinimapWidth * kMinimapHeight, error
.ENDPROC

;;; The "Current area:" label that is drawn on the pause screen, along with
;;; some of the surrounding tiles.
.PROC DataA_Pause_CurrentAreaLabel_u8_arr
Start:
    .byte kTileIdBgWindowTopRight, ' '
LineStart:
    .byte ' ', kTileIdBgWindowVert
    .byte " Current area: "
kAreaNameStartCol = * - LineStart
kSize = * - Start
.ENDPROC

;;; The screen tile column that the area name begins on.
kAreaNameStartCol = DataA_Pause_CurrentAreaLabel_u8_arr::kAreaNameStartCol

;;; Initializes pause mode, then fades in the screen.
;;; @prereq Rendering is disabled.
.PROC FuncA_Pause_Init
    ;; Reset the frame counter before drawing any objects so that the
    ;; current-position blink will be in a consistent state as we fade in.
    lda #0
    sta Zp_FrameCounter_u8
_InitActivatedBreakers:
    lda #0
    sta Zp_ActivatedBreakers_byte
    ldx #kLastBreakerFlag
    @loop:
    jsr Func_IsFlagSet  ; preserves X, clears Z if flag is set
    clc
    beq @notActivated
    sec
    @notActivated:
    rol Zp_ActivatedBreakers_byte
    dex
    cpx #kFirstBreakerFlag
    bge @loop
_DrawScreen:
    ldy #$00  ; param: fill byte
    jsr Func_FillUpperAttributeTable
    jsr Func_Window_Disable
    jsr FuncA_Pause_DirectDrawBg
    jsr FuncA_Pause_DrawObjects
    jsr Func_ClearRestOfOam
_FadeIn:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    jmp Func_FadeInFromBlack
.ENDPROC

;;; Directly fills PPU nametable 0 with BG tile data for the pause screen.
;;; @prereq Rendering is disabled.
.PROC FuncA_Pause_DirectDrawBg
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldax #Ppu_Nametable0_sName + sName::Tiles_u8_arr
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
_ClearTopRows:
    lda #' '
    ldx #kScreenWidthTiles * 2 + 1
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
_DrawTopBorder:
    lda #kTileIdBgWindowTopLeft
    sta Hw_PpuData_rw
    lda #kTileIdBgWindowHorz
    ldx #kScreenWidthTiles - 4
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
_DrawCurrentAreaLabel:
    ldx #0
    @loop:
    lda DataA_Pause_CurrentAreaLabel_u8_arr, x
    sta Hw_PpuData_rw
    inx
    cpx #DataA_Pause_CurrentAreaLabel_u8_arr::kSize
    blt @loop
_DrawCurrentAreaName:
    ;; Copy the current room's AreaName_u8_arr_ptr into T1T0.
    lda <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    and #bRoom::AreaMask
    tay  ; eArea value
    lda DataA_Pause_AreaNames_u8_arr_ptr_0_arr, y
    sta T0
    lda DataA_Pause_AreaNames_u8_arr_ptr_1_arr, y
    sta T1
    ;; Draw the room's area name.
    ldy #0
    beq @start  ; unconditional
    @loop:
    sta Hw_PpuData_rw
    iny
    @start:
    lda (T1T0), y
    bpl @loop
    @break:
_FinishCurrentAreaLine:
    lda #' '
    .assert ' ' = 0, error
    beq @start  ; unconditional
    @loop:
    sta Hw_PpuData_rw
    iny
    @start:
    cpy #kScreenWidthTiles - kAreaNameStartCol - 2
    blt @loop
_DrawMinimap:
    jsr _DrawBlankLine
    ldya #DataA_Pause_Minimap_u8_arr
    stya T1T0  ; param: start of minimap row data
    ldx #0
    stx Zp_MinimapMarkerOffset_u8
    @rowLoop:
    jsr _DrawLineBreak  ; preserves X and T0+
    jsr FuncA_Pause_DirectDrawMinimapLine  ; preserves X, advances T1T0
    inx
    cpx #kMinimapHeight
    bne @rowLoop
    jsr _DrawBlankLine
_DrawItems:
    ldx #0
    @rowLoop:
    jsr _DrawLineBreak  ; preserves X
    jsr FuncA_Pause_DirectDrawItemsLine  ; preserves X
    inx
    cpx #6
    bne @rowLoop
_DrawBottomBorder:
    lda #kTileIdBgWindowVert
    sta Hw_PpuData_rw
    lda #' '
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
    lda #kTileIdBgWindowBottomLeft
    sta Hw_PpuData_rw
    lda #kTileIdBgWindowHorz
    ldx #kScreenWidthTiles - 4
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
    lda #kTileIdBgWindowBottomRight
    sta Hw_PpuData_rw
_ClearBottomRows:
    lda #' '
    ldx #kScreenWidthTiles * 2 + 1
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
    rts
_DrawLineBreak:
    lda #kTileIdBgWindowVert
    ldy #' '
    sta Hw_PpuData_rw
    sty Hw_PpuData_rw
    sty Hw_PpuData_rw
    sta Hw_PpuData_rw
    rts
_DrawBlankLine:
    jsr _DrawLineBreak
    lda #' '
    ldy #kScreenWidthTiles - 4
    @colLoop:
    sta Hw_PpuData_rw
    dey
    bne @colLoop
    rts
.ENDPROC

;;; Writes BG tile data for one line of the pause screen minimap (not including
;;; the borders, but including the margin on either side between the border and
;;; the minimap) directly to the PPU.
;;; @prereq Rendering is disabled.
;;; @param T1T0 The start of the minimap tile data row.
;;; @param X The minimap row (0-15).
;;; @return T1T0 The start of the next minimap tile data row.
;;; @preserve X
.PROC FuncA_Pause_DirectDrawMinimapLine
    ;; Draw left margin.
    lda #' '
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
    ;; Determine the bitmask we should use for this minimap row, and store it
    ;; in T2.
    txa  ; minimap row
    and #$07
    tay
    lda Data_PowersOfTwo_u8_arr8, y
    sta T2  ; mask
    ;; Save X in T3 so we can use X for something else and later restore it.
    stx T3  ; minimap row
    ;; We'll use X as the byte index into Sram_Minimap_u16_arr.  If we're in
    ;; the first eight rows, we'll be checking our bitmask against the low
    ;; eight bits of each u16; otherwise, we'll be checking against the high
    ;; eight bits.
    txa  ; minimap row
    ldx #0
    stx T4  ; byte index into minimap tile data (from pointer in T1T0)
    cmp #8
    blt @ready
    inx  ; now X is 1
    @ready:
_ColLoop:
    ;; Determine the "original" tile ID for this cell of the minimap (without
    ;; yet taking map markers into account), and store it in T5.
    lda Sram_Minimap_u16_arr, x
    and T2  ; mask
    bne @explored
    @unexplored:
    lda #kTileIdBgMinimapUnexplored
    .assert kTileIdBgMinimapUnexplored > 0, error
    bne @setOriginalTile  ; unconditional
    @explored:
    ldy T4  ; byte index into minimap tile data (from pointer in T1T0)
    lda (T1T0), y
    @setOriginalTile:
    sta T5  ; original minimap tile ID
_MarkerLoop:
    ;; Check the minimap row number for the next map marker.  If it is greater
    ;; than the current row, then we haven't reached that marker yet, so just
    ;; draw the original minimap tile.  If it's less than the current row, then
    ;; skip this marker and check the next one.
    ldy Zp_MinimapMarkerOffset_u8
    lda T3  ; minimap row
    cmp DataA_Pause_Minimap_sMarker_arr + sMarker::Row_u8, y
    blt _DrawOriginalTile
    bne @continue
    ;; Now do the same thing again, for the minimap column number this time.
    txa  ; byte index into Sram_Minimap_u16_arr
    div #2  ; now A is the minimap column number
    cmp DataA_Pause_Minimap_sMarker_arr + sMarker::Col_u8, y
    blt _DrawOriginalTile
    bne @continue
    ;; At this point, we need to save X so we can use it for Func_IsFlagSet and
    ;; then restore it later.
    stx T6  ; byte index into Sram_Minimap_u16_arr
    ;; If this map marker's "Not" flag is set, then skip this marker and check
    ;; the next one.
    ldx DataA_Pause_Minimap_sMarker_arr + sMarker::Not_eFlag, y  ; param: flag
    jsr Func_IsFlagSet  ; preserves T0+
    bne @restoreXAndContinue
    ;; Check this map marker's "If" flag; if it's zero, this is an item marker
    ;; (small dot), otherwise it's a quest marker (large dot).
    ldy Zp_MinimapMarkerOffset_u8
    ldx DataA_Pause_Minimap_sMarker_arr + sMarker::If_eFlag, y  ; param: flag
    beq @itemMarker
    ;; For a quest marker, we need to check if the "If" flag is set, and skip
    ;; the marker if not.  But if the flag is set, we can compute the new tile
    ;; ID to use and draw it.
    @questMarker:
    jsr Func_IsFlagSet  ; preserves T0+
    beq @restoreXAndContinue
    lda T5  ; original minimap tile ID
    sub #$80
    tay
    lda DataA_Pause_MinimapQuestMarkerTiles_u8_arr, y
    ldx T6  ; byte index into Sram_Minimap_u16_arr
    bpl _DrawTileA  ; unconditional
    ;; For item markers, we can just always draw the marker; if the original
    ;; tile ID for this minimap cell is unexplored, then that will just map
    ;; back to the unexplored tile.
    @itemMarker:
    lda T5  ; original minimap tile ID
    sub #$80
    tay
    lda DataA_Pause_MinimapItemMarkerTiles_u8_arr, y
    ldx T6  ; byte index into Sram_Minimap_u16_arr
    bpl _DrawTileA  ; unconditional
    ;; If we had to skip this marker, then increment the byte offset into the
    ;; marker table and check the next marker.
    @restoreXAndContinue:
    ldx T6  ; byte index into Sram_Minimap_u16_arr
    @continue:
    lda Zp_MinimapMarkerOffset_u8
    add #.sizeof(sMarker)
    sta Zp_MinimapMarkerOffset_u8
    bne _MarkerLoop  ; unconditional
_DrawOriginalTile:
    lda T5  ; original minimap tile ID
_DrawTileA:
    sta Hw_PpuData_rw
    inc T4  ; byte index into minimap tile data (from pointer in T1T0)
    ;; Increment byte index into Sram_Minimap_u16_arr.
    inx
    inx
    cpx #kMinimapWidth * 2
    blt _ColLoop
_Finish:
    ;; Advance T1T0 to point to the next minimap row.
    lda T0
    add T4  ; byte index into minimap tile data (from pointer in T1T0)
    sta T0
    lda T1
    adc #0
    sta T1
    ;; Restore X (since this function needs to preserve it).
    ldx T3  ; minimap row
    ;; Draw right margin.
    lda #' '
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
    rts
.ENDPROC

;;; Writes BG tile data for one line of the items section of the pause screen
;;; (not including the borders) directly to the PPU.
;;; @prereq Rendering is disabled.
;;; @param X The item line number (0-5).
;;; @preserve X
.PROC FuncA_Pause_DirectDrawItemsLine
    stx T0  ; line number (0-5)
    lda #' '
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
.PROC _DrawUpgrades
    ;; Calculate the eFlag value for the first upgrade on this line, and store
    ;; it in X.
    lda T0  ; line number (0-5)
    div #2
    sta T1  ; upgrade row (0-2)
    mul #4
    adc T1  ; upgrade row (0-2), carry flag is already zero
    .assert kFirstUpgradeFlag > 0, error
    adc #kFirstUpgradeFlag
    tax  ; first upgrade eFlag
    ;; Calculate the loop limit, and store it in T1.
    add #5
    sta T1  ; ending eFlag
    ;; Loop over each upgrade on this line.
    @loop:
    jsr Func_IsFlagSet  ; preserves X and T0+, sets Z if flag X is not set
    bne @drawUpgrade
    ;; The player doesn't have this upgrade yet, so draw some blank space.
    lda #' '
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
    .assert ' ' = 0, error
    beq @continue  ; unconditional
    @drawUpgrade:
    ;; The player does have this upgrade.  Determine the first tile ID to draw
    ;; for this line of this upgrade.
    lda T0  ; line number (0-5)
    and #$01
    beq @top
    @bottom:
    lda #kTileIdBgUpgradeBottomLeft
    .assert kTileIdBgUpgradeBottomLeft > 0, error
    bne @draw  ; unconditional
    @top:
    txa  ; upgrade eFlag
    sub #kLastRamUpgradeFlag + 1
    blt @isRamUpgrade
    mul #2
    add #kTileIdBgRemainingTopLeft
    bcc @draw  ; unconditional
    @isRamUpgrade:
    lda #kTileIdBgRamTopLeft
    @draw:
    ;; Draw the upgrade.
    sta Hw_PpuData_rw
    add #1
    sta Hw_PpuData_rw
    lda #' '
    sta Hw_PpuData_rw
    @continue:
    ;; Continue to the next upgrade on this line.
    inx  ; upgrade eFlag
    cpx T1  ; ending eFlag
    blt @loop
    ;; At this point, A is still set to ' '.
    sta Hw_PpuData_rw
.ENDPROC
.PROC _DrawCircuits
    lda T0  ; line number (0-5)
    mul #8
    tax
    ldy #8
    @loop:
    lda _CircuitBreakers_byte_arr8_arr6, x
    beq @drawTile
    and Zp_ActivatedBreakers_byte
    beq @drawA
    @drawTile:
    lda _CircuitTiles_u8_arr8_arr6, x
    @drawA:
    sta Hw_PpuData_rw
    inx
    dey
    bne @loop
    lda #' '
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
.ENDPROC
    ldx T0  ; restore X register (line number)
    rts
_CircuitTiles_u8_arr8_arr6:
    .byte "1", $e0, $00, $f0, $f6, $00, $e1, "6"
    .byte $00, $e2, $e8, $f1, $f7, $e8, $e3, $00
    .byte $00, $e4, $e8, $f2, $f8, $e8, $e5, $00
    .byte "2", $e6, $e4, $f3, $f9, $e5, $e7, "5"
    .byte $00, "3", $e6, $f4, $fa, $e7, "4", $00
    .byte $00, $00, $00, $f5, $fb, $00, $00, $00
_CircuitBreakers_byte_arr8_arr6:
    .byte $01, $00, $00, $00, $00, $00, $00, $20
    .byte $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00, $00, $00, $00
    .byte $02, $00, $00, $00, $00, $00, $00, $10
    .byte $00, $04, $00, $00, $00, $00, $08, $00
    .byte $00, $00, $00, $40, $40, $00, $00, $00
.ENDPROC

;;; Draws objects that should be drawn on the pause screen.
.PROC FuncA_Pause_DrawObjects
    jsr FuncA_Pause_DrawMinimapObjects
    jsr FuncA_Pause_DrawCircuitObjects
    jmp FuncA_Pause_DrawFlowerCount
.ENDPROC

;;; Draws objects to mark the current area on the minimap.
.PROC FuncA_Pause_DrawMinimapObjects
    ;; Copy the current room's AreaCells_u8_arr2_arr_ptr into T1T0.
    lda <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    and #bRoom::AreaMask
    tay  ; eArea value
    lda DataA_Pause_AreaCells_u8_arr2_arr_ptr_0_arr, y
    sta T0
    lda DataA_Pause_AreaCells_u8_arr2_arr_ptr_1_arr, y
    sta T1
    ;; Draw an object for each explored minimap cell in the array.
    ldy #0
    beq @continue  ; unconditional
    @loop:
    ;; At this point, A holds the most recently read minimap row number.  Store
    ;; it in T2 for later.
    iny
    sta T2  ; minimap row number
    ;; Determine the bitmask we should use for this minimap row number, and
    ;; store it in T4.
    and #$07
    tax
    lda Data_PowersOfTwo_u8_arr8, x
    sta T4  ; mask
    ;; Read the minimap column number and store it in T3 for later.
    lda (T1T0), y
    iny
    sta T3  ; minimap col number
    ;; We'll use X as the byte index into Sram_Minimap_u16_arr.  If we're in
    ;; the first eight rows, we'll be checking our bitmask against the low
    ;; eight bits of each u16; otherwise, we'll be checking against the high
    ;; eight bits.
    mul #2
    tax
    lda T2  ; minimap row number
    cmp #$08
    blt @loByte
    inx
    @loByte:
    ;; Check if this minimap cell has been explored.  If not, don't draw an
    ;; object for this cell.
    lda Sram_Minimap_u16_arr, x
    and T4  ; mask
    beq @continue
    ;; If this minimap cell is the avatar's current position, blink its color.
    lda T2  ; minimap row number
    cmp Zp_CameraMinimapRow_u8
    bne @noBlink
    lda T3  ; minimap col number
    cmp Zp_CameraMinimapCol_u8
    bne @noBlink
    lda Zp_FrameCounter_u8
    and #$10
    beq @noBlink
    @blink:
    lda #bObj::Pri | kPaletteObjMinimapCurrentScreen
    bne @setFlags  ; unconditional
    @noBlink:
    lda #bObj::Pri | kPaletteObjMinimapCurrentArea
    @setFlags:
    ;; Draw an object for this minimap cell.
    ldx Zp_OamOffset_u8
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, x
    lda T2  ; minimap row number
    mul #kTileHeightPx
    adc #kMinimapTopPx - 1
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, x
    lda T3  ; minimap col number
    mul #kTileWidthPx
    adc #kMinimapLeftPx
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, x
    lda #kTileIdObjMinimapCurrentArea
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, x
    .repeat .sizeof(sObj)
    inx
    .endrepeat
    stx Zp_OamOffset_u8
    ;; Read the minimap row number (or $ff terminator) for the next iteration.
    @continue:
    lda (T1T0), y
    bpl @loop
    rts
.ENDPROC

;;; Draws objects to animate circuits for any activated breakers.
.PROC FuncA_Pause_DrawCircuitObjects
    lda Zp_FrameCounter_u8
    div #4
    and #$03
    sta T0  ; anim offset
    ldy Zp_OamOffset_u8
    ldx #14
    @loop:
    lda _CircuitBreakerMask_byte_arr, x
    and Zp_ActivatedBreakers_byte
    beq @continue
    lda _CircuitPosX_u8_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    lda _CircuitPosY_u8_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    lda _CircuitFlags_bObj_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda _CircuitFirstTile_u8_arr, x
    add T0  ; anim offset
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    .repeat .sizeof(sObj)
    iny
    .endrepeat
    @continue:
    dex
    bpl @loop
    sty Zp_OamOffset_u8
    rts
_CircuitBreakerMask_byte_arr:
    .byte $01, $01, $01, $20, $20, $20
    .byte $02, $02,           $10, $10
    .byte      $04, $04, $08, $08
    .byte              $40
_CircuitPosX_u8_arr:
    .byte $a8, $b0, $b8, $c0, $c8, $d0
    .byte $a8, $b0,           $c8, $d0
    .byte      $b0, $b8, $c0, $c8
    .byte              $bc
_CircuitPosY_u8_arr:
    .byte $ac, $ac, $ac, $ac, $ac, $ac
    .byte $ba, $ba,           $ba, $ba
    .byte      $c2, $c2, $c2, $c2
    .byte              $c9
_CircuitFirstTile_u8_arr:
    .byte $c0, $c4, $c4, $c4, $c4, $c0
    .byte $c0, $c4,           $c4, $c0
    .byte      $c0, $c4, $c4, $c0
    .byte              $c8
_CircuitFlags_bObj_arr:
    .byte 0, 0, bObj::Pri, bObj::Pri | bObj::FlipH, bObj::FlipH, bObj::FlipH
    .byte bObj::FlipV, bObj::FlipV, bObj::FlipHV, bObj::FlipHV
    .byte bObj::FlipV, bObj::Pri | bObj::FlipV
    .byte bObj::Pri | bObj::FlipHV, bObj::FlipHV
    .byte 0
.ENDPROC

;;; Draws objects showing the number of collected flowers.
.PROC FuncA_Pause_DrawFlowerCount
    ;; Only display the flower count if at least one flower has been delivered,
    ;; but the BEEP opcode has not been unlocked yet.
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpBeep
    bne @noFlowerCount
    jsr Func_CountDeliveredFlowers  ; returns Z and A
    beq @noFlowerCount
    sta T0  ; flower count
    ;; Allocate objects to display the flower count.
    ldy Zp_OamOffset_u8
    tya
    add #.sizeof(sObj) * 2
    sta Zp_OamOffset_u8
    ;; Set object positions.
    lda #$28
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    lda #$1f
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    lda #$c8
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    lda #$c9
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    ;; Set object palettes.
    lda #kPaletteObjFlowerTop
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #0
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    ;; Set object tile IDs.
    lda #kTileIdObjFlowerTop
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda T0  ; flower count
    ora #$80 | '0'
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    @noFlowerCount:
    rts
.ENDPROC

;;; These two arrays each map from (original minimap tile ID - $80) to the tile
;;; ID to use if there is an item/quest map marker on that tile.
.PROC DataA_Pause_MinimapItemMarkerTiles_u8_arr
    .byte $80, $b1, '?', $b3, $b2, '?', $b6, '?'
    .byte '?', '?', '?', $b7, '?', '?', '?', $b5
    .byte '?', '?', '?', '?', '?', '?', $b8, '?'
    .byte '?', '?', '?', '?', '?', '?', '?', '?'
    .byte $bd
.ENDPROC
.PROC DataA_Pause_MinimapQuestMarkerTiles_u8_arr
    .byte $b0, '?', '?', '?', '?', '?', '?', '?'
    .byte '?', '?', '?', '?', '?', '?', '?', '?'
    .byte '?', '?', '?', '?', '?', $b9, '?', '?'
    .byte $b4, '?', '?', '?', '?', '?', $be, '?'
    .byte '?', $bc, $ba, '?', '?', $bb
.ENDPROC

;;;=========================================================================;;;
