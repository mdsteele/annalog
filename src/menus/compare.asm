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

.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../menu.inc"
.INCLUDE "../program.inc"

.IMPORT Ram_MenuCols_u8_arr
.IMPORT Ram_MenuRows_u8_arr
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_Current_sMenu_ptr
.IMPORTZP Zp_MenuItem_u8
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; +--------+
;;; |        |
;;; |        |
;;; | = < >  |
;;; |        |
;;; | / { }  |
;;; |        |
;;; |        |
;;; |        |
;;; +--------+
.PROC DataA_Console_Compare_sMenu
    D_STRUCT sMenu
    d_byte WidthsMinusOne_u8_arr
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr Labels_u8_arr_ptr_arr
    D_ENUM eCmp, kSizeofAddr
    d_addr Eq, _LabelEq
    d_addr Ne, _LabelNe
    d_addr Lt, _LabelLt
    d_addr Le, _LabelLe
    d_addr Gt, _LabelGt
    d_addr Ge, _LabelGe
    D_END
    .addr 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr OnUp_func_ptr,    _OnUp
    d_addr OnDown_func_ptr,  _OnDown
    d_addr OnLeft_func_ptr,  _OnLeft
    d_addr OnRight_func_ptr, _OnRight
    D_END
_LabelEq: .byte "="
_LabelNe: .byte kTileIdCmpNe
_LabelLt: .byte "<"
_LabelLe: .byte kTileIdCmpLe
_LabelGt: .byte ">"
_LabelGe: .byte kTileIdCmpGe
_OnLeft:
    lda Zp_MenuItem_u8
    sub #2
    bge _SetItem
    rts
_OnRight:
    lda Zp_MenuItem_u8
    add #2
    cmp #6
    blt _SetItem
    rts
_OnUp:
    lda Zp_MenuItem_u8
    and #$06
    bpl _SetItem  ; unconditional
_OnDown:
    lda Zp_MenuItem_u8
    ora #$01
_SetItem:
    sta Zp_MenuItem_u8
    rts
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for a comparison operator menu.
.EXPORT FuncA_Console_SetUpCompareMenu
.PROC FuncA_Console_SetUpCompareMenu
    ldax #DataA_Console_Compare_sMenu
    stax Zp_Current_sMenu_ptr
    ;; Store the starting row in Zp_Tmp1_byte.
    lda Zp_ConsoleNumInstRows_u8
    sub #3
    lsr a
    sta Zp_Tmp1_byte  ; starting row
    ;; Set up rows and cols.
    ldx #eCmp::NUM_VALUES - 1
    @loop:
    txa
    and #$01
    asl a
    add Zp_Tmp1_byte  ; starting row
    sta Ram_MenuRows_u8_arr, x
    txa
    ora #$01
    sta Ram_MenuCols_u8_arr, x
    dex
    bpl @loop
    rts
.ENDPROC

;;;=========================================================================;;;
