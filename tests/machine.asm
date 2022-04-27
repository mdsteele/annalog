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

.INCLUDE "../src/machine.inc"
.INCLUDE "../src/macros.inc"
.INCLUDE "../src/program.inc"
.INCLUDE "../src/room.inc"

.IMPORT Exit_Success
.IMPORT Func_ExpectAEqualsY
.IMPORT Func_InitAllMachines
.IMPORT Func_MachineError
.IMPORT Func_MachineExecuteNext
.IMPORT Func_SetMachineIndex
.IMPORT Ram_MachinePc_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_Current_sProgram_ptr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_MachineMaxInstructions_u8

;;;=========================================================================;;;

.DEFINE kTestMachineIndex 0
.DEFINE kTestProgramIndex 3

kMaxTestMachinePosX = 9
kMaxTestMachinePosY = 9

;;;=========================================================================;;;

.ZEROPAGE

.EXPORTZP Zp_P1ButtonsHeld_bJoypad
Zp_P1ButtonsHeld_bJoypad: .res 1

.EXPORTZP Zp_Tmp1_byte, Zp_Tmp_ptr
Zp_Tmp1_byte: .res 1
Zp_Tmp_ptr: .res 2

.EXPORTZP Zp_Current_sRoom
Zp_Current_sRoom: .tag sRoom

;;; The current X/Y position of the test machine.
Zp_TestMachinePosX_u8: .res 1
Zp_TestMachinePosY_u8: .res 1

;;; Counter that is incremented whenever the machine executes an ACT opcode.
Zp_TestMachineActCounter_u8: .res 1

;;; The number of instructions to execute during the test.
Zp_TestCycleCount_u8: .res 1

;;;=========================================================================;;;

.CODE

.EXPORT Sram_Programs_sProgram_arr
.PROC Sram_Programs_sProgram_arr
    .res .sizeof(sProgram) * kTestProgramIndex
TestProgram:
    .word $b300  ; MOVE >
    .word $93e5  ; TIL 5<=X
    .word $b000  ; MOVE ^
    .word $1a0f  ; A <- Y
    .word $3aa2  ; A <- 2 + A
    .word $4a1a  ; A <- A - 1
    .word $a000  ; ACT
    .word $815a  ; IF A!=5
    .word $6200  ; GOTO 2
    .word $b300  ; MOVE >
    .word $e000  ; END
    .word $0000
    .word $0000
    .word $0000
    .word $0000
    .word $0000
.ASSERT * - TestProgram = .sizeof(sProgram), error
.ENDPROC

.PROC Data_Machines_sMachine_arr
TestMachine:
    D_STRUCT sMachine
    d_byte Code_eProgram, kTestProgramIndex
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::MoveH
    d_byte Status_eDiagram, eDiagram::Barrier
    d_word ScrollGoalX_u16, 0
    d_byte ScrollGoalY_u8, 0
    d_byte RegNames_u8_arr4, 0, 0, "X", "Y"
    d_addr Init_func_ptr, _Init
    d_addr ReadReg_func_ptr, _ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, _TryMove
    d_addr TryAct_func_ptr, _TryAct
    d_addr Tick_func_ptr, _Tick
    d_addr Draw_func_ptr, _Draw
    d_addr Reset_func_ptr, _Reset
    d_byte Padding
    .res kMachinePadding
    D_END
_Init:
    lda #1
    sta Zp_TestMachinePosX_u8
    sta Zp_TestMachinePosY_u8
    lda #0
    sta Zp_TestMachineActCounter_u8
    rts
_ReadReg:
    cmp #$e
    beq @readRegX
    cmp #$f
    beq @readRegY
    jmp Func_MachineError
    @readRegX:
    lda Zp_TestMachinePosX_u8
    rts
    @readRegY:
    lda Zp_TestMachinePosY_u8
    rts
