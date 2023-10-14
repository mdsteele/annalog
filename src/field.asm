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

.INCLUDE "machine.inc"
.INCLUDE "macros.inc"
.INCLUDE "program.inc"

.IMPORT Ram_ConsoleRegNames_u8_arr6
.IMPORT Ram_Console_sProgram
.IMPORTZP Zp_ConsoleFieldNumber_u8
.IMPORTZP Zp_ConsoleInstNumber_u8
.IMPORTZP Zp_ConsoleNominalFieldOffset_u8
.IMPORTZP Zp_Current_sMachine_ptr

;;;=========================================================================;;;

.LINECONT +
.DEFINE OpcodeLabels \
    _OpEmpty, _OpCopy, _OpSync, _OpAdd, _OpSub, _OpMul, _OpGoto, _OpSkip, \
    _OpIf, _OpTil, _OpAct, _OpMove, _OpRest, _OpBeep, _OpEnd, _OpNop
.LINECONT -

.MACRO OPCODE_TABLE arg
    .repeat $10, index
    .byte .mid(index * 2, 1, {OpcodeLabels}) - arg
    .endrepeat
.ENDMACRO

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; Returns the number of fields for the currently-selected instruction.
;;; @return X The number of fields.
;;; @preserve T0+
.EXPORT FuncA_Console_GetCurrentInstNumFields
.PROC FuncA_Console_GetCurrentInstNumFields
    jsr FuncA_Console_GetCurrentOpcode  ; preserves T0+, returns Y
    ldx _NumFields_u8_arr, y
    rts
_NumFields_u8_arr:
    D_ARRAY .enum, eOpcode
    d_byte Empty, 1
    d_byte Copy,  3
    d_byte Sync,  1
    d_byte Add,   5
    d_byte Sub,   5
    d_byte Mul,   5
    d_byte Goto,  2
    d_byte Skip,  2
    d_byte If,    4
    d_byte Til,   4
    d_byte Act,   1
    d_byte Move,  2
    d_byte Rest,  1
    d_byte Beep,  2
    d_byte End,   1
    d_byte Nop,   1
    D_END
.ENDPROC

;;; Returns the width of the currently-selected instruction field, in tiles,
;;; minus one.
;;; @return A The width minus one.
;;; @preserve T0+
.EXPORT FuncA_Console_GetCurrentFieldWidth
.PROC FuncA_Console_GetCurrentFieldWidth
    jsr FuncA_Console_GetCurrentOpcode  ; preserves T0+, returns Y
    lda _OpcodeTable_u8_arr, y
    add Zp_ConsoleFieldNumber_u8
    tay
    lda _WidthTable_u8_arr, y
    rts
_OpcodeTable_u8_arr:
    OPCODE_TABLE _WidthTable_u8_arr
_WidthTable_u8_arr:
_OpEmpty:
_OpNop:
    .byte 5
_OpCopy:
    .byte 0, 0, 0
_OpAdd:
_OpSub:
_OpMul:
    .byte 0, 0, 0, 0, 0
_OpGoto:
_OpSkip:
_OpMove:
_OpBeep:
    .byte 3, 0
_OpIf:
    .byte 1, 0, 0, 0
_OpTil:
    .byte 2, 0, 0, 0
_OpAct:
_OpEnd:
    .byte 2
_OpSync:
_OpRest:
    .byte 3
.ENDPROC

;;; Returns the horizontal offset of the currently-selected instruction field,
;;; in tiles.  This can range from 0-6 inclusive.
;;; @return A The field offset.
;;; @preserve T0+
.EXPORT FuncA_Console_GetCurrentFieldOffset
.PROC FuncA_Console_GetCurrentFieldOffset
    jsr FuncA_Console_GetCurrentOpcode  ; preserves T0+, returns Y
    lda _OpcodeTable_u8_arr, y
    add Zp_ConsoleFieldNumber_u8
    tay
    lda _OffsetTable_u8_arr, y
    rts
_OpcodeTable_u8_arr:
    OPCODE_TABLE _OffsetTable_u8_arr
_OffsetTable_u8_arr:
_OpEmpty:
_OpSync:
_OpAct:
_OpRest:
_OpEnd:
_OpNop:
    .byte 0
