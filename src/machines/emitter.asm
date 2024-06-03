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
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "emitter.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_DivMod
.IMPORT Func_GetRandomByte
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_SetPlatformTopLeftToPoint
.IMPORT Func_SetPointToPlatformTopLeft
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineSlowdown_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; How long an emitter machine's beam fires for after an ACT operation, in
;;; frames.
kEmitterBeamDuration = 10

;;; How long an emitter machine must wait after an ACT operation before it can
;;; continue executing, in frames.
kEmitterActCooldown = 30

;;; OBJ tiles IDs used for drawing emitter machines.
kTileIdObjEmitterBeamHorz   = kTileIdObjEmitterFirst + 0
kTileIdObjEmitterBeamVert   = kTileIdObjEmitterFirst + 1
kTileIdObjEmitterGlowXFirst = kTileIdObjEmitterFirst + 2
kTileIdObjEmitterGlowYFirst = kTileIdObjEmitterFirst + 4

;;; OBJ palette numbers used for drawing emitter machines.
kPaletteObjEmitterBeam = 1
kPaletteObjEmitterGlow = 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; ReadReg implementation for emitter machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return A The value of the emitter's position register (0-9).
.EXPORT Func_MachineEmitterReadReg
.PROC Func_MachineEmitterReadReg
    ldy Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, y  ; X/Y register value
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Init/Reset implementation for emitter-Y machines.
;;; @param A The initial value of the Y register (0-9).
.EXPORT FuncA_Room_MachineEmitterYInitReset
.PROC FuncA_Room_MachineEmitterYInitReset
    sta Ram_MachineState1_byte_arr + kEmitterYMachineIndex  ; Y register value
    pha  ; register value
    lda Ram_PlatformBottom_i16_0_arr + kEmitterRegionPlatformIndex
    sub Ram_PlatformTop_i16_0_arr + kEmitterRegionPlatformIndex
    div #kBlockHeightPx
    sta T2  ; num rows
    tay  ; num rows (param: divisor)
    pla  ; register value (param: dividend)
    jsr Func_DivMod  ; preserves T2+, returns remainder in A
    clc
    rsbc T2
    sta Ram_MachineGoalVert_u8_arr + kEmitterYMachineIndex  ; beam row
    bpl FuncA_Room_RemoveEmitterForcefield  ; unconditional
.ENDPROC

;;; Init/Reset implementation for emitter-X machines.
;;; @param A The initial value of the X register (0-9).
.EXPORT FuncA_Room_MachineEmitterXInitReset
.PROC FuncA_Room_MachineEmitterXInitReset
    sta Ram_MachineState1_byte_arr + kEmitterXMachineIndex  ; X register value
    sta Ram_MachineGoalHorz_u8_arr + kEmitterXMachineIndex  ; beam col
    fall FuncA_Room_RemoveEmitterForcefield
.ENDPROC

;;; Removes the forcefield (if any) created by the emitter machines.
.PROC FuncA_Room_RemoveEmitterForcefield
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kEmitterForcefieldPlatformIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; WriteReg implementation for emitter-X machines.
;;; @param A The value to write (0-9).
.EXPORT FuncA_Machine_EmitterXWriteReg
.PROC FuncA_Machine_EmitterXWriteReg
    sta Ram_MachineState1_byte_arr + kEmitterXMachineIndex  ; X register value
    sta Ram_MachineGoalHorz_u8_arr + kEmitterXMachineIndex  ; beam column
    rts
.ENDPROC

;;; WriteReg implementation for emitter-Y machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
.EXPORT FuncA_Machine_EmitterYWriteReg
.PROC FuncA_Machine_EmitterYWriteReg
    sta Ram_MachineState1_byte_arr + kEmitterYMachineIndex  ; Y register value
    pha  ; register value
    lda Ram_PlatformBottom_i16_0_arr + kEmitterRegionPlatformIndex
    sub Ram_PlatformTop_i16_0_arr + kEmitterRegionPlatformIndex
    div #kBlockHeightPx
    sta T2  ; num rows
    tay  ; num rows (param: divisor)
    pla  ; register value (param: dividend)
    jsr Func_DivMod  ; preserves T2+, returns remainder in A
    clc
    rsbc T2
    sta Ram_MachineGoalVert_u8_arr + kEmitterYMachineIndex  ; beam row
    rts
.ENDPROC

