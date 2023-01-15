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

.INCLUDE "fade.inc"
.INCLUDE "macros.inc"
.INCLUDE "ppu.inc"

.IMPORT Func_ProcessFrame
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
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

;;; How many frames to wait between fade steps for normal/slow fade functions.
kFramesPerFadeStepNormal = 5
kFramesPerFadeStepSlow   = 11

kPalettesTransferLen = .sizeof(sPal) * 8

;;;=========================================================================;;;

.SEGMENT "PRGA_Fade"

.REPEAT 2, table
    D_TABLE_LO table, DataA_Fade_Palettes_sPal_arr8_ptr_0_arr
    D_TABLE_HI table, DataA_Fade_Palettes_sPal_arr8_ptr_1_arr
    D_TABLE eFade
    d_entry table, Black,  DataA_Fade_Palettes0_sPal_arr8
    d_entry table, Dark,   DataA_Fade_Palettes1_sPal_arr8
    d_entry table, Dim,    DataA_Fade_Palettes2_sPal_arr8
    d_entry table, Normal, DataA_Fade_Palettes3_sPal_arr8
    D_END
.ENDREPEAT

;;; The palette set for fade step 3 (normal).
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

;;; The palette set for fade step 2 (dim).
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

;;; The palette set for fade step 1 (dark).
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

;;; The palette set for fade step 0 (black).
.PROC DataA_Fade_Palettes0_sPal_arr8
    .repeat 2
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorBlack
    d_byte C3_u6, kColorBlack
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorBlack
    d_byte C3_u6, kColorBlack
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorBlack
    d_byte C3_u6, kColorBlack
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack
    d_byte C1_u6, kColorBlack
    d_byte C2_u6, kColorRed3
    d_byte C3_u6, kColorWhite3
    D_END
    .endrepeat
.ENDPROC

;;; Buffers a PPU transfer to write palette colors for the specified fade
;;; level.
;;; @param Y The eFade value for the palettes to transfer.
;;; @preserve X, Y
.EXPORT FuncA_Fade_TransferPalettes
.PROC FuncA_Fade_TransferPalettes
    sty Zp_Tmp1_byte  ; fade step
    stx Zp_Tmp2_byte  ; old X register (just to preserve it)
    ;; Make Zp_Tmp_ptr point to the palettes array for this fade step.
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
    ldy Zp_Tmp1_byte  ; fade step (just to preserve Y)
    ldx Zp_Tmp2_byte  ; old X register (just to preserve X)
    rts
.ENDPROC

;;; Calls Func_ProcessFrame the specified number of times.
;;; @param X The number of frames to wait (must be nonzero).
;;; @preserve X, Y
.PROC FuncA_Fade_Wait
    tya
    pha
    txa
    pha
    @waitLoop:
    pha
    jsr Func_ProcessFrame
    pla
    sub #1
    bne @waitLoop
    pla
    tax
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
    ldx #kFramesPerFadeStepNormal  ; param: num frames to wait
    ;; Note that even with rendering disabled (as it is now), palette data
    ;; should only be updated during VBlank, since otherwise we may glitch the
    ;; background color (see https://www.nesdev.org/wiki/The_frame_and_NMIs).
    ;; So we always use the PPU transfer array instead of writing palette data
    ;; directly to the PPU.
    ldy #eFade::Black
    @stepLoop:
    .assert eFade::Normal > eFade::Black, error
    iny
    jsr FuncA_Fade_TransferPalettes  ; preserves X and Y
    jsr FuncA_Fade_Wait  ; preserves X and Y
    cpy #eFade::Normal
    bne @stepLoop
    rts
.ENDPROC

;;; Fades out the screen over a number of frames (using the normal fade speed),
;;; then disables rendering.
.EXPORT FuncA_Fade_Out
.PROC FuncA_Fade_Out
    ldx #kFramesPerFadeStepNormal  ; param: num frames between fade steps
    bne FuncA_Fade_OutWithSlowdown  ; unconditional
.ENDPROC

;;; Fades out the screen over a number of frames (using a slower fade speed),
;;; then disables rendering.
.EXPORT FuncA_Fade_OutSlowly
.PROC FuncA_Fade_OutSlowly
    ldx #kFramesPerFadeStepSlow  ; param: num frames between fade steps
    .assert * = FuncA_Fade_OutWithSlowdown, error, "fallthrough"
.ENDPROC

;;; Fades out the screen over a number of frames (as specified by the given
;;; delay), then disables rendering.
;;; @param X The number of frames to wait between fade steps.
.PROC FuncA_Fade_OutWithSlowdown
    jsr FuncA_Fade_ToBlackWithSlowdown  ; preserves X
    lda #0
    sta Zp_Render_bPpuMask
    jmp FuncA_Fade_Wait
.ENDPROC

;;; Fades out the screen over a number of frames (using the normal fade speed),
;;; but leaves rendering enabled.
.EXPORT FuncA_Fade_ToBlack
.PROC FuncA_Fade_ToBlack
    ldx #kFramesPerFadeStepNormal  ; param: num frames between fade steps
    .assert * = FuncA_Fade_ToBlackWithSlowdown, error, "fallthrough"
.ENDPROC

;;; Fades out the screen over a number of frames (as specified by the given
;;; delay), but leaves rendering enabled.
;;; @param X The number of frames to wait between fade steps.
;;; @preserve X
.PROC FuncA_Fade_ToBlackWithSlowdown
    ldy #eFade::Normal
    @stepLoop:
    jsr FuncA_Fade_Wait  ; preserves X and Y
    .assert eFade::Black < eFade::Normal, error
    dey
    jsr FuncA_Fade_TransferPalettes  ; preserves X and Y
    tya
    .assert eFade::Black = 0, error
    bne @stepLoop
    rts
.ENDPROC

;;;=========================================================================;;;