_OpCopy:
    .byte 0, 1, 2
_OpAdd:
_OpSub:
_OpMul:
    .byte 0, 1, 2, 3, 4
_OpGoto:
_OpSkip:
_OpMove:
_OpBeep:
    .byte 0, 5
_OpIf:
    .byte 0, 3, 4, 5
_OpTil:
    .byte 0, 4, 5, 6
.ENDPROC

;;; Sets Zp_ConsoleFieldNumber_u8 to whichever field in the current instruction
;;; best overlaps with Zp_ConsoleNominalFieldOffset_u8 (which must be in the
;;; range 0-6 inclusive).
;;; @preserve T0+
.EXPORT FuncA_Console_SetFieldForNominalOffset
.PROC FuncA_Console_SetFieldForNominalOffset
    jsr FuncA_Console_GetCurrentOpcode  ; preserves T0+, returns Y
    lda _OpcodeTable_u8_arr, y
    add Zp_ConsoleNominalFieldOffset_u8
    tay
    lda _FieldTable_u8_arr, y
    sta Zp_ConsoleFieldNumber_u8
    rts
_OpcodeTable_u8_arr:
    OPCODE_TABLE _FieldTable_u8_arr
_FieldTable_u8_arr:
_OpEmpty:
_OpSync:
_OpAct:
_OpRest:
_OpEnd:
_OpNop:
    .byte 0, 0, 0, 0, 0, 0, 0
_OpCopy:
    .byte 0, 1, 2, 2, 2, 2, 2
_OpAdd:
_OpSub:
_OpMul:
    .byte 0, 1, 2, 3, 4, 4, 4
_OpGoto:
_OpSkip:
_OpMove:
_OpBeep:
    .byte 0, 0, 0, 0, 1, 1, 1
_OpIf:
    .byte 0, 0, 1, 1, 2, 3, 3
_OpTil:
    .byte 0, 0, 0, 1, 1, 2, 3
.ENDPROC

;;; Returns the eField for the currently-selected instruction field.
;;; @return Y The eField value.
;;; @preserve T0+
.EXPORT FuncA_Console_GetCurrentFieldType
.PROC FuncA_Console_GetCurrentFieldType
    jsr FuncA_Console_GetCurrentOpcode  ; preserves T0+, returns Y
    lda _OpcodeTable_u8_arr, y
    add Zp_ConsoleFieldNumber_u8
    tax
    ldy _TypeTable_u8_arr, x
    rts
_OpcodeTable_u8_arr:
    OPCODE_TABLE _TypeTable_u8_arr
_TypeTable_u8_arr:
_OpEmpty:
_OpSync:
_OpAct:
_OpRest:
_OpEnd:
_OpNop:
    .byte eField::Opcode
_OpCopy:
    .byte eField::LValue, eField::Opcode, eField::RValue
_OpAdd:
_OpSub:
_OpMul:
    .byte eField::LValue, eField::Opcode, eField::RValue, eField::Opcode
    .byte eField::RValue
_OpGoto:
    .byte eField::Opcode, eField::Address
_OpSkip:
_OpBeep:
    .byte eField::Opcode, eField::RValue
_OpIf:
_OpTil:
    .byte eField::Opcode, eField::RValue, eField::Compare, eField::RValue
_OpMove:
    .byte eField::Opcode, eField::Direction
.ENDPROC

;;; Returns the argument slot number for the currently-selected instruction
;;; field.  The opcode nibble of the sIns is slot 0, the first argument nibble
;;; is slot 1, and so on.
;;; @return Y Slot number for the field (0-3).
;;; @preserve T0+
.PROC FuncA_Console_GetCurrentFieldSlot
    jsr FuncA_Console_GetCurrentOpcode  ; preserves T0+, returns Y
    lda _OpcodeTable_u8_arr, y
    add Zp_ConsoleFieldNumber_u8
    tax
    ldy _SlotTable_u8_arr, x
    rts
_OpcodeTable_u8_arr:
    OPCODE_TABLE _SlotTable_u8_arr
