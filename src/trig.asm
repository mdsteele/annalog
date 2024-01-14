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

;;; Computes the arc tangent of Y/X, taking the signs of X and Y into account.
;;; @param X The (signed) horizontal vector component.
;;; @param Y The (signed) vertical vector component.
;;; @return A The angle, measured in increments of tau/256.
;;; @preserve T4+
.EXPORT Func_SignedAtan2
.PROC Func_SignedAtan2
    ;; This function is implemented in terms of Func_UnsignedAtan2, which only
    ;; works for Quadrant 1 (non-negative X and Y).  Let A by the the angle
    ;; returned by Func_UnsignedAtan2 for |X| and |Y|; then the results we want
    ;; for each quadrant are:
    ;;     * Q1 (+X/+Y): A
    ;;     * Q2 (-X/+Y): $80 - A
    ;;     * Q3 (-X/-Y): $80 + A
    ;;     * Q4 (+X/-Y): -A
    ;; Thus, if exactly one of X or Y is negative, then we need to negate the
    ;; output angle, and if X is negative, we need to offset the angle by $80.
    lda #0
    sta T3  ; angle offset
    sta T2  ; number of negative inputs
_CheckXSign:
    ;; Check if X is negative.
    txa
    bpl @done
    inc T2  ; number of negative inputs
    ;; Set X to its absolute value.
    eor #$ff
    tax
    inx
    ;; Change the angle offset from 0 to $80.
    sec
    ror T3  ; angle offset
    @done:
_CheckYSign:
    ;; Check if Y is negative.
    tya
    bpl @done
    inc T2  ; number of negative inputs
    ;; Set Y to its absolute value.
    eor #$ff
    tay
    iny
    @done:
_GetAngle:
    jsr Func_UnsignedAtan2  ; preserves T2+, returns A
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
;;; @param X The (unsigned) horizontal vector component.
;;; @param Y The (unsigned) vertical vector component.
;;; @return A The angle (0-64), measured in increments of tau/256.
;;; @preserve T2+
.PROC Func_UnsignedAtan2
_ShiftY:
    stx T0  ; Xpos
    tya     ; Ypos
    ;; While Ypos > $0f, halve both Xpos and Ypos.
    @loop:
    cmp #$10
    blt @done
    lsr T0  ; Xpos
    lsr a   ; Ypos
    bne @loop
    @done:
_ShiftX:
    sta T1  ; Ypos
    lda T0  ; Xpos
    ;; While Xpos > $0f, halve both Xpos and Ypos.
    @loop:
    cmp #$10
    blt @done
    lsr T1  ; Ypos
    lsr a   ; Xpos
    bne @loop
    @done:
_Combine:
    ;; Now that Xpos and Ypos fit into four bits each, use %xxxxyyyy as an
    ;; index into the below table.
    mul #$10  ; Xpos
    ora T1    ; Ypos
    tax  ; combined position index
    lda _Angle_u8_arr256, x
    rts
_Angle_u8_arr256:
:   ;; [round(atan2(y, x) * 128 / pi) for  x in range(16) for y in range(16)]
    .byte 0, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64
    .byte 0, 32, 45, 51, 54, 56, 57, 58, 59, 59, 60, 60, 61, 61, 61, 61
    .byte 0, 19, 32, 40, 45, 48, 51, 53, 54, 55, 56, 57, 57, 58, 58, 59
    .byte 0, 13, 24, 32, 38, 42, 45, 48, 49, 51, 52, 53, 54, 55, 55, 56
    .byte 0, 10, 19, 26, 32, 37, 40, 43, 45, 47, 48, 50, 51, 52, 53, 53
    .byte 0,  8, 16, 22, 27, 32, 36, 39, 41, 43, 45, 47, 48, 49, 50, 51
    .byte 0,  7, 13, 19, 24, 28, 32, 35, 38, 40, 42, 44, 45, 46, 48, 48
    .byte 0,  6, 11, 16, 21, 25, 29, 32, 35, 37, 39, 41, 42, 44, 45, 46
    .byte 0,  5, 10, 15, 19, 23, 26, 29, 32, 34, 37, 38, 40, 42, 43, 44
    .byte 0,  5,  9, 13, 17, 21, 24, 27, 30, 32, 34, 36, 38, 39, 41, 42
    .byte 0,  4,  8, 12, 16, 19, 22, 25, 27, 30, 32, 34, 36, 37, 39, 40
    .byte 0,  4,  7, 11, 14, 17, 20, 23, 26, 28, 30, 32, 34, 35, 37, 38
    .byte 0,  3,  7, 10, 13, 16, 19, 22, 24, 26, 28, 30, 32, 34, 35, 37
    .byte 0,  3,  6,  9, 12, 15, 18, 20, 22, 25, 27, 29, 30, 32, 34, 35
    .byte 0,  3,  6,  9, 11, 14, 16, 19, 21, 23, 25, 27, 29, 30, 32, 33
    .byte 0,  3,  5,  8, 11, 13, 16, 18, 20, 22, 24, 26, 27, 29, 31, 32
    .assert * - :- = 256, error
.ENDPROC

;;;=========================================================================;;;
