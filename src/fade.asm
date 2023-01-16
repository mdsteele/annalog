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

kColorBlack6 = $30  ; white
kColorBlack5 = $3d  ; light gray
kColorBlack4 = $2d  ; dark gray
kColorBlack3 = $0f  ; black
kColorBlack2 = $0f  ; black
kColorBlack1 = $0f  ; black
kColorBlack0 = $0f  ; black

kColorGray6  = $30  ; white
kColorGray5  = $3d  ; light gray
kColorGray4  = $3d  ; light gray
kColorGray3  = $00  ; dark gray
kColorGray2  = $2d  ; darker gray
kColorGray1  = $2d  ; darker gray
kColorGray0  = $0f  ; black

kColorGreen6 = $30  ; white
kColorGreen5 = $3a  ; pale green
kColorGreen4 = $2a  ; light green
kColorGreen3 = $1a  ; medium green
kColorGreen2 = $0a  ; dark green
kColorGreen1 = $09  ; dark chartreuse
kColorGreen0 = $0f  ; black

kColorRed6   = $30  ; white
kColorRed5   = $36  ; pale red
kColorRed4   = $26  ; light red
kColorRed3   = $16  ; medium red
kColorRed2   = $06  ; dark red
kColorRed1   = $06  ; dark red
kColorRed0   = $0f  ; black

kColorWhite6 = $30  ; white
kColorWhite5 = $30  ; white
kColorWhite4 = $30  ; white
kColorWhite3 = $30  ; white
kColorWhite2 = $3d  ; light gray
kColorWhite1 = $2d  ; dark gray
kColorWhite0 = $0f  ; black

;;; How many frames to wait between fade steps for normal/slow fade functions.
kFramesPerFadeStepNormal = 5
kFramesPerFadeStepSlow   = 11

kPalettesTransferLen = .sizeof(sPal) * 8

;;;=========================================================================;;;

.SEGMENT "PRG8"

.REPEAT 2, table
    D_TABLE_LO table, Data_FadePalettes_sPal_arr4_ptr_0_arr
    D_TABLE_HI table, Data_FadePalettes_sPal_arr4_ptr_1_arr
    D_TABLE eFade
    d_entry table, Black,  Data_FadePalettes0_sPal_arr4
    d_entry table, Dark,   Data_FadePalettes1_sPal_arr4
    d_entry table, Dim,    Data_FadePalettes2_sPal_arr4
    d_entry table, Normal, Data_FadePalettes3_sPal_arr4
    d_entry table, Light,  Data_FadePalettes4_sPal_arr4
    d_entry table, Bright, Data_FadePalettes5_sPal_arr4
    d_entry table, White,  Data_FadePalettes6_sPal_arr4
    D_END
.ENDREPEAT

;;; The palette set for fade step 6 (white).
.PROC Data_FadePalettes6_sPal_arr4
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack6
    d_byte C1_u6, kColorBlack6
    d_byte C2_u6, kColorGray6
    d_byte C3_u6, kColorWhite6
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack6
    d_byte C1_u6, kColorBlack6
    d_byte C2_u6, kColorRed6
    d_byte C3_u6, kColorWhite6
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack6
    d_byte C1_u6, kColorBlack6
    d_byte C2_u6, kColorGreen6
    d_byte C3_u6, kColorWhite6
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack3
    d_byte C1_u6, kColorBlack3
    d_byte C2_u6, kColorRed3
    d_byte C3_u6, kColorWhite3
    D_END
.ENDPROC

;;; The palette set for fade step 5 (bright).
.PROC Data_FadePalettes5_sPal_arr4
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack5
    d_byte C1_u6, kColorBlack5
    d_byte C2_u6, kColorGray5
    d_byte C3_u6, kColorWhite5
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack5
    d_byte C1_u6, kColorBlack5
    d_byte C2_u6, kColorRed5
    d_byte C3_u6, kColorWhite5
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack5
    d_byte C1_u6, kColorBlack5
    d_byte C2_u6, kColorGreen5
    d_byte C3_u6, kColorWhite5
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack3
    d_byte C1_u6, kColorBlack3
    d_byte C2_u6, kColorRed3
    d_byte C3_u6, kColorWhite3
    D_END
