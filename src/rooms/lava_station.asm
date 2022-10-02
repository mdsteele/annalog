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
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/boiler.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_LavaAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_LavaAreaName_u8_arr
.IMPORT DataA_Room_Lava_sTileset
.IMPORT FuncA_Machine_BoilerFinishEmittingSteam
.IMPORT FuncA_Machine_BoilerTick
.IMPORT FuncA_Machine_BoilerWriteReg
.IMPORT FuncA_Machine_EmitSteamRightFromPipe
.IMPORT FuncA_Machine_EmitSteamUpFromPipe
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Objects_DrawBoilerMachine
.IMPORT FuncA_Objects_DrawBoilerValve1
.IMPORT Func_MachineBoilerReadReg
.IMPORT Func_MachineBoilerReset
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjLava
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; The device index for the upgrade in this room.
kUpgradeDeviceIndex = 1

;;; The eFlag value for the upgrade in this room.
kUpgradeFlag = eFlag::UpgradeOpcodeCopy

;;; The machine index for the LavaStationBoiler machine in this room.
kBoilerMachineIndex = 0

;;; Platform indices for various parts of the LavaStationBoiler machine.
kBoilerPlatformIndex = 0
kValvePlatformIndex  = 1
kPipe1PlatformIndex  = 2
kPipe2PlatformIndex  = 3

;;;=========================================================================;;;

.SEGMENT "PRGC_Lava"

.EXPORT DataC_Lava_Station_sRoom
.PROC DataC_Lava_Station_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $10
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 12
    d_byte MinimapStartCol_u8, 17
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjLava)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_LavaAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_LavaAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Lava_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, FuncC_Lava_Station_InitRoom
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/lava_station.room"
    .assert * - :- = 17 * 16, error
_Machines_sMachine_arr:
:   .assert * - :- = kBoilerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::LavaStationBoiler
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::Boiler
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $40
    d_byte RegNames_u8_arr4, "V", 0, 0, 0
    d_byte MainPlatform_u8, kBoilerPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, Func_MachineBoilerReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BoilerWriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncC_Lava_StationBoiler_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BoilerTick
    d_addr Draw_func_ptr, FuncA_Objects_LavaStationBoiler_Draw
    d_addr Reset_func_ptr, Func_MachineBoilerReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kBoilerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $18
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0060
    d_word Top_i16,   $00d0
    D_END
    .assert * - :- = kValvePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0034
    d_word Top_i16,   $00b4
    D_END
    .assert * - :- = kPipe1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0038
    d_word Top_i16,   $0058
    D_END
    .assert * - :- = kPipe2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16,   $0080
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 7
    d_byte Target_u8, kBoilerMachineIndex
    D_END
    .assert * - :- = kUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 13
    d_byte Target_u8, kUpgradeFlag
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::LavaShaft
    d_byte SpawnBlock_u8, 3
    D_END
.ENDPROC

.PROC FuncC_Lava_Station_InitRoom
    lda Sram_ProgressFlags_arr + (kUpgradeFlag >> 3)
    and #1 << (kUpgradeFlag & $07)
    beq @done
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr + kUpgradeDeviceIndex
    @done:
    rts
.ENDPROC

;;; TryAct implemention for the LavaStationBoiler machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq PRGA_Machine is loaded.
.PROC FuncC_Lava_StationBoiler_TryAct
    ;; Determine which pipe the steam should exit out of (or fail if both pipes
    ;; are blocked).
    ldy Zp_MachineIndex_u8
    ldx Ram_MachineGoalVert_u8_arr, y  ; valve angle (0-9)
    ldy _ValvePipePlatformIndex_u8_arr10, x  ; pipe platform index
    bmi _Failure
    ;; Emit steam from the chosen pipe.
    cpy #kPipe1PlatformIndex
    beq @steamRight
    @steamUp:
    jsr FuncA_Machine_EmitSteamUpFromPipe
    jmp FuncA_Machine_BoilerFinishEmittingSteam
    @steamRight:
    jsr FuncA_Machine_EmitSteamRightFromPipe
    jmp FuncA_Machine_BoilerFinishEmittingSteam
_Failure:
    jmp FuncA_Machine_Error
_ValvePipePlatformIndex_u8_arr10:
:   .byte kPipe1PlatformIndex
    .byte $ff
    .byte kPipe2PlatformIndex
    .byte kPipe2PlatformIndex
    .byte $ff
    .byte kPipe1PlatformIndex
    .byte kPipe1PlatformIndex
    .byte $ff
    .byte kPipe2PlatformIndex
    .byte kPipe2PlatformIndex
    .assert * - :- = 10, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_LavaStationBoiler_Draw
    jsr FuncA_Objects_DrawBoilerMachine
    ldx #kValvePlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawBoilerValve1
.ENDPROC

;;;=========================================================================;;;
