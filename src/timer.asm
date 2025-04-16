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
.INCLUDE "mmc3.inc"
.INCLUDE "timer.inc"

.IMPORT Sram_ExploreTimer_u8_arr

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Advances Ram_ExploreTimer_u8_arr by one frame.
.EXPORT FuncA_Avatar_TickExploreTimer
.PROC FuncA_Avatar_TickExploreTimer
_CountDigitsToRoll:
    ldx #0
    @loop:
    lda Sram_ExploreTimer_u8_arr, x
    cmp _TimerDigitMax_u8_arr, x
    blt _RollDigits
    inx
    cpx #kNumTimerDigits
    blt @loop
    ;; The timer is already at its maximum value, so leave it unchanged.
    rts
_RollDigits:
    lda #0
    ;; Enable writes to SRAM.
    ldy #bMmc3PrgRam::Enable
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Increment the first digit that shouldn't roll over to zero.
    inc Sram_ExploreTimer_u8_arr, x
    ;; Roll all lower digits back to zero.
    bne @start  ; unconditional
    @loop:
    sta Sram_ExploreTimer_u8_arr, x
    @start:
    dex
    .assert kNumTimerDigits <= $80, error
    bpl @loop
    ;; Disable writes to SRAM.
    ldy #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sty Hw_Mmc3PrgRamProtect_wo
    rts
_TimerDigitMax_u8_arr:
:   .byte 59       ; frames (one base-60 digit)
    .byte 9, 5     ; seconds (two decimal digits, little-endian)
    .byte 9, 5     ; minutes (two decimal digits, little-endian)
    .byte 9, 9, 9  ; hours (three decimal digits, little-endian)
    .assert * - :- = kNumTimerDigits, error
.ENDPROC

;;;=========================================================================;;;
