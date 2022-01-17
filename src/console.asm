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
.INCLUDE "program.inc"
.INCLUDE "window.inc"

.IMPORT Func_ClearRestOfOam
.IMPORT Func_ExploreDrawAvatar
.IMPORT Func_ProcessFrame
.IMPORT Func_ScrollTowardsGoal
.IMPORT Func_SetScrollGoalFromAvatar
.IMPORT Func_UpdateButtons
.IMPORT Func_Window_PrepareRowTransfer
.IMPORT Func_Window_SetUpIrq
.IMPORT Func_Window_TransferBottomBorder
.IMPORT Func_Window_TransferClearRow
.IMPORT Main_Explore_Continue
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp_ptr
.IMPORTZP Zp_WindowNextRowToTransfer_u8
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; The number of rows in the console window, including the borders but not
;;; including the bottom margin.
;;; TODO: This should not be a constant.
kConsoleWindowNumRows = 10

;;; How many pixels of blank space we keep between the bottom of the console
;;; window border and the bottom of the screen.  This margin should be at least
;;; 12 pixels to avoid any of the console border being hidden by TV overscan
;;; (see https://wiki.nesdev.org/w/index.php/Overscan).  However, it must be
;;; less than 16 pixels in order to prevent the explore mode scroll-Y from
;;; leaving the upper nametable when the window is fully open and the player is
;;; at the bottom of a tall room.
kConsoleMarginBottomPx = 12

;;; The top position of the console window when fully open.
;;; TODO: This should not be a constant.
.LINECONT +
kConsoleWindowTop = kScreenHeightPx - \
    (kTileHeightPx * kConsoleWindowNumRows + kConsoleMarginBottomPx)
.LINECONT -

;;; How fast the console window scrolls up/down, in pixels per frame.
kConsoleWindowScrollSpeed = 6

;;; Tile IDs for drawing the contents of the console window.
kConsoleTileIdArrowFirst = $5a
kConsoleTileIdArrowLeft  = $5c
kConsoleTileIdArrowRight = $5d
kConsoleTileIdCmpFirst   = $09
kConsoleTileIdColon      = $04
kConsoleTileIdDigitZero  = $10
kConsoleTileIdMinus      = $08
kConsoleTileIdPlus       = $07
kConsoleTileIdTimes      = $57

;;;=========================================================================;;;

.ZEROPAGE

;;; The "current" instruction number within Ram_Console_sProgram.  While
;;; editing or debug stepping, this is the instruction highlighted by the
;;; cursor.  While drawing the console window, this is the instruction being
;;; drawn.
Zp_Console_InstNumber_u4: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Console"

;;; A copy of the program that is being edited in the console.  This gets
;;; populated from SRAM, and will be copied back out to SRAM when done editing.
Ram_Console_sProgram: .tag sProgram

;;;=========================================================================;;;

.SEGMENT "PRG8_Console"

;;; Mode for scrolling in the console window.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.EXPORT Main_Console_OpenWindow
.PROC Main_Console_OpenWindow
    ;; TODO: Load the correct program from SRAM
    ldax #$1a07
    stax Ram_Console_sProgram + $00
    ldax #$2a0b
    stax Ram_Console_sProgram + $02
    ldax #$3ab1
    stax Ram_Console_sProgram + $04
    ldax #$4a1b
    stax Ram_Console_sProgram + $06
    ldax #$5ab2
    stax Ram_Console_sProgram + $08
    ldax #$6200
    stax Ram_Console_sProgram + $0a
    ldax #$7a00
    stax Ram_Console_sProgram + $0c
    ldax #$82a1
    stax Ram_Console_sProgram + $0e
    ldax #$936a
    stax Ram_Console_sProgram + $10
    ldax #$a000
    stax Ram_Console_sProgram + $12
    ldax #$b100
    stax Ram_Console_sProgram + $14
    ldax #$e000
    stax Ram_Console_sProgram + $16
    ldax #$f000
    stax Ram_Console_sProgram + $18
    ldax #$0000
    stax Ram_Console_sProgram + $1a
_InitWindow:
    lda #kScreenHeightPx - kConsoleWindowScrollSpeed
    sta Zp_WindowTop_u8
    jsr Func_Window_SetUpIrq
    lda #1
    sta Zp_WindowNextRowToTransfer_u8
_GameLoop:
    jsr Func_ExploreDrawAvatar
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_ScrollWindowUp:
    lda Zp_WindowTop_u8
    sub #kConsoleWindowScrollSpeed
    cmp #kConsoleWindowTop
    bge @notDone
    lda #kConsoleWindowTop
    @notDone:
    sta Zp_WindowTop_u8
    jsr Func_Window_SetUpIrq
    jsr Func_Console_TransferNextWindowRow
_CheckIfDone:
    lda Zp_WindowTop_u8
    cmp #kConsoleWindowTop
    jeq Main_Console_Edit
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    jsr Func_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;; Mode for scrolling out the console window.  Switches to explore mode once
;;; the window is fully hidden.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Console_CloseWindow
_GameLoop:
    jsr Func_ExploreDrawAvatar
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_ScrollWindowDown:
    lda Zp_WindowTop_u8
    add #kConsoleWindowScrollSpeed
    cmp #kScreenHeightPx
    blt @notDone
    lda #$ff
    @notDone:
    sta Zp_WindowTop_u8
    jsr Func_Window_SetUpIrq
_CheckIfDone:
    lda Zp_WindowTop_u8
    cmp #$ff
    jeq Main_Explore_Continue
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    jsr Func_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;; Mode for editing a program in the console window.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
.PROC Main_Console_Edit
    ;; TODO: initialize the cursor
_GameLoop:
    jsr Func_ExploreDrawAvatar
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_CheckIfDone:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::BButton
    jne Main_Console_CloseWindow
_MoveCursor:
    ;; TODO: implement moving the cursor
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    jsr Func_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;; Transfers the next console window row (if any) that still needs to be
;;; transferred to the PPU.
.PROC Func_Console_TransferNextWindowRow
    lda Zp_WindowNextRowToTransfer_u8
    cmp #kConsoleWindowNumRows - 1
    blt _Interior
    beq _BottomBorder
_BottomMargin:
    cmp #kWindowMaxNumRows
    blt @clear
    rts
    @clear:
    jmp Func_Window_TransferClearRow
_BottomBorder:
    jmp Func_Window_TransferBottomBorder
_Interior:
    jsr Func_Window_PrepareRowTransfer
    ;; Draw margins, borders, and column separators:
    lda #kWindowTileIdBlank
    sta Ram_PpuTransfer_arr, x
    sta Ram_PpuTransfer_arr + kScreenWidthTiles - 1, x
    lda #kWindowTileIdVert
    sta Ram_PpuTransfer_arr + 1, x
    sta Ram_PpuTransfer_arr + 11, x
    sta Ram_PpuTransfer_arr + 21, x
    sta Ram_PpuTransfer_arr + kScreenWidthTiles - 2, x
    inx
    inx
    ;; Calculate the instruction number for the left column.
    lda Zp_WindowNextRowToTransfer_u8
    sub #2
    sta Zp_Console_InstNumber_u4
    ;; Draw the instruction for the left column.
    add #kConsoleTileIdDigitZero
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kConsoleTileIdColon
    sta Ram_PpuTransfer_arr, x
    inx
    jsr Func_Console_WriteInstTransferData
    inx
    ;; Calculate the instruction number for the right column.
    lda Zp_Console_InstNumber_u4
    add #kConsoleWindowNumRows - 2
    sta Zp_Console_InstNumber_u4
    ;; Draw the instruction for the right column.
    add #kConsoleTileIdDigitZero
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kConsoleTileIdColon
    sta Ram_PpuTransfer_arr, x
    inx
    jsr Func_Console_WriteInstTransferData
    inx
    ;; Draw the status box.
    ;; TODO: Make a real implementation for drawing the status box.
    lda #kWindowTileIdBlank
    ldy #8
    @loop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @loop
    lda #kWindowTileIdVert
    sta Ram_PpuTransfer_arr, x
    rts
.ENDPROC

;;; Writes seven bytes into a PPU transfer entry with the text of instruction
;;; number Zp_Console_InstNumber_u4 within Ram_Console_sProgram.
;;; @param X PPU transfer array index within an entry's data.
;;; @return X Updated PPU transfer array index.
.PROC Func_Console_WriteInstTransferData
    ;; Store the Arg_byte in Zp_Tmp2_byte.
    lda Zp_Console_InstNumber_u4
    asl a
    tay
    .assert sInst::Arg_byte = 0, error
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr, y
    sta Zp_Tmp2_byte
    ;; Store the Op_byte in Zp_Tmp1_byte.
    iny
    .assert sInst::Op_byte = 1, error
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr, y
    sta Zp_Tmp1_byte
    ;; Extract the opcode and jump to the correct label below.
    and #$f0
    lsr a
    lsr a
    lsr a
    tay
    lda _JumpTable, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable + 1, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
_JumpTable:
    .addr _OpEmpty
    .addr _OpCopy
    .addr _OpSwap
    .addr _OpAdd
    .addr _OpSub
    .addr _OpMul
    .addr _OpGoto
    .addr _OpSkip
    .addr _OpIf
    .addr _OpTil
    .addr _OpAct
    .addr _OpMove
    .addr _OpEnd  ; unused opcode
    .addr _OpEnd  ; unused opcode
    .addr _OpEnd
    .addr _OpNop
_OpEmpty:
    ldya #@string
    jsr _WriteString5
    jmp _Write2Spaces
    @string: .byte " --- "
_OpCopy:
    lda Zp_Tmp1_byte
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteArrowLeft
    lda Zp_Tmp2_byte
    jsr _WriteLowRegisterOrImmediate
    jmp _Write4Spaces
_OpSwap:
    lda Zp_Tmp1_byte
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteArrowLeft
    lda #kConsoleTileIdArrowRight
    sta Ram_PpuTransfer_arr, x
    inx
    lda Zp_Tmp2_byte
    jsr _WriteLowRegisterOrImmediate
    jmp _Write3Spaces
_OpAdd:
    lda #kConsoleTileIdPlus
    jmp _WriteBinop
_OpSub:
    lda #kConsoleTileIdMinus
    jmp _WriteBinop
_OpMul:
    lda #kConsoleTileIdTimes
    jmp _WriteBinop
_OpGoto:
    ldya #@string
    jsr _WriteString5
    lda Zp_Tmp1_byte
    and #$0f
    add #kConsoleTileIdDigitZero
    sta Ram_PpuTransfer_arr, x
    inx
    jmp _Write1Space
    @string: .byte "GOTO "
_OpSkip:
    ldya #@string
    jsr _WriteString5
    lda Zp_Tmp1_byte
    jsr _WriteLowRegisterOrImmediate
    jmp _Write1Space
    @string: .byte "SKIP "
_OpIf:
    ldya #@string
    jsr _WriteString3
    lda Zp_Tmp2_byte
    jsr _WriteHighRegisterOrImmediate
    jsr _WriteComparisonOperator
    lda Zp_Tmp2_byte
    jsr _WriteLowRegisterOrImmediate
    jmp _Write1Space
    @string: .byte "IF "
_OpTil:
    ldya #@string
    jsr _WriteString3
    jsr _Write1Space
    lda Zp_Tmp2_byte
    jsr _WriteHighRegisterOrImmediate
    jsr _WriteComparisonOperator
    lda Zp_Tmp2_byte
    jmp _WriteLowRegisterOrImmediate
    @string: .byte "TIL"
_OpAct:
    ldya #@string
    jsr _WriteString3
    jmp _Write4Spaces
    @string: .byte "ACT"
_OpMove:
    ldya #@string
    jsr _WriteString5
    lda Zp_Tmp1_byte
    and #$0f
    add #kConsoleTileIdArrowFirst
    sta Ram_PpuTransfer_arr, x
    inx
    jmp _Write1Space
    @string: .byte "MOVE "
_OpEnd:
    ldya #@string
    jsr _WriteString3
    jmp _Write4Spaces
    @string: .byte "END"
_OpNop:
    ldya #@string
    jsr _WriteString3
    jmp _Write4Spaces
    @string: .byte "NOP"
_WriteString3:
    stya Zp_Tmp_ptr
    ldy #0
    @loop:
    lda (Zp_Tmp_ptr), y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #3
    bne @loop
    rts
_WriteString5:
    stya Zp_Tmp_ptr
    ldy #0
    @loop:
    lda (Zp_Tmp_ptr), y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #5
    bne @loop
    rts
_WriteBinop:
    pha
    lda Zp_Tmp1_byte
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteArrowLeft
    lda Zp_Tmp2_byte
    jsr _WriteHighRegisterOrImmediate
    pla
    sta Ram_PpuTransfer_arr, x
    inx
    lda Zp_Tmp2_byte
    jsr _WriteLowRegisterOrImmediate
    jmp _Write2Spaces
_Write4Spaces:
    lda #kWindowTileIdBlank
    sta Ram_PpuTransfer_arr, x
    inx
_Write3Spaces:
    lda #kWindowTileIdBlank
    sta Ram_PpuTransfer_arr, x
    inx
_Write2Spaces:
    lda #kWindowTileIdBlank
    sta Ram_PpuTransfer_arr, x
    inx
_Write1Space:
    lda #kWindowTileIdBlank
    sta Ram_PpuTransfer_arr, x
    inx
    rts
_WriteArrowLeft:
    lda #kConsoleTileIdArrowLeft
    sta Ram_PpuTransfer_arr, x
    inx
    rts
_WriteHighRegisterOrImmediate:
    .repeat 4
    lsr a
    .endrepeat
_WriteLowRegisterOrImmediate:
    and #$0f
    cmp #$0a
    bge @register
    add #kConsoleTileIdDigitZero
    bne @write  ; unconditional
    @register:
    add #$16  ; TODO: Determine correct register name.
    @write:
    sta Ram_PpuTransfer_arr, x
    inx
    rts
_WriteComparisonOperator:
    lda Zp_Tmp1_byte
    and #$0f
    add #kConsoleTileIdCmpFirst
    sta Ram_PpuTransfer_arr, x
    inx
    rts
.ENDPROC

;;;=========================================================================;;;
