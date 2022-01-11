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

.INCLUDE "oam.inc"

;;;=========================================================================;;;

.ZEROPAGE

;;; A byte offset into Ram_Oam_sObj_arr64 pointing to the next unused entry.
;;; This must always be a multiple of .sizeof(sObj).
.EXPORTZP Zp_OamOffset_u8
Zp_OamOffset_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Oam"

.EXPORT Ram_Oam_sObj_arr64
Ram_Oam_sObj_arr64: .res .sizeof(sObj) * kNumOamSlots
.ASSERT kNumOamSlots = 64, error

;;;=========================================================================;;;

.SEGMENT "PRG8_Oam"

;;; Clears all remaining object entries in Ram_Oam_sObj_arr64, starting with
;;; the one indicated by Zp_OamOffset_u8, then sets Zp_OamOffset_u8 to zero.
.EXPORT Func_ClearRestOfOam
.PROC Func_ClearRestOfOam
    lda #$ff
    ;; Zp_OamOffset_u8 is assumed to hold a multiple of .sizeof(sObj).
    ldy Zp_OamOffset_u8
    @loop:
    ;; Hide the object by setting its Y-position to offscreen.
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    ;; Advance to the next object.
    .repeat .sizeof(sObj)
    iny
    .endrepeat
    ;; OAM is exactly $100 bytes, so when Y wraps around to zero, we are done.
    .assert .sizeof(sObj) * 64 = $100, error
    bne @loop
    sty Zp_OamOffset_u8
    rts
.ENDPROC

;;;=========================================================================;;;
