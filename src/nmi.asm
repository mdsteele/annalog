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

.INCLUDE "irq.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"

.IMPORT Func_AudioSync
.IMPORT Func_AudioUpdate
.IMPORT Func_ReadJoypad
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_NextIrq_int_ptr

;;;=========================================================================;;;

.ZEROPAGE

;;; Set this to true ($ff) to signal that PPU and APU transfer data is ready to
;;; be consumed by the NMI handler.  The NMI handler will set it back to false
;;; ($00) once the data is transferred.
Zp_NmiReady_bool: .res 1

;;; The NMI handler will set this as the CHR0C bank number during VBlank when
;;; Zp_NmiReady_bool is set.
.EXPORTZP Zp_Chr0cBank_u8
Zp_Chr0cBank_u8: .res 1

;;; The NMI handler will copy this to Hw_PpuMask_wo when Zp_NmiReady_bool is
;;; set.
.EXPORTZP Zp_Render_bPpuMask
Zp_Render_bPpuMask: .res 1

;;; The NMI handler will copy these to Hw_PpuScroll_w2 when Zp_NmiReady_bool is
;;; set.
.EXPORTZP Zp_PpuScrollX_u8, Zp_PpuScrollY_u8
Zp_PpuScrollX_u8: .res 1
Zp_PpuScrollY_u8: .res 1

;;; The current length of Ram_PpuTransfer_arr, in bytes.  When Zp_NmiReady_bool
;;; is set, the NMI handler will transfer the data and reset this back to zero.
.EXPORTZP Zp_PpuTransferLen_u8
Zp_PpuTransferLen_u8: .res 1

;;; A counter that gets incremented by every call to Func_ProcessFrame.  It can
;;; be used to drive looping animations.
.EXPORTZP Zp_FrameCounter_u8
Zp_FrameCounter_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_PpuTransfer"

;;; Storage for data that the NMI hanlder should transfer to the PPU the next
;;; time that Zp_NmiReady_bool is set.  Consists of zero or more entries, where
;;; each entry consists of:
;;;     - Value to set for Hw_PpuCtrl_wo (1 byte, must include EnableNmi)
;;;     - Destination PPU address (2 bytes, *big*-endian)
;;;     - Length (1 byte, must be nonzero)
;;;     - Data to transfer (length bytes)
.EXPORT Ram_PpuTransfer_arr
Ram_PpuTransfer_arr: .res $80

;;;=========================================================================;;;

.SEGMENT "PRGE_Nmi"

;;; NMI interrupt handler, which is called at the start of VBlank.
.EXPORT Int_Nmi
.PROC Int_Nmi
    ;; Save registers.  (Note that the interrupt automatically saves processor
    ;; flags, so we don't need a php instruction here.)
    pha
    txa
    pha
    tya
    pha
    ;; Check if the CPU is ready to transfer data to the PPU.
    bit Zp_NmiReady_bool
    bpl _DoneUpdatingPpu
_TransferOamData:
    lda #0
    sta Hw_OamAddr_wo
    .assert <Ram_Oam_sObj_arr64 = 0, error
    lda #>Ram_Oam_sObj_arr64
    sta Hw_OamDma_wo
_TransferPpuData:
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    ldx #0
    @entryLoop:
    lda Ram_PpuTransfer_arr, x  ; control byte
    bpl @done
    sta Hw_PpuCtrl_wo
    inx
    .repeat 2
    lda Ram_PpuTransfer_arr, x  ; PPU addr
    sta Hw_PpuAddr_w2
    inx
    .endrepeat
    ldy Ram_PpuTransfer_arr, x  ; length
    inx
    @dataLoop:
    lda Ram_PpuTransfer_arr, x
    sta Hw_PpuData_rw
    inx
    dey
    bne @dataLoop
    beq @entryLoop  ; unconditional
    @done:
_UpdatePpuRegisters:
    ;; Update other PPU registers.  Note that writing to Hw_PpuAddr_w2 (as
    ;; above) can corrupt the scroll position, so we must write Hw_PpuScroll_w2
    ;; afterwards.  See https://wiki.nesdev.org/w/index.php/PPU_scrolling.
    lda Zp_PpuScrollX_u8
    sta Hw_PpuScroll_w2
    lda Zp_PpuScrollY_u8
    sta Hw_PpuScroll_w2
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    lda Zp_Render_bPpuMask
    sta Hw_PpuMask_wo
    chr0c_bank Zp_Chr0cBank_u8
_TransferIrqStruct:
    .repeat .sizeof(sIrq), index
    lda <(Zp_Buffered_sIrq + index)
    sta <(Zp_Active_sIrq + index)
    .endrepeat
_FinishUpdatingPpu:
    ;; Mark the PPU transfer buffer as empty.
    lda #0
    sta Zp_PpuTransferLen_u8
_DoneUpdatingPpu:
    ;; Set up HBlank IRQs for this frame.
    lda <(Zp_Active_sIrq + sIrq::Latch_u8)
    sta Hw_Mmc3IrqLatch_wo
    sta Hw_Mmc3IrqReload_wo
    ldax <(Zp_Active_sIrq + sIrq::FirstIrq_int_ptr)
    stax Zp_NextIrq_int_ptr
    ;; Everything up until this point *must* finish before VBlank ends, while
    ;; everything after this point is safe to extend past the VBlank period.
    ;; Call audio driver.
    bit Zp_NmiReady_bool
    bpl @doneAudioSync
    jsr Func_AudioSync
    @doneAudioSync:
    jsr Func_AudioUpdate
    ;; Indicate that we are done updating the PPU and APU.
    lda #0
    sta Zp_NmiReady_bool
    ;; Restore registers and return.  (Note that the rti instruction
    ;; automatically restores processor flags, so we don't need a plp
    ;; instruction here.)
    pla
    tay
    pla
    tax
    pla
    rti
.ENDPROC

;;; Signals that shadow OAM/PPU data is ready to be transferred, then waits for
;;; the next NMI to complete.
.EXPORT Func_ProcessFrame
.PROC Func_ProcessFrame
    ;; Change this to ".if 1" to enable frame budget debugging.
    .if 0
    lda Zp_Render_bPpuMask
    ora #bPpuMask::EmphGreen
    sta Hw_PpuMask_wo
    .endif
    ;; Increment animation counter.
    inc Zp_FrameCounter_u8
    ;; Zero-terminate the PPU transfer buffer.
    ldx Zp_PpuTransferLen_u8
    lda #0
    sta Ram_PpuTransfer_arr, x
    ;; Tell the NMI handler that we are ready for it to transfer data, then
    ;; wait until it finishes.
    dec Zp_NmiReady_bool  ; change from false ($00) to true ($ff)
    @loop:
    bit Zp_NmiReady_bool  ; loop until high bit is 0 again
    bmi @loop
    ;; Read the joypad for this frame.
    jmp Func_ReadJoypad
.ENDPROC

;;;=========================================================================;;;
