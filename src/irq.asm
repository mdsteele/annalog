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

;;; See https://wiki.nesdev.org/w/index.php/IRQ for a list of IRQ sources and
;;; how to acknowledge each one.

.INCLUDE "irq.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"

;;;=========================================================================;;;

.ZEROPAGE

;;; The draft HBlank interrupt structure.  The main thread can freely mutate
;;; this, and it will be copied to Zp_Active_sIrq when Func_ProcessFrame is
;;; called.
.EXPORTZP Zp_Buffered_sIrq
Zp_Buffered_sIrq: .tag sIrq

;;; The active HBlank interrupt structure.  Each frame, the NMI handler will
;;; use this to initialize HBlank interrupts for that frame.  Only the NMI
;;; thread should access this.
.EXPORTZP Zp_Active_sIrq
Zp_Active_sIrq: .tag sIrq

;;; The interrupt handler function to call the next time that an IRQ occurs.
;;; Only the NMI and IRQ threads should access this.
.EXPORTZP Zp_NextIrq_int_ptr
Zp_NextIrq_int_ptr: .res 2

;;; Temporary variable that any IRQ-thread function can use.
.EXPORTZP Zp_IrqTmp_byte
Zp_IrqTmp_byte: .res 1

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; The IRQ handler.  The only IRQ that this game uses is the MMC3's HBlank
;;; interrupt.
.EXPORT Int_Irq
.PROC Int_Irq
    jmp (Zp_NextIrq_int_ptr)
.ENDPROC

;;;=========================================================================;;;
