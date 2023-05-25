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

;;; Moves Zp_PointX_i16 by the given signed number of pixels (positive for
;;; right, negative for left).
;;; @param A The number of pixels to shift by (signed).
;;; @preserve X, Y, T0+
.EXPORT Func_MovePointHorz
.PROC Func_MovePointHorz
    ora #0
    bpl Func_MovePointRightByA  ; preserves X, Y, and T0+
    clc  ; param: carry bit
    bcc Func_MovePointHorzNegative  ; unconditional
.ENDPROC

;;; Moves Zp_PointX_i16 rightwards by the given number of pixels.
;;; @param A The number of pixels to shift right by (unsigned).
;;; @preserve X, Y, T0+
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
;;; @preserve X, Y, T0+
.EXPORT Func_MovePointLeftByA
.PROC Func_MovePointLeftByA
    eor #$ff  ; param: negative offset
    sec  ; param: carry bit
    .assert * = Func_MovePointHorzNegative, error, "fallthrough"
.ENDPROC

;;; Helper function for Func_MovePointHorz and Func_MovePointLeftByA.
;;; @param A The negative number of pixels to shift by.
;;; @param C The carry bit to include in the addition.
;;; @preserve X, Y, T0+
.PROC Func_MovePointHorzNegative
    adc Zp_PointX_i16 + 0
    sta Zp_PointX_i16 + 0
    lda Zp_PointX_i16 + 1
    adc #$ff
    sta Zp_PointX_i16 + 1
    rts
.ENDPROC

;;; Moves Zp_PointY_i16 by the given signed number of pixels (positive for
;;; down, negative for up).
;;; @param A The number of pixels to shift by (signed).
;;; @preserve X, T0+
.EXPORT Func_MovePointVert
.PROC Func_MovePointVert
    ora #0
    bpl Func_MovePointDownByA  ; preserves X, Y, and T0+
    clc  ; param: carry bit
    bcc Func_MovePointVertNegative  ; unconditional
.ENDPROC

;;; Moves Zp_PointX_i16 downwards by the given number of pixels.
;;; @param A The number of pixels to shift down by (unsigned).
;;; @preserve X, Y, T0+
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
;;; @preserve X, Y, T0+
.EXPORT Func_MovePointUpByA
.PROC Func_MovePointUpByA
    eor #$ff  ; param: negative offset
    sec  ; param: carry bit
    .assert * = Func_MovePointVertNegative, error, "fallthrough"
.ENDPROC

;;; Helper function for Func_MovePointVert and Func_MovePointUpByA.
;;; @param A The negative number of pixels to shift by.
;;; @param C The carry bit to include in the addition.
;;; @preserve X, Y, T0+
.PROC Func_MovePointVertNegative
    adc Zp_PointY_i16 + 0
    sta Zp_PointY_i16 + 0
    lda Zp_PointY_i16 + 1
    adc #$ff
    sta Zp_PointY_i16 + 1
    rts
.ENDPROC

;;;=========================================================================;;;
