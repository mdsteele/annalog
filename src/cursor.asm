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

.INCLUDE "cursor.inc"
.INCLUDE "joypad.inc"
.INCLUDE "machine.inc"
.INCLUDE "macros.inc"
.INCLUDE "menu.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "program.inc"

.IMPORT FuncA_Console_GetCurrentFieldOffset
.IMPORT FuncA_Console_GetCurrentFieldWidth
.IMPORT FuncA_Console_GetCurrentInstNumFields
.IMPORT FuncA_Console_IsPrevInstructionEmpty
.IMPORT FuncA_Console_SetFieldForNominalOffset
.IMPORT FuncA_Console_UpdateMenuNominalCol
.IMPORT Func_AllocObjects
.IMPORT Func_AllocOneObject
.IMPORT Func_PlaySfxMenuMove
.IMPORT Ram_Console_sProgram
.IMPORT Ram_MachinePc_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_MenuCols_u8_arr
.IMPORT Ram_MenuRows_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_ConsoleFieldNumber_u8
.IMPORTZP Zp_ConsoleInstNumber_u8
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_ConsoleNominalFieldOffset_u8
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_Current_sMenu_ptr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_MachineMaxInstructions_u8
.IMPORTZP Zp_MenuItem_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; Moves the console field cursor based on the current joypad state.
.EXPORT FuncA_Console_MoveFieldCursor
.PROC FuncA_Console_MoveFieldCursor
.PROC _MoveCursorVertically
    lda Zp_ConsoleInstNumber_u8
    sta T0  ; old instruction number
_CheckDown:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Down
    beq _CheckUp
    ldx Zp_ConsoleInstNumber_u8
    ;; Check if the currently selection instruction is eOpcode::Empty; if so,
    ;; moving down from there wraps back to instruction number zero.
    txa
    mul #.sizeof(sIns)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, y
    and #$f0
    .assert eOpcode::Empty = 0, error
    beq @wrap
    ;; Increment the instruction number, but if that would exceed the max
    ;; number of instructions in the console window, then wrap back to zero.
    inx
    cpx Zp_MachineMaxInstructions_u8
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
    mul #.sizeof(sIns)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, y
    and #$f0
    ;; If this instruction is empty, select it.
    .assert eOpcode::Empty = 0, error
    beq @select
    ;; Otherwise, keep looking.  If there are no empty instructions, we'll
    ;; select the last instruction.
    inx
    cpx Zp_MachineMaxInstructions_u8
    blt @loop
    dex
    @select:
    stx Zp_ConsoleInstNumber_u8
_FinishUpDown:
    ;; Check if the cursor actually moved vertically; if so, play a sound and
    ;; set the field number from the nominal field offset.
    lda Zp_ConsoleInstNumber_u8
    cmp T0  ; old instruction number
    beq _NoUpOrDown  ; cursor didn't actually move
    jsr Func_PlaySfxMenuMove
    jsr FuncA_Console_SetFieldForNominalOffset
_NoUpOrDown:
.ENDPROC
.PROC _MoveCursorHorizontally
    lda Zp_ConsoleInstNumber_u8
    sta T2  ; old instruction number
    lda Zp_ConsoleFieldNumber_u8
    sta T1  ; old field number
    jsr FuncA_Console_GetCurrentInstNumFields  ; preserves T0+, returns X
    stx T0  ; num fields
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
    jsr FuncA_Console_GetCurrentInstNumFields  ; preserves T0+ returns X
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
    cpx T0  ; num fields
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
    jsr FuncA_Console_IsPrevInstructionEmpty  ; preserves T0+, returns Z
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
    ;; Check if the cursor actually moved horizontally; if so, play a sound and
    ;; set the nominal field offset from the actual field offset.
    lda Zp_ConsoleFieldNumber_u8
    cmp T1  ; old field number
    bne @didMove
    lda Zp_ConsoleInstNumber_u8
    cmp T2  ; old instruction number
    beq _NoLeftOrRight  ; didn't move
    @didMove:
    jsr Func_PlaySfxMenuMove
    jsr FuncA_Console_GetCurrentFieldOffset  ; returns A
    sta Zp_ConsoleNominalFieldOffset_u8
_NoLeftOrRight:
.ENDPROC
    rts
.ENDPROC

;;; Moves the console menu cursor (updating Zp_MenuItem_u8 appropriately) based
;;; on the current joypad state.
.EXPORT FuncA_Console_MoveMenuCursor
.PROC FuncA_Console_MoveMenuCursor
    lda Zp_MenuItem_u8
    pha  ; prev menu item
_MoveCursorUp:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Up
    beq @noUp
    ldy #sMenu::OnUp_func_ptr
    jsr _MenuFunc
    @noUp:
_MoveCursorDown:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Down
    beq @noDown
    ldy #sMenu::OnDown_func_ptr
    jsr _MenuFunc
    @noDown:
