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
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Town_sTileset
.IMPORT DataC_Town_AreaCells_u8_arr2_arr
.IMPORT DataC_Town_AreaName_u8_arr
.IMPORT Func_Noop

;;;=========================================================================;;;

.SEGMENT "PRGC_Town"

.EXPORT DataC_Town_Outdoors_sRoom
.PROC DataC_Town_Outdoors_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $100
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 0
    d_byte MinimapStartCol_u8, 11
    d_byte MinimapWidth_u8, 2
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataC_Town_AreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataC_Town_AreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Town_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, _Dialogs_sDialog_ptr_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Init_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/town_outdoors.room"
    .assert * - :- = 32 * 16, error
_Platforms_sPlatform_arr:
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 19
    d_byte Target_u8, 0
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_u8, eRoom::TownHouse1
    D_END
    .byte eDevice::None
_Dialogs_sDialog_ptr_arr:
    .addr _Dialog0_sDialog
_Dialog0_sDialog:
    .word ePortrait::Sign
    .byte "Lorem ipsum dolor sit$"
    .byte "amet, consectetur$"
    .byte "adipiscing elit, sed$"
    .byte "do eiusmod tempor.#"
    .word ePortrait::Sign
    .byte "Ut enim ad minim$"
    .byte "veniam, quis nostrud$"
    .byte "exercitation.#"
    .byte 0
.ENDPROC

;;;=========================================================================;;;
