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
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Hut_sTileset
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjMermaid
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_ProgressFlags_arr

;;;=========================================================================;;;

;;; The device index for the upgrade in this room.
kUpgradeDeviceIndex = 0

;;; The eFlag value for the upgrade in this room.
kUpgradeFlag = eFlag::UpgradeOpBeep

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Cellar_sRoom
.PROC DataC_Mermaid_Cellar_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, eArea::Mermaid
    d_byte MinimapStartRow_u8, 11
    d_byte MinimapStartCol_u8, 12
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjMermaid)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Hut_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncC_Mermaid_Cellar_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/mermaid_cellar.room"
    .assert * - :- = 16 * 15, error
_Platforms_sPlatform_arr:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $c0
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0020
    d_word Top_i16,   $0034
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 3
    d_byte Target_u8, kUpgradeFlag
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 11
    d_byte Target_u8, eRoom::MermaidHut4
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC FuncC_Mermaid_Cellar_EnterRoom
    flag_bit Sram_ProgressFlags_arr, kUpgradeFlag
    beq @done
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr + kUpgradeDeviceIndex
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
