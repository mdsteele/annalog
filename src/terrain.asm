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

.INCLUDE "macros.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

.ZEROPAGE

;;; The currently-loaded room.
.EXPORTZP Zp_Current_sRoom
Zp_Current_sRoom: .tag sRoom

;;; Return value for FuncA_Terrain_GetColumnPtrFor* functions.  This will point
;;; to the beginning (top) of the requested terrain block column in the current
;;; room.
.EXPORTZP Zp_TerrainColumn_u8_arr_ptr
Zp_TerrainColumn_u8_arr_ptr: .res 2

;;; Temporary variable for FuncA_Terrain_FillNametables.
Zp_TerrainColumnIndexLimit_u8: .res 1

;;; Temporary variable for FuncA_Terrain_TransferTileColumn.
Zp_NametableColumnIndex_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

.SCOPE DataA_Terrain_Table
UpperLeft_u8_arr:
    .byte $00, $86, $84, $86, $00, $80, $82, $80, $00
UpperRight_u8_arr:
    .byte $00, $86, $86, $85, $00, $00, $80, $00, $81
LowerLeft_u8_arr:
    .byte $00, $00, $81, $00, $87, $81, $87, $81, $00
LowerRight_u8_arr:
    .byte $00, $00, $82, $81, $87, $87, $80, $00, $80
.ENDSCOPE

;;; Populates Zp_TerrainColumn_u8_arr_ptr with a pointer to the start of the
;;; requested terrain block column in the current room.
;;; @param A The index of the room block column.
.EXPORT FuncA_Terrain_GetColumnPtrForBlockIndex
.PROC FuncA_Terrain_GetColumnPtrForBlockIndex
    asl a
    .assert * = FuncA_Terrain_GetColumnPtrForTileIndex, error  ; fall through
.ENDPROC

;;; Populates Zp_TerrainColumn_u8_arr_ptr with a pointer to the start of the
;;; terrain block column in the current room that contains the specified room
;;; tile column.
;;; @param A The index of the room tile column.
.EXPORT FuncA_Terrain_GetColumnPtrForTileIndex
.PROC FuncA_Terrain_GetColumnPtrForTileIndex
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
    bit <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bmi _TallRoom
_ShortRoom:
    asl a                                ; lo byte of (col * 16)
    rol Zp_TerrainColumn_u8_arr_ptr + 1  ; hi byte of (col * 16)
    jmp _SetPtr
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

;;; Directly fills the PPU nametables with terrain tile data for the current
;;; room.
;;; @prereq Rendering is disabled.
;;; @param A The block column index for the left side of the screen.
.EXPORT FuncA_Terrain_FillNametables
.PROC FuncA_Terrain_FillNametables
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    ldx #bPpuCtrl::EnableNmi | bPpuCtrl::ObjPat1 | bPpuCtrl::Inc32
    stx Hw_PpuCtrl_wo
    tax
    add #kScreenWidthBlocks
    sta Zp_TerrainColumnIndexLimit_u8
    txa  ; now a is the starting block column index
_BlockColumnLoop:
    pha
    jsr FuncA_Terrain_GetColumnPtrForBlockIndex
    pla
    pha
.SCOPE
    asl a  ; now a is the tile column index for the left side of the blocks
    pha
    ldy #0  ; y will count the block row index
.SCOPE
    ldx #>Ppu_Nametable0_sName
    .assert <Ppu_Nametable0_sName = 0, error
    stx Hw_PpuAddr_w2
    sta Hw_PpuAddr_w2
    @tileLoop:
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    tax  ; terrain block type
    lda DataA_Terrain_Table::UpperLeft_u8_arr, x
    sta Hw_PpuData_rw
    lda DataA_Terrain_Table::LowerLeft_u8_arr, x
    sta Hw_PpuData_rw
    iny
    cpy #kScreenHeightBlocks
    bne @tileLoop
