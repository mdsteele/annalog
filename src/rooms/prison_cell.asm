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
.INCLUDE "../dialog.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataC_Prison_AreaCells_u8_arr2_arr
.IMPORT DataC_Prison_AreaName_u8_arr
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_MachineError
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Ram_MachineState
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; The machine index for the PrisonCellBarrier machine in this room.
kBarrierMachineIndex = 0

;;; The platform index for the PrisonCellBarrier machine in this room.
kBarrierPlatformIndex = 0

;;; The initial value for sState::BarrierRegY_u8.
kBarrierInitRegY = 1

;;; The maximum permitted value for sState::BarrierRegY_u8.
kBarrierMaxRegY = 1

;;; How fast the PrisonCellBarrier platform moves, in pixels per frame.
kBarrierSpeed = 1

;;; How many frames the PrisonCellBarrier machine spends per move operation.
kBarrierCountdown = $10

;;; Various OBJ tile IDs used for drawing the PrisonCellBarrier machine.
kBarrierTileIdLightOff = $60
kBarrierTileIdLightOn  = $61
kBarrierTileIdCorner   = $63
kBarrierTileIdSurface  = $62

;;; Defines room-specific machine state data for this particular room.
.STRUCT sState
    ;; The current value of the PrisonCellBarrier machine's Y register.
    BarrierRegY_u8      .byte
    ;; The goal value of the PrisonCellBarrier machine's Y register; it will
    ;; keep moving until this is reached.
    BarrierGoalY_u8     .byte
    ;; Nonzero if the PrisonCellBarrier machine is moving; this is how many
    ;; more frames until it finishes the current move operation.
    BarrierCountdown_u8 .byte
    ;; If BarrierCountdown_u8 is nonzero, this is the direction the machine is
    ;; currently moving.
    BarrierMove_eDir    .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kMachineStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

.EXPORT DataC_Prison_Cell_sRoom
.PROC DataC_Prison_Cell_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $10
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 2
    d_byte MinimapStartCol_u8, 3
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataC_Prison_AreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataC_Prison_AreaCells_u8_arr2_arr
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, _Dialogs_sDialog_ptr_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/prison_cell.room"
    .assert * - :- = 18 * 16, error
_Machines_sMachine_arr:
    .assert kBarrierMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::PrisonCellBarrier
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Barrier
    d_byte RegNames_u8_arr5, 0, 0, 0, 0, "Y"
    d_addr Init_func_ptr, _Barrier_Init
    d_addr ReadReg_func_ptr, _Barrier_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, _Barrier_TryMove
    d_addr TryAct_func_ptr, Func_MachineError
    d_addr Tick_func_ptr, _Barrier_Tick
    d_addr Draw_func_ptr, FuncA_Objects_PrisonCellBarrier_Draw
    d_addr Reset_func_ptr, _Barrier_Reset
    d_byte Padding
    .res kMachinePadding
    D_END
_Platforms_sPlatform_arr:
    .assert kBarrierPlatformIndex = 0, error
    D_STRUCT sPlatform
    d_byte WidthPx_u8,  $10
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0020
    d_word Top_i16,   $0080
    D_END
    .byte 0
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 8
    d_byte Target_u8, 0
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 4
    d_byte Target_u8, kBarrierMachineIndex
    D_END
    .byte eDevice::None
_Dialogs_sDialog_ptr_arr:
    .addr _Dialog0_sDialog
_Dialog0_sDialog:
    .word ePortrait::Sign
    .byte "We were once a great$"
    .byte "civilization. Then one$"
    .byte "day, the orcs came...#"
    .byte 0
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_word PositionAdjust_i16, $ffff & -$20
    d_byte Destination_eRoom, eRoom::PrisonEscape
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_word PositionAdjust_i16, $50
    d_byte Destination_eRoom, eRoom::TallRoom
    D_END
