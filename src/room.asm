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

.INCLUDE "charmap.inc"
.INCLUDE "machine.inc"
.INCLUDE "macros.inc"
.INCLUDE "oam.inc"
.INCLUDE "program.inc"
.INCLUDE "room.inc"

.IMPORT Func_AllocObjectsFor2x2Shape
.IMPORT Func_MachineError
.IMPORT Ram_MachineState
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_ScrollXHi_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; The machine index for the jail cell door machine in this room.
kJailCellDoorMachineIndex = 0

;;; The fixed room-space X-position for the center of the jail cell door
;;; machine, in pixels.
kJailCellDoorPosX = $0038

;;; The min, max, and initial room-space Y-positions for the center of the jail
;;; cell door machine, in pixels.
kJailCellDoorMinPosY = $78
kJailCellDoorMaxPosY = $88
kJailCellDoorInitPosY = kJailCellDoorMaxPosY

;;; How fast the jail cell door moves, in pixels per frame.
kJailCellDoorSpeed = 1

;;; The OBJ palette number to use for machines in this room.
kMachinePalette = 1

;;; Defines room-specific machine state data for this particular room.
.STRUCT sState
    LeverState_u1       .byte
    JailCellDoorRegY_u8 .byte
    JailCellDoorPosY_u8 .byte
    JailCellDoorVelY_i8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kMachineStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Room"

.PROC DataC_ShortRoomTerrain_arr
:   .incbin "out/data/short.room"
    .assert * - :- = 16 * 16, error
.ENDPROC

.PROC DataC_TallRoomTerrain_arr
:   .incbin "out/data/tall.room"
    .assert * - :- = 35 * 24, error
.ENDPROC

.EXPORT DataC_TallRoom_sRoom
.PROC DataC_TallRoom_sRoom
    D_STRUCT sRoom
    d_word MaxScrollX_u16, $130
    d_byte IsTall_bool, $ff
    d_addr TerrainData_ptr, DataC_TallRoomTerrain_arr
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, DataC_TallRoomMachines_sMachine_arr
    D_END
.ENDPROC

.PROC DataC_TallRoomMachines_sMachine_arr
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::JailCellDoor
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte RegNames_u8_arr6, "A", 0, "L", 0, 0, "Y"
    d_addr Init_func_ptr, _Init
    d_addr ReadReg_func_ptr, _ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, _TryMove
    d_addr TryAct_func_ptr, Func_MachineError
    d_addr Tick_func_ptr, _Tick
    d_addr Draw_func_ptr, _Draw
    d_addr Reset_func_ptr, _Reset
    d_byte Padding
    .res kMachinePadding
    D_END
_Init:
    lda #kJailCellDoorInitPosY
    sta Ram_MachineState + sState::JailCellDoorPosY_u8
    lda #0
    sta Ram_MachineState + sState::JailCellDoorRegY_u8
    sta Ram_MachineState + sState::JailCellDoorVelY_i8
    rts
_ReadReg:
    cmp #$c
    beq @readRegL
    cmp #$f
    beq @readRegY
    jmp Func_MachineError
    @readRegL:
    lda Ram_MachineState + sState::LeverState_u1
    rts
    @readRegY:
    lda Ram_MachineState + sState::JailCellDoorRegY_u8
    rts
_TryMove:
    lda Ram_MachineState + sState::JailCellDoorVelY_i8
    beq @ready
    sec  ; set C to indicate not ready yet
    rts
    @ready:
    ldy Ram_MachineState + sState::JailCellDoorRegY_u8
    cpx #eDir::Up
    beq @moveUp
    cpx #eDir::Down
    beq @moveDown
    @error:
    jmp Func_MachineError
    @moveUp:
    tya
    bne @error
    lda #$ff & -kJailCellDoorSpeed
    iny
    bne @setY  ; unconditional
    @moveDown:
    tya
    beq @error
    lda #kJailCellDoorSpeed
    dey
    @setY:
    sty Ram_MachineState + sState::JailCellDoorRegY_u8
    sta Ram_MachineState + sState::JailCellDoorVelY_i8
    clc  ; clear C to indicate success
    rts
_Tick:
    lda Ram_MachineState + sState::JailCellDoorVelY_i8
    beq @finishResetting
    add Ram_MachineState + sState::JailCellDoorPosY_u8
    sta Ram_MachineState + sState::JailCellDoorPosY_u8
    and #$0f
    cmp #$08
    bne @done
    lda #0
    sta Ram_MachineState + sState::JailCellDoorVelY_i8
    @finishResetting:
    lda Ram_MachineStatus_eMachine_arr + kJailCellDoorMachineIndex
    cmp #eMachine::Resetting
    bne @done
    lda #eMachine::Running
    sta Ram_MachineStatus_eMachine_arr + kJailCellDoorMachineIndex
    @done:
    rts
_Draw:
    ;; Calculate screen-space Y-position.
    lda Ram_MachineState + sState::JailCellDoorPosY_u8
    sub Zp_PpuScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda #0
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Calculate screen-space X-position.
    lda #<kJailCellDoorPosX
    sub Zp_PpuScrollX_u8
    sta Zp_ShapePosX_i16 + 0
    lda #>kJailCellDoorPosX
    sbc Zp_ScrollXHi_u8
    sta Zp_ShapePosX_i16 + 1
    ;; Allocate objects.
    jsr Func_AllocObjectsFor2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kMachinePalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kMachinePalette | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kMachinePalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #$1d
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda Ram_MachineStatus_eMachine_arr + kJailCellDoorMachineIndex
    cmp #eMachine::Error
    bne @lightOff
    lda Zp_FrameCounter_u8
    and #$08
    beq @lightOff
    lda #$1b
    bne @setLight  ; unconditional
    @lightOff:
    lda #$1a
    @setLight:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    @done:
    rts
_Reset:
    lda #0
    sta Ram_MachineState + sState::JailCellDoorRegY_u8
    lda Ram_MachineState + sState::JailCellDoorPosY_u8
    cmp #kJailCellDoorMaxPosY
    bge @done
    lda #kJailCellDoorSpeed
    sta Ram_MachineState + sState::JailCellDoorVelY_i8
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
