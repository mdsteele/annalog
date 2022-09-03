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
.INCLUDE "ppu.inc"

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Fills the lower attribute table with the given byte.
;;; @prereq Rendering is disabled.
;;; @param Y The attribute byte to set.
;;; @preserve Y
.EXPORT Func_FillLowerAttributeTable
.PROC Func_FillLowerAttributeTable
    ldax #Ppu_Nametable3_sName + sName::Attrs_u8_arr64  ; param: table addr
    jmp Func_FillAttributeTable  ; preserves Y
.ENDPROC

;;; Fills the upper attribute table with the given byte.
;;; @prereq Rendering is disabled.
;;; @param Y The attribute byte to set.
;;; @preserve Y
.EXPORT Func_FillUpperAttributeTable
.PROC Func_FillUpperAttributeTable
    ldax #Ppu_Nametable0_sName + sName::Attrs_u8_arr64  ; param: table addr
    .assert * = Func_FillAttributeTable, error, "fallthrough"
.ENDPROC

;;; Fills the specified attribute table with the given byte.
;;; @prereq Rendering is disabled.
;;; @param AX The PPU address for the attribute table to fill.
;;; @param Y The attribute byte to set.
;;; @preserve Y
.PROC Func_FillAttributeTable
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldx #64
    @loop:
    sty Hw_PpuData_rw
    dex
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;
