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
.INCLUDE "machine.inc"
.INCLUDE "machines/ammorack.inc"
.INCLUDE "machines/boiler.inc"
.INCLUDE "machines/bridge.inc"
.INCLUDE "machines/cannon.inc"
.INCLUDE "machines/carriage.inc"
.INCLUDE "machines/crane.inc"
.INCLUDE "machines/field.inc"
.INCLUDE "machines/hoist.inc"
.INCLUDE "machines/jet.inc"
.INCLUDE "machines/laser.inc"
.INCLUDE "machines/launcher.inc"
.INCLUDE "machines/lift.inc"
.INCLUDE "machines/minigun.inc"
.INCLUDE "machines/multiplexer.inc"
.INCLUDE "machines/pump.inc"
.INCLUDE "machines/reloader.inc"
.INCLUDE "machines/rotor.inc"
.INCLUDE "machines/semaphore.inc"
.INCLUDE "machines/shared.inc"
.INCLUDE "machines/winch.inc"
.INCLUDE "macros.inc"
.INCLUDE "ppu.inc"

.IMPORT Func_SetMachineIndex
.IMPORT Func_Window_GetRowPpuAddr
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_PpuTransferLen_u8

;;;=========================================================================;;;

;;; The height of the console machine diagram, in tiles.
kNumDiagramRows = 4

;;; The width of the console status box, in tiles.
kStatusBoxWidthTiles = 8

;;; The leftmost nametable tile column in the console status box.
kStatusBoxStartTileColumn = 22

;;; How many rows the "no power" message takes up, in tiles.
kNumNoPowerRows = 2

;;; The width of the "no power" message box, in tiles.
kNoPowerWidthTiles = 19

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; Maps from an eDiagram to the CHR04 bank with that diagram's tiles.
.EXPORT DataA_Console_DiagramBank_u8_arr
.PROC DataA_Console_DiagramBank_u8_arr
    D_ARRAY .enum, eDiagram
    d_byte AmmoRack,      kChrBankDiagramAmmoRack
    d_byte Boiler,        kChrBankDiagramBoiler
    d_byte BridgeLeft,    kChrBankDiagramBridgeLeft
    d_byte BridgeRight,   kChrBankDiagramBridgeRight
    d_byte CannonLeft,    kChrBankDiagramCannonLeft
    d_byte CannonRight,   kChrBankDiagramCannonRight
    d_byte Carriage,      kChrBankDiagramCarriage
    d_byte Crane,         kChrBankDiagramCrane
    d_byte Debugger,      kChrBankDiagramDebugger
    d_byte Field,         kChrBankDiagramField
    d_byte HoistLeft,     kChrBankDiagramHoistLeft
    d_byte HoistRight,    kChrBankDiagramHoistRight
    d_byte Jet,           kChrBankDiagramJet
    d_byte Laser,         kChrBankDiagramLaser
    d_byte LauncherDown,  kChrBankDiagramLauncherDown
    d_byte LauncherLeft,  kChrBankDiagramLauncherLeft
    d_byte Lift,          kChrBankDiagramLift
    d_byte MinigunDown,   kChrBankDiagramMinigunDown
    d_byte MinigunLeft,   kChrBankDiagramMinigunLeft
    d_byte MinigunRight,  kChrBankDiagramMinigunRight
    d_byte MinigunUp,     kChrBankDiagramMinigunUp
    d_byte Multiplexer,   kChrBankDiagramMultiplexer
    d_byte Pump,          kChrBankDiagramPump
    d_byte Reloader,      kChrBankDiagramReloader
    d_byte Rotor,         kChrBankDiagramRotor
    d_byte SemaphoreComm, kChrBankDiagramSemaphoreComm
    d_byte SemaphoreKey,  kChrBankDiagramSemaphoreKey
    d_byte SemaphoreLock, kChrBankDiagramSemaphoreLock
    d_byte Trolley,       kChrBankDiagramTrolley
    d_byte Winch,         kChrBankDiagramWinch
    D_END
.ENDPROC

