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

.INCLUDE "avatar.inc"
.INCLUDE "charmap.inc"
.INCLUDE "cpu.inc"
.INCLUDE "macros.inc"
.INCLUDE "minimap.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT DataA_Pause_AreaCells_u8_arr2_arr_ptr_0_arr
.IMPORT DataA_Pause_AreaCells_u8_arr2_arr_ptr_1_arr
.IMPORT DataA_Pause_Minimap_sMarker_arr
.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT FuncA_Pause_AllocBaseObject
.IMPORT FuncA_Pause_DirectDrawWindowLineSide
.IMPORT Func_IsFlagSet
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Sram_Minimap_u16_arr
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8

;;;=========================================================================;;;

;;; The screen pixel positions for the top and left edges of the minimap rect.
kMinimapTopPx  = $28
kMinimapLeftPx = $20

;;; The BG tile ID for an unexplored tile on the minimap.
kTileIdBgMinimapUnexplored = $c0

;;; The OBJ tile ID for marking the current area on the minimap.
kTileIdObjMinimapCurrentArea = $02
;;; The OBJ palette numbers for marking the current area and blinking the
;;; current screen on the minimap.
kPaletteObjMinimapCurrentArea   = 0
kPaletteObjMinimapCurrentScreen = 1

;;;=========================================================================;;;

.ZEROPAGE

;;; The minimap cell that the room camera is currently looking at.
Zp_CameraMinimapRow_u8: .res 1
Zp_CameraMinimapCol_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Marks a cell on the minimap as having been visited.
;;; @param A The minimap column (0-23).
;;; @param Y The minimap row (0-14).
.EXPORT Func_MarkMinimap
.PROC Func_MarkMinimap
    pha  ; minimap col
    ;; Determine the bitmask to use for Sram_Minimap_u16_arr, and store it in
    ;; T0.
    tya  ; minimap row
    mod #8
    tax
    lda Data_PowersOfTwo_u8_arr8, x
    sta T0  ; mask
    ;; Calculate the byte offset into Sram_Minimap_u16_arr and store it in X.
    pla  ; minimap col
    mul #2
    tax  ; byte offset into Sram_Minimap_u16_arr
    cpy #8
    blt @loByte
    inx
    @loByte:
    ;; Check if minimap needs to be updated.
    lda Sram_Minimap_u16_arr, x
    ora T0  ; mask
    cmp Sram_Minimap_u16_arr, x
    beq @done
    ;; Enable writes to SRAM.
    ldy #bMmc3PrgRam::Enable
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Update minimap.
    sta Sram_Minimap_u16_arr, x
    ;; Disable writes to SRAM.
    ldy #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sty Hw_Mmc3PrgRamProtect_wo
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; Recomputes Zp_CameraMinimapRow_u8 and Zp_CameraMinimapCol_u8 from the
;;; current room scroll position, then (if necessary) updates SRAM to mark that
;;; minimap cell as explored.
.EXPORT FuncA_Terrain_UpdateAndMarkMinimap
.PROC FuncA_Terrain_UpdateAndMarkMinimap
    ;; Don't update the minimap if the avatar is hidden for a cutscene.
    lda Zp_AvatarPose_eAvatar
    .assert eAvatar::Hidden = 0, error
    beq _Return
_UpdateMinimapRow:
    ldy Zp_Current_sRoom + sRoom::MinimapStartRow_u8
    bit Zp_Current_sRoom + sRoom::Flags_bRoom
    .assert bRoom::Tall = bProc::Overflow, error
    bvc @upperHalf
    @tall:
    lda Zp_RoomScrollY_u8
    cmp #(kTallRoomHeightBlocks * kBlockHeightPx - kScreenHeightPx) / 2
    blt @upperHalf
    @lowerHalf:
    iny
    @upperHalf:
    sty Zp_CameraMinimapRow_u8
