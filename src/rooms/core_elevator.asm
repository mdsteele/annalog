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
.INCLUDE "../machines/jet.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"
.INCLUDE "elevator.inc"

.IMPORT DataA_Room_Core_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_JetTick
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Machine_WriteToPhantomLever
.IMPORT FuncA_Objects_AnimateCircuitIfBreakerActive
.IMPORT FuncA_Objects_DrawJetMachine
.IMPORT FuncA_Room_InitElevatorJetState
.IMPORT FuncA_Room_ResetLever
.IMPORT FuncA_Room_StoreElevatorJetState
.IMPORT Func_MachineJetReadRegY
.IMPORT Func_MarkMinimap
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjFactory
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORTZP Zp_Previous_eRoom
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The index of the vertical passage at the bottom of the room.
kLowerShaftPassageIndex = 2

;;; The minimap column/row for the bottom of the vertical shaft that leads into
;;; this room.
kShaftMinimapCol = 14
kShaftMinimapBottomRow = 5

;;; The device index for the lever in this room.
kUpperJetUpperLeverDeviceIndex = 1

;;; The machine index for the CoreElevatorJet machine in this room.
kJetMachineIndex = 0

;;; The platform index for the CoreElevatorJet machine in this room.
kJetPlatformIndex = 0

;;; The initial and maximum permitted values for the jet's Y-goal.
kJetInitGoalY = 9
kJetMaxGoalY = 9

;;; The maximum and initial Y-positions for the top of the jet platform.
kJetMinPlatformTop = $0060
kJetMaxPlatformTop = kJetMinPlatformTop + kJetMaxGoalY * kJetMoveInterval
kJetInitPlatformTop = kJetMaxPlatformTop - kJetInitGoalY * kJetMoveInterval

.ASSERT .sizeof(sElevatorState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Core"

.EXPORT DataC_Core_Elevator_sRoom
.PROC DataC_Core_Elevator_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | bRoom::ShareState | eArea::Core
    d_byte MinimapStartRow_u8, 3
    d_byte MinimapStartCol_u8, 14
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjFactory)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_CoreElevator_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_CoreElevator_TickRoom
    d_addr Draw_func_ptr, FuncC_Core_Elevator_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/core_elevator.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kJetMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CoreElevatorJet
    d_byte Breaker_eFlag, eFlag::BreakerCrypt
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::WriteCE
    d_byte Status_eDiagram, eDiagram::Jet
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, "U", 0, "L", "Y"
    d_byte MainPlatform_u8, kJetPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_CoreElevatorJet_Init
    d_addr ReadReg_func_ptr, FuncC_Core_ElevatorJet_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_CoreElevatorJet_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_CoreElevatorJet_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_CoreElevatorJet_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawJetMachine
    d_addr Reset_func_ptr, FuncA_Room_CoreElevatorJet_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kJetPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kJetPlatformWidthPx
    d_byte HeightPx_u8, kJetPlatformHeightPx
    d_word Left_i16, $0080
    d_word Top_i16, kJetInitPlatformTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kJetFlameWidthPx
    d_byte HeightPx_u8, kJetFlameHeightPx
    d_word Left_i16,  $0080 + kJetFlameOffsetX
    d_word Top_i16, kJetInitPlatformTop + kJetFlameOffsetY
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 12
    d_byte Target_byte, kJetMachineIndex
    D_END
    .assert * - :- = kUpperJetUpperLeverDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 7
    d_byte Target_byte, sElevatorState::UpperJetUpperLever_u8
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::CoreFlower
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CoreEast
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- = kLowerShaftPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 0
    d_byte Destination_eRoom, eRoom::FactoryElevator
    d_byte SpawnBlock_u8, 9
    d_byte SpawnAdjust_byte, $f0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Core_Elevator_DrawRoom
    ldx #eFlag::BreakerLava  ; param: breaker flag
    jmp FuncA_Objects_AnimateCircuitIfBreakerActive
.ENDPROC

.PROC FuncC_Core_ElevatorJet_ReadReg
    cmp #$c
    beq @readU
    cmp #$e
    beq @readL
    @readY:
    ldax #kJetMaxPlatformTop  ; param: max platform top
    jmp Func_MachineJetReadRegY  ; returns A
    @readU:
    lda Zp_RoomState + sElevatorState::UpperJetUpperLever_u8
    rts
    @readL:
    lda Zp_RoomState + sElevatorState::UpperJetLowerLever_u8
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Called when the player avatar enters the MermaidElevator room.
;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncA_Room_CoreElevator_EnterRoom
    ;; If the player avatar didn't enter from the lower shaft, do nothing.
    cmp #bSpawn::Passage | kLowerShaftPassageIndex
    bne @done
    ;; Mark the bottom minimap cell of the shaft as explored.
    lda #kShaftMinimapCol        ; param: minimap col
    ldy #kShaftMinimapBottomRow  ; param: minimap row
    jsr Func_MarkMinimap
    ;; If the player avatar didn't actually come from the FactoryElevator room
    ;; (e.g. due to respawning from the lower shaft after saving), we're done.
    lda Zp_Previous_eRoom
    cmp #eRoom::FactoryElevator
    bne @done
    ;; Initialize the jet machine from its state in the previous room.
    ldx #kJetMachineIndex  ; param: machine index
    ldya #$0172  ; param: vertical offset
    jmp FuncA_Room_InitElevatorJetState
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_CoreElevator_TickRoom
    ldx #kJetMachineIndex  ; param: machine index
    jmp FuncA_Room_StoreElevatorJetState
.ENDPROC

.PROC FuncA_Room_CoreElevatorJet_Reset
    ldx #kUpperJetUpperLeverDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    lda #0
    sta Zp_RoomState + sElevatorState::UpperJetLowerLever_u8
    .assert * = FuncA_Room_CoreElevatorJet_Init, error, "fallthrough"
.ENDPROC

.PROC FuncA_Room_CoreElevatorJet_Init
    lda #kJetInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kJetMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_CoreElevatorJet_WriteReg
    cpx #$e
    beq _WriteL
_WriteU:
    ldx #kUpperJetUpperLeverDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteL:
    ldy #sElevatorState::UpperJetLowerLever_u8  ; param: phantom lever target
    jmp FuncA_Machine_WriteToPhantomLever
.ENDPROC

.PROC FuncA_Machine_CoreElevatorJet_TryMove
    lda #kJetMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncA_Machine_CoreElevatorJet_Tick
    ldax #kJetMaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_JetTick
.ENDPROC

;;;=========================================================================;;;
