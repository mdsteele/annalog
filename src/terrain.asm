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

.INCLUDE "cpu.inc"
.INCLUDE "macros.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "terrain.inc"
.INCLUDE "tileset.inc"

.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_PpuTransferLen_u8

;;;=========================================================================;;;

.ZEROPAGE

;;; Return value for Func_GetTerrainColumnPtrForTileIndex.  This will point
;;; to the beginning (top) of the requested terrain block column in the current
;;; room.
.EXPORTZP Zp_TerrainColumn_u8_arr_ptr
Zp_TerrainColumn_u8_arr_ptr: .res 2

;;; Temporary variable for FuncA_Terrain_FillNametables.
Zp_TerrainColumnIndexLimit_u8: .res 1

;;; Temporary variable for FuncA_Terrain_TransferTileColumn.
Zp_NametableColumnIndex_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Checks if the point stored in Zp_PointX_i16 and Zp_PointY_i16 is colliding
;;; with solid terrain.  It is assumed that both coordinates are nonnegative
;;; and within the bounds of the room terrain.
;;; @return A The terrain type at the point.
;;; @return C Set if the terrain is solid, cleared otherwise.
;;; @preserve X, T0+
.EXPORT Func_PointHitsTerrain
.PROC Func_PointHitsTerrain
    lda Zp_PointY_i16 + 1
    sta Zp_TerrainColumn_u8_arr_ptr + 0
    lda Zp_PointY_i16 + 0
    .assert kBlockHeightPx = (1 << 4), error
    .repeat 4
    lsr Zp_TerrainColumn_u8_arr_ptr + 0
    ror a
    .endrepeat
    tay  ; room block row index
    jsr Func_GetTerrainColumnPtrForPointX  ; preserves X, Y, and T0+
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    rts
.ENDPROC

;;; Populates Zp_TerrainColumn_u8_arr_ptr with a pointer to the start of the
;;; terrain block column in the current room that contains the room pixel
;;; X-position stored in Zp_PointX_i16.  It is assumed that Zp_PointX_i16 is
;;; nonnegative and within the bounds of the room terrain.
;;; @preserve X, Y, T0+
.EXPORT Func_GetTerrainColumnPtrForPointX
.PROC Func_GetTerrainColumnPtrForPointX
    bit <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    .assert bRoom::Tall = bProc::Overflow, error
    bvs _TallRoom
_ShortRoom:
    ;; The width of a block in pixels is 16, so by clearing the bottom four
    ;; bits of Zp_PointX_i16, we end up with block column index * 16 (with the
    ;; lo byte in A, and the hi byte still in Zp_PointX_i16 + 1).
    .assert kBlockWidthPx = $10, error
    lda Zp_PointX_i16 + 0
    and #$f0
    ;; However, the short room terrain data stride is also 16, so this number
    ;; is also the byte offset into the terrain data that we need.
    add <(Zp_Current_sRoom + sRoom::TerrainData_ptr + 0)
    sta Zp_TerrainColumn_u8_arr_ptr + 0
    lda Zp_PointX_i16 + 1
    adc <(Zp_Current_sRoom + sRoom::TerrainData_ptr + 1)
    sta Zp_TerrainColumn_u8_arr_ptr + 1
    rts
