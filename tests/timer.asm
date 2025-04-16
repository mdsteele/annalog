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

.INCLUDE "../src/macros.inc"
.INCLUDE "../src/timer.inc"

.IMPORT Exit_Success
.IMPORT FuncA_Avatar_TickExploreTimer
.IMPORT Func_ExpectAEqualsY

;;;=========================================================================;;;

.ZEROPAGE

Zp_TestTmp_ptr: .res 2

;;;=========================================================================;;;

.BSS

.EXPORT Sram_ExploreTimer_u8_arr
Sram_ExploreTimer_u8_arr: .res kNumTimerDigits

;;;=========================================================================;;;

.CODE

;;; Copies the given array into Sram_ExploreTimer_u8_arr.
;;; @param YA Pointer to an array of eight timer bytes.
.PROC Func_SetExploreTimer
    stya Zp_TestTmp_ptr
    ldy #kNumTimerDigits - 1
    @loop:
    lda (Zp_TestTmp_ptr), y
    sta Sram_ExploreTimer_u8_arr, y
    dey
    .assert kNumTimerDigits <= $80, error
    bpl @loop
    rts
.ENDPROC

;;; Tests that Sram_ExploreTimer_u8_arr equals the given array; if not, prints
;;; an error message and exits.
;;; @param YA Pointer to an array of eight timer bytes.
.PROC Func_ExpectExploreTimer
    stya Zp_TestTmp_ptr
    ldy #kNumTimerDigits - 1
    @loop:
    tya  ; loop index
    pha  ; loop index
    ldx Sram_ExploreTimer_u8_arr, y
    lda (Zp_TestTmp_ptr), y
    tay  ; param: expected value
    txa  ; param: actual value
    jsr Func_ExpectAEqualsY
    pla  ; loop index
    tay  ; loop index
    dey
    .assert kNumTimerDigits <= $80, error
    bpl @loop
    rts
.ENDPROC

.PROC Data_TimerTests_u8_arr8_arr2_arr
    .assert kNumTimerDigits = 8, error
    ;; Test:
    .byte 00, 0, 0, 0, 0, 0, 0, 0  ; initial
    .byte 01, 0, 0, 0, 0, 0, 0, 0  ; expected
    ;; Test:
    .byte 58, 0, 0, 0, 0, 0, 0, 0  ; initial
    .byte 59, 0, 0, 0, 0, 0, 0, 0  ; expected
    ;; Test:
    .byte 59, 0, 0, 0, 0, 0, 0, 0  ; initial
    .byte 00, 1, 0, 0, 0, 0, 0, 0  ; expected
    ;; Test:
    .byte 59, 8, 0, 0, 0, 0, 0, 0  ; initial
    .byte 00, 9, 0, 0, 0, 0, 0, 0  ; expected
    ;; Test:
    .byte 59, 9, 0, 0, 0, 0, 0, 0  ; initial
    .byte 00, 0, 1, 0, 0, 0, 0, 0  ; expected
    ;; Test:
    .byte 59, 9, 4, 0, 0, 0, 0, 0  ; initial
    .byte 00, 0, 5, 0, 0, 0, 0, 0  ; expected
    ;; Test:
    .byte 59, 9, 5, 0, 0, 0, 0, 0  ; initial
    .byte 00, 0, 0, 1, 0, 0, 0, 0  ; expected
    ;; Test:
    .byte 59, 9, 5, 8, 0, 0, 0, 0  ; initial
    .byte 00, 0, 0, 9, 0, 0, 0, 0  ; expected
    ;; Test:
    .byte 59, 9, 5, 9, 0, 0, 0, 0  ; initial
    .byte 00, 0, 0, 0, 1, 0, 0, 0  ; expected
    ;; Test:
    .byte 59, 9, 5, 9, 4, 0, 0, 0  ; initial
    .byte 00, 0, 0, 0, 5, 0, 0, 0  ; expected
    ;; Test:
    .byte 59, 9, 5, 9, 5, 0, 0, 0  ; initial
    .byte 00, 0, 0, 0, 0, 1, 0, 0  ; expected
    ;; Test:
    .byte 59, 9, 5, 9, 5, 8, 0, 0  ; initial
    .byte 00, 0, 0, 0, 0, 9, 0, 0  ; expected
    ;; Test:
    .byte 59, 9, 5, 9, 5, 9, 0, 0  ; initial
    .byte 00, 0, 0, 0, 0, 0, 1, 0  ; expected
    ;; Test:
    .byte 59, 9, 5, 9, 5, 9, 8, 0  ; initial
    .byte 00, 0, 0, 0, 0, 0, 9, 0  ; expected
    ;; Test:
    .byte 59, 9, 5, 9, 5, 9, 9, 0  ; initial
    .byte 00, 0, 0, 0, 0, 0, 0, 1  ; expected
    ;; Test:
    .byte 59, 9, 5, 9, 5, 9, 9, 8  ; initial
    .byte 00, 0, 0, 0, 0, 0, 0, 9  ; expected
    ;; Timer should stop ticking when it reaches its maximum value:
    .byte 59, 9, 5, 9, 5, 9, 9, 9  ; initial
    .byte 59, 9, 5, 9, 5, 9, 9, 9  ; expected
    ;; Timer should repair itself when a digit is out of range:
    .byte 99, 2, 1, 2, 1, 3, 2, 1  ; initial
    .byte 00, 3, 1, 2, 1, 3, 2, 1  ; expected
    ;; Timer should repair itself when a digit is out of range:
    .byte 59, 99, 1, 2, 1, 3, 2, 1  ; initial
    .byte 00,  0, 2, 2, 1, 3, 2, 1  ; expected
    ;; Timer should repair itself when a digit is out of range:
    .byte 59, 9, 99, 2, 1, 3, 2, 1  ; initial
    .byte 00, 0,  0, 3, 1, 3, 2, 1  ; expected
    ;; Timer should repair itself when a digit is out of range:
    .byte 59, 9, 5, 99, 1, 3, 2, 1  ; initial
    .byte 00, 0, 0,  0, 2, 3, 2, 1  ; expected
    ;; Timer should repair itself when a digit is out of range:
    .byte 59, 9, 5, 9, 99, 3, 2, 1  ; initial
    .byte 00, 0, 0, 0,  0, 4, 2, 1  ; expected
    ;; Timer should repair itself when a digit is out of range:
    .byte 59, 9, 5, 9, 5, 99, 2, 1  ; initial
    .byte 00, 0, 0, 0, 0,  0, 3, 1  ; expected
    ;; Timer should repair itself when a digit is out of range:
    .byte 59, 9, 5, 9, 5, 9, 99, 1  ; initial
    .byte 00, 0, 0, 0, 0, 0,  0, 2  ; expected
.ENDPROC

.LINECONT +
kNumTimerTests = \
    .sizeof(Data_TimerTests_u8_arr8_arr2_arr) / (2 * kNumTimerDigits)
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "MAIN"
    sei
    cld
    ldx #$ff
    txs
RunTests:
    .repeat kNumTimerTests, i
    ldya #Data_TimerTests_u8_arr8_arr2_arr + kNumTimerDigits * (2 * i + 0)
    jsr Func_SetExploreTimer
    jsr FuncA_Avatar_TickExploreTimer
    ldya #Data_TimerTests_u8_arr8_arr2_arr + kNumTimerDigits * (2 * i + 1)
    jsr Func_ExpectExploreTimer
    .endrepeat
Success:
    jmp Exit_Success

;;;=========================================================================;;;
