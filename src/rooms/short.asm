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

.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../room.inc"

.IMPORT Ram_DeviceAnim_u8_arr

;;;=========================================================================;;;

.SEGMENT "PRGC_Room"

.EXPORT DataC_Room_AreaName_u8_arr
.PROC DataC_Room_AreaName_u8_arr
    .byte "Prison Caves", $ff
.ENDPROC

.EXPORT DataC_Room_Short_sRoom
.PROC DataC_Room_Short_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $10
    d_byte IsTall_bool, $00
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_TerrainData:
:   .incbin "out/data/short.room"
    .assert * - :- = 18 * 16, error
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataC_Room_AreaName_u8_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Exits_sDoor_arr_ptr, _Exits_sDoor_arr
    d_addr Init_func_ptr, _Init
    D_END
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 6
    d_byte Target_u8, eFlag::UpgradeOpcodeTil
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 5
    d_byte Target_u8, eFlag::UpgradeOpcodeSkip
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_u8, eFlag::UpgradeMaxInstructions3
    D_END
    .byte eDevice::None
_Exits_sDoor_arr:
    D_STRUCT sDoor
    d_byte Exit_bDoor, eDoor::Western | 0
    d_word PositionAdjust_i16, $10
    d_byte Destination_eRoom, eRoom::TallRoom
    D_END
    D_STRUCT sDoor
    d_byte Exit_bDoor, eDoor::Eastern | 0
    d_word PositionAdjust_i16, $30
    d_byte Destination_eRoom, eRoom::TallRoom
    D_END
_Init:
    ;; Animate the upgrade device.
    lda #kUpgradeDeviceAnimStart
    sta Ram_DeviceAnim_u8_arr + 0
    rts
.ENDPROC

;;;=========================================================================;;;