;;; Maps from an eDiagram to the first BG tile ID for that diagram.
.PROC DataA_Console_DiagramFirstTileId_u8_arr
    D_ARRAY .enum, eDiagram
    d_byte AmmoRack,      kTileIdBgDiagramAmmoRackFirst
    d_byte Boiler,        kTileIdBgDiagramBoilerFirst
    d_byte BridgeLeft,    kTileIdBgDiagramBridgeLeftFirst
    d_byte BridgeRight,   kTileIdBgDiagramBridgeRightFirst
    d_byte CannonLeft,    kTileIdBgDiagramCannonLeftFirst
    d_byte CannonRight,   kTileIdBgDiagramCannonRightFirst
    d_byte Carriage,      kTileIdBgDiagramCarriageFirst
    d_byte Crane,         kTileIdBgDiagramCraneFirst
    d_byte Debugger,      0
    d_byte Field,         kTileIdBgDiagramFieldFirst
    d_byte HoistLeft,     kTileIdBgDiagramHoistLeftFirst
    d_byte HoistRight,    kTileIdBgDiagramHoistRightFirst
    d_byte Jet,           kTileIdBgDiagramJetFirst
    d_byte Laser,         kTileIdBgDiagramLaserFirst
    d_byte LauncherDown,  kTileIdBgDiagramLauncherDownFirst
    d_byte LauncherLeft,  kTileIdBgDiagramLauncherLeftFirst
    d_byte Lift,          kTileIdBgDiagramLiftFirst
    d_byte MinigunDown,   kTileIdBgDiagramMinigunDownFirst
    d_byte MinigunLeft,   kTileIdBgDiagramMinigunLeftFirst
    d_byte MinigunRight,  kTileIdBgDiagramMinigunRightFirst
    d_byte MinigunUp,     kTileIdBgDiagramMinigunUpFirst
    d_byte Multiplexer,   kTileIdBgDiagramMultiplexerFirst
    d_byte Pump,          kTileIdBgDiagramPumpFirst
    d_byte Reloader,      kTileIdBgDiagramReloaderFirst
    d_byte Rotor,         kTileIdBgDiagramRotorFirst
    d_byte SemaphoreComm, kTileIdBgDiagramSemaphoreCommFirst
    d_byte SemaphoreKey,  kTileIdBgDiagramSemaphoreKeyFirst
    d_byte SemaphoreLock, kTileIdBgDiagramSemaphoreLockFirst
    d_byte Trolley,       kTileIdBgDiagramTrolleyFirst
    d_byte Winch,         kTileIdBgDiagramWinchFirst
    D_END
.ENDPROC

;;; Appends PPU transfer entries to redraw all rows in the console status box.
.EXPORT FuncA_Console_TransferAllStatusRows
.PROC FuncA_Console_TransferAllStatusRows
    ldx Zp_ConsoleMachineIndex_u8  ; param: machine index
    jsr Func_SetMachineIndex
    ldy #0  ; param: status box row
    @loop:
    jsr FuncA_Console_TransferStatusRow  ; preserves Y
    iny
    cpy Zp_ConsoleNumInstRows_u8
    blt @loop
    rts
.ENDPROC

;;; Appends a PPU transfer entry to redraw the specified row of the console
;;; status box.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param Y The status box row to transfer (0-7).
;;; @preserve Y
.PROC FuncA_Console_TransferStatusRow
    tya
    pha
    ;; Get the transfer destination address, and store it in T0 (lo) and T1
    ;; (hi).
    iny  ; add 1 for the top border
    tya  ; param: window row
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    tya
    add #kStatusBoxStartTileColumn
    sta T0  ; transfer destination (lo)
    txa
    adc #0
    sta T1  ; transfer destination (hi)
    ;; Update Zp_PpuTransferLen_u8.
    ldx Zp_PpuTransferLen_u8
    txa
    add #4 + kStatusBoxWidthTiles
    sta Zp_PpuTransferLen_u8
    ;; Write the transfer entry header.
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr, x
    inx
    lda T1  ; transfer destination (hi)
    sta Ram_PpuTransfer_arr, x
    inx
    lda T0  ; transfer destination (lo)
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kStatusBoxWidthTiles
    sta Ram_PpuTransfer_arr, x
    inx
    ;; Write the transfer data.
    pla
    tay  ; param: status box row
    .assert * = FuncA_Console_WriteStatusTransferData, error, "fallthrough"
.ENDPROC