_UpdateMinimapCol:
    ;; Calculate which horizontal screen of the room the camera is looking at
    ;; (in other words, the hi byte of (camera center position - min scroll X)
    ;; in room pixel coordinates), storing the result in A.
    lda #kScreenWidthPx / 2
    sub Zp_Current_sRoom + sRoom::MinScrollX_u8
    add Zp_RoomScrollX_u16 + 0
    lda #0
    adc Zp_RoomScrollX_u16 + 1
    ;; Add that screen number to the room's starting minimap column to get the
    ;; current absolute minimap column.
    add Zp_Current_sRoom + sRoom::MinimapStartCol_u8
    sta Zp_CameraMinimapCol_u8
_MarkMinimap:
    lda Zp_CameraMinimapCol_u8  ; param: minimap col
    ldy Zp_CameraMinimapRow_u8  ; param: minimap row
    jmp Func_MarkMinimap
_Return:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Pause"

;;; Writes BG tile data for the pause screen minimap directly to the PPU.
;;; @prereq Rendering is disabled.
;;; @prereq Hw_PpuCtrl_wo is set to horizontal mode.
;;; @prereq Hw_PpuAddr_w2 is set to the start of a nametable row.
.EXPORT FuncA_Pause_DirectDrawMinimap
.PROC FuncA_Pause_DirectDrawMinimap
    ldya #DataA_Pause_Minimap_u8_arr
    stya T1T0  ; param: start of minimap row data
    ldx #0
    stx T2  ; param: byte offset into DataA_Pause_Minimap_sMarker_arr
    @rowLoop:
    jsr FuncA_Pause_DirectDrawMinimapLine  ; preserves X, advances T1T0 and T2
    inx
    cpx #kMinimapHeight
    bne @rowLoop
    rts
.ENDPROC

;;; Writes BG tile data for one line of the pause screen minimap directly to
;;; the PPU.
;;; @prereq Rendering is disabled.
;;; @prereq Hw_PpuCtrl_wo is set to horizontal mode.
;;; @prereq Hw_PpuAddr_w2 is set to the start of the nametable row.
;;; @param T1T0 The start of the minimap tile data row.
;;; @param T2 The current byte offset into DataA_Pause_Minimap_sMarker_arr.
;;; @param X The minimap row (0-15).
;;; @return T1T0 The start of the next minimap tile data row.
;;; @return T2 The updated byte offset into DataA_Pause_Minimap_sMarker_arr.
;;; @preserve X
.PROC FuncA_Pause_DirectDrawMinimapLine
    jsr FuncA_Pause_DirectDrawWindowLineSide  ; preserves X and T0+
    ;; Draw left margin.
    lda #' '
    sta Hw_PpuData_rw
    ;; Determine the bitmask we should use for this minimap row, and store it
    ;; in T7.
    txa  ; minimap row
    and #$07
    tay
    lda Data_PowersOfTwo_u8_arr8, y
    sta T7  ; mask
    ;; Save X in T3 so we can use X for something else and later restore it.
    stx T3  ; minimap row
    ;; We'll use X as the byte offset into Sram_Minimap_u16_arr.  If we're in
    ;; the first eight rows, we'll be checking our bitmask against the low
    ;; eight bits of each u16; otherwise, we'll be checking against the high
    ;; eight bits.
    txa  ; minimap row
    ldx #0
    stx T4  ; byte offset into minimap tile data (from pointer in T1T0)
    cmp #8
    blt @ready
    inx  ; now X is 1
    @ready:
_ColLoop:
    ;; Determine the "original" tile ID for this cell of the minimap (without
    ;; yet taking map markers into account), and store it in T5.
    lda Sram_Minimap_u16_arr, x
    and T7  ; mask
    bne @explored
    @unexplored:
    lda #kTileIdBgMinimapUnexplored
    .assert kTileIdBgMinimapUnexplored > 0, error
    bne @setOriginalTile  ; unconditional
    @explored:
    ldy T4  ; byte offset into minimap tile data (from pointer in T1T0)
    lda (T1T0), y
    @setOriginalTile:
    sta T5  ; original minimap tile ID
