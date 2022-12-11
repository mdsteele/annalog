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

.INCLUDE "macros.inc"

;;;=========================================================================;;;

.ZEROPAGE

;;; Room-space X/Y positions to use for various physics/collision functions.
.EXPORTZP Zp_PointX_i16
Zp_PointX_i16: .res 2
.EXPORTZP Zp_PointY_i16
Zp_PointY_i16: .res 2

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Moves Zp_PointX_i16 rightwards by the given number of pixels.
;;; @param A The number of pixels to shift right by (unsigned).
;;; @preserve X, Y, Zp_Tmp*
.EXPORT Func_MovePointRightByA
.PROC Func_MovePointRightByA
    add Zp_PointX_i16 + 0
    sta Zp_PointX_i16 + 0
    lda Zp_PointX_i16 + 1
    adc #0
    sta Zp_PointX_i16 + 1
    rts
.ENDPROC

;;; Moves Zp_PointX_i16 leftwards by the given number of pixels.
;;; @param A The number of pixels to shift left by (unsigned).
;;; @preserve X, Y, Zp_Tmp*
.EXPORT Func_MovePointLeftByA
.PROC Func_MovePointLeftByA
    eor #$ff
    sec
    adc Zp_PointX_i16 + 0
    sta Zp_PointX_i16 + 0
    lda Zp_PointX_i16 + 1
    adc #$ff
    sta Zp_PointX_i16 + 1
    rts
.ENDPROC

;;; Moves Zp_PointX_i16 downwards by the given number of pixels.
;;; @param A The number of pixels to shift down by (unsigned).
;;; @preserve X, Y, Zp_Tmp*
.EXPORT Func_MovePointDownByA
.PROC Func_MovePointDownByA
    add Zp_PointY_i16 + 0
    sta Zp_PointY_i16 + 0
    lda Zp_PointY_i16 + 1
    adc #0
    sta Zp_PointY_i16 + 1
    rts
.ENDPROC

;;; Moves Zp_PointY_i16 upwards by the given number of pixels.
;;; @param A The number of pixels to shift up by (unsigned).
;;; @preserve X, Y, Zp_Tmp*
.EXPORT Func_MovePointUpByA
.PROC Func_MovePointUpByA
    eor #$ff
    sec
    adc Zp_PointY_i16 + 0
    sta Zp_PointY_i16 + 0
    lda Zp_PointY_i16 + 1
    adc #$ff
    sta Zp_PointY_i16 + 1
    rts
.ENDPROC

;;;=========================================================================;;;
