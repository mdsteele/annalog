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
.INCLUDE "cpu.inc"
.INCLUDE "fake.inc"
.INCLUDE "joypad.inc"
.INCLUDE "machine.inc"
.INCLUDE "machines/emitter.inc"
.INCLUDE "machines/lift.inc"
.INCLUDE "machines/shared.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"
.INCLUDE "program.inc"
.INCLUDE "window.inc"

.IMPORT FuncA_Console_AdjustAvatar
.IMPORT FuncA_Console_WriteDiagramTransferDataForDiagram
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncM_ConsoleScrollTowardsGoalAndTick
.IMPORT FuncM_DrawObjectsForRoom
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_Window_PrepareRowTransfer
.IMPORT Func_Window_ScrollUp
.IMPORT Func_Window_TransferBottomBorder
.IMPORT Func_Window_TransferClearRow
.IMPORT Main_Console_CloseWindow
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_ConsoleNeedsPower_u8
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_WindowNextRowToTransfer_u8
.IMPORTZP Zp_WindowTopGoal_u8
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; The number of interior rows for a fake console window.
kFakeConsoleMessageRows = kMaxProgramLength / 2

;;; The width of the fake console message box, in tiles.
kFakeConsoleMessageCols = 19

;;;=========================================================================;;;

.ZEROPAGE

;;; Which fake console is currently being used (if any).
Zp_Current_eFake: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for using a fake console device.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @param X The fake console device index.
.EXPORT Main_FakeConsole_UseDevice
.PROC Main_FakeConsole_UseDevice
    jsr_prga FuncA_Console_InitFakeConsole
_GameLoop:
    jsr FuncM_DrawFakeConsoleObjectsAndProcessFrame
    jsr_prga FuncA_Console_ScrollWindowUpForFakeConsole  ; returns C
    bcs Main_FakeConsole_Message
    jsr FuncM_ConsoleScrollTowardsGoalAndTick
    jmp _GameLoop
.ENDPROC

;;; Mode for when a fake console window is open.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Current_eFake is initialized.
;;; @prereq The console window is fully visible.
.PROC Main_FakeConsole_Message
_GameLoop:
    jsr FuncM_DrawFakeConsoleObjectsAndProcessFrame
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::AButton | bJoypad::BButton
    beq _GameLoop
    jmp Main_Console_CloseWindow
.ENDPROC

;;; Draws all objects that should be drawn in fake console mode, then calls
;;; Func_ClearRestOfOamAndProcessFrame.
;;; @prereq Zp_Current_eFake is initialized.
.PROC FuncM_DrawFakeConsoleObjectsAndProcessFrame
    jsr FuncM_DrawObjectsForRoom
    jsr_prga FuncA_Objects_DrawFakeMachineLight
    jmp Func_ClearRestOfOamAndProcessFrame
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; Initializes fake console mode.
;;; @param X The fake console device index.
.PROC FuncA_Console_InitFakeConsole
    ;; Set the CHR0C bank for this fake console's diagram.
    ldy Ram_DeviceTarget_byte_arr, x
    sty Zp_Current_eFake
    main_chr0c _Chr0cBank_u8_arr, y
    ;; Initialize Zp_ConsoleNumInstRows_u8, since some console utility
    ;; functions need it.
    lda #kFakeConsoleMessageRows
    sta Zp_ConsoleNumInstRows_u8
    ;; Write a non-zero value to Zp_ConsoleNeedsPower_u8 so that various
    ;; console functions won't try to treat this like a working machine.
    .assert kFakeConsoleMessageRows > 0, error
    sta Zp_ConsoleNeedsPower_u8
_InitWindow:
    lda #kScreenHeightPx - kConsoleWindowScrollSpeed
    sta Zp_WindowTop_u8
    lda #1
    sta Zp_WindowNextRowToTransfer_u8
    .linecont +
    lda #kScreenHeightPx - (kTileHeightPx * 2 + kWindowMarginBottomPx) - \
         kTileHeightPx * kFakeConsoleMessageRows
    .linecont -
    sta Zp_WindowTopGoal_u8
    rts
_Chr0cBank_u8_arr:
    D_ARRAY .enum, eFake
    d_byte CoreDump,         $61  ; TODO
    d_byte Ethical,          $60  ; TODO
    d_byte InsufficientData, $50  ; TODO
    d_byte NoPower,          kChrBankDiagramLift
    D_END
.ENDPROC

;;; Scrolls the fake console window in a bit, and transfers PPU data as needed;
;;; call this each frame when the fake console window is opening.
;;; @prereq Zp_Current_eFake is initialized.
;;; @return C Set if the window is now fully scrolled in.
.PROC FuncA_Console_ScrollWindowUpForFakeConsole
    jsr FuncA_Console_AdjustAvatar
    jsr FuncA_Console_TransferNextWindowRowForFakeConsole
    lda #kConsoleWindowScrollSpeed  ; param: scroll by
    jmp Func_Window_ScrollUp  ; sets C if fully scrolled in
