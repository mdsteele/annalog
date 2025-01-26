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
.INCLUDE "water.inc"

.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Returns the OBJ tile ID that should be used for drawing the surface of a
;;; movable water platform this frame.
;;; @return A The OBJ tile ID to use for water this frame.
;;; @preserve Y, T0+
.EXPORT FuncA_Objects_GetWaterObjTileId
.PROC FuncA_Objects_GetWaterObjTileId
    lda Zp_FrameCounter_u8
    div #8
    and #$03
    tax
    lda _WaterTileIds_u8_arr4, x
    rts
_WaterTileIds_u8_arr4:
    .byte kTileIdObjPlatformWaterFirst + 0
    .byte kTileIdObjPlatformWaterFirst + 1
    .byte kTileIdObjPlatformWaterFirst + 2
    .byte kTileIdObjPlatformWaterFirst + 1
.ENDPROC

;;;=========================================================================;;;
