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

.INCLUDE "audio.inc"
.INCLUDE "charmap.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "newgame.inc"
.INCLUDE "ppu.inc"

.IMPORT DataA_Pcm0_Well_arr
.IMPORT DataA_Pcm1_MaybeThisTime_arr
.IMPORT DataA_Pcm2_WillBeDifferent_arr
.IMPORT FuncC_Title_ClearNametableTiles
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_ClearRestOfOam
.IMPORT Func_FadeInFromBlackToNormal
.IMPORT Func_FillUpperAttributeTable
.IMPORT Func_PlayPrgaPcm
.IMPORT Func_ProcessFrame
.IMPORT Func_WaitXFrames
.IMPORT Func_Window_Disable
.IMPORT MainC_Title_BeginGame
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask

;;;=========================================================================;;;

;;; The PPU addresses for the start (left) of each row of the prologue text.
.LINECONT +
Ppu_PrologueTextRow1Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * 12 + (kScreenWidthTiles - 7) / 2
Ppu_PrologueTextRow2Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * 14 + (kScreenWidthTiles - 15) / 2
Ppu_PrologueTextRow3Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * 16 + (kScreenWidthTiles - 18) / 2
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "PRGC_Title"

;;; The PPU transfer entry for drawing the prologue text.
.PROC DataC_Title_PrologueTextTransfer_arr
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_PrologueTextRow1Start  ; transfer destination
    .byte 7
    .byte "Well..."
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_PrologueTextRow2Start  ; transfer destination
    .byte 15
    .byte "Maybe this time"
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_PrologueTextRow3Start  ; transfer destination
    .byte 18
    .byte "will be different."
.ENDPROC

;;; Mode for running the story prologue when a new game is started.
;;; @prereq Rendering is disabled.
;;; @prereq No saved game exists.
.EXPORT MainC_Title_Prologue
.PROC MainC_Title_Prologue
    jsr Func_Window_Disable
    jsr Func_ClearRestOfOam
    ;; Disable audio.
    lda #0
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Enable_bool
    jsr Func_ProcessFrame
    ;; Clear the upper nametable.
    ldxy #Ppu_Nametable0_sName  ; param: nametable addr
    jsr FuncC_Title_ClearNametableTiles
    ldy #$00  ; param: attribute byte
    jsr Func_FillUpperAttributeTable
    ;; Draw the prologue text.
    ldax #DataC_Title_PrologueTextTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataC_Title_PrologueTextTransfer_arr)  ; param: data length
    jsr Func_BufferPpuTransfer
    ;; Fade in the screen.
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    jsr Func_FadeInFromBlackToNormal
    ldx #10  ; param: num frames
    jsr Func_WaitXFrames
    ;; Play the prologue PCM data.
    main_prga_bank DataA_Pcm0_Well_arr
    jsr Func_PlayPrgaPcm
    main_prga_bank DataA_Pcm1_MaybeThisTime_arr
    jsr Func_PlayPrgaPcm
    main_prga_bank DataA_Pcm2_WillBeDifferent_arr
    jsr Func_PlayPrgaPcm
    ldx #60  ; param: num frames
    jsr Func_WaitXFrames
    ;; Start a new game.
    lda #eNewGame::Town  ; param: eNewGame value
    jmp MainC_Title_BeginGame
.ENDPROC

;;;=========================================================================;;;
