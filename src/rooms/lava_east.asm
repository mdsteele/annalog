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
.INCLUDE "../actors/lavaball.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../devices/boiler.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/blaster.inc"
.INCLUDE "../machines/boiler.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/lava.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Lava_sTileset
.IMPORT FuncA_Machine_BlasterTick
.IMPORT FuncA_Machine_BlasterTryAct
.IMPORT FuncA_Machine_BlasterWriteRegM
.IMPORT FuncA_Machine_BoilerFinishEmittingSteam
.IMPORT FuncA_Machine_BoilerTick
.IMPORT FuncA_Machine_BoilerWriteReg
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_AnimateLavaTerrain
.IMPORT FuncA_Objects_DrawBlasterMachine
.IMPORT FuncA_Objects_DrawBlasterMirror
.IMPORT FuncA_Objects_DrawBoilerMachine
.IMPORT FuncA_Objects_DrawBoilerValve
.IMPORT FuncA_Room_MachineBoilerReset
.IMPORT FuncA_Room_ReflectFireblastsOffMirror
.IMPORT FuncA_Room_ResetLever
.IMPORT FuncA_Room_TurnProjectilesToSmokeIfConsoleOpen
.IMPORT FuncA_Room_TurnSteamToSmokeIfConsoleOpen
.IMPORT FuncA_Terrain_FadeInTallRoomWithLava
.IMPORT Func_EmitSteamRightFromPipe
.IMPORT Func_EmitSteamUpFromPipe
.IMPORT Func_MachineBlasterReadRegM
.IMPORT Func_MachineBoilerReadReg
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjLava
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState3_byte_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The device indices for the levers in this room.
kUpperLeverDeviceIndex   = 3
kMiddleLeverLDeviceIndex = 4
kMiddleLeverUDeviceIndex = 5
kLowerLeverDeviceIndex   = 6

;;; The machine indices for the machines in this room.
kBlasterMachineIndex     = 0
kUpperBoilerMachineIndex = 1
kLowerBoilerMachineIndex = 2

;;; Platform indices for various parts of the LavaEastBlaster machine.
kBlasterPlatformIndex = 0
kMirror1PlatformIndex = 1
kMirror2PlatformIndex = 2
kMirror3PlatformIndex = 3

;;; Platform indices for various parts of the LavaEastUpperBoiler machine.
kUpperBoilerPlatformIndex = 4
kUpperValvePlatformIndex  = 5
kUpperPipe1PlatformIndex  = 6
kUpperPipe2PlatformIndex  = 7

;;; Platform indices for various parts of the LavaEastLowerBoiler machine.
kLowerBoilerPlatformIndex = 8
kLowerPipe1PlatformIndex  = 9

;;; Platform indices for pipes attached to "loose" boiler tanks.
kLoosePipe1PlatformIndex  = 10
kLoosePipe2PlatformIndex  = 11
kLoosePipe3PlatformIndex  = 12

;;; The initial value for the blaster's M register.
kBlasterInitGoalM = 3
;;; The initial and maximum permitted values for the blaster's X register.
kBlasterInitGoalX = 5
kBlasterMaxGoalX  = 9

;;; The minimum and initial X-positions for the left of the blaster platform.
.LINECONT +
kBlasterMinPlatformLeft = $00b0
kBlasterInitPlatformLeft = \
    kBlasterMinPlatformLeft + kBlasterInitGoalX * kBlockWidthPx
.LINECONT -

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    UpperLever_u8   .byte
    MiddleLeverL_u8 .byte
    MiddleLeverU_u8 .byte
    LowerLever_u8   .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Lava"

.EXPORT DataC_Lava_East_sRoom
.PROC DataC_Lava_East_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $110
    d_byte Flags_bRoom, bRoom::Tall | eArea::Lava
    d_byte MinimapStartRow_u8, 13
    d_byte MinimapStartCol_u8, 18
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 3
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
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, FuncA_Terrain_FadeInTallRoomWithLava
    d_addr Tick_func_ptr, FuncA_Room_LavaEast_TickRoom
    d_addr Draw_func_ptr, FuncA_Objects_AnimateLavaTerrain
    D_END
