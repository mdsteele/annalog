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

.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "ppu.inc"
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

;;;=========================================================================;;;

.SEGMENT "PRG8_Console"

;;; Mode for scrolling in the console window.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.EXPORT Main_Console_OpenWindow
.PROC Main_Console_OpenWindow
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
    lda #kWindowTileIdBlank
    sta Ram_PpuTransfer_arr, x
    sta Ram_PpuTransfer_arr + kScreenWidthTiles - 1, x
    inx
    lda #kWindowTileIdVert
    sta Ram_PpuTransfer_arr, x
    inx
    ;; TODO: Draw instruction
    lda #kWindowTileIdBlank
    ldy #9
    @loop1:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @loop1
    lda #kWindowTileIdVert
    sta Ram_PpuTransfer_arr, x
    inx
    ;; TODO: Draw instruction
    lda #kWindowTileIdBlank
    ldy #9
    @loop2:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @loop2
    lda #kWindowTileIdVert
    sta Ram_PpuTransfer_arr, x
    inx
    ;; TODO: Draw status window
    lda #kWindowTileIdBlank
    ldy #8
    @loop3:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @loop3
    lda #kWindowTileIdVert
    sta Ram_PpuTransfer_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;