_TallRoom:
    ;; For tall rooms, we'll still clear the bottom four bits of Zp_PointX_i16
    ;; to get (block row * 16), but then we need to add that number to half of
    ;; itself to get (block row * 24).
    .assert kTallRoomHeightBlocks = 24, error
    ;; We start by dividing the hi byte of Zp_PointX_i16 in half, and using
    ;; Zp_TerrainColumn_u8_arr_ptr + 1 as a temporary variable to store it (so
    ;; we can preserve T0+).
    lda Zp_PointX_i16 + 1   ; effectively block row * 16 (hi)
    lsr a  ; sets up C
    sta Zp_TerrainColumn_u8_arr_ptr + 1  ; block row * 8 (hi)
    ;; Next, we clear out the bottom four bits of the lo byte of Zp_PointX_i16,
    ;; using Zp_TerrainColumn_u8_arr_ptr + 0 as another temporary variable.
    .assert kBlockWidthPx = $10, error
    lda Zp_PointX_i16 + 0
    and #$f0
    sta Zp_TerrainColumn_u8_arr_ptr + 0  ; block row * 16 (lo)
    ;; At this point, A holds the lo byte of (block row * 16), and C still has
    ;; the carry bit from halving the hi byte of (block row * 16).  So we can
    ;; halve A with carry and add to it to get the lo byte of (block row * 24).
    ror a  ; uses C (and then clears C, since bottom bit of A is zero)
    adc Zp_TerrainColumn_u8_arr_ptr + 0  ; block row * 16 (lo)
    sta Zp_TerrainColumn_u8_arr_ptr + 0  ; block row * 24 (lo)
    ;; Now we can perform the high byte of the addition.
    lda Zp_PointX_i16 + 1    ; effectively block row * 16 (hi)
    adc Zp_TerrainColumn_u8_arr_ptr + 1  ; block row * 8 (hi)
    sta Zp_TerrainColumn_u8_arr_ptr + 1  ; block row * 24 (hi)
    ;; At this point, Zp_TerrainColumn_u8_arr_ptr holds the byte offset into
    ;; the terrain data, so add the base terrain data pointer to it.
    lda Zp_TerrainColumn_u8_arr_ptr + 0
    adc <(Zp_Current_sRoom + sRoom::TerrainData_ptr + 0)  ; C is already clear
    sta Zp_TerrainColumn_u8_arr_ptr + 0
    lda Zp_TerrainColumn_u8_arr_ptr + 1
    adc <(Zp_Current_sRoom + sRoom::TerrainData_ptr + 1)
    sta Zp_TerrainColumn_u8_arr_ptr + 1
    rts
.ENDPROC

;;; Populates Zp_TerrainColumn_u8_arr_ptr with a pointer to the start of the
;;; terrain block column in the current room that contains the specified room
;;; tile column.
;;; @param A The index of the room tile column.
;;; @preserve T0+
.EXPORT Func_GetTerrainColumnPtrForTileIndex
.PROC Func_GetTerrainColumnPtrForTileIndex
    and #$fe
    ;; Currently, a is (col * 2), where col is the room block column index.
    ;; Calculate (col * 8), with the lo byte in a, and the hi byte in
    ;; (Zp_TerrainColumn_u8_arr_ptr + 1).
    ldx #0
    stx Zp_TerrainColumn_u8_arr_ptr + 1
    .repeat 2
    asl a
    rol Zp_TerrainColumn_u8_arr_ptr + 1
    .endrepeat
    ;; We now have (col * 8).  If the room is short, we want (col * 16), and if
    ;; it's tall we want (col * 24).
    bit <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    .assert bRoom::Tall = bProc::Overflow, error
    bvs _TallRoom
_ShortRoom:
    asl a                                ; lo byte of (col * 16)
    rol Zp_TerrainColumn_u8_arr_ptr + 1  ; hi byte of (col * 16)
    bcc _SetPtr  ; unconditional
_TallRoom:
    sta Zp_TerrainColumn_u8_arr_ptr + 0  ; lo byte of (col * 8)
    ldx Zp_TerrainColumn_u8_arr_ptr + 1  ; hi byte of (col * 8)
    asl a                                ; lo byte of (col * 16)
    rol Zp_TerrainColumn_u8_arr_ptr + 1  ; hi byte of (col * 16)
    add Zp_TerrainColumn_u8_arr_ptr + 0  ; lo byte of (col * 24)
    tay
    txa
    adc Zp_TerrainColumn_u8_arr_ptr + 1  ; hi byte of (col * 24)
    sta Zp_TerrainColumn_u8_arr_ptr + 1
    tya
_SetPtr:
    ;; At this point, the lo byte of (col * height) is in a, and the hi byte is
    ;; in (Zp_TerrainColumn_u8_arr_ptr + 1).  Add that to the current room's
    ;; TerrainData_ptr and store the result in Zp_TerrainColumn_u8_arr_ptr.
    add <(Zp_Current_sRoom + sRoom::TerrainData_ptr + 0)
    sta Zp_TerrainColumn_u8_arr_ptr + 0
    lda Zp_TerrainColumn_u8_arr_ptr + 1
    adc <(Zp_Current_sRoom + sRoom::TerrainData_ptr + 1)
    sta Zp_TerrainColumn_u8_arr_ptr + 1
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; Directly fills the PPU nametables with terrain tile data for the current
;;; room.
;;; @prereq Rendering is disabled.
;;; @param A The tile column index for the left side of the screen.
.EXPORT FuncA_Terrain_FillNametables
.PROC FuncA_Terrain_FillNametables
    sta T0  ; current room tile column index
    add #kScreenWidthTiles - 1
    sta T1  ; final room tile column index
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    ldx #kPpuCtrlFlagsVert
    stx Hw_PpuCtrl_wo
