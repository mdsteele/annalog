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
.INCLUDE "../actors/child.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../hud.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/jet.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"
.INCLUDE "elevator.inc"

.IMPORT DataA_Room_Factory_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_JetTick
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Machine_WriteToPhantomLever
.IMPORT FuncA_Objects_DrawJetMachine
.IMPORT FuncA_Room_ResetLever
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MachineJetReadRegY
.IMPORT Func_MarkMinimap
.IMPORT Func_Noop
.IMPORT Func_SetMachineIndex
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Ppu_ChrObjFactory
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachinePc_u8_arr
.IMPORT Ram_MachineRegA_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_MachineWait_u8_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_FloatingHud_bHud
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_Previous_eRoom
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for Bruno in this room.
kBrunoActorIndex = 0
;;; The talk devices indices for Bruno in this room.
kBrunoDeviceIndexLeft = 5
kBrunoDeviceIndexRight = 4

;;; The platform index for the zone where Bruno asks you to wait up.
kWaitUpZonePlatformIndex = 2

;;;=========================================================================;;;

;;; The indices of the vertical passages at the top and bottom of the room.
kUpperShaftPassageIndex = 4
kLowerShaftPassageIndex = 5

;;; The minimap column/row for the bottom of the upper shaft that leads into
;;; the top of this room.
kUpperShaftMinimapCol = 14
kUpperShaftMinimapBottomRow = 5

;;; The device indices for the levers in this room.
kUpperJetLowerLeverDeviceIndex = 1
kLowerJetUpperLeverDeviceIndex = 3

;;; The machine indices for the jet machines in this room.
kUpperJetMachineIndex = 0
kLowerJetMachineIndex = 1

;;; The platform indices for the jet machines in this room.
kUpperJetPlatformIndex = 0
kLowerJetPlatformIndex = 1

;;; The initial and maximum permitted values for the jets' Y-goals.
kUpperJetInitGoalY = 9
kUpperJetMaxGoalY = 9
kLowerJetInitGoalY = 0
kLowerJetMaxGoalY = 9

;;; The maximum and initial Y-positions for the top of the jet platforms.
.LINECONT +
kUpperJetMaxPlatformTop = $00a0
kUpperJetInitPlatformTop = \
    kUpperJetMaxPlatformTop - kUpperJetInitGoalY * kJetMoveInterval
kLowerJetMinPlatformTop = $0110
kLowerJetMaxPlatformTop = \
    kLowerJetMinPlatformTop + kLowerJetMaxGoalY * kJetMoveInterval
kLowerJetInitPlatformTop = \
    kLowerJetMaxPlatformTop - kLowerJetInitGoalY * kJetMoveInterval
.LINECONT -

