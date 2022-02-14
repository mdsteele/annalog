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
.INCLUDE "dialog.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "window.inc"

.IMPORT Func_ClearRestOfOam
.IMPORT Func_DrawObjectsForRoom
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
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_WindowNextRowToTransfer_u8
.IMPORTZP Zp_WindowTopGoal_u8
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; The number of text rows in the dialog window (i.e. not including the
;;; borders or the bottom margin).
kDialogNumTextRows = 4

;;; The window tile row/col to start drawing dialog text.
kDialogTextStartRow = 1
kDialogTextStartCol = 7

;;; How many columns wide a line of dialog text is allowed to be at most.
kDialogTextMaxCols = 22

;;; The goal value for Zp_WindowTop_u8 while scrolling in the dialog window.
.LINECONT +
kDialogWindowTopGoal = kScreenHeightPx - \
    ((kDialogNumTextRows + 2) * kTileHeightPx + kWindowMarginBottomPx)
.LINECONT -

;;; How fast the dialog window scrolls up/down, in pixels per frame.
kDialogWindowScrollSpeed = 4

;;; The OBJ palette number and tile ID used for the visual prompt that appears
;;; when dialog is paused.
kDialogPromptObjPalette = 1
kDialogPromptObjTileId = $08

;;;=========================================================================;;;

.ZEROPAGE

;;; The CHR04 bank to set when the dialog portrait is at rest.
Zp_PortraitRestBank_u8: .res 1

;;; The CHR04 bank to alternate with Zp_PortraitRestBank_u8 when animating the
;;; dialog portrait.
Zp_PortraitAnimBank_u8: .res 1

;;; The window tile row/col where the next character of dialog text will be
;;; drawn.
Zp_DialogTextRow_u8: .res 1
Zp_DialogTextCol_u8: .res 1

;;; If set to true ($ff), the end of the current block of dialog text has been
;;; reached, and dialog mode is waiting for the player to press the button to
;;; continue.  If set to false ($00), the dialog text is still being written to
;;; the screen character by character.
Zp_DialogPaused_bool: .res 1

;;; A pointer into the current dialog data.  If Zp_DialogPaused_bool is true,
;;; this points to the 2-byte ePortrait value for the next block of text;
;;; otherwise, this points to the next character of text to draw.
Zp_DialogText_ptr: .res 2

;;;=========================================================================;;;

.SEGMENT "PRG8_Dialog"

.PROC Data_TestDialog_sDialog
    .word ePortrait::Woman
    .byte "Lorem ipsum dolor sit$"
    .byte "amet, consectetur$"
    .byte "adipiscing elit, sed$"
    .byte "do eiusmod tempor.#"
    .word ePortrait::Woman
    .byte "Ut enim ad minim$"
    .byte "veniam, quis nostrud$"
    .byte "exercitation.#"
    .byte 0
.ENDPROC

;;; Mode for scrolling in the dialog window.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @param A The dialog index.
.EXPORT Main_Dialog_OpenWindow
.PROC Main_Dialog_OpenWindow
    ;; TODO: Get actual dialog ptr from dialog index.
    ldax #Data_TestDialog_sDialog
    stax Zp_DialogText_ptr
    jsr Func_Dialog_LoadNextPortrait
_InitWindow:
    lda #kScreenHeightPx - kDialogWindowScrollSpeed
    sta Zp_WindowTop_u8
    jsr Func_Window_SetUpIrq
    lda #1
    sta Zp_WindowNextRowToTransfer_u8
    lda #kDialogWindowTopGoal
    sta Zp_WindowTopGoal_u8
_GameLoop:
    jsr Func_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_ScrollWindowUp:
    lda Zp_WindowTop_u8
    sub #kDialogWindowScrollSpeed
    cmp Zp_WindowTopGoal_u8
    bge @notDone
    lda Zp_WindowTopGoal_u8
    @notDone:
    sta Zp_WindowTop_u8
    jsr Func_Window_SetUpIrq
    jsr Func_Dialog_TransferNextWindowRow
_CheckIfDone:
    lda Zp_WindowTop_u8
    cmp Zp_WindowTopGoal_u8
    jeq Main_Dialog_Run
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    jsr Func_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;; Mode for scrolling out the dialog window.  Switches to explore mode once
;;; the window is fully hidden.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Dialog_CloseWindow
_GameLoop:
    jsr Func_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_ScrollWindowDown:
    lda Zp_WindowTop_u8
    add #kDialogWindowScrollSpeed
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

;;; Mode for running the dialog window.
;;; @prereq Rendering is enabled.
;;; @prereq The dialog window is fully visible.
;;; @prereq Explore mode is initialized.
.PROC Main_Dialog_Run
_GameLoop:
    jsr Func_Dialog_DrawObjectsForPrompt
    jsr Func_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_CheckBButton:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::BButton
    beq @done
    jmp Main_Dialog_CloseWindow
    @done:
_CheckAButton:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::AButton
    beq @done
    bit Zp_DialogPaused_bool
    bpl @skip
    jsr Func_Dialog_TransferClearText
    ldy #0
    lda (Zp_DialogText_ptr), y
    bne @next
    jmp Main_Dialog_CloseWindow
    @next:
    jsr Func_Dialog_LoadNextPortrait
    jmp _GameLoop
    @skip:
    chr04_bank Zp_PortraitRestBank_u8
    jsr Func_Dialog_TransferRestOfText
    jmp _GameLoop
    @done:
_UpdateText:
    bit Zp_DialogPaused_bool
    bmi @paused
    jsr Func_Dialog_TransferNextCharacter
    ;; Animate portrait:
    lda Zp_FrameCounter_u8
    and #$08
    beq @paused
    chr04_bank Zp_PortraitAnimBank_u8
    jmp @done
    @paused:
    chr04_bank Zp_PortraitRestBank_u8
    @done:
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    jsr Func_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;; Reads the 2-byte ePortrait value that Zp_DialogText_ptr points to,
;;; initializes dialog variables appropriately, and then advances
;;; Zp_DialogText_ptr to point to the start of the text.
;;; @prereq Zp_DialogText_ptr is pointing to an ePortrait.
.PROC Func_Dialog_LoadNextPortrait
    lda #kDialogTextStartCol
    sta Zp_DialogTextCol_u8
    lda #kDialogTextStartRow
    sta Zp_DialogTextRow_u8
    ldy #0
    sty Zp_DialogPaused_bool
    lda (Zp_DialogText_ptr), y
    sta Zp_PortraitRestBank_u8
    iny
    lda (Zp_DialogText_ptr), y
    sta Zp_PortraitAnimBank_u8
    iny
    chr04_bank Zp_PortraitRestBank_u8
    .assert * = Func_Dialog_AdvanceTextPtr, error, "fallthrough"
.ENDPROC

;;; Adds Y to Zp_DialogText_ptr and stores the result in Zp_DialogText_ptr.
;;; @param Y The byte offset to add to Zp_DialogText_ptr.
.PROC Func_Dialog_AdvanceTextPtr
    tya
    add Zp_DialogText_ptr + 0
    sta Zp_DialogText_ptr + 0
    lda Zp_DialogText_ptr + 1
    adc #0
    sta Zp_DialogText_ptr + 1
    rts
.ENDPROC

;;; Transfers the next dialog window row (if any) that still needs to be
;;; transferred to the PPU.
.PROC Func_Dialog_TransferNextWindowRow
    ldy Zp_WindowNextRowToTransfer_u8
    dey
    cpy #kDialogNumTextRows
    blt _Interior
    beq _BottomBorder
_BottomMargin:
    cpy #kWindowMaxNumRows
    blt @clear
    rts
    @clear:
    jmp Func_Window_TransferClearRow
_BottomBorder:
    jmp Func_Window_TransferBottomBorder
_Interior:
    jsr Func_Window_PrepareRowTransfer
    ;; Draw borders and margins:
    lda #kWindowTileIdBlank
    sta Ram_PpuTransfer_arr, x
    sta Ram_PpuTransfer_arr + kScreenWidthTiles - 1, x
    lda #kWindowTileIdVert
    sta Ram_PpuTransfer_arr + 1, x
    sta Ram_PpuTransfer_arr + kScreenWidthTiles - 2, x
    inx
    inx
    ;; Draw portrait:
    lda Zp_WindowNextRowToTransfer_u8
    add #$6e
    ldy #4
    @portraitLoop:
    sta Ram_PpuTransfer_arr, x
    adc #4
    inx
    dey
    bne @portraitLoop
    ;; Clear interior:
    lda #kWindowTileIdBlank
    ldy #kScreenWidthTiles - 8
    @clearLoop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @clearLoop
    rts
.ENDPROC

;;; Transfers the next character of dialog text (if any) to the PPU.  If an
;;; end-of-line/text marker is reached, updates dialog variables accordingly.
;;; @prereq Zp_DialogPaused_bool is false and Zp_DialogText_ptr points to text.
.PROC Func_Dialog_TransferNextCharacter
    ldy #0
    lda (Zp_DialogText_ptr), y
    pha
    iny
    jsr Func_Dialog_AdvanceTextPtr
    pla
    cmp #kDialogTextNewline
    beq _Newline
    cmp #kDialogTextEnd
    beq _End
_TransferCharacter:
    pha  ; character to transfer
    lda Zp_DialogTextRow_u8  ; param: window row
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    stx Zp_Tmp1_byte  ; destination address (hi)
    ;; Update Zp_PpuTransferLen_u8.
    ldx Zp_PpuTransferLen_u8
    txa
    add #5
    sta Zp_PpuTransferLen_u8
    ;; Write the transfer entry.
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr + 0, x
    lda Zp_Tmp1_byte  ; destination address (hi)
    sta Ram_PpuTransfer_arr + 1, x
    tya               ; destination address (lo)
    ora Zp_DialogTextCol_u8
    sta Ram_PpuTransfer_arr + 2, x
    lda #1
    sta Ram_PpuTransfer_arr + 3, x
    pla  ; character to transfer
    sta Ram_PpuTransfer_arr + 4, x
    inc Zp_DialogTextCol_u8
    rts
