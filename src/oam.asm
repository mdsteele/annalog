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

.INCLUDE "cpu.inc"
.INCLUDE "macros.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"

.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

.ZEROPAGE

;;; A byte offset into Ram_Oam_sObj_arr64 pointing to the next unused entry.
;;; This must always be a multiple of .sizeof(sObj).
.EXPORTZP Zp_OamOffset_u8
Zp_OamOffset_u8: .res 1

;;; The screen-space X/Y positions to use for various shape functions below.
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

;;; Moves Zp_ShapePosX_i16 rightwards by the width of one tile.
;;; @preserve X, Y
.EXPORT FuncA_Objects_MoveShapeRightOneTile
.PROC FuncA_Objects_MoveShapeRightOneTile
    lda Zp_ShapePosX_i16 + 0
    add #kTileWidthPx
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    adc #0
    sta Zp_ShapePosX_i16 + 1
    rts
.ENDPROC

;;; Moves Zp_ShapePosX_i16 leftwards by half the width of a tile.
;;; @preserve X, Y
.EXPORT FuncA_Objects_MoveShapeLeftHalfTile
.PROC FuncA_Objects_MoveShapeLeftHalfTile
    lda Zp_ShapePosX_i16 + 0
    sub #kTileWidthPx / 2
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    sbc #0
    sta Zp_ShapePosX_i16 + 1
    rts
.ENDPROC

;;; Moves Zp_ShapePosX_i16 leftwards by the width of one tile.
;;; @preserve X, Y
.EXPORT FuncA_Objects_MoveShapeLeftOneTile
.PROC FuncA_Objects_MoveShapeLeftOneTile
    lda Zp_ShapePosX_i16 + 0
    sub #kTileWidthPx
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    sbc #0
    sta Zp_ShapePosX_i16 + 1
    rts
.ENDPROC

;;; Moves Zp_ShapePosY_i16 downwards by the height of one tile.
;;; @preserve X, Y
.EXPORT FuncA_Objects_MoveShapeDownOneTile
.PROC FuncA_Objects_MoveShapeDownOneTile
    lda Zp_ShapePosY_i16 + 0
    add #kTileHeightPx
    sta Zp_ShapePosY_i16 + 0
    lda Zp_ShapePosY_i16 + 1
    adc #0
    sta Zp_ShapePosY_i16 + 1
    rts
.ENDPROC

;;; Moves Zp_ShapePosY_i16 upwards by the height of one tile.
;;; @preserve X, Y
.EXPORT FuncA_Objects_MoveShapeUpOneTile
.PROC FuncA_Objects_MoveShapeUpOneTile
    lda Zp_ShapePosY_i16 + 0
    sub #kTileHeightPx
    sta Zp_ShapePosY_i16 + 0
    lda Zp_ShapePosY_i16 + 1
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    rts
.ENDPROC

;;; Allocates and sets the X/Y position for a single object.  The top-left
;;; corner of the object is given by Zp_ShapePosX_i16 and Zp_ShapePosY_i16.
;;; These variables will be preserved by this function.
;;;
;;; If the object would be offscreen (or behind the window), then it isn't
;;; allocated (and C is cleared).  Otherwise, the caller should use the
;;; returned OAM byte offset in Y to set the object's flags and tile ID.
;;;
;;; @return C Set if no OAM slot was allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the allocated object.
;;; @preserve X
.EXPORT FuncA_Objects_Alloc1x1Shape
.PROC FuncA_Objects_Alloc1x1Shape
    ;; If the shape is offscreen horizontally, return without allocating any
    ;; objects.
    lda Zp_ShapePosX_i16 + 1
    bne @notVisible
    ;; If the object is offscreen vertically or behind the window, return
    ;; without allocating the object.
    lda Zp_ShapePosY_i16 + 1
    bne @notVisible
    lda Zp_ShapePosY_i16 + 0
    cmp #kScreenHeightPx
    bge @notVisible
    cmp Zp_WindowTop_u8
    blt @visible
    @notVisible:
    sec  ; Set C to indicate that no object was allocated.
    rts
    @visible:
    ;; Set the vertical position of the object.
    sub #1
    ldy Zp_OamOffset_u8
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    ;; Set the horizontal position of the object.
    lda Zp_ShapePosX_i16 + 0
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    ;; Update the OAM offset.
    tya
    add #.sizeof(sObj)
    sta Zp_OamOffset_u8
    clc  ; Clear C to indicate that an object was allocated.
    rts