.ASSERT .sizeof(sElevatorState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Factory"

.EXPORT DataC_Factory_Elevator_sRoom
.PROC DataC_Factory_Elevator_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | bRoom::ShareState | eArea::Factory
    d_byte MinimapStartRow_u8, 6
    d_byte MinimapStartCol_u8, 14
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjFactory)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Factory_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_FactoryElevator_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_FactoryElevator_TickRoom
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/factory_elevator.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kUpperJetMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CoreElevatorJet
    d_byte Breaker_eFlag, eFlag::BreakerCrypt
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::WriteCE
    d_byte Status_eDiagram, eDiagram::Jet
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, "U", 0, "L", "Y"
    d_byte MainPlatform_u8, kUpperJetPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_FactoryElevatorUpperJet_Init
    d_addr ReadReg_func_ptr, FuncC_Factory_ElevatorUpperJet_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_FactoryElevatorUpperJet_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_FactoryElevatorUpperJet_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_FactoryElevatorUpperJet_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawJetMachine
    d_addr Reset_func_ptr, FuncA_Room_FactoryElevatorUpperJet_Reset
    D_END
    .assert * - :- = kLowerJetMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MermaidElevatorJet
    d_byte Breaker_eFlag, eFlag::BreakerTemple
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::WriteCE
    d_byte Status_eDiagram, eDiagram::Jet
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $b0
    d_byte RegNames_u8_arr4, "U", 0, "L", "Y"
    d_byte MainPlatform_u8, kLowerJetPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_FactoryElevatorLowerJet_Init
    d_addr ReadReg_func_ptr, FuncC_Factory_ElevatorLowerJet_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_FactoryElevatorLowerJet_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_FactoryElevatorLowerJet_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_FactoryElevatorLowerJet_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawJetMachine
    d_addr Reset_func_ptr, FuncA_Room_FactoryElevatorLowerJet_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kUpperJetPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kJetPlatformWidthPx
    d_byte HeightPx_u8, kJetPlatformHeightPx
    d_word Left_i16,  $0080
    d_word Top_i16, $ffff & kUpperJetInitPlatformTop
    D_END
    .assert * - :- = kLowerJetPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kJetPlatformWidthPx
    d_byte HeightPx_u8, kJetPlatformHeightPx
    d_word Left_i16,  $0080
    d_word Top_i16, kLowerJetInitPlatformTop
    D_END
    .assert * - :- = kWaitUpZonePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $80
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0050
    d_word Top_i16,   $0100
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kBrunoActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $00d0
    d_word PosY_i16, $0128
    d_byte Param_byte, eNpcChild::BrunoStanding
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 4
    d_byte Target_byte, kUpperJetMachineIndex
    D_END
    .assert * - :- = kUpperJetLowerLeverDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 7
    d_byte Target_byte, sElevatorState::UpperJetLowerLever_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 16
    d_byte BlockCol_u8, 11
    d_byte Target_byte, kLowerJetMachineIndex
    D_END
    .assert * - :- = kLowerJetUpperLeverDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 16
    d_byte BlockCol_u8, 7
    d_byte Target_byte, sElevatorState::LowerJetUpperLever_u8
    D_END
    .assert * - :- = kBrunoDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 12
    d_byte Target_byte, eDialog::FactoryElevatorBrunoHi
    D_END
    .assert * - :- = kBrunoDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 13
    d_byte Target_byte, eDialog::FactoryElevatorBrunoHi
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::FactoryBridge
    d_byte SpawnBlock_u8, 8
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::FactoryFlower
    d_byte SpawnBlock_u8, 8
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::FactoryCenter
    d_byte SpawnBlock_u8, 19
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::FactoryPass
    d_byte SpawnBlock_u8, 19
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- = kUpperShaftPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Top | 0
    d_byte Destination_eRoom, eRoom::CoreElevator
    d_byte SpawnBlock_u8, 9
    d_byte SpawnAdjust_byte, $f0
    D_END
    .assert * - :- = kLowerShaftPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 0
    d_byte Destination_eRoom, eRoom::MermaidElevator
    d_byte SpawnBlock_u8, 9
    d_byte SpawnAdjust_byte, $2f
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Factory_ElevatorUpperJet_ReadReg
    cmp #$c
    beq @readU
    cmp #$e
    beq @readL
    @readY:
    ldax #kUpperJetMaxPlatformTop  ; param: max platform top
    jmp Func_MachineJetReadRegY  ; returns A
    @readU:
    lda Zp_RoomState + sElevatorState::UpperJetUpperLever_u8
    rts
    @readL:
    lda Zp_RoomState + sElevatorState::UpperJetLowerLever_u8
    rts
.ENDPROC

.PROC FuncC_Factory_ElevatorLowerJet_ReadReg
    cmp #$c
    beq @readU
    cmp #$e
    beq @readL
    @readY:
    ldax #kLowerJetMaxPlatformTop  ; param: max platform top
    jmp Func_MachineJetReadRegY  ; returns A
    @readU:
    lda Zp_RoomState + sElevatorState::LowerJetUpperLever_u8
    rts
    @readL:
    lda Zp_RoomState + sElevatorState::LowerJetLowerLever_u8
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncA_Room_FactoryElevator_EnterRoom
_MaybeRemoveBruno:
    pha  ; bSpawn value
    flag_bit Sram_ProgressFlags_arr, eFlag::FactoryPassLoweredRocks
    beq @removeBruno  ; Bruno isn't here yet
    flag_bit Sram_ProgressFlags_arr, eFlag::FactoryVaultTalkedToAlex
    beq @keepBruno  ; Bruno is still here
    @removeBruno:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kBrunoActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kBrunoDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kBrunoDeviceIndexRight
    @keepBruno:
    pla  ; bSpawn value
