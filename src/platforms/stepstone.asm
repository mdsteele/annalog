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
.INCLUDE "../platform.inc"
.INCLUDE "stepstone.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Ram_PlatformType_ePlatform_arr

;;;=========================================================================;;;

;;; The OBJ palette number to use for drawing stepping stone platforms.
kPaletteObjStepstone = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a stepping stone platform.  If the platform type is not solid, draws
;;; nothing.
;;; @param X The platform index.
.EXPORT FuncA_Objects_DrawStepstonePlatform
.PROC FuncA_Objects_DrawStepstonePlatform
    lda Ram_PlatformType_ePlatform_arr, x
    cmp #ePlatform::Solid
    bne @done
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldy #kPaletteObjStepstone  ; param: object flags
    lda #kTileIdObjStepstone  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