.ENDPROC

;;; The palette set for fade step 4 (light).
.PROC Data_FadePalettes4_sPal_arr4
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack4
    d_byte C1_u6, kColorBlack4
    d_byte C2_u6, kColorGray4
    d_byte C3_u6, kColorWhite4
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack4
    d_byte C1_u6, kColorBlack4
    d_byte C2_u6, kColorRed4
    d_byte C3_u6, kColorWhite4
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack4
    d_byte C1_u6, kColorBlack4
    d_byte C2_u6, kColorGreen4
    d_byte C3_u6, kColorWhite4
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack3
    d_byte C1_u6, kColorBlack3
    d_byte C2_u6, kColorRed3
    d_byte C3_u6, kColorWhite3
    D_END
.ENDPROC

;;; The palette set for fade step 3 (normal).
.PROC Data_FadePalettes3_sPal_arr4
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack3
    d_byte C1_u6, kColorBlack3
    d_byte C2_u6, kColorGray3
    d_byte C3_u6, kColorWhite3
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack3
    d_byte C1_u6, kColorBlack3
    d_byte C2_u6, kColorRed3
    d_byte C3_u6, kColorWhite3
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack3
    d_byte C1_u6, kColorBlack3
    d_byte C2_u6, kColorGreen3
    d_byte C3_u6, kColorWhite3
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack3
    d_byte C1_u6, kColorBlack3
    d_byte C2_u6, kColorRed3
    d_byte C3_u6, kColorWhite3
    D_END
.ENDPROC

;;; The palette set for fade step 2 (dim).
.PROC Data_FadePalettes2_sPal_arr4
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack2
    d_byte C1_u6, kColorBlack2
    d_byte C2_u6, kColorGray2
    d_byte C3_u6, kColorWhite2
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack2
    d_byte C1_u6, kColorBlack2
    d_byte C2_u6, kColorRed2
    d_byte C3_u6, kColorWhite2
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack2
    d_byte C1_u6, kColorBlack2
    d_byte C2_u6, kColorGreen2
    d_byte C3_u6, kColorWhite2
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack3
    d_byte C1_u6, kColorBlack3
    d_byte C2_u6, kColorRed3
    d_byte C3_u6, kColorWhite3
    D_END
.ENDPROC

;;; The palette set for fade step 1 (dark).
.PROC Data_FadePalettes1_sPal_arr4
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack1
    d_byte C1_u6, kColorBlack1
    d_byte C2_u6, kColorGray1
    d_byte C3_u6, kColorWhite1
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack1
    d_byte C1_u6, kColorBlack1
    d_byte C2_u6, kColorRed1
    d_byte C3_u6, kColorWhite1
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack1
    d_byte C1_u6, kColorBlack1
    d_byte C2_u6, kColorGreen1
    d_byte C3_u6, kColorWhite1
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack3
    d_byte C1_u6, kColorBlack3
    d_byte C2_u6, kColorRed3
    d_byte C3_u6, kColorWhite3
    D_END
.ENDPROC

;;; The palette set for fade step 0 (black).
.PROC Data_FadePalettes0_sPal_arr4
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack0
    d_byte C1_u6, kColorBlack0
    d_byte C2_u6, kColorGray0
    d_byte C3_u6, kColorWhite0
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack0
    d_byte C1_u6, kColorBlack0
    d_byte C2_u6, kColorRed0
    d_byte C3_u6, kColorWhite0
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack0
    d_byte C1_u6, kColorBlack0
    d_byte C2_u6, kColorGreen0
    d_byte C3_u6, kColorWhite0
    D_END
    D_STRUCT sPal
    d_byte C0_u6, kColorBlack3
    d_byte C1_u6, kColorBlack3
    d_byte C2_u6, kColorRed3
    d_byte C3_u6, kColorWhite3
    D_END
