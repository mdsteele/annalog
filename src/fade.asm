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

.IMPORT Func_ProcessFrame
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_Render_bPpuMask

;;;=========================================================================;;;

kNumFadeSteps = 4
kFramesPerStep = 7

Ppu_BgColors_u6_arr2 = Ppu_Palettes_sPal_arr8 + .sizeof(sPal) * 0 + sPal::C2_u6

;;;=========================================================================;;;

.SEGMENT "PRG8_Fade"

.SCOPE Data_FadeColors
Gray_u6_arr:
    .byte $0f, $0f, $2d, $00
    .assert * - Gray_u6_arr = kNumFadeSteps, error
White_u6_arr:
    .byte $0f, $2d, $3d, $30
    .assert * - White_u6_arr = kNumFadeSteps, error
.ENDSCOPE

;;; Updates PPU palettes for fade step A, then waits for kFramesPerStep frames.
;;; @param A The fade step, from 0 (faded fully out) to kNumFadeSteps - 1.
;;; @preserve A
.PROC Func_FadeTransferAndWait
    ;; Buffer the palette data to be transferred to the PPU.
    tay
    ldx Zp_PpuTransferLen_u8
    lda #bPpuCtrl::EnableNmi
    sta Ram_PpuTransfer_arr + 0, x
    lda #>Ppu_BgColors_u6_arr2
    sta Ram_PpuTransfer_arr + 1, x
    lda #<Ppu_BgColors_u6_arr2
    sta Ram_PpuTransfer_arr + 2, x
    lda #2
    sta Ram_PpuTransfer_arr + 3, x
    lda Data_FadeColors::Gray_u6_arr, y
    sta Ram_PpuTransfer_arr + 4, x
    lda Data_FadeColors::White_u6_arr, y
    sta Ram_PpuTransfer_arr + 5, x
    ;; TODO: Also fade object palettes.
    txa
    add #6
    sta Zp_PpuTransferLen_u8
    tya
    ;; Process kFramesPerStep frames.
    pha
    lda #kFramesPerStep
    @waitLoop:
    pha
    jsr Func_ProcessFrame
    pla
    sub #1
    bne @waitLoop
    pla
    rts
.ENDPROC

;;; Fades in the screen over a number of frames.  Variables such as
;;; Zp_Render_bPpuMask, scrolling, and shadow OAM must be set up before calling
;;; this.
.EXPORT Func_FadeIn
.PROC Func_FadeIn
    lda #0
    @stepLoop:
    jsr Func_FadeTransferAndWait  ; preserves A
    add #1
    cmp #kNumFadeSteps
    bne @stepLoop
    rts
.ENDPROC

;;; Fades out the screen over a number of frames, then disables rendering.
.EXPORT Func_FadeOut
.PROC Func_FadeOut
    lda #kNumFadeSteps - 1
    @stepLoop:
    jsr Func_FadeTransferAndWait  ; preserves A
    sub #1
    bne @stepLoop
    ;; A is now zero, so we can use it to diable rendering.
    sta Zp_Render_bPpuMask
    jmp Func_ProcessFrame
.ENDPROC

;;;=========================================================================;;;