;;; TryAct implementation for emitter machines.
.EXPORT FuncA_Machine_EmitterTryAct
.PROC FuncA_Machine_EmitterTryAct
    ldy #kEmitterRegionPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformTopLeft
    ;; Start this emitter machine's beam firing.
    ldy Zp_MachineIndex_u8
    lda #kEmitterBeamDuration
    sta Ram_MachineSlowdown_u8_arr, y
    ;; Remove any existing forcefield.
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kEmitterForcefieldPlatformIndex
    ;; Only make a new forcefield if both emitters are firing at once.
    lda Ram_MachineSlowdown_u8_arr + kEmitterXMachineIndex
    beq _Finish
    lda Ram_MachineSlowdown_u8_arr + kEmitterYMachineIndex
    beq _Finish
    ;; Reposition the forcefield platform.
    lda Ram_MachineGoalHorz_u8_arr + kEmitterXMachineIndex  ; beam col
    mul #kBlockWidthPx
    jsr Func_MovePointRightByA
    lda Ram_MachineGoalVert_u8_arr + kEmitterYMachineIndex  ; beam row
    mul #kBlockHeightPx
    jsr Func_MovePointDownByA
    ldy #kEmitterForcefieldPlatformIndex  ; param: platform index
    jsr Func_SetPlatformTopLeftToPoint
    ;; Make the forcefield platform solid.
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kEmitterForcefieldPlatformIndex
    ;; TODO: if avatar is deep in platform, harm (kill?) it
    ;; TODO: push avatar out of platform
_Finish:
    ;; Make the emitter machine wait to cool down.
    lda #kEmitterActCooldown  ; param: num frames to wait
    jmp FuncA_Machine_StartWaiting
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a forcefield emitter machine that fires a vertical beam at various
;;; X-positions.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param Y The length of the beam, in tiles.
.EXPORT FuncA_Objects_DrawEmitterXMachine
.PROC FuncA_Objects_DrawEmitterXMachine
    sty T0  ; beam length in tiles
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves T0+
    lda #kTileHeightPx  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves T0+
    ldx Zp_MachineIndex_u8
    lda #9
    sub Ram_MachineGoalHorz_u8_arr, x
    mul #kBlockHeightPx
    adc #kTileWidthPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeLeftByA  ; preserves X and T0+
    lda Ram_MachineSlowdown_u8_arr, x
    beq _DrawGlow
_DrawBeam:
    jsr Func_GetRandomByte  ; preserves T0+, returns A
    ldy T0  ; beam length in tiles
    jsr Func_DivMod  ; returns remainder in A
    mul #kTileHeightPx  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    lda #kTileIdObjEmitterBeamVert  ; param: tile ID
    ldy #kPaletteObjEmitterBeam  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    jmp _DrawMachineLight
_DrawGlow:
    lda Zp_FrameCounter_u8
    div #4
    and #$01
    add #kTileIdObjEmitterGlowXFirst  ; param: tile ID
    ldy #kPaletteObjEmitterGlow  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
_DrawMachineLight:
    ldy #kPaletteObjMachineLight | bObj::FlipHV  ; param: object flags
    bne FuncA_Objects_DrawEmitterMachineLight  ; unconditional
.ENDPROC

;;; Draws a forcefield emitter machine that fires a horizontal beam at various
;;; Y-positions.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param Y The length of the beam, in tiles.
.EXPORT FuncA_Objects_DrawEmitterYMachine
.PROC FuncA_Objects_DrawEmitterYMachine
    sty T0  ; beam length in tiles
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves T0+
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves T0+
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x
    mul #kBlockHeightPx
    adc #kTileHeightPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X and T0+
    lda Ram_MachineSlowdown_u8_arr, x
    beq _DrawGlow
_DrawBeam:
    jsr Func_GetRandomByte  ; preserves T0+, returns A
    ldy T0  ; beam length in tiles
    jsr Func_DivMod  ; returns remainder in A
    mul #kTileWidthPx  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #kTileIdObjEmitterBeamHorz  ; param: tile ID
    ldy #kPaletteObjEmitterBeam  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    jmp _DrawMachineLight
_DrawGlow:
    lda Zp_FrameCounter_u8
    div #4
    and #$01
    add #kTileIdObjEmitterGlowYFirst  ; param: tile ID
    ldy #kPaletteObjEmitterGlow  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
_DrawMachineLight:
    ldy #kPaletteObjMachineLight | bObj::FlipH  ; param: object flags
    fall FuncA_Objects_DrawEmitterMachineLight
.ENDPROC

;;; Draws the machine light for a forcefield emitter machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param Y The object flags to use for the machine light.
.PROC FuncA_Objects_DrawEmitterMachineLight
    sty T0  ; object flags
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves T0+, returns A
    cmp #kTileIdObjMachineLightOn
    bne @done
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves T0+
    ldy T0  ; param: object flags
    lda #kTileIdObjEmitterLight  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