_MoveCursorLeft:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Left
    beq @noLeft
    ldy #sMenu::OnLeft_func_ptr
    jsr _MenuFunc
    jsr FuncA_Console_UpdateMenuNominalCol
    @noLeft:
_MoveCursorRight:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Right
    beq @noRight
    ldy #sMenu::OnRight_func_ptr
    jsr _MenuFunc
    jsr FuncA_Console_UpdateMenuNominalCol
    @noRight:
_CheckIfMoved:
    pla  ; prev menu item
    cmp Zp_MenuItem_u8
    beq @done  ; menu item didn't change
    jsr Func_PlaySfxMenuMove
    @done:
    rts
_MenuFunc:
    lda (Zp_Current_sMenu_ptr), y
    sta T0
    iny
    lda (Zp_Current_sMenu_ptr), y
    sta T1
    jmp (T1T0)
.ENDPROC

;;; Draws the console menu cursor and the diminished console field cursor.
.EXPORT FuncA_Console_DrawMenuCursor
.PROC FuncA_Console_DrawMenuCursor
    ldx Zp_MenuItem_u8
_XPosition:
    lda Ram_MenuCols_u8_arr, x
    mul #kTileWidthPx
    add #kMenuStartTileColumn * kTileWidthPx
    sta T1  ; cursor left X-position, in pixels
_CursorWidth:
    txa
    add #sMenu::WidthsMinusOne_u8_arr
    tay
    lda (Zp_Current_sMenu_ptr), y
    sta T2  ; cursor (width - 1), in tiles
_YPosition:
    ;; Calculate the window row that the cursor is in.
    lda Ram_MenuRows_u8_arr, x
    add #kMenuStartWindowRow
    ;; Calculate the Y-position of the objects and store in T0.
    mul #kTileHeightPx
    adc Zp_WindowTop_u8  ; carry will by clear
    adc #$ff  ; subtract 1 (carry will still be clear)
    sta T0  ; cursor Y-position, in pixels
_DrawCursors:
    jsr FuncA_Console_DrawFullCursor
    lda #$ff  ; param: cursor diminished bool ($ff = diminished)
    bne FuncA_Console_DrawFieldCursorFullOrDim  ; unconditional
.ENDPROC

;;; Draws the console instruction field cursor.
.EXPORT FuncA_Console_DrawFieldCursor
.PROC FuncA_Console_DrawFieldCursor
    lda #$00  ; param: cursor diminished bool ($00 = undiminished)
    fall FuncA_Console_DrawFieldCursorFullOrDim
.ENDPROC

;;; Draws the console instruction field cursor, possibly diminished.
;;; @param A True ($ff) to draw the cursor diminished, false ($00) otherwise.
.PROC FuncA_Console_DrawFieldCursorFullOrDim
    sta T3  ; cursor diminished bool
_YPosition:
    ;; Calculate the window row that the cursor is in.
    lda Zp_ConsoleInstNumber_u8
    cmp Zp_ConsoleNumInstRows_u8
    blt @leftColumn
    sub Zp_ConsoleNumInstRows_u8
    @leftColumn:
    add #1  ; add 1 for the top border
    ;; Calculate the Y-position of the objects and store in T0.
    mul #kTileHeightPx
    adc Zp_WindowTop_u8  ; carry will by clear
    adc #$ff  ; subtract 1 (carry will still be clear)
    sta T0  ; Y-position
_XPosition:
    jsr FuncA_Console_GetCurrentFieldOffset  ; preserves T0+, returns A
    mul #kTileWidthPx
    add #kTileWidthPx * 4
    ldx Zp_ConsoleInstNumber_u8
    cpx Zp_ConsoleNumInstRows_u8
    blt @leftColumn
    add #kTileWidthPx * 10
    @leftColumn:
    sta T1  ; X-position
_DrawCursor:
    jsr FuncA_Console_GetCurrentFieldWidth  ; preserves T0+, returns A
    sta T2  ; cursor width - 1
    bit T3  ; cursor diminished bool
    bpl FuncA_Console_DrawFullCursor
    fall FuncA_Console_DrawDiminishedCursor
.ENDPROC

;;; Draws a diminished window cursor at the specified position on the screen.
;;; @param T0 The Y-position for the top of the cursor.
;;; @param T1 The X-position for the left of the cursor.
;;; @param T2 The (width - 1) of the cursor, in tiles.
.PROC FuncA_Console_DrawDiminishedCursor
    lda #2  ; param: num objects
    jsr Func_AllocObjects  ; preserves T0+, returns Y
    lda T1  ; X-position
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    lda T2  ; cursor (width - 1), in tiles
    mul #kTileWidthPx
    adc T1  ; X-position
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    lda T0  ; Y-position
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    lda #kTileIdObjCursorDimLeft
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #bObj::Pri | kPaletteObjCursor
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    rts
.ENDPROC

