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

.INCLUDE "macros.inc"
.INCLUDE "ppu.inc"
.INCLUDE "window.inc"

.IMPORT Func_Window_GetRowPpuAddr
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte

;;;=========================================================================;;;

;;; The height of the console status box diagram, in tiles.
kNumDiagramRows = 4

;;; The width of the console status box, in tiles.
kStatusBoxWidthTiles = 8

;;; The leftmost nametable tile column in the console status box.
kStatusBoxStartTileColumn = 22

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; Appends PPU transfer entries to redraw all rows in the console status box.
.EXPORT FuncA_Console_TransferAllStatusRows
.PROC FuncA_Console_TransferAllStatusRows
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
;;; @param Y The status box row to transfer (0-7).
;;; @preserve Y
.PROC FuncA_Console_TransferStatusRow
    tya
    pha
    ;; Get the transfer destination address, and store it in Zp_Tmp1_byte (lo)
    ;; and Zp_Tmp2_byte (hi).
    iny  ; add 1 for the top border
    tya  ; param: window row
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    tya
    add #kStatusBoxStartTileColumn
    sta Zp_Tmp1_byte  ; transfer destination (lo)
    txa
    adc #0
    sta Zp_Tmp2_byte  ; transfer destination (hi)
    ;; Update Zp_PpuTransferLen_u8.
    ldx Zp_PpuTransferLen_u8
    txa
    add #4 + kStatusBoxWidthTiles
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
;;; @param X PPU transfer array index within an entry's data.
;;; @param Y The status box row to transfer (0-7).
;;; @return X Updated PPU transfer array index.
;;; @preserve Y
.EXPORT FuncA_Console_WriteStatusTransferData
.PROC FuncA_Console_WriteStatusTransferData
    stx Zp_Tmp1_byte  ; starting PPU transfer index
    sty Zp_Tmp2_byte  ; status box row
    ;; Compute the diagram row and store it in A.
    lda Zp_ConsoleNumInstRows_u8
    sub #kNumDiagramRows
    div #2
    sta Zp_Tmp3_byte  ; num leading blank rows
    lda Zp_Tmp2_byte  ; status box row
    sub Zp_Tmp3_byte  ; num leading blank rows
    ;; If the diagram row is negative, or more than the number of diagram rows,
    ;; then transfer a blank row.
    bmi _WriteBlankRow
    cmp #kNumDiagramRows
    bge _WriteBlankRow
_WriteDiagramRow:
    tay  ; diagram row
    ;; Draw the blank margin on either side of the diagram.
    .assert kStatusBoxWidthTiles = 8, error
    lda #kWindowTileIdBlank
    sta Ram_PpuTransfer_arr + 0, x
    sta Ram_PpuTransfer_arr + 1, x
    sta Ram_PpuTransfer_arr + 6, x
    sta Ram_PpuTransfer_arr + 7, x
    ;; Draw the diagram itself.
    tya  ; diagram row
    add #$60
    ldy #kNumDiagramRows
    @loop:
    sta Ram_PpuTransfer_arr + 2, x
    adc #kNumDiagramRows
    inx
    dey
    bne @loop
    beq _WriteRegisters  ; unconditional
_WriteBlankRow:
    lda #kWindowTileIdBlank
    ldy #kStatusBoxWidthTiles
    @loop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @loop
_WriteRegisters:
    ;; TODO: Write any register values that should appear on this status row.
    lda Zp_Tmp1_byte  ; starting PPU transfer index
    add #kStatusBoxWidthTiles
    tax
    ldy Zp_Tmp2_byte  ; status box row
    rts
.ENDPROC

;;;=========================================================================;;;
