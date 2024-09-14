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

.IMPORT FuncM_DrawObjectsForRoom
.IMPORT Func_AudioSync
.IMPORT Func_AudioUpdate
.IMPORT Func_ClearRestOfOam
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

;;; The NMI handler will set this as the CHR04 bank number during VBlank when
;;; Zp_NmiReady_bool is set.
.EXPORTZP Zp_Chr04Bank_u8
Zp_Chr04Bank_u8: .res 1

;;; The NMI handler will copy this to Hw_PpuMask_wo when Zp_NmiReady_bool is
;;; set.
.EXPORTZP Zp_Render_bPpuMask
Zp_Render_bPpuMask: .res 1

;;; The NMI handler will copy these to Hw_PpuScroll_w2 when Zp_NmiReady_bool is
;;; set.
.EXPORTZP Zp_PpuScrollX_u8
Zp_PpuScrollX_u8: .res 1
.EXPORTZP Zp_PpuScrollY_u8
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
    pha
    txa
    pha
    tya
    pha
    ;; Check if the CPU is ready to transfer data to the PPU.
    bit Zp_NmiReady_bool
    bpl _DoneUpdatingPpu
_TransferOamData:
    ldx #0
    stx Hw_OamAddr_wo
    .assert <Ram_Oam_sObj_arr64 = 0, error
    lda #>Ram_Oam_sObj_arr64
    sta Hw_OamDma_wo
_TransferPpuData:
    ;; At this point, X is still zero.
    .assert >Ram_Oam_sObj_arr64 > 0, error
    bne @start  ; unconditional
    @entryLoop:
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
    @start:
    lda Ram_PpuTransfer_arr, x  ; control byte
    bne @entryLoop
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
    ;; Switch CHR04 banks (for animated terrain).  Note that the NMI thread
    ;; will only be executing this code if the main thread is currently blocked
    ;; in Func_ProcessFrame, and has already set up Hw_Mmc3BankSelect_wo for
    ;; CHR04.
    lda Zp_Chr04Bank_u8
    sta Hw_Mmc3BankData_wo
_TransferIrqStruct:
    .repeat .sizeof(sIrq), index
    lda Zp_Buffered_sIrq + index
    sta Zp_Active_sIrq + index
    .endrepeat
_DoneUpdatingPpu:
    ;; Set up HBlank IRQs for this frame.
    lda Zp_Active_sIrq + sIrq::Latch_u8
    sta Hw_Mmc3IrqLatch_wo
    sta Hw_Mmc3IrqReload_wo
    ldax Zp_Active_sIrq + sIrq::FirstIrq_int_ptr
    stax Zp_NextIrq_int_ptr
    ;; Everything up until this point *must* finish before VBlank ends, while
    ;; everything after this point is safe to extend past the VBlank period.
    ;; Just in case it does, we'll re-enable IRQs for the remainder of this NMI
    ;; handler, so that HBlank interrupts can still happen while we're working
    ;; on e.g. audio processing.
    cli
_AfterVBlank:
    ;; These updates should only happen this frame if the main thread was ready
    ;; for this NMI, but unlike the above, they don't need to happen during
    ;; VBlank.
    bit Zp_NmiReady_bool
    bpl @done
    ;; Consume audio commands from the main thread.
    jsr Func_AudioSync
    ;; Clear the PPU transfer array.
    lda #0
    sta Zp_PpuTransferLen_u8
    ;; Indicate that PPU and APU transfer data was consumed.
    sta Zp_NmiReady_bool
    @done:
_Finish:
    ;; Audio should continue to update even if the main thread wasn't ready for
    ;; this NMI, so that lag frames (e.g. during screen transitions) won't
    ;; affect the audio.
    jsr Func_AudioUpdate
    pla
    tay
    pla
    tax
    pla
    rti
.ENDPROC

;;; Calls FuncM_DrawObjectsForRoom and then Func_ClearRestOfOamAndProcessFrame.
.EXPORT FuncM_DrawObjectsForRoomAndProcessFrame
.PROC FuncM_DrawObjectsForRoomAndProcessFrame
    jsr FuncM_DrawObjectsForRoom
    fall Func_ClearRestOfOamAndProcessFrame
.ENDPROC

;;; Calls Func_ClearRestOfOam and then Func_ProcessFrame.
.EXPORT Func_ClearRestOfOamAndProcessFrame
.PROC Func_ClearRestOfOamAndProcessFrame
    jsr Func_ClearRestOfOam
    fall Func_ProcessFrame
.ENDPROC

;;; Signals that shadow OAM/PPU data is ready to be transferred, then waits for
;;; the next NMI to complete.
;;; @preserve T0+
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
    ;; Set up bank select value to be used by the NMI thread.  Note that any
    ;; IRQs that switch CHR banks while the main thread is blocked on the
    ;; Zp_NmiReady_bool loop below will ensure that this bank select value gets
    ;; restored before the next NMI occurs.
    main_bank_select kSelectChr04
    ;; Tell the NMI handler that we are ready for it to transfer data, then
    ;; wait until it finishes.
    dec Zp_NmiReady_bool  ; change from false ($00) to true ($ff)
    @loop:
    bit Zp_NmiReady_bool  ; loop until high bit is 0 again
    bmi @loop
    ;; Read the joypad for this frame.
    jmp Func_ReadJoypad  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
