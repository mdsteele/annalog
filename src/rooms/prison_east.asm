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
.INCLUDE "../actors/orc.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../devices/console.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/lift.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/gate.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Prison_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_LiftTick
.IMPORT FuncA_Machine_LiftTryMove
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT FuncA_Room_MachineResetHalt
.IMPORT FuncA_Room_MachineResetRun
.IMPORT FuncC_Prison_DrawGatePlatform
.IMPORT FuncC_Prison_OpenGateAndFlipLever
.IMPORT FuncC_Prison_TickGatePlatform
.IMPORT Func_ClearFlag
.IMPORT Func_Noop
.IMPORT Func_PlaySfxConsoleTurnOn
.IMPORT Func_SetFlag
.IMPORT Func_SetMachineIndex
.IMPORT Func_SetOrClearFlag
.IMPORT Ppu_ChrObjTown
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for the orc in this room.
kOrcActorIndex = 0

;;; The device index for the console in this room.
kConsoleDeviceIndex = 3

;;; The machine index for the PrisonEastLift machine in this room.
kLiftMachineIndex = 0

;;; The platform index for the PrisonEastLift machine.
kLiftPlatformIndex = 0

;;; The initial and maximum permitted vertical goal values for the lift.
kLiftInitGoalY = 4
kLiftMaxGoalY = 5

;;; The maximum and initial Y-positions for the top of the lift platform.
kLiftMaxPlatformTop = $00d0
kLiftInitPlatformTop = kLiftMaxPlatformTop - kLiftInitGoalY * kBlockHeightPx

;;; The platform indices for the prison gates in this room.
kEastGatePlatformIndex  = 1
kLowerGatePlatformIndex = 2
kWestGatePlatformIndex  = 3

;;; The room block row for the top of each gate when it's shut.
kEastGateBlockRow = 9
kLowerGateBlockRow = 14
kWestGateBlockRow = 6

;;; The room pixel X-position for the left side of the lower gate.
kLowerGateLeft = $00cd

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the levers in this room.
    EastGateLever_u8  .byte
    LowerGateLever_u8 .byte
    WestGateLever_u8  .byte
    ;; Timer that decrements each frame when nonzero.  When it decrements from
    ;; one to zero, it turns on the lift machine console.
    ConsoleDelay_u8   .byte
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
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTown)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Prison_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Prison_East_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Prison_East_TickRoom
    d_addr Draw_func_ptr, FuncC_Prison_East_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/prison_east.room"
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
    d_addr Init_func_ptr, FuncC_Prison_EastLift_InitReset
    d_addr ReadReg_func_ptr, FuncC_Prison_EastLift_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_PrisonEastLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_PrisonEastLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, FuncC_Prison_EastLift_InitReset
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
    d_word Left_i16, kLowerGateLeft
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
    ;; Half-height block near lift machine:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00f0
    d_word Top_i16,   $00a0
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0030
    d_word Top_i16,   $015e
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kOrcActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadOrc
    d_word PosX_i16, $011c
    d_word PosY_i16, $00f8
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 3
    d_byte BlockCol_u8, 30
    d_byte Target_byte, sState::EastGateLever_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 17
    d_byte BlockCol_u8, 12
    d_byte Target_byte, sState::LowerGateLever_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 13
    d_byte Target_byte, sState::WestGateLever_u8
    D_END
    .assert * - :- = kConsoleDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 15
    d_byte BlockCol_u8, 18
    d_byte Target_byte, kLiftMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::PrisonCrossroad
    d_byte SpawnBlock_u8, 8
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CoreWest
    d_byte SpawnBlock_u8, 7
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::PrisonLower
    d_byte SpawnBlock_u8, 20
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; Enter function for the PrisonEast room.
.PROC FuncC_Prison_East_EnterRoom
_InitOrc:
    ;; Once the kids have been rescued, remove the orc from this room.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperFreedKids
    beq @keepOrc
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kOrcActorIndex
    .assert eActor::None = 0, error
    beq @done  ; unconditional
    @keepOrc:
    ;; If the orc is trapped, move it inside the cell.  Otherwise, disable the
    ;; lift machine until the orc gets trapped.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonEastOrcTrapped
    bne @orcIsTrapped
    @disableLift:
    lda #eMachine::Halted
    sta Ram_MachineStatus_eMachine_arr + kLiftMachineIndex
    lda #eDevice::Placeholder
    sta Ram_DeviceType_eDevice_arr + kConsoleDeviceIndex
    .assert eDevice::Placeholder > 0, error
    bne @done  ; unconditional
    @orcIsTrapped:
    ldya #kLowerGateLeft - kOrcTrappedDistance
    sta Ram_ActorPosX_i16_0_arr + kOrcActorIndex
    sty Ram_ActorPosX_i16_1_arr + kOrcActorIndex
    lda #eBadOrc::TrapPounding
    sta Ram_ActorState1_byte_arr + kOrcActorIndex  ; current eBadOrc mode
    @done:
_EastGate:
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonEastEastGateOpen
    beq @shut
    ldy #sState::EastGateLever_u8  ; param: lever target
    ldx #kEastGatePlatformIndex  ; param: gate platform index
    jsr FuncC_Prison_OpenGateAndFlipLever
    @shut:
_LowerGate:
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonEastLowerGateOpen
    beq @shut
    ldy #sState::LowerGateLever_u8  ; param: lever target
    ldx #kLowerGatePlatformIndex  ; param: gate platform index
    jsr FuncC_Prison_OpenGateAndFlipLever
    @shut:
_WestGate:
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonEastWestGateOpen
    beq @shut
    ldy #sState::WestGateLever_u8  ; param: lever target
    ldx #kWestGatePlatformIndex  ; param: gate platform index
    jmp FuncC_Prison_OpenGateAndFlipLever
    @shut:
    rts
.ENDPROC

;;; Tick function for the PrisonEast room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Prison_East_TickRoom
_ConsoleDelay:
    lda Zp_RoomState + sState::ConsoleDelay_u8
    beq @done
    dec Zp_RoomState + sState::ConsoleDelay_u8
    bne @done
    jsr Func_PlaySfxConsoleTurnOn
    lda #eDevice::ConsoleFloor
    sta Ram_DeviceType_eDevice_arr + kConsoleDeviceIndex
    lda #kConsoleAnimCountdown
    sta Ram_DeviceAnim_u8_arr + kConsoleDeviceIndex
    ;; Let the machine run again.
    ldx #kLiftMachineIndex  ; param: machine index
    jsr Func_SetMachineIndex
    jsr FuncA_Room_MachineResetRun
    @done:
_EastGate:
    ;; Update the flag from the lever.
    ldx #eFlag::PrisonEastEastGateOpen  ; param: flag
    lda Zp_RoomState + sState::EastGateLever_u8  ; param: zero for clear
    jsr Func_SetOrClearFlag
    ;; Move the gate based on the lever.
    ldy Zp_RoomState + sState::EastGateLever_u8  ; param: zero for shut
    ldx #kEastGatePlatformIndex  ; param: gate platform index
    lda #kEastGateBlockRow  ; param: block row
    jsr FuncC_Prison_TickGatePlatform
_LowerGate:
    ;; Update the flag from the lever.
    ldx #eFlag::PrisonEastLowerGateOpen  ; param: flag
    lda Zp_RoomState + sState::LowerGateLever_u8  ; param: zero for clear
    jsr Func_SetOrClearFlag
    ;; Move the gate based on the lever.
    ldy Zp_RoomState + sState::LowerGateLever_u8  ; param: zero for shut
    ldx #kLowerGatePlatformIndex  ; param: gate platform index
    lda #kLowerGateBlockRow  ; param: block row
    jsr FuncC_Prison_TickGatePlatform
_WestGate:
    ;; Update the flag from the lever.
    ldx #eFlag::PrisonEastWestGateOpen  ; param: flag
    lda Zp_RoomState + sState::WestGateLever_u8  ; param: zero for clear
    jsr Func_SetOrClearFlag
    ;; Move the gate based on the lever.
    ldy Zp_RoomState + sState::WestGateLever_u8  ; param: zero for shut
    ldx #kWestGatePlatformIndex  ; param: gate platform index
    lda #kWestGateBlockRow  ; param: block row
    jsr FuncC_Prison_TickGatePlatform
