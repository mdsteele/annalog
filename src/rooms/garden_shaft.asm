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
.INCLUDE "../actors/townsfolk.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/cannon.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_GardenAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_GardenAreaName_u8_arr
.IMPORT DataA_Room_Garden_sTileset
.IMPORT FuncA_Objects_DrawBridgeMachine
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MovePlatformLeftToward
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The machine indices for the GardenShaftLowerBridge and
;;; GardenShaftUpperBridge machines.
kLowerBridgeMachineIndex = 0
kUpperBridgeMachineIndex = 1
;;; The maximum permitted value for sState::BridgeAngle_u8.
kBridgeMaxAngle = $10
;;; How many frames the bridge machine spends per move operation.
kBridgeMoveUpCountdown = kBridgeMaxAngle + $20
kBridgeMoveDownCountdown = kBridgeMaxAngle / 2

;;; The number of movable segments in each drawbridge (i.e. NOT including the
;;; fixed segment).
.DEFINE kNumMovableLowerBridgeSegments 6
.DEFINE kNumMovableUpperBridgeSegments 4
;;; The platform indices for each bridge's fixed segment, which the rest of the
;;; bridge pivots around.
kLowerBridgePivotPlatformIndex = 0
kUpperBridgePivotPlatformIndex = kNumMovableLowerBridgeSegments + 1
;;; Room pixel positions for the top-left corner of the each bridge's fixed
;;; segment.
kLowerBridgePivotPosX = $0070
kLowerBridgePivotPosY = $0120
kUpperBridgePivotPosX = $0048
kUpperBridgePivotPosY = $0080

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers, indexed by machine index.
    Lever_u1_arr       .res 2
    ;; The current angle of each bridge (from 0 to kBridgeMaxAngle, inclusive),
    ;; indexed by machine index.
    BridgeAngle_u8_arr .res 2
    ;; The goal value of the GardenShaftLowerBridge machine's Y register.
    BridgeGoalY_u8_arr .res 2
.ENDSTRUCT

;;;=========================================================================;;;

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_Shaft_sRoom
.PROC DataC_Garden_Shaft_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 6
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjGarden)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_GardenAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_GardenAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/garden_shaft.room"
    .assert * - :- = 17 * 24, error
_Machines_sMachine_arr:
    .assert kLowerBridgeMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenShaftLowerBridge
    d_byte Conduit_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $90
    d_byte RegNames_u8_arr4, "L", 0, 0, "Y"
    d_addr Init_func_ptr, FuncC_Garden_ShaftBridge_Init
    d_addr ReadReg_func_ptr, FuncC_Garden_ShaftBridge_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, FuncC_Garden_ShaftBridge_TryMove
    d_addr TryAct_func_ptr, Func_MachineError
    d_addr Tick_func_ptr, FuncC_Garden_ShaftBridge_Tick
    d_addr Draw_func_ptr, FuncA_Objects_GardenShaftLowerBridge_Draw
    d_addr Reset_func_ptr, FuncC_Garden_ShaftBridge_Reset
    D_END
    .assert kUpperBridgeMachineIndex = 1, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenShaftUpperBridge
    d_byte Conduit_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $20
    d_byte RegNames_u8_arr4, "L", 0, 0, "Y"
    d_addr Init_func_ptr, FuncC_Garden_ShaftBridge_Init
    d_addr ReadReg_func_ptr, FuncC_Garden_ShaftBridge_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, FuncC_Garden_ShaftBridge_TryMove
    d_addr TryAct_func_ptr, Func_MachineError
    d_addr Tick_func_ptr, FuncC_Garden_ShaftBridge_Tick
    d_addr Draw_func_ptr, FuncA_Objects_GardenShaftUpperBridge_Draw
    d_addr Reset_func_ptr, FuncC_Garden_ShaftBridge_Reset
    D_END
