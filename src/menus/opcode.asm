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
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../menu.inc"
.INCLUDE "../program.inc"

.IMPORT Ram_MenuCols_u8_arr
.IMPORT Ram_MenuRows_u8_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_Current_sMenu_ptr
.IMPORTZP Zp_MenuItem_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp4_byte

;;;=========================================================================;;;

;;; The menu tile column numbers for the left and right columns of the opcode
;;; menu.
kOpcodeMenuLeftCol  = 0
kOpcodeMenuRightCol = 5

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; +--------+
;;; |BEEP END|
;;; |WAIT MUL|
;;; |SYNC SUB|
;;; |COPY ADD|
;;; |SKIP TIL|
;;; |GOTO IF |
;;; |MOVE ACT|
;;; |delete  |
;;; +--------+
.PROC DataA_Console_Opcode_sMenu
    D_STRUCT sMenu
    d_byte WidthsMinusOne_u8_arr
    .byte 5, 3, 3, 2, 2, 2, 3, 3, 1, 2, 2, 3, 3, 3, 2, 2
    d_addr Labels_u8_arr_ptr_arr
    D_ENUM eOpcode, kSizeofAddr
    d_addr Empty, _LabelEmpty
    d_addr Copy,  _LabelCopy
    d_addr Sync,  _LabelSync
    d_addr Add,   _LabelAdd
    d_addr Sub,   _LabelSub
    d_addr Mul,   _LabelMul
    d_addr Goto,  _LabelGoto
    d_addr Skip,  _LabelSkip
    d_addr If,    _LabelIf
    d_addr Til,   _LabelTil
    d_addr Act,   _LabelAct
    d_addr Move,  _LabelMove
    d_addr Wait,  _LabelWait
    d_addr Beep,  _LabelBeep
    d_addr End,   _LabelEnd
    d_addr Nop,   _LabelNop
    D_END
    d_addr OnUp_func_ptr,    _OnUp
    d_addr OnDown_func_ptr,  _OnDown
    d_addr OnLeft_func_ptr,  _OnLeft
    d_addr OnRight_func_ptr, _OnRight
    D_END
_LabelEmpty: .byte "delete"
_LabelCopy:  .byte "COPY"
_LabelSync:  .byte "SYNC"
_LabelAdd:   .byte "ADD"
_LabelSub:   .byte "SUB"
_LabelMul:   .byte "MUL"
_LabelGoto:  .byte "GOTO"
_LabelSkip:  .byte "SKIP"
_LabelIf:    .byte "IF"
_LabelTil:   .byte "TIL"
_LabelAct:   .byte "ACT"
_LabelMove:  .byte "MOVE"
_LabelWait:  .byte "WAIT"
_LabelBeep:  .byte "BEEP"
_LabelEnd:   .byte "END"
_LabelNop:   .byte "NOP"
_OnRight:
    ldx Zp_MenuItem_u8
    lda Ram_MenuRows_u8_arr, x
    sta Zp_Tmp1_byte  ; current menu row
    ;; Check all menu items, and find the item that is in the same row as the
    ;; current item, but in the right column.
    ldx #kMaxMenuItems - 1
    @loop:
    lda Ram_MenuCols_u8_arr, x
    .assert kOpcodeMenuLeftCol = 0, error
    beq @continue
    lda Ram_MenuRows_u8_arr, x
    cmp Zp_Tmp1_byte  ; current menu row
    bne @continue
    stx Zp_MenuItem_u8
    rts
    @continue:
    dex
    bpl @loop
    ;; If no such item exists, then try moving to the lowest item in the
    ;; right-hand column.
    ldx Zp_MenuItem_u8
    lda #kOpcodeMenuRightCol
    bne _UpFromCol  ; unconditional
_OnUp:
    ldx Zp_MenuItem_u8
    lda Ram_MenuCols_u8_arr, x
_UpFromCol:
    sta Zp_Tmp2_byte  ; current menu col
    lda Ram_MenuRows_u8_arr, x
    sta Zp_Tmp1_byte  ; current menu row
    lda #0
    sta Zp_Tmp3_byte  ; best new row so far
    lda #$ff
    sta Zp_Tmp4_byte  ; best new item so far
    ;; Check all menu items, and find the lowest possible one that is still
    ;; above the current item and in the same column.
    ldx #kMaxMenuItems - 1
    @loop:
    lda Ram_MenuCols_u8_arr, x
    cmp Zp_Tmp2_byte  ; current menu col
    bne @continue
    lda Ram_MenuRows_u8_arr, x
    cmp Zp_Tmp1_byte  ; current menu row
    bge @continue
    cmp Zp_Tmp3_byte  ; best new row so far
    blt @continue
    sta Zp_Tmp3_byte  ; best new row so far
    stx Zp_Tmp4_byte  ; best new item so far
    @continue:
    dex
    bpl @loop
    ;; If we found any such item, set it as the new selected item.
    lda Zp_Tmp4_byte  ; best new item so far
    bmi @doNotSet
    sta Zp_MenuItem_u8
    @doNotSet:
    rts
