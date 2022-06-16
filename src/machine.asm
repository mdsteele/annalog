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

.IMPORT Func_PlayBeepSfx
.IMPORT Sram_Programs_sProgram_arr
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_P1ButtonsHeld_bJoypad
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

.LINECONT +
.DEFINE OpcodeLabels \
    _OpEmpty, _OpCopy, _OpSwap, _OpAdd, _OpSub, _OpMul, _OpGoto, _OpSkip, \
    _OpIf, _OpTil, _OpAct, _OpMove, _OpWait, _OpBeep, _OpEnd, _OpNop
.LINECONT -

;;; OBJ tile IDs used for drawing machine status lights.
kMachineLightTileIdOff = $70
kMachineLightTileIdOn  = $71

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
.EXPORT Ram_MachineRegA_u8_arr
Ram_MachineRegA_u8_arr: .res kMaxMachines

;;; How many more frames until each machine is done moving/acting.
Ram_MachineWait_u8_arr: .res kMaxMachines

;;; A generic counter that decrements on every call to Func_MachineTick.  Each
;;; machine can use this for any purpose it likes, but typically it is used to
;;; help implement moving slower than one pixel per frame.
.EXPORT Ram_MachineSlowdown_u8_arr
Ram_MachineSlowdown_u8_arr: .res kMaxMachines

;;; A one-byte variable that each machine can use however it wants.
.EXPORT Ram_MachineParam1_u8_arr
Ram_MachineParam1_u8_arr: .res kMaxMachines

;;; A two-byte variable that each machine can use however it wants.
.EXPORT Ram_MachineParam2_i16_0_arr, Ram_MachineParam2_i16_1_arr
Ram_MachineParam2_i16_0_arr: .res kMaxMachines
Ram_MachineParam2_i16_1_arr: .res kMaxMachines

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Sets the specified machine's status to the specified eMachine value, and
;;; zeroes all other variables for that machine.
;;; @param A The eMachine value to set for the machine's status.
;;; @param X The machine index.
.PROC Func_ZeroVarsAndSetStatus
    sta Ram_MachineStatus_eMachine_arr, x
    lda #0
    sta Ram_MachinePc_u8_arr, x
    sta Ram_MachineRegA_u8_arr, x
    sta Ram_MachineWait_u8_arr, x
    sta Ram_MachineSlowdown_u8_arr, x
    sta Ram_MachineParam1_u8_arr, x
    sta Ram_MachineParam2_i16_0_arr, x
    sta Ram_MachineParam2_i16_1_arr, x
    rts
.ENDPROC

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

;;; If the current machine's status is eMachine::Resetting, changes it back to
;;; eMachine::Running.  Otherwise, does nothing.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.EXPORT Func_MachineFinishResetting
.PROC Func_MachineFinishResetting
    ldx Zp_MachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Resetting
    bne @notResetting
    lda #eMachine::Running
    sta Ram_MachineStatus_eMachine_arr, x
    @notResetting:
    rts
.ENDPROC

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

;;; If the current machine isn't already restting, zeroes its variables and
;;; puts it into resetting mode.  A resetting machine will move back to its
;;; original position and state (over some period of time) without executing
;;; instructions, and once fully reset, will start running again.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT Func_MachineReset
.PROC Func_MachineReset
    ldx Zp_MachineIndex_u8  ; param: machine index
    lda #eMachine::Resetting  ; param: machine status
    cmp Ram_MachineStatus_eMachine_arr, x
    beq @done
    jsr Func_ZeroVarsAndSetStatus
    ;; Start resetting the machine.
    ldy #sMachine::Reset_func_ptr  ; param: function pointer offset
    jmp Func_MachineCall
    @done:
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
    lda #eMachine::Running  ; param: machine status
    jsr Func_ZeroVarsAndSetStatus
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

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Executes the next instruction on the current machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.PROC FuncA_Machine_ExecuteNext
    ldx Zp_MachineIndex_u8
    ;; Check if the machine is running; if not, do nothing.
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Running
    beq @running
    rts
    @running:
    ;; Decrement the wait timer if necessary.
    lda Ram_MachineWait_u8_arr, x
    beq @doneTimer
    dec Ram_MachineWait_u8_arr, x
    beq @incrementPc
    rts
    @incrementPc:
    jsr _IncrementPc
    ldx Zp_MachineIndex_u8
    @doneTimer:
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
    .assert sMachine::TryAct_func_ptr > 0, error
    bne _MoveOrAct  ; unconditional
_OpMove:
    lda <(Zp_Current_sInst + sInst::Op_byte)
    and #$0f  ; param: immediate value or register
    jsr Func_MachineRead  ; returns A
    and #$03  ; turn 0-9 value into 2-bit eDir value
    tax  ; param: eDir value
    ldy #sMachine::TryMove_func_ptr  ; param: function pointer offset
_MoveOrAct:
    jsr Func_MachineCall  ; sets C on error, returns A
    bcs @error
    tay  ; just to compare A to zero
    beq _IncrementPc
    ldx Zp_MachineIndex_u8
    sta Ram_MachineWait_u8_arr, x
    rts
    @error:
    lda #eMachine::Error
    ldx Zp_MachineIndex_u8
    sta Ram_MachineStatus_eMachine_arr, x
    rts
_OpBeep:
    lda <(Zp_Current_sInst + sInst::Op_byte)
    and #$0f  ; param: immediate value or register
    jsr Func_MachineRead  ; returns A
    jsr Func_PlayBeepSfx
    ldx Zp_MachineIndex_u8
_OpWait:
    lda #$20  ; 32 frames = about half a second
    sta Ram_MachineWait_u8_arr, x
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
.ENDPROC

;;; Calls the current machine's per-frame tick function.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_Tick
.PROC FuncA_Machine_Tick
    ;; Decrement the machine's slowdown value if it's not zero.
    ldx Zp_MachineIndex_u8
    lda Ram_MachineSlowdown_u8_arr, x
    beq @doneWithSlowdown
    dec Ram_MachineSlowdown_u8_arr, x
    @doneWithSlowdown:
    ;; Call the machine's tick function.
    ldy #sMachine::Tick_func_ptr  ; param: function pointer offset
    jmp Func_MachineCall
.ENDPROC

;;; Executes instructions and performs per-frame state updates for all machines
;;; in the room.
.EXPORT FuncA_Machine_ExecuteAll
.PROC FuncA_Machine_ExecuteAll
    ldx #0
    beq @while  ; unconditional
    @loop:
    jsr Func_SetMachineIndex
    jsr Func_GetMachineProgram
    jsr FuncA_Machine_ExecuteNext
    jsr FuncA_Machine_Tick
    ldx Zp_MachineIndex_u8
    inx
    @while:
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    blt @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for all machines in the room.
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

;;; Returns the tile ID to use for the status light on the current machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @return A The tile ID to use.
;;; @preserve Y
.EXPORT FuncA_Objects_GetMachineLightTileId
.PROC FuncA_Objects_GetMachineLightTileId
    ldx Zp_MachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Error
    beq @error
    cpx Zp_ConsoleMachineIndex_u8
    beq @lightOn
    bne @lightOff  ; unconditional
    @error:
    lda Zp_FrameCounter_u8
    and #$08
    beq @lightOff
    @lightOn:
    lda #kMachineLightTileIdOn
    rts
    @lightOff:
    lda #kMachineLightTileIdOff
    rts
.ENDPROC

;;;=========================================================================;;;
