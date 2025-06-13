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

.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../menu.inc"
.INCLUDE "../program.inc"

.IMPORT DataA_Console_NumberLabels_u8_arr
.IMPORT Ram_ConsoleRegNames_u8_arr6
.IMPORT Ram_MenuCols_u8_arr
.IMPORT Ram_MenuRows_u8_arr
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_Current_sMenu_ptr
.IMPORTZP Zp_MenuItem_u8

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; +--------+
;;; |        |
;;; |        |
;;; |  0     |
;;; | 123 AB |
;;; | 456 CD |
;;; | 789 EF |
;;; |        |
;;; |        |
;;; +--------+
.PROC DataA_Console_Value_sMenu
    D_STRUCT sMenu
    ;; This sMenu is used for both LValue and RValue fields, but nothing that
    ;; reads Type_eField cares about the difference, so just list RValue.
    d_byte Type_eField, eField::RValue
    d_byte WidthsMinusOne_u8_arr
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr Labels_u8_arr_ptr_arr
    .repeat 10, index
    .addr DataA_Console_NumberLabels_u8_arr + index
    .endrepeat
    .repeat 6, index
    .addr Ram_ConsoleRegNames_u8_arr6 + index
    .endrepeat
    d_addr OnUp_func_ptr,    _OnUp
    d_addr OnDown_func_ptr,  _OnDown
    d_addr OnLeft_func_ptr,  _OnLeft
    d_addr OnRight_func_ptr, _OnRight
    D_END
_OnUp:
    lda Zp_MenuItem_u8
    cmp #4
    bge @doNotGoToZero
    lda #0
    beq @setToA  ; unconditional
    @doNotGoToZero:
    cmp #$a
    bge @register
    sub #3
    bpl @setToA  ; unconditional
    @register:
    tax
    @loop1:
    dex
    dex
    cpx #$a
    blt @tryOtherColumn
    lda Ram_MenuRows_u8_arr, x
    bmi @loop1
    bpl @setToX  ; unconditional
    @tryOtherColumn:
    lda Zp_MenuItem_u8
    eor #$01
    tax
    @loop2:
    dex
    dex
    cpx #$a
    blt @doNotSet
    lda Ram_MenuRows_u8_arr, x
    bmi @loop2
    @setToX:
    txa
    @setToA:
    sta Zp_MenuItem_u8
    @doNotSet:
    rts
_OnDown:
    lda Zp_MenuItem_u8
    bne @notAtZero
    lda #2
    bne @setToA  ; unconditional
    @notAtZero:
    cmp #$a
    bge @register
    cmp #7
    bge @doNotSet
    add #3
    bne @setToA  ; unconditional
    @register:
    tax
    @loop1:
    inx
    inx
    cpx #$10
    bge @tryOtherColumn
    lda Ram_MenuRows_u8_arr, x
    bmi @loop1
    bpl @setToX  ; unconditional
    @tryOtherColumn:
    lda Zp_MenuItem_u8
    eor #$01
    tax
    @loop2:
    inx
    inx
    cpx #$10
    bge @doNotSet
    lda Ram_MenuRows_u8_arr, x
    bmi @loop2
    @setToX:
    txa
    @setToA:
    sta Zp_MenuItem_u8
    @doNotSet:
    rts
_OnLeft:
    ldx Zp_MenuItem_u8
    bne @notAtZero
    lda #1
    bne @setToA  ; unconditional
    @notAtZero:
    lda Ram_MenuRows_u8_arr, x
    sta T0  ; current menu row
    lda Ram_MenuCols_u8_arr, x
    sta T1  ; current menu col
    lda #0
    sta T2  ; best new col so far
    lda #$ff
    sta T3  ; best new item so far
    ;; Check all menu items, and find the rightmost possible one that is still
    ;; to the left of the current item and in the same row.
    ldx #kMaxMenuItems - 1
    @loop:
    lda Ram_MenuRows_u8_arr, x
    cmp T0  ; current menu row
    bne @continue
    lda Ram_MenuCols_u8_arr, x
    cmp T1  ; current menu col
    bge @continue
    cmp T2  ; best new col so far
    blt @continue
    sta T2  ; best new col so far
    stx T3  ; best new item so far
    @continue:
    dex
    bpl @loop
    ;; If we found any such item, set it as the new selected item.
    lda T3  ; best new item so far
    bmi @doNotSet
    @setToA:
    sta Zp_MenuItem_u8
    @doNotSet:
    rts
