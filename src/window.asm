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
.INCLUDE "irq.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"
.INCLUDE "window.inc"

.IMPORT Ppu_ChrBgFontUpper
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_NextIrq_int_ptr
.IMPORTZP Zp_PpuTransferLen_u8

;;;=========================================================================;;;

.ASSERT kWindowStartRow + kWindowMaxNumRows = kScreenHeightTiles, error

;;; The PPU address in the lower nametable for the leftmost tile column of the
;;; window start row.
.EXPORT Ppu_WindowTopLeft
.LINECONT +
Ppu_WindowTopLeft := Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * kWindowStartRow
.LINECONT -

;;;=========================================================================;;;

.ZEROPAGE

;;; The screen pixel Y coordinate for the top edge of the window.  Set this to
;;; kScreenHeightPx or greater to hide the window.  An object that should not
;;; be visible within the window should not be drawn if its Y position is
;;; greater than or equal to this.
.EXPORTZP Zp_WindowTop_u8
Zp_WindowTop_u8: .res 1

;;; Stores the goal value for Zp_WindowTop_u8 while scrolling the window.
.EXPORTZP Zp_WindowTopGoal_u8
Zp_WindowTopGoal_u8: .res 1

;;; The index of the next window row that needs to be transferred to the PPU as
;;; the window scrolls in.
.EXPORTZP Zp_WindowNextRowToTransfer_u8
Zp_WindowNextRowToTransfer_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Sets Zp_WindowTop_u8 to put the window offscreen, then calls
;;; Func_Window_SetUpIrq.
.EXPORT Func_Window_Disable
.PROC Func_Window_Disable
    lda #$ff
    sta Zp_WindowTop_u8
    .assert * = Func_Window_SetUpIrq, error, "fallthrough"
.ENDPROC

;;; Populates Ram_Buffered_sIrq appropriately for the current value of
;;; Zp_WindowTop_u8.  This should be called whenever Zp_WindowTop_u8 is
;;; changed.
.EXPORT Func_Window_SetUpIrq
.PROC Func_Window_SetUpIrq
    lda #0
    sta Zp_Buffered_sIrq + sIrq::Param1_byte
    sta Zp_Buffered_sIrq + sIrq::Param2_byte
    sta Zp_Buffered_sIrq + sIrq::Param3_byte
    sta Zp_Buffered_sIrq + sIrq::Param4_byte
    ldy Zp_WindowTop_u8
    cpy #kScreenHeightPx
    bge _Disable
_Enable:
    dey
    sty Zp_Buffered_sIrq + sIrq::Latch_u8
    ldax #Int_WindowTopIrq
    stax Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr
    rts
_Disable:
    lda #$ff
    sta Zp_Buffered_sIrq + sIrq::Latch_u8
    ldax #Int_NoopIrq
    stax Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr
    rts
.ENDPROC

;;; Scrolls the window up a bit; call this each frame while the window is
;;; opening.
;;; @param A The number of pixels to scroll the window by.
;;; @return C Set if the window is now fully scrolled in.
.EXPORT Func_Window_ScrollUp
.PROC Func_Window_ScrollUp
    rsub Zp_WindowTop_u8
    cmp Zp_WindowTopGoal_u8
    bge @notDone
    lda Zp_WindowTopGoal_u8
    @notDone:
    sta Zp_WindowTop_u8
    lda Zp_WindowTopGoal_u8
    cmp Zp_WindowTop_u8  ; clears C if Zp_WindowTopGoal_u8 < Zp_WindowTop_u8
    rts
.ENDPROC

;;; Scrolls the window down a bit; call this each frame while the window is
;;; closing.
;;; @param A The number of pixels to scroll the window by.
;;; @return C Set if the window is now fully scrolled out.
.EXPORT Func_Window_ScrollDown
.PROC Func_Window_ScrollDown
    add Zp_WindowTop_u8
    cmp #kScreenHeightPx
    blt @notDone
    lda #$ff
    @notDone:
    sta Zp_WindowTop_u8
    rts
.ENDPROC

;;; Draws the top border of the window directly into the nametable.
;;; @prereq Rendering is disabled.
.EXPORT Func_Window_DirectDrawTopBorder
.PROC Func_Window_DirectDrawTopBorder
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldax #Ppu_WindowTopLeft
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda #' '
    sta Hw_PpuData_rw
    lda #kTileIdBgWindowTopLeft
    sta Hw_PpuData_rw
    lda #kTileIdBgWindowHorz
    ldx #kScreenWidthTiles - 4
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
    lda #kTileIdBgWindowTopRight
    sta Hw_PpuData_rw
    ;; At this point, X is zero (from exiting the loop), which conveniently
    ;; just happens to be the tile ID we want to draw next.
    .assert ' ' = 0, error
    stx Hw_PpuData_rw
    rts
