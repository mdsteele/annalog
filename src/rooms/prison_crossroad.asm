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
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Prison_sTileset
.IMPORT Data_Empty_sDevice_arr
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjSewer

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

.EXPORT DataC_Prison_Crossroad_sRoom
.PROC DataC_Prison_Crossroad_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $10
    d_byte Flags_bRoom, bRoom::Tall | eArea::Prison
    d_byte MinimapStartRow_u8, 1
    d_byte MinimapStartCol_u8, 7
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjSewer)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Prison_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, Data_Empty_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/prison_crossroad.room"
    .assert * - :- = 18 * 24, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $a0
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0040
    d_word Top_i16,   $0154
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0088
    d_word PosY_i16, $0088
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $00a0
    d_word PosY_i16, $00e8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadFish
    d_word PosX_i16, $0080
    d_word PosY_i16, $0160
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::PrisonUpper
    d_byte SpawnBlock_u8, 6
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::PrisonFlower
    d_byte SpawnBlock_u8, 4
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::PrisonCell
    d_byte SpawnBlock_u8, 19
    d_byte SpawnAdjust_byte, $f0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1 | bPassage::Secondary
    d_byte Destination_eRoom, eRoom::PrisonCell
    d_byte SpawnBlock_u8, 12
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::PrisonEast
    d_byte SpawnBlock_u8, 20
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;;=========================================================================;;;
