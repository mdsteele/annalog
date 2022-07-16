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
.IMPORT Main_Title
.IMPORT Ppu_ChrBgFontLower01
.IMPORT Ppu_ChrBgFontUpper
.IMPORT Ppu_ChrBgPause
.IMPORT Ppu_ChrObjAnnaNormal
.IMPORT Ppu_ChrObjUpgrade
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_NextIrq_int_ptr

;;;=========================================================================;;;

kSharedBgColor = $0f  ; black

;;;=========================================================================;;;

.SEGMENT "PRGE_Reset"

;;; Reset handler, which is jumped to on startup/reset.
.EXPORT Main_Reset
.PROC Main_Reset
    sei  ; disable maskable (IRQ) interrupts
    cld  ; disable BCD mode (doesn't matter for NES, but may for debuggers)
    ;; Disable VBlank NMI.
    ldx #0
    stx Hw_PpuCtrl_wo   ; disable VBlank NMI
    ;; Initialize stack pointer.
    dex  ; now x is $ff
    txs
    ;; Set mapper PRG ROM bank for $a000 and jump to rest of reset code.
    prga_bank #<.bank(MainA_Reset_Ext)
    jmp MainA_Reset_Ext
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Reset"

.PROC MainA_Reset_Ext
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
    ;; May as well also clear OAM (note that Zp_OamOffset_u8 is zero, since we
    ;; just zeroed all of RAM).
    jsr Func_ClearRestOfOam
    ;; Initialize HBlank IRQs.
    lda #$ff
    sta Hw_Mmc3IrqLatch_wo
    sta <(Zp_Active_sIrq + sIrq::Latch_u8)
    ldax #Int_NoopIrq
    stax Zp_NextIrq_int_ptr
    stax <(Zp_Active_sIrq + sIrq::FirstIrq_int_ptr)
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
    chr00_bank #<.bank(Ppu_ChrBgFontUpper)
    chr04_bank #<.bank(Ppu_ChrBgFontLower01)
    chr08_bank #<.bank(Ppu_ChrBgPause)
    chr0c_bank #<.bank(Ppu_ChrBgPause)
    chr10_bank #<.bank(Ppu_ChrObjAnnaNormal)
    chr18_bank #<.bank(Ppu_ChrObjUpgrade)
_InitAttributeTable0:
    ;; Set all blocks in nametable 0 to use BG palette 0.
    ldax #Ppu_Nametable0_sName + sName::Attrs_u8_arr64
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda #0
    ldx #64
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
_InitAttributeTable3:
    ;; Set all blocks in nametable 3 to use BG palette 0.
    ldax #Ppu_Nametable3_sName + sName::Attrs_u8_arr64
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda #0
    ldx #64
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
_Finish:
    ;; Enable interrupts and start the game.
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo        ; enable VBlank NMI
    sta Hw_Mmc3IrqEnable_wo  ; enable HBlank IRQ
    cli                      ; enable maskable (IRQ) interrupts
    jmp Main_Title
.ENDPROC

;;;=========================================================================;;;
