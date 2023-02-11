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
.IMPORT Ram_Console_sProgram
.IMPORT Ram_MenuCols_u8_arr
.IMPORT Ram_MenuRows_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_ConsoleFieldNumber_u8
.IMPORTZP Zp_ConsoleInstNumber_u8
.IMPORTZP Zp_ConsoleNominalFieldOffset_u8
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_Current_sMenu_ptr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_MachineMaxInstructions_u8
.IMPORTZP Zp_MenuItem_u8
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp4_byte
.IMPORTZP Zp_Tmp_ptr
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; Moves the console field cursor based on the current joypad state.
.EXPORT FuncA_Console_MoveFieldCursor
.PROC FuncA_Console_MoveFieldCursor
.PROC _MoveCursorVertically
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
    cpx Zp_MachineMaxInstructions_u8
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
    jsr FuncA_Console_IsPrevInstructionEmpty  ; returns Z
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

;;; Moves the console menu cursor (updating Zp_MenuItem_u8 appropriately) based
;;; on the current joypad state.
.EXPORT FuncA_Console_MoveMenuCursor
.PROC FuncA_Console_MoveMenuCursor
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
    @noLeft:
_MoveCursorRight:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Right
    beq @noRight
    ldy #sMenu::OnRight_func_ptr
    jsr _MenuFunc
    @noRight:
    rts
_MenuFunc:
    lda (Zp_Current_sMenu_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sMenu_ptr), y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
.ENDPROC

;;; Draws the console instruction field cursor.
.EXPORT FuncA_Console_DrawFieldCursor
.PROC FuncA_Console_DrawFieldCursor
    lda #$00  ; param: cursor diminished bool ($00 = undiminished)
    .assert * = FuncA_Console_DrawFieldCursorDiminished, error, "fallthrough"
.ENDPROC

;;; Draws the console instruction field cursor, possibly diminished.
;;; @param A True ($ff) to draw the cursor diminished, false ($00) otherwise.
.PROC FuncA_Console_DrawFieldCursorDiminished
    sta Zp_Tmp4_byte  ; cursor diminished bool
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
    jsr FuncA_Console_GetCurrentFieldOffset  ; preserves Zp_Tmp*, returns A
    mul #kTileWidthPx
    add #kTileWidthPx * 4
    ldx Zp_ConsoleInstNumber_u8
    cpx Zp_ConsoleNumInstRows_u8
    blt @leftColumn
    add #kTileWidthPx * 10
    @leftColumn:
    sta Zp_Tmp2_byte  ; X-position
_PrepareForLoop:
    jsr FuncA_Console_GetCurrentFieldWidth  ; preserves Zp_Tmp*, returns A
    sta Zp_Tmp3_byte  ; cursor width - 1
    tax  ; loop variable (counts from cursor width - 1 down to zero)
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
    lda #bObj::Pri | kPaletteObjCursor
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    ;; Set tile ID.
    lda Zp_Tmp4_byte  ; cursor diminished bool
    bpl @undiminished
    lda Zp_Tmp3_byte  ; cursor width - 1
    beq @dimSingle
    cpx Zp_Tmp3_byte  ; cursor width - 1
    beq @dimLeft
    txa
    bne @continue
    @dimRight:
    lda #kTileIdObjCursorDimRight
    bne @setTile  ; unconditional
    @dimLeft:
    lda #kTileIdObjCursorDimLeft
    bne @setTile  ; unconditional
    @dimSingle:
    lda #kTileIdObjCursorDimSingle
    bne @setTile  ; unconditional
    @undiminished:
    lda Zp_Tmp3_byte  ; cursor width - 1
    beq @tileSingle
    cpx Zp_Tmp3_byte  ; cursor width - 1
    beq @tileLeft
    txa
    beq @tileRight
    @tileMiddle:
    lda #kTileIdObjCursorSolidMiddle
    bne @setTile  ; unconditional
    @tileRight:
    lda #kTileIdObjCursorSolidRight
    bne @setTile  ; unconditional
    @tileLeft:
    lda #kTileIdObjCursorSolidLeft
    bne @setTile  ; unconditional
    @tileSingle:
    lda #kTileIdObjCursorSolidSingle
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

;;; Draws the console menu cursor and the diminished console field cursor.
.EXPORT FuncA_Console_DrawMenuCursor
.PROC FuncA_Console_DrawMenuCursor
    ldx Zp_MenuItem_u8
_XPosition:
    lda Ram_MenuCols_u8_arr, x
    mul #kTileWidthPx
    add #kMenuStartTileColumn * kTileWidthPx
    sta Zp_Tmp2_byte  ; cursor left X-position, in pixels
_CursorWidth:
    txa
    add #sMenu::WidthsMinusOne_u8_arr
    tay
    lda (Zp_Current_sMenu_ptr), y
    sta Zp_Tmp3_byte  ; cursor (width - 1), in tiles
_YPosition:
    ;; Calculate the window row that the cursor is in.
    lda Ram_MenuRows_u8_arr, x
    add #kMenuStartWindowRow
    ;; Calculate the Y-position of the objects and store in Zp_Tmp1_byte.
    mul #kTileHeightPx
    adc Zp_WindowTop_u8  ; carry will by clear
    adc #$ff  ; subtract 1 (carry will still be clear)
    sta Zp_Tmp1_byte  ; cursor Y-position, in pixels
_PrepareForLoop:
    ldx Zp_Tmp3_byte  ; cursor (width - 1), in tiles
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
    lda #bObj::Pri | kPaletteObjCursor
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    ;; Set tile ID.
    lda Zp_Tmp3_byte  ; cursor (width - 1), in tiles
    beq @tileSingle
    cpx Zp_Tmp3_byte  ; cursor (width - 1), in tiles
    beq @tileLeft
    txa
    beq @tileRight
    @tileMiddle:
    lda #kTileIdObjCursorSolidMiddle
    bne @setTile  ; unconditional
    @tileRight:
    lda #kTileIdObjCursorSolidRight
    bne @setTile  ; unconditional
    @tileLeft:
    lda #kTileIdObjCursorSolidLeft
    bne @setTile  ; unconditional
    @tileSingle:
    lda #kTileIdObjCursorSolidSingle
    @setTile:
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ;; Move offset to the next object.
    .repeat .sizeof(sObj)
    iny
    .endrepeat
    dex
    bpl _ObjectLoop
    sty Zp_OamOffset_u8
_DrawFieldCursor:
    lda #$ff  ; param: cursor diminished bool ($ff = diminished)
    jmp FuncA_Console_DrawFieldCursorDiminished
.ENDPROC

;;; Draws the console instruction error cursor.
.EXPORT FuncA_Console_DrawErrorCursor
.PROC FuncA_Console_DrawErrorCursor
    lda Zp_FrameCounter_u8
    and #$08
    beq _Done
    ldy Zp_OamOffset_u8
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
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
_XPosition:
    lda #kTileWidthPx * 2
    ldx Zp_ConsoleInstNumber_u8
    cpx Zp_ConsoleNumInstRows_u8
    blt @leftColumn
    lda #kTileWidthPx * 12
    @leftColumn:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    add #5
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
_TileAndFlags:
    lda #kTileIdObjCursorSolidLeft
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #bObj::Pri | kPaletteObjCursor
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    tya
    add #.sizeof(sObj) * 2
    sta Zp_OamOffset_u8
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;
