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
.INCLUDE "ppu.inc"

.IMPORT Func_ClearRestOfOam
.IMPORT Func_FadeIn
.IMPORT Func_FadeOut
.IMPORT Func_ProcessFrame
.IMPORT Func_UpdateButtons
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsHeld_bJoypad
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_ScrollX_u8
.IMPORTZP Zp_ScrollY_u8

;;;=========================================================================;;;

.SEGMENT "PRG8_Title"

.PROC Data_TitleString_u8_arr
    .byte "ANNALOG"
End:
.ENDPROC

.PROC Data_StartString_u8_arr
    .byte "start was pressed"
End:
.ENDPROC

.PROC Func_DisplayStartString
    ldy Zp_PpuTransferLen_u8
    lda #bPpuCtrl::EnableNmi | bPpuCtrl::Inc32
    sta Ram_PpuTransfer_arr, y
    iny
    .linecont +
    ldax #Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
          kScreenWidthTiles * 3 + 7
    .linecont -
    sta Ram_PpuTransfer_arr, y
    iny
    txa
    sta Ram_PpuTransfer_arr, y
    iny
    lda #Data_StartString_u8_arr::End - Data_StartString_u8_arr
    sta Ram_PpuTransfer_arr, y
    iny
    ldx #0
    @loop:
    lda Data_StartString_u8_arr, x
    sta Ram_PpuTransfer_arr, y
    iny
    inx
    cpx #Data_StartString_u8_arr::End - Data_StartString_u8_arr
    bne @loop
    sty Zp_PpuTransferLen_u8
    rts
.ENDPROC

;;; @prereq Rendering is disabled.
.EXPORT Main_Title
.PROC Main_Title
    ;; Clear OAM:
    sta Zp_OamOffset_u8
    jsr Func_ClearRestOfOam
_ClearNametable0:
    ldax #Ppu_Nametable0_sName + sName::Tiles_u8_arr
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda #0
    ldxy #kScreenWidthTiles * kScreenHeightTiles
    @loop:
    sta Hw_PpuData_rw
    dey
    bne @loop
    dex
    bpl @loop
_DrawTitleString:
    .linecont +
    ldax #Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
          kScreenWidthTiles * 14 + 12
    .linecont -
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    ldy #Data_TitleString_u8_arr::End - Data_TitleString_u8_arr
    ldx #0
    @loop:
    lda Data_TitleString_u8_arr, x
    sta Hw_PpuData_rw
    inx
    dey
    bne @loop
_FadeIn:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_ScrollX_u8
    sta Zp_ScrollY_u8
    jsr Func_FadeIn
_GameLoop:
    jsr Func_UpdateButtons
    ;; Check D-pad left.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Left
    beq @noLeft
    dec Zp_ScrollX_u8
    @noLeft:
    ;; Check D-pad right.
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Right
    beq @noRight
    lda Zp_ScrollX_u8
    add #15
    sta Zp_ScrollX_u8
    @noRight:
    ;; Check SELECT button.
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Select
    beq @noSelect
    jsr Func_FadeOut
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    jsr Func_FadeIn
    @noSelect:
    ;; Check START button.
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    beq @noStart
    jsr Func_DisplayStartString
    @noStart:
    jsr Func_ProcessFrame
    jmp _GameLoop
.ENDPROC

;;;=========================================================================;;;
