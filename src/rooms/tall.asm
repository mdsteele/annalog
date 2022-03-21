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
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataC_Prison_AreaCells_u8_arr2_arr
.IMPORT DataC_Prison_AreaName_u8_arr
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_MachineState

;;;=========================================================================;;;

;;; Defines room-specific machine state data for this particular room.
.STRUCT sState
    LeverState_u1       .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kMachineStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

.EXPORT DataC_Prison_Tall_sRoom
.PROC DataC_Prison_Tall_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $120
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 3
    d_byte MinimapStartCol_u8, 2
    d_byte MinimapWidth_u8, 2
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_TerrainData:
:   .incbin "out/data/tall.room"
    .assert * - :- = 35 * 24, error
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataC_Prison_AreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataC_Prison_AreaCells_u8_arr2_arr
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, _Dialogs_sDialog_ptr_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, _Init
    D_END
_Platforms_sPlatform_arr:
    .byte 0
_Actors_sActor_arr:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Crawler
    d_byte TileRow_u8, 43
    d_byte TileCol_u8, 39
    d_byte State_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Crawler
    d_byte TileRow_u8, 29
    d_byte TileCol_u8, 35
    d_byte State_byte, 0
    D_END
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 4
    d_byte Target_u8, sState::LeverState_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 12
    d_byte Target_u8, 0
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, 13
    d_byte BlockCol_u8, 6
    d_byte Target_u8, eFlag::UpgradeOpcodeTil
    D_END
    .byte eDevice::None
_Dialogs_sDialog_ptr_arr:
    .addr _Dialog0_sDialog
_Dialog0_sDialog:
    .word ePortrait::Woman
    .byte "Lorem ipsum dolor sit$"
    .byte "amet, consectetur$"
    .byte "adipiscing elit, sed$"
    .byte "do eiusmod tempor.#"
    .word ePortrait::Woman
    .byte "Ut enim ad minim$"
    .byte "veniam, quis nostrud$"
    .byte "exercitation.#"
    .byte 0
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_word PositionAdjust_i16, $ffff & -$50
    d_byte Destination_eRoom, eRoom::PrisonCell
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_word PositionAdjust_i16, $50
    d_byte Destination_eRoom, eRoom::PrisonCell
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_word PositionAdjust_i16, $ffff & -$c0
    d_byte Destination_eRoom, eRoom::PrisonCell
    D_END
_Init:
    lda #1
    sta Ram_MachineState + sState::LeverState_u1
    ;; Animate the upgrade device.
    lda #kUpgradeDeviceAnimStart
    sta Ram_DeviceAnim_u8_arr + 2
    rts
.ENDPROC

;;;=========================================================================;;;
