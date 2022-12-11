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
.INCLUDE "../src/room.inc"
.INCLUDE "../src/tileset.inc"

.IMPORT Exit_Success
.IMPORT Func_ExpectAEqualsY
.IMPORT Func_GetTerrainColumnPtrForPoint
.IMPORT Func_GetTerrainColumnPtrForTileIndex
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr

;;;=========================================================================;;;

kTerrainDataPtr = $80ff
kBlockColumnIndex = 11
kExpectedStripePtrShortRoom = $81af
kExpectedStripePtrTallRoom = $8207

.LINECONT +
.ASSERT kTerrainDataPtr + kBlockColumnIndex * 16 = \
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
.EXPORTZP Zp_PointX_i16, Zp_PointY_i16
Zp_PointX_i16: .res 2
Zp_PointY_i16: .res 2
.EXPORTZP Zp_PpuTransferLen_u8
Zp_PpuTransferLen_u8: .res 1
.EXPORTZP Zp_Tmp1_byte, Zp_Tmp2_byte, Zp_Tmp3_byte, Zp_Tmp_ptr
Zp_Tmp1_byte: .res 1
Zp_Tmp2_byte: .res 1
Zp_Tmp3_byte: .res 1
Zp_Tmp_ptr: .res 2

;;;=========================================================================;;;

.BSS

.EXPORT Ram_PpuTransfer_arr
Ram_PpuTransfer_arr: .res $80

;;;=========================================================================;;;

.CODE

.EXPORT DataA_Terrain_UpperLeft_u8_arr, DataA_Terrain_UpperRight_u8_arr
.EXPORT DataA_Terrain_LowerLeft_u8_arr, DataA_Terrain_LowerRight_u8_arr
DataA_Terrain_UpperLeft_u8_arr:
DataA_Terrain_LowerLeft_u8_arr:
DataA_Terrain_UpperRight_u8_arr:
DataA_Terrain_LowerRight_u8_arr:
    .res $100

.PROC Func_TestColumnForTileIndexInShortRoom
    ;; Setup:
    lda #$00
    sta Zp_Current_sRoom + sRoom::IsTall_bool
    ;; Test:
    lda #kBlockColumnIndex * 2  ; param: tile column index
    jsr Func_GetTerrainColumnPtrForTileIndex
    ;; Verify:
    lda Zp_TerrainColumn_u8_arr_ptr + 0
    ldy #<kExpectedStripePtrShortRoom
    jsr Func_ExpectAEqualsY
    lda Zp_TerrainColumn_u8_arr_ptr + 1
    ldy #>kExpectedStripePtrShortRoom
    jmp Func_ExpectAEqualsY
.ENDPROC

.PROC Func_TestColumnForTileIndexInTallRoom
    ;; Setup:
    lda #$ff
    sta Zp_Current_sRoom + sRoom::IsTall_bool
    ;; Test:
    lda #kBlockColumnIndex * 2  ; param: tile column index
    jsr Func_GetTerrainColumnPtrForTileIndex
    ;; Verify:
    lda Zp_TerrainColumn_u8_arr_ptr + 0
    ldy #<kExpectedStripePtrTallRoom
    jsr Func_ExpectAEqualsY
    lda Zp_TerrainColumn_u8_arr_ptr + 1
    ldy #>kExpectedStripePtrTallRoom
    jmp Func_ExpectAEqualsY
.ENDPROC

.PROC Func_TestColumnForPointInShortRoom
    ;; Setup:
    lda #$00
    sta Zp_Current_sRoom + sRoom::IsTall_bool
    ldax #kBlockColumnIndex * 16 + 5
    stax Zp_PointX_i16
    ;; Test:
    jsr Func_GetTerrainColumnPtrForPoint
    ;; Verify:
    lda Zp_TerrainColumn_u8_arr_ptr + 0
    ldy #<kExpectedStripePtrShortRoom
    jsr Func_ExpectAEqualsY
    lda Zp_TerrainColumn_u8_arr_ptr + 1
    ldy #>kExpectedStripePtrShortRoom
    jmp Func_ExpectAEqualsY
.ENDPROC

.PROC Func_TestColumnForPointInTallRoom
    ;; Setup:
    lda #$ff
    sta Zp_Current_sRoom + sRoom::IsTall_bool
    ldax #kBlockColumnIndex * 16 + 5
    stax Zp_PointX_i16
    ;; Test:
    jsr Func_GetTerrainColumnPtrForPoint
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
    jsr Func_TestColumnForTileIndexInShortRoom
    jsr Func_TestColumnForTileIndexInTallRoom
    jsr Func_TestColumnForPointInShortRoom
    jsr Func_TestColumnForPointInTallRoom
Success:
    jmp Exit_Success

;;;=========================================================================;;;
