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
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"

;;;=========================================================================;;;

.ZEROPAGE

;;; The current index into the Ram_Active_sIrq arrays.  This is reset back to
;;; zero for every frame by the NMI handler, and incremented each time the IRQ
;;; handler fires.
.EXPORTZP Zp_IrqIndex_u8
Zp_IrqIndex_u8: .res 1

;;; The value to copy into Hw_PpuMask_wo during the next IRQ.  We keep this
;;; cached in the zeropage so that the IRQ handler can grab it very quickly at
;;; the start of the handler.
.EXPORTZP Zp_IrqNextRender_bPpuMask
Zp_IrqNextRender_bPpuMask: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Irq"

;;; The IRQ table that is actively being used by the IRQ handler.  It is only
;;; safe to write to this during VBlank (since the IRQ handler uses it during
;;; the frame), so the NMI handler is responsible for doing so.
.EXPORT Ram_Active_sIrq
Ram_Active_sIrq: .tag sIrq

;;; The IRQ table that the NMI handler will copy to Ram_Active_sIrq during
;;; VBlank once Zp_TransferIrqTable_bool is set to true ($ff).  The CPU can
;;; safely write to this during the frame, then set Zp_TransferIrqTable_bool
;;; once it's ready for the transfer.
.EXPORT Ram_Buffered_sIrq
Ram_Buffered_sIrq: .tag sIrq

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; The IRQ handler.  The only IRQ that this game uses is the MMC3's HBlank
;;; interrupt.  We have too much to do to fit in a single HBlank (which only
;;; lasts about 28 CPU cycles), and worse, the interrupt handler usually
;;; doesn't even fire until partway through the HBlank.  So we split our work
;;; across two HBlanks (with a little processing and a little busy-looping in
;;; between).
.EXPORT Int_Irq
.PROC Int_Irq
    ;; Save the A register and update the PPU mask as quickly as possible.
    pha
    lda Zp_IrqNextRender_bPpuMask
    sta Hw_PpuMask_wo
    ;; At this point, the first HBlank is now just about over.  Now we can ack
    ;; the current IRQ.
    sta Hw_Mmc3IrqDisable_wo  ; ack
    sta Hw_Mmc3IrqEnable_wo  ; re-enable
    ;; Save X register (A register is alrady saved, and we won't use Y).
    txa
    pha
    ;; X = Zp_IrqIndex_u8++
    ldx Zp_IrqIndex_u8
    inc Zp_IrqIndex_u8
    ;; Set up the latch value for next IRQ.
    lda Ram_Active_sIrq + sIrq::Latch_u8_arr + 1, x
    sta Hw_Mmc3IrqLatch_wo
    sta Hw_Mmc3IrqReload_wo
    ;; The special latch value $ff signals the last entry in the IRQ table, so
    ;; once we hit that, we're done.
    cmp #$ff
    beq _Done
    ;; Cache the PPU mask for the next IRQ.
    lda Ram_Active_sIrq + sIrq::Render_bPpuMask_arr + 1, x
    sta Zp_IrqNextRender_bPpuMask
    ;; Load the ScrollY value for this IRQ.  The special value $ff means "leave
    ;; scroll unchanged", so in that case, we're done.
    lda Ram_Active_sIrq + sIrq::ScrollY_u8_arr, x
    cmp #$ff
    beq _Done
    ;; Otherwise, we will set that as the PPU's new scroll-Y value, as well as
    ;; setting the PPU's scroll-X to zero, and setting the lower nametable as
    ;; the scrolling origin.  All of this takes four writes, and the last two
    ;; must happen during HBlank, so we busy-loop for a bit in the middle.
    ;; See https://wiki.nesdev.org/w/index.php/PPU_scrolling#Split_X.2FY_scroll
    ldx #$0c
    stx Hw_PpuAddr_w2
    sta Hw_PpuScroll_w2
    and #$f8
    asl a
    asl a
    ldx #4  ; this value is hand-tuned to make the loop finish as HBlank starts
    @busyLoop:
    dex
    bne @busyLoop
    ;; We should now be in the second HBlank (and x is zero).
    stx Hw_PpuScroll_w2
    sta Hw_PpuAddr_w2
_Done:
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;;=========================================================================;;;