_TileColumnLoop:
    lda T0  ; param: room tile column index
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves T0+
    ldy #0  ; room block row index
    lda T0  ; room tile column index
    and #$01
    bne _RightSide
.PROC _LeftSide
    ;; Fill in the top screen's worth of tiles.
    ldx #>Ppu_Nametable0_sName
    .assert <Ppu_Nametable0_sName = 0, error
    lda T0  ; room tile column index
    and #$1f
    stx Hw_PpuAddr_w2
    sta Hw_PpuAddr_w2
    @tileLoop:
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    sty T2  ; room block row index
    tay  ; terrain block type
    lda (Zp_Current_sTileset + sTileset::UpperLeft_u8_arr_ptr), y
    sta Hw_PpuData_rw
    lda (Zp_Current_sTileset + sTileset::LowerLeft_u8_arr_ptr), y
    sta Hw_PpuData_rw
    ldy T2  ; room block row index
    iny
    cpy #kScreenHeightBlocks
    bne @tileLoop
    ;; Prepare to fill in the bottom screen's worth of tiles.
    ldx #>Ppu_Nametable3_sName
    .assert <Ppu_Nametable3_sName = 0, error
    lda T0  ; room tile column index
    and #$1f
    stx Hw_PpuAddr_w2
    sta Hw_PpuAddr_w2
    ;; Check if this room is more than one screen tall.
    bit <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    .assert bRoom::Tall = bProc::Overflow, error
    bvc _ShortRoom
_TallRoom:
    @tileLoop:
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    sty T2  ; room block row index
    tay  ; terrain block type
    lda (Zp_Current_sTileset + sTileset::UpperLeft_u8_arr_ptr), y
    sta Hw_PpuData_rw
    lda (Zp_Current_sTileset + sTileset::LowerLeft_u8_arr_ptr), y
    sta Hw_PpuData_rw
    ldy T2  ; room block row index
    iny
    cpy #kTallRoomHeightBlocks
    bne @tileLoop
    beq _Continue  ; unconditional
.ENDPROC
.PROC _RightSide
    ;; Fill in the top screen's worth of tiles.
    ldx #>Ppu_Nametable0_sName
    .assert <Ppu_Nametable0_sName = 0, error
    lda T0  ; room tile column index
    and #$1f
    stx Hw_PpuAddr_w2
    sta Hw_PpuAddr_w2
    @tileLoop:
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    sty T2  ; room block row index
    tay  ; terrain block type
    lda (Zp_Current_sTileset + sTileset::UpperRight_u8_arr_ptr), y
    sta Hw_PpuData_rw
    lda (Zp_Current_sTileset + sTileset::LowerRight_u8_arr_ptr), y
    sta Hw_PpuData_rw
    ldy T2  ; room block row index
    iny
    cpy #kScreenHeightBlocks
    bne @tileLoop
    ;; Prepare to fill in the bottom screen's worth of tiles.
    ldx #>Ppu_Nametable3_sName
    .assert <Ppu_Nametable3_sName = 0, error
    lda T0  ; room tile column index
    and #$1f
    stx Hw_PpuAddr_w2
    sta Hw_PpuAddr_w2
    ;; Check if this room is more than one screen tall.
    bit <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    .assert bRoom::Tall = bProc::Overflow, error
    bvc _ShortRoom
_TallRoom:
    @tileLoop:
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    sty T2  ; room block row index
    tay  ; terrain block type
    lda (Zp_Current_sTileset + sTileset::UpperRight_u8_arr_ptr), y
    sta Hw_PpuData_rw
    lda (Zp_Current_sTileset + sTileset::LowerRight_u8_arr_ptr), y
    sta Hw_PpuData_rw
    ldy T2  ; room block row index
    iny
    cpy #kTallRoomHeightBlocks
    bne @tileLoop
    beq _Continue  ; unconditional
.ENDPROC
_ShortRoom:
    lda #0
    @tileLoop:
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
    iny
    cpy #kTallRoomHeightBlocks
    bne @tileLoop
_Continue:
    lda T0  ; current room tile column index
    cmp T1  ; final room tile column index
    beq _Done
    inc T0  ; current room tile column index
    jmp _TileColumnLoop
