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

.LINECONT +
Ppu_Bg0Colors_u6_arr2 = \
    Ppu_Palettes_sPal_arr8 + .sizeof(sPal) * 0 + sPal::C2_u6
Ppu_Obj0Colors_u6_arr2 = \
    Ppu_Palettes_sPal_arr8 + .sizeof(sPal) * 4 + sPal::C2_u6
Ppu_Obj1Colors_u6_arr2 = \
    Ppu_Palettes_sPal_arr8 + .sizeof(sPal) * 5 + sPal::C2_u6
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "PRG8_Fade"

.SCOPE Data_FadeColors
Gray_u6_arr:
    .byte $0f, $2d, $2d, $00
    .assert * - Gray_u6_arr = kNumFadeSteps, error
Green_u6_arr:
    .byte $0f, $09, $0a, $1a
    .assert * - Green_u6_arr = kNumFadeSteps, error
Red_u6_arr:
    .byte $0f, $06, $06, $16
    .assert * - Red_u6_arr = kNumFadeSteps, error
White_u6_arr:
    .byte $0f, $2d, $3d, $30
    .assert * - White_u6_arr = kNumFadeSteps, error
.ENDSCOPE

;;; Updates PPU palettes for fade step A, then waits for kFramesPerStep frames.
;;; @param Y The fade step, from 0 (faded fully out) to kNumFadeSteps - 1.
;;; @preserve Y
.PROC Func_FadeTransferAndWait
    ;; Buffer the palette data to be transferred to the PPU.
    ldx Zp_PpuTransferLen_u8
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr +  0, x
    sta Ram_PpuTransfer_arr +  6, x
    sta Ram_PpuTransfer_arr + 12, x
    lda #>Ppu_Bg0Colors_u6_arr2
    sta Ram_PpuTransfer_arr +  1, x
    lda #<Ppu_Bg0Colors_u6_arr2
    sta Ram_PpuTransfer_arr +  2, x
    lda #>Ppu_Obj0Colors_u6_arr2
    sta Ram_PpuTransfer_arr +  7, x
    lda #<Ppu_Obj0Colors_u6_arr2
    sta Ram_PpuTransfer_arr +  8, x
    lda #>Ppu_Obj1Colors_u6_arr2
    sta Ram_PpuTransfer_arr + 13, x
    lda #<Ppu_Obj1Colors_u6_arr2
    sta Ram_PpuTransfer_arr + 14, x
    lda #2
    sta Ram_PpuTransfer_arr +  3, x
    sta Ram_PpuTransfer_arr +  9, x
    sta Ram_PpuTransfer_arr + 15, x
    lda Data_FadeColors::Gray_u6_arr,  y
    sta Ram_PpuTransfer_arr +  4, x
    lda Data_FadeColors::Red_u6_arr,   y
    sta Ram_PpuTransfer_arr + 10, x
    lda Data_FadeColors::Green_u6_arr, y
    sta Ram_PpuTransfer_arr + 16, x
    lda Data_FadeColors::White_u6_arr, y
    sta Ram_PpuTransfer_arr +  5, x
    sta Ram_PpuTransfer_arr + 11, x
    sta Ram_PpuTransfer_arr + 17, x
    txa
    add #18
    sta Zp_PpuTransferLen_u8
    ;; Process kFramesPerStep frames.
    tya
    pha
    lda #kFramesPerStep
    @waitLoop:
    pha
    jsr Func_ProcessFrame
    pla
    sub #1
    bne @waitLoop
    pla
    tay
    rts
.ENDPROC

;;; Fades in the screen over a number of frames.  Variables such as
;;; Zp_Render_bPpuMask, scrolling, and shadow OAM must be set up before calling
;;; this.
.EXPORT Func_FadeIn
.PROC Func_FadeIn
    ldy #0
    @stepLoop:
    jsr Func_FadeTransferAndWait  ; preserves Y
    iny
    cpy #kNumFadeSteps
    bne @stepLoop
    rts
.ENDPROC

;;; Fades out the screen over a number of frames, then disables rendering.
.EXPORT Func_FadeOut
.PROC Func_FadeOut
    ldy #kNumFadeSteps - 1
    @stepLoop:
    jsr Func_FadeTransferAndWait  ; preserves Y
    dey
    bne @stepLoop
    ;; Y is now zero, so we can use it to diable rendering.
    sty Zp_Render_bPpuMask
    jmp Func_ProcessFrame
.ENDPROC

;;;=========================================================================;;;
