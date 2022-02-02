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
.INCLUDE "machine.inc"
.INCLUDE "macros.inc"
.INCLUDE "program.inc"

.IMPORT Sram_Programs_sProgram_arr
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

.LINECONT +
.DEFINE OpcodeLabels \
    _OpEmpty, _OpCopy, _OpSwap, _OpAdd, _OpSub, _OpMul, _OpGoto, _OpSkip, \
    _OpIf, _OpTil, _OpAct, _OpMove, _OpEnd, _OpEnd, _OpEnd, _OpNop
.LINECONT -

;;;=========================================================================;;;

.ZEROPAGE

;;; The maximum number of instructions a program is allowed to have, as
;;; calculated from the player's upgrades.  This should be a positive even
;;; number no greater than kMaxProgramLength.
.EXPORTZP Zp_MachineMaxInstructions_u8
Zp_MachineMaxInstructions_u8: .res 1

;;; A pointer to the machine data array for the current area.  This is
;;; generally expected to point somewhere in PRGC.
.EXPORTZP Zp_Machines_sMachine_arr_ptr
Zp_Machines_sMachine_arr_ptr: .res 2

;;; The index of the "current" machine, used for indexing into
;;; Zp_Machines_sMachine_arr_ptr as well as Ram_MachinePc_u8_arr and friends.
;;; This is either the machine that's currently executing, or (if the console
;;; window is open) the machine that the console is controlling.
.EXPORTZP Zp_MachineIndex_u8
Zp_MachineIndex_u8: .res 1

;;; A convenience pointer to entry number Zp_MachineIndex_u8 in the
;;; Zp_Machines_sMachine_arr_ptr array.  Whenever Zp_MachineIndex_u8 is
;;; updated, this should also be updated to match.
.EXPORTZP Zp_Current_sMachine_ptr
Zp_Current_sMachine_ptr: .res 2

;;; A pointer to the program that the the current machine is executing.
;;; Normally this should point to the machine's saved program in SRAM, but it
;;; can also point instead to Ram_Console_sProgram when debugging a machine in
;;; the console.
.EXPORTZP Zp_Current_sProgram_ptr
Zp_Current_sProgram_ptr: .res 2

;;; Temporary storage for the instruction that is currently being executed.
Zp_Current_sInst: .tag sInst

;;;=========================================================================;;;

.SEGMENT "RAM_Machine"

;;; The current status for each machine in the area, indexed by
;;; Zp_MachineIndex_u8.
.EXPORT Ram_MachineStatus_eMachine_arr
Ram_MachineStatus_eMachine_arr: .res kMaxMachines

;;; The program counter for each machine in the area, indexed by
;;; Zp_MachineIndex_u8.
.EXPORT Ram_MachinePc_u8_arr
Ram_MachinePc_u8_arr: .res kMaxMachines

;;; The value of the $a register for each machine in the area, indexed by
;;; Zp_MachineIndex_u8.
Ram_MachineRegA_u8_arr: .res kMaxMachines

;;; TODO: Machine position and other state.

;;;=========================================================================;;;

.SEGMENT "PRGC_Room"

.EXPORT DataC_Machines_sMachine_arr
.PROC DataC_Machines_sMachine_arr
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::JailCellDoor
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte RegNames_u8_arr6, "T", "R", 0, 0, 0, "Y"
    d_addr Init_func_ptr, _Init
    d_addr ReadReg_func_ptr, _ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, _TryMove
    d_addr TryAct_func_ptr, Func_MachineError
    d_addr Tick_func_ptr, _Tick
    d_addr Draw_func_ptr, _Draw
    d_addr Reset_func_ptr, _Reset
    d_byte Padding
    .res kMachinePadding
    D_END
_Init:
    ;; TODO: Implement Init for JailCellDoor machine.
    rts
_ReadReg:
    lda #0  ; TODO: Implement ReadReg for JailCellDoor machine.
    rts
_TryMove:
    jmp Func_MachineError  ; TODO: Implement TryMove for JailCellDoor machine.
_Tick:
    ;; TODO: Implement Tick for JailCellDoor machine.
    rts
_Draw:
    ;; TODO: Implement Draw for JailCellDoor machine.
    rts
_Reset:
    ;; TODO: Implement Reset for JailCellDoor machine.
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8_Machine"

;;; Marks the current machine as having an error and returns zero.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return A Always zero.
;;; @return Z Always set.
.EXPORT Func_MachineError
.PROC Func_MachineError
    ldx Zp_MachineIndex_u8
    lda #eMachine::Error
    sta Ram_MachineStatus_eMachine_arr, x
    lda #0  ; return zero and set Z to indicate failure
    rts
.ENDPROC

