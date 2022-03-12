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
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataC_Prison_AreaCells_u8_arr2_arr
.IMPORT DataC_Prison_AreaName_u8_arr
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT Func_MachineError
.IMPORT Func_MovePlatformHorz
.IMPORT Func_Noop
.IMPORT Ram_MachineState
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORT Ram_PlatformExists_bool_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformRight_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_ScrollXHi_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; The machine index for the PrisonEscapeCarriage machine in this room.
kCarriageMachineIndex = 0

;;; The platform index for the PrisonEscapeCarriage machine in this room.
kCarriagePlatformIndex = 0

;;; The origin position of the PrisonEscapeCarriage platform, in room pixels.
kCarriageOriginX = $00f0
kCarriageOriginY = $0120

;;; The width and height of the PrisonEscapeCarriage platform, in pixels.
kCarriageWidthPx  = $20
kCarriageHeightPx = $10

;;; The maximum permitted value for sState::CarriageRegX_u8.
kCarriageMaxRegX = 8

;;; How fast the PrisonEscapeCarriage platform moves, in pixels per frame.
kCarriageSpeed = 1

;;; How many frames the PrisonEscapeCarriage machine spends per move operation.
kCarriageCountdown = kBlockWidthPx / kCarriageSpeed

;;; Various OBJ tile IDs used for drawing the PrisonEscapeCarriage machine.
kCarriageTileIdLightOff = $60
kCarriageTileIdLightOn  = $61
kCarriageTileIdCorner   = $63
kCarriageTileIdSurface  = $64

;;; Defines room-specific machine state data for this particular room.
.STRUCT sState
    ;; The current value of the PrisonEscapeCarriage machine's X register.
    CarriageRegX_u8      .byte
    ;; The goal value of the PrisonEscapeCarriage machine's X register; it will
    ;; keep moving until this is reached.
    CarriageGoalX_u8     .byte
    ;; Nonzero if the PrisonEscapeCarriage machine is moving; this is how many
    ;; more frames until it finishes the current move operation.
    CarriageCountdown_u8 .byte
    ;; If CarriageCountdown_u8 is nonzero, this is the direction the machine is
    ;; currently moving.
    CarriageMove_eDir    .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kMachineStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

.EXPORT DataC_Prison_Escape_sRoom
.PROC DataC_Prison_Escape_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0100
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 2
    d_byte MinimapStartCol_u8, 1
    d_byte MinimapWidth_u8, 2
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataC_Prison_AreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataC_Prison_AreaCells_u8_arr2_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, _Dialogs_sDialog_ptr_arr
    d_addr Exits_sDoor_arr_ptr, _Exits_sDoor_arr
    d_addr Init_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/prison_escape.room"
    .assert * - :- = 33 * 24, error
_Machines_sMachine_arr:
    .assert kCarriageMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::PrisonEscapeCarriage
    d_byte Flags_bMachine, bMachine::MoveH
    d_byte Status_eDiagram, eDiagram::Barrier  ; TODO: use a different diagram
    d_byte RegNames_u8_arr5, 0, 0, 0, "X", 0
    d_addr Init_func_ptr, _Carriage_Init
    d_addr ReadReg_func_ptr, _Carriage_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, _Carriage_TryMove
    d_addr TryAct_func_ptr, Func_MachineError
    d_addr Tick_func_ptr, _Carriage_Tick
    d_addr Draw_func_ptr, FuncA_Objects_PrisonEscapeCarriage_Draw
    d_addr Reset_func_ptr, _Carriage_Reset
    d_byte Padding
    .res kMachinePadding
    D_END
_Actors_sActor_arr:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Crawler
    d_byte TileRow_u8, 11
    d_byte TileCol_u8, 10
    d_byte State_byte, 0
    D_END
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 11
    d_byte Target_u8, 0
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 16
    d_byte Target_u8, kCarriageMachineIndex
    D_END
    .byte eDevice::None
_Dialogs_sDialog_ptr_arr:
    .addr _Dialog0_sDialog
_Dialog0_sDialog:
    .word ePortrait::Woman
    .byte "Of course, it wasn't$"
    .byte "the orcs that caused$"
    .byte "our downfall.#"
    .word ePortrait::Woman
    .byte "Their arrival was$"
    .byte "simply the inevitable$"
    .byte "result of our own$"
    .byte "failures.#"
    .byte 0
_Exits_sDoor_arr:
    D_STRUCT sDoor
    d_byte Exit_bDoor, eDoor::Eastern | 0
    d_word PositionAdjust_i16, $20
    d_byte Destination_eRoom, eRoom::PrisonCell
    D_END
    D_STRUCT sDoor
    d_byte Exit_bDoor, eDoor::Eastern | 1
    d_word PositionAdjust_i16, $30
    d_byte Destination_eRoom, eRoom::TallRoom
    D_END