.ENDPROC

;;; Buffers a PPU transfer to write palette colors for the specified fade
;;; level.
;;; @param Y The eFade value for the palettes to transfer.
;;; @preserve X, Y
.EXPORT Func_TransferPalettes
.PROC Func_TransferPalettes
    sty Zp_Tmp1_byte  ; fade step
    stx Zp_Tmp2_byte  ; old X register (just to preserve it)
    ;; Make Zp_Tmp_ptr point to the palettes array for this fade step.
    lda Data_FadePalettes_sPal_arr4_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda Data_FadePalettes_sPal_arr4_ptr_1_arr, y
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
    lda #.sizeof(sPal) * 8
    sta Ram_PpuTransfer_arr, x
    inx
    ;; Write the transfer entry data.
    jsr _WritePaletteData
    jsr _WritePaletteData
    ;; Update the PPU transfer array length and restore X and Y.
    stx Zp_PpuTransferLen_u8
    ldy Zp_Tmp1_byte  ; fade step (just to preserve Y)
    ldx Zp_Tmp2_byte  ; old X register (just to preserve X)
    rts
_WritePaletteData:
    ldy #0
    @loop:
    lda (Zp_Tmp_ptr), y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #.sizeof(sPal) * 4
    blt @loop
    rts
.ENDPROC

;;; Calls Func_ProcessFrame the specified number of times.
;;; @param X The number of frames to wait (must be nonzero).
;;; @preserve X, Y
.PROC Func_WaitXFrames
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
.EXPORT Func_FadeInFromBlack
.PROC Func_FadeInFromBlack
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
    jsr Func_TransferPalettes  ; preserves X and Y
    jsr Func_WaitXFrames  ; preserves X and Y
    cpy #eFade::Normal
    bne @stepLoop
    rts
.ENDPROC

;;; Fades out the screen over a number of frames (using the normal fade speed),
;;; then disables rendering.
.EXPORT Func_FadeOutToBlack
.PROC Func_FadeOutToBlack
    ldx #kFramesPerFadeStepNormal  ; param: num frames between fade steps
    bne Func_FadeOutToBlackWithSlowdown  ; unconditional
.ENDPROC

;;; Fades out the screen over a number of frames (using a slower fade speed),
;;; then disables rendering.
.EXPORT Func_FadeOutToBlackSlowly
.PROC Func_FadeOutToBlackSlowly
    ldx #kFramesPerFadeStepSlow  ; param: num frames between fade steps
    .assert * = Func_FadeOutToBlackWithSlowdown, error, "fallthrough"
.ENDPROC

;;; Fades out the screen over a number of frames (as specified by the given
;;; delay), then disables rendering.
;;; @param X The number of frames to wait between fade steps.
.PROC Func_FadeOutToBlackWithSlowdown
    jsr Func_FadeToBlackWithSlowdown  ; preserves X
    lda #0
    sta Zp_Render_bPpuMask
    jmp Func_WaitXFrames
.ENDPROC

;;; Fades out the screen over a number of frames (using the normal fade speed),
;;; but leaves rendering enabled.
.EXPORT Func_FadeToBlack
.PROC Func_FadeToBlack
    ldx #kFramesPerFadeStepNormal  ; param: num frames between fade steps
    .assert * = Func_FadeToBlackWithSlowdown, error, "fallthrough"
.ENDPROC

;;; Fades out the screen over a number of frames (as specified by the given
;;; delay), but leaves rendering enabled.
;;; @param X The number of frames to wait between fade steps.
;;; @preserve X
.PROC Func_FadeToBlackWithSlowdown
    ldy #eFade::Normal
    @stepLoop:
    jsr Func_WaitXFrames  ; preserves X and Y
    .assert eFade::Black < eFade::Normal, error
    dey
    jsr Func_TransferPalettes  ; preserves X and Y
    tya
    .assert eFade::Black = 0, error
    bne @stepLoop
    rts
.ENDPROC

;;;=========================================================================;;;
