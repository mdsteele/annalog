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

.SEGMENT "PRG8"

;;; Computes the cosine of an angle.
;;; @param A The input angle, measured in increments of tau/256.
;;; @return A 127 times the cosine of the angle (signed).
;;; @return N Set if the cosine is negative.
;;; @return Z Set if the cosine is zero.
;;; @preserve X, T0+
.EXPORT Func_Cosine
.PROC Func_Cosine
    add #$40
    .assert * = Func_Sine, error, "fallthrough"
.ENDPROC

;;; Computes the sine of an angle.
;;; @param A The input angle, measured in increments of tau/256.
;;; @return A 127 times the sine of the angle (signed).
;;; @return N Set if the sine is negative.
;;; @return Z Set if the sine is zero.
;;; @preserve X, T0+
.EXPORT Func_Sine
.PROC Func_Sine
    tay
    bmi _BottomHalf
_TopHalf:
    ;; At this point, A contains an angle value from 0-127 inclusive.  If it's
    ;; within 0-64 inclusive, then we can use it as an index into the table.
    cmp #65
    bcc @lookup
    ;; Otherwise, use (128 - A) as an index into the table.  We can compute
    ;; this by negating A and adding 128, which is equivalent to inverting all
    ;; eight bits and adding 129.  Or we could invert just the bottom seven
    ;; bits and add 1, which will guarantee that the carry bit ends up cleared,
    ;; which will turn out to be useful below.  Since we know from the BCC
    ;; above that the carry bit is currently set, we can add 1 with an ADC #0.
    eor #$7f
    adc #0  ; add 1 (carry bit is already set)
    @lookup:
    ;; At this point, the carry bit is now clear, regardless of which branch we
    ;; took (we'll make use of this guarantee in _BottomHalf, below).
    tay
    lda _Sine_i8_arr65, y
    rts
_BottomHalf:
    ;; At this point, A contains an angle value from 128-255 inclusive.
    and #$7f  ; subtract 128
    jsr _TopHalf  ; clears carry bit, returns A
    ;; Now negate A (by inverting bits and adding 1).
    eor #$ff
    adc #1  ; carry bit is already clear
    rts
_Sine_i8_arr65:
    ;; [0xff & int(round(127 * sin(x * pi / 128))) for x in range(65)]
:   .byte $00, $03, $06, $09, $0c, $10, $13, $16, $19, $1c, $1f, $22
    .byte $25, $28, $2b, $2e, $31, $33, $36, $39, $3c, $3f, $41, $44
    .byte $47, $49, $4c, $4e, $51, $53, $55, $58, $5a, $5c, $5e, $60
    .byte $62, $64, $66, $68, $6a, $6b, $6d, $6f, $70, $71, $73, $74
    .byte $75, $76, $78, $79, $7a, $7a, $7b, $7c, $7d, $7d, $7e, $7e
    .byte $7e, $7f, $7f, $7f, $7f
    .assert * - :- = 65, error
.ENDPROC

;;;=========================================================================;;;
