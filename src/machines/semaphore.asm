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

.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "semaphore.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_Draw1x2Shape
.IMPORT FuncA_Objects_Draw2x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState2_byte_arr
.IMPORT Ram_MachineState3_byte_arr
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; How many frames a semaphore machine spends for an ACT operation.
kSemaphoreActFrames = 16

;;; OBJ tile IDs used for drawing semaphore machines.
kTileIdObjSemaphoreFlagUpFirst   = kTileIdObjSemaphoreFirst + 0
kTileIdObjSemaphoreFlagDownFirst = kTileIdObjSemaphoreFirst + 2
kTileIdObjSemaphoreFlagMidFirst  = kTileIdObjSemaphoreFirst + 4
kTileIdObjSemaphoreDistSensor    = kTileIdObjSemaphoreFirst + 7

;;; The OBJ palette number used for drawing the flags of a semaphore machine.
kPaletteObjSemaphoreFlag = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Reset implemention for semaphore machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Room_MachineSemaphoreReset
.PROC FuncA_Room_MachineSemaphoreReset
    ldx Zp_MachineIndex_u8
    lda #0
    sta Ram_MachineGoalHorz_u8_arr, x  ; combination array index
    sta Ram_MachineGoalVert_u8_arr, x  ; vertical position goal
    ;; Clear MoveOut bits for each of the semaphore flags.
    lda Ram_MachineState1_byte_arr, x  ; lower bSemaphoreFlag
    and #<~bSemaphoreFlag::MoveOut
    sta Ram_MachineState1_byte_arr, x  ; lower bSemaphoreFlag
    lda Ram_MachineState2_byte_arr, x  ; upper bSemaphoreFlag
    and #<~bSemaphoreFlag::MoveOut
    sta Ram_MachineState2_byte_arr, x  ; upper bSemaphoreFlag
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; TryMove implemention for semaphore machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X The eDir value for the direction to move in.
.EXPORT FuncA_Machine_SemaphoreTryMove
.PROC FuncA_Machine_SemaphoreTryMove
    lda #1  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

;;; TryAct implemention for semaphore machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_SemaphoreTryAct
.PROC FuncA_Machine_SemaphoreTryAct
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x  ; vertical position goal
    beq @lowerFlag
    @upperFlag:
    lda Ram_MachineState2_byte_arr, x  ; upper bSemaphoreFlag
    eor #bSemaphoreFlag::MoveOut
    sta Ram_MachineState2_byte_arr, x  ; upper bSemaphoreFlag
    jmp @startWaiting
    @lowerFlag:
    lda Ram_MachineState1_byte_arr, x  ; lower bSemaphoreFlag
    eor #bSemaphoreFlag::MoveOut
    sta Ram_MachineState1_byte_arr, x  ; lower bSemaphoreFlag
    @startWaiting:
    lda #kSemaphoreActFrames  ; param: num frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

;;; Tick implemention for semaphore machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.EXPORT FuncA_Machine_SemaphoreTick
.PROC FuncA_Machine_SemaphoreTick
    ldx Zp_MachineIndex_u8
    lda #0
    sta T0  ; num components moved
_MoveUpperFlag:
    lda Ram_MachineState2_byte_arr, x  ; upper bSemaphoreFlag
    jsr FuncA_Machine_SemaphoreTickFlagState  ; preserves X, returns A
    sta Ram_MachineState2_byte_arr, x  ; upper bSemaphoreFlag
_MoveLowerFlag:
    lda Ram_MachineState1_byte_arr, x  ; lower bSemaphoreFlag
    jsr FuncA_Machine_SemaphoreTickFlagState  ; preserves X, returns A
    sta Ram_MachineState1_byte_arr, x  ; lower bSemaphoreFlag