_MarkerLoop:
    ;; Check the minimap row number for the next map marker.  If it is greater
    ;; than the current row, then we haven't reached that marker yet, so just
    ;; draw the original minimap tile.  If it's less than the current row, then
    ;; skip this marker and check the next one.
    ldy T2  ; byte offset into DataA_Pause_Minimap_sMarker_arr
    lda T3  ; minimap row
    cmp DataA_Pause_Minimap_sMarker_arr + sMarker::Row_u8, y
    blt _DrawOriginalTile
    bne @continue
    ;; Now do the same thing again, for the minimap column number this time.
    txa  ; byte offset into Sram_Minimap_u16_arr
    div #2  ; now A is the minimap column number
    cmp DataA_Pause_Minimap_sMarker_arr + sMarker::Col_u8, y
    blt _DrawOriginalTile
    bne @continue
    ;; At this point, we need to save X so we can use it for Func_IsFlagSet and
    ;; then restore it later.
    stx T6  ; byte offset into Sram_Minimap_u16_arr
    ;; If this map marker's "Not" flag is set, then skip this marker and check
    ;; the next one.
    ldx DataA_Pause_Minimap_sMarker_arr + sMarker::Not_eFlag, y  ; param: flag
    jsr Func_IsFlagSet  ; preserves T0+
    bne @restoreXAndContinue
    ;; Check this map marker's "If" flag; if it's zero, this is an item marker
    ;; (small dot), otherwise it's a quest marker (large dot).
    ldy T2  ; byte offset into DataA_Pause_Minimap_sMarker_arr
    ldx DataA_Pause_Minimap_sMarker_arr + sMarker::If_eFlag, y  ; param: flag
    beq @itemMarker
    ;; For a quest marker, we need to check if the "If" flag is set, and skip
    ;; the marker if not.  But if the flag is set, we can compute the new tile
    ;; ID to use and draw it.
    @questMarker:
    jsr Func_IsFlagSet  ; preserves T0+
    beq @restoreXAndContinue
    lda T5  ; original minimap tile ID
    sub #kTileIdBgMinimapUnexplored
    tay
    lda DataA_Pause_MinimapQuestMarkerTiles_u8_arr, y
    ldx T6  ; byte offset into Sram_Minimap_u16_arr
    bpl _DrawTileA  ; unconditional
    ;; For item markers, we can just always draw the marker; if the original
    ;; tile ID for this minimap cell is unexplored, then that will just map
    ;; back to the unexplored tile.
    @itemMarker:
    lda T5  ; original minimap tile ID
    sub #kTileIdBgMinimapUnexplored
    tay
    lda DataA_Pause_MinimapItemMarkerTiles_u8_arr, y
    ldx T6  ; byte offset into Sram_Minimap_u16_arr
    bpl _DrawTileA  ; unconditional
    ;; If we had to skip this marker, then increment the byte offset into the
    ;; marker table and check the next marker.
    @restoreXAndContinue:
    ldx T6  ; byte offset into Sram_Minimap_u16_arr
    @continue:
    lda T2  ; byte offset into DataA_Pause_Minimap_sMarker_arr
    add #.sizeof(sMarker)
    sta T2  ; byte offset into DataA_Pause_Minimap_sMarker_arr
    bne _MarkerLoop  ; unconditional
_DrawOriginalTile:
    lda T5  ; original minimap tile ID
_DrawTileA:
    sta Hw_PpuData_rw
    inc T4  ; byte offset into minimap tile data (from pointer in T1T0)
    ;; Increment byte offset into Sram_Minimap_u16_arr.
    inx
    inx
    cpx #kMinimapWidth * 2
    blt _ColLoop