_CheckPassage:
    ;; Check which vertical shaft the player avatar entered from, if either.
    cmp #bSpawn::Passage | kUpperShaftPassageIndex
    beq _UpperShaft
    cmp #bSpawn::Passage | kLowerShaftPassageIndex
    beq _LowerShaft
_Return:
    rts
_UpperShaft:
    ;; Mark the bottom minimap cell of the shaft as explored.
    lda #kUpperShaftMinimapCol        ; param: minimap col
    ldy #kUpperShaftMinimapBottomRow  ; param: minimap row
    jsr Func_MarkMinimap
    ;; If the player avatar didn't actually come from the CoreElevator room
    ;; (e.g. due to respawning from the upper shaft after saving), stop.
    lda Zp_Previous_eRoom
    cmp #eRoom::CoreElevator
    bne _Return
    ;; Initialize the jet machine from its state in the previous room.
    ldx #kUpperJetMachineIndex  ; param: machine index
    ldya #$ffff & -$16f  ; param: vertical offset
    jmp FuncA_Room_InitElevatorJetState
_LowerShaft:
    ;; If the player avatar didn't actually come from the MermaidElevator room
    ;; (e.g. due to respawning from the lower shaft after saving), do nothing.
    lda Zp_Previous_eRoom
    cmp #eRoom::MermaidElevator
    bne _Return
    ;; Initialize the jet machine from its state in the previous room.
    ldx #kLowerJetMachineIndex  ; param: machine index
    ldya #$172  ; param: vertical offset
    jmp FuncA_Room_InitElevatorJetState
.ENDPROC

.PROC FuncA_Room_FactoryElevator_TickRoom
_StartCutscene:
    ;; If Bruno isn't here, or if Anna has already talked to Bruno, don't start
    ;; the cutscene.
    flag_bit Sram_ProgressFlags_arr, eFlag::FactoryPassLoweredRocks
    beq @done  ; Bruno isn't here yet
    flag_bit Sram_ProgressFlags_arr, eFlag::FactoryVaultTalkedToAlex
    bne @done  ; Bruno is no longer here
    flag_bit Sram_ProgressFlags_arr, eFlag::FactoryElevatorTalkedToBruno
    bne @done
    ;; If the player avatar isn't standing in the cutscene-starting zone, don't
    ;; start it yet.
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Airborne = bProc::Negative, error
    bmi @done
    jsr Func_SetPointToAvatarCenter
    ldy #kWaitUpZonePlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcc @done
    ;; Start the cutscene.
    lda #eCutscene::FactoryElevatorWaitUp
    sta Zp_Next_eCutscene
    @done:
_StoreElevatorState:
    ldx #kUpperJetMachineIndex  ; param: machine index
    lda Zp_AvatarPosY_i16 + 1
    beq FuncA_Room_StoreElevatorJetState
    ldx #kLowerJetMachineIndex  ; param: machine index
    .assert * = FuncA_Room_StoreElevatorJetState, error, "fallthrough"
.ENDPROC

;;; Stores state data for the specified jet machine in Zp_RoomState, so that it
;;; can be restored later by FuncA_Room_InitElevatorJetState.
;;; @param X The machine index for the jet.
.EXPORT FuncA_Room_StoreElevatorJetState
.PROC FuncA_Room_StoreElevatorJetState
    jsr Func_SetMachineIndex  ; preserves X
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay  ; jet machine's main platform index
    lda Ram_PlatformTop_i16_0_arr, y
    sta Zp_RoomState + sElevatorState::PrevJetPlatformTop_i16 + 0
    lda Ram_PlatformTop_i16_1_arr, y
    sta Zp_RoomState + sElevatorState::PrevJetPlatformTop_i16 + 1
    lda Ram_MachineStatus_eMachine_arr, x
    sta Zp_RoomState + sElevatorState::PrevJetStatus_eMachine
    lda Ram_MachinePc_u8_arr, x
    sta Zp_RoomState + sElevatorState::PrevJetPc_u8
    lda Ram_MachineRegA_u8_arr, x
    sta Zp_RoomState + sElevatorState::PrevJetRegA_u8
    lda Ram_MachineWait_u8_arr, x
    sta Zp_RoomState + sElevatorState::PrevJetWait_u8
    lda Ram_MachineGoalVert_u8_arr, x
    sta Zp_RoomState + sElevatorState::PrevJetGoalVert_u8
