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
.INCLUDE "../ppu.inc"
.INCLUDE "rotor.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_Alloc2x2MachineShape
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeHorz
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_MoveShapeVert
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_Cosine
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePointHorz
.IMPORT Func_MovePointVert
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_SignedMult
.IMPORT Func_Sine
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; OBJ tile IDs used for drawing various parts of a rotor machine.
kTileIdObjRotorSpoke    = kTileIdObjRotorFirst + 0
kTileIdObjRotorNut      = kTileIdObjRotorFirst + 1
kTileIdObjRotorCarriage = kTileIdObjRotorFirst + 2
kTileIdObjRotorGear     = kTileIdObjRotorFirst + 3

;;; The OBJ palette number used for drawing parts of rotor machines.
kPaletteObjRotor = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Reads the "T" register for a rotor machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return A The value of the machine's "T" register (0-7).
.EXPORT Func_MachineRotorReadRegT
.PROC Func_MachineRotorReadRegT
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; rotation angle (0-255)
    add #$10
    div #$20
    rts
.ENDPROC

;;; Computes a polar vector with the specified angle and radius.  The radius
;;; will be equal to (Y * 127 / 256).
;;; @param A The angle.
;;; @param Y The radius multiplier (unsigned).
;;; @return T2 The X-offset (signed).
;;; @return T3 The Y-offset (signed).
;;; @preserve X, T4+
.PROC Func_GetRotorPolarOffset
    sty T3  ; radius multiplier
    ;; Compute 256 * the X-offset.
    pha  ; param: angle
    jsr Func_Cosine  ; preserves T0+, returns A (param: multiplicand)
    ldy T3  ; param: radius multiplier
    jsr Func_SignedMult  ; preserves T2+, returns YA
    ;; Divide by 256, rounding to the nearest integer.
    add #$80
    tya
    adc #0
    sta T2  ; X-offset (signed)
    ;; Compute 256 * the Y-offset.
    pla  ; param: angle
    jsr Func_Sine  ; preserves T0+, returns A (param: multiplicand)
    ldy T3  ; param: radius multiplier
    jsr Func_SignedMult  ; preserves T2+, returns YA
    ;; Divide by 256, rounding to the nearest integer.
    add #$80
    tya
    adc #0
    sta T3  ; Y-offset (signed)
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Moves a rotor carriage platform to a new position along a large rotor
;;; wheel.
;;; @param A The new rotation angle for the carriage.
;;; @param X The platform index for the center of the wheel.
;;; @param Y The platform index for the wheel carriage.
.EXPORT FuncA_Machine_RotorMoveCarriage
.PROC FuncA_Machine_RotorMoveCarriage
    stx T4  ; wheel center platform index
    sty T5  ; carriage platform index
    ;; Set Zp_Point* to the top-left corner of where the rotor carriage should
    ;; be.
    ldy #56  ; param: radius multiplier
    jsr Func_GetRotorPolarOffset  ; preserves T4+, returns T2 and T3
    ldy T4  ; param: wheel center platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X and T0+
    lda T2  ; X-offset (signed)
    sub #kRotorCarriageWidthPx / 2  ; param: signed offset
    jsr Func_MovePointHorz  ; preserves T0+
    lda T3  ; Y-offset (signed)
    sub #kRotorCarriageHeightPx / 2  ; param: signed offset
    jsr Func_MovePointVert  ; preserves T0+
    ;; Move the rotor carriage all the way to where it should be.
    ldx T5  ; param: carriage platform index
    lda #127  ; param: max distance
    jsr Func_MovePlatformLeftTowardPointX  ; preserves X
    lda #127  ; param: max distance
    jmp Func_MovePlatformTopTowardPointY
.ENDPROC

;;; Moves a rotor machine towards its goal angle.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.EXPORT FuncA_Machine_RotorTick
.PROC FuncA_Machine_RotorTick
    ldx Zp_MachineIndex_u8
_PickTurnSpeed:
    ldy #1
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Resetting
    bne @notResetting
    iny
    @notResetting:
    sty T0  ; turn speed
_MoveTowardsGoal:
    lda Ram_MachineGoalHorz_u8_arr, x  ; goal position (0-7)
    mul #$20
    sta T1  ; goal angle (0-255)
    sub Ram_MachineState1_byte_arr, x  ; rotation angle (0-255)
    beq _ReachedGoal
    bpl @increment
    @decrement:
    eor #$ff
    cmp T0  ; turn speed
    blt @moveToGoal
    lda Ram_MachineState1_byte_arr, x  ; rotation angle (0-255)
    sub T0  ; turn speed
    jmp @setAngle
    @increment:
    cmp T0  ; turn speed
    blt @moveToGoal
    lda Ram_MachineState1_byte_arr, x  ; rotation angle (0-255)
    add T0  ; turn speed
    jmp @setAngle
    @moveToGoal:
    lda T1  ; goal angle
    @setAngle:
    sta Ram_MachineState1_byte_arr, x  ; rotation angle (0-255)
    rts