.ENDPROC

;;; Transfers the next console window row (if any) that still needs to be
;;; transferred to the PPU.
;;; @prereq Zp_Current_eFake is initialized.
.PROC FuncA_Console_TransferNextWindowRowForFakeConsole
    ldy Zp_WindowNextRowToTransfer_u8
    dey
    cpy #kFakeConsoleMessageRows
    blt _Interior
    beq _BottomBorder
    cpy #kWindowMaxNumRows - 1
    blt _BottomMargin
    rts
_BottomMargin:
    jmp Func_Window_TransferClearRow
_BottomBorder:
    jmp Func_Window_TransferBottomBorder
_Interior:
    jsr Func_Window_PrepareRowTransfer  ; returns X
    ;; Draw margins, borders, and column separators:
    lda #' '
    sta Ram_PpuTransfer_arr, x
    sta Ram_PpuTransfer_arr + kScreenWidthTiles - 1, x
    lda #kTileIdBgWindowVert
    sta Ram_PpuTransfer_arr + 1, x
    sta Ram_PpuTransfer_arr + 21, x
    sta Ram_PpuTransfer_arr + kScreenWidthTiles - 2, x
_Message:
    inx
    inx
    ldy Zp_WindowNextRowToTransfer_u8
    dey
    dey  ; param: status box row
    jsr FuncA_Console_WriteFakeConsoleMessageTransferData
    inx
_DrawStatus:
    ldy Zp_Current_eFake
    lda _Fake_eDiagram, y  ; param: eDiagram value
    ;; Draw the status box.
    ldy Zp_WindowNextRowToTransfer_u8
    dey
    dey  ; param: status box row
    jmp FuncA_Console_WriteDiagramTransferDataForDiagram
_Fake_eDiagram:
    D_ARRAY .enum, eFake
    d_byte CoreDump,         eDiagram::MinigunDown  ; TODO
    d_byte Ethical,          eDiagram::MinigunDown  ; TODO
    d_byte InsufficientData, eDiagram::MinigunDown  ; TODO
    d_byte NoPower,          eDiagram::Lift
    D_END
.ENDPROC

