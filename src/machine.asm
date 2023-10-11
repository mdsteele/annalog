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

.INCLUDE "cpu.inc"
.INCLUDE "joypad.inc"
.INCLUDE "machine.inc"
.INCLUDE "macros.inc"
.INCLUDE "program.inc"
.INCLUDE "room.inc"

.IMPORT FuncA_Machine_PlaySfxBeep
.IMPORT FuncA_Machine_PlaySfxError
.IMPORT FuncA_Machine_PlaySfxSync
.IMPORT Sram_Programs_sProgram_arr
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_P1ButtonsHeld_bJoypad

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
Zp_Current_sIns: .tag sIns

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

;;; How many more frames until each machine is done with Waiting mode.
Ram_MachineWait_u8_arr: .res kMaxMachines

;;; A generic counter that decrements on every call to FuncA_Machine_Tick.
;;; Each machine can use this for any purpose it likes, but typically it is
;;; used to help implement moving slower than one pixel per frame.  This is
;;; automatically set to zero on both init and reset.
.EXPORT Ram_MachineSlowdown_u8_arr
Ram_MachineSlowdown_u8_arr: .res kMaxMachines

;;; Horizontal and vertical goal positions, for machines that need them.  These
;;; are automatically set to zero on init (though they can be set to something
;;; else in the machine's Init function), but are *not* automatically modified
;;; on reset (so that the machine's Reset function can check their current
;;; values when deciding how to reset).
.EXPORT Ram_MachineGoalHorz_u8_arr
Ram_MachineGoalHorz_u8_arr: .res kMaxMachines
.EXPORT Ram_MachineGoalVert_u8_arr
Ram_MachineGoalVert_u8_arr: .res kMaxMachines

;;; State variables that each machine can use however it wants.  These are
;;; automatically set to zero on init (though they can be set to something else
;;; in the machine's Init function), but are *not* automatically modified on
;;; reset.
.EXPORT Ram_MachineState1_byte_arr
Ram_MachineState1_byte_arr: .res kMaxMachines
.EXPORT Ram_MachineState2_byte_arr
Ram_MachineState2_byte_arr: .res kMaxMachines
.EXPORT Ram_MachineState3_byte_arr
Ram_MachineState3_byte_arr: .res kMaxMachines
.EXPORT Ram_MachineState4_byte_arr
Ram_MachineState4_byte_arr: .res kMaxMachines

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Sets Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr.
;;; @prereq Zp_Current_sRoom is initialized.
;;; @param X The machine index to set.
;;; @preserve X
.EXPORT Func_SetMachineIndex
.PROC Func_SetMachineIndex
    stx Zp_MachineIndex_u8
    ;; Update Zp_Current_sMachine_ptr.
    lda <(Zp_Current_sRoom + sRoom::Machines_sMachine_arr_ptr + 0)
    add _MachineOffsets_u8_arr, x
    sta Zp_Current_sMachine_ptr + 0
    lda <(Zp_Current_sRoom + sRoom::Machines_sMachine_arr_ptr + 1)
    adc #0
    sta Zp_Current_sMachine_ptr + 1
    rts
_MachineOffsets_u8_arr:
    .assert .sizeof(sMachine) * (kMaxMachines - 1) < $100, error
    .repeat kMaxMachines, index
    .byte .sizeof(sMachine) * index
    .endrepeat
.ENDPROC

;;; Sets Zp_Current_sProgram_ptr to point to the current machine's program in
;;; SRAM.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT Func_GetMachineProgram
.PROC Func_GetMachineProgram
    ;; Store the machine's program number in A.
    ldy #sMachine::Code_eProgram
    lda (Zp_Current_sMachine_ptr), y
    ;; Calculate the 16-bit byte offset into Sram_Programs_sProgram_arr,
    ;; putting the lo byte in A and the hi byte in T0.
    .assert sMachine::Code_eProgram = 0, error
    sty T0  ; Y is currently zero
    .assert .sizeof(sProgram) = 1 << 5, error
    .repeat 5
    asl a
    rol T0
    .endrepeat
    ;; Calculate a pointer to the start of the sProgram in SRAM and store it in
    ;; Zp_Current_sProgram_ptr.
    adc #<Sram_Programs_sProgram_arr  ; carry is already clear
    sta Zp_Current_sProgram_ptr + 0
    lda T0  ; byte offset (hi)
    adc #>Sram_Programs_sProgram_arr
    sta Zp_Current_sProgram_ptr + 1
    rts
.ENDPROC

;;; Reads an immediate or register value for the current machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The 4-bit immediate (0-9) or register ($a-$f) value.
;;; @return A The value that was read (0-9).
.EXPORT Func_MachineRead
.PROC Func_MachineRead
    cmp #$0a
    blt _Immediate
    beq _ReadRegA
    cmp #$0b
    beq _ReadRegB
    ldy #sMachine::ReadReg_func_ptr  ; param: function pointer offset
    jmp Func_MachineCall  ; sMachine::ReadReg_func_ptr returns A
_ReadRegA:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineRegA_u8_arr, x
_Immediate:
    rts
_ReadRegB:
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::BButton
    beq _Immediate
    ldy #5
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Left
    beq @noLeft
    dey
    @noLeft:
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Right
    beq @noRight
    iny
    @noRight:
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Up
    beq @noUp
    dey
    dey
    dey
    @noUp:
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Down
    beq @noDown
    iny
    iny
    iny
    @noDown:
    tya
    rts
.ENDPROC

;;; Calls the specified function for the current machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq The appropriate PRGA bank for the function (if any) is loaded.
;;; @param Y The byte offset for a function pointer in sMachine.
;;; @param A The A parameter for the function (if any).
;;; @param X The X parameter for the function (if any).
;;; @return Whatever the called function returns (if anything).
.PROC Func_MachineCall
    sta T2  ; parameter A
    lda (Zp_Current_sMachine_ptr), y
    sta T0  ; func ptr (lo)
    iny
    lda (Zp_Current_sMachine_ptr), y
    sta T1  ; func ptr (hi)
    lda T2  ; parameter A
    jmp (T1T0)
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Sets the specified machine's status to the specified eMachine value, and
;;; zeroes all other non-goal/param variables for that machine.
;;; @param A The eMachine value to set for the machine's status.
;;; @param X The machine index.
;;; @return A Always zero.
;;; @preserve X
.PROC FuncA_Room_ZeroMachineVarsAndSetStatus
    sta Ram_MachineStatus_eMachine_arr, x
    lda #0
    sta Ram_MachinePc_u8_arr, x
    sta Ram_MachineRegA_u8_arr, x
    sta Ram_MachineWait_u8_arr, x
    sta Ram_MachineSlowdown_u8_arr, x
    rts
.ENDPROC

;;; If the current machine isn't already resetting, zeroes its variables and
;;; puts it into resetting mode.  A resetting machine will move back to its
;;; original position and state (over some period of time) without executing
;;; instructions, and once fully reset, will start running again.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Room_MachineReset
.PROC FuncA_Room_MachineReset
    ldx Zp_MachineIndex_u8  ; param: machine index
    lda #eMachine::Resetting  ; param: machine status
    cmp Ram_MachineStatus_eMachine_arr, x
    beq @done
    jsr FuncA_Room_ZeroMachineVarsAndSetStatus
    ;; Start resetting the machine.
    ldy #sMachine::Reset_func_ptr  ; param: function pointer offset
    jmp Func_MachineCall
    @done:
    rts
.ENDPROC

;;; Initializes state for all machines in the room.
.EXPORT FuncA_Room_InitAllMachines
.PROC FuncA_Room_InitAllMachines
    ldx #0
    beq @while  ; unconditional
    @loop:
    jsr Func_SetMachineIndex  ; preserves X
    lda #eMachine::Running  ; param: machine status
    jsr FuncA_Room_ZeroMachineVarsAndSetStatus  ; preserves X, returns 0 in A
    sta Ram_MachineGoalHorz_u8_arr, x
    sta Ram_MachineGoalVert_u8_arr, x
    sta Ram_MachineState1_byte_arr, x
    sta Ram_MachineState2_byte_arr, x
    sta Ram_MachineState3_byte_arr, x
    sta Ram_MachineState4_byte_arr, x
    ;; Initialize any machine-specific state.
    ldy #sMachine::Init_func_ptr  ; param: function pointer offset
    jsr Func_MachineCall
    ;; Continue to the next machine.
    ldx Zp_MachineIndex_u8
    inx
    @while:
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    blt @loop
    rts
.ENDPROC

;;; Halts execution for all machines in the room (as though each one had
;;; executed an END opcode).  Machines that are in the middle of moving or
;;; resetting will continue doing so until they finish their current operation.
.EXPORT FuncA_Room_HaltAllMachines
.PROC FuncA_Room_HaltAllMachines
    lda #eMachine::Ended
    ldx #0
    beq @while  ; unconditional
    @loop:
    sta Ram_MachineStatus_eMachine_arr, x
    inx
    @while:
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    blt @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Marks the current machine as having an error.  This should be called
;;; from a machine's TryMove or TryAct function when one of those operations
;;; fails.  It can also be used as a default implemention for those functions
;;; for machines that don't support moving/acting.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_Error
.PROC FuncA_Machine_Error
    ldx Zp_MachineIndex_u8
    lda #eMachine::Error
    sta Ram_MachineStatus_eMachine_arr, x
    jmp FuncA_Machine_PlaySfxError
.ENDPROC

;;; Puts the current machine into Working mode (which blocks execution until
;;; the machine's Tick function calls FuncA_Machine_ReachedGoal).  This should
;;; be called from a machine's TryMove, TryAct, or WriteReg function for
;;; operations that will require an indeterminate amount of time to complete
;;; (e.g. if some part of the machine needs to move until it reaches some goal
;;; position).
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_StartWorking
.PROC FuncA_Machine_StartWorking
    ldx Zp_MachineIndex_u8
    lda #eMachine::Working
    sta Ram_MachineStatus_eMachine_arr, x
    rts
.ENDPROC

;;; Puts the current machine into Waiting mode for the specified number of
;;; frames (which blocks execution until that many frames have elapsed).  This
;;; should be called from a machine's TryMove, TryAct, or WriteReg function for
;;; operations that are instantaneous, but that require a cooldown period
;;; before execution continues.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The number of frames to wait (must be nonzero).
.EXPORT FuncA_Machine_StartWaiting
.PROC FuncA_Machine_StartWaiting
    ldx Zp_MachineIndex_u8
    sta Ram_MachineWait_u8_arr, x
    lda #eMachine::Waiting
    sta Ram_MachineStatus_eMachine_arr, x
    rts
.ENDPROC

;;; This should be called from a machine's Tick function when its goal position
;;; has been reached.
;;;   * If the machine is in Resetting mode, this will put it back into Running
;;;     mode so it can start executing its program.
;;;   * If the machine is in Working mode, this will increment its PC and put
;;;     it back into Running mode, so that it is ready to execute the next
;;;     instruction.
;;;   * If the machine is in any other mode, this will do nothing.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.EXPORT FuncA_Machine_ReachedGoal
.PROC FuncA_Machine_ReachedGoal
    ldx Zp_MachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Resetting
    beq _StartRunning
    cmp #eMachine::Working
    bne _Return
_FinishWorking:
    jsr FuncA_Machine_IncrementPc
_StartRunning:
    lda #eMachine::Running
    sta Ram_MachineStatus_eMachine_arr, x
_Return:
    rts
.ENDPROC

;;; Helper function for FuncA_Machine_ExecuteNext.  Extracts the two arguments
;;; from a binop instruction (ADD, SUB, MUL, IF, or TIL).
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sIns holds a binop instruction.
;;; @return A The left-hand value (0-9).
;;; @return Y The right-hand value (0-9).
.PROC FuncA_Machine_GetBinopArgs
    lda <(Zp_Current_sIns + sIns::Arg_byte)
    and #$0f  ; param: immediate value or register to read
    jsr Func_MachineRead  ; returns A
    pha  ; left-hand value
    lda <(Zp_Current_sIns + sIns::Arg_byte)
    div #$10  ; param: immediate value or register to read
    jsr Func_MachineRead  ; returns A
    tay  ; right-hand value
    pla  ; left-hand value
    rts
.ENDPROC

;;; Helper function for FuncA_Machine_ExecuteNext.  Evaluates the predicate for
;;; a conditional instruction (IF or TIL).
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sIns holds a conditional instruction.
;;; @return Z Set if the condition is true, cleared if false.
.PROC FuncA_Machine_EvalConditional
    jsr FuncA_Machine_GetBinopArgs  ; returns A and Y
    sty T0  ; right-hand value
    cmp T0  ; right-hand value
    php  ; comparison flags
    lda <(Zp_Current_sIns + sIns::Op_byte)
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
    eor #bProc::Carry
    and #bProc::Carry
    rts
_Eq:
    ;; Set Z if Z was set.
    eor #bProc::Zero
    and #bProc::Zero
    rts
_Ne:
    ;; Set Z if Z was cleared.
    and #bProc::Zero
    rts
_Lt:
    ;; Set Z if C was cleared.
    and #bProc::Carry
    rts
_Gt:
    ;; Set Z if C was set and Z was cleared.
    eor #bProc::Carry
    and #bProc::Carry | bProc::Zero
    rts
_Le:
    ;; Set Z if C was cleared or Z was set.
    tax
    and #bProc::Carry
    beq @done
    txa
    eor #bProc::Zero
    and #bProc::Zero
    @done:
    rts
.ENDPROC

;;; Executes the next instruction on the current machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.EXPORT FuncA_Machine_ExecuteNext
.PROC FuncA_Machine_ExecuteNext
    ;; If the machine is in Running mode, then execute the next instruction.
    ;; Otherwise, execution is blocked, so we're done.
    ldx Zp_MachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, x
    .assert eMachine::Running = 0, error
    beq _ExecInstruction
    rts
_ExecInstruction:
    ;; Load next instruction into Zp_Current_sIns.
    lda Ram_MachinePc_u8_arr, x
    mul #.sizeof(sIns)
    tay
    lda (Zp_Current_sProgram_ptr), y
    sta Zp_Current_sIns + 0
    iny
    lda (Zp_Current_sProgram_ptr), y
    sta Zp_Current_sIns + 1
    .assert .sizeof(sIns) = 2, error
    ;; Branch based on opcode.
    .assert sIns::Op_byte = 1, error
    and #$f0
    div #$10
    tay  ; opcode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eOpcode
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
    d_entry table, Nop,   FuncA_Machine_IncrementPc
    D_END
.ENDREPEAT
_OpAdd:
    jsr FuncA_Machine_GetBinopArgs  ; returns A and Y
    sty T0  ; right-hand value
    add T0  ; right-hand value
    cmp #10
    blt _SetLValueToA
    lda #9
    bne _SetLValueToA  ; unconditional
_OpSub:
    jsr FuncA_Machine_GetBinopArgs  ; returns A and Y
    sty T0  ; right-hand value
    sub T0  ; right-hand value
    bge _SetLValueToA
    lda #0
    beq _SetLValueToA  ; unconditional
_OpMul:
    ;; Get the two factors to multiply together.
    jsr FuncA_Machine_GetBinopArgs  ; returns A and Y
    sty T0  ; right-hand value
    ;; If necessary, swap the two factors so that the smaller factor is in A,
    ;; and the larger factor is in T0.
    cmp T0  ; right-hand value
    blt @doneSwap
    sta T0  ; larger factor
    tya     ; smaller factor
    @doneSwap:
    ;; If the smaller factor is >= 3, then the product will be >= 9, so just
    ;; saturate at 9.
    cmp #3
    bge @productIs9
    ;; If the smaller factor is zero, the product is zero.
    cmp #1
    blt _SetLValueToA  ; A is zero
    ;; Otherwise, the smaller factor is 1 or 2, so the product is the other
    ;; factor, possibly doubled.  We just have to check for saturation.
    beq @doneShift
    asl T0  ; larger factor
    @doneShift:
    lda T0  ; product (possibly > 9)
    cmp #10
    blt _SetLValueToA
    @productIs9:
    lda #9
    bne _SetLValueToA  ; unconditional
_OpCopy:
    lda <(Zp_Current_sIns + sIns::Arg_byte)
    and #$0f  ; param: immediate value or register to read
    jsr Func_MachineRead  ; returns A
_SetLValueToA:
    pha  ; value to write
    lda <(Zp_Current_sIns + sIns::Op_byte)
    and #$0f
    tax  ; param: register to write to
    pla  ; param: value to write
    jsr FuncA_Machine_WriteReg
    jmp FuncA_Machine_IncrementPcIfRunning
_OpSkip:
    lda <(Zp_Current_sIns + sIns::Op_byte)
    and #$0f  ; param: immediate value or register
    jsr Func_MachineRead  ; returns A
    tax
    inx
    bne FuncA_Machine_IncrementPcByX  ; unconditional
_OpIf:
    jsr FuncA_Machine_EvalConditional  ; sets Z if condition is true
    beq FuncA_Machine_IncrementPc
    ldx #2
    bne FuncA_Machine_IncrementPcByX  ; unconditional
_OpTil:
    jsr FuncA_Machine_EvalConditional  ; sets Z if condition is true
    beq FuncA_Machine_IncrementPc
_DecrementPc:
    ldx Zp_MachineIndex_u8
    lda Ram_MachinePc_u8_arr, x
    beq @wrap
    sub #1
    sta Ram_MachinePc_u8_arr, x
    rts
    @wrap:
    lda Zp_MachineMaxInstructions_u8
    mul #.sizeof(sIns)
    tay
    .assert sIns::Op_byte = .sizeof(sIns) - 1, error
    dey
    @loop:
    lda (Zp_Current_sProgram_ptr), y
    and #$f0
    bne @break
    .repeat .sizeof(sIns)
    dey
    .endrepeat
    bpl @loop
    @break:
    tya
    div #.sizeof(sIns)
    sta Ram_MachinePc_u8_arr, x
    rts
_OpAct:
    ldy #sMachine::TryAct_func_ptr  ; param: function pointer offset
    .assert sMachine::TryAct_func_ptr > 0, error
    bne _MoveOrAct  ; unconditional
_OpMove:
    lda <(Zp_Current_sIns + sIns::Op_byte)
    and #$0f  ; param: immediate value or register
    jsr Func_MachineRead  ; returns A
    and #$03  ; turn 0-9 value into 2-bit eDir value
    tax  ; param: eDir value
    ldy #sMachine::TryMove_func_ptr  ; param: function pointer offset
_MoveOrAct:
    jsr Func_MachineCall
    jmp FuncA_Machine_IncrementPcIfRunning
_OpGoto:
    lda <(Zp_Current_sIns + sIns::Op_byte)
    and #$0f
    sta Ram_MachinePc_u8_arr, x
    rts
_OpBeep:
    lda <(Zp_Current_sIns + sIns::Op_byte)
    and #$0f  ; param: immediate value or register
    jsr Func_MachineRead  ; returns A
    jsr FuncA_Machine_PlaySfxBeep
_OpRest:
    lda #$10  ; 16 frames = about a quarter second
    jmp FuncA_Machine_StartWaiting
_OpEnd:
    lda #eMachine::Ended
    sta Ram_MachineStatus_eMachine_arr, x
_OpEmpty:
    rts
_OpSync:
    lda #eMachine::Syncing
    sta Ram_MachineStatus_eMachine_arr, x
    rts
.ENDPROC

;;; If the current machine's status is Running, increments its program counter
;;; by 1.  Otherwise (e.g. if the program is still busy working on the current
;;; instruction), does nothing.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.PROC FuncA_Machine_IncrementPcIfRunning
    ldx Zp_MachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, x
    .assert eMachine::Running = 0, error
    beq FuncA_Machine_IncrementPc
    rts
.ENDPROC

;;; Increments the program counter of the current machine by 1.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.PROC FuncA_Machine_IncrementPc
    ldx #1  ; param: num instructions
    .assert * = FuncA_Machine_IncrementPcByX, error, "fallthrough"
.ENDPROC

;;; Increments the program counter of the current machine by X.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
;;; @param X The number of instructions to increment by (must be nonzero).
.PROC FuncA_Machine_IncrementPcByX
    lda Zp_MachineMaxInstructions_u8
    mul #.sizeof(sIns)
    sta T0  ; max byte offset
    ldy Zp_MachineIndex_u8
    lda Ram_MachinePc_u8_arr, y
    mul #.sizeof(sIns)
    .assert sProgram::Code_sIns_arr = 0, error
    tay  ; byte offset for current instruction
    .assert sIns::Op_byte = 1, error
    iny
    @loop:
    .repeat .sizeof(sIns)
    iny
    .endrepeat
    cpy T0  ; max byte offset
    bge @wrap
    lda (Zp_Current_sProgram_ptr), y
    and #$f0
    .assert eOpcode::Empty = 0, error
    bne @noWrap
    @wrap:
    ldy #sProgram::Code_sIns_arr + .sizeof(sIns) * 0 + sIns::Op_byte
    @noWrap:
    dex
    bne @loop
    tya  ; byte offset for opcode of new PC instruction
    div #.sizeof(sIns)
    ldx Zp_MachineIndex_u8
    sta Ram_MachinePc_u8_arr, x
    rts
.ENDPROC

;;; Writes a value to a register of the current machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
;;; @param X The register to write to ($a-$f).
.PROC FuncA_Machine_WriteReg
    cpx #$0a
    beq @writeRegA
    ldy #sMachine::WriteReg_func_ptr  ; param: function pointer offset
    jmp Func_MachineCall
    @writeRegA:
    ldx Zp_MachineIndex_u8
    sta Ram_MachineRegA_u8_arr, x
    rts
.ENDPROC

;;; Calls the current machine's per-frame tick function.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.PROC FuncA_Machine_Tick
    ldx Zp_MachineIndex_u8
_DecrementWaitTimer:
    ;; If the machine is in Waiting mode, decrement its wait timer.
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Waiting
    bne @done
    dec Ram_MachineWait_u8_arr, x
    bne @done
    ;; Return the machine to Running mode when the timer reaches zero.
    lda #eMachine::Running
    sta Ram_MachineStatus_eMachine_arr, x
    jsr FuncA_Machine_IncrementPc
    @done:
_DecrementSlowdownTimer:
    ;; Decrement the machine's slowdown value if it's not zero.
    lda Ram_MachineSlowdown_u8_arr, x
    beq @done
    dec Ram_MachineSlowdown_u8_arr, x
    @done:
_CallTickFunction:
    ldy #sMachine::Tick_func_ptr  ; param: function pointer offset
    jmp Func_MachineCall
.ENDPROC

;;; Performs per-frame state updates for all machines in the room (but does not
;;; execute any further instructions).
.EXPORT FuncA_Machine_TickAll
.PROC FuncA_Machine_TickAll
    ;; If there are no machines in this room, then we're done.
    lda <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    beq @return
    ;; Call each machine's tick function.
    ldx #0
    @loop:
    jsr Func_SetMachineIndex
    jsr Func_GetMachineProgram
    jsr FuncA_Machine_Tick
    ldx Zp_MachineIndex_u8
    inx
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    blt @loop
    @return:
    rts
.ENDPROC

;;; Executes instructions and performs per-frame state updates for all machines
;;; in the room.
.EXPORT FuncA_Machine_ExecuteAll
.PROC FuncA_Machine_ExecuteAll
    ;; If there are no machines in this room, then we're done.
    lda <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    beq _Return
_Execute:
    ;; Give each machine in the room a chance to execute.
    ldx #0
    @loop:
    jsr Func_SetMachineIndex
    jsr Func_GetMachineProgram
    jsr FuncA_Machine_ExecuteNext
    jsr FuncA_Machine_Tick
    ldx Zp_MachineIndex_u8
    inx
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    blt @loop
_CheckForSync:
    ;; Check if all machines in the room are blocked on a SYNC instruction.  If
    ;; at least one isn't, then we're done.
    ldx #0
    @loop:
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Syncing
    bne _Return
    inx
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    blt @loop
_UnblockSync:
    ;; At this point, all machines in the room have reached a SYNC instruction,
    ;; so advance each one past the SYNC instruction and put them back into
    ;; Running mode.
    ldx #0
    @loop:
    lda #eMachine::Running
    sta Ram_MachineStatus_eMachine_arr, x
    jsr Func_SetMachineIndex
    jsr Func_GetMachineProgram
    jsr FuncA_Machine_IncrementPc
    ldx Zp_MachineIndex_u8
    inx
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    blt @loop
    jmp FuncA_Machine_PlaySfxSync
_Return:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws all machines in the room.
.EXPORT FuncA_Objects_DrawAllMachines
.PROC FuncA_Objects_DrawAllMachines
    ldx #0
    beq @while  ; unconditional
    @loop:
    jsr Func_SetMachineIndex
    ldy #sMachine::Draw_func_ptr  ; param: function pointer offset
    jsr Func_MachineCall
    ldx Zp_MachineIndex_u8
    inx
    @while:
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    blt @loop
    rts
.ENDPROC

;;;=========================================================================;;;
