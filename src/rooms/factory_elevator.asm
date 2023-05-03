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

.IMPORT DataA_Room_Factory_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_JetTick
.IMPORT FuncA_Objects_DrawJetMachine
.IMPORT Func_MachineJetReadRegY
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjFactory
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The machine indices for the jet machines in this room.
kUpperJetMachineIndex = 0
kLowerJetMachineIndex = 1

;;; The platform indices for the jet machines in this room.
kUpperJetPlatformIndex = 0
kLowerJetPlatformIndex = 1

;;; The initial and maximum permitted values for the jets' Y-goals.
kUpperJetInitGoalY = 0
kUpperJetMaxGoalY = 9
kLowerJetInitGoalY = 0
kLowerJetMaxGoalY = 8

;;; The maximum and initial Y-positions for the top of the jet platforms.
.LINECONT +
kUpperJetMaxPlatformTop = $0090
kUpperJetInitPlatformTop = \
    kUpperJetMaxPlatformTop - kUpperJetInitGoalY * kJetMoveInterval
kLowerJetMinPlatformTop = $0130
kLowerJetMaxPlatformTop = \
    kLowerJetMinPlatformTop + kLowerJetMaxGoalY * kJetMoveInterval
kLowerJetInitPlatformTop = \
    kLowerJetMaxPlatformTop - kLowerJetInitGoalY * kJetMoveInterval
.LINECONT -

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the levers in this room.
    UpperJetLowerLever_u8 .byte
    LowerJetUpperLever_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Factory"

.EXPORT DataC_Factory_Elevator_sRoom
.PROC DataC_Factory_Elevator_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Factory
    d_byte MinimapStartRow_u8, 6
    d_byte MinimapStartCol_u8, 14
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjFactory)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Factory_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/factory_elevator.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kUpperJetMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CoreElevatorJet
    d_byte Breaker_eFlag, eFlag::BreakerCrypt
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Jet
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, "U", 0, "L", "Y"
    d_byte MainPlatform_u8, kUpperJetPlatformIndex
    d_addr Init_func_ptr, FuncC_Factory_ElevatorUpperJet_InitReset
    d_addr ReadReg_func_ptr, FuncC_Factory_ElevatorUpperJet_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop  ; TODO
    d_addr TryMove_func_ptr, FuncC_Factory_ElevatorUpperJet_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Factory_ElevatorUpperJet_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawJetMachine
    d_addr Reset_func_ptr, FuncC_Factory_ElevatorUpperJet_InitReset
    D_END
    .assert * - :- = kLowerJetMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MermaidElevatorJet
    d_byte Breaker_eFlag, eFlag::BreakerTemple
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Jet
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $b0
    d_byte RegNames_u8_arr4, "U", 0, "L", "Y"
    d_byte MainPlatform_u8, kLowerJetPlatformIndex
    d_addr Init_func_ptr, FuncC_Factory_ElevatorLowerJet_InitReset
    d_addr ReadReg_func_ptr, FuncC_Factory_ElevatorLowerJet_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop  ; TODO
    d_addr TryMove_func_ptr, FuncC_Factory_ElevatorLowerJet_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Factory_ElevatorLowerJet_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawJetMachine
    d_addr Reset_func_ptr, FuncC_Factory_ElevatorLowerJet_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kUpperJetPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kJetPlatformWidthPx
    d_byte HeightPx_u8, kJetPlatformHeightPx
    d_word Left_i16,  $0080
    d_word Top_i16, kUpperJetInitPlatformTop
    D_END
    .assert * - :- = kLowerJetPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kJetPlatformWidthPx
    d_byte HeightPx_u8, kJetPlatformHeightPx
    d_word Left_i16,  $0080
    d_word Top_i16, kLowerJetInitPlatformTop
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 3
    d_byte Target_u8, kUpperJetMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 7
    d_byte Target_u8, sState::UpperJetLowerLever_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 16
    d_byte BlockCol_u8, 15
    d_byte Target_u8, kLowerJetMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 7
    d_byte Target_u8, sState::LowerJetUpperLever_u8
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::FactoryBridge
    d_byte SpawnBlock_u8, 8
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::FactoryElevator  ; TODO
    d_byte SpawnBlock_u8, 8
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::FactoryCenter
    d_byte SpawnBlock_u8, 19
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::FactoryElevator  ; TODO
    d_byte SpawnBlock_u8, 19
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Top | 0
    d_byte Destination_eRoom, eRoom::CoreElevator
    d_byte SpawnBlock_u8, 9
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 0
    d_byte Destination_eRoom, eRoom::MermaidElevator
    d_byte SpawnBlock_u8, 9
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Factory_ElevatorUpperJet_InitReset
    ;; TODO: Reset upper lever (in room above)
    ;; TODO: Reset lower lever
    lda #kUpperJetInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kUpperJetMachineIndex
    rts
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
    lda #0  ; TODO read upper lever (in room above)
    rts
    @readL:
    lda Zp_RoomState + sState::UpperJetLowerLever_u8
    rts
.ENDPROC

.PROC FuncC_Factory_ElevatorUpperJet_TryMove
    lda #kUpperJetMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncC_Factory_ElevatorUpperJet_Tick
    ldax #kUpperJetMaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_JetTick
.ENDPROC

.PROC FuncC_Factory_ElevatorLowerJet_InitReset
    ;; TODO: Reset upper lever
    ;; TODO: Reset lower lever (in room below)
    lda #kLowerJetInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLowerJetMachineIndex
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
    lda Zp_RoomState + sState::LowerJetUpperLever_u8
    rts
    @readL:
    lda #0  ; TODO read lower lever (in room below)
    rts
.ENDPROC

.PROC FuncC_Factory_ElevatorLowerJet_TryMove
    lda #kLowerJetMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncC_Factory_ElevatorLowerJet_Tick
    ldax #kLowerJetMaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_JetTick
.ENDPROC

;;;=========================================================================;;;
