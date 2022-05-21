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

.INCLUDE "../src/irq.inc"
.INCLUDE "../src/macros.inc"

.IMPORT Exit_Success
.IMPORT Func_ExpectAEqualsY
.IMPORT Func_Window_GetRowPpuAddr

;;;=========================================================================;;;

kExpectedPpuAddr = $2f80

;;;=========================================================================;;;

.ZEROPAGE

Zp_WindowRowPpuAddr_ptr: .res 2

.EXPORTZP Zp_Buffered_sIrq
Zp_Buffered_sIrq: .tag sIrq
.EXPORTZP Zp_NextIrq_int_ptr
Zp_NextIrq_int_ptr: .res 2
.EXPORTZP Zp_PpuTransferLen_u8
Zp_PpuTransferLen_u8: .res 1
.EXPORTZP Zp_Tmp1_byte
Zp_Tmp1_byte: .res 1
.EXPORTZP Zp_TransferIrqTable_bool
Zp_TransferIrqTable_bool: .res 1

;;;=========================================================================;;;

.BSS

.EXPORT Ram_PpuTransfer_arr
Ram_PpuTransfer_arr: .res $80

;;;=========================================================================;;;

.SEGMENT "MAIN"
    sei
    cld
    ldx #$ff
    txs
Test:
    lda #10
    jsr Func_Window_GetRowPpuAddr
    stxy Zp_WindowRowPpuAddr_ptr
Verify:
    lda Zp_WindowRowPpuAddr_ptr + 0
    ldy #<kExpectedPpuAddr
    jsr Func_ExpectAEqualsY
    lda Zp_WindowRowPpuAddr_ptr + 1
    ldy #>kExpectedPpuAddr
    jsr Func_ExpectAEqualsY
Success:
    jmp Exit_Success

;;;=========================================================================;;;