.ENDPROC

;;; Appends a new PPU transfer entry to draw the bottom border of the window at
;;; the next row.
.EXPORT Func_Window_TransferBottomBorder
.PROC Func_Window_TransferBottomBorder
    jsr Func_Window_PrepareRowTransfer  ; returns X
    lda #' '
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kTileIdBgWindowBottomLeft
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kTileIdBgWindowHorz
    ldy #kScreenWidthTiles - 4
    @loop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @loop
    lda #kTileIdBgWindowBottomRight
    sta Ram_PpuTransfer_arr, x
    inx
    lda #' '
    sta Ram_PpuTransfer_arr, x
    rts
.ENDPROC

;;; Appends a new PPU transfer entry to fully clear the next window row.
.EXPORT Func_Window_TransferClearRow
.PROC Func_Window_TransferClearRow
    jsr Func_Window_PrepareRowTransfer  ; returns X
    lda #' '
    ldy #kScreenWidthTiles
    @loop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @loop
    rts
.ENDPROC

;;; Sets up a new PPU transfer entry to write kScreenWidthTiles tiles to the
;;; nametable for the next window row.  This function writes the entry header,
;;; increments Zp_WindowNextRowToTransfer_u8, updates Zp_PpuTransferLen_u8, and
;;; then returns the starting index for the data, which the caller can then
;;; fill in.
;;; @prereq Zp_WindowNextRowToTransfer_u8 has been set.
;;; @return X The index into Ram_PpuTransfer_arr for the start of the data.
.EXPORT Func_Window_PrepareRowTransfer
.PROC Func_Window_PrepareRowTransfer
    lda Zp_WindowNextRowToTransfer_u8  ; param: window tile row
    inc Zp_WindowNextRowToTransfer_u8
    ;; Get the transfer destination address, and store it in T0 (hi) and Y
    ;; (lo).
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    stx T0  ; transfer destination (hi)
    ;; Update Zp_PpuTransferLen_u8.
    ldx Zp_PpuTransferLen_u8
    txa
    add #4 + kScreenWidthTiles
    sta Zp_PpuTransferLen_u8
    ;; Write the transfer entry header.
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr, x
    inx
    lda T0  ; transfer destination (hi)
    sta Ram_PpuTransfer_arr, x
    inx
    tya     ; transfer destination (lo)
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kScreenWidthTiles
    sta Ram_PpuTransfer_arr, x
    inx
    rts
.ENDPROC

;;; Given a window row index, returns the PPU address for that window row.
;;; @param A The window tile row, from 0 (inclusive) to kWindowMaxNumRows
;;;     (exclusive).
;;; @return XY The PPU address.
.EXPORT Func_Window_GetRowPpuAddr
.PROC Func_Window_GetRowPpuAddr
    ldx #0
    stx T0
    ;; First, we need to multiply the window row (A) by kScreenWidthTiles to
    ;; get the address offset from the top of the window.  Since we're
    ;; multiplying by kScreenWidthTiles = $20, we need five ASL instructions.
    .assert kScreenWidthTiles = $20, error
    .repeat 5
    asl a
    .endrepeat
    ;; Since kWindowMaxNumRows is a four-bit number, we do need to ROL the hi
    ;; byte after the fifth ASL, but not after any of the earlier ones.
    .assert kWindowMaxNumRows <= $10, error
    .assert kWindowMaxNumRows > $8, error
    rol T0
    ;; Add the offset we just calculated to the start address for the window.
    add #<Ppu_WindowTopLeft
    tay  ; return value (lo)
    lda T0
    adc #>Ppu_WindowTopLeft
    tax  ; return value (hi)
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; Acks the current HBlank IRQ, and sets up the next IRQ for the top of the
;;; window, using Param4_byte from Zp_Active_sIrq as the latch value.  This
;;; should only be called from within an IRQ handler.
;;; @preserve X, Y, T0+
.EXPORT Func_AckIrqAndLatchWindowFromParam4
.PROC Func_AckIrqAndLatchWindowFromParam4
    ;; Update Zp_NextIrq_int_ptr for the next IRQ.
    lda #<Int_WindowTopIrq
    sta Zp_NextIrq_int_ptr + 0
    lda #>Int_WindowTopIrq
    sta Zp_NextIrq_int_ptr + 1
    ;; Ack and set latch for the window.
    lda Zp_Active_sIrq + sIrq::Param4_byte  ; window latch
    .assert * = Func_AckIrqAndSetLatch, error, "fallthrough"
