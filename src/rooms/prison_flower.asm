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
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Prison_sTileset
.IMPORT FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
.IMPORT FuncA_Room_RespawnFlowerDeviceIfDropped
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjPrison

;;;=========================================================================;;;

;;; The device index for the flower in this room.
kFlowerDeviceIndex = 1

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

.EXPORT DataC_Prison_Flower_sRoom
.PROC DataC_Prison_Flower_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $10
    d_byte Flags_bRoom, eArea::Prison
    d_byte MinimapStartRow_u8, 1
    d_byte MinimapStartCol_u8, 8
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPrison)
    d_addr Tick_func_ptr, FuncC_Prison_Flower_TickRoom
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Prison_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Prison_Flower_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/prison_flower.room"
    .assert * - :- = 17 * 16, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0098
    d_word Top_i16,   $0088
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0070
    d_word Top_i16,   $00a8
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadToad
    d_word PosX_i16, $0068
    d_word PosY_i16, $00b0
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 3
    d_byte Target_u8, eDialog::PrisonFlowerSign
    D_END
    .assert * - :- = kFlowerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Flower
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 11
    d_byte Target_u8, eFlag::FlowerPrison
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::PrisonCrossroad
    d_byte SpawnBlock_u8, 12
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Prison_Flower_EnterRoom
    ldx #kFlowerDeviceIndex  ; param: device index
    jmp FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Prison_Flower_TickRoom
    ldx #kFlowerDeviceIndex  ; param: device index
    jmp FuncA_Room_RespawnFlowerDeviceIfDropped
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_PrisonFlowerSign_sDialog
.PROC DataA_Dialog_PrisonFlowerSign_sDialog
    .word ePortrait::Sign
    .byte "Surface Access ", kTileIdArrowRight, "$"
    .byte "$"
    .byte kTileIdArrowLeft, " Holding Cells#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;