_Platforms_sPlatform_arr:
:   .assert kLowerBridgePivotPlatformIndex = 0, error
    .repeat kNumMovableLowerBridgeSegments + 1, index
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kTileWidthPx
    d_byte HeightPx_u8, kTileHeightPx
    d_word Left_i16, kLowerBridgePivotPosX
    d_word Top_i16, kLowerBridgePivotPosY - kTileWidthPx * index
    D_END
    .endrepeat
    .repeat kNumMovableUpperBridgeSegments + 1, index
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kTileWidthPx
    d_byte HeightPx_u8, kTileHeightPx
    d_word Left_i16, kUpperBridgePivotPosX
    d_word Top_i16, kUpperBridgePivotPosY - kTileWidthPx * index
    D_END
    .endrepeat
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Vinebug
    d_byte TileRow_u8, 17
    d_byte TileCol_u8, 25
    d_byte Param_byte, 0
    D_END
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 2
    d_byte Target_u8, sState::Lever_u1_arr + kUpperBridgeMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 3
    d_byte Target_u8, kUpperBridgeMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 17
    d_byte BlockCol_u8, 2
    d_byte Target_u8, sState::Lever_u1_arr + kLowerBridgeMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 8
    d_byte Target_u8, kLowerBridgeMachineIndex
    D_END
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | bPassage::SameScreen | 0
    d_byte Destination_eRoom, eRoom::GardenTower
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | bPassage::SameScreen | 1
    d_byte Destination_eRoom, eRoom::GardenTower
    d_byte SpawnBlock_u8, 17
    D_END
.ENDPROC

.PROC FuncC_Garden_ShaftBridge_ReadReg
    ldx Zp_MachineIndex_u8
    cmp #$c
    beq @readL
    @readY:
    lda Ram_RoomState + sState::BridgeAngle_u8_arr, x
    cmp #kBridgeMaxAngle / 2  ; now carry bit is 1 if angle >= this
    lda #0
    rol a  ; shift in carry bit, now A is 0 or 1
    rts
    @readL:
    lda Ram_RoomState + sState::Lever_u1_arr, x
    rts
.ENDPROC

.PROC FuncC_Garden_ShaftBridge_TryMove
    cpx #eDir::Down
    beq @moveDown
    @moveUp:
    ldx Zp_MachineIndex_u8
    lda Ram_RoomState + sState::BridgeGoalY_u8_arr, x
    bne @error
    inc Ram_RoomState + sState::BridgeGoalY_u8_arr, x
    lda #kBridgeMoveUpCountdown
    clc  ; clear C to indicate success
    rts
    @moveDown:
    ldx Zp_MachineIndex_u8
    lda Ram_RoomState + sState::BridgeGoalY_u8_arr, x
    beq @error
    dec Ram_RoomState + sState::BridgeGoalY_u8_arr, x
    lda #kBridgeMoveDownCountdown
    clc  ; clear C to indicate success
    rts
    @error:
    sec  ; set C to indicate failure
    rts
.ENDPROC

.PROC FuncC_Garden_ShaftBridge_Tick
    ldx Zp_MachineIndex_u8
    lda Ram_RoomState + sState::BridgeGoalY_u8_arr, x
    beq _MoveDown
_MoveUp:
    ldy Ram_RoomState + sState::BridgeAngle_u8_arr, x
    cpy #kBridgeMaxAngle
    beq _Finished
    iny
    bne _SetAngle  ; unconditional
_MoveDown:
    ldy Ram_RoomState + sState::BridgeAngle_u8_arr, x
    beq _Finished
    dey
    dey
    bpl @noUnderflow
    ldy #0
    @noUnderflow:
_SetAngle:
    tya
    sta Ram_RoomState + sState::BridgeAngle_u8_arr, x
    ;; Loop through each consequtive pair of bridge segments, starting with the
    ;; fixed pivot segment and the first movable segment.
    ldy Zp_MachineIndex_u8
    ldx _PivotPlatformIndex_u8_arr, y
    @loop:
    ;; Position the next segment vertically relative to the previous segment.
    ldy Zp_MachineIndex_u8
    lda Ram_RoomState + sState::BridgeAngle_u8_arr, y
    tay
    lda Ram_PlatformTop_i16_0_arr, x
    sub _Delta_u8_arr, y
    sta Zp_PlatformGoal_i16 + 0
    lda Ram_PlatformTop_i16_1_arr, x
    sbc #0
    sta Zp_PlatformGoal_i16 + 1
    inx
    lda #127  ; param: max distance to move by
    jsr Func_MovePlatformTopToward  ; preserves X
    dex
    ;; Position the next segment horizontally relative to the previous segment.
    ldy Zp_MachineIndex_u8
    lda #kBridgeMaxAngle
    sub Ram_RoomState + sState::BridgeAngle_u8_arr, y
    tay
    lda Zp_MachineIndex_u8
    .assert kLowerBridgeMachineIndex = 0, error
    bne @upperBridge
    @lowerBridge:
    lda Ram_PlatformLeft_i16_0_arr, x
    sub _Delta_u8_arr, y
    sta Zp_PlatformGoal_i16 + 0
    lda Ram_PlatformLeft_i16_1_arr, x
    sbc #0
    sta Zp_PlatformGoal_i16 + 1
    jmp @moveHorz
    @upperBridge:
    lda Ram_PlatformLeft_i16_0_arr, x
    add _Delta_u8_arr, y
    sta Zp_PlatformGoal_i16 + 0
    lda Ram_PlatformLeft_i16_1_arr, x
    adc #0
    sta Zp_PlatformGoal_i16 + 1
    @moveHorz:
    inx
    lda #127  ; param: max distance to move by
    jsr Func_MovePlatformLeftToward  ; preserves X
    ;; Continue to the next pair of segments.
    ldy Zp_MachineIndex_u8
    lda _LastSegmentPlatformIndex_u8_arr, y
    sta Zp_Tmp1_byte
    cpx Zp_Tmp1_byte
    blt @loop
    rts
_Finished:
    jmp Func_MachineFinishResetting
_Delta_u8_arr:
    ;; [int(round(8 * sin(x * pi/32))) for x in range(0, 17)]
:   .byte 0, 1, 2, 2, 3, 4, 4, 5, 6, 6, 7, 7, 7, 8, 8, 8, 8
    .assert * - :- = kBridgeMaxAngle + 1, error
_PivotPlatformIndex_u8_arr:
    .assert kLowerBridgeMachineIndex = 0, error
    .byte kLowerBridgePivotPlatformIndex
    .assert kUpperBridgeMachineIndex = 1, error
    .byte kUpperBridgePivotPlatformIndex
_LastSegmentPlatformIndex_u8_arr:
    .assert kLowerBridgeMachineIndex = 0, error
    .byte kLowerBridgePivotPlatformIndex + kNumMovableLowerBridgeSegments
    .assert kUpperBridgeMachineIndex = 1, error
    .byte kUpperBridgePivotPlatformIndex + kNumMovableUpperBridgeSegments
.ENDPROC

.PROC FuncC_Garden_ShaftBridge_Init
    ldx Zp_MachineIndex_u8
    lda #kBridgeMaxAngle
    sta Ram_RoomState + sState::BridgeAngle_u8_arr, x
    .assert * = FuncC_Garden_ShaftBridge_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Garden_ShaftBridge_Reset
    ldx Zp_MachineIndex_u8
    lda #1
    sta Ram_RoomState + sState::BridgeGoalY_u8_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the GardenShaftLowerBridge machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.PROC FuncA_Objects_GardenShaftLowerBridge_Draw
    ldy #kLowerBridgePivotPlatformIndex  ; param: fixed segment platform index
    ldx #kLowerBridgePivotPlatformIndex + kNumMovableLowerBridgeSegments
    lda #bObj::FlipH  ; param: horz flip
    jmp FuncA_Objects_DrawBridgeMachine
.ENDPROC

;;; Allocates and populates OAM slots for the GardenShaftLowerBridge machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.PROC FuncA_Objects_GardenShaftUpperBridge_Draw
    ldy #kUpperBridgePivotPlatformIndex  ; param: fixed segment platform index
    ldx #kUpperBridgePivotPlatformIndex + kNumMovableUpperBridgeSegments
    lda #0  ; param: horz flip
    jmp FuncA_Objects_DrawBridgeMachine
.ENDPROC

;;;=========================================================================;;;
