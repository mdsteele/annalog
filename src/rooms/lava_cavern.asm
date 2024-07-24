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
.INCLUDE "../irq.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/lava.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Lava_sTileset
.IMPORT FuncA_Machine_BoilerFinishEmittingSteam
.IMPORT FuncA_Machine_BoilerTick
.IMPORT FuncA_Machine_BoilerWriteReg
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Objects_AnimateCircuitIfBreakerActive
.IMPORT FuncA_Objects_DrawBoilerMachine
.IMPORT FuncA_Objects_DrawBoilerValve
.IMPORT FuncA_Objects_SetUpLavaAnimationIrq
.IMPORT FuncA_Room_MachineBoilerReset
.IMPORT FuncA_Room_TurnSteamToSmokeIfConsoleOpen
.IMPORT FuncA_Terrain_FadeInShortRoomWithLava
.IMPORT Func_DistanceSensorRightDetectPoint
.IMPORT Func_EmitSteamUpFromPipe
.IMPORT Func_MachineBoilerReadReg
.IMPORT Func_Noop
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Ppu_ChrObjLava
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineGoalHorz_u8_arr

;;;=========================================================================;;;

;;; The actor index for the solifuge baddie in this room.
kSolifugeActorIndex = 0

;;; The machine index for the LavaCavernBoiler machine in this room.
kBoilerMachineIndex = 0

;;; Platform indices for various parts of the LavaCavernBoiler machine.
kBoilerPlatformIndex = 0
kSensorPlatformIndex = 1
kValvePlatformIndex  = 2
kPipe1PlatformIndex  = 3
kPipe2PlatformIndex  = 4

;;;=========================================================================;;;

.SEGMENT "PRGC_Lava"

.EXPORT DataC_Lava_Cavern_sRoom
.PROC DataC_Lava_Cavern_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $110
    d_byte Flags_bRoom, eArea::Lava
    d_byte MinimapStartRow_u8, 14
    d_byte MinimapStartCol_u8, 20
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
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, FuncA_Terrain_FadeInShortRoomWithLava
    d_addr Tick_func_ptr, FuncA_Room_TurnSteamToSmokeIfConsoleOpen
    d_addr Draw_func_ptr, FuncC_Lava_Cavern_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/lava_cavern.room"
    .assert * - :- = 33 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kBoilerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::LavaCavernBoiler
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteE
    d_byte Status_eDiagram, eDiagram::Boiler
    d_word ScrollGoalX_u16, $0028
    d_byte ScrollGoalY_u8, $30
    d_byte RegNames_u8_arr4, "D", 0, "V", 0
    d_byte MainPlatform_u8, kBoilerPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Lava_CavernBoiler_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BoilerWriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_LavaCavernBoiler_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BoilerTick
    d_addr Draw_func_ptr, FuncC_Lava_CavernBoiler_Draw
    d_addr Reset_func_ptr, FuncA_Room_MachineBoilerReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   ;; Boiler machine:
    .assert * - :- = kBoilerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $18
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0048
    d_word Top_i16,   $00a0
    D_END
    ;; Distance sensor:
    .assert * - :- = kSensorPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00b8
    d_word Top_i16,   $00b0
    D_END
    ;; Valve:
    .assert * - :- = kValvePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0064
    d_word Top_i16,   $00b4
    D_END
    ;; Left-hand pipe opening:
    .assert * - :- = kPipe1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00f8
    d_word Top_i16,   $00c0
    D_END
    ;; Right-hand pipe opening:
    .assert * - :- = kPipe2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0148
    d_word Top_i16,   $00c0
    D_END
    ;; Pipes leading from valve down into lava:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0058
    d_word Top_i16,   $00b8
    D_END
    ;; Upper ceiling spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $80
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0090
    d_word Top_i16,   $000a
    D_END
    ;; Lower ceiling spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00c0
    d_word Top_i16,   $007a
    D_END
    ;; Lava:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $210
    d_byte HeightPx_u8, kLavaPlatformHeightPx
    d_word Left_i16,   $0000
    d_word Top_i16, kLavaPlatformTopShortRoom
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kSolifugeActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadSolifuge
    d_word PosX_i16, $0138
    d_word PosY_i16, $00b8
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 25
    d_byte Target_byte, eRoom::BossLava
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 3
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kBoilerMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::LavaEast
    d_byte SpawnBlock_u8, 6
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Lava_CavernBoiler_ReadReg
    cmp #$c
    beq _ReadD
    jmp Func_MachineBoilerReadReg
_ReadD:
    lda #kBlockWidthPx * 9
    sta T0  ; param: minimum distance so far, in pixels
    ldy #kSensorPlatformIndex  ; param: distance sensor platform index
    jsr Func_SetPointToAvatarCenter  ; preserves Y and T0+
    jsr Func_DistanceSensorRightDetectPoint  ; preserves Y, returns T0
    lda Ram_ActorType_eActor_arr + kSolifugeActorIndex
    .assert eActor::None = 0, error
    beq @noSolifuge  ; the solifuge baddie is dead
    ldx #kSolifugeActorIndex  ; param: actor index
    jsr Func_SetPointToActorCenter  ; preserves Y and T0+
    jsr Func_DistanceSensorRightDetectPoint  ; returns T0
    @noSolifuge:
    lda T0  ; minimum distance so far, in pixels
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Lava_Cavern_DrawRoom
_AnimateCircuit:
    ldx #eFlag::BreakerLava  ; param: breaker flag
    jsr FuncA_Objects_AnimateCircuitIfBreakerActive
_SetUpIrq:
    jmp FuncA_Objects_SetUpLavaAnimationIrq
.ENDPROC

.PROC FuncC_Lava_CavernBoiler_Draw
    jsr FuncA_Objects_DrawBoilerMachine
    ldx #kValvePlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawBoilerValve
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_LavaCavernBoiler_TryAct
    ;; Determine which pipe the steam should exit out of.
    lda Ram_MachineGoalHorz_u8_arr + kBoilerMachineIndex  ; valve 1 angle
    and #$03
    tax  ; valve angle (in tau/8 units, mod 4)
    ldy _ValvePipePlatformIndex_u8_arr4, x  ; param: pipe platform index
    ;; Emit steam from the chosen pipe.
    jsr Func_EmitSteamUpFromPipe
    jmp FuncA_Machine_BoilerFinishEmittingSteam
_ValvePipePlatformIndex_u8_arr4:
    .byte kPipe1PlatformIndex
    .byte kPipe2PlatformIndex
    .byte kPipe2PlatformIndex
    .byte kPipe1PlatformIndex
.ENDPROC

;;;=========================================================================;;;