_OnDown:
    ldx Zp_MenuItem_u8
    lda Ram_MenuRows_u8_arr, x
    sta Zp_Tmp1_byte  ; current menu row
    lda Ram_MenuCols_u8_arr, x
    sta Zp_Tmp2_byte  ; current menu col
    ;; If we don't find anything else, default to the "delete" option at the
    ;; bottom.
    ldy Zp_ConsoleNumInstRows_u8
    dey
    sty Zp_Tmp3_byte  ; best new row so far
    lda #eOpcode::Empty
    sta Zp_Tmp4_byte  ; best new item so far
    ;; Check all menu items, and find the highest possible one that is still
    ;; below the current item and in the same column.
    ldx #kMaxMenuItems - 1
    @loop:
    lda Ram_MenuCols_u8_arr, x
    cmp Zp_Tmp2_byte  ; current menu col
    bne @continue
    lda Ram_MenuRows_u8_arr, x
    cmp Zp_Tmp1_byte  ; current menu row
    ble @continue
    cmp Zp_Tmp3_byte  ; best new row so far
    bge @continue
    sta Zp_Tmp3_byte  ; best new row so far
    stx Zp_Tmp4_byte  ; best new item so far
    @continue:
    dex
    bpl @loop
    ;; Set whatever we found as the new selected item.
    lda Zp_Tmp4_byte  ; best new item so far
    sta Zp_MenuItem_u8
    rts
_OnLeft:
    ldx Zp_MenuItem_u8
    lda Ram_MenuRows_u8_arr, x
    sta Zp_Tmp1_byte  ; current menu row
    ;; Check all menu items, and find the item that is in the same row as the
    ;; current item, but in the left column.
    ldx #kMaxMenuItems - 1
    @loop:
    lda Ram_MenuCols_u8_arr, x
    .assert kOpcodeMenuLeftCol = 0, error
    bne @continue
    lda Ram_MenuRows_u8_arr, x
    cmp Zp_Tmp1_byte  ; current menu row
    beq @setItem
    @continue:
    dex
    bpl @loop
    ;; If no such item exists, then move to the "delete" menu item.
    ldx #eOpcode::Empty
    @setItem:
    stx Zp_MenuItem_u8
    rts
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for an instruction opcode menu.
;;; @prereq Zp_Current_sMachine_ptr is initialized.
.EXPORT FuncA_Console_SetUpOpcodeMenu
.PROC FuncA_Console_SetUpOpcodeMenu
    ldax #DataA_Console_Opcode_sMenu
    stax Zp_Current_sMenu_ptr
_SelectDeleteInsteadOfNop:
    lda Zp_MenuItem_u8
    cmp #eOpcode::Nop
    bne @done
    lda #eOpcode::Empty
    sta Zp_MenuItem_u8
    @done:
_SetColumnsForAllMenuItems:
    ldx #kMaxMenuItems - 1
    @loop:
    lda _Columns_u8_arr, x
    sta Ram_MenuCols_u8_arr, x
    dex
    bpl @loop
_SetRowsForMenuLeftColumn:
    ldx #0
    ;; Check if the BEEP opcode is unlocked.
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpBeep
    beq @noBeepOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Beep
    inx
    @noBeepOpcode:
    ;; Check if the WAIT opcode is unlocked.
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpWait
    beq @noWaitOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Wait
    inx
    @noWaitOpcode:
    ;; Check if the SYNC opcode is unlocked.
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpSync
    beq @noSyncOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Sync
    inx
    @noSyncOpcode:
    ;; Check if the COPY opcode is unlocked.
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpCopy
    beq @noCopyOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Copy
    inx
    @noCopyOpcode:
    ;; Check if the SKIP opcode is unlocked.
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpSkip
    beq @noSkipOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Skip
    inx
    @noSkipOpcode:
    ;; Check if the GOTO opcode is unlocked.
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpGoto
    beq @noGotoOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Goto
    inx
    @noGotoOpcode:
    ;; Check if this machine supports the MOVE opcode.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::MoveH | bMachine::MoveV
    beq @noMoveOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Move
    @noMoveOpcode:
    ;; Put an entry for the EMPTY opcode on the last row of the menu.
    ldx Zp_ConsoleNumInstRows_u8
    dex
    stx Ram_MenuRows_u8_arr + eOpcode::Empty
_SetRowsForMenuRightColumn:
    ldx #0
    ;; The END opcode is always available.
    stx Ram_MenuRows_u8_arr + eOpcode::End
    inx
    ;; Check if the MUL opcode is unlocked.
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpMul
    beq @noMulOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Mul
    inx
    @noMulOpcode:
    ;; Check if the ADD/SUB opcodes are unlocked.
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpAddSub
    beq @noAddSubOpcodes
    stx Ram_MenuRows_u8_arr + eOpcode::Sub
    inx
    stx Ram_MenuRows_u8_arr + eOpcode::Add
    inx
    @noAddSubOpcodes:
    ;; Check if the TIL opcode is unlocked.
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpTil
    beq @noTilOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Til
    inx
    @noTilOpcode:
    ;; Check if the IF opcode is unlocked.
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpIf
    beq @noIfOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::If
    inx
    @noIfOpcode:
    ;; Check if this machine supports the ACT opcode.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    .assert bMachine::Act = $80, error
    bpl @noActOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Act
    @noActOpcode:
    rts
_Columns_u8_arr:
    D_ENUM eOpcode
    d_byte Empty, kOpcodeMenuLeftCol
    d_byte Copy,  kOpcodeMenuLeftCol
    d_byte Sync,  kOpcodeMenuLeftCol
    d_byte Add,   kOpcodeMenuRightCol
    d_byte Sub,   kOpcodeMenuRightCol
    d_byte Mul,   kOpcodeMenuRightCol
    d_byte Goto,  kOpcodeMenuLeftCol
    d_byte Skip,  kOpcodeMenuLeftCol
    d_byte If,    kOpcodeMenuRightCol
    d_byte Til,   kOpcodeMenuRightCol
    d_byte Act,   kOpcodeMenuRightCol
    d_byte Move,  kOpcodeMenuLeftCol
    d_byte Wait,  kOpcodeMenuLeftCol
    d_byte Beep,  kOpcodeMenuLeftCol
    d_byte End,   kOpcodeMenuRightCol
    d_byte Nop,   kOpcodeMenuRightCol
    D_END
.ENDPROC

;;;=========================================================================;;;
