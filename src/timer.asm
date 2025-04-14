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
.INCLUDE "timer.inc"

;;;=========================================================================;;;

.SEGMENT "RAM_Timer"

;;; The total time spent in explore mode for this game, stored as hours (3
;;; decimal digits), minutes (2 decimal digits), seconds (2 decimal digits),
;;; and frames (1 base-60 digit), in big-endian order.
.EXPORT Ram_ExploreTimer_u8_arr
Ram_ExploreTimer_u8_arr: .res kNumTimerDigits

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Advances Ram_ExploreTimer_u8_arr by one frame.
.EXPORT FuncA_Avatar_TickExploreTimer
.PROC FuncA_Avatar_TickExploreTimer
    ldx #kNumTimerDigits - 1
    @loop:
    lda Ram_ExploreTimer_u8_arr, x
    cmp _TimerDigitMax_u8_arr, x
    blt _IncrementDigit
    lda #0
    sta Ram_ExploreTimer_u8_arr, x
    dex
    .assert kNumTimerDigits <= $80, error
    bpl @loop
_TimerOverflow:
    ;; At this point, we've rolled the whole timer back to 000:00:00.00, so set
    ;; it back to its maximum value of 999:59:59.59.
    ldx #kNumTimerDigits - 1
    @loop:
    lda _TimerDigitMax_u8_arr, x
    sta Ram_ExploreTimer_u8_arr, x
    dex
    .assert kNumTimerDigits <= $80, error
    bpl @loop
    rts
_IncrementDigit:
    inc Ram_ExploreTimer_u8_arr, x
    rts
_TimerDigitMax_u8_arr:
:   .byte 9, 9, 9  ; hours (three decimal digits)
    .byte 5, 9     ; minutes (two decimal digits)
    .byte 5, 9     ; seconds (two decimal digits)
    .byte 59       ; frames (one base-60 digit)
    .assert * - :- = kNumTimerDigits, error
.ENDPROC

;;;=========================================================================;;;
