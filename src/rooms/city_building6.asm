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
.INCLUDE "../devices/mousehole.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Building_sTileset
.IMPORT DataA_Text0_CityBuilding2Screen_Locked_u8_arr
.IMPORT DataA_Text0_CityBuilding2Screen_Unlocked_u8_arr
.IMPORT Data_Empty_sPlatform_arr
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjCity
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_ProgressFlags_arr

;;;=========================================================================;;;

;;; The device index for the locked door in this room.
kLockedDoorDeviceIndex = 1

;;;=========================================================================;;;

.SEGMENT "PRGC_City"

.EXPORT DataC_City_Building6_sRoom
.PROC DataC_City_Building6_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, bRoom::Tall | eArea::City
    d_byte MinimapStartRow_u8, 1
    d_byte MinimapStartCol_u8, 22
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCity)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Building_sTileset
    d_addr Platforms_sPlatform_arr_ptr, Data_Empty_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncC_City_Building6_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/city_building6.room"
    .assert * - :- = 16 * 24, error
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadRodent
    d_word PosX_i16, 0
    d_word PosY_i16, 0
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadRodent
    d_word PosX_i16, 0
    d_word PosY_i16, 0
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadRodent
    d_word PosX_i16, 0
    d_word PosY_i16, 0
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door2Open
    d_byte BlockRow_u8, 3
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eRoom::CityCenter
    D_END
    .assert * - :- = kLockedDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Locked
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eRoom::CityCenter
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door3Open
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eRoom::CityCenter
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Screen
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 3
    d_byte Target_byte, eDialog::CityBuilding6Screen
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Mousehole
    d_byte BlockRow_u8, 3
    d_byte BlockCol_u8, 12
    d_byte Target_byte, bMousehole::OnLeft | bMousehole::RunLeft
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Mousehole
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 8
    d_byte Target_byte, bMousehole::OnLeft | bMousehole::RunRight
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Mousehole
    d_byte BlockRow_u8, 15
    d_byte BlockCol_u8, 8
    d_byte Target_byte, bMousehole::OnRight | bMousehole::RunEither
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Mousehole
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 5
    d_byte Target_byte, bMousehole::OnRight | bMousehole::RunEither
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Mousehole
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 3
    d_byte Target_byte, bMousehole::OnRight | bMousehole::RunRight
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC FuncC_City_Building6_EnterRoom
    flag_bit Sram_ProgressFlags_arr, eFlag::CityCenterDoorUnlocked
    beq @done
    lda #eDevice::Door1Unlocked
    sta Ram_DeviceType_eDevice_arr + kLockedDoorDeviceIndex
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_CityBuilding6Screen_sDialog
.PROC DataA_Dialog_CityBuilding6Screen_sDialog
    dlg_Func _InitialFunc
_InitialFunc:
    ;; If the door has already been unlocked, display a message to that effect.
    flag_bit Sram_ProgressFlags_arr, eFlag::CityCenterDoorUnlocked
    beq @doorStillLocked
    ldya #_Unlocked_sDialog
    rts
    @doorStillLocked:
    ldya #_Locked_sDialog
    rts
_Locked_sDialog:
    dlg_Text Screen, DataA_Text0_CityBuilding2Screen_Locked_u8_arr
    dlg_Done
_Unlocked_sDialog:
    dlg_Text Screen, DataA_Text0_CityBuilding2Screen_Unlocked_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