_Hud:
    bit Zp_FloatingHud_bHud
    .assert bHud::NoMachine = bProc::Overflow, error
    bvs @noHud
    lda Zp_FloatingHud_bHud
    and #bHud::IndexMask
    sta T0  ; floating HUD machine index
    cpx T0  ; floating HUD machine index
    beq @yesHud
    @noHud:
    lda #bHud::NoMachine
    bne @setHud  ; unconditional
    @yesHud:
    lda Zp_FloatingHud_bHud
    and #bHud::Hidden
    @setHud:
    sta Zp_RoomState + sElevatorState::PrevJetHud_bHud
    rts
.ENDPROC

;;; Initialises a jet machine from the state data stored in Zp_RoomState by
;;; FuncA_Room_StoreElevatorJetState.
;;; @param X The machine index for the jet.
;;; @param YA The signed offset to apply to the platform top position.
.EXPORT FuncA_Room_InitElevatorJetState
.PROC FuncA_Room_InitElevatorJetState
    stya T1T0  ; platform top offset
    jsr Func_SetMachineIndex  ; preserves X and T0+
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay  ; jet machine's main platform index
    ;; Adjust platform top position from previous room:
    lda Zp_RoomState + sElevatorState::PrevJetPlatformTop_i16 + 0
    add T0  ; platform top offset (lo)
    sta Ram_PlatformTop_i16_0_arr, y
    lda Zp_RoomState + sElevatorState::PrevJetPlatformTop_i16 + 1
    adc T1  ; platform top offset (hi)
    sta Ram_PlatformTop_i16_1_arr, y
    ;; Set platform bottom position relative to top.
    lda Ram_PlatformTop_i16_0_arr, y
    add #kJetPlatformHeightPx
    sta Ram_PlatformBottom_i16_0_arr, y
    lda Ram_PlatformTop_i16_1_arr, y
    adc #0
    sta Ram_PlatformBottom_i16_1_arr, y
    ;; Init machine state from previous room.
    lda Zp_RoomState + sElevatorState::PrevJetStatus_eMachine
    sta Ram_MachineStatus_eMachine_arr, x
    lda Zp_RoomState + sElevatorState::PrevJetPc_u8
    sta Ram_MachinePc_u8_arr, x
    lda Zp_RoomState + sElevatorState::PrevJetRegA_u8
    sta Ram_MachineRegA_u8_arr, x
    lda Zp_RoomState + sElevatorState::PrevJetWait_u8
    sta Ram_MachineWait_u8_arr, x
    lda Zp_RoomState + sElevatorState::PrevJetGoalVert_u8
    sta Ram_MachineGoalVert_u8_arr, x
    ;; Init HUD state from previous room.
    txa
    ora Zp_RoomState + sElevatorState::PrevJetHud_bHud
    sta Zp_FloatingHud_bHud
    rts
.ENDPROC

.PROC FuncA_Room_FactoryElevatorUpperJet_Reset
    lda #0
    sta Zp_RoomState + sElevatorState::UpperJetUpperLever_u8
    ldx #kUpperJetLowerLeverDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    .assert * = FuncA_Room_FactoryElevatorUpperJet_Init, error, "fallthrough"
.ENDPROC

.PROC FuncA_Room_FactoryElevatorUpperJet_Init
    lda #kUpperJetInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kUpperJetMachineIndex
    rts
.ENDPROC

.PROC FuncA_Room_FactoryElevatorLowerJet_Reset
    ldx #kLowerJetUpperLeverDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    lda #0
    sta Zp_RoomState + sElevatorState::LowerJetLowerLever_u8
    .assert * = FuncA_Room_FactoryElevatorLowerJet_Init, error, "fallthrough"
.ENDPROC

.PROC FuncA_Room_FactoryElevatorLowerJet_Init
    lda #kLowerJetInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLowerJetMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_FactoryElevatorUpperJet_WriteReg
    cpx #$e
    beq _WriteL