_Done:
    rts
.ENDPROC

;;; Buffers a PPU transfer to update one tile column from the current room.
;;; @param A The index of the room tile column to transfer.
.EXPORT FuncA_Terrain_TransferTileColumn
.PROC FuncA_Terrain_TransferTileColumn
    tax
    .assert kScreenWidthTiles = $20, error
    and #$1f
    sta Zp_NametableColumnIndex_u8
    txa  ; param: room tile column index
    jsr Func_GetTerrainColumnPtrForTileIndex
    ;; Buffer a PPU transfer for the upper nametable.
.PROC _UpperTransfer
    ldx Zp_PpuTransferLen_u8
    txa
    add #4 + kScreenHeightTiles
    sta Zp_PpuTransferLen_u8
    lda #kPpuCtrlFlagsVert
    sta Ram_PpuTransfer_arr, x
    inx
    lda #>Ppu_Nametable0_sName
    sta Ram_PpuTransfer_arr, x
    inx
    .assert <Ppu_Nametable0_sName = 0, error
    lda Zp_NametableColumnIndex_u8
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kScreenHeightTiles
    sta Ram_PpuTransfer_arr, x
    inx
    ldy #0  ; param: starting block row index
    jsr FuncA_Terrain_TransferTileColumnData
.ENDPROC
    ;; If this is a tall room, then we need to also buffer a PPU transfer for
    ;; the lower nametable.
    bit <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    .assert bRoom::Tall = bProc::Overflow, error
    bvc _Return
.PROC _LowerTransfer
    ldx Zp_PpuTransferLen_u8
    txa
    add #4 + (kTallRoomHeightTiles - kScreenHeightTiles)
    sta Zp_PpuTransferLen_u8
    lda #kPpuCtrlFlagsVert
    sta Ram_PpuTransfer_arr, x
    inx
    lda #>Ppu_Nametable3_sName
    sta Ram_PpuTransfer_arr, x
    inx
    .assert <Ppu_Nametable3_sName = 0, error
    lda Zp_NametableColumnIndex_u8
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kTallRoomHeightTiles - kScreenHeightTiles
    sta Ram_PpuTransfer_arr, x
    inx
    ldy #kScreenHeightBlocks  ; param: starting block row index
    jsr FuncA_Terrain_TransferTileColumnData
.ENDPROC
_Return:
    rts
.ENDPROC

;;; Helper function for FuncA_Terrain_TransferTileColumn.  Fills out a PPU
;;; transfer entry with the data for a particular tile column in the current
;;; room.
;;; @prereq Zp_NametableColumnIndex_u8 holds the index of the nametable tile
;;;         column that should be updated.
;;; @prereq The PPU transfer entry header has already been written.
;;; @prereq Zp_PpuTransferLen_u8 is set as though the entry were complete.
;;; @param X PPU transfer array index for start of the entry's data.
;;; @param Y Starting block row index.
.PROC FuncA_Terrain_TransferTileColumnData
    sty T0  ; block row index
    lda Zp_NametableColumnIndex_u8
    and #$01
    bne _Right
_Left:
    ldy T0  ; block row index
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    tay  ; terrain block type
    lda (Zp_Current_sTileset + sTileset::UpperLeft_u8_arr_ptr), y
    sta Ram_PpuTransfer_arr, x
    inx
    lda (Zp_Current_sTileset + sTileset::LowerLeft_u8_arr_ptr), y
    sta Ram_PpuTransfer_arr, x
    inx
    inc T0  ; block row index
    cpx Zp_PpuTransferLen_u8
    bne _Left
    rts
_Right:
    ldy T0  ; block row index
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    tay  ; terrain block type
    lda (Zp_Current_sTileset + sTileset::UpperRight_u8_arr_ptr), y
    sta Ram_PpuTransfer_arr, x
    inx
    lda (Zp_Current_sTileset + sTileset::LowerRight_u8_arr_ptr), y
    sta Ram_PpuTransfer_arr, x
    inx
    inc T0  ; block row index
    cpx Zp_PpuTransferLen_u8
    bne _Right
    rts
.ENDPROC

;;; Calls the current room's FadeIn_func_ptr function.
.EXPORT FuncA_Terrain_CallRoomFadeIn
.PROC FuncA_Terrain_CallRoomFadeIn
    ldy #sRoomExt::FadeIn_func_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    jmp (T1T0)
.ENDPROC

;;;=========================================================================;;;
