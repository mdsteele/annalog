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

.INCLUDE "../actor.inc"
.INCLUDE "../device.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Crypt_sTileset
.IMPORT Data_Empty_sDevice_arr
.IMPORT Func_Noop
.IMPORT Func_WriteToUpperAttributeTable
.IMPORT Ppu_ChrObjCrypt

;;;=========================================================================;;;

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_East_sRoom
.PROC DataC_Crypt_East_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Crypt
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 2
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCrypt)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Crypt_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, Data_Empty_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, FuncA_Terrain_CryptEast_FadeInRoom
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/crypt_east.room"
    .assert * - :- = 18 * 24, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $70
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $0030
    d_word Top_i16,   $0154
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Spike
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0060
    d_word Top_i16,   $008e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Spike
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0080
    d_word Top_i16,   $008e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Spike
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00b0
    d_word Top_i16,   $008e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Spike
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0030
    d_word Top_i16,   $0166
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Spike
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16,   $016e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Spike
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0080
    d_word Top_i16,   $0166
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadSpider
    d_word PosX_i16, $0060
    d_word PosY_i16, $0018
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBat
    d_word PosX_i16, $00a0
    d_word PosY_i16, $00d0
    d_byte Param_byte, eDir::Up
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBat
    d_word PosX_i16, $0078
    d_word PosY_i16, $00c8
    d_byte Param_byte, eDir::Down
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CryptFlower
    d_byte SpawnBlock_u8, 3
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::CryptCenter
    d_byte SpawnBlock_u8, 17
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::CryptGallery
    d_byte SpawnBlock_u8, 17
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 0
    d_byte Destination_eRoom, eRoom::CryptChains
    d_byte SpawnBlock_u8, 13
    d_byte SpawnAdjust_byte, $c1
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

.PROC FuncA_Terrain_CryptEast_FadeInRoom
    ldx #3    ; param: num bytes to write
    ldy #$05  ; param: attribute value
    lda #$23  ; param: initial byte offset
    jmp Func_WriteToUpperAttributeTable
.ENDPROC

;;;=========================================================================;;;