.ENDPROC

;;; Acks the current HBlank IRQ, writes a new latch value, and then immediately
;;; reloads the latch.
;;; @param A The value to write to Hw_Mmc3IrqLatch_wo.
;;; @preserve X, Y, T0+
.EXPORT Func_AckIrqAndSetLatch
.PROC Func_AckIrqAndSetLatch
    ;; Ack the current IRQ.
    sta Hw_Mmc3IrqDisable_wo  ; ack
    sta Hw_Mmc3IrqEnable_wo  ; re-enable
    ;; Set up the latch value for next IRQ.
    sta Hw_Mmc3IrqLatch_wo
    sta Hw_Mmc3IrqReload_wo
    rts
.ENDPROC

;;; HBlank IRQ handler function for the top edge of the window.  Sets the PPU
;;; scroll so as to display the window, and disables drawing objects over the
;;; window's top border, so that it looks like the window is in front of any
;;; objects in the room.
.PROC Int_WindowTopIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Set up the
    ;; next IRQ.
    lda #kTileHeightPx - 1  ; param: latch value
    jsr Func_AckIrqAndSetLatch  ; preserves Y
    ldax #Int_WindowInteriorIrq
    stax Zp_NextIrq_int_ptr
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #7  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the upper
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #$0c  ; nametable number << 2 (so $0c for nametable 3)
    sta Hw_PpuAddr_w2
    lda #kWindowStartRow * kTileHeightPx  ; new scroll-Y value
    sta Hw_PpuScroll_w2
    and #$38
    asl a
    asl a
    ;; We should now be in the second HBlank (and X is zero).
    stx Hw_PpuScroll_w2  ; new scroll-X value (zero)
    sta Hw_PpuAddr_w2    ; ((Y & $38) << 2) | (X >> 3)
    ;; Disable drawing objects for now.
    lda #bPpuMask::BgMain
    sta Hw_PpuMask_wo
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;; HBlank IRQ handler function for the bottom edge of the window's top border
;;; (i.e. the top edge of the window interior).  Re-enables object rendering,
;;; so that objects can be displayed inside the window.
.PROC Int_WindowInteriorIrq
    ;; Save the A register (we won't be using X or Y).
    pha
    ;; At this point, the first HBlank is already just about over.  Set up the
    ;; next IRQ.
    lda #kTileHeightPx * (kWindowMaxNumRows - 2)  ; param: latch value
    jsr Func_AckIrqAndSetLatch  ; preserves X and Y
    lda #<Int_WindowBottomIrq
    sta Zp_NextIrq_int_ptr + 0
    lda #>Int_WindowBottomIrq
    sta Zp_NextIrq_int_ptr + 1
    ;; Set the CHR04 bank (which is normally used for animated terrain) to
    ;; instead hold font tiles that are only needed within the window.  That
    ;; bank setting will be restored for the next frame during VBlank.
    irq_chr04_bank Ppu_ChrBgFontUpper
    ;; Busy-wait for a bit, so that our final write in this function will occur
    ;; during the next HBlank (between dots 256 and 320).
    lda #5  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    sub #1
    bne @busyLoop
    ;; Re-enable drawing of objects.
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Hw_PpuMask_wo
    ;; Restore the A register and return.
    pla
    rti
.ENDPROC

;;; HBlank IRQ handler function for the bottom of the window's maximum size
;;; (not counting the blank rows below the window border).  Disables BG
;;; rendering, so that the top row of the upper nametable will not be visible
;;; at the bottom of the screen when a max-sized window is fully scrolled in.
.PROC Int_WindowBottomIrq
    ;; Save the A register and update the PPU mask as quickly as possible.
    pha
    lda #bPpuMask::ObjMain
    sta Hw_PpuMask_wo
    ;; No more IRQs for the rest of this frame.
    lda #$ff
    sta Hw_Mmc3IrqLatch_wo
    sta Hw_Mmc3IrqReload_wo
    ;; Restore the A register and finish.
    pla
    .assert * = Int_NoopIrq, error, "fallthrough"
.ENDPROC

;;; HBlank IRQ handler function that does nothing other than ack the IRQ.
.EXPORT Int_NoopIrq
.PROC Int_NoopIrq
    ;; Ack the current IRQ.
    sta Hw_Mmc3IrqDisable_wo  ; ack
    sta Hw_Mmc3IrqEnable_wo  ; re-enable
    rti
.ENDPROC

;;;=========================================================================;;;