;;; Writes kStatusBoxWidthTiles (eight) bytes into a PPU transfer entry with
;;; the tile IDs of the specified row of the console status box.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X PPU transfer array index within an entry's data.
;;; @param Y The status box row to transfer (0-7).
;;; @return X Updated PPU transfer array index.
;;; @preserve Y
.EXPORT FuncA_Console_WriteStatusTransferData
.PROC FuncA_Console_WriteStatusTransferData
    stx T0  ; starting PPU transfer index
    sty T1  ; status box row
    ;; Compute the diagram row and store it in A.
    lda Zp_ConsoleNumInstRows_u8
    sub #kNumDiagramRows
    div #2
    sta T2  ; num leading blank rows
    lda T1  ; status box row
    sub T2  ; num leading blank rows
    ;; If the diagram row is negative, or more than the number of diagram rows,
    ;; then transfer a blank row.
    bmi _WriteBlankRow
    cmp #kNumDiagramRows
    bge _WriteBlankRow
_WriteDiagramRow:
    sta T3  ; diagram row
    ;; Draw the blank margin on either side of the diagram.
    .assert kStatusBoxWidthTiles = 8, error
    lda #' '
    sta Ram_PpuTransfer_arr + 0, x
    sta Ram_PpuTransfer_arr + 5, x
    sta Ram_PpuTransfer_arr + 6, x
    sta Ram_PpuTransfer_arr + 7, x
    ;; Draw the diagram itself.
    ldy #sMachine::Status_eDiagram
    lda (Zp_Current_sMachine_ptr), y
    tay  ; eDiagram value
    lda DataA_Console_DiagramFirstTileId_u8_arr, y
    add T3  ; diagram row
    ldy #kNumDiagramRows
    @loop:
    sta Ram_PpuTransfer_arr + 1, x
    adc #kNumDiagramRows
    inx
    dey
    bne @loop
    beq _Finish  ; unconditional
_WriteBlankRow:
    lda #' '
    ldy #kStatusBoxWidthTiles
    @loop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @loop
_Finish:
    lda T0  ; starting PPU transfer index
    add #kStatusBoxWidthTiles
    tax     ; updated PPU transfer index (return value)
    ldy T1  ; status box row (just to preserve Y)
    rts
.ENDPROC

;;; Writes kNoPowerWidthTiles bytes into a PPU transfer entry with the tile IDs
;;; of the specified row of the "no power" message box.
;;; @param A The needed circuit number (1-7).
;;; @param X PPU transfer array index within an entry's data.
;;; @param Y The console interior row to transfer (0-7).
;;; @return X Updated PPU transfer array index.
.EXPORT FuncA_Console_WriteNeedsPowerTransferData
.PROC FuncA_Console_WriteNeedsPowerTransferData
    sta T0  ; circuit number (1-7)
    ;; Compute the message row and store it in A.
    lda Zp_ConsoleNumInstRows_u8
    sub #kNumNoPowerRows
    div #2
    sta T1  ; num leading blank rows
    tya
    sub T1  ; num leading blank rows
    ;; If the message row is negative, or more than the number of diagram rows,
    ;; then transfer a blank row.
    beq _WriteMessageRow0
    cmp #1
    beq _WriteMessageRow1
    .assert kNumNoPowerRows = 2, error
_WriteBlankRow:
    ldy #kNoPowerWidthTiles
_WriteYSpaces:
    lda #' '
    @loop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @loop
    rts
_WriteMessageRow0:
    ldy #0
    @loop:
    lda _MessageString0_u8_arr, y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #kNoPowerWidthTiles
    blt @loop
    rts
_WriteMessageRow1:
    ;; Write the first portion of the row.
    ldy #0
    @loop:
    lda _MessageString1_u8_arr15, y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #15
    blt @loop
    ;; Write the tile ID for the circuit number.
    lda T0  ; circuit number (1-7)
    .assert '0' & $0f = 0, error
    ora #'0'
    sta Ram_PpuTransfer_arr, x
    inx
    ;; Write the last few spaces.
    ldy #kNoPowerWidthTiles - 16
    .assert kNoPowerWidthTiles - 16 > 0, error
    bne _WriteYSpaces  ; unconditional
_MessageString0_u8_arr:
    .byte "  ERROR: NO POWER  "
    .assert * - _MessageString0_u8_arr = kNoPowerWidthTiles, error
_MessageString1_u8_arr15:
    .byte "    ON CIRCUIT "
    .assert * - _MessageString1_u8_arr15 = 15, error
.ENDPROC

;;;=========================================================================;;;