_TryMove:
    cpx #eDir::Up
    beq @moveUp
    cpx #eDir::Down
    beq @moveDown
    cpx #eDir::Left
    beq @moveLeft
    cpx #eDir::Right
    beq @moveRight
    @error:
    sec  ; set C to indicate failure
    rts
    @moveUp:
    lda Zp_TestMachinePosY_u8
    cmp #kMaxTestMachinePosY
    beq @error
    inc Zp_TestMachinePosY_u8
    jmp @success
    @moveDown:
    lda Zp_TestMachinePosY_u8
    beq @error
    dec Zp_TestMachinePosY_u8
    jmp @success
    @moveLeft:
    lda Zp_TestMachinePosX_u8
    beq @error
    dec Zp_TestMachinePosX_u8
    jmp @success
    @moveRight:
    lda Zp_TestMachinePosX_u8
    cmp #kMaxTestMachinePosX
    beq @error
    inc Zp_TestMachinePosX_u8
    @success:
    lda #0  ; wait for zero frames
    clc  ; clear C to indicate success
    rts
_TryAct:
    inc Zp_TestMachineActCounter_u8
    lda #0  ; wait for zero frames
    clc  ; clear C to indicate success
    rts
_Tick:
_Draw:
_Reset:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "MAIN"
    sei
    cld
    ldx #$ff
    txs
SetMachineIndex:
    lda #kMaxProgramLength
    sta Zp_MachineMaxInstructions_u8
    ldax #Data_Machines_sMachine_arr
    stax <(Zp_Current_sRoom + sRoom::Machines_sMachine_arr_ptr)
    lda #1
    sta <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    ;; Set the current machine.
    ldx #kTestMachineIndex  ; param: machine index
    jsr Func_SetMachineIndex
    ;; Verify that the correct machine index was set.
    lda Zp_MachineIndex_u8
    ldy #kTestMachineIndex
    jsr Func_ExpectAEqualsY
    ;; Verify that Zp_Current_sMachine_ptr has been initialized.
    lda Zp_Current_sMachine_ptr + 1
    ldy #>Data_Machines_sMachine_arr::TestMachine
    jsr Func_ExpectAEqualsY
    lda Zp_Current_sMachine_ptr + 0
    ldy #<Data_Machines_sMachine_arr::TestMachine
    jsr Func_ExpectAEqualsY
    ;; Verify that Zp_Current_sProgram_ptr has been initialized.
    lda Zp_Current_sProgram_ptr + 1
    ldy #>Sram_Programs_sProgram_arr::TestProgram
    jsr Func_ExpectAEqualsY
    lda Zp_Current_sProgram_ptr + 0
    ldy #<Sram_Programs_sProgram_arr::TestProgram
    jsr Func_ExpectAEqualsY
InitMachine:
    ;; Initialize the machine.
    jsr Func_InitAllMachines
    ;; Verify that the PC starts at zero.
    lda Ram_MachinePc_u8_arr + kTestMachineIndex
    ldy #0
    jsr Func_ExpectAEqualsY
    ;; Verify that the machine is ready to run.
    lda Ram_MachineStatus_eMachine_arr + kTestMachineIndex
    ldy #eMachine::Running
    jsr Func_ExpectAEqualsY
    ;; Verify that the machine state was initialized.
    lda Zp_TestMachinePosX_u8
    ldy #1
    jsr Func_ExpectAEqualsY
    lda Zp_TestMachinePosY_u8
    ldy #1
    jsr Func_ExpectAEqualsY
    lda Zp_TestMachineActCounter_u8
    ldy #0
    jsr Func_ExpectAEqualsY
ExecuteInstructions:
    ;; Execute some instructions.
    lda #30
    sta Zp_TestCycleCount_u8
    @loop:
    jsr Func_MachineExecuteNext
    dec Zp_TestCycleCount_u8
    bne @loop
    ;; Verify that the machine is in the expected X/Y position.
    lda Zp_TestMachinePosX_u8
    ldy #6
    jsr Func_ExpectAEqualsY
    lda Zp_TestMachinePosY_u8
    ldy #4
    jsr Func_ExpectAEqualsY
    ;; Verify that the machine ACTed the expected number of times.
    lda Zp_TestMachineActCounter_u8
    ldy #3
    jsr Func_ExpectAEqualsY
    ;; Verify that the machine hit an END instruction.
    lda Ram_MachineStatus_eMachine_arr + kTestMachineIndex
    ldy #eMachine::Ended
    jsr Func_ExpectAEqualsY
    jmp Exit_Success

;;;=========================================================================;;;