_TerrainData:
:   .incbin "out/rooms/lava_east.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kBlasterMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::LavaEastBlaster
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act | bMachine::WriteCDF
    d_byte Status_eDiagram, eDiagram::Blaster
    d_word ScrollGoalX_u16, $090
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "M", "U", "X", "L"
    d_byte MainPlatform_u8, kBlasterPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_LavaEastBlaster_Init
    d_addr ReadReg_func_ptr, FuncC_Lava_EastBlaster_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_LavaEastBlaster_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_LavaEastBlaster_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_BlasterTryAct
    d_addr Tick_func_ptr, FuncA_Machine_LavaEastBlaster_Tick
    d_addr Draw_func_ptr, FuncC_Lava_EastBlaster_Draw
    d_addr Reset_func_ptr, FuncA_Room_LavaEastBlaster_Reset
    D_END
    .assert * - :- = kUpperBoilerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::LavaEastUpperBoiler
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteCE
    d_byte Status_eDiagram, eDiagram::Boiler
    d_word ScrollGoalX_u16, $010
    d_byte ScrollGoalY_u8, $40
    d_byte RegNames_u8_arr4, "L", 0, "V", 0
    d_byte MainPlatform_u8, kUpperBoilerPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Lava_EastUpperBoiler_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_LavaEastUpperBoiler_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_LavaEastUpperBoiler_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BoilerTick
    d_addr Draw_func_ptr, FuncC_Lava_EastUpperBoiler_Draw
    d_addr Reset_func_ptr, FuncA_Room_LavaEastUpperBoiler_Reset
    D_END
    .assert * - :- = kLowerBoilerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::LavaEastLowerBoiler
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::Boiler
    d_word ScrollGoalX_u16, $110
    d_byte ScrollGoalY_u8, $c0
    d_byte RegNames_u8_arr4, "L", 0, 0, 0
    d_byte MainPlatform_u8, kLowerBoilerPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Lava_EastLowerBoiler_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_LavaEastLowerBoiler_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_LavaEastLowerBoiler_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BoilerTick
    d_addr Draw_func_ptr, FuncA_Objects_DrawBoilerMachine
    d_addr Reset_func_ptr, FuncA_Room_LavaEastLowerBoiler_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kBlasterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBlasterMachineWidthPx
    d_byte HeightPx_u8, kBlasterMachineHeightPx
    d_word Left_i16, kBlasterInitPlatformLeft
    d_word Top_i16, $0010
    D_END
    .assert * - :- = kMirror1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00d4
    d_word Top_i16,   $0054
    D_END
    .assert * - :- = kMirror2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01c4
    d_word Top_i16,   $0054
    D_END
    .assert * - :- = kMirror3PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0164
    d_word Top_i16,   $00b4
    D_END
    .assert * - :- = kUpperBoilerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $18
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0080
    d_word Top_i16,   $0090
    D_END
    .assert * - :- = kUpperValvePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0054
    d_word Top_i16,   $0084
    D_END
    .assert * - :- = kUpperPipe1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0070
    d_word Top_i16,   $0060
    D_END
    .assert * - :- = kUpperPipe2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0058
    d_word Top_i16,   $00d0
    D_END
    .assert * - :- = kLowerBoilerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $18
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0148
    d_word Top_i16,   $0140
    D_END
    .assert * - :- = kLowerPipe1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0170
    d_word Top_i16,   $0140
    D_END
    .assert * - :- = kLoosePipe1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00a8
    d_word Top_i16,   $0070
    D_END
    .assert * - :- = kLoosePipe2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0118
    d_word Top_i16,   $00b0
    D_END
    .assert * - :- = kLoosePipe3PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0168
    d_word Top_i16,   $00e8
    D_END
    ;; Lava:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $220
    d_byte HeightPx_u8, kLavaPlatformHeightPx
    d_word Left_i16,   $0000
    d_word Top_i16, kLavaPlatformTopTallRoom
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadLavaball
    d_word PosX_i16, $0068
    d_word PosY_i16, kLavaballStartYTall
    d_byte Param_byte, 5
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadLavaball
    d_word PosX_i16, $00c4
    d_word PosY_i16, kLavaballStartYTall
    d_byte Param_byte, 5
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 15
    d_byte BlockCol_u8, 10
    d_byte Target_byte, kUpperBoilerMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 16
    d_byte Target_byte, kBlasterMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 19
    d_byte BlockCol_u8, 30
    d_byte Target_byte, kLowerBoilerMachineIndex
    D_END
    .assert * - :- = kUpperLeverDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 4
    d_byte Target_byte, sState::UpperLever_u8
    D_END
    .assert * - :- = kMiddleLeverLDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 18
    d_byte Target_byte, sState::MiddleLeverL_u8
    D_END
    .assert * - :- = kMiddleLeverUDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 19
    d_byte Target_byte, sState::MiddleLeverU_u8
    D_END
    .assert * - :- = kLowerLeverDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 19
    d_byte BlockCol_u8, 22
    d_byte Target_byte, sState::LowerLever_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Boiler
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 11
    d_byte Target_byte, bBoiler::SteamUp | kLoosePipe1PlatformIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Boiler
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 18
    d_byte Target_byte, bBoiler::SteamUp | kLoosePipe2PlatformIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Boiler
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 19
    d_byte Target_byte, bBoiler::SteamUp | kLoosePipe2PlatformIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Boiler
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 22
    d_byte Target_byte, bBoiler::SteamRight | kLoosePipe3PlatformIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | bPassage::SameScreen | 0
    d_byte Destination_eRoom, eRoom::LavaCenter
    d_byte SpawnBlock_u8, 4
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | bPassage::SameScreen | 1
    d_byte Destination_eRoom, eRoom::LavaCenter
    d_byte SpawnBlock_u8, 15
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::LavaVent
    d_byte SpawnBlock_u8, 4
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::LavaCavern
    d_byte SpawnBlock_u8, 15
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Lava_EastBlaster_ReadReg
    cmp #$e
    beq _ReadX
    bge _ReadL
    cmp #$d
    beq _ReadU
    jmp Func_MachineBlasterReadRegM
