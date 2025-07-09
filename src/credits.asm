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

.INCLUDE "charmap.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"

.IMPORT FuncA_Pause_DirectDrawBlankTiles
.IMPORT FuncA_Pause_DirectDrawWindowBottomBorder
.IMPORT FuncA_Pause_DirectDrawWindowLineSide
.IMPORT FuncA_Pause_DirectDrawWindowTopBorder
.IMPORT Func_ClearRestOfOam
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_FadeInFromBlackToNormal
.IMPORT Func_FadeOutToBlack
.IMPORT Func_FillUpperAttributeTable
.IMPORT Func_Window_Disable
.IMPORT Func_WriteToUpperAttributeTable
.IMPORT MainC_Title_Menu
.IMPORT Ppu_ChrBgFontUpper
.IMPORT Ppu_ChrBgTitle
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask

;;;=========================================================================;;;

;;; The number of tile rows between the top and bottom borders of the credits
;;; window.
kNumCreditsRows = 24
;;; The number of tile columns between the left and right borders/margins of
;;; the credits window.
kNumCreditsCols = 26

;;;=========================================================================;;;

.SEGMENT "PRGC_Title"

;;; Mode for displaying title screen credits.
;;; @prereq Rendering is disabled.
.EXPORT MainC_Title_Credits
.PROC MainC_Title_Credits
    jsr_prga FuncA_Pause_InitCreditsAndFadeIn
_GameLoop:
    jsr Func_ClearRestOfOamAndProcessFrame
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start | bJoypad::BButton | bJoypad::AButton
    beq _GameLoop
_Exit:
    jsr Func_FadeOutToBlack
    jmp MainC_Title_Menu
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Pause"

;;; Initializes title screen credits mode, then fades in the screen.
;;; @prereq Rendering is disabled.
.PROC FuncA_Pause_InitCreditsAndFadeIn
    jsr Func_Window_Disable
    jsr Func_ClearRestOfOam
    ldy #$05  ; param: attribute byte
    jsr Func_FillUpperAttributeTable
    ldx #$18  ; param: num bytes to write
    ldy #$00  ; param: attribute value
    lda #$28  ; param: initial byte offset
    jsr Func_WriteToUpperAttributeTable
_SetUpChrBanks:
    lda #<.bank(Ppu_ChrBgFontUpper)
    sta Zp_Chr04Bank_u8
    main_chr08_bank Ppu_ChrBgTitle
_PrepareDirectDraw:
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldax #Ppu_Nametable0_sName + sName::Tiles_u8_arr
    sta Hw_PpuAddr_w2  ; PPU address (hi)
    stx Hw_PpuAddr_w2  ; PPU address (lo)
_DrawTopBorder:
    ldy #kScreenWidthTiles * 2  ; param: num blank tiles to draw
    jsr FuncA_Pause_DirectDrawBlankTiles
    jsr FuncA_Pause_DirectDrawWindowTopBorder
_DrawWindowContents:
    ldya #DataA_Pause_CreditsText
    stya T1T0  ; param: text pointer
    ldx #0
    @loop:
    jsr FuncA_Pause_DirectDrawWindowLineSide  ; preserves X and T0+
    jsr FuncA_Pause_DrawCreditsTileRow  ; preserves X, returns T1T0
    jsr FuncA_Pause_DirectDrawWindowLineSide  ; preserves X and T0+
    inx
    cpx #kNumCreditsRows
    blt @loop
_DrawBottomBorder:
    jsr FuncA_Pause_DirectDrawWindowBottomBorder  ; preserves T0+
    ldy #3  ; param: num blank tiles to draw
    jsr FuncA_Pause_DirectDrawBlankTiles  ; preserves T0+
    jsr FuncA_Pause_DrawCreditsTileRow
    ldy #3 + kScreenWidthTiles  ; param: num blank tiles to draw
    jsr FuncA_Pause_DirectDrawBlankTiles
_FadeIn:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    jmp Func_FadeInFromBlackToNormal
.ENDPROC

;;; Text for the title screen credits.  Each text row is kNumCreditsCols tiles
;;; wide.  A sequence of N spaces can be encoded as ($c0 | N) to save space.
.PROC DataA_Pause_CreditsText
    .byte $c0 | kNumCreditsCols
    .byte $c7, "- ANNALOG -", $c8
    .byte $c0 | kNumCreditsCols
    .assert kTileIdBgFontCopyrightFirst = $ae, error
    .byte " ", $ae, $af, "2025 Matthew D. Steele "
    .byte $c2, "https://mdsteele.games/ "
    .byte $c0 | kNumCreditsCols
    .byte $c7, "PUBLISHED BY:", $c6
    .byte $c6, "The Retro Room", $c6
    .byte $c3, "TheRetroRoomGames.com", $c2
    .byte $c0 | kNumCreditsCols
    .byte $ca, "MUSIC:", $ca
    .byte $c8, "Jon Moran", $c9
    .byte $c6, "Matthew Steele", $c6
    .byte $c0 | kNumCreditsCols
    .byte " CREATIVE COMMONS ASSETS: "
    .byte "Adam Saltsman", $c8, "Hyell"
    .byte "CobraLad", $cd, "KJose"
    .byte "Daivuk", $c7, "Luke Sharples"
    .byte "drotzruhn", $ca, "qubodup"
    .byte "Exuin", $c7, "SamsterBirdies"
    .byte "gpag1", $c6, "Walter Odington"
    .byte $c0 | kNumCreditsCols
    .byte $c4, "Thanks for playing!", $c3
    .byte $c0 | kNumCreditsCols
_Version:
    ;; This last row appears just below the window border:
    .include "../out/version"
    .assert (* - _Version) < kNumCreditsCols, error
    .byte $c0 | (kNumCreditsCols - (* - _Version))
.ENDPROC

;;; Draws one row of the text for the credits window.
;;; @prereq Rendering is disabled.
;;; @param T1T0 Pointer to the text row to draw.
;;; @return T1T0 Pointer to the next text row.
;;; @preserve X, T4+
.PROC FuncA_Pause_DrawCreditsTileRow
    ldy #0
    sty T3  ; num tiles drawn
_OuterLoop:
    lda (T1T0), y
    cmp #$c0
    blt _DrawTile
_DrawSpaces:
    and #$3f
    sta T2  ; num spaces to draw
    lda #' '
    @loop:
    sta Hw_PpuData_rw
    inc T3  ; num tiles drawn
    dec T2  ; num spaces to draw
    bne @loop
    beq _Continue  ; unconditional
_DrawTile:
    sta Hw_PpuData_rw
    inc T3  ; num tiles drawn
_Continue:
    iny
    lda T3  ; num tiles drawn
    cmp #kScreenWidthTiles - 6
    blt _OuterLoop
_Finish:
    tya
    add T0  ; text pointer (lo)
    sta T0  ; text pointer (lo)
    lda #0
    adc T1  ; text pointer (hi)
    sta T1  ; text pointer (hi)
    rts
.ENDPROC

;;;=========================================================================;;;
