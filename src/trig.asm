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
    fall Func_Sine
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

;;; Computes the arc tangent of Y/X, taking the signs of X and Y into account.
;;; @param A The (signed) horizontal vector component.
;;; @param Y The (signed) vertical vector component.
;;; @return A The angle, measured in increments of tau/256.
;;; @preserve X, T4+
.EXPORT Func_SignedAtan2
.PROC Func_SignedAtan2
    pha  ; Xpos
    ;; This function is implemented in terms of Func_UnsignedAtan2, which only
    ;; works for Quadrant 1 (non-negative Xpos and Ypos).  Let T by the the
    ;; angle returned by Func_UnsignedAtan2 for |Xpos| and |Ypos|; then the
    ;; results we want for each quadrant are:
    ;;     * Q1 (+Xpos/+Ypos): T
    ;;     * Q2 (-Xpos/+Ypos): $80 - T
    ;;     * Q3 (-Xpos/-Ypos): $80 + T
    ;;     * Q4 (+Xpos/-Ypos): -T
    ;; Thus, if exactly one of Xpos or Ypos is negative, then we need to negate
    ;; the output angle, and if Xpos is negative, we need to offset the angle
    ;; by $80.
    lda #0
    sta T3  ; angle offset
    sta T2  ; number of negative inputs
_CheckVertSign:
    ;; Check if the vertical component is negative.
    tya  ; Ypos
    bpl @done
    inc T2  ; number of negative inputs
    ;; Set Ypos to its absolute value.
    eor #$ff
    tay
    iny
    @done:
_CheckHorzSign:
    ;; Check if the horizontal component is negative.
    pla  ; Xpos
    bpl @done
    inc T2  ; number of negative inputs
    ;; Change the angle offset from 0 to $80.
    sec
    ror T3  ; angle offset (T3 is zero at this point, so this clears the carry)
    ;; Set Xpos to its absolute value.
    eor #$ff
    adc #1  ; carry is already clear from `ror T3` above
    @done:
_GetAngle:
    jsr Func_UnsignedAtan2  ; preserves X and T2+, returns A
    ;; If the number of negative inputs is even, add A to the angle offset; if
    ;; it's odd, subtract A from the angle offset.
    lsr T2  ; number of negative inputs
    bcc @noNegate
    eor #$ff
    @noNegate:
    adc T3  ; angle offset
    rts
.ENDPROC

;;; Computes the arc tangent of Y/X.
;;; @param A The (unsigned) horizontal vector component.
;;; @param Y The (unsigned) vertical vector component.
;;; @return A The angle (0-64), measured in increments of tau/256.
;;; @preserve X, T2+
.PROC Func_UnsignedAtan2
_ShiftX:
    sty T1  ; Ypos
    ;; While Xpos > $0f, halve both Xpos and Ypos.
    @loop:
    cmp #$10
    blt @done
    lsr T1  ; Ypos
    lsr a   ; Xpos
    bne @loop
    @done:
_ShiftY:
    sta T0  ; Xpos
    lda T1  ; Ypos
    ;; While Ypos > $0f, halve both Xpos and Ypos.
    @loop:
    cmp #$10
    blt @done
    lsr T0  ; Xpos
    lsr a   ; Ypos
    bne @loop
    @done:
_Combine:
    ;; Now that Xpos and Ypos fit into four bits each, use %yyyyxxxx as an
    ;; index into the below table.
    mul #$10  ; Ypos
    ora T0    ; Xpos
    tay  ; combined position index
    lda _Angle_u8_arr256, y
    rts
_Angle_u8_arr256:
:   ;; [round(atan2(y, x) * 128 / pi) for y in range(16) for x in range(16)]
    .byte  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
    .byte 64, 32, 19, 13, 10,  8,  7,  6,  5,  5,  4,  4,  3,  3,  3,  3
    .byte 64, 45, 32, 24, 19, 16, 13, 11, 10,  9,  8,  7,  7,  6,  6,  5
    .byte 64, 51, 40, 32, 26, 22, 19, 16, 15, 13, 12, 11, 10,  9,  9,  8
    .byte 64, 54, 45, 38, 32, 27, 24, 21, 19, 17, 16, 14, 13, 12, 11, 11
    .byte 64, 56, 48, 42, 37, 32, 28, 25, 23, 21, 19, 17, 16, 15, 14, 13
    .byte 64, 57, 51, 45, 40, 36, 32, 29, 26, 24, 22, 20, 19, 18, 16, 16
    .byte 64, 58, 53, 48, 43, 39, 35, 32, 29, 27, 25, 23, 22, 20, 19, 18
    .byte 64, 59, 54, 49, 45, 41, 38, 35, 32, 30, 27, 26, 24, 22, 21, 20
    .byte 64, 59, 55, 51, 47, 43, 40, 37, 34, 32, 30, 28, 26, 25, 23, 22
    .byte 64, 60, 56, 52, 48, 45, 42, 39, 37, 34, 32, 30, 28, 27, 25, 24
    .byte 64, 60, 57, 53, 50, 47, 44, 41, 38, 36, 34, 32, 30, 29, 27, 26
    .byte 64, 61, 57, 54, 51, 48, 45, 42, 40, 38, 36, 34, 32, 30, 29, 27
    .byte 64, 61, 58, 55, 52, 49, 46, 44, 42, 39, 37, 35, 34, 32, 30, 29
    .byte 64, 61, 58, 55, 53, 50, 48, 45, 43, 41, 39, 37, 35, 34, 32, 31
    .byte 64, 61, 59, 56, 53, 51, 48, 46, 44, 42, 40, 38, 37, 35, 33, 32
    .assert * - :- = 256, error
.ENDPROC

;;;=========================================================================;;;
