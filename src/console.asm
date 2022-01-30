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
.INCLUDE "console.inc"
.INCLUDE "joypad.inc"
.INCLUDE "machine.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "program.inc"
.INCLUDE "window.inc"

.IMPORT FuncA_Console_GetCurrentFieldOffset
.IMPORT FuncA_Console_GetCurrentFieldWidth
.IMPORT FuncA_Console_GetCurrentInstNumFields
.IMPORT FuncA_Console_SetFieldForNominalOffset
.IMPORT Func_ClearRestOfOam
.IMPORT Func_DrawObjectsForRoom
.IMPORT Func_Menu_EditSelectedField
.IMPORT Func_ProcessFrame
.IMPORT Func_ScrollTowardsGoal
.IMPORT Func_SetScrollGoalFromAvatar
.IMPORT Func_UpdateButtons
.IMPORT Func_Window_GetRowPpuAddr
.IMPORT Func_Window_PrepareRowTransfer
.IMPORT Func_Window_SetUpIrq
.IMPORT Func_Window_TransferBottomBorder
.IMPORT Func_Window_TransferClearRow
.IMPORT Main_Explore_Continue
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PpuTransfer_arr
.IMPORT Sram_Programs_sProgram_arr
.IMPORTZP Zp_Machines_sMachine_arr_ptr
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuTransferLen_u8
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

;;; BG tile IDs for drawing the contents of the console window.
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

;;; The width of an instruction in the console, in tiles.
kInstructionWidthTiles = 7

;;;=========================================================================;;;

.ZEROPAGE

;;; The index of the machine that the console is controlling.
Zp_ConsoleMachineIndex_u8: .res 1

;;; A pointer to the static data for the machine the console is controlling.
.EXPORTZP Zp_Console_sMachine_ptr
Zp_Console_sMachine_ptr: .res 2

;;; The number of instruction rows in the console window (i.e. not including
;;; the borders or the bottom margin).
.EXPORTZP Zp_ConsoleNumInstRows_u8
Zp_ConsoleNumInstRows_u8: .res 1

;;; The "current" instruction number within Ram_Console_sProgram.  While
;;; editing or debug stepping, this is the instruction highlighted by the
;;; cursor.  While drawing the console window, this is the instruction being
;;; drawn.
.EXPORTZP Zp_ConsoleInstNumber_u8
Zp_ConsoleInstNumber_u8: .res 1

;;; Which field within the current instruction is currently selected.
.EXPORTZP Zp_ConsoleFieldNumber_u8
Zp_ConsoleFieldNumber_u8: .res 1

;;; The current "nominal" field offset (0-6 inclusive).  When moving the cursor
;;; left/right, this is set to the actual offset of the selected instruction
;;; field.  When moving the cursor up/down, this stays the same, and is used to
;;; choose whichever field in each instruction has roughly this offset.
.EXPORTZP Zp_ConsoleNominalFieldOffset_u8
Zp_ConsoleNominalFieldOffset_u8: .res 1

;;; If set to true ($ff), the console instruction cursor will be drawn
;;; "diminished", making it less visually prominent.
Zp_ConsoleCursorIsDiminished_bool: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Console"

;;; A copy of the program that is being edited in the console.  This gets
;;; populated from SRAM, and will be copied back out to SRAM when done editing.
.EXPORT Ram_Console_sProgram
Ram_Console_sProgram: .tag sProgram

;;;=========================================================================;;;

.SEGMENT "PRG8_Console"

;;; Mode for scrolling in the console window.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @param A The machine index to open a console for.
.EXPORT Main_Console_OpenWindow
.PROC Main_Console_OpenWindow
    sta Zp_ConsoleMachineIndex_u8
    prga_bank #<.bank(FuncA_Console_LoadProgram)
    jsr FuncA_Console_LoadProgram
    ;; TODO: Get actual number of instructions from progress data
    lda #8
    sta Zp_ConsoleNumInstRows_u8
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
    jsr Func_DrawObjectsForRoom
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
    prga_bank #<.bank(FuncA_Console_TransferNextWindowRow)
    jsr FuncA_Console_TransferNextWindowRow
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
    jsr Func_DrawObjectsForRoom
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
    sta Zp_ConsoleCursorIsDiminished_bool
