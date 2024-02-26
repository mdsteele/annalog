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

.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_PpuTransferLen_u8

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Copies one or more transfer entries into the PPU transfer buffer.
;;; @param AX Pointer to the start of the transfer entry(ies) to copy.
;;; @param Y The number of bytes to buffer (including any transfer headers).
;;; @preserve T3+
.EXPORT Func_BufferPpuTransfer
.PROC Func_BufferPpuTransfer
    stax T1T0  ; pointer to start of data to copy
    sty T2  ; total number of bytes to copy
    ldx Zp_PpuTransferLen_u8
    ldy #0
    @loop:
    lda (T1T0), y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy T2  ; total number of bytes to copy
    blt @loop
    stx Zp_PpuTransferLen_u8
    rts
.ENDPROC

;;; Fills the lower attribute table with the given byte.
;;; @prereq Rendering is disabled.
;;; @param Y The attribute byte to set.
;;; @preserve Y
.EXPORT Func_FillLowerAttributeTable
.PROC Func_FillLowerAttributeTable
    ldx #64  ; param: num bytes to write
    lda #0   ; param: initial byte offset
    fall Func_WriteToLowerAttributeTable  ; preserves Y
.ENDPROC

;;; Writes the specified byte to a portion of the lower attribute table.
;;; @prereq Rendering is disabled.
;;; @param A The initial byte offset into the upper nametable's attributes.
;;; @param X The number of bytes to write (1-64).
;;; @param Y The attribute byte value to write.
;;; @preserve Y
.EXPORT Func_WriteToLowerAttributeTable
.PROC Func_WriteToLowerAttributeTable
    sta T0  ; param: initial byte offset
    lda #>(Ppu_Nametable3_sName + sName::Attrs_u8_arr64)  ; param: dest (hi)
    .assert >(Ppu_Nametable3_sName + sName::Attrs_u8_arr64) > 0, error
    bne Func_WriteToAttributeTable  ; unconditional, preserves Y
.ENDPROC

;;; Fills the upper attribute table with the given byte.
;;; @prereq Rendering is disabled.
;;; @param Y The attribute byte to set.
;;; @preserve Y
.EXPORT Func_FillUpperAttributeTable
.PROC Func_FillUpperAttributeTable
    ldx #64  ; param: num bytes to write
    lda #0   ; param: initial byte offset
    fall Func_WriteToUpperAttributeTable  ; preserves Y
.ENDPROC

;;; Writes the specified byte to a portion of the upper attribute table.
;;; @prereq Rendering is disabled.
;;; @param A The initial byte offset into the upper nametable's attributes.
;;; @param X The number of bytes to write (1-64).
;;; @param Y The attribute byte value to write.
;;; @preserve Y
.EXPORT Func_WriteToUpperAttributeTable
.PROC Func_WriteToUpperAttributeTable
    sta T0  ; param: initial byte offset
    lda #>(Ppu_Nametable0_sName + sName::Attrs_u8_arr64)  ; param: dest (hi)
    fall Func_WriteToAttributeTable
.ENDPROC

;;; Writes the specified byte to a portion of the specified attribute table.
;;; @prereq Rendering is disabled.
;;; @param A The hi byte of the PPU address for the attribute table.
;;; @param T0 The initial byte offset into the attribute table.
;;; @param X The number of bytes to write (1-64).
;;; @param Y The attribute byte value to write.
;;; @preserve Y
.PROC Func_WriteToAttributeTable
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    lda T0  ; byte offset
    .assert <Ppu_Nametable0_sName .mod $100 = 0, error
    .assert <Ppu_Nametable3_sName .mod $100 = 0, error
    .assert <sName::Attrs_u8_arr64 .mod 64 = 0, error
    ora #<sName::Attrs_u8_arr64
    sta Hw_PpuAddr_w2
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    @loop:
    sty Hw_PpuData_rw
    dex
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;
