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
.INCLUDE "oam.inc"
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
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp_ptr
.IMPORTZP Zp_WindowNextRowToTransfer_u8
.IMPORTZP Zp_WindowTopGoal_u8
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

.LINECONT +
.DEFINE OpcodeLabels \
    _OpEmpty, _OpCopy, _OpSwap, _OpAdd, _OpSub, _OpMul, _OpGoto, _OpSkip, \
    _OpIf, _OpTil, _OpAct, _OpMove, _OpEnd, _OpEnd, _OpEnd, _OpNop
.LINECONT -

;;;=========================================================================;;;

;;; How many pixels of blank space we keep between the bottom of the console
;;; window border and the bottom of the screen.  This margin should be at least
;;; 12 pixels to avoid any of the console border being hidden by TV overscan
;;; (see https://wiki.nesdev.org/w/index.php/Overscan).  However, it must be
;;; less than 16 pixels in order to prevent the explore mode scroll-Y from
;;; leaving the upper nametable when the window is fully open and the player is
;;; at the bottom of a tall room.
kConsoleMarginBottomPx = 12

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

;;; The OBJ palette number used for the console cursor.
kCursorObjPalette = 0

;;;=========================================================================;;;

.ZEROPAGE

;;; The number of instruction rows in the console window (i.e. not including
;;; the borders or the bottom margin).
Zp_ConsoleNumInstRows_u8: .res 1

;;; The "current" instruction number within Ram_Console_sProgram.  While
;;; editing or debug stepping, this is the instruction highlighted by the
;;; cursor.  While drawing the console window, this is the instruction being
;;; drawn.
Zp_ConsoleInstNumber_u8: .res 1

;;; Which field within the current instruction is currently selected.
Zp_ConsoleFieldNumber_u8: .res 1

;;; The current "nominal" field offset (0-6 inclusive).  When moving the cursor
;;; left/right, this is set to the actual offset of the selected instruction
;;; field.  When moving the cursor up/down, this stays the same, and is used to
;;; choose whichever field in each instruction has roughly this offset.
Zp_ConsoleNominalFieldOffset_u8: .res 1

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
    ;; TODO: Get actual number of instructions from progress data
    lda #8
    sta Zp_ConsoleNumInstRows_u8
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
    ;; Calculate the window top goal from the number of instruction rows.
    lda Zp_ConsoleNumInstRows_u8
    mul #kTileHeightPx
    sta Zp_Tmp1_byte
    lda #kScreenHeightPx - (kTileHeightPx * 2 + kConsoleMarginBottomPx)
    sub Zp_Tmp1_byte
    sta Zp_WindowTopGoal_u8
_GameLoop:
    jsr Func_ExploreDrawAvatar
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_ScrollWindowUp:
    lda Zp_WindowTop_u8
    sub #kConsoleWindowScrollSpeed
    cmp Zp_WindowTopGoal_u8
    bge @notDone
    lda Zp_WindowTopGoal_u8
    @notDone:
    sta Zp_WindowTop_u8
    jsr Func_Window_SetUpIrq
    jsr Func_Console_TransferNextWindowRow
_CheckIfDone:
    lda Zp_WindowTop_u8
    cmp Zp_WindowTopGoal_u8
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
    ;; Initialize the cursor.
    lda #0
    sta Zp_ConsoleInstNumber_u8
    sta Zp_ConsoleFieldNumber_u8
    sta Zp_ConsoleNominalFieldOffset_u8
_GameLoop:
    jsr Func_Console_DrawCursorObjects
    jsr Func_ExploreDrawAvatar
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_CheckIfDone:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::BButton
    jne Main_Console_CloseWindow
.PROC _MoveCursorVertically
    ;; Store the max number of instructions in Zp_Tmp1_byte.
    lda Zp_ConsoleNumInstRows_u8
    asl a
    sta Zp_Tmp1_byte  ; max num instructions
_CheckDown:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Down
    beq _CheckUp
    ldx Zp_ConsoleInstNumber_u8
    ;; Check if the currently selection instruction is eOpcode::Empty; if so,
    ;; moving down from there wraps back to instruction number zero.
    txa
    mul #.sizeof(sInst)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, y
    and #$f0
    .assert eOpcode::Empty = 0, error
    beq @wrap
    ;; Increment the instruction number, but if that would exceed the max
    ;; number of instructions in the console window, then wrap back to zero.
    inx
    cpx Zp_Tmp1_byte  ; max num instructions
    blt @noWrap
    @wrap:
    ldx #0
    @noWrap:
    stx Zp_ConsoleInstNumber_u8
    jmp _FinishUpDown
_CheckUp:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Up
    beq _NoUpOrDown
    ;; If the current instruction number is nonzero, just decrement it.
    ldx Zp_ConsoleInstNumber_u8
    beq @loop
    dec Zp_ConsoleInstNumber_u8
    bpl _FinishUpDown  ; unconditional
    ;; Otherwise, search forward (starting from instruction zero) for the first
    ;; empty instruction.
    @loop:
    txa
    mul #.sizeof(sInst)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, y
    and #$f0
    ;; If this instruction is empty, select it.
    .assert eOpcode::Empty = 0, error
    beq @select
    ;; Otherwise, keep looking.  If there are no empty instructions, we'll
    ;; select the last instruction.
    inx
    cpx Zp_Tmp1_byte  ; max num instructions
    blt @loop
    dex
    @select:
    stx Zp_ConsoleInstNumber_u8
_FinishUpDown:
    jsr Func_Console_SetFieldForNominalOffset
_NoUpOrDown:
.ENDPROC
.PROC _MoveCursorHorizontally
    jsr Func_Console_GetCurrentInstNumFields  ; returns X
    stx Zp_Tmp1_byte  ; num fields
_CheckLeft:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Left
    beq _CheckRight
    ;; Decrement the field number; if we weren't at zero, we're done.
    ldx Zp_ConsoleFieldNumber_u8
    dex
    bpl @setFieldNumber
    ;; We're trying to move left from field zero.  If we're in the left-hand
    ;; column of instructions, then give up.
    lda Zp_ConsoleInstNumber_u8
    sub Zp_ConsoleNumInstRows_u8
    blt _NoLeftOrRight
    ;; Looks like we're in the right-hand column, so move to the last field of
    ;; the instruction on the same row in the left-hand column.
    sta Zp_ConsoleInstNumber_u8
    jsr Func_Console_GetCurrentInstNumFields  ; returns X
    dex
    @setFieldNumber:
    stx Zp_ConsoleFieldNumber_u8
    jmp _FinishLeftRight
_CheckRight:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Right
    beq _NoLeftOrRight
    ;; Increment the field number; if we weren't in the last field, we're done.
    ldx Zp_ConsoleFieldNumber_u8
    inx
    cpx Zp_Tmp1_byte  ; num fields
    blt @setFieldNumber
    ;; We're trying to move right from the last field.  If we're in the
    ;; right-hand column of instructions, then give up.
    lda Zp_ConsoleInstNumber_u8
    cmp Zp_ConsoleNumInstRows_u8
    bge _NoLeftOrRight
    ;; Looks like we're in the left-hand column, so move to the first field of
    ;; the instruction on the same row in the right-hand column.
    add Zp_ConsoleNumInstRows_u8
    sta Zp_ConsoleInstNumber_u8
    ;; If we're now beyond the first empty instruction, then undo what we just
    ;; did, and go back to the left-hand instruction column.
    jsr Func_IsPrevInstructionEmpty  ; returns Z
    bne @prevInstNotEmpty
    lda Zp_ConsoleInstNumber_u8
    sub Zp_ConsoleNumInstRows_u8
    sta Zp_ConsoleInstNumber_u8
    bpl _NoLeftOrRight  ; unconditional
    ;; Otherwise, now that we moved to the right-hand instruction column,
    ;; select the leftmost field.
    @prevInstNotEmpty:
    ldx #0
    @setFieldNumber:
    stx Zp_ConsoleFieldNumber_u8
_FinishLeftRight:
    jsr Func_Console_GetCurrentFieldOffset  ; returns A
    sta Zp_ConsoleNominalFieldOffset_u8
_NoLeftOrRight:
.ENDPROC
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    jsr Func_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;; Allocates and populates OAM slots for the console cursor.
.PROC Func_Console_DrawCursorObjects
    jsr Func_Console_GetCurrentFieldWidth
    sta Zp_Tmp3_byte
    jsr Func_Console_GetCurrentFieldOffset
    mul #kTileWidthPx
    sta Zp_Tmp2_byte
_YPosition:
    ;; Calculate the window row that the cursor is in.
    lda Zp_ConsoleInstNumber_u8
    cmp Zp_ConsoleNumInstRows_u8
    blt @leftColumn
    sub Zp_ConsoleNumInstRows_u8
    @leftColumn:
    add #1  ; add 1 for the top border
    ;; Calculate the Y-position of the objects and store in Zp_Tmp1_byte.
    mul #kTileHeightPx
    adc Zp_WindowTop_u8  ; carry will by clear
    adc #$ff  ; subtract 1 (carry will still be clear)
    sta Zp_Tmp1_byte  ; Y-position
_XPosition:
    lda #kTileWidthPx * 4
    add Zp_Tmp2_byte  ; current field offset
    ldx Zp_ConsoleInstNumber_u8
    cpx Zp_ConsoleNumInstRows_u8
    blt @leftColumn
    add #kTileWidthPx * 10
    @leftColumn:
    sta Zp_Tmp2_byte  ; X-position
_PrepareForLoop:
    ldx Zp_Tmp3_byte  ; cursor width - 1
    ldy Zp_OamOffset_u8
_ObjectLoop:
    ;; Set Y-position.
    lda Zp_Tmp1_byte  ; Y-position
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    ;; Set and increment X-position.
    lda Zp_Tmp2_byte  ; X-position
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    add #kTileWidthPx
    sta Zp_Tmp2_byte  ; X-position
    ;; Set flags.
    lda #bObj::Pri | kCursorObjPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    ;; Set tile ID.
    lda Zp_Tmp3_byte
    beq @tileSingle
    cpx Zp_Tmp3_byte
    beq @tileLeft
    txa
    beq @tileRight
    @tileMiddle:
    lda #$02
    bne @setTile  ; unconditional
    @tileRight:
    lda #$03
    bne @setTile  ; unconditional
    @tileLeft:
    lda #$01
    bne @setTile  ; unconditional
    @tileSingle:
    lda #$00
    @setTile:
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ;; Move offset to the next object.
    .repeat .sizeof(sObj)
    iny
    .endrepeat
    dex
    bpl _ObjectLoop
    sty Zp_OamOffset_u8
    rts
.ENDPROC

;;; Transfers the next console window row (if any) that still needs to be
;;; transferred to the PPU.
.PROC Func_Console_TransferNextWindowRow
    lda Zp_WindowNextRowToTransfer_u8
    sub #1
    cmp Zp_ConsoleNumInstRows_u8
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
    sta Zp_ConsoleInstNumber_u8
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
    lda Zp_ConsoleInstNumber_u8
    add Zp_ConsoleNumInstRows_u8
    sta Zp_ConsoleInstNumber_u8
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
;;; number Zp_ConsoleInstNumber_u8 within Ram_Console_sProgram.
;;; @param X PPU transfer array index within an entry's data.
;;; @return X Updated PPU transfer array index.
.PROC Func_Console_WriteInstTransferData
    jsr Func_IsPrevInstructionEmpty
    beq _Write7Spaces
    ;; Store the Arg_byte in Zp_Tmp2_byte.
    lda Zp_ConsoleInstNumber_u8
    mul #.sizeof(sInst)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Arg_byte, y
    sta Zp_Tmp2_byte
    ;; Store the Op_byte in Zp_Tmp1_byte.
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, y
    sta Zp_Tmp1_byte
    ;; Extract the opcode and jump to the correct label below.
    and #$f0
    div #$10
    tay
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
_Write7Spaces:
    jsr _Write3Spaces
    jmp _Write4Spaces
_JumpTable_ptr_0_arr: .lobytes OpcodeLabels
_JumpTable_ptr_1_arr: .hibytes OpcodeLabels
_OpEmpty:
    ldya #@string
    jsr _WriteString5
    jmp _Write2Spaces
    @string: .byte " ----"
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
    div #$10
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

;;; Returns the number of fields for the currently-selected instruction.
;;; @return X The number of fields.
.PROC Func_Console_GetCurrentInstNumFields
    jsr Func_Console_GetCurrentOpcode  ; returns A
    tay
    ldx _NumFields_u8_arr, y
    rts
_NumFields_u8_arr:
    .byte 1  ; Empty
    .byte 3  ; Copy
    .byte 3  ; Swap
    .byte 5  ; Add
    .byte 5  ; Sub
    .byte 5  ; Mul
    .byte 2  ; Goto
    .byte 2  ; Skip
    .byte 4  ; If
    .byte 4  ; Til
    .byte 1  ; Act
    .byte 2  ; Move
    .byte 1  ; unused opcode
    .byte 1  ; unused opcode
    .byte 1  ; End
    .byte 1  ; Nop
.ENDPROC

;;; Returns the width of the currently-selected instruction field, in tiles,
;;; minus one.
;;; @return A The width minus one.
.PROC Func_Console_GetCurrentFieldWidth
    jsr Func_Console_GetCurrentOpcode  ; returns A
    tay
    lda _FieldWidths_u8_arr_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _FieldWidths_u8_arr_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    ;; Look up the field width in that table.
    ldy Zp_ConsoleFieldNumber_u8
    lda (Zp_Tmp_ptr), y
    rts
_FieldWidths_u8_arr_ptr_0_arr: .lobytes OpcodeLabels
_FieldWidths_u8_arr_ptr_1_arr: .hibytes OpcodeLabels
_OpEmpty:
    .byte 5
_OpCopy:
    .byte 0, 0, 0
_OpSwap:
    .byte 0, 1, 0
_OpAdd:
_OpSub:
_OpMul:
    .byte 0, 0, 0, 0, 0
_OpGoto:
_OpSkip:
_OpMove:
    .byte 3, 0
_OpIf:
    .byte 1, 0, 0, 0
_OpTil:
    .byte 2, 0, 0, 0
_OpAct:
_OpEnd:
_OpNop:
    .byte 2
.ENDPROC

;;; Returns the horizontal offset of the currently-selected instruction field,
;;; in tiles.  This can range from 0-6 inclusive.
;;; @return A The field offset.
.PROC Func_Console_GetCurrentFieldOffset
    jsr Func_Console_GetCurrentOpcode  ; returns A
    tay
    lda _FieldOffsets_u8_arr_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _FieldOffsets_u8_arr_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    ;; Look up the field offset in that table.
    ldy Zp_ConsoleFieldNumber_u8
    lda (Zp_Tmp_ptr), y
    rts
_FieldOffsets_u8_arr_ptr_0_arr: .lobytes OpcodeLabels
_FieldOffsets_u8_arr_ptr_1_arr: .hibytes OpcodeLabels
_OpEmpty:
_OpAct:
_OpEnd:
_OpNop:
    .byte 0
_OpCopy:
    .byte 0, 1, 2
_OpSwap:
    .byte 0, 1, 3
_OpAdd:
_OpSub:
_OpMul:
    .byte 0, 1, 2, 3, 4
_OpGoto:
_OpSkip:
_OpMove:
    .byte 0, 5
_OpIf:
    .byte 0, 3, 4, 5
_OpTil:
    .byte 0, 4, 5, 6
.ENDPROC

;;; Sets Zp_ConsoleFieldNumber_u8 to whichever field in the current instruction
;;; best overlaps with Zp_ConsoleNominalFieldOffset_u8 (which must be in the
;;; range 0-6 inclusive).
.PROC Func_Console_SetFieldForNominalOffset
    jsr Func_Console_GetCurrentOpcode  ; returns A
    tay
    lda _FieldNumbers_u8_arr7_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _FieldNumbers_u8_arr7_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    ;; Look up the field number in that table.
    ldy Zp_ConsoleNominalFieldOffset_u8
    lda (Zp_Tmp_ptr), y
    sta Zp_ConsoleFieldNumber_u8
    rts
_FieldNumbers_u8_arr7_ptr_0_arr: .lobytes OpcodeLabels
_FieldNumbers_u8_arr7_ptr_1_arr: .hibytes OpcodeLabels
_OpEmpty:
_OpAct:
_OpEnd:
_OpNop:
    .byte 0, 0, 0, 0, 0, 0, 0
_OpCopy:
    .byte 0, 1, 2, 2, 2, 2, 2
_OpSwap:
    .byte 0, 1, 1, 2, 2, 2, 2
_OpAdd:
_OpSub:
_OpMul:
    .byte 0, 1, 2, 3, 4, 4, 4
_OpGoto:
_OpSkip:
_OpMove:
    .byte 0, 0, 0, 0, 1, 1, 1
_OpIf:
    .byte 0, 0, 1, 1, 2, 3, 3
_OpTil:
    .byte 0, 0, 0, 1, 1, 2, 3
.ENDPROC

;;; Returns the opcode for the currently-selected instruction.
;;; @return A The eOpcode value.
.PROC Func_Console_GetCurrentOpcode
    lda Zp_ConsoleInstNumber_u8
    mul #.sizeof(sInst)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, y
    and #$f0
    div #$10
    rts
.ENDPROC

;;; Determines if the current instruction number is beyond the first empty
;;; instruction in the program.
;;; @return Z Set if the previous instruction is empty; cleared if the previous
;;;     instruction is not empty (or if we're on the first instruction).
.PROC Func_IsPrevInstructionEmpty
    ldy Zp_ConsoleInstNumber_u8
    dey
    bmi @done
    tya
    mul #.sizeof(sInst)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, y
    and #$f0
    .assert eOpcode::Empty = 0, error
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