;;; Sets Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr, and makes
;;; Zp_Current_sProgram_ptr point to the machine's program in SRAM.
;;; @prereq Zp_Machines_sMachine_arr_ptr is initialized.
;;; @param X The machine index to set.
.EXPORT Func_SetMachineIndex
.PROC Func_SetMachineIndex
    stx Zp_MachineIndex_u8
    ;; Update Zp_Current_sMachine_ptr.
    txa
    .assert .sizeof(sMachine) * kMaxMachines <= $100, error
    mul #.sizeof(sMachine)
    add Zp_Machines_sMachine_arr_ptr + 0
    sta Zp_Current_sMachine_ptr + 0
    lda Zp_Machines_sMachine_arr_ptr + 1
    adc #0
    sta Zp_Current_sMachine_ptr + 1
    ;; Store the machine's program number in A.
    ldy #sMachine::Code_eProgram
    lda (Zp_Current_sMachine_ptr), y
    ;; Calculate the 16-bit byte offset into Sram_Programs_sProgram_arr,
    ;; putting the lo byte in A and the hi byte in Zp_Tmp1_byte.
    .assert sMachine::Code_eProgram = 0, error
    sty Zp_Tmp1_byte  ; Y is currently zero
    .assert .sizeof(sProgram) = $20, error
    .repeat 5
    asl a
    rol Zp_Tmp1_byte
    .endrepeat
    ;; Calculate a pointer to the start of the sProgram in SRAM and store it in
    ;; Zp_Current_sProgram_ptr.
    add #<Sram_Programs_sProgram_arr
    sta Zp_Current_sProgram_ptr + 0
    lda Zp_Tmp1_byte
    adc #>Sram_Programs_sProgram_arr
    sta Zp_Current_sProgram_ptr + 1
    rts
.ENDPROC

;;; Executes the next instruction on the current machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.EXPORT Func_MachineInit
.PROC Func_MachineInit
    ldx Zp_MachineIndex_u8
    ;; Init the machine's PC and $a register to zero.
    lda #0
    sta Ram_MachinePc_u8_arr, x
    sta Ram_MachineRegA_u8_arr, x
    ;; Init the machine's status to Halted if the program is empty, or Running
    ;; otherwise.
    ldy #.sizeof(sInst) * 0 + sInst::Op_byte
    lda (Zp_Current_sProgram_ptr), y
    and #$f0
    beq @emptyProgram
    lda #eMachine::Running
    @emptyProgram:
    .assert eMachine::Halted = 0, error
    sta Ram_MachineStatus_eMachine_arr, x
    ;; Initialize any machine-specific state.
    ldy #sMachine::Init_func_ptr
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
.ENDPROC

;;; Executes the next instruction on the current machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.EXPORT Func_MachineExecuteNext
.PROC Func_MachineExecuteNext
    ldx Zp_MachineIndex_u8
    ;; Check if the machine is running.
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Running
    beq @running
    rts
    @running:
    ;; Load next instruction into Zp_Current_sInst.
    lda Ram_MachinePc_u8_arr, x
    mul #.sizeof(sInst)
    tay
    lda (Zp_Current_sProgram_ptr), y
    sta Zp_Current_sInst + 0
    iny
    lda (Zp_Current_sProgram_ptr), y
    sta Zp_Current_sInst + 1
    .assert .sizeof(sInst) = 2, error
    ;; Branch based on opcode.
    .assert sInst::Op_byte = 1, error
    and #$f0
    div #$10
    tay  ; opcode
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
_JumpTable_ptr_0_arr: .lobytes OpcodeLabels
_JumpTable_ptr_1_arr: .hibytes OpcodeLabels
_OpCopy:
    lda <(Zp_Current_sInst + sInst::Arg_byte)
    and #$0f  ; param: immediate value or register to read
    jsr Func_MachineRead  ; returns A
    tax       ; param: value to write
    lda <(Zp_Current_sInst + sInst::Op_byte)
    and #$0f  ; param: register to write to
    jsr Func_MachineWrite
    jmp _IncrementPc
_OpGoto:
    lda <(Zp_Current_sInst + sInst::Op_byte)
    and #$0f
    sta Ram_MachinePc_u8_arr, x
    rts
_OpSkip:
    lda <(Zp_Current_sInst + sInst::Op_byte)
    and #$0f  ; param: immediate value or register
    jsr Func_MachineRead  ; returns A
    tax
    inx
    bne _IncrementPcByX  ; unconditional
_OpIf:
    jsr _EvalConditional  ; sets Z if condition is true
    beq _IncrementPc
    ldx #2
    bne _IncrementPcByX  ; unconditional
_OpTil:
    jsr _EvalConditional  ; sets Z if condition is true
    bne _IncrementPc
    beq _DecrementPc  ; unconditional
_OpAct:
    jsr Func_MachineTryAct  ; clears Z on success
    bne _IncrementPc
    rts
_OpMove:
    lda <(Zp_Current_sInst + sInst::Op_byte)
    and #$0f  ; param: immediate value or register
    jsr Func_MachineRead  ; returns A
    and #$03  ; turn 0-9 value into 2-bit eDir value
    tax  ; param: eDir value
    jsr Func_MachineTryMove  ; clears Z on success
    bne _IncrementPc
    rts
_OpEnd:
    lda #eMachine::Halted
    sta Ram_MachineStatus_eMachine_arr, x
    rts
