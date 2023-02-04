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
.INCLUDE "../machines/lift.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/gate.inc"
.INCLUDE "../platforms/stepstone.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Prison_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericMoveTowardGoalVert
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT FuncA_Objects_DrawStepstonePlatform
.IMPORT FuncC_Prison_DrawGatePlatform
.IMPORT FuncC_Prison_OpenGateAndFlipLever
.IMPORT FuncC_Prison_TickGatePlatform
.IMPORT Func_Noop
.IMPORT Func_SetOrClearFlag
.IMPORT Ppu_ChrObjPrison
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The machine index for the PrisonEastLift machine in this room.
kLiftMachineIndex = 0

;;; The platform index for the PrisonEastLift machine.
kLiftPlatformIndex = 0

;;; The initial and maximum permitted vertical goal values for the lift.
kLiftInitGoalY = 5
kLiftMaxGoalY = 6

;;; The maximum and initial Y-positions for the top of the lift platform.
kLiftMaxPlatformTop = $00e0
kLiftInitPlatformTop = kLiftMaxPlatformTop - kLiftInitGoalY * kBlockHeightPx

;;; The platform indices for the prison gates in this room.
kEastGatePlatformIndex  = 1
kLowerGatePlatformIndex = 2
kWestGatePlatformIndex  = 3

;;; The room block row for the top of each gate when it's shut.
kEastGateBlockRow = 9
kLowerGateBlockRow = 14
kWestGateBlockRow = 6

;;; The platform index for the stepstone in the bottom-center of the room.
kStepstonePlatformIndex = 4

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the levers in this room.
    EastGateLever_u1  .byte
    LowerGateLever_u1 .byte
    WestGateLever_u1  .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

.EXPORT DataC_Prison_East_sRoom
.PROC DataC_Prison_East_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0110
    d_byte Flags_bRoom, bRoom::Tall | eArea::Prison
    d_byte MinimapStartRow_u8, 2
    d_byte MinimapStartCol_u8, 8
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPrison)
    d_addr Tick_func_ptr, FuncC_Prison_East_TickRoom
    d_addr Draw_func_ptr, FuncC_Prison_East_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Prison_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    d_addr Enter_func_ptr, FuncC_Prison_East_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/prison_east.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kLiftMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::PrisonEastLift
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $a0
    d_byte ScrollGoalY_u8, $70
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kLiftPlatformIndex
    d_addr Init_func_ptr, FuncC_Prison_EastLift_Init
    d_addr ReadReg_func_ptr, FuncC_Prison_EastLift_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Prison_EastLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Prison_EastLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, FuncC_Prison_EastLift_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLiftPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLiftMachineWidthPx
    d_byte HeightPx_u8, kLiftMachineHeightPx
    d_word Left_i16, $0100
    d_word Top_i16, kLiftInitPlatformTop
    D_END
    .assert * - :- = kEastGatePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kGatePlatformWidthPx
    d_byte HeightPx_u8, kGatePlatformHeightPx
    d_word Left_i16, $01a3
    d_word Top_i16, kEastGateBlockRow * kBlockHeightPx
    D_END
    .assert * - :- = kLowerGatePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kGatePlatformWidthPx
    d_byte HeightPx_u8, kGatePlatformHeightPx
    d_word Left_i16, $00cd
    d_word Top_i16, kLowerGateBlockRow * kBlockHeightPx
    D_END
    .assert * - :- = kWestGatePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kGatePlatformWidthPx
    d_byte HeightPx_u8, kGatePlatformHeightPx
    d_word Left_i16, $0070
    d_word Top_i16, kWestGateBlockRow * kBlockHeightPx
    D_END
    ;; Stepping stone on left side of bottom-center prison cell:
    .assert * - :- = kStepstonePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kStepstonePlatformWidthPx
    d_byte HeightPx_u8, kStepstonePlatformHeightPx
    d_word Left_i16, $0099
    d_word Top_i16,  $012c
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0020
    d_word Top_i16,   $015e
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    ;; TODO: Add an orc guard.
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 3
    d_byte BlockCol_u8, 30
    d_byte Target_u8, sState::EastGateLever_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 17
    d_byte BlockCol_u8, 11
    d_byte Target_u8, sState::LowerGateLever_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 13
    d_byte Target_u8, sState::WestGateLever_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 15
    d_byte BlockCol_u8, 18
    d_byte Target_u8, kLiftMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::PrisonCrossroad
    d_byte SpawnBlock_u8, 8
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::PrisonEast  ; TODO
    d_byte SpawnBlock_u8, 7
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; Ener function for the PrisonEast room.
.PROC FuncC_Prison_East_EnterRoom
_EastGate:
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonEastEastGateOpen
    beq @shut
    ldy #sState::EastGateLever_u1  ; param: lever target
    ldx #kEastGatePlatformIndex  ; param: gate platform index
    jsr FuncC_Prison_OpenGateAndFlipLever
    @shut:
_LowerGate:
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonEastLowerGateShut
    bne @shut
    ldy #sState::LowerGateLever_u1  ; param: lever target
    ldx #kLowerGatePlatformIndex  ; param: gate platform index
    jsr FuncC_Prison_OpenGateAndFlipLever
    @shut:
_WestGate:
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonEastWestGateOpen
    bne @open
    rts
    @open:
    ldy #sState::WestGateLever_u1  ; param: lever target
    ldx #kWestGatePlatformIndex  ; param: gate platform index
    jmp FuncC_Prison_OpenGateAndFlipLever
.ENDPROC

;;; Tick function for the PrisonEast room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Prison_East_TickRoom
_EastGate:
    ;; Update the flag from the lever.
    ldx #eFlag::PrisonEastEastGateOpen  ; param: flag
    lda Zp_RoomState + sState::EastGateLever_u1  ; param: zero for clear
    jsr Func_SetOrClearFlag
    ;; Move the gate based on the lever.
    ldy Zp_RoomState + sState::EastGateLever_u1  ; param: zero for shut
    ldx #kEastGatePlatformIndex  ; param: gate platform index
    lda #kEastGateBlockRow  ; param: block row
    jsr FuncC_Prison_TickGatePlatform
_LowerGate:
    ;; Update the flag from the lever.
    ldx #eFlag::PrisonEastLowerGateShut  ; param: flag
    lda Zp_RoomState + sState::LowerGateLever_u1
    eor #1  ; param: zero for clear
    jsr Func_SetOrClearFlag
    ;; Move the gate based on the lever.
    ldy Zp_RoomState + sState::LowerGateLever_u1  ; param: zero for shut
    ldx #kLowerGatePlatformIndex  ; param: gate platform index
    lda #kLowerGateBlockRow  ; param: block row
    jsr FuncC_Prison_TickGatePlatform
_WestGate:
    ;; Update the flag from the lever.
    ldx #eFlag::PrisonEastWestGateOpen  ; param: flag
    lda Zp_RoomState + sState::WestGateLever_u1  ; param: zero for clear
    jsr Func_SetOrClearFlag
    ;; Move the gate based on the lever.
    ldy Zp_RoomState + sState::WestGateLever_u1  ; param: zero for shut
    ldx #kWestGatePlatformIndex  ; param: gate platform index
    lda #kWestGateBlockRow  ; param: block row
    jmp FuncC_Prison_TickGatePlatform
.ENDPROC

;;; Draw function for the PrisonEast room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Prison_East_DrawRoom
    ldx #kStepstonePlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawStepstonePlatform
    ldx #kEastGatePlatformIndex  ; param: platform index
    jsr FuncC_Prison_DrawGatePlatform
    ldx #kLowerGatePlatformIndex  ; param: platform index
    jsr FuncC_Prison_DrawGatePlatform
    ldx #kWestGatePlatformIndex  ; param: platform index
    jmp FuncC_Prison_DrawGatePlatform
.ENDPROC

.PROC FuncC_Prison_EastLift_Reset
    .assert * = FuncC_Prison_EastLift_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Prison_EastLift_Init
    lda #kLiftInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    rts
.ENDPROC

.PROC FuncC_Prison_EastLift_ReadReg
    lda #kLiftMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kLiftPlatformIndex
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Prison_EastLift_TryMove
    lda #kLiftMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncC_Prison_EastLift_Tick
    ldax #kLiftMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_GenericMoveTowardGoalVert  ; returns Z, N, and A
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;