;;; Draws a full (undiminished) window cursor at the specified position on the
;;; screen.
;;; @param T0 The screen pixel Y-position for the top of the cursor.
;;; @param T1 The screen pixel X-position for the left of the cursor.
;;; @param T2 The (width - 1) of the cursor, in tiles.
.PROC FuncA_Console_DrawFullCursor
    ldx T2  ; cursor (width - 1), in tiles
_ObjectLoop:
    jsr Func_AllocOneObject  ; preserves X and T0+, returns Y
    ;; Set Y-position.
    lda T0  ; Y-position
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    ;; Set and increment X-position.
    lda T1  ; X-position
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    add #kTileWidthPx
    sta T1  ; X-position
    ;; Set flags.
    lda #bObj::Pri | kPaletteObjCursor
    cpx #0
    bne @noFlip
    eor #bObj::FlipH
    @noFlip:
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    ;; Set tile ID.
    lda T2  ; cursor (width - 1), in tiles
    beq @tileSingle
    cpx T2  ; cursor (width - 1), in tiles
    beq @tileSide
    txa
    beq @tileSide
    @tileMiddle:
    lda #kTileIdObjCursorSolidMiddle
    bne @setTile  ; unconditional
    @tileSide:
    lda #kTileIdObjCursorSolidLeft
    bne @setTile  ; unconditional
    @tileSingle:
    lda #kTileIdObjCursorSolidSingle
    @setTile:
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ;; Move offset to the next object.
    dex
    bpl _ObjectLoop
    rts
.ENDPROC

;;; Draws the console debug cursor.
;;; @prereq The (real) machine console is open.
.EXPORT FuncA_Console_DrawDebugCursor
.PROC FuncA_Console_DrawDebugCursor
    ldx Zp_ConsoleMachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, x
    .assert eMachine::Running = 0, error
    beq _DrawSolid
    cmp #eMachine::Error
    beq _Error
    cmp #kFirstResetStatus
    bge _Resetting
    cmp #eMachine::Halted
    bne _DrawDim
_Halted:
    lda Zp_FrameCounter_u8
    and #$04
    bne _DrawSolid
    rts
_Error:
    lda Zp_FrameCounter_u8
    and #$08
    bne _DrawSolid
    rts
_Resetting:
    lda Zp_FrameCounter_u8
    and #$04
    bne _DrawDim
    rts
_DrawSolid:
    lda #$00  ; param: diminished bool
    beq FuncA_Console_DrawPcCursor  ; unconditional
_DrawDim:
    lda #$ff  ; param: diminished bool
    fall FuncA_Console_DrawPcCursor
.ENDPROC

;;; Draws a console debug cursor that hilights the instruction number for the
;;; console machine's current PC.
;;; @prereq The (real) machine console is open.
;;; @param A True ($ff) to draw the cursor diminished, false ($00) otherwise.
.PROC FuncA_Console_DrawPcCursor
    ldy Zp_ConsoleMachineIndex_u8
    ldx Ram_MachinePc_u8_arr, y  ; param: instruction number
    fall FuncA_Console_DrawInstructionCursor
.ENDPROC

;;; Draws a console debug cursor that hilights the specified instruction
;;; number.
;;; @prereq Zp_ConsoleNumInstRows_u8 is initialized.
;;; @param A True ($ff) to draw the cursor diminished, false ($00) otherwise.
;;; @param X The instruction number.
.EXPORT FuncA_Console_DrawInstructionCursor
.PROC FuncA_Console_DrawInstructionCursor
    sta T0  ; cursor diminished bool
    lda #2  ; param: num objects
    jsr Func_AllocObjects  ; preserves X and T0+, returns Y
_YPosition:
    ;; Calculate the window row that the cursor is in.
    txa  ; instruction number
    cmp Zp_ConsoleNumInstRows_u8
    blt @leftColumn
    sub Zp_ConsoleNumInstRows_u8
    @leftColumn:
    add #1  ; add 1 for the top border
    ;; Calculate the Y-position of the objects.
    mul #kTileHeightPx
    adc Zp_WindowTop_u8  ; carry will by clear
    adc #<-1  ; subtract 1 (carry will still be clear)
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
_XPosition:
    lda #kTileWidthPx * 2
    cpx Zp_ConsoleNumInstRows_u8
    blt @leftColumn
    lda #kTileWidthPx * 12
    @leftColumn:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    add #5
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
_TileAndFlags:
    lda #kTileIdObjCursorSolidLeft
    bit T0  ; cursor diminished bool
    bpl @undiminished
    lda #kTileIdObjCursorDimLeft
    @undiminished:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #bObj::Pri | kPaletteObjCursor
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    rts
.ENDPROC

;;;=========================================================================;;;
