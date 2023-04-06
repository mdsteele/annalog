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

.INCLUDE "flag.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"

.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT Sram_ProgressFlags_arr

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Determines if the specified eFlag is set.
;;; @param X The eFlag value to test.
;;; @return Z Cleared if the flag is set, or set if the flag is cleared.
;;; @preserve X, T0+
.EXPORT Func_IsFlagSet
.PROC Func_IsFlagSet
    ;; Get the bitmask for this eFlag.
    txa  ; eFlag value
    and #$07
    tay
    lda Data_PowersOfTwo_u8_arr8, y
    pha  ; flag bitmask
    ;; Get the byte offset into Sram_ProgressFlags_arr for this eFlag, and
    ;; store it in Y.
    txa  ; eFlag value
    div #8
    tay
    ;; Check if the flag is set.
    pla  ; flag bitmask
    and Sram_ProgressFlags_arr, y
    rts
.ENDPROC

;;; Sets or clears the specified eFlag.
;;; @param A Zero if the flag should be cleared; nonzero if it should be set.
;;; @param X The eFlag value to set/clear.
;;; @preserve T0+
.EXPORT Func_SetOrClearFlag
.PROC Func_SetOrClearFlag
    tay
    beq Func_ClearFlag
    .assert * = Func_SetFlag, error, "fallthrough"
.ENDPROC

;;; Sets the specified eFlag to true if it isn't already.
;;; @param X The eFlag value to set.
;;; @return C Set if the flag was already set to true, cleared otherwise.
;;; @preserve T0+
.EXPORT Func_SetFlag
.PROC Func_SetFlag
    ;; Get the bitmask for this eFlag.
    txa  ; eFlag value
    and #$07
    tay
    lda Data_PowersOfTwo_u8_arr8, y
    tay  ; flag bitmask
    ;; Get the byte offset into Sram_ProgressFlags_arr for this eFlag, and
    ;; store it in X.
    txa  ; eFlag value
    div #8
    tax  ; byte offset
    ;; Check if the flag is already set.
    tya  ; flag bitmask
    and Sram_ProgressFlags_arr, x
    bne _AlreadySet
    ;; Compute the new value for the byte in Sram_ProgressFlags_arr.
    tya  ; flag bitmask
    ora Sram_ProgressFlags_arr, x
    bne Func_WriteFlag  ; unconditional; preserves T0+, clears C
_AlreadySet:
    sec
    rts
.ENDPROC

;;; Clears the specified eFlag to false if it isn't already.
;;; @param X The eFlag value to clear.
;;; @preserve T0+
.EXPORT Func_ClearFlag
.PROC Func_ClearFlag
    ;; Get the bitmask for this eFlag.
    txa  ; eFlag value
    and #$07
    tay
    lda Data_PowersOfTwo_u8_arr8, y
    tay  ; flag bitmask
    ;; Get the byte offset into Sram_ProgressFlags_arr for this eFlag, and
    ;; store it in X.
    txa  ; eFlag value
    div #8
    tax  ; byte offset
    ;; Check if the flag is already set.
    tya  ; flag bitmask
    and Sram_ProgressFlags_arr, x
    bne _ClearFlag
    rts
_ClearFlag:
    ;; Compute the new value for the byte in Sram_ProgressFlags_arr.
    eor Sram_ProgressFlags_arr, x
    .assert * = Func_WriteFlag, error, "fallthrough"
.ENDPROC

;;; Writes a byte to Sram_ProgressFlags_arr.
;;; @param A The byte to write.
;;; @param X The byte index into Sram_ProgressFlags_arr.
;;; @return C Always cleared.
;;; @preserve T0+
.PROC Func_WriteFlag
    ;; Enable writes to SRAM.
    ldy #bMmc3PrgRam::Enable
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Write progress flag.
    sta Sram_ProgressFlags_arr, x
    ;; Disable writes to SRAM.
    ldy #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sty Hw_Mmc3PrgRamProtect_wo
    clc
    rts
.ENDPROC

;;; Returns the number of flowers that have been delivered.
;;; @return A The number of delivered flowers.
;;; @return Z Set if zero flowers have been delivered.
;;; @preserve T0+
.EXPORT Func_CountDeliveredFlowers
.PROC Func_CountDeliveredFlowers
    ldy #0
_FirstByte:
    lda Sram_ProgressFlags_arr + (kFirstFlowerFlag >> 3)
    .assert (kFirstFlowerFlag & $07) = 0, error
    ldx #8
    @loop:
    asl a
    bcc @continue
    iny
    @continue:
    dex
    bne @loop
_SecondByte:
    .assert kNumFlowerFlags - 8 <= 8, error
    lda Sram_ProgressFlags_arr + (kLastFlowerFlag >> 3)
    .assert kNumFlowerFlags - 8 > 1, error
    ldx #kNumFlowerFlags - 8
    @loop:
    lsr a
    bcc @continue
    iny
    @continue:
    dex
    bne @loop
_Done:
    tya
    rts
.ENDPROC

;;;=========================================================================;;;