_ReachedGoal:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws the main platform of a rotor machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawRotorMachine
.PROC FuncA_Objects_DrawRotorMachine
    lda #kPaletteObjRotor  ; param: object flags
    jsr FuncA_Objects_Alloc2x2MachineShape  ; returns C and Y
    bcs @done
    lda #kPaletteObjMachineLight
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kPaletteObjMachineLight | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kPaletteObjRotor | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kTileIdObjMachineCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdObjRotorGear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Draws a carriage platform that's attached to a large rotor wheel.
;;; @param X The platform index for the rotor carriage.
.EXPORT FuncA_Objects_DrawRotorCarriage
.PROC FuncA_Objects_DrawRotorCarriage
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    lda #kTileIdObjRotorCarriage  ; param: tile ID
    ldy #kPaletteObjRotor  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    jsr FuncA_Objects_MoveShapeRightOneTile
    lda #kTileIdObjRotorCarriage  ; param: tile ID
    ldy #kPaletteObjRotor | bObj::FlipH  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;; Draws the spokes on a large rotor wheel.
;;; @param A The wheel's rotation angle.
;;; @param X The platform index for the center of the wheel.
.EXPORT FuncA_Objects_DrawRotorWheelLarge
.PROC FuncA_Objects_DrawRotorWheelLarge
    pha  ; param: angle
    jsr FuncA_Objects_DrawRotorSpoke  ; preserves X
    pla  ; angle
    add #$40  ; param: angle
    pha  ; param: angle
    jsr FuncA_Objects_DrawRotorSpoke  ; preserves X
    pla  ; angle
    add #$40  ; param: angle
    pha  ; param: angle
    jsr FuncA_Objects_DrawRotorSpoke  ; preserves X
    pla  ; angle
    add #$40  ; param: angle
    jmp FuncA_Objects_DrawRotorSpoke
.ENDPROC

;;; Draws the nuts on a small rotor wheel.
;;; @param A The wheel's rotation angle.
;;; @param X The platform index for the center of the wheel.
.EXPORT FuncA_Objects_DrawRotorWheelSmall
.PROC FuncA_Objects_DrawRotorWheelSmall
    pha  ; param: angle
    jsr FuncA_Objects_DrawRotorNut  ; preserves X
    pla  ; angle
    add #$80  ; param: angle
    jmp FuncA_Objects_DrawRotorNut
.ENDPROC

;;; Draws one nut on a small rotor wheel.
;;; @param A The angle.
;;; @param X The platform index for the center of the wheel.
;;; @preserve X
.PROC FuncA_Objects_DrawRotorNut
    ldy #26  ; param: radius multiplier
    jsr FuncA_Objects_SetShapePosToRotorPolarTopLeft
    ldy #kPaletteObjRotor  ; param: object flags
    lda #kTileIdObjRotorNut  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
.ENDPROC

;;; Draws one spoke on a large rotor wheel.
;;; @param A The angle.
;;; @param X The platform index for the center of the wheel.
;;; @preserve X
.PROC FuncA_Objects_DrawRotorSpoke
    ldy #42  ; param: radius multiplier
    jsr FuncA_Objects_SetShapePosToRotorPolarTopLeft
    ldy #kPaletteObjRotor  ; param: object flags
    lda #kTileIdObjRotorSpoke  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
.ENDPROC

;;; Sets Zp_ShapePos* to the screen position of the top-left corner of a rotor
;;; nut/spoke.
;;; @param A The angle.
;;; @param Y The radius multiplier (unsigned).
;;; @param X The platform index for the center of the wheel.
;;; @preserve X
.PROC FuncA_Objects_SetShapePosToRotorPolarTopLeft
    jsr Func_GetRotorPolarOffset  ; preserves X, returns T2 and T3
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X and T0+
    lda T2  ; X-offset (signed)
    sub #kTileWidthPx / 2  ; param: signed offset
    jsr FuncA_Objects_MoveShapeHorz  ; preserves X and T0+
    lda T3  ; Y-offset (signed)
    sub #kTileWidthPx / 2  ; param: signed offset
    jmp FuncA_Objects_MoveShapeVert  ; preserves X
.ENDPROC

;;;=========================================================================;;;
