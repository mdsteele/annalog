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
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_City_sTileset
.IMPORT Data_Empty_sPlatform_arr
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjFactory

;;;=========================================================================;;;

.SEGMENT "PRGC_City"

.EXPORT DataC_City_Dump_sRoom
.PROC DataC_City_Dump_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $10
    d_byte Flags_bRoom, eArea::City
    d_byte MinimapStartRow_u8, 3
    d_byte MinimapStartCol_u8, 20
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjFactory)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_City_sTileset
    d_addr Platforms_sPlatform_arr_ptr, Data_Empty_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/city_dump.room"
    .assert * - :- = 17 * 15, error
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadToad
    d_word PosX_i16, $007c
    d_word PosY_i16, $0060
    d_byte Param_byte, bObj::FlipH
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $00a0
    d_word PosY_i16, $0088
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0070
    d_word PosY_i16, $00c8
    d_byte Param_byte, bObj::FlipH
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eRoom::CityFlower
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eFlag::PaperJerome35
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::CityDrain
    d_byte SpawnBlock_u8, 6
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_PaperJerome35_sDialog
.PROC DataA_Dialog_PaperJerome35_sDialog
    dlg_Text Paper, DataA_Text0_PaperJerome35_Page1_u8_arr
    dlg_Text Paper, DataA_Text0_PaperJerome35_Page2_u8_arr
    dlg_Text Paper, DataA_Text0_PaperJerome35_Page3_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_PaperJerome35_Page1_u8_arr
    .byte "Day 35: I have hidden$"
    .byte "the remote. Without it$"
    .byte "the complex can never$"
    .byte "be fully put to use.#"
.ENDPROC

.PROC DataA_Text0_PaperJerome35_Page2_u8_arr
    .byte "I can't bring myself$"
    .byte "to destroy our work.$"
    .byte "Maybe, someday, we'll$"
    .byte "be responsible enough.#"
.ENDPROC

.PROC DataA_Text0_PaperJerome35_Page3_u8_arr
    .byte "Maybe someday...#"
.ENDPROC

;;;=========================================================================;;;