_Finish:
    ;; Advance T1T0 to point to the next minimap row.
    lda T0
    add T4  ; byte offset into minimap tile data (from pointer in T1T0)
    sta T0
    lda T1
    adc #0
    sta T1
    ;; Restore X (since this function needs to preserve it).
    ldx T3  ; minimap row
    ;; Draw right margin.
    lda #' '
    sta Hw_PpuData_rw
    jmp FuncA_Pause_DirectDrawWindowLineSide  ; preserves X and T0+
.ENDPROC

;;; Draws objects to mark the current area on the minimap.
.EXPORT FuncA_Pause_DrawMinimapObjects
.PROC FuncA_Pause_DrawMinimapObjects
    ;; Copy the current area's AreaCells_u8_arr2_arr_ptr into T1T0.
    lda Zp_Current_sRoom + sRoom::Flags_bRoom
    and #bRoom::AreaMask
    tay  ; eArea value
    lda DataA_Pause_AreaCells_u8_arr2_arr_ptr_0_arr, y
    sta T0
    lda DataA_Pause_AreaCells_u8_arr2_arr_ptr_1_arr, y
    sta T1
    ;; Draw an object for each minimap cell in the array (objects for any
    ;; unexplored cells will be hidden behind the minimap BG tiles).
    ldy #0
    beq @start  ; unconditional
    @loop:
    ;; At this point, A holds the most recently read minimap row number.  Store
    ;; it in T2 for later.
    iny
    sta T2  ; minimap row number
    ;; Read the minimap column number and store it in X for later.
    lda (T1T0), y
    iny
    tax  ; minimap col number
    ;; Allocate an object for this minimap cell.
    sty T3  ; byte offset into AreaCells_u8_arr2_arr_ptr
    lda T2  ; minimap row number
    mul #kTileHeightPx
    adc #kMinimapTopPx  ; param: Y-position
    jsr FuncA_Pause_AllocBaseObject  ; preserves X and T0+, returns C and Y
    bcs @noAlloc
    ;; Set object X-position.
    txa  ; minimap col number
    mul #kTileWidthPx
    adc #kMinimapLeftPx
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    ;; If this minimap cell is the avatar's current position, blink its color.
    cpx Zp_CameraMinimapCol_u8
    bne @noBlink
    lda T2  ; minimap row number
    cmp Zp_CameraMinimapRow_u8
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
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    ;; Set object tile ID and restore Y.
    lda #kTileIdObjMinimapCurrentArea
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @noAlloc:
    ldy T3  ; byte offset into AreaCells_u8_arr2_arr_ptr
    ;; Read the minimap row number (or $ff terminator) for the next iteration.
    @start:
    lda (T1T0), y
    bpl @loop
    rts
.ENDPROC

;;; The tile ID grid for the minimap (stored in row-major order).
.PROC DataA_Pause_Minimap_u8_arr
:   .incbin "out/data/minimap.map"
    .assert * - :- = kMinimapWidth * kMinimapHeight, error
.ENDPROC

;;; These two arrays each map from (original minimap tile ID - $80) to the tile
;;; ID to use if there is an item/quest map marker on that tile.
.PROC DataA_Pause_MinimapItemMarkerTiles_u8_arr
    .assert kTileIdBgMinimapUnexplored = $c0, error
    .byte $c0, $f1, '?', $f3, $f2, '?', $f6, '?'
    .byte '?', '?', '?', $f7, '?', '?', '?', $f5
    .byte $ff, '?', '?', '?', '?', '?', $f8, '?'
    .byte '?', '?', '?', '?', '?', '?', '?', '?'
    .byte $fd
.ENDPROC
.PROC DataA_Pause_MinimapQuestMarkerTiles_u8_arr
    .byte $f0, $a9, $aa, '?', '?', $ee, '?', '?'
    .byte '?', '?', '?', '?', '?', $ef, '?', '?'
    .byte '?', '?', '?', '?', '?', $f9, '?', '?'
    .byte $f4, '?', '?', '?', '?', '?', $fe, '?'
    .byte '?', $fc, $fa, '?', '?', $fb
.ENDPROC

;;;=========================================================================;;;