_GameLoop:
    prga_bank #<.bank(FuncA_Console_DrawFieldCursorObjects)
    jsr FuncA_Console_DrawFieldCursorObjects
    jsr Func_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_CheckButtons:
    prga_bank #<.bank(FuncA_Console_SaveProgram)
    ;; B button:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::BButton
    beq @noClose
    jsr FuncA_Console_SaveProgram
    jmp Main_Console_CloseWindow
    @noClose:
    ;; Select button:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Select
    beq @noInsert
    jsr FuncA_Console_InsertInstruction
    @noInsert:
    ;; A button:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::AButton
    beq @noEdit
    lda #$ff
    sta Zp_ConsoleCursorIsDiminished_bool
    jsr Func_Menu_EditSelectedField
    lda #$00
    sta Zp_ConsoleCursorIsDiminished_bool
    @noEdit:
    ;; D-pad:
    jsr FuncA_Console_MoveFieldCursor
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    jsr Func_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; Returns a pointer to the SRAM program for the current machine.
;;; @prereq Zp_Console_sMachine_ptr has been initialized.
;;; @return Zp_Tmp_ptr A pointer to the sProgram in SRAM.
.PROC FuncA_Console_GetSramProgramPtr
    ;; Store the machine's program number in A.
    ldy #sMachine::Code_eProgram
    lda (Zp_Machines_sMachine_arr_ptr), y
    ;; Calculate the 16-bit byte offset into Sram_Programs_sProgram_arr,
    ;; putting the lo byte in A and the hi byte in Zp_Tmp1_byte.
    .assert sMachine::Code_eProgram = 0, error
    sty Zp_Tmp1_byte  ; Y is currently zero
    .repeat .sizeof(sProgram)
    asl a
    rol Zp_Tmp1_byte
    .endrepeat
    ;; Calculate a pointer to the start of the sProgram in SRAM and store it in
    ;; Zp_Tmp_ptr.
    add #<Sram_Programs_sProgram_arr
    sta Zp_Tmp_ptr + 0
    lda Zp_Tmp1_byte
    adc #>Sram_Programs_sProgram_arr
    sta Zp_Tmp_ptr + 1
    rts
.ENDPROC

;;; Initializes Zp_Console_sMachine_ptr and Ram_Console_sProgram for the
;;; current machine.
;;; @prereq Zp_ConsoleMachineIndex_u8 has been initialized.
.PROC FuncA_Console_LoadProgram
    ;; Initialize Zp_Console_sMachine_ptr.
    lda Zp_ConsoleMachineIndex_u8
    .assert .sizeof(sMachine) * kMaxMachines <= $100, error
    mul #.sizeof(sMachine)
    add Zp_Machines_sMachine_arr_ptr + 0
    sta Zp_Console_sMachine_ptr + 0
    lda Zp_Machines_sMachine_arr_ptr + 1
    adc #0
    sta Zp_Console_sMachine_ptr + 1
    ;; Initialize Ram_Console_sProgram from SRAM.
    jsr FuncA_Console_GetSramProgramPtr  ; returns Zp_Tmp_ptr
    ldy #.sizeof(sProgram) - 1
    @loop:
    lda (Zp_Tmp_ptr), y
    sta Ram_Console_sProgram, y
    dey
    bpl @loop
    rts
.ENDPROC

;;; Saves Ram_Console_sProgram back to SRAM.
;;; @prereq Zp_Console_sMachine_ptr has been initialized.
.PROC FuncA_Console_SaveProgram
    jsr FuncA_Console_GetSramProgramPtr  ; returns Zp_Tmp_ptr
    ;; Enable writes to SRAM.
    lda #bMmc3PrgRam::Enable
    sta Hw_Mmc3PrgRamProtect_wo
    ;; Copy Ram_Console_sProgram back to SRAM.
    ldy #.sizeof(sProgram) - 1
    @loop:
    lda Ram_Console_sProgram, y
    sta (Zp_Tmp_ptr), y
    dey
    bpl @loop
    ;; Disable writes to SRAM.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
    rts
.ENDPROC

;;; Moves the console field cursor based on the current joypad state.
.PROC FuncA_Console_MoveFieldCursor
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
    jsr FuncA_Console_SetFieldForNominalOffset
_NoUpOrDown:
.ENDPROC
.PROC _MoveCursorHorizontally
    jsr FuncA_Console_GetCurrentInstNumFields  ; returns X
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
    jsr FuncA_Console_GetCurrentInstNumFields  ; returns X
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
    jsr FuncA_IsPrevInstructionEmpty  ; returns Z
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
    jsr FuncA_Console_GetCurrentFieldOffset  ; returns A
    sta Zp_ConsoleNominalFieldOffset_u8
_NoLeftOrRight:
.ENDPROC
    rts
.ENDPROC

