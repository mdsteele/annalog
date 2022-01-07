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
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"

.IMPORT Func_ClearRestOfOam
.IMPORT Main_Title
.IMPORT Ppu_ChrCave
.IMPORT Ppu_ChrFont
.IMPORT Ppu_ChrPlayer

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
    prga_bank #<.bank(MainA_ResetExt)
    jmp MainA_ResetExt
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_ResetExt"

.PROC MainA_ResetExt
    ;; Disable SRAM access for now.
    lda #bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
_WaitForFirstVBlank:
    ;; We need to wait for the PPU to warm up before can start the game.  The
    ;; standard strategy for this is to wait for two VBlanks to occur (for
    ;; details, see https://wiki.nesdev.org/w/index.php/Init_code and
    ;; https://wiki.nesdev.org/w/index.php/PPU_power_up_state#Best_practice).
    ;; For now, we'll wait for first VBlank.
    bit Hw_PpuStatus_ro  ; Reading this implicitly clears the VBlank bit.
    @loop:
    bit Hw_PpuStatus_ro  ; Set N (negative) CPU flag to value of VBlank bit.
    bpl @loop            ; Continue looping until the VBlank bit is set again.
_DisableRenderingAndIrqs:
    ;; Now that we're in VBlank, we can disable rendering.  On a true reset,
    ;; the PPU won't be warmed up yet and will ignore these writes, but that's
    ;; okay because on a true reset, rendering is initially disabled anyway.
    ;; On a soft reset, we want to disable rendering during VBlank.
    lda #0
    sta Hw_PpuMask_wo   ; disable rendering
    ;; Disable all IRQ sources for now.
    sta Hw_Mmc3IrqDisable_wo  ; disable MMC3 IRQ
    sta Hw_DmcFlags_wo        ; disable DMC IRQ
    ldx #bApuCount::DisableIrq
    stx Hw_ApuCount_wo        ; disable APU counter IRQ
_ClearRam:
    ;; We've still got time to burn until the second VBlank, so this is a good
    ;; time to initialize RAM.
    tax  ; now x is 0
    @loop:
    sta $0000, x
    sta $0100, x
    sta $0200, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    inx
    bne @loop
    jsr Func_ClearRestOfOam
_WaitForSecondVBlank:
    ;; Wait for the second VBlank.  After this, the PPU should be warmed up.
    bit Hw_PpuStatus_ro  ; Reading this implicitly clears the VBlank bit.
    @loop:
    bit Hw_PpuStatus_ro  ; Set N (negative) CPU flag to value of VBlank bit.
    bpl @loop            ; Continue looping until the VBlank bit is set again.
_InitPalettes:
    ;; We're back in VBlank, and the PPU should be warmed up now, so this is a
    ;; good time to initialize our palette data.  Note that even when rendering
    ;; is disabled (as it is right now), palette data should only be updated
    ;; during VBlank, since otherwise we may glitch the backgroundc color (see
    ;; https://wiki.nesdev.org/w/index.php/The_frame_and_NMIs).
    ldax #Ppu_Palettes_sPal_arr8
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    ldx #0
    ldy #.sizeof(sPal) * 8
    @loop:
    lda DataA_ResetExt_Palettes_sPal_arr8, x
    sta Hw_PpuData_rw
    inx
    dey
    bne @loop
_InitPpuMapping:
    ;; Set nametable mirroring to horizontal (which is what we'll want for
    ;; implementing four-way scrolling).
    lda #eMmc3Mirror::Horizontal
    sta Hw_Mmc3Mirroring_wo
    ;; Set all CHR ROM banks to a known state.
    chr00_bank #<.bank(Ppu_ChrFont)
    chr04_bank #<.bank(Ppu_ChrFont) + 1
    chr08_bank #<.bank(Ppu_ChrCave)
    chr0c_bank #3
    chr10_bank #<.bank(Ppu_ChrPlayer)
    chr18_bank #6
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
    lda #bPpuCtrl::EnableNmi | bPpuCtrl::ObjPat1
    sta Hw_PpuCtrl_wo  ; enable VBlank NMI
    cli                ; enable maskable (IRQ) interrupts
    jmp Main_Title
.ENDPROC

.PROC DataA_ResetExt_Palettes_sPal_arr8
    .repeat 4
    ;; BG palette 0:
    .byte kSharedBgColor
    .byte $0f  ; black
    .byte $00  ; dark gray
    .byte $30  ; white
    .endrepeat
    .repeat 2
    ;; Obj palette 0:
    .byte kSharedBgColor
    .byte $0f  ; black
    .byte $16  ; medium red
    .byte $30  ; white
    ;; Obj palette 1:
    .byte kSharedBgColor
    .byte $0f  ; black
    .byte $1a  ; medium green
    .byte $30  ; white
    .endrepeat
.ENDPROC
.ASSERT * - DataA_ResetExt_Palettes_sPal_arr8 = .sizeof(sPal) * 8, error

;;;=========================================================================;;;
