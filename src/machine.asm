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
.INCLUDE "room.inc"

.IMPORT Sram_Programs_sProgram_arr
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

.LINECONT +
.DEFINE OpcodeLabels \
    _OpEmpty, _OpCopy, _OpSwap, _OpAdd, _OpSub, _OpMul, _OpGoto, _OpSkip, \
    _OpIf, _OpTil, _OpAct, _OpMove, _OpEnd, _OpEnd, _OpEnd, _OpNop
.LINECONT -

;;; Constants for 6502 processor flags.
kPFlagC = $01  ; carry flag
kPFlagZ = $02  ; zero flag

;;;=========================================================================;;;

.ZEROPAGE

;;; The maximum number of instructions a program is allowed to have, as
;;; calculated from the player's upgrades.  This should be a positive even
;;; number no greater than kMaxProgramLength.
.EXPORTZP Zp_MachineMaxInstructions_u8
Zp_MachineMaxInstructions_u8: .res 1

;;; The index of the "current" machine, used for indexing into
;;; sRoom::Machines_sMachine_arr_ptr as well as Ram_MachinePc_u8_arr and
;;; friends.
;;; This is either the machine that's currently executing, or (if the console
;;; window is open) the machine that the console is controlling.
.EXPORTZP Zp_MachineIndex_u8
Zp_MachineIndex_u8: .res 1

;;; A convenience pointer to entry number Zp_MachineIndex_u8 in the
;;; Zp_Current_sRoom + sRoom::Machines_sMachine_arr_ptr array.  Whenever
;;; Zp_MachineIndex_u8 is updated, this should also be updated to match.
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

;;; The current status for each machine in the room, indexed by
;;; Zp_MachineIndex_u8.
.EXPORT Ram_MachineStatus_eMachine_arr
Ram_MachineStatus_eMachine_arr: .res kMaxMachines

;;; The program counter for each machine in the room, indexed by
;;; Zp_MachineIndex_u8.
.EXPORT Ram_MachinePc_u8_arr
Ram_MachinePc_u8_arr: .res kMaxMachines

;;; The value of the $a register for each machine in the room, indexed by
;;; Zp_MachineIndex_u8.
Ram_MachineRegA_u8_arr: .res kMaxMachines

;;; RAM that each room's machines can divvy up however they want to store their
;;; state.
.EXPORT Ram_MachineState
Ram_MachineState: .res kMachineStateSize

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Marks the current machine as having an error, sets C, and returns zero.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return A Always zero.
;;; @return C Always set.
.EXPORT Func_MachineError
.PROC Func_MachineError
    ldx Zp_MachineIndex_u8
    lda #eMachine::Error
    sta Ram_MachineStatus_eMachine_arr, x
    lda #0  ; return zero for ReadReg
    sec  ; set C to indicate failure for TryAct/TryMove
    rts
.ENDPROC

;;; Sets Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr, and makes
;;; Zp_Current_sProgram_ptr point to the machine's program in SRAM.
;;; @prereq Zp_Current_sRoom is initialized.
;;; @param X The machine index to set.
;;; @preserve X
.EXPORT Func_SetMachineIndex
.PROC Func_SetMachineIndex
    stx Zp_MachineIndex_u8
    ;; Update Zp_Current_sMachine_ptr.
    txa
    .assert .sizeof(sMachine) * kMaxMachines <= $100, error
    mul #.sizeof(sMachine)
    add <(Zp_Current_sRoom + sRoom::Machines_sMachine_arr_ptr + 0)
    sta Zp_Current_sMachine_ptr + 0
    lda <(Zp_Current_sRoom + sRoom::Machines_sMachine_arr_ptr + 1)
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
.EXPORT Func_MachineExecuteNext
.PROC Func_MachineExecuteNext
    ldx Zp_MachineIndex_u8
    ;; Check if the machine is running; if not, do nothing.
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
_SetLValueToA:
    tax       ; param: value to write
    lda <(Zp_Current_sInst + sInst::Op_byte)
    and #$0f  ; param: register to write to
    jsr Func_MachineWrite
    jmp _IncrementPc
