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
.INCLUDE "multiplexer.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_DoubleIfResetting
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

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

;;; Draws a multiplexer machine.  The movable platform indices must be
;;; contiguous, starting at zero.
;;; @param X The number of movable platforms.
.EXPORT FuncA_Objects_DrawMultiplexerMachine
.PROC FuncA_Objects_DrawMultiplexerMachine
_MovablePlatforms:
    @loop:
    dex
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    lda #kTileIdObjMultiplexerFirst  ; param: tile ID
    ldy #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    lda #kTileIdObjMultiplexerFirst  ; param: tile ID
    ldy #kPaletteObjMachineLight | bObj::FlipV  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    txa
    bne @loop
_MainPlatform:
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_GetMachineLightTileId  ; returns A
    ldy #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    jsr FuncA_Objects_MoveShapeDownOneTile
    lda #kTileIdObjMachineCorner  ; param: tile ID
    ldy #kPaletteObjMachineLight | bObj::FlipH  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;;=========================================================================;;;
