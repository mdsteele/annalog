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
.INCLUDE "gate.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft

;;;=========================================================================;;;

;;; OBJ tile IDs for drawing prison gate platforms.
kTileIdObjGateLeft  = kTileIdObjGateFirst + 0
kTileIdObjGateRight = kTileIdObjGateFirst + 1
kTileIdObjGateLock  = kTileIdObjGateFirst + 2

;;; The OBJ palette number to use for drawing prison gate platforms.
kPaletteObjGate = 0

;;; The bObj value to use for objects for prison gate platforms.
kGateObjFlags = kPaletteObjGate | bObj::Pri

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

;;; Draws a prison gate.
;;; @prereq PRGA_Objects is loaded.
;;; @param X The platform index.
.EXPORT FuncC_Prison_DrawGatePlatform
.PROC FuncC_Prison_DrawGatePlatform
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
_LeftSide:
    ldx #3
    bne @begin  ; unconditional
    @loop:
    jsr FuncA_Objects_MoveShapeDownOneTile
    @begin:
    ldy #kGateObjFlags  ; param: object flags
    lda #kTileIdObjGateLeft  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    dex
    bpl @loop
_RightSide:
    jsr FuncA_Objects_MoveShapeRightOneTile
    ldx #3
    bne @begin  ; unconditional
    @loop:
    jsr FuncA_Objects_MoveShapeUpOneTile
    @begin:
    ldy #kGateObjFlags  ; param: object flags
    lda _RightTileIds_u8_arr, x  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    dex
    bpl @loop
    rts
_RightTileIds_u8_arr:
    .byte kTileIdObjGateRight, kTileIdObjGateRight
    .byte kTileIdObjGateLock, kTileIdObjGateRight
.ENDPROC

;;;=========================================================================;;;