_CheckIfOrcIsGone:
    ;; Once the kids have been rescued, the orc is gone from this room, so we
    ;; don't need to check for whether it's trapped, and the lift machine just
    ;; stays enabled regardless of the state of the lower prison gate.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperFreedKids
    bne _Return  ; orc is gone
_CheckIfOrcIsTrapped:
    ldx #eFlag::PrisonEastOrcTrapped  ; param: flag
    ;; If the lower gate is open, mark the orc as not trapped.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonEastLowerGateOpen
    bne _OrcIsNotTrapped
    ;; Otherwise, if the orc is to the right of the gate, it's not trapped.
    lda #<kLowerGateLeft
    cmp Ram_ActorPosX_i16_0_arr + kOrcActorIndex
    lda #>kLowerGateLeft
    sbc Ram_ActorPosX_i16_1_arr + kOrcActorIndex
    bmi _OrcIsNotTrapped
_OrcIsTrapped:
    jsr Func_SetFlag  ; sets C if flag was already set
    ;; Set the orc's mode to trapped mode.
    bcs @doneOrc
    lda #eBadOrc::TrapSurprised
    sta Ram_ActorState1_byte_arr + kOrcActorIndex  ; current eBadOrc mode
    lda #45
    sta Ram_ActorState2_byte_arr + kOrcActorIndex  ; mode timer
    lda #0
    sta Ram_ActorFlags_bObj_arr + kOrcActorIndex
    @doneOrc:
    ;; If the console is disabled, enable it.
    lda Ram_DeviceType_eDevice_arr + kConsoleDeviceIndex
    cmp #eDevice::ConsoleFloor
    beq _Return  ; console is already enabled
    lda Zp_RoomState + sState::ConsoleDelay_u8
    bne _Return  ; console is already about to be enabled
    lda #30
    sta Zp_RoomState + sState::ConsoleDelay_u8
_Return:
    rts
_OrcIsNotTrapped:
    jsr Func_ClearFlag  ; sets C if flag was already cleared
    ;; Set the orc's mode to start patrolling.
    bcs @doneOrc
    lda #eBadOrc::Patrolling
    sta Ram_ActorState1_byte_arr + kOrcActorIndex  ; current eBadOrc mode
    lda #120
    sta Ram_ActorState2_byte_arr + kOrcActorIndex  ; mode timer
    @doneOrc:
    ;; If the console is currently enabled, disable it and reset/halt the lift
    ;; machine.
    lda #eDevice::Placeholder
    cmp Ram_DeviceType_eDevice_arr + kConsoleDeviceIndex
    beq _Return
    sta Ram_DeviceType_eDevice_arr + kConsoleDeviceIndex
    ldx #kLiftMachineIndex  ; param: machine index
    .assert kLiftMachineIndex = 0, error
    stx Zp_RoomState + sState::ConsoleDelay_u8
    jsr Func_SetMachineIndex
    jmp FuncA_Room_MachineResetHalt
.ENDPROC

;;; Draw function for the PrisonEast room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Prison_East_DrawRoom
    ldx #kEastGatePlatformIndex  ; param: platform index
    jsr FuncC_Prison_DrawGatePlatform
    ldx #kLowerGatePlatformIndex  ; param: platform index
    jsr FuncC_Prison_DrawGatePlatform
    ldx #kWestGatePlatformIndex  ; param: platform index
    jmp FuncC_Prison_DrawGatePlatform
.ENDPROC

.PROC FuncC_Prison_EastLift_InitReset
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

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_PrisonEastLift_TryMove
    lda #kLiftMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_LiftTryMove
.ENDPROC

.PROC FuncA_Machine_PrisonEastLift_Tick
    ldax #kLiftMaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_LiftTick
.ENDPROC

;;;=========================================================================;;;