_SlotTable_u8_arr:
_OpEmpty:
_OpSync:
_OpAct:
_OpRest:
_OpEnd:
_OpNop:
    .byte 0
_OpCopy:
    .byte 1, 0, 2
_OpAdd:
_OpSub:
_OpMul:
    .byte 1, 0, 2, 0, 3
_OpGoto:
_OpSkip:
_OpMove:
_OpBeep:
    .byte 0, 1
_OpIf:
_OpTil:
    .byte 0, 2, 1, 3
.ENDPROC

;;; Returns the value of the currently selected instruction field.
;;; @return A The value of the field (0-15).
;;; @preserve T0+
.EXPORT FuncA_Console_GetCurrentFieldValue
.PROC FuncA_Console_GetCurrentFieldValue
    jsr FuncA_Console_GetCurrentFieldSlot  ; preserves T0+, returns Y
    lda Zp_ConsoleInstNumber_u8
    mul #.sizeof(sIns)
    tax  ; sProgram byte index
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    dey
    bmi @highNibble
    dey
    bmi @lowNibble
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
    dey
    bmi @lowNibble
    @highNibble:
    div #$10
    rts
    @lowNibble:
    and #$0f
    rts
.ENDPROC

;;; Sets the value of the currently selected instruction field.  If that field
;;; is the opcode, then other fields may also be updated.
;;; @prereq Zp_Current_sMachine_ptr is initialized.
;;; @param A The new field value ($0-$f).
.EXPORT FuncA_Console_SetCurrentFieldValue
.PROC FuncA_Console_SetCurrentFieldValue
    pha  ; new field value (in low nibble)
    jsr FuncA_Console_GetCurrentFieldSlot  ; returns Y
    lda Zp_ConsoleInstNumber_u8
    mul #.sizeof(sIns)
    tax  ; sProgram byte index
    pla  ; new field value (in low nibble)
    dey
    bmi _SetOpcode
    dey
    bmi _SetArg1
    dey
    bmi _SetArg2
_SetArg3:
    mul #$10
    sta T0  ; new field value (in high nibble)
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
    and #$0f
    ora T0  ; new field value (in high nibble)
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
    rts
_SetArg2:
    sta T0  ; new field value (in low nibble)
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
    and #$f0
    ora T0  ; new field value (in low nibble)
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
    rts
_SetArg1:
    sta T0  ; new field value (in low nibble)
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    and #$f0
    ora T0  ; new field value (in low nibble)
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    rts
_SetOpcode:
    pha  ; new eOpcode value
    jsr FuncA_Console_GetCurrentOpcode  ; returns Y
    sty T0  ; old eOpcode value
    pla  ; new eOpcode value
    cmp T0  ; old eOpcode value
    bne @update
    rts
    @update:
    tay  ; new eOpcode value
    lda Zp_ConsoleInstNumber_u8
    mul #.sizeof(sIns)
    tax  ; sProgram byte index
    lda _JumpTable_ptr_0_arr, y
    sta T2
    lda _JumpTable_ptr_1_arr, y
    sta T3
    jmp (T3T2)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eOpcode
    d_entry table, Empty, _OpEmpty
    d_entry table, Copy,  _OpCopy
    d_entry table, Sync,  _OpSync
    d_entry table, Add,   _OpAdd
    d_entry table, Sub,   _OpSub
    d_entry table, Mul,   _OpMul
    d_entry table, Goto,  _OpGoto
    d_entry table, Skip,  _OpSkip
    d_entry table, If,    _OpIf
    d_entry table, Til,   _OpTil
    d_entry table, Act,   _OpAct
    d_entry table, Move,  _OpMove
    d_entry table, Rest,  _OpRest
    d_entry table, Beep,  _OpBeep
    d_entry table, End,   _OpEnd
    d_entry table, Nop,   _OpNop
    D_END
