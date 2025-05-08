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

.INCLUDE "apu.inc"
.INCLUDE "cpu.inc"
.INCLUDE "irq.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"

.IMPORT Func_AudioReset
.IMPORT Func_ClearRestOfOam
.IMPORT Int_NoopIrq
.IMPORT MainC_Title_Menu
.IMPORT Ppu_ChrBgFontLower
.IMPORT Ppu_ChrObjAnnaNormal
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_NextIrq_int_ptr

;;;=========================================================================;;;

kSharedBgColor = $0f  ; black

;;;=========================================================================;;;

.SEGMENT "PRGE_Reset"

;;; Reset handler, which is jumped to on startup/reset.
;;; @thread RESET
.EXPORT Main_Reset
.PROC Main_Reset
    sei  ; disable maskable (IRQ) interrupts
    cld  ; disable BCD mode (doesn't matter for NES, but may for debuggers)
    ;; Disable VBlank NMI.
    ldx #0
    stx Hw_PpuCtrl_wo   ; disable VBlank NMI
    ;; Initialize stack pointer.
    dex  ; now X is $ff
    txs
    ;; Initialize the MMC and load PRGC_Title.  Since all NMI/IRQ interrupts
    ;; are disabled at this point, we can just do this directly rather than
    ;; using the main_prgc_bank macro, which uses extra instructions in order
    ;; to be interrupt-safe.
    lda #kSelectPrgc
    sta Hw_Mmc3BankSelect_wo
    lda #<.bank(MainC_Title_Reset)
    sta Hw_Mmc3BankData_wo
    ;; Jump to the rest of the reset code (stored in a swappable bank, to save
    ;; valuable space in PRG8 and PRGE).
    jmp MainC_Title_Reset
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGC_Title"

;;; @thread RESET
.PROC MainC_Title_Reset
    ;; Enable SRAM, but disable writes for now.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
_WaitForFirstVBlank:
    ;; We need to wait for the PPU to warm up before can start the game.  The
    ;; standard strategy for this is to wait for two VBlanks to occur (for
    ;; details, see https://www.nesdev.org/wiki/Init_code and
    ;; https://www.nesdev.org/wiki/PPU_power_up_state#Best_practice).  For now,
    ;; we'll wait for first VBlank.
    bit Hw_PpuStatus_ro  ; Reading this implicitly clears the VBlank bit.
    @loop:
    .assert bPpuStatus::VBlank = bProc::Negative, error
    bit Hw_PpuStatus_ro  ; Set N (negative) CPU flag to value of VBlank bit.
    bpl @loop            ; Continue looping until the VBlank bit is set again.
_DisableRendering:
    ;; Now that we're in VBlank, we can disable rendering.  On a true reset,
    ;; the PPU won't be warmed up yet and will ignore these writes, but that's
    ;; okay because on a true reset, rendering is initially disabled anyway.
    ;; On a soft reset, we want to disable rendering during VBlank.
    lda #0
    sta Hw_PpuMask_wo   ; disable rendering
_InitializeRam:
    ;; We've still got time to burn until the second VBlank, so this is a good
    ;; time to initialize RAM.
    tax  ; now x is 0
    @loop:
    .repeat $08, index
    sta $100 * index, x
    .endrepeat
    inx
    bne @loop
    ;; May as well also clear OAM (note that our OAM offset is zero, since we
    ;; just zeroed all of RAM, so this will clear OAM from the beginning).
    jsr Func_ClearRestOfOam
    ;; Initialize HBlank IRQs.
    lda #$ff
    sta Hw_Mmc3IrqLatch_wo
    sta Zp_Active_sIrq + sIrq::Latch_u8
    ldax #Int_NoopIrq
    stax Zp_NextIrq_int_ptr
    stax Zp_Active_sIrq + sIrq::FirstIrq_int_ptr
    ;; Initialize APU.
    jsr Func_AudioReset
_WaitForSecondVBlank:
    ;; Wait for the second VBlank.  After this, the PPU should be warmed up.
    bit Hw_PpuStatus_ro  ; Reading this implicitly clears the VBlank bit.
    @loop:
    .assert bPpuStatus::VBlank = bProc::Negative, error
    bit Hw_PpuStatus_ro  ; Set N (negative) CPU flag to value of VBlank bit.
    bpl @loop            ; Continue looping until the VBlank bit is set again.
_InitPpuMapping:
    ;; Set nametable mirroring to horizontal (which is what we'll want for
    ;; implementing four-way scrolling).
    lda #eMmc3Mirror::Horizontal
    sta Hw_Mmc3Mirroring_wo
    ;; Set all CHR ROM banks to a known state.
    main_chr00_bank Ppu_ChrBgFontLower
    main_chr04_bank Ppu_ChrBgFontLower
    main_chr08_bank Ppu_ChrBgFontLower
    main_chr0c_bank Ppu_ChrBgFontLower
    main_chr10_bank Ppu_ChrObjAnnaNormal
    main_chr18_bank Ppu_ChrObjAnnaNormal
_Finish:
    ;; Enable interrupts and start the game.
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo        ; enable VBlank NMI
    sta Hw_Mmc3IrqEnable_wo  ; enable HBlank IRQ
    cli                      ; enable maskable (IRQ) interrupts
    jmp MainC_Title_Menu
.ENDPROC

;;;=========================================================================;;;