.PROC FuncA_Console_InsertInstruction
    ;; TODO: If there's no room to insert an instruction, bail.
    ;; TODO: Insert a new Empty instruction above the current one (updating any
    ;;   GOTO instruction addresses as needed), and set current
    ;;   instruction/field/column to point to the new Empty instruction.
    ;; TODO: Redraw all instructions in the console (over a couple of frames).
    ;; TODO: Switch to menu mode for the current field (which will be the
    ;;   opcode field of the new Empty instruction).
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the console instruction field cursor.
.EXPORT FuncA_Console_DrawFieldCursorObjects
.PROC FuncA_Console_DrawFieldCursorObjects
    jsr FuncA_Console_GetCurrentFieldWidth
    sta Zp_Tmp3_byte
    jsr FuncA_Console_GetCurrentFieldOffset
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
    lda Zp_ConsoleCursorIsDiminished_bool
    bpl @undiminished
    lda Zp_Tmp3_byte
    beq @dimSingle
    cpx Zp_Tmp3_byte
    beq @dimLeft
    txa
    bne @continue
    @dimRight:
    lda #kConsoleObjTileIdCursorDimRight
    bne @setTile  ; unconditional
    @dimLeft:
    lda #kConsoleObjTileIdCursorDimLeft
    bne @setTile  ; unconditional
    @dimSingle:
    lda #kConsoleObjTileIdCursorDimSingle
    bne @setTile  ; unconditional
    @undiminished:
    lda Zp_Tmp3_byte
    beq @tileSingle
    cpx Zp_Tmp3_byte
    beq @tileLeft
    txa
    beq @tileRight
    @tileMiddle:
    lda #kConsoleObjTileIdCursorSolidMiddle
    bne @setTile  ; unconditional
    @tileRight:
    lda #kConsoleObjTileIdCursorSolidRight
    bne @setTile  ; unconditional
    @tileLeft:
    lda #kConsoleObjTileIdCursorSolidLeft
    bne @setTile  ; unconditional
    @tileSingle:
    lda #kConsoleObjTileIdCursorSolidSingle
    @setTile:
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ;; Move offset to the next object.
    .repeat .sizeof(sObj)
    iny
    .endrepeat
    @continue:
    dex
    bpl _ObjectLoop
    sty Zp_OamOffset_u8
    rts
.ENDPROC

;;; Transfers the next console window row (if any) that still needs to be
;;; transferred to the PPU.
.PROC FuncA_Console_TransferNextWindowRow
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
    jsr FuncA_Console_WriteInstTransferData
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
    jsr FuncA_Console_WriteInstTransferData
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

;;; Appends a PPU transfer entry to redraw the current instruction.
.EXPORT FuncA_Console_TransferInstruction
.PROC FuncA_Console_TransferInstruction
    ;; Get the transfer destination address, and store it in Zp_Tmp1_byte (lo)
    ;; and Zp_Tmp2_byte (hi).
    lda Zp_ConsoleInstNumber_u8
    cmp Zp_ConsoleNumInstRows_u8
    blt @leftColumn
    sub Zp_ConsoleNumInstRows_u8
    @leftColumn:
    add #1  ; add 1 for the top border
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    sty Zp_Tmp1_byte
    lda #14
    ldy Zp_ConsoleInstNumber_u8
    cpy Zp_ConsoleNumInstRows_u8
    bge @rightColumn
    lda #4
    @rightColumn:
    add Zp_Tmp1_byte
    sta Zp_Tmp1_byte  ; transfer destination (lo)
    txa
    adc #0
    sta Zp_Tmp2_byte  ; transfer destination (hi)
    ;; Update Zp_PpuTransferLen_u8.
    ldx Zp_PpuTransferLen_u8
    txa
    add #4 + kInstructionWidthTiles
    sta Zp_PpuTransferLen_u8
    ;; Write the transfer entry header.
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr, x
    inx
    lda Zp_Tmp2_byte  ; transfer destination (hi)
    sta Ram_PpuTransfer_arr, x
    inx
    lda Zp_Tmp1_byte  ; transfer destination (lo)
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kInstructionWidthTiles
    sta Ram_PpuTransfer_arr, x
    inx
    .assert * = FuncA_Console_WriteInstTransferData, error, "fallthrough"
.ENDPROC

;;; Writes seven bytes into a PPU transfer entry with the text of instruction
;;; number Zp_ConsoleInstNumber_u8 within Ram_Console_sProgram.
;;; @prereq Zp_Console_sMachine_ptr is initialized.
;;; @param X PPU transfer array index within an entry's data.
;;; @return X Updated PPU transfer array index.
.PROC FuncA_Console_WriteInstTransferData
    jsr FuncA_IsPrevInstructionEmpty
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
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteComparisonOperator
    lda Zp_Tmp2_byte
    jsr _WriteHighRegisterOrImmediate
    jmp _Write1Space
    @string: .byte "IF "
_OpTil:
    ldya #@string
    jsr _WriteString3
    jsr _Write1Space
    lda Zp_Tmp2_byte
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteComparisonOperator
    lda Zp_Tmp2_byte
    jmp _WriteHighRegisterOrImmediate
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
    jsr _WriteLowRegisterOrImmediate
    pla
    sta Ram_PpuTransfer_arr, x
    inx
    lda Zp_Tmp2_byte
    jsr _WriteHighRegisterOrImmediate
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
    cmp #$0a  ; immediate values are 0-9; registers are $a-$f
    bge @register
    add #kConsoleTileIdDigitZero  ; Get tile ID for immediate value (0-9).
    bne @write  ; unconditional
    @register:                             ; This is a register ($a-$f), so
    sub #$0a - sMachine::RegNames_u8_arr6  ; subtract $a to get the index into
    tay                                    ; RegNames, and add RegNames_u8_arr6
    lda (Zp_Console_sMachine_ptr), y       ; to get offset into sMachine.
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

;;; Determines if the current instruction number is beyond the first empty
;;; instruction in the program.
;;; @return Z Set if the previous instruction is empty; cleared if the previous
;;;     instruction is not empty (or if we're on the first instruction).
.PROC FuncA_IsPrevInstructionEmpty
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
