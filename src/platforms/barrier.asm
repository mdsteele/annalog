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
.INCLUDE "barrier.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Ram_PlatformType_ePlatform_arr

;;;=========================================================================;;;

;;; The OBJ palette number to use for drawing laboratory barrier platforms.
kPaletteObjBarrier = 0

;;;=========================================================================;;;

.SEGMENT "PRGC_Shadow"

;;; Draws a laboratory barrier.  If the platform type is non-solid, draws
;;; nothing.
;;; @prereq PRGA_Objects is loaded.
;;; @param X The barrier platform index.
.EXPORT FuncC_Shadow_DrawBarrierPlatform
.PROC FuncC_Shadow_DrawBarrierPlatform
    ;; If the platform isn't solid, we're done.
    lda Ram_PlatformType_ePlatform_arr, x
    cmp #kFirstSolidPlatformType
    blt @return
    ;; Draw each object tile in the platform, starting from the top.
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx #3
    @loop:
    ldy #kPaletteObjBarrier | bObj::Pri  ; param: object flags
    lda _TileIds_u8_arr4, x  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    jsr FuncA_Objects_MoveShapeDownOneTile
    dex
    bpl @loop
    @return:
    rts
_TileIds_u8_arr4:
    .byte kTileIdObjBarrierFirst + 1
    .byte kTileIdObjBarrierFirst + 0
    .byte kTileIdObjBarrierFirst + 0
    .byte kTileIdObjBarrierFirst + 0
.ENDPROC

;;;=========================================================================;;;
