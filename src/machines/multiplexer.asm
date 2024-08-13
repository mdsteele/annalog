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

.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "multiplexer.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_DoubleIfResetting
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState2_byte_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; WriteReg implemention for a multiplexer machine's J register.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
;;; @param X The number of movable platforms.
.EXPORT FuncA_Machine_MultiplexerWriteRegJ
.PROC FuncA_Machine_MultiplexerWriteRegJ
    stx T0  ; number of movable platforms
    ldy Zp_MachineIndex_u8
    sta Ram_MachineState1_byte_arr, y  ; J register
    bpl @start  ; unconditional
    @loop:
    sbc T0  ; number of movable platforms
    @start:
    cmp T0  ; number of movable platforms
    bge @loop
    sta Ram_MachineState2_byte_arr, y  ; selected platform index
    rts
.ENDPROC

;;; Returns the speed at which the current multiplexer machine should move, in
;;; pixels per frame.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @return A The speed the machine should move at.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Machine_GetMultiplexerMoveSpeed
.PROC FuncA_Machine_GetMultiplexerMoveSpeed
    lda #2  ; param: base value
    jmp FuncA_Machine_DoubleIfResetting  ; preserves X, Y, and T0+; returns A
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a multiplexer machine with movable platforms.  The movable platform
;;; indices must be contiguous, starting at zero.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X The number of movable platforms.
.EXPORT FuncA_Objects_DrawMultiplexerMachine
.PROC FuncA_Objects_DrawMultiplexerMachine
    ;; If the machine is not halted, light up the selected platform.
    ldy Zp_MachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, y
    cmp #eMachine::Halted
    bne @running
    @halted:
    lda #$ff
    bne @setPlatformIndex  ; unconditional
    @running:
    lda Ram_MachineState2_byte_arr, y  ; selected platform index
    @setPlatformIndex:
    sta T2  ; lit platform index (or $ff for none)
_DrawMovablePlatforms:
    @loop:
    dex
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X and T0+
    lda #kTileIdObjMultiplexerFirst + 0
    cpx T2  ; lit platform index (or $ff for none)
    bne @setTileId
    lda #kTileIdObjMultiplexerFirst + 1
    @setTileId:
    pha  ; param: tile ID
    ldy #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X and T0+
    pla  ; param: tile ID
    ldy #kPaletteObjMachineLight | bObj::FlipV  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    txa
    bne @loop
_DrawMainPlatform:
    fall FuncA_Objects_DrawMultiplexerMachineMainPlatform
.ENDPROC

;;; Draws a multiplexer machine's main platform.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawMultiplexerMachineMainPlatform
.PROC FuncA_Objects_DrawMultiplexerMachineMainPlatform
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_GetMachineLightTileId  ; returns A
    ldy #kPaletteObjMachineLight  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;;=========================================================================;;;