_Newline:
    lda #kDialogTextStartCol
    sta Zp_DialogTextCol_u8
    inc Zp_DialogTextRow_u8
    rts
_End:
    lda #$ff
    sta Zp_DialogPaused_bool
    rts
.ENDPROC

;;; Transfers all remaining dialog text (if any) until the next end-of-text
;;; marker to the PPU, then updates dialog variables accordingly (in
;;; particular, Zp_DialogPaused_bool will be set to true when this returns).
;;; @prereq Zp_DialogPaused_bool is false and Zp_DialogText_ptr points to text.
.PROC Func_Dialog_TransferRestOfText
    ;; If the next character is already an end-of-line/text marker, don't
    ;; create a transfer entry for this line.
    ldy #0
    lda (Zp_DialogText_ptr), y
    bmi _EndOfLine
_TransferLine:
    ;; Write the transfer entry header (except for transfer len) for the rest
    ;; of the current line of text.
    lda Zp_DialogTextRow_u8  ; param: window row
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    stx Zp_Tmp1_byte  ; destination address (hi)
    ldx Zp_PpuTransferLen_u8
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr, x
    inx
    lda Zp_Tmp1_byte  ; destination address (hi)
    sta Ram_PpuTransfer_arr, x
    inx
    tya               ; destination address (lo)
    ora Zp_DialogTextCol_u8
    sta Ram_PpuTransfer_arr, x
    inx
    stx Zp_Tmp1_byte  ; byte offset for transfer data length
    inx
    ;; Write the transfer data for the rest of the current line of text.
    ldy #0
    @loop:
    lda (Zp_DialogText_ptr), y
    bmi @finish
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    bne @loop  ; unconditional
    ;; Finish the transfer.
    @finish:
    pha  ; end-of-line/text marker
    stx Zp_PpuTransferLen_u8
    ldx Zp_Tmp1_byte  ; byte offset for transfer data length
    tya               ; transfer data length
    sta Ram_PpuTransfer_arr, x
    pla  ; end-of-line/text marker
_EndOfLine:
    ;; Update the dialog text position.
    cmp #kDialogTextEnd
    beq @endOfText
    lda #kDialogTextStartCol
    sta Zp_DialogTextCol_u8
    inc Zp_DialogTextRow_u8
    bne @advance  ; unconditional
    @endOfText:
    lda #$ff
    sta Zp_DialogPaused_bool
    @advance:
    iny  ; Skip past the end-of-line/text marker.
    jsr Func_Dialog_AdvanceTextPtr
    ;; Check whether there are still more lines to transfer.
    bit Zp_DialogPaused_bool
    bpl _TransferLine
    rts
.ENDPROC

;;; Buffers a PPU transfer to clear all text from the dialog window.
.PROC Func_Dialog_TransferClearText
    lda #kDialogTextStartRow
    @rowLoop:
    pha
    ;; Write the transfer entry header.
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    stx Zp_Tmp1_byte  ; destination address (hi)
    ldx Zp_PpuTransferLen_u8
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr, x
    inx
    lda Zp_Tmp1_byte  ; destination address (hi)
    sta Ram_PpuTransfer_arr, x
    inx
    tya               ; destination address (lo)
    ora #kDialogTextStartCol
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kDialogTextMaxCols
    sta Ram_PpuTransfer_arr, x
    inx
    ;; Write the transfer data.
    lda #kWindowTileIdBlank
    ldy #kDialogTextMaxCols
    @columnLoop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @columnLoop
    stx Zp_PpuTransferLen_u8
    pla
    add #1
    cmp #kDialogTextStartRow + kDialogNumTextRows
    bne @rowLoop
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the visual prompt that appears when
;;; dialog is paused.
.PROC Func_Dialog_DrawObjectsForPrompt
    bit Zp_DialogPaused_bool
    bpl _NotPaused
_DrawPrompt:
    ;; Calculate the screen Y-position.
    lda Zp_FrameCounter_u8
    lsr a
    lsr a
    lsr a
    and #$03
    cmp #$03
    bne @noZigZag
    lda #$01
    @noZigZag:
    add #kScreenHeightPx - kWindowMarginBottomPx - $12
    ;; Set object attributes.
    ldy Zp_OamOffset_u8
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    lda #$e8
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    lda #kDialogPromptObjPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kDialogPromptObjTileId
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ;; Update the OAM offset.
    .repeat .sizeof(sObj)
    iny
    .endrepeat
    sty Zp_OamOffset_u8
_NotPaused:
    rts
.ENDPROC

;;;=========================================================================;;;