;;; Writes kFakeConsoleMessageCols bytes into a PPU transfer entry with the
;;; tile IDs of the specified row of the current fake console message box.
;;; @prereq Zp_Current_eFake is initialized.
;;; @param X PPU transfer array index within an entry's data.
;;; @param Y The console interior row to transfer (0-7).
;;; @return X Updated PPU transfer array index.
.PROC FuncA_Console_WriteFakeConsoleMessageTransferData
    ;; Compute the byte index into the array for the pointer to the data for
    ;; this row (first asserting that the calculation won't overflow).
    .assert eFake::NUM_VALUES * kFakeConsoleMessageRows <= $100, error
    sty T0  ; interior row
    lda Zp_Current_eFake
    .assert kFakeConsoleMessageRows = 8, error
    mul #8
    adc T0  ; interior row (carry is already clear from mul)
    mul #kSizeofAddr
    tay  ; byte index into array
    ;; Copy the pointer into T1T0.
    lda DataA_Console_FakeMessage_u8_arr19_ptr_arr8_arr, y
    sta T0  ; data pointer (lo)
    iny
    lda DataA_Console_FakeMessage_u8_arr19_ptr_arr8_arr, y
    sta T1  ; data pointer (hi)
    ;; Copy the data into the PPU transfer array.
    ldy #0
    @loop:
    lda (T1T0), y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #kFakeConsoleMessageCols
    blt @loop
    rts
.ENDPROC

;;; Maps from eFake values to arrays (of length kFakeConsoleMessageRows) of
;;; pointers to tile data for each row of the message for that fake console.
.ASSERT kFakeConsoleMessageCols = 19, error
.ASSERT kFakeConsoleMessageRows = 8, error
.PROC DataA_Console_FakeMessage_u8_arr19_ptr_arr8_arr
    D_ARRAY .enum, eFake, kSizeofAddr * 8
    d_byte CoreDump
    .addr _CoreDump0_u8_arr19
    .addr _CoreDump1_u8_arr19
    .addr _CoreDump2_u8_arr19
    .addr _CoreDump3_u8_arr19
    .addr _CoreDump4_u8_arr19
    .addr _CoreDump5_u8_arr19
    .addr _CoreDump6_u8_arr19
    .addr _CoreDump7_u8_arr19
    d_byte Ethical
    .addr _Blank_u8_arr19
    .addr _Blank_u8_arr19
    .addr _Ethical2_u8_arr19
    .addr _Ethical3_u8_arr19
    .addr _Ethical4_u8_arr19
    .addr _Ethical5_u8_arr19
    .addr _Blank_u8_arr19
    .addr _Blank_u8_arr19
    d_byte InsufficientData
    .addr _CoreDump0_u8_arr19
    .addr _CoreDump1_u8_arr19
    .addr _CoreDump2_u8_arr19
    .addr _InsufficientData3_u8_arr19
    .addr _InsufficientData4_u8_arr19
    .addr _InsufficientData5_u8_arr19
    .addr _CoreDump6_u8_arr19
    .addr _CoreDump7_u8_arr19
    d_byte NoPower
    .addr _Blank_u8_arr19
    .addr _Blank_u8_arr19
    .addr _Blank_u8_arr19
    .addr _NoPower3_u8_arr19
    .addr _NoPower4_u8_arr19
    .addr _NoPower5_u8_arr19
    .addr _NoPower5_u8_arr19
    .addr _NoPower5_u8_arr19
    D_END
_Blank_u8_arr19:
:   .byte "                   "
    .assert * - :- = kFakeConsoleMessageCols, error
_CoreDump0_u8_arr19:
:   .byte "0:       ", kTileIdBgWindowVert, "8:       "
    .assert * - :- = kFakeConsoleMessageCols, error
_CoreDump1_u8_arr19:
:   .byte "1:       ", kTileIdBgWindowVert, "9:       "
    .assert * - :- = kFakeConsoleMessageCols, error
_CoreDump2_u8_arr19:
:   .byte "2:       ", kTileIdBgWindowVert, '0' + 10, ":       "
    .assert * - :- = kFakeConsoleMessageCols, error
_CoreDump3_u8_arr19:
:   .byte "3: FATAL ", kTileIdBgWindowVert, '0' + 11, ": CORE  "
    .assert * - :- = kFakeConsoleMessageCols, error
_CoreDump4_u8_arr19:
:   .byte "4: ERROR ", kTileIdBgWindowVert, '0' + 12, ": DUMP  "
    .assert * - :- = kFakeConsoleMessageCols, error
_CoreDump5_u8_arr19:
:   .byte "5:       ", kTileIdBgWindowVert, '0' + 13, ":       "
    .assert * - :- = kFakeConsoleMessageCols, error
_CoreDump6_u8_arr19:
:   .byte "6:       ", kTileIdBgWindowVert, '0' + 14, ":       "
    .assert * - :- = kFakeConsoleMessageCols, error
_CoreDump7_u8_arr19:
:   .byte "7:       ", kTileIdBgWindowVert, '0' + 15, ":       "
    .assert * - :- = kFakeConsoleMessageCols, error
_Ethical2_u8_arr19:
:   .byte "SYNTAX ERROR:      "
    .assert * - :- = kFakeConsoleMessageCols, error
_Ethical3_u8_arr19:
:   .byte " `Is this ethical?'"
    .assert * - :- = kFakeConsoleMessageCols, error
_Ethical4_u8_arr19:
:   .byte "IS NOT A VALID     "
    .assert * - :- = kFakeConsoleMessageCols, error
_Ethical5_u8_arr19:
:   .byte "INSTRUCTION.       "
    .assert * - :- = kFakeConsoleMessageCols, error
_InsufficientData3_u8_arr19:
:   .byte "ERROR: INSUFFICIENT"
    .assert * - :- = kFakeConsoleMessageCols, error
_InsufficientData4_u8_arr19:
:   .byte "DATA FOR MEANINGFUL"
    .assert * - :- = kFakeConsoleMessageCols, error
_InsufficientData5_u8_arr19:
:   .byte "RESPONSIBILITY.    "
    .assert * - :- = kFakeConsoleMessageCols, error
_NoPower3_u8_arr19:
:   .byte "  ERROR: NO POWER  "
    .assert * - :- = kFakeConsoleMessageCols, error
_NoPower4_u8_arr19:
:   .byte "    ON CIRCUIT 9379"
    .assert * - :- = kFakeConsoleMessageCols, error
_NoPower5_u8_arr19:
:   .byte "9999999999999999999"
    .assert * - :- = kFakeConsoleMessageCols, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws the fake machine light for when a fake console window is open.
;;; @prereq Zp_Current_eFake is initialized.
.PROC FuncA_Objects_DrawFakeMachineLight
    ldx Zp_Current_eFake
    lda _ShapeX_u8_arr, x
    sta Zp_ShapePosX_i16 + 0
    lda _ShapeY_u8_arr, x
    sta Zp_ShapePosY_i16 + 0
    lda #0
    sta Zp_ShapePosX_i16 + 1
    sta Zp_ShapePosY_i16 + 1
    ldy #kPaletteObjMachineLight  ; param: objects flags
    lda #kTileIdObjEmitterLight  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
_ShapeX_u8_arr:
    D_ARRAY .enum, eFake
    d_byte CoreDump,         $60
    d_byte Ethical,          $47
    d_byte InsufficientData, $a0
    d_byte NoPower,          $77
    D_END
_ShapeY_u8_arr:
    D_ARRAY .enum, eFake
    d_byte CoreDump,         $80
    d_byte Ethical,          $a0
    d_byte InsufficientData, $c0
    d_byte NoPower,          $67
    D_END
.ENDPROC

;;;=========================================================================;;;
