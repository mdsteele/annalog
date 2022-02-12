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
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

kNumFadeSteps = 4
kFramesPerStep = 7

.DEFINE kNumTransferEntries 4
.DEFINE kTransferDataLen 2
kTransferEntryLen = 4 + kTransferDataLen
kTotalTransferLen = kTransferEntryLen * kNumTransferEntries

.LINECONT +
Ppu_Bg0Colors_u6_arr2 = \
    Ppu_Palettes_sPal_arr8 + .sizeof(sPal) * 0 + sPal::C2_u6
Ppu_Obj0Colors_u6_arr2 = \
    Ppu_Palettes_sPal_arr8 + .sizeof(sPal) * 4 + sPal::C2_u6
Ppu_Obj1Colors_u6_arr2 = \
    Ppu_Palettes_sPal_arr8 + .sizeof(sPal) * 5 + sPal::C2_u6
Ppu_Obj2Colors_u6_arr2 = \
    Ppu_Palettes_sPal_arr8 + .sizeof(sPal) * 6 + sPal::C2_u6
.DEFINE TransferAddrs \
    Ppu_Bg0Colors_u6_arr2 \
    Ppu_Obj0Colors_u6_arr2 \
    Ppu_Obj1Colors_u6_arr2 \
    Ppu_Obj2Colors_u6_arr2
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

.PROC Data_FadeTransferTemplate_u8_arr
:   .repeat kNumTransferEntries, i
    .byte kPpuCtrlFlagsHorz
    .byte >.mid(i, 1, {TransferAddrs})
    .byte <.mid(i, 1, {TransferAddrs})
    .byte kTransferDataLen
    .res kTransferDataLen
    .endrepeat
    .assert * - :- = kTotalTransferLen, error
.ENDPROC

;;; Updates PPU palettes for fade step A, then waits for kFramesPerStep frames.
;;; @param Y The fade step, from 0 (faded fully out) to kNumFadeSteps - 1.
;;; @preserve Y
.PROC Func_FadeTransferAndWait
    ;; Write entry headers for all the transfer entries.
    sty Zp_Tmp1_byte  ; fade step
    ldx Zp_PpuTransferLen_u8
    ldy #0
    @loop:
    lda Data_FadeTransferTemplate_u8_arr, y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #kTotalTransferLen
    bne @loop
    lda Zp_PpuTransferLen_u8
    stx Zp_PpuTransferLen_u8
    tax
    ldy Zp_Tmp1_byte  ; fade step
    ;; Fill in the data to transfer for all the entries.
    lda Data_FadeColors::Gray_u6_arr,  y
    sta Ram_PpuTransfer_arr + kTransferEntryLen * 0 + 4, x
    sta Ram_PpuTransfer_arr + kTransferEntryLen * 1 + 4, x
    lda Data_FadeColors::Red_u6_arr,   y
    sta Ram_PpuTransfer_arr + kTransferEntryLen * 2 + 4, x
    lda Data_FadeColors::Green_u6_arr, y
    sta Ram_PpuTransfer_arr + kTransferEntryLen * 3 + 4, x
    lda Data_FadeColors::White_u6_arr, y
    .repeat kNumTransferEntries, i
    sta Ram_PpuTransfer_arr + kTransferEntryLen * i + 5, x
    .endrepeat
_Wait:
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