_ReadL:
    lda Zp_RoomState + sState::MiddleLeverL_u8
    rts
_ReadU:
    lda Zp_RoomState + sState::MiddleLeverU_u8
    rts
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kBlasterPlatformIndex
    sub #kBlasterMinPlatformLeft - kTileHeightPx
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Lava_EastUpperBoiler_ReadReg
    cmp #$c
    beq _ReadL
    jmp Func_MachineBoilerReadReg
_ReadL:
    lda Zp_RoomState + sState::UpperLever_u8
    rts
.ENDPROC

.PROC FuncC_Lava_EastLowerBoiler_ReadReg
    lda Zp_RoomState + sState::LowerLever_u8
    rts
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Lava_EastBlaster_Draw
_Mirrors:
    ldx #kMirror3PlatformIndex
    @loop:
    jsr FuncA_Objects_DrawBlasterMirror  ; preserves X
    dex
    .assert kMirror1PlatformIndex > 0, error
    cpx #kMirror1PlatformIndex
    bge @loop
_Blaster:
    jmp FuncA_Objects_DrawBlasterMachine
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Lava_EastUpperBoiler_Draw
    jsr FuncA_Objects_DrawBoilerMachine
    ldx #kUpperValvePlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawBoilerValve
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_LavaEast_TickRoom
    jsr FuncA_Room_TurnSteamToSmokeIfConsoleOpen
    lda #eActor::ProjFireblast  ; param: projectile type
    jsr FuncA_Room_TurnProjectilesToSmokeIfConsoleOpen