_OpAdd:
    lda <(Zp_Current_sInst + sInst::Arg_byte)
    and #$0f  ; param: immediate value or register to read
    jsr Func_MachineRead  ; returns A
    pha
    lda <(Zp_Current_sInst + sInst::Arg_byte)
    div #$10  ; param: immediate value or register to read
    jsr Func_MachineRead  ; returns A
    sta Zp_Tmp1_byte
    pla
    add Zp_Tmp1_byte
    cmp #10
    blt _SetLValueToA
    lda #9
    bne _SetLValueToA  ; unconditional
_OpSub:
    lda <(Zp_Current_sInst + sInst::Arg_byte)
    and #$0f  ; param: immediate value or register to read
    jsr Func_MachineRead  ; returns A
    pha
    lda <(Zp_Current_sInst + sInst::Arg_byte)
    div #$10  ; param: immediate value or register to read
    jsr Func_MachineRead  ; returns A
    sta Zp_Tmp1_byte
    pla
    sub Zp_Tmp1_byte
    bge _SetLValueToA
    lda #0
    beq _SetLValueToA  ; unconditional
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
    beq _IncrementPc
_DecrementPc:
    ldx Zp_MachineIndex_u8
    lda Ram_MachinePc_u8_arr, x
    beq @wrap
    sub #1
    sta Ram_MachinePc_u8_arr, x
    rts
    @wrap:
    lda Zp_MachineMaxInstructions_u8
    mul #.sizeof(sInst)
    tay
    .assert sInst::Op_byte = .sizeof(sInst) - 1, error
    dey
    @loop:
    lda (Zp_Current_sProgram_ptr), y
    and #$f0
    bne @break
    .repeat .sizeof(sInst)
    dey
    .endrepeat
    bpl @loop
    @break:
    tya
    div #.sizeof(sInst)
    sta Ram_MachinePc_u8_arr, x
    rts
_OpAct:
    ldy #sMachine::TryAct_func_ptr  ; param: function pointer offset
    jsr Func_MachineCall  ; clears C on success
    bcc _IncrementPc
    rts
_OpMove:
    lda <(Zp_Current_sInst + sInst::Op_byte)
    and #$0f  ; param: immediate value or register
    jsr Func_MachineRead  ; returns A
    and #$03  ; turn 0-9 value into 2-bit eDir value
    tax  ; param: eDir value
    ldy #sMachine::TryMove_func_ptr  ; param: function pointer offset
    jsr Func_MachineCall  ; clears C on success
    bcc _IncrementPc
    rts
_OpEnd:
    lda #eMachine::Ended
    sta Ram_MachineStatus_eMachine_arr, x
_OpEmpty:
    rts
_OpSwap:
_OpMul:
    ;; TODO: Implement executing SWAP/MUL instructions.
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
    eor #kPFlagC
    and #kPFlagC
    rts
_Eq:
    ;; Set Z if Z was set.
    eor #kPFlagZ
    and #kPFlagZ
    rts
_Ne:
    ;; Set Z if Z was cleared.
    and #kPFlagZ
    rts
_Lt:
    ;; Set Z if C was cleared.
    and #kPFlagC
    rts
_Gt:
    ;; Set Z if C was set and Z was cleared.
    eor #kPFlagC
    and #kPFlagC | kPFlagZ
    rts
_Le:
    ;; Set Z if C was cleared or Z was set.
    tax
    and #kPFlagC
    beq @done
    txa
    eor #kPFlagZ
    and #kPFlagZ
    @done:
    rts
.ENDPROC
.ENDPROC

