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
.INCLUDE "../actors/bird.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Core_sTileset
.IMPORT Data_Empty_sDevice_arr
.IMPORT Data_Empty_sPlatform_arr
.IMPORT FuncA_Objects_AnimateCircuitIfBreakerActive
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjSewer

;;;=========================================================================;;;

.SEGMENT "PRGC_Core"

.EXPORT DataC_Core_East_sRoom
.PROC DataC_Core_East_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $10
    d_byte Flags_bRoom, bRoom::Tall | eArea::Core
    d_byte MinimapStartRow_u8, 2
    d_byte MinimapStartCol_u8, 15
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjSewer)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr Platforms_sPlatform_arr_ptr, Data_Empty_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, Data_Empty_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Core_East_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/core_east.room"
    .assert * - :- = 18 * 24, error
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBird
    d_word PosX_i16, $0038
    d_word PosY_i16, $0030
    d_byte Param_byte, $7f
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBird
    d_word PosX_i16, $00b8
    d_word PosY_i16, $00a8
    d_byte Param_byte, bBadBird::FlipH | $7f
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBird
    d_word PosX_i16, $0058
    d_word PosY_i16, $00f8
    d_byte Param_byte, $7f
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcBlinky
    d_word PosX_i16, $0058
    d_word PosY_i16, $0018
    d_byte Param_byte, %01010100
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcBlinky
    d_word PosX_i16, $0028
    d_word PosY_i16, $00b8
    d_byte Param_byte, %11011000
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcBlinky
    d_word PosX_i16, $00d8
    d_word PosY_i16, $0168
    d_byte Param_byte, %00001110
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::CoreElevator
    d_byte SpawnBlock_u8, 19
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CityOutskirts
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Core_East_DrawRoom
    ldx #eFlag::BreakerMine  ; param: breaker flag
    jmp FuncA_Objects_AnimateCircuitIfBreakerActive
.ENDPROC

;;;=========================================================================;;;