_Barrier_Init:
    ;; Initialize the machine.
    lda #kBarrierInitRegY
    sta Ram_MachineState + sState::BarrierRegY_u8
    sta Ram_MachineState + sState::BarrierGoalY_u8
    lda #0
    sta Ram_MachineState + sState::BarrierCountdown_u8
    sta Ram_MachineState + sState::BarrierMove_eDir
    rts
_Barrier_ReadReg:
    lda Ram_MachineState + sState::BarrierRegY_u8
    rts
_Barrier_TryMove:
    lda Ram_MachineState + sState::BarrierCountdown_u8
    beq @ready
    sec  ; set C to indicate not ready yet
    rts
    @ready:
    lda Ram_MachineState + sState::BarrierRegY_u8
    cpx #eDir::Up
    beq @moveUp
    @moveDown:
    cmp #kBarrierMaxRegY
    bge @error
    tay
    iny
    bne @success  ; unconditional
    @moveUp:
    tay
    beq @error
    dey
    @success:
    sty Ram_MachineState + sState::BarrierGoalY_u8
    clc  ; clear C to indicate success
    rts
    @error:
    jmp Func_MachineError
_Barrier_Tick:
    lda Ram_MachineState + sState::BarrierCountdown_u8
    bne @continueMove
    ldy Ram_MachineState + sState::BarrierRegY_u8
    cpy Ram_MachineState + sState::BarrierGoalY_u8
    beq @finishResetting
    bge @beginMoveUp
    @beginMoveDown:
    ldx #eDir::Down
    iny
    bne @beginMove  ; unconditional
    @beginMoveUp:
    ldx #eDir::Up
    dey
    @beginMove:
    sty Ram_MachineState + sState::BarrierRegY_u8
    stx Ram_MachineState + sState::BarrierMove_eDir
    lda #kBarrierCountdown
    sta Ram_MachineState + sState::BarrierCountdown_u8
    @continueMove:
    dec Ram_MachineState + sState::BarrierCountdown_u8
    ldx Ram_MachineState + sState::BarrierMove_eDir
    cpx #eDir::Up
    beq @continueMoveUp
    @continueMoveDown:
    lda #kBarrierSpeed          ; param: move delta
    ldx #kBarrierPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
    @continueMoveUp:
    lda #$ff & -kBarrierSpeed   ; param: move delta
    ldx #kBarrierPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
    @finishResetting:
    lda Ram_MachineStatus_eMachine_arr + kBarrierMachineIndex
    cmp #eMachine::Resetting
    bne @notResetting
    lda #eMachine::Running
    sta Ram_MachineStatus_eMachine_arr + kBarrierMachineIndex
    @notResetting:
    rts
_Barrier_Reset:
    lda #kBarrierInitRegY
    sta Ram_MachineState + sState::BarrierGoalY_u8
    ;; TODO: Turn the machine around if it's currently moving up.
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_PrisonCellBarrier_Draw
    ldx #kBarrierPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
_TopHalf:
    ;; Allocate objects.
    jsr FuncA_Objects_MoveShapeDownOneTile
    jsr FuncA_Objects_MoveShapeRightOneTile
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kMachineLightPalette | bObj::FlipH | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kMachineLightPalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kBarrierTileIdCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kBarrierTileIdSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_BottomHalf:
    ;; Allocate objects.
    jsr FuncA_Objects_MoveShapeDownOneTile
    jsr FuncA_Objects_MoveShapeDownOneTile
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kMachineLightPalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipH | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kBarrierTileIdCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kBarrierTileIdSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda Ram_MachineStatus_eMachine_arr + kBarrierMachineIndex
    cmp #eMachine::Error
    bne @lightOff
    lda Zp_FrameCounter_u8
    and #$08
    beq @lightOff
    lda #kBarrierTileIdLightOn
    bne @setLight  ; unconditional
    @lightOff:
    lda #kBarrierTileIdLightOff
    @setLight:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
