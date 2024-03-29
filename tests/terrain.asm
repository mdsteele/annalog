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

.INCLUDE "../src/macros.inc"
.INCLUDE "../src/ppu.inc"
.INCLUDE "../src/room.inc"
.INCLUDE "../src/tileset.inc"

.IMPORT Exit_Success
.IMPORT FuncA_Terrain_GetColumnPtrForTileIndex
.IMPORT Func_ExpectAEqualsY
.IMPORT Func_GetTerrainColumnPtrForPointX
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr

;;;=========================================================================;;;

kTerrainDataPtr = $80ff
kBlockColumnIndex = 11
kExpectedStripePtrShortRoom = $81a4
kExpectedStripePtrTallRoom = $8207

.LINECONT +
.ASSERT kTerrainDataPtr + kBlockColumnIndex * kScreenHeightBlocks = \
        kExpectedStripePtrShortRoom, error
.ASSERT kTerrainDataPtr + kBlockColumnIndex * kTallRoomHeightBlocks = \
        kExpectedStripePtrTallRoom, error
.LINECONT -

;;;=========================================================================;;;

.ZEROPAGE

.EXPORTZP Zp_Current_sRoom
Zp_Current_sRoom: .tag sRoom
.EXPORTZP Zp_Current_sTileset
Zp_Current_sTileset: .tag sTileset
.EXPORTZP Zp_PointX_i16
Zp_PointX_i16: .res 2
.EXPORTZP Zp_PointY_i16
Zp_PointY_i16: .res 2
.EXPORTZP Zp_PpuTransferLen_u8
Zp_PpuTransferLen_u8: .res 1

;;;=========================================================================;;;

.BSS

.EXPORT Ram_PpuTransfer_arr
Ram_PpuTransfer_arr: .res $80

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

.PROC FuncA_Terrain_TestColumnForTileIndexInShortRoom
    ;; Setup:
    lda #0
    sta Zp_Current_sRoom + sRoom::Flags_bRoom
    ;; Test:
    lda #kBlockColumnIndex * 2  ; param: tile column index
    jsr FuncA_Terrain_GetColumnPtrForTileIndex
    ;; Verify:
    lda Zp_TerrainColumn_u8_arr_ptr + 0
    ldy #<kExpectedStripePtrShortRoom
    jsr Func_ExpectAEqualsY
    lda Zp_TerrainColumn_u8_arr_ptr + 1
    ldy #>kExpectedStripePtrShortRoom
    jmp Func_ExpectAEqualsY
.ENDPROC

.PROC FuncA_Terrain_TestColumnForTileIndexInTallRoom
    ;; Setup:
    lda #bRoom::Tall
    sta Zp_Current_sRoom + sRoom::Flags_bRoom
    ;; Test:
    lda #kBlockColumnIndex * 2  ; param: tile column index
    jsr FuncA_Terrain_GetColumnPtrForTileIndex
    ;; Verify:
    lda Zp_TerrainColumn_u8_arr_ptr + 0
    ldy #<kExpectedStripePtrTallRoom
    jsr Func_ExpectAEqualsY
    lda Zp_TerrainColumn_u8_arr_ptr + 1
    ldy #>kExpectedStripePtrTallRoom
    jmp Func_ExpectAEqualsY
.ENDPROC

.PROC FuncA_Terrain_TestColumnForPointInShortRoom
    ;; Setup:
    lda #0
    sta Zp_Current_sRoom + sRoom::Flags_bRoom
    ldax #kBlockColumnIndex * kBlockWidthPx + 5
    stax Zp_PointX_i16
    ;; Test:
    jsr Func_GetTerrainColumnPtrForPointX
    ;; Verify:
    lda Zp_TerrainColumn_u8_arr_ptr + 0
    ldy #<kExpectedStripePtrShortRoom
    jsr Func_ExpectAEqualsY
    lda Zp_TerrainColumn_u8_arr_ptr + 1
    ldy #>kExpectedStripePtrShortRoom
    jmp Func_ExpectAEqualsY
.ENDPROC

.PROC FuncA_Terrain_TestColumnForPointInTallRoom
    ;; Setup:
    lda #bRoom::Tall
    sta Zp_Current_sRoom + sRoom::Flags_bRoom
    ldax #kBlockColumnIndex * kBlockWidthPx + 5
    stax Zp_PointX_i16
    ;; Test:
    jsr Func_GetTerrainColumnPtrForPointX
    ;; Verify:
    lda Zp_TerrainColumn_u8_arr_ptr + 0
    ldy #<kExpectedStripePtrTallRoom
    jsr Func_ExpectAEqualsY
    lda Zp_TerrainColumn_u8_arr_ptr + 1
    ldy #>kExpectedStripePtrTallRoom
    jmp Func_ExpectAEqualsY
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "MAIN"
    sei
    cld
    ldx #$ff
    txs
SetUp:
    ldax #kTerrainDataPtr
    stax Zp_Current_sRoom + sRoom::TerrainData_ptr
Tests:
    jsr FuncA_Terrain_TestColumnForTileIndexInShortRoom
    jsr FuncA_Terrain_TestColumnForTileIndexInTallRoom
    jsr FuncA_Terrain_TestColumnForPointInShortRoom
    jsr FuncA_Terrain_TestColumnForPointInTallRoom
Success:
    jmp Exit_Success

;;;=========================================================================;;;