_OpSwap:
_OpAdd:
_OpSub:
_OpMul:
    ;; TODO: Implement executing SWAP/ADD/SUB/MUL instructions.
_OpEmpty:
_OpNop:
_IncrementPc:
    ldx #1
_IncrementPcByX:
    lda Zp_MachineMaxInstructions_u8
    mul #.sizeof(sInst)
    sta Zp_Tmp1_byte  ; max offset
    ldy Zp_MachineIndex_u8
    lda Ram_MachinePc_u8_arr, y
    mul #.sizeof(sInst)
    tay
    .assert sInst::Op_byte = 1, error
    iny
    @loop:
    .repeat .sizeof(sInst)
    iny
    .endrepeat
    cpy Zp_Tmp1_byte  ; max offset
    bge @wrap
    lda (Zp_Current_sProgram_ptr), y
    and #$f0
    bne @noWrap
    @wrap:
    ldy #.sizeof(sInst) * 0 + sInst::Op_byte
    @noWrap:
    dex
    bne @loop
    tya
    div #.sizeof(sInst)
    ldx Zp_MachineIndex_u8
    sta Ram_MachinePc_u8_arr, x
    rts
_DecrementPc:
    ;; TODO: Implement _DecrementPc
    rts
.PROC _EvalConditional
    lda <(Zp_Current_sInst + sInst::Arg_byte)
    and #$0f  ; param: immediate value or register to read
    jsr Func_MachineRead  ; returns A
    pha  ; left-hand value
    lda <(Zp_Current_sInst + sInst::Arg_byte)
    div #$10  ; param: immediate value or register to read
    jsr Func_MachineRead  ; returns A
    sta Zp_Tmp1_byte  ; right-hand value
    pla  ; left-hand value
    cmp Zp_Tmp1_byte
    php
    lda <(Zp_Current_sInst + sInst::Op_byte)
    and #$0f
    tax  ; eCmp value
    pla  ; comparison flags
    cpx #eCmp::Eq
    beq _Eq
    cpx #eCmp::Ne
    beq _Ne
    cpx #eCmp::Lt
    beq _Lt
    cpx #eCmp::Gt
    beq _Gt
    cpx #eCmp::Le
    beq _Le
_Ge:
    ;; Set Z if C was set.
    eor #$01
    and #$01
    rts
_Eq:
    ;; Set Z if Z was set.
    eor #$02
    and #$02
    rts
_Ne:
    ;; Set Z if Z was cleared.
    and #$02
    rts
_Lt:
    ;; Set Z if C was cleared.
    and #$01
    rts
_Gt:
    ;; Set Z if C was set and Z was cleared.
    eor #$01
    and #$03
    rts
_Le:
    ;; Set Z if C was cleared or Z was set.
    ;; TODO: Implement LE comparison.
    rts
.ENDPROC
.ENDPROC

;;; Attempts to make the current machine perform its action.  If the machine
;;; is not ready to act yet (e.g. because it's still moving, or because its
;;; last action hasn't cooled off yet), then Z will be set, and the machine
;;; should remain on the same opcode.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return Z Cleared if the machine was able to act, set otherwise.
.PROC Func_MachineTryAct
    ldy #sMachine::TryAct_func_ptr
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)  ; sMachine::TryAct_func_ptr returns Z
.ENDPROC

;;; Attempts to make the current machine move in the specified direction.  If
;;; the machine is not ready to move yet (e.g. because it's still moving), then
;;; Z will be set, and the machine should remain on the same opcode.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X The eDir value for the direction to move in.
;;; @return Z Cleared if the machine was able to move, set otherwise.
.PROC Func_MachineTryMove
    ldy #sMachine::TryMove_func_ptr
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)  ; sMachine::TryMove_func_ptr returns Z
.ENDPROC

;;; Reads a value from a register of the current machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The 4-bit immediate (0-9) or register ($a-$f) value.
;;; @return A The value that was read (0-9).
.PROC Func_MachineRead
    cmp #$0a
    blt @immediate
    beq @readRegA
    tax  ; register to read from
    ldy #sMachine::ReadReg_func_ptr
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp_ptr + 1
    txa  ; param: register to read from
    jmp (Zp_Tmp_ptr)  ; sMachine::ReadReg_func_ptr returns A
    @readRegA:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineRegA_u8_arr, x
    @immediate:
    rts
.ENDPROC

;;; Writes a value to a register of the current machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The register to write to ($a-$f).
;;; @param X The value to write (0-9).
.PROC Func_MachineWrite
    cmp #$0a
    beq @writeRegA
    sta Zp_Tmp1_byte  ; register to write to
    ldy #sMachine::WriteReg_func_ptr
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp_ptr + 1
    lda Zp_Tmp1_byte  ; param: register to write to
    jmp (Zp_Tmp_ptr)
    @writeRegA:
    txa  ; the value to write
    ldx Zp_MachineIndex_u8
    sta Ram_MachineRegA_u8_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;
