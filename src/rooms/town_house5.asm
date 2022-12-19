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
.INCLUDE "../actors/townsfolk.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Indoors_sTileset
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjPrison

;;;=========================================================================;;;

;;; The dialog indices for the kids in this room.
kBrunoDialogIndex = 0
kMarieDialogIndex = 1

;;;=========================================================================;;;

.SEGMENT "PRGC_Town"

.EXPORT DataC_Town_House5_sRoom
.PROC DataC_Town_House5_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, eArea::Town
    d_byte MinimapStartRow_u8, 0
    d_byte MinimapStartCol_u8, 14
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPrison)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Indoors_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, DataA_Dialog_TownHouse5_sDialog_ptr_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Init_func_ptr, Func_Noop
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/town_house5.room"
    .assert * - :- = 16 * 16, error
_Platforms_sPlatform_arr:
    .byte ePlatform::None
_Actors_sActor_arr:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_byte TileRow_u8, 25
    d_byte TileCol_u8, 12
    d_byte Param_byte, eNpcChild::CrewcutStanding
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_byte TileRow_u8, 25
    d_byte TileCol_u8, 24
    d_byte Param_byte, eNpcChild::BobcutStanding
    D_END
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 5
    d_byte Target_u8, kBrunoDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 6
    d_byte Target_u8, kBrunoDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::UnlockedDoor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 8
    d_byte Target_u8, eRoom::TownOutdoors
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 11
    d_byte Target_u8, kMarieDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 12
    d_byte Target_u8, kMarieDialogIndex
    D_END
    .byte eDevice::None
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the TownHouse5 room.
.PROC DataA_Dialog_TownHouse5_sDialog_ptr_arr
:   .assert * - :- = kBrunoDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_TownHouse5_Bruno_sDialog
    .assert * - :- = kMarieDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_TownHouse5_Marie_sDialog
.ENDPROC

.PROC DataA_Dialog_TownHouse5_Bruno_sDialog
    .word ePortrait::Man  ; TODO
    .byte "Lorem ipsum?#"
    .word ePortrait::Done
.ENDPROC

.PROC DataA_Dialog_TownHouse5_Marie_sDialog
    .word ePortrait::Girl  ; TODO
    .byte "Lorem ipsum!#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;