.ENDSCOPE
.SCOPE
    bit <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bpl @shortRoom
    pla  ; now a is the tile column index for the left side of the blocks
    pha
    ldx #>Ppu_Nametable3_sName
    .assert <Ppu_Nametable3_sName = 0, error
    stx Hw_PpuAddr_w2
    sta Hw_PpuAddr_w2
    @tileLoop:
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    tax  ; terrain block type
    lda DataA_Terrain_Table::UpperLeft_u8_arr, x
    sta Hw_PpuData_rw
    lda DataA_Terrain_Table::LowerLeft_u8_arr, x
    sta Hw_PpuData_rw
    iny
    cpy #kTallRoomHeightBlocks
    bne @tileLoop
    @shortRoom:
.ENDSCOPE
    pla     ; now a is the tile column index for the left side of the blocks
    add #1  ; now a is the tile column index for the right side of the blocks
    pha
    ldy #0  ; y will count the block row index
.SCOPE
    ldx #>Ppu_Nametable0_sName
    .assert <Ppu_Nametable0_sName = 0, error
    stx Hw_PpuAddr_w2
    sta Hw_PpuAddr_w2
    @tileLoop:
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    tax  ; terrain block type
    lda DataA_Terrain_Table::UpperRight_u8_arr, x
    sta Hw_PpuData_rw
    lda DataA_Terrain_Table::LowerRight_u8_arr, x
    sta Hw_PpuData_rw
    iny
    cpy #kScreenHeightBlocks
    bne @tileLoop
.ENDSCOPE
.SCOPE
    bit <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bpl @shortRoom
    pla  ; now a is the tile column index for the right side of the blocks
    pha
    ldx #>Ppu_Nametable3_sName
    .assert <Ppu_Nametable3_sName = 0, error
    stx Hw_PpuAddr_w2
    sta Hw_PpuAddr_w2
    @tileLoop:
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    tax  ; terrain block type
    lda DataA_Terrain_Table::UpperRight_u8_arr, x
    sta Hw_PpuData_rw
    lda DataA_Terrain_Table::LowerRight_u8_arr, x
    sta Hw_PpuData_rw
    iny
    cpy #kTallRoomHeightBlocks
    bne @tileLoop
    @shortRoom:
.ENDSCOPE
    pla
.ENDSCOPE
    pla  ; now a is the current block column index
    add #1
    cmp Zp_TerrainColumnIndexLimit_u8
    jne _BlockColumnLoop
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
    jsr FuncA_Terrain_GetColumnPtrForTileIndex
    ;; Buffer a PPU transfer for the upper nametable.
.PROC _UpperTransfer
    ldx Zp_PpuTransferLen_u8
    txa
    add #4 + kScreenHeightTiles
    sta Zp_PpuTransferLen_u8
    lda #bPpuCtrl::EnableNmi | bPpuCtrl::Inc32
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
    bit <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bpl _Return
.PROC _LowerTransfer
    ldx Zp_PpuTransferLen_u8
    txa
    add #4 + (kTallRoomHeightTiles - kScreenHeightTiles)
    sta Zp_PpuTransferLen_u8
    lda #bPpuCtrl::EnableNmi | bPpuCtrl::Inc32
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
    sty Zp_Tmp1_byte  ; block row index
    lda Zp_NametableColumnIndex_u8
    and #$01
    bne _Right
_Left:
    ldy Zp_Tmp1_byte  ; block row index
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    tay  ; terrain block type
    lda DataA_Terrain_Table::UpperLeft_u8_arr, y
    sta Ram_PpuTransfer_arr, x
    inx
    lda DataA_Terrain_Table::LowerLeft_u8_arr, y
    sta Ram_PpuTransfer_arr, x
    inx
    inc Zp_Tmp1_byte  ; block row index
    cpx Zp_PpuTransferLen_u8
    bne _Left
    rts
_Right:
    ldy Zp_Tmp1_byte  ; block row index
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    tay  ; terrain block type
    lda DataA_Terrain_Table::UpperRight_u8_arr, y
    sta Ram_PpuTransfer_arr, x
    inx
    lda DataA_Terrain_Table::LowerRight_u8_arr, y
    sta Ram_PpuTransfer_arr, x
    inx
    inc Zp_Tmp1_byte  ; block row index
    cpx Zp_PpuTransferLen_u8
    bne _Right
    rts
.ENDPROC

;;;=========================================================================;;;
