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
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"

.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

.ZEROPAGE

;;; A byte offset into Ram_Oam_sObj_arr64 pointing to the next unused entry.
;;; This must always be a multiple of .sizeof(sObj).
.EXPORTZP Zp_OamOffset_u8
Zp_OamOffset_u8: .res 1

;;; The screen-space X/Y positions to use for Func_AllocObjectsFor2x2Shape.
.EXPORTZP Zp_ShapePosX_i16, Zp_ShapePosY_i16
Zp_ShapePosX_i16: .res 2
Zp_ShapePosY_i16: .res 2

;;;=========================================================================;;;

.SEGMENT "RAM_Oam"

.EXPORT Ram_Oam_sObj_arr64
Ram_Oam_sObj_arr64: .res .sizeof(sObj) * kNumOamSlots
.ASSERT kNumOamSlots = 64, error

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Clears all remaining object entries in Ram_Oam_sObj_arr64, starting with
;;; the one indicated by Zp_OamOffset_u8, then sets Zp_OamOffset_u8 to zero.
.EXPORT Func_ClearRestOfOam
.PROC Func_ClearRestOfOam
    lda #$ff
    ;; Zp_OamOffset_u8 is assumed to hold a multiple of .sizeof(sObj).
    ldy Zp_OamOffset_u8
    @loop:
    ;; Hide the object by setting its Y-position to offscreen.
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    ;; Advance to the next object.
    .repeat .sizeof(sObj)
    iny
    .endrepeat
    ;; OAM is exactly $100 bytes, so when Y wraps around to zero, we are done.
    .assert .sizeof(sObj) * 64 = $100, error
    bne @loop
    sty Zp_OamOffset_u8
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and sets X/Y positions for a 2x2 grid of objects, taking into
;;; account the window position and hiding any of the objects as necessary.
;;;
;;; The screen-space center of the 2x2 grid is given by Zp_ShapePosX_i16 and
;;; Zp_ShapePosY_i16.  These variables will be preserved by this function.
;;;
;;; If all of the objects would be offscreen, then none are allocated (and C is
;;; cleared).  Otherwise, the caller should use the returned OAM byte offset in
;;; Y to set the objects' flags and tile IDs; the allocated objects will be in
;;; the order: top-left, bottom-left, top-right, bottom-right.
;;;
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the four objects.
;;; @preserve X
.EXPORT FuncA_Objects_Alloc2x2Shape
.PROC FuncA_Objects_Alloc2x2Shape
    ldy Zp_OamOffset_u8
_ObjectYPositions:
    ;; If the shape is completely offscreen vertically or behind the window,
    ;; return without allocating any objects.
    lda Zp_ShapePosY_i16 + 1
    bne _NotVisible
    lda Zp_ShapePosY_i16 + 0
    sub #kTileHeightPx
    cmp #kScreenHeightPx
    bge _NotVisible
    cmp Zp_WindowTop_u8
    bge _NotVisible
    ;; Set the vertical positions of the four objects.
    sub #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::YPos_u8, y
    add #kTileHeightPx
    cmp Zp_WindowTop_u8
    blt @bottom
    lda #$ff
    @bottom:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
_ObjectXPositions:
    ;; Determine the shape's center X position on screen; if the shape is
    ;; completely offscreen to the left, return without allocating any objects.
    lda Zp_ShapePosX_i16 + 1
    bmi _NotVisible
    ;; If the center of the shape is offscreen to the right, hide the two
    ;; right-hand objects.
    beq @rightSide
    lda #$ff
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
    @rightSide:
    lda Zp_ShapePosX_i16 + 0
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::XPos_u8, y
    ;; Determine the shape's left edge X position on screen; if the shape is
    ;; completely offscreen to the right, return without allocating any
    ;; objects.  If the left edge is offscreen to the left, hide the two
    ;; left-hand objects.
    sub #kTileWidthPx
    sta Zp_Tmp1_byte  ; left X position on screen (lo)
    lda Zp_ShapePosX_i16 + 1
    sbc #0
    beq @leftSide
    bpl _NotVisible
    lda #$ff
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    @leftSide:
    lda Zp_Tmp1_byte  ; left X position on screen (lo)
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
_FinishAllocation:
    tya
    add #.sizeof(sObj) * 4
    sta Zp_OamOffset_u8
    clc  ; Clear C to indicate that objects were allocated.
    rts
_NotVisible:
    sec  ; Set C to indicate that no objects were allocated.
    rts
.ENDPROC

;;;=========================================================================;;;