_WriteU:
    ldy #sElevatorState::UpperJetUpperLever_u8  ; param: phantom lever target
    jmp FuncA_Machine_WriteToPhantomLever
_WriteL:
    ldx #kUpperJetLowerLeverDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_FactoryElevatorUpperJet_TryMove
    lda #kUpperJetMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncA_Machine_FactoryElevatorUpperJet_Tick
    ldax #kUpperJetMaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_JetTick
.ENDPROC

.PROC FuncA_Machine_FactoryElevatorLowerJet_WriteReg
    cpx #$e
    beq _WriteL
_WriteU:
    ldx #kLowerJetUpperLeverDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteL:
    ldy #sElevatorState::LowerJetLowerLever_u8  ; param: phantom lever target
    jmp FuncA_Machine_WriteToPhantomLever
.ENDPROC

.PROC FuncA_Machine_FactoryElevatorLowerJet_TryMove
    lda #kLowerJetMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncA_Machine_FactoryElevatorLowerJet_Tick
    ldax #kLowerJetMaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_JetTick
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_FactoryElevatorWaitUp_sCutscene
.PROC DataA_Cutscene_FactoryElevatorWaitUp_sCutscene
    act_SetAvatarState 0
    act_SetAvatarVelX 0
    act_SetAvatarPose eAvatar::Standing
    act_RunDialog eDialog::FactoryElevatorBrunoWait
    act_WalkAvatar $00ba
    act_SetAvatarFlags kPaletteObjAvatarNormal | 0
    act_SetAvatarPose eAvatar::Standing
    act_WaitFrames 30
    act_RunDialog eDialog::FactoryElevatorBrunoHi
    act_ContinueExploring
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_FactoryElevatorBrunoWait_sDialog
.PROC DataA_Dialog_FactoryElevatorBrunoWait_sDialog
    dlg_Text ChildBruno, DataA_Text2_FactoryElevatorBruno_Wait_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_FactoryElevatorBrunoHi_sDialog
.PROC DataA_Dialog_FactoryElevatorBrunoHi_sDialog
    dlg_IfSet FactoryElevatorTalkedToBruno, _ALot_sDialog
_Whew_sDialog:
    dlg_Text ChildBruno, DataA_Text2_FactoryElevatorBruno_Hi1_u8_arr
_ALot_sDialog:
    dlg_Text ChildBruno, DataA_Text2_FactoryElevatorBruno_Hi2_u8_arr
    dlg_Text ChildBruno, DataA_Text2_FactoryElevatorBruno_Hi3_u8_arr
    dlg_Text ChildBruno, DataA_Text2_FactoryElevatorBruno_Hi4_u8_arr
    dlg_Quest FactoryElevatorTalkedToBruno
    dlg_Text ChildBruno, DataA_Text2_FactoryElevatorBruno_Hi5_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text2"

.PROC DataA_Text2_FactoryElevatorBruno_Wait_u8_arr
    .byte "Hey Anna, wait up!#"
.ENDPROC

.PROC DataA_Text2_FactoryElevatorBruno_Hi1_u8_arr
    .byte "Whew, glad you made it$"
    .byte "out of there OK, Anna.$"
    .byte "Alex asked me to keep$"
    .byte "an eye out for you.#"
.ENDPROC

.PROC DataA_Text2_FactoryElevatorBruno_Hi2_u8_arr
    .byte "A lot's been happening$"
    .byte "while you were gone.$"
    .byte "Orcs on the move, more$"
    .byte "machines turning on...#"
.ENDPROC

.PROC DataA_Text2_FactoryElevatorBruno_Hi3_u8_arr
    .byte "Queen Eirene seems$"
    .byte "pretty agitated, but$"
    .byte "she's still letting us$"
    .byte "stay for now.#"
.ENDPROC

.PROC DataA_Text2_FactoryElevatorBruno_Hi4_u8_arr
    .byte "And, uh...Alex found$"
    .byte "something weird. He$"
    .byte "wanted you to meet him$"
    .byte "when you got back.#"
.ENDPROC

.PROC DataA_Text2_FactoryElevatorBruno_Hi5_u8_arr
    .byte "I'll mark it on your$"
    .byte "map.#"
.ENDPROC

;;;=========================================================================;;;
