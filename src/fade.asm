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
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

kColorBlack    = $0f  ; black
kColorGray3    = $00  ; dark gray
kColorGray2    = $2d  ; darker gray
kColorGray1    = $2d  ; darker gray
kColorGreen3   = $1a  ; medium green
kColorGreen2   = $0a  ; dark green
kColorGreen1   = $09  ; dark chartreuse
kColorRed3     = $16  ; medium red
kColorRed2     = $06  ; dark red
kColorRed1     = $06  ; dark red
kColorWhite3   = $30  ; white
kColorWhite2   = $3d  ; light gray
kColorWhite1   = $2d  ; dark gray

kNumFadeSteps = 4
kFramesPerStep = 5

kPalettesTransferLen = .sizeof(sPal) * 8

.LINECONT +
.DEFINE PalettesPtrs \
    DataA_Fade_Palettes1_sPal_arr8, \
    DataA_Fade_Palettes2_sPal_arr8, \
    DataA_Fade_Palettes3_sPal_arr8
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "PRGA_Fade"

;;; Pointers to palette sets for each nonzero fade step, indexed by (step - 1).
.PROC DataA_Fade_Palettes_sPal_arr8_ptr_0_arr
    .lobytes PalettesPtrs
.ENDPROC
.PROC DataA_Fade_Palettes_sPal_arr8_ptr_1_arr
    .hibytes PalettesPtrs
.ENDPROC

;;; The palette set for fade step 3.
.PROC DataA_Fade_Palettes3_sPal_arr8
    .repeat 2
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorGray3
    d_byte C3_u6, kColorWhite3
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorRed3
    d_byte C3_u6, kColorWhite3
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorGreen3
    d_byte C3_u6, kColorWhite3
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorRed3
    d_byte C3_u6, kColorWhite3
    D_END
    .endrepeat
.ENDPROC

;;; The palette set for fade step 2.
.PROC DataA_Fade_Palettes2_sPal_arr8
    .repeat 2
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorGray2
    d_byte C3_u6, kColorWhite2
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorRed2
    d_byte C3_u6, kColorWhite2
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorGreen2
    d_byte C3_u6, kColorWhite2
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorRed3
    d_byte C3_u6, kColorWhite3
    D_END
    .endrepeat
.ENDPROC

;;; The palette set for fade step 1.
.PROC DataA_Fade_Palettes1_sPal_arr8
    .repeat 2
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorGray1
    d_byte C3_u6, kColorWhite1
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorRed1
    d_byte C3_u6, kColorWhite1
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorGreen1
    d_byte C3_u6, kColorWhite1
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorRed3
    d_byte C3_u6, kColorWhite3
    D_END
    .endrepeat
.ENDPROC

;;; Updates PPU palettes and/or Zp_Render_bPpuMask for the specified fade step.
;;; @param Y The fade step, from 0 (faded fully out) to kNumFadeSteps - 1.
;;; @preserve Y
.PROC FuncA_Fade_TransferPalettes
    sty Zp_Tmp1_byte  ; fade step
    bne @enable
    sty Zp_Render_bPpuMask
    rts
    @enable:
    ;; Make Zp_Tmp_ptr point to the palettes array for this fade step.
    dey
    lda DataA_Fade_Palettes_sPal_arr8_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda DataA_Fade_Palettes_sPal_arr8_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    ;; Write the transfer entry header.
    ldx Zp_PpuTransferLen_u8
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr, x
    inx
    lda #>Ppu_Palettes_sPal_arr8
    sta Ram_PpuTransfer_arr, x
    inx
    lda #<Ppu_Palettes_sPal_arr8
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kPalettesTransferLen
    sta Ram_PpuTransfer_arr, x
    inx
    ;; Write the transfer entry data.
    ldy #0
    @loop:
    lda (Zp_Tmp_ptr), y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #kPalettesTransferLen
    blt @loop
    ;; Update the PPU transfer array length and restore Y.
    stx Zp_PpuTransferLen_u8
    ldy Zp_Tmp1_byte  ; fade step
    rts
.ENDPROC

;;; Waits for kFramesPerStep frames.
;;; @preserve Y
.PROC FuncA_Fade_Wait
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
;;; @prereq Rendering is disabled.
.EXPORT FuncA_Fade_In
.PROC FuncA_Fade_In
    ;; Note that even with rendering disabled (as it is now), palette data
    ;; should only be updated during VBlank, since otherwise we may glitch the
    ;; background color (see https://www.nesdev.org/wiki/The_frame_and_NMIs).
    ;; So we always use the PPU transfer array instead of writing palette data
    ;; directly to the PPU.
    ldy #1
    @stepLoop:
    jsr FuncA_Fade_TransferPalettes  ; preserves Y
    jsr FuncA_Fade_Wait              ; preserves Y
    iny
    cpy #kNumFadeSteps
    blt @stepLoop
    rts
.ENDPROC

;;; Fades out the screen over a number of frames, then disables rendering.
.EXPORT FuncA_Fade_Out
.PROC FuncA_Fade_Out
    jsr FuncA_Fade_Wait
    ldy #kNumFadeSteps - 2
    @stepLoop:
    jsr FuncA_Fade_TransferPalettes  ; preserves Y
    jsr FuncA_Fade_Wait              ; preserves Y
    dey
    bpl @stepLoop
    rts
.ENDPROC

;;;=========================================================================;;;