.ENDPROC

;;; Allocates and sets X/Y positions and flags for a 2x1 grid of objects (that
;;; is, two tiles wide and one tile high), taking into account the window
;;; position and hiding any of the objects as necessary.
;;;
;;; The screen-space top-center of the 2x1 grid is given by Zp_ShapePosX_i16
;;; and Zp_ShapePosY_i16.  These variables will be preserved by this function.
;;;
;;; If both of the objects would be offscreen, then none are allocated (and C
;;; is cleared).  Otherwise, the caller should use the returned OAM byte
;;; offset in Y to set the objects' tile IDs.  If bObj::FlipH was cleared, then
;;; the left object will come first, followed by the right; if bObj::FlipH was
;;; set, then right object will come first instead.
;;;
;;; @param A The Flags_bObj value to set for each object.  If bObj::FlipH is
;;;     included, then the order of the two objects will be reversed.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the four objects.
;;; @preserve X
.EXPORT FuncA_Objects_Alloc2x1Shape
.PROC FuncA_Objects_Alloc2x1Shape
    sta Zp_Tmp2_byte  ; Flags_bObj to set
_ObjectYPositions:
    ;; If the shape is completely offscreen vertically or behind the window,
    ;; return without allocating any objects.
    lda Zp_ShapePosY_i16 + 1
    bne _NotVisible
    lda Zp_ShapePosY_i16 + 0
    cmp #kScreenHeightPx
    bge _NotVisible
    cmp Zp_WindowTop_u8
    bge _NotVisible
    ;; Set the vertical positions of the two objects.
    sub #1
    ldy Zp_OamOffset_u8
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
_RightObjectXPosition:
    ;; Determine the shape's center X position on screen; if the shape is
    ;; completely offscreen to the left, return without allocating any objects.
    lda Zp_ShapePosX_i16 + 1
    bmi _NotVisible
    ;; If the center of the shape is offscreen to the right, hide the
    ;; right-hand object.
    beq @show
    @hide:
    lda #$ff
    bit Zp_Tmp2_byte  ; Flags_bObj to set
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @hideFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    bvc @doneRight  ; unconditional
    @hideFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    bvs @doneRight  ; unconditional
    @show:
    lda Zp_ShapePosX_i16 + 0
    bit Zp_Tmp2_byte  ; Flags_bObj to set
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @showFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    bvc @doneRight  ; unconditional
    @showFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    @doneRight:
_LeftObjectXPosition:
    ;; Determine the shape's left edge X position on screen; if the shape is
    ;; completely offscreen to the right, return without allocating any
    ;; objects.  If the left edge is offscreen to the left, hide the left-hand
    ;; object.
    lda Zp_ShapePosX_i16 + 0
    sub #kTileWidthPx
    sta Zp_Tmp1_byte  ; left X position on screen (lo)
    lda Zp_ShapePosX_i16 + 1
    sbc #0
    beq @show
    bpl _NotVisible
    @hide:
    lda #$ff
    bit Zp_Tmp2_byte  ; Flags_bObj to set
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @hideFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    bvc @doneLeft  ; unconditional
    @hideFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    bvs @doneLeft  ; unconditional
    @show:
    lda Zp_Tmp1_byte  ; left X position on screen (lo)
    bit Zp_Tmp2_byte  ; Flags_bObj to set
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @showFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    bvc @doneLeft  ; unconditional
    @showFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    @doneLeft:
_FinishAllocation:
    ;; Set the object flags.
    lda Zp_Tmp2_byte  ; Flags_bObj to set
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    ;; Update the OAM offset.
    tya
    add #.sizeof(sObj) * 2
    sta Zp_OamOffset_u8
    clc  ; Clear C to indicate that an object was allocated.
    rts
_NotVisible:
    sec  ; Set C to indicate that no objects were allocated.
    rts
.ENDPROC