_Mirrors:
    ldx #kBlasterMachineIndex  ; param: blaster machine index
    ldy #kMirror3PlatformIndex  ; param: mirror platform index
    @loop:
    jsr FuncA_Room_ReflectFireblastsOffMirror  ; preserves X and Y
    dey
    .assert kMirror1PlatformIndex > 0, error
    cpy #kMirror1PlatformIndex
    bge @loop
    rts
.ENDPROC

.PROC FuncA_Room_LavaEastBlaster_Init
    lda #kBlasterInitGoalM * kBlasterMirrorAnimSlowdown
    sta Ram_MachineState3_byte_arr + kBlasterMachineIndex  ; mirror anim
    fall FuncA_Room_LavaEastBlaster_Reset
.ENDPROC

.PROC FuncA_Room_LavaEastBlaster_Reset
    lda #kBlasterInitGoalM
    sta Ram_MachineState1_byte_arr + kBlasterMachineIndex  ; mirror goal
    lda #kBlasterInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kBlasterMachineIndex
    ldx #kMiddleLeverLDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    ldx #kMiddleLeverUDeviceIndex  ; param: device index
    jmp FuncA_Room_ResetLever
.ENDPROC

.PROC FuncA_Room_LavaEastUpperBoiler_Reset
    jsr FuncA_Room_MachineBoilerReset
    ldx #kUpperLeverDeviceIndex  ; param: device index
    jmp FuncA_Room_ResetLever
.ENDPROC

.PROC FuncA_Room_LavaEastLowerBoiler_Reset
    jsr FuncA_Room_MachineBoilerReset
    ldx #kLowerLeverDeviceIndex  ; param: device index
    jmp FuncA_Room_ResetLever
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_LavaEastBlaster_WriteReg
    cpx #$d
    beq _WriteU
    bge _WriteL
    jmp FuncA_Machine_BlasterWriteRegM
_WriteU:
    ldx #kMiddleLeverUDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteL:
    ldx #kMiddleLeverLDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_LavaEastUpperBoiler_WriteReg
    cpx #$c
    beq _WriteL
    jmp FuncA_Machine_BoilerWriteReg
_WriteL:
    ldx #kUpperLeverDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_LavaEastLowerBoiler_WriteReg
    ldx #kLowerLeverDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_LavaEastBlaster_TryMove
    lda #kBlasterMaxGoalX  ; param: max goal horz
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncA_Machine_LavaEastBlaster_Tick
    ldax #kBlasterMinPlatformLeft  ; param: min platform left
    jmp FuncA_Machine_BlasterTick
.ENDPROC

;;; TryAct implemention for the LavaEastUpperBoiler machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.PROC FuncA_Machine_LavaEastUpperBoiler_TryAct
    lda Ram_MachineGoalHorz_u8_arr + kUpperBoilerMachineIndex  ; valve angle
    mod #4
    cmp #2
    beq @lowerPipe
    @upperPipe:
    ldy #kUpperPipe1PlatformIndex
    jsr Func_EmitSteamUpFromPipe
    jmp FuncA_Machine_BoilerFinishEmittingSteam
    @lowerPipe:
    ldy #kUpperPipe2PlatformIndex
    jsr Func_EmitSteamRightFromPipe
    jmp FuncA_Machine_BoilerFinishEmittingSteam
.ENDPROC

;;; TryAct implemention for the LavaEastLowerBoiler machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.PROC FuncA_Machine_LavaEastLowerBoiler_TryAct
    ldy #kLowerPipe1PlatformIndex  ; param: platform index
    jsr Func_EmitSteamUpFromPipe
    jmp FuncA_Machine_BoilerFinishEmittingSteam
.ENDPROC

;;;=========================================================================;;;
