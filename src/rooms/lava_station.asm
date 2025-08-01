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

.IMPORT DataA_Room_Lava_sTileset
.IMPORT FuncA_Machine_BoilerFinishEmittingSteam
.IMPORT FuncA_Machine_BoilerStartEmittingSteam
.IMPORT FuncA_Machine_BoilerTick
.IMPORT FuncA_Machine_BoilerWriteReg
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Objects_DrawBoilerMachine
.IMPORT FuncA_Objects_DrawBoilerValve
.IMPORT FuncA_Room_MachineBoilerReset
.IMPORT FuncA_Room_TurnSteamToSmokeIfConsoleOpen
.IMPORT Func_EmitSteamRightFromPipe
.IMPORT Func_EmitSteamUpFromPipe
.IMPORT Func_MachineBoilerReadReg
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjLava
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_ProgressFlags_arr

;;;=========================================================================;;;

;;; The device index for the upgrade in this room.
kUpgradeDeviceIndex = 1

;;; The eFlag value for the upgrade in this room.
kUpgradeFlag = eFlag::UpgradeOpCopy

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
    d_word MaxScrollX_u16, $110
    d_byte Flags_bRoom, eArea::Lava
    d_byte MinimapStartRow_u8, 12
    d_byte MinimapStartCol_u8, 17
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjLava)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Lava_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Lava_Station_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_TurnSteamToSmokeIfConsoleOpen
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/lava_station.room"
    .assert * - :- = 33 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kBoilerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::LavaStationBoiler
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteE
    d_byte Status_eDiagram, eDiagram::BoilerValve
    d_word ScrollGoalX_u16, $fc
    d_byte ScrollGoalY_u8, $40
    d_byte RegNames_u8_arr4, 0, 0, "V", 0
    d_byte MainPlatform_u8, kBoilerPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, Func_MachineBoilerReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BoilerWriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_LavaStationBoiler_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BoilerTick
    d_addr Draw_func_ptr, FuncC_Lava_StationBoiler_Draw
    d_addr Reset_func_ptr, FuncA_Room_MachineBoilerReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kBoilerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $18
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0160
    d_word Top_i16,   $00d0
    D_END
    .assert * - :- = kValvePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0134
    d_word Top_i16,   $00b4
    D_END
    .assert * - :- = kPipe1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0138
    d_word Top_i16,   $0058
    D_END
    .assert * - :- = kPipe2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0150
    d_word Top_i16,   $0080
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadSolifuge
    d_word PosX_i16, $00d8
    d_word PosY_i16, $0078
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 23
    d_byte Target_byte, kBoilerMachineIndex
    D_END
    .assert * - :- = kUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 29
    d_byte Target_byte, kUpgradeFlag
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 27
    d_byte Target_byte, eFlag::PaperManual4
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::LavaShaft
    d_byte SpawnBlock_u8, 4
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Lava_Station_EnterRoom
    flag_bit Ram_ProgressFlags_arr, kUpgradeFlag
    beq @done
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr + kUpgradeDeviceIndex
    @done:
    rts
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Lava_StationBoiler_Draw
    jsr FuncA_Objects_DrawBoilerMachine
    ldx #kValvePlatformIndex  ; param: platform index
    ldy #eValveInput::LeftHalfOfBottomEdge  ; param: input pipe position
    jmp FuncA_Objects_DrawBoilerValve
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; TryAct implemention for the LavaStationBoiler machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.PROC FuncA_Machine_LavaStationBoiler_TryAct
    jsr FuncA_Machine_BoilerStartEmittingSteam
    ;; Determine which pipe the steam should exit out of.
    lda Ram_MachineGoalHorz_u8_arr + kBoilerMachineIndex  ; valve 1 angle
    mod #4
    tax  ; valve angle (in tau/8 units, mod 4)
    ldy _ValvePipePlatformIndex_u8_arr4, x  ; param: pipe platform index
    ;; Emit steam from the chosen pipe.
    cpy #kPipe1PlatformIndex
    beq @steamRight
    @steamUp:
    jsr Func_EmitSteamUpFromPipe
    jmp FuncA_Machine_BoilerFinishEmittingSteam
    @steamRight:
    jsr Func_EmitSteamRightFromPipe
    jmp FuncA_Machine_BoilerFinishEmittingSteam
_ValvePipePlatformIndex_u8_arr4:
    .byte kPipe1PlatformIndex
    .byte kPipe2PlatformIndex
    .byte kPipe2PlatformIndex
    .byte kPipe1PlatformIndex
.ENDPROC

;;;=========================================================================;;;