_MoveVert:
    lda Ram_MachineGoalVert_u8_arr, x
    beq @moveDown
    @moveUp:
    lda Ram_MachineState3_byte_arr, x  ; vertical offset
    cmp #kBlockHeightPx
    bge @done
    inc Ram_MachineState3_byte_arr, x  ; vertical offset
    bne @moved  ; unconditional
    @moveDown:
    lda Ram_MachineState3_byte_arr, x  ; vertical offset
    beq @done
    dec Ram_MachineState3_byte_arr, x  ; vertical offset
    @moved:
    inc T0  ; num components moved
    @done:
_CheckIfDone:
    lda T0  ; num components moved
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;; Updates a bSemaphoreFlag value by one frame.
;;; @param A The current bSemaphoreFlag value for the flag.
;;; @return A The updated bSemaphoreFlag value.
;;; @preserve X
.PROC FuncA_Machine_SemaphoreTickFlagState
    tay
    .assert bSemaphoreFlag::MoveOut = $80, error
    bmi @moveOut
    @moveIn:
    ;; At this point, we know the MoveOut bit is clear.  If the whole
    ;; bSemaphoreFlag value is zero, then the angle must be zero.
    beq @done
    dey
    tya
    rts
    @moveOut:
    ;; At this point, we know the MoveOut bit is set.  If the AngleMask bits
    ;; are also all set, then the angle is at maximum.
    cmp #bSemaphoreFlag::MoveOut | bSemaphoreFlag::AngleMask
    bge @done
    iny
    tya
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a semaphore machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawSemaphoreMachine
.PROC FuncA_Objects_DrawSemaphoreMachine
_DrawUpperFlag:
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_MoveShapeUpOneTile
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState2_byte_arr, x  ; upper bSemaphoreFlag
    and #bSemaphoreFlag::AngleMask  ; param: flag angle
    jsr FuncA_Objects_DrawSemaphoreFlag
_DrawLowerFlag:
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_MoveShapeDownOneTile
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; lower bSemaphoreFlag
    and #bSemaphoreFlag::AngleMask  ; param: flag angle
    jsr FuncA_Objects_DrawSemaphoreFlag
_DrawActuator:
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    lda #kBlockWidthPx  ; param: offset
    jsr FuncA_Objects_MoveShapeLeftByA
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState3_byte_arr, x  ; param: vertical offset
    jsr FuncA_Objects_MoveShapeUpByA
    jsr FuncA_Objects_GetMachineLightTileId  ; returns A (param: tile ID)
    ldy #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    jsr FuncA_Objects_MoveShapeDownOneTile
    ldy #kPaletteObjMachineLight  ; param: object flags
    lda #kTileIdObjSemaphoreDistSensor  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;; Draws one flag on a semaphore machine.
;;; @prereq The shape position is set to the center-left of the flag.
;;; @param A The flag angle (0-15).
.PROC FuncA_Objects_DrawSemaphoreFlag
    cmp #11
    bge _FlagDown
    cmp #5
    bge _FlagMid
_FlagUp:
    ldy #kPaletteObjSemaphoreFlag  ; param: object flags
    lda #kTileIdObjSemaphoreFlagUpFirst  ; param: first tile ID
    jmp FuncA_Objects_Draw1x2Shape
_FlagMid:
    ldx #2
    @loop:
    ldy #kPaletteObjSemaphoreFlag  ; param: object flags
    lda _MidTiles_u8_arr3, x  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    lda #4  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    lda #4  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA  ; preserves X
    dex
    bpl @loop
    rts
_FlagDown:
    jsr FuncA_Objects_MoveShapeRightOneTile
    ldy #kPaletteObjSemaphoreFlag  ; param: object flags
    lda #kTileIdObjSemaphoreFlagDownFirst  ; param: first tile ID
    jmp FuncA_Objects_Draw2x1Shape
_MidTiles_u8_arr3:
    .byte kTileIdObjSemaphoreFlagMidFirst + 2
    .byte kTileIdObjSemaphoreFlagMidFirst + 1
    .byte kTileIdObjSemaphoreFlagMidFirst + 0
.ENDPROC

;;;=========================================================================;;;
