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

.IMPORT DataA_Pause_CoreAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_CoreAreaName_u8_arr
.IMPORT DataA_Room_Factory_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_JetTick
.IMPORT FuncA_Machine_LiftTryMove
.IMPORT FuncA_Objects_DrawJetMachine
.IMPORT Func_MachineJetReadRegY
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjFactory
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_RoomState

;;;=========================================================================;;;

;;; The machine index for the CoreElevatorJet machine in this room.
kJetMachineIndex = 0

;;; The platform index for the CoreElevatorJet machine in this room.
kJetPlatformIndex = 0

;;; The initial and maximum permitted values for the jet's Y-goal.
kJetInitGoalY = 0
kJetMaxGoalY = 9

;;; The maximum and initial Y-positions for the top of the jet platform.
kJetMinPlatformTop = $0060
kJetMaxPlatformTop = kJetMinPlatformTop + kJetMaxGoalY * kJetMoveInterval
kJetInitPlatformTop = kJetMaxPlatformTop - kJetInitGoalY * kJetMoveInterval

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the lever in this room.
    JetUpperLever_u1 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Core"

.EXPORT DataC_Core_Elevator_sRoom
.PROC DataC_Core_Elevator_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 3
    d_byte MinimapStartCol_u8, 14
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjFactory)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_CoreAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_CoreAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Factory_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/core_elevator.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kJetMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CoreElevatorJet
    d_byte Breaker_eFlag, eFlag::BreakerCity
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Jet
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, "U", 0, "L", "Y"
    d_byte MainPlatform_u8, kJetPlatformIndex
    d_addr Init_func_ptr, FuncC_Core_ElevatorJet_Init
    d_addr ReadReg_func_ptr, FuncC_Core_ElevatorJet_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Core_ElevatorJet_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Core_ElevatorJet_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawJetMachine
    d_addr Reset_func_ptr, FuncC_Core_ElevatorJet_Reset
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
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 12
    d_byte Target_u8, kJetMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 7
    d_byte Target_u8, sState::JetUpperLever_u1
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::CoreElevator  ; TODO
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CoreElevator  ; TODO
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 0
    d_byte Destination_eRoom, eRoom::FactoryElevator
    d_byte SpawnBlock_u8, 9
    D_END
.ENDPROC

.PROC FuncC_Core_ElevatorJet_Reset
    .assert * = FuncC_Core_ElevatorJet_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Core_ElevatorJet_Init
    lda #kJetInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kJetMachineIndex
    rts
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
    lda Ram_RoomState + sState::JetUpperLever_u1
    rts
    @readL:
    lda #0  ; TODO read lower lever (in room below)
    rts
.ENDPROC

.PROC FuncC_Core_ElevatorJet_TryMove
    lda #kJetMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_LiftTryMove
.ENDPROC

.PROC FuncC_Core_ElevatorJet_Tick
    ldax #kJetMaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_JetTick
.ENDPROC

;;;=========================================================================;;;
