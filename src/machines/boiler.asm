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

.INCLUDE "../actors/steam.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "boiler.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState2_byte_arr
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; How many frames a boiler machine spends per ACT operation.
kBoilerActCooldown = kSteamNumFrames + 16

;;; OBJ palette numbers used for drawing boiler machines.
kPaletteObjBoilerFlame = 1
kPaletteObjValve       = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; ReadReg implemention for boiler machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.EXPORT Func_MachineBoilerReadReg
.PROC Func_MachineBoilerReadReg
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; valve angle
    add #kBoilerValveAnimSlowdown / 2
    div #kBoilerValveAnimSlowdown
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Reset implemention for boiler machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Room_MachineBoilerReset
.PROC FuncA_Room_MachineBoilerReset
    ldx Zp_MachineIndex_u8
    lda #0
    sta Ram_MachineGoalHorz_u8_arr, x  ; valve goal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; WriteReg implemention for boiler machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
;;; @param X The register to write to ($c-$f).
.EXPORT FuncA_Machine_BoilerWriteReg
.PROC FuncA_Machine_BoilerWriteReg
    ldy Zp_MachineIndex_u8
    cmp Ram_MachineGoalHorz_u8_arr, y  ; valve goal
    beq @done
    sta Ram_MachineGoalHorz_u8_arr, y  ; valve goal
    jmp FuncA_Machine_StartWorking
    @done:
    rts
.ENDPROC

;;; Tick implemention for boiler machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.EXPORT FuncA_Machine_BoilerTick
.PROC FuncA_Machine_BoilerTick
    ldx Zp_MachineIndex_u8
_CoolDown:
    lda Ram_MachineState2_byte_arr, x  ; ignition cooldown
    beq @done
    dec Ram_MachineState2_byte_arr, x  ; ignition cooldown
    @done:
_Valve:
    lda Ram_MachineGoalHorz_u8_arr, x  ; valve goal
    mul #kBoilerValveAnimSlowdown
    cmp Ram_MachineState1_byte_arr, x  ; valve angle
    beq @reachedGoal
    blt @decrement
    @increment:
    inc Ram_MachineState1_byte_arr, x  ; valve angle
    rts
    @decrement:
    dec Ram_MachineState1_byte_arr, x  ; valve angle
    rts
    @reachedGoal:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

;;; Called at the end of a boiler machine's TryAct function after it has
;;; successfully emitted steam from one or more pipes.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_BoilerFinishEmittingSteam
.PROC FuncA_Machine_BoilerFinishEmittingSteam
    ;; TODO play a sound
    ldx Zp_MachineIndex_u8
    lda #kSteamNumFrames
    sta Ram_MachineState2_byte_arr, x  ; ignition cooldown
    lda #kBoilerActCooldown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a boiler machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawBoilerMachine
.PROC FuncA_Objects_DrawBoilerMachine
    ;; Draw the machine light.
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_GetMachineLightTileId  ; returns A (param: tile ID)
    ldy #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    ;; Draw the ignition flame (if active).
    ldx Zp_MachineIndex_u8
    ldy Ram_MachineState2_byte_arr, x  ; ignition cooldown
    beq @done
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves Y
    lda #9  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves Y
    tya  ; ignition cooldown
    div #2
    mod #2
    .assert kTileIdObjBoilerFlameFirst .mod 2 = 0, error
    ora #kTileIdObjBoilerFlameFirst  ; param: tile ID
    ldy #kPaletteObjBoilerFlame  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape
    @done:
    rts
.ENDPROC

;;; Draws the valve for a boiler machine.  The valve platform should be 8x8
;;; pixels and centered on the center of the valve.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X The platform index for the valve.
.EXPORT FuncA_Objects_DrawBoilerValve
.PROC FuncA_Objects_DrawBoilerValve
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldy Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, y  ; valve angle (in tau/32 units)
    fall FuncA_Objects_DrawValveShape
.ENDPROC

;;; Draws a valve for a boiler or multiplexer machine at the current shape
;;; position.
;;; @param A The angle of the valve (in tau/32 units)
;;; @preserve X
.EXPORT FuncA_Objects_DrawValveShape
.PROC FuncA_Objects_DrawValveShape
    div #2
    pha  ; valve angle (in tau/16 units)
    div #4
    mod #4
    tay  ; valve angle (in tau/4 units, mod 4)
    lda _Flags_bObj_arr4, y
    sta T0  ; object flags
    pla  ; valve angle (in tau/16 units)
    mod #8
    tay  ; valve angle (in tau/16 units, mod 8)
    lda _TileId_u8_arr8, y  ; param: tile ID
    ldy T0  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape
_TileId_u8_arr8:
    .byte kTileIdObjValveFirst + 0
    .byte kTileIdObjValveFirst + 1
    .byte kTileIdObjValveFirst + 2
    .byte kTileIdObjValveFirst + 3
    .byte kTileIdObjValveFirst + 4
    .byte kTileIdObjValveFirst + 3
    .byte kTileIdObjValveFirst + 2
    .byte kTileIdObjValveFirst + 1
_Flags_bObj_arr4:
    .byte 0, bObj::FlipH, bObj::FlipHV, bObj::FlipV
.ENDPROC

;;;=========================================================================;;;