;;; Reads a value from a register of the current machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The 4-bit immediate (0-9) or register ($a-$f) value.
;;; @return A The value that was read (0-9).
.PROC Func_MachineRead
    cmp #$0a
    blt @immediate
    beq @readRegA
    ldy #sMachine::ReadReg_func_ptr  ; param: function pointer offset
    jmp Func_MachineCall  ; sMachine::ReadReg_func_ptr returns A
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
    ldy #sMachine::WriteReg_func_ptr  ; param: function pointer offset
    jmp Func_MachineCall
    @writeRegA:
    txa  ; the value to write
    ldx Zp_MachineIndex_u8
    sta Ram_MachineRegA_u8_arr, x
    rts
.ENDPROC

;;; Resets the current machine's PC and $a register, and puts the machine into
;;; resetting mode.  A resetting machine will move back to its original
;;; position and state (over some period of time) without executing
;;; instructions, and once fully reset, will start running again.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT Func_MachineReset
.PROC Func_MachineReset
    ldx Zp_MachineIndex_u8
    ;; Reset the machine's PC and $a register to zero.
    lda #0
    sta Ram_MachinePc_u8_arr, x
    sta Ram_MachineRegA_u8_arr, x
    ;; Set the machine's status to Resetting.
    lda #eMachine::Resetting
    sta Ram_MachineStatus_eMachine_arr, x
    ;; Start resetting the machine.
    ldy #sMachine::Reset_func_ptr  ; param: function pointer offset
    jmp Func_MachineCall
.ENDPROC

;;; Calls the current machine's per-frame tick function.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT Func_MachineTick
.PROC Func_MachineTick
    ldy #sMachine::Tick_func_ptr  ; param: function pointer offset
    .assert * = Func_MachineCall, error, "fallthrough"
.ENDPROC

;;; Calls the specified function for the current machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param Y The byte offset for a function pointer in sMachine.
;;; @param A The A parameter for the function (if any).
;;; @param X The X parameter for the function (if any).
;;; @return Whatever the called function returns (if anything).
.PROC Func_MachineCall
    sta Zp_Tmp1_byte
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp_ptr + 1
    lda Zp_Tmp1_byte
    jmp (Zp_Tmp_ptr)
.ENDPROC

;;; Initializes state for all machines in the room.
.EXPORT Func_InitAllMachines
.PROC Func_InitAllMachines
    ldx #0
    beq @while  ; unconditional
    @loop:
    jsr Func_SetMachineIndex  ; preserves X
    ;; Init the machine's PC and $a register to zero, and status to Running.
    lda #0
    sta Ram_MachinePc_u8_arr, x
    sta Ram_MachineRegA_u8_arr, x
    .assert eMachine::Running = 0, error
    sta Ram_MachineStatus_eMachine_arr, x
    ;; Initialize any machine-specific state.
    txa
    pha
    ldy #sMachine::Init_func_ptr  ; param: function pointer offset
    jsr Func_MachineCall
    pla
    tax
    ;; Continue to the next machine.
    inx
    @while:
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    blt @loop
    rts
.ENDPROC

;;; Executes instructions and performs per-frame state updates for all machines
;;; in the room.
.EXPORT Func_ExecuteAllMachines
.PROC Func_ExecuteAllMachines
    ldx #0
    beq @while  ; unconditional
    @loop:
    txa
    pha
    jsr Func_SetMachineIndex
    jsr Func_MachineExecuteNext
    jsr Func_MachineTick
    pla
    tax
    inx
    @while:
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    blt @loop
    rts
.ENDPROC

;;; Allocates and populates OAM slots for all machines in the room.
.EXPORT Func_DrawObjectsForAllMachines
.PROC Func_DrawObjectsForAllMachines
    ldx #0
    beq @while  ; unconditional
    @loop:
    txa
    pha
    jsr Func_SetMachineIndex
    ldy #sMachine::Draw_func_ptr  ; param: function pointer offset
    jsr Func_MachineCall
    pla
    tax
    inx
    @while:
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    blt @loop
    rts
.ENDPROC

;;;=========================================================================;;;
