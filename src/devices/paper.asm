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

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft

;;;=========================================================================;;;

;;; The OBJ tile ID used for drawing paper devices.
kTileIdObjPaper = $06

;;; The OBJ palette number to use for drawing paper devices.
kPaletteObjPaper = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a paper device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawPaperDevice
.PROC FuncA_Objects_DrawPaperDevice
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
    lda #4  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    ldy #kPaletteObjPaper  ; param: object flags
    lda #kTileIdObjPaper  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;;=========================================================================;;;
