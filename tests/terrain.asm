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

.IMPORT Exit_Success
.IMPORT FuncA_Terrain_GetColumnPtrForTileIndex
.IMPORT Func_ExpectAEqualsY
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr

;;;=========================================================================;;;

kTerrainDataPtr = $80ff
kBlockColumnIndex = 11
kExpectedStripePtr = $8207

.LINECONT +
.ASSERT kTerrainDataPtr + kBlockColumnIndex * kTallRoomHeightBlocks = \
        kExpectedStripePtr, error
.LINECONT -

;;;=========================================================================;;;

.ZEROPAGE

.EXPORTZP Zp_PpuTransferLen_u8
Zp_PpuTransferLen_u8: .res 1
.EXPORTZP Zp_Tmp1_byte, Zp_Tmp2_byte
Zp_Tmp1_byte: .res 1
Zp_Tmp2_byte: .res 1

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

;;;=========================================================================;;;

.SEGMENT "MAIN"
    sei
    cld
    ldx #$ff
    txs
SetUp:
    lda #$ff
    sta Zp_Current_sRoom + sRoom::IsTall_bool
    ldax #kTerrainDataPtr
    stx Zp_Current_sRoom + sRoom::TerrainData_ptr + 0
    sta Zp_Current_sRoom + sRoom::TerrainData_ptr + 1
Test:
    lda #kBlockColumnIndex * 2
    jsr FuncA_Terrain_GetColumnPtrForTileIndex
Verify:
    lda Zp_TerrainColumn_u8_arr_ptr + 0
    ldy #<kExpectedStripePtr
    jsr Func_ExpectAEqualsY
    lda Zp_TerrainColumn_u8_arr_ptr + 1
    ldy #>kExpectedStripePtr
    jsr Func_ExpectAEqualsY
Success:
    jmp Exit_Success

;;;=========================================================================;;;