.ENDREPEAT
_OpEmpty:
_OpSync:
_OpGoto:
_OpAct:
_OpRest:
_OpEnd:
_OpNop:
    tya  ; new eOpcode value
    mul #$10
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    jmp _ZeroArgByteAndFieldNumber
_OpCopy:
    ;; If coming from ADD/SUB/MUL, just remove third arg.
    lda T0  ; old eOpcode value
    cmp #eOpcode::Add
    beq @clearThirdArg
    cmp #eOpcode::Sub
    beq @clearThirdArg
    cmp #eOpcode::Mul
    beq @clearThirdArg
    ;; Otherwise, initialize args to A <- 0.
    lda #eOpcode::Copy * $10 + $0a
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    lda #$00
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
    lda #1
    bne _SetFieldNumber  ; unconditional
    ;; Clear third arg to 0.
    @clearThirdArg:
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
    and #$0f
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
    jsr _UpdateOpcodeOnly
    lda #1
    bne _SetFieldNumber  ; unconditional
_UpdateOpcodeOnly:
    tya  ; new eOpcode value
    mul #$10
    sta T1  ; new eOpcode (in high nibble)
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    and #$0f
    ora T1  ; new eOpcode (in high nibble)
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    rts
_OpAdd:
_OpSub:
_OpMul:
    ;; If coming from ADD/SUB/MUL, leave all args the same.
    lda T0  ; old eOpcode value
    cmp #eOpcode::Add
    beq _UpdateOpcodeOnly
    cmp #eOpcode::Sub
    beq _UpdateOpcodeOnly
    cmp #eOpcode::Mul
    beq _UpdateOpcodeOnly
    ;; If coming from COPY, keep first two args, and initialize third arg.
    cmp #eOpcode::Copy
    beq @setThirdArg
    ;; Otherwise, initialize args to A <- A op 1.
    tya  ; new eOpcode value
    mul #$10
    ora #$0a
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    lda #$1a
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
    lda #1
    bne _SetFieldNumber  ; unconditional
    ;; Initialize third arg to 1.
    @setThirdArg:
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
    and #$0f
    ora #$10
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
    bne _UpdateOpcodeOnly  ; unconditional
_ZeroArgByteAndFieldNumber:
    lda #0
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
_SetFieldNumber:
    sta Zp_ConsoleFieldNumber_u8
    jsr FuncA_Console_GetCurrentFieldOffset  ; returns A
    sta Zp_ConsoleNominalFieldOffset_u8
    rts
_OpSkip:
    lda #eOpcode::Skip * $10 + $01
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    bne _ZeroArgByteAndFieldNumber  ; unconditional
_OpIf:
_OpTil:
    ;; If coming from IF/TIL, leave all args the same.
    lda T0  ; old eOpcode value
    cmp #eOpcode::If
    beq _UpdateOpcodeOnly
    cmp #eOpcode::Til
    beq _UpdateOpcodeOnly
    ;; Otherwise, pick an available register.
    sty T1  ; new eOpcode value
    ldy #0
    @loop:
    lda Ram_ConsoleRegNames_u8_arr6, y
    bne @foundRegister
    iny
    cpy #5
    blt @loop
    @foundRegister:
    ;; Initialize args to R = 0, where R is the register we picked.
    lda T1  ; new eOpcode value
    mul #$10
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    tya  ; register name index (0-5)
    add #$0a
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
    lda #0
    beq _SetFieldNumber  ; unconditional
_OpMove:
    ;; Check if this machine supports moving vertically.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::MoveV
    beq @moveHorz
    ;; If so, default to moving up.
    lda #eOpcode::Move * $10 + eDir::Up
    .assert eOpcode::Move <> 0, error
    bne @setOp  ; unconditional
    ;; Otherwise, default to moving right.
    @moveHorz:
    lda #eOpcode::Move * $10 + eDir::Right
    @setOp:
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    bne _ZeroArgByteAndFieldNumber  ; unconditional
_OpBeep:
    lda #eOpcode::Beep * $10 + $02
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    bne _ZeroArgByteAndFieldNumber  ; unconditional
.ENDPROC

;;; Returns the opcode for the currently-selected instruction.
;;; @return Y The eOpcode value.
;;; @preserve T0+
.PROC FuncA_Console_GetCurrentOpcode
    lda Zp_ConsoleInstNumber_u8
    mul #.sizeof(sIns)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, y
    div #$10
    tay
    rts
.ENDPROC

;;;=========================================================================;;;