_Carriage_Init:
    ;; Initialize the machine.
    lda #0
    sta Ram_MachineState + sState::CarriageRegX_u8
    sta Ram_MachineState + sState::CarriageGoalX_u8
    sta Ram_MachineState + sState::CarriageCountdown_u8
    sta Ram_MachineState + sState::CarriageMove_eDir
    ;; Initialize the platform for the machine.
    lda #$ff
    sta Ram_PlatformExists_bool_arr + kCarriagePlatformIndex
    ldax #kCarriageOriginX
    sta Ram_PlatformLeft_i16_1_arr + kCarriagePlatformIndex
    stx Ram_PlatformLeft_i16_0_arr + kCarriagePlatformIndex
    ldax #kCarriageOriginY
    sta Ram_PlatformTop_i16_1_arr + kCarriagePlatformIndex
    stx Ram_PlatformTop_i16_0_arr + kCarriagePlatformIndex
    ldax #kCarriageOriginX + kCarriageWidthPx
    sta Ram_PlatformRight_i16_1_arr + kCarriagePlatformIndex
    stx Ram_PlatformRight_i16_0_arr + kCarriagePlatformIndex
    ldax #kCarriageOriginY + kCarriageHeightPx
    sta Ram_PlatformBottom_i16_1_arr + kCarriagePlatformIndex
    stx Ram_PlatformBottom_i16_0_arr + kCarriagePlatformIndex
    rts
_Carriage_ReadReg:
    lda Ram_MachineState + sState::CarriageRegX_u8
    rts
_Carriage_TryMove:
    lda Ram_MachineState + sState::CarriageCountdown_u8
    beq @ready
    sec  ; set C to indicate not ready yet
    rts
    @ready:
    lda Ram_MachineState + sState::CarriageRegX_u8
    cpx #eDir::Left
    beq @moveLeft
    @moveRight:
    cmp #kCarriageMaxRegX
    bge @error
    tay
    iny
    bne @success  ; unconditional
    @moveLeft:
    tay
    beq @error
    dey
    @success:
    sty Ram_MachineState + sState::CarriageGoalX_u8
    clc  ; clear C to indicate success
    rts
    @error:
    jmp Func_MachineError
_Carriage_Tick:
    lda Ram_MachineState + sState::CarriageCountdown_u8
    bne @continueMove
    ldy Ram_MachineState + sState::CarriageRegX_u8
    cpy Ram_MachineState + sState::CarriageGoalX_u8
    beq @finishResetting
    bge @beginMoveLeft
    @beginMoveRight:
    ldx #eDir::Right
    iny
    bne @beginMove  ; unconditional
    @beginMoveLeft:
    ldx #eDir::Left
    dey
    @beginMove:
    sty Ram_MachineState + sState::CarriageRegX_u8
    stx Ram_MachineState + sState::CarriageMove_eDir
    lda #kCarriageCountdown
    sta Ram_MachineState + sState::CarriageCountdown_u8
    @continueMove:
    dec Ram_MachineState + sState::CarriageCountdown_u8
    ldx Ram_MachineState + sState::CarriageMove_eDir
    cpx #eDir::Left
    beq @continueMoveLeft
    @continueMoveRight:
    lda #kCarriageSpeed          ; param: move delta
    ldx #kCarriagePlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @continueMoveLeft:
    lda #$ff & -kCarriageSpeed   ; param: move delta
    ldx #kCarriagePlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @finishResetting:
    lda Ram_MachineStatus_eMachine_arr + kCarriageMachineIndex
    cmp #eMachine::Resetting
    bne @notResetting
    lda #eMachine::Running
    sta Ram_MachineStatus_eMachine_arr + kCarriageMachineIndex
    @notResetting:
    rts
_Carriage_Reset:
    lda #0
    sta Ram_MachineState + sState::CarriageGoalX_u8
    ;; TODO: Turn the machine around if it's currently moving right.
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_PrisonEscapeCarriage_Draw
    ;; Calculate top edge in screen space.
    lda Ram_PlatformTop_i16_0_arr + kCarriagePlatformIndex
    sub Zp_PpuScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda Ram_PlatformTop_i16_1_arr + kCarriagePlatformIndex
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Calculate left edge in screen space.
    lda Ram_PlatformLeft_i16_0_arr + kCarriagePlatformIndex
    sub Zp_PpuScrollX_u8
    sta Zp_ShapePosX_i16 + 0
    lda Ram_PlatformLeft_i16_1_arr + kCarriagePlatformIndex
    sbc Zp_ScrollXHi_u8
    sta Zp_ShapePosX_i16 + 1
    ;; Adjust Y-position.
    lda Zp_ShapePosY_i16 + 0
    add #kTileHeightPx
    sta Zp_ShapePosY_i16 + 0
    lda Zp_ShapePosY_i16 + 1
    adc #0
    sta Zp_ShapePosY_i16 + 1
_LeftHalf:
    ;; Adjust X-position.
    lda Zp_ShapePosX_i16 + 0
    add #kTileWidthPx
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    adc #0
    sta Zp_ShapePosX_i16 + 1
    ;; Allocate objects.
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kMachineLightPalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kCarriageTileIdCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kCarriageTileIdSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda Ram_MachineStatus_eMachine_arr + kCarriageMachineIndex
    cmp #eMachine::Error
    bne @lightOff
    lda Zp_FrameCounter_u8
    and #$08
    beq @lightOff
    lda #kCarriageTileIdLightOn
    bne @setLight  ; unconditional
    @lightOff:
    lda #kCarriageTileIdLightOff
    @setLight:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    @done:
_RightHalf:
    ;; Adjust X-position.
    lda Zp_ShapePosX_i16 + 0
    add #kTileWidthPx * 2
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    adc #0
    sta Zp_ShapePosX_i16 + 1
    ;; Allocate objects.
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kMachineLightPalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kCarriageTileIdSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kCarriageTileIdCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