_OnRight:
    ldx Zp_MenuItem_u8
    bne @notAtZero
    lda #3
    bne @setToA  ; unconditional
    @notAtZero:
    lda Ram_MenuRows_u8_arr, x
    sta T0  ; current menu row
    lda Ram_MenuCols_u8_arr, x
    sta T1  ; current menu col
    lda #$ff
    sta T2  ; best new col so far
    sta T3  ; best new item so far
    ;; Check all menu items, and find the leftmost possible one that is still
    ;; to the right of the current item and in the same row.
    ldx #kMaxMenuItems - 1
    @loop:
    lda Ram_MenuRows_u8_arr, x
    cmp T0  ; current menu row
    bne @continue
    lda Ram_MenuCols_u8_arr, x
    cmp T1  ; current menu col
    ble @continue
    cmp T2  ; best new col so far
    bge @continue
    sta T2  ; best new col so far
    stx T3  ; best new item so far
    @continue:
    dex
    bpl @loop
    ;; If we found any such item, set it as the new selected item.
    lda T3  ; best new item so far
    bmi @doNotSet
    @setToA:
    sta Zp_MenuItem_u8
    @doNotSet:
    rts
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for an L-value menu.
;;; @prereq Zp_Current_sMachine_ptr is initialized.
.EXPORT FuncA_Console_SetUpLValueMenu
.PROC FuncA_Console_SetUpLValueMenu
    jsr FuncA_Console_SetUpValueMenuCommon
_SetColumnsForAllMenuItems:
    ldx #kMaxMenuItems - 1
    @loop:
    lda _Columns_u8_arr, x
    sta Ram_MenuCols_u8_arr, x
    dex
    bpl @loop
_DisableMenuItemsForReadOnlyRegisters:
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    sta T0  ; machine flags
    lda #$ff
    sta Ram_MenuRows_u8_arr + $b  ; the B register is always read-only
    .assert bMachine::WriteF = $01, error
    .assert bMachine::WriteE = $02, error
    .assert bMachine::WriteD = $04, error
    .assert bMachine::WriteC = $08, error
    ldx #$f
    @loop:
    lsr T0
    bcs @continue
    sta Ram_MenuRows_u8_arr, x
    @continue:
    dex
    cpx #$b
    bne @loop
    rts
_Columns_u8_arr:
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4, 3, 4, 3, 4
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for an R-value menu.
.EXPORT FuncA_Console_SetUpRValueMenu
.PROC FuncA_Console_SetUpRValueMenu
    jsr FuncA_Console_SetUpValueMenuCommon
_SetColumnsForAllMenuItems:
    ldx #kMaxMenuItems - 1
    @loop:
    lda _Columns_u8_arr, x
    sta Ram_MenuCols_u8_arr, x
    dex
    bpl @loop
_SetRowsForImmediateValues:
    lda Zp_ConsoleNumInstRows_u8
    sub #4
    div #2
    tax
    stx Ram_MenuRows_u8_arr + 0
    inx
    stx Ram_MenuRows_u8_arr + 1
    stx Ram_MenuRows_u8_arr + 2
    stx Ram_MenuRows_u8_arr + 3
    inx
    stx Ram_MenuRows_u8_arr + 4
    stx Ram_MenuRows_u8_arr + 5
    stx Ram_MenuRows_u8_arr + 6
    inx
    stx Ram_MenuRows_u8_arr + 7
    stx Ram_MenuRows_u8_arr + 8
    stx Ram_MenuRows_u8_arr + 9
    rts
_Columns_u8_arr:
    .byte 2, 1, 2, 3, 1, 2, 3, 1, 2, 3, 5, 6, 5, 6, 5, 6
.ENDPROC

;;; Helper function for FuncA_Console_SetUpLValueMenu and
;;; FuncA_Console_SetUpRValueMenu.
.PROC FuncA_Console_SetUpValueMenuCommon
    ldax #DataA_Console_Value_sMenu
    stax Zp_Current_sMenu_ptr
_SetRowsForRegisters:
    lda Zp_ConsoleNumInstRows_u8
    sub #4
    div #2
    sta T0  ; starting row
    ldy #$f
    ldx #5
    @loop:
    lda Ram_ConsoleRegNames_u8_arr6, x
    beq @continue
    txa
    div #2
    sec
    adc T0  ; starting row
    sta Ram_MenuRows_u8_arr, y
    @continue:
    dey
    dex
    bpl @loop
    rts
.ENDPROC

;;;=========================================================================;;;