;;; Allocates and sets X/Y positions and flags for a 2x2 grid of objects,
;;; taking into account the window position and hiding any of the objects as
;;; necessary.
;;;
;;; The screen-space center of the 2x2 grid is given by Zp_ShapePosX_i16 and
;;; Zp_ShapePosY_i16.  These variables will be preserved by this function.
;;;
;;; If all of the objects would be offscreen, then none are allocated (and C
;;; is cleared).  Otherwise, the caller should use the returned OAM byte
;;; offset in Y to set the objects' tile IDs.  If bObj::FlipH and bObj::FlipV
;;; are cleared, then the allocated objects will be in the order: top-left,
;;; bottom-left, top-right, bottom-right.  If one or both of the flip flags
;;; are set, then the objects will be ordered appropriately such that the same
;;; tile IDs can still be set in the same order.
;;;
;;; @param A The Flags_bObj value to set for each object.  If bObj::FlipH is
;;;     included, then the order of the two objects will be reversed.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the four objects.
;;; @preserve X
.EXPORT FuncA_Objects_Alloc2x2Shape
.PROC FuncA_Objects_Alloc2x2Shape
    sta Zp_Tmp2_byte  ; Flags_bObj to set
_ObjectYPositions:
    ;; If the shape is completely offscreen vertically or behind the window,
    ;; return without allocating any objects.
    lda Zp_ShapePosY_i16 + 1
    bne _NotVisible
    lda Zp_ShapePosY_i16 + 0
    sub #kTileHeightPx
    blt @visible
    cmp #kScreenHeightPx
    bge _NotVisible
    cmp Zp_WindowTop_u8
    bge _NotVisible
    @visible:
    ;; Set the vertical positions of the four objects.
    sub #1
    ldy Zp_OamOffset_u8
    bit Zp_Tmp2_byte  ; Flags_bObj to set
    .assert bObj::FlipV = bProc::Negative, error
    bmi @topFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::YPos_u8, y
    bpl @doneTop  ; unconditional
    @topFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
    @doneTop:
    add #kTileHeightPx
    cmp Zp_WindowTop_u8
    blt @bottom
    lda #$ff
    @bottom:
    bit Zp_Tmp2_byte  ; Flags_bObj to set
    .assert bObj::FlipV = bProc::Negative, error
    bmi @bottomFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
    bpl _RightObjectXPositions  ; unconditional
    @bottomFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::YPos_u8, y
    bmi _RightObjectXPositions  ; unconditional
_NotVisible:
    sec  ; Set C to indicate that no objects were allocated.
    rts
_RightObjectXPositions:
    ;; Determine the shape's center X position on screen; if the shape is
    ;; completely offscreen to the left, return without allocating any objects.
    lda Zp_ShapePosX_i16 + 1
    bmi _NotVisible
    ;; If the center of the shape is offscreen to the right, hide the two
    ;; right-hand objects.
    beq @show
    @hide:
    lda #$ff
    bit Zp_Tmp2_byte  ; Flags_bObj to set
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @hideFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
    bvc @doneRight  ; unconditional
    @hideFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    bvs @doneRight  ; unconditional
    @show:
    lda Zp_ShapePosX_i16 + 0
    bit Zp_Tmp2_byte  ; Flags_bObj to set
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @showFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::XPos_u8, y
    bvc @doneRight  ; unconditional
    @showFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    @doneRight:
_LeftObjectXPositions:
    ;; Determine the shape's left edge X position on screen; if the shape is
    ;; completely offscreen to the right, return without allocating any
    ;; objects.  If the left edge is offscreen to the left, hide the two
    ;; left-hand objects.
    lda Zp_ShapePosX_i16 + 0
    sub #kTileWidthPx
    sta Zp_Tmp1_byte  ; left X position on screen (lo)
    lda Zp_ShapePosX_i16 + 1
    sbc #0
    beq @show
    bpl _NotVisible
    @hide:
    lda #$ff
    bit Zp_Tmp2_byte  ; Flags_bObj to set
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @hideFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    bvc @doneLeft  ; unconditional
    @hideFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
    bvs @doneLeft  ; unconditional
    @show:
    lda Zp_Tmp1_byte  ; left X position on screen (lo)
    bit Zp_Tmp2_byte  ; Flags_bObj to set
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @showFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    bvc @doneLeft  ; unconditional
    @showFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::XPos_u8, y
    @doneLeft:
_FinishAllocation:
    ;; Set the object flags.
    lda Zp_Tmp2_byte  ; Flags_bObj to set
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    ;; Update the OAM offset.
    tya
    add #.sizeof(sObj) * 4
    sta Zp_OamOffset_u8
    clc  ; Clear C to indicate that objects were allocated.
    rts
.ENDPROC

;;;=========================================================================;;;
