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

.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

.ZEROPAGE

;;; A byte offset into Ram_Oam_sObj_arr64 pointing to the next unused entry.
;;; This must always be a multiple of .sizeof(sObj).
Zp_OamOffset_u8: .res 1

;;; The screen-space X/Y positions to use for various shape functions below.
.EXPORTZP Zp_ShapePosX_i16
Zp_ShapePosX_i16: .res 2
.EXPORTZP Zp_ShapePosY_i16
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

;;; Allocates a single OAM slot, and returns the byte offset into
;;; Ram_Oam_sObj_arr64 for the allocated slot.
;;; @return Y The OAM byte offset for the allocated object.
;;; @preserve X, T0+
.EXPORT Func_AllocOneObject
.PROC Func_AllocOneObject
    lda #1  ; param: num objects
    fall Func_AllocObjects
.ENDPROC

;;; Allocates a number of contiguous OAM slots, and returns the byte offset
;;; into Ram_Oam_sObj_arr64 for the first allocated slot.
;;; @param A The number of OAM slots to allocate.
;;; @return Y The OAM byte offset for the first of the allocated objects.
;;; @preserve X, T0+
.EXPORT Func_AllocObjects
.PROC Func_AllocObjects
    ldy Zp_OamOffset_u8
    mul #.sizeof(sObj)
    adc Zp_OamOffset_u8  ; carry will already be clear from the multiply
    sta Zp_OamOffset_u8
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Moves Zp_ShapePosX_i16 by the given signed number of pixels (positive for
;;; right, negative for left).
;;; @param A The number of pixels to shift by (signed).
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeHorz
.PROC FuncA_Objects_MoveShapeHorz
    ora #0
    bpl FuncA_Objects_MoveShapeRightByA  ; preserves X, Y, and T0+
    clc  ; param: carry bit
    bcc FuncA_Objects_MoveShapeHorzNegative  ; unconditional
.ENDPROC

;;; Moves Zp_ShapePosX_i16 rightwards by half the width of a tile.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeRightHalfTile
.PROC FuncA_Objects_MoveShapeRightHalfTile
    lda #kTileWidthPx / 2  ; param: offset
    bne FuncA_Objects_MoveShapeRightByA  ; unconditional
.ENDPROC

;;; Moves the shape position down and right by the size of one tile.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.PROC FuncA_Objects_MoveShapeDownAndRightOneTile
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X, Y, and T0+
    fall FuncA_Objects_MoveShapeRightOneTile
.ENDPROC

;;; Moves Zp_ShapePosX_i16 rightwards by the width of one tile.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeRightOneTile
.PROC FuncA_Objects_MoveShapeRightOneTile
    lda #kTileWidthPx  ; param: offset
    fall FuncA_Objects_MoveShapeRightByA
.ENDPROC

;;; Moves Zp_ShapePosX_i16 rightwards by the given number of pixels.
;;; @param A The number of pixels to shift right by (unsigned).
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeRightByA
.PROC FuncA_Objects_MoveShapeRightByA
    add Zp_ShapePosX_i16 + 0
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    adc #0
    sta Zp_ShapePosX_i16 + 1
    rts
.ENDPROC

;;; Moves Zp_ShapePosX_i16 leftwards by half the width of a tile.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeLeftHalfTile
.PROC FuncA_Objects_MoveShapeLeftHalfTile
    lda #kTileWidthPx / 2  ; param: offset
    bne FuncA_Objects_MoveShapeLeftByA  ; unconditional
.ENDPROC

;;; Moves Zp_ShapePosX_i16 leftwards by the width of one tile.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeLeftOneTile
.PROC FuncA_Objects_MoveShapeLeftOneTile
    lda #kTileWidthPx  ; param: offset
    fall FuncA_Objects_MoveShapeLeftByA
.ENDPROC

;;; Moves Zp_ShapePosX_i16 leftwards by the given number of pixels.
;;; @param A The number of pixels to shift left by (unsigned).
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeLeftByA
.PROC FuncA_Objects_MoveShapeLeftByA
    eor #$ff  ; param: negative offset
    sec  ; param: carry bit
    fall FuncA_Objects_MoveShapeHorzNegative
.ENDPROC

;;; Helper function for FuncA_Objects_MoveShapeHorz and
;;; FuncA_Objects_MoveShapeLeftByA.
;;; @param A The negative number of pixels to shift by.
;;; @param C The carry bit to include in the addition.
;;; @preserve X, Y, T0+
.PROC FuncA_Objects_MoveShapeHorzNegative
    adc Zp_ShapePosX_i16 + 0
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    adc #$ff
    sta Zp_ShapePosX_i16 + 1
    rts
.ENDPROC

;;; Moves Zp_ShapePosY_i16 by the given signed number of pixels (positive for
;;; down, negative for up).
;;; @param A The number of pixels to shift by (signed).
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeVert
.PROC FuncA_Objects_MoveShapeVert
    ora #0
    bpl FuncA_Objects_MoveShapeDownByA  ; preserves X, Y, and T0+
    clc  ; param: carry bit
    bcc FuncA_Objects_MoveShapeVertNegative  ; unconditional
.ENDPROC

;;; Moves Zp_ShapePosY_i16 downwards by the height of one tile.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeDownOneTile
.PROC FuncA_Objects_MoveShapeDownOneTile
    lda #kTileHeightPx  ; param: offset
    fall FuncA_Objects_MoveShapeDownByA
.ENDPROC

;;; Moves Zp_ShapePosX_i16 downwards by the given number of pixels.
;;; @param A The number of pixels to shift down by (unsigned).
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeDownByA
.PROC FuncA_Objects_MoveShapeDownByA
    add Zp_ShapePosY_i16 + 0
    sta Zp_ShapePosY_i16 + 0
    lda Zp_ShapePosY_i16 + 1
    adc #0
    sta Zp_ShapePosY_i16 + 1
    rts
.ENDPROC

;;; Moves Zp_ShapePosY_i16 upwards by half the height of a tile.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeUpHalfTile
.PROC FuncA_Objects_MoveShapeUpHalfTile
    lda #kTileHeightPx / 2  ; param: offset
    bne FuncA_Objects_MoveShapeUpByA  ; unconditional
.ENDPROC

;;; Moves Zp_ShapePosY_i16 upwards by the height of one tile.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeUpOneTile
.PROC FuncA_Objects_MoveShapeUpOneTile
    lda #kTileHeightPx  ; param: offset
    fall FuncA_Objects_MoveShapeUpByA
.ENDPROC

;;; Moves Zp_ShapePosY_i16 upwards by the given number of pixels.
;;; @param A The number of pixels to shift up by (unsigned).
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_MoveShapeUpByA
.PROC FuncA_Objects_MoveShapeUpByA
    eor #$ff
    sec
    fall FuncA_Objects_MoveShapeVertNegative
.ENDPROC

;;; Helper function for FuncA_Objects_MoveShapeVert and
;;; FuncA_Objects_MoveShapeUpByA.
;;; @param A The negative number of pixels to shift by.
;;; @param C The carry bit to include in the addition.
;;; @preserve X, Y, T0+
.PROC FuncA_Objects_MoveShapeVertNegative
    adc Zp_ShapePosY_i16 + 0
    sta Zp_ShapePosY_i16 + 0
    lda Zp_ShapePosY_i16 + 1
    adc #$ff
    sta Zp_ShapePosY_i16 + 1
    rts
.ENDPROC

;;; Allocates and sets X/Y positions and flags for a 1x2 grid of objects (that
;;; is, one tile wide and two tiles high), taking into account the window
;;; position and hiding any of the objects as necessary.
;;;
;;; The screen-space center-left of the 1x2 grid is given by Zp_ShapePosX_i16
;;; and Zp_ShapePosY_i16.  These variables will be preserved by this function.
;;;
;;; If both of the objects would be offscreen, then none are allocated (and C
;;; is cleared).  Otherwise, the caller should use the returned OAM byte
;;; offset in Y to set the objects' tile IDs.  If bObj::FlipV was cleared, then
;;; the top object will come first, followed by the bottom; if bObj::FlipV was
;;; set, then bottom object will come first instead.
;;;
;;; @param A The Flags_bObj value to set for each object.  If bObj::FlipV is
;;;     included, then the order of the two objects will be reversed.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the two objects.
;;; @preserve X, T2+
.PROC FuncA_Objects_Alloc1x2Shape
    sta T0  ; Flags_bObj to set
    ;; If the shape is offscreen horizontally, return without allocating any
    ;; objects.
    lda Zp_ShapePosX_i16 + 1
    bne _NotVisible
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
    ;; Set the vertical positions of the two objects.
    sub #1
    ldy Zp_OamOffset_u8
    bit T0  ; Flags_bObj to set
    .assert bObj::FlipV = bProc::Negative, error
    bmi @topFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    bpl @doneTop  ; unconditional
    @topFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    @doneTop:
    add #kTileHeightPx
    cmp Zp_WindowTop_u8
    blt @bottom
    lda #$ff
    @bottom:
    bit T0  ; Flags_bObj to set
    .assert bObj::FlipV = bProc::Negative, error
    bmi @bottomFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    bpl _ObjectXPositions  ; unconditional
    @bottomFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    bmi _ObjectXPositions  ; unconditional
_NotVisible:
    sec  ; Set C to indicate that no objects were allocated.
    rts
_ObjectXPositions:
    lda Zp_ShapePosX_i16 + 0
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
_FinishAllocation:
    ;; Set the object flags.
    lda T0  ; Flags_bObj to set
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    ;; Update the OAM offset.
    tya
    add #.sizeof(sObj) * 2
    sta Zp_OamOffset_u8
    clc  ; Clear C to indicate that objects were allocated.
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
;;; @return Y The OAM byte offset for the first of the two objects.
;;; @preserve X, T2+
.EXPORT FuncA_Objects_Alloc2x1Shape
.PROC FuncA_Objects_Alloc2x1Shape
    sta T1  ; Flags_bObj to set
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
    bit T1  ; Flags_bObj to set
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @hideFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    bvc @doneRight  ; unconditional
    @hideFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    bvs @doneRight  ; unconditional
    @show:
    lda Zp_ShapePosX_i16 + 0
    bit T1  ; Flags_bObj to set
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
    sta T0  ; left X position on screen (lo)
    lda Zp_ShapePosX_i16 + 1
    sbc #0
    beq @show
    bpl _NotVisible
    @hide:
    lda #$ff
    bit T1  ; Flags_bObj to set
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @hideFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    bvc @doneLeft  ; unconditional
    @hideFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    bvs @doneLeft  ; unconditional
    @show:
    lda T0  ; left X position on screen (lo)
    bit T1  ; Flags_bObj to set
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @showFlipped
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    bvc @doneLeft  ; unconditional
    @showFlipped:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    @doneLeft:
_FinishAllocation:
    ;; Set the object flags.
    lda T1  ; Flags_bObj to set
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
;;; @param A The Flags_bObj value to set for each object.  If bObj::FlipH
;;;     and/or FlipV is set, then the order of the objects will be flipped.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the four objects.
;;; @preserve X, T2+
.EXPORT FuncA_Objects_Alloc2x2Shape
.PROC FuncA_Objects_Alloc2x2Shape
    sta T1  ; Flags_bObj to set
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
    bit T1  ; Flags_bObj to set
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
    bit T1  ; Flags_bObj to set
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
    bit T1  ; Flags_bObj to set
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
    bit T1  ; Flags_bObj to set
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
    sta T0  ; left X position on screen (lo)
    lda Zp_ShapePosX_i16 + 1
    sbc #0
    beq @show
    bpl _NotVisible
    @hide:
    lda #$ff
    bit T1  ; Flags_bObj to set
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
    lda T0  ; left X position on screen (lo)
    bit T1  ; Flags_bObj to set
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
    lda T1  ; Flags_bObj to set
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

;;; Draws a 1x1 shape with its top-left corner at the current shape position,
;;; using the given tile ID and object flags.  The caller can then further
;;; modify the object if needed.
;;; @param A The tile ID to set for the object.
;;; @param Y The Flags_bObj value to set for the object.
;;; @return C Set if no OAM slot was allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the allocated object.
;;; @preserve X, T2+
.EXPORT FuncA_Objects_Draw1x1Shape
.PROC FuncA_Objects_Draw1x1Shape
    sta T0  ; tile ID
    sty T1  ; object flags
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
    ;; Set the object's tile ID and flags.
    lda T0  ; tile ID
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda T1  ; object flags
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    ;; Update the OAM offset.
    tya
    add #.sizeof(sObj)
    sta Zp_OamOffset_u8
    clc  ; Clear C to indicate that an object was allocated.
    rts
.ENDPROC

;;; Draws a 1x2 shape with its center-left point on the current shape position,
;;; using the given first tile ID and the subsequent tile ID.  The caller can
;;; then further modify the objects if needed.
;;; @param A The first tile ID.
;;; @param Y The Flags_bObj value to set for each object.  If bObj::FlipV is
;;;     is set, then the order of the objects will be flipped.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the two objects.
;;; @preserve X, T2+
.EXPORT FuncA_Objects_Draw1x2Shape
.PROC FuncA_Objects_Draw1x2Shape
    pha  ; first tile ID
    tya  ; param: object flags
    jsr FuncA_Objects_Alloc1x2Shape  ; preserves X and T2+, returns C and Y
    pla  ; first tile ID
    bcc FuncA_Objects_SetTwoTileIdsForShape
    rts
.ENDPROC

;;; Draws a 2x1 shape with its top-center point on the current shape position,
;;; using the given first tile ID and the subsequent tile ID.  The caller can
;;; then further modify the objects if needed.
;;; @param A The first tile ID.
;;; @param Y The Flags_bObj value to set for each object.  If bObj::FlipH is
;;;     is set, then the order of the objects will be flipped.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the two objects.
;;; @preserve X, T2+
.EXPORT FuncA_Objects_Draw2x1Shape
.PROC FuncA_Objects_Draw2x1Shape
    pha  ; first tile ID
    tya  ; param: object flags
    jsr FuncA_Objects_Alloc2x1Shape  ; preserves X and T2+, returns C and Y
    pla  ; first tile ID
    bcc FuncA_Objects_SetTwoTileIdsForShape
    rts
.ENDPROC

;;; Private helper function for FuncA_Objects_Draw1x2Shape and
;;; FuncA_Objects_Draw2x1Shape.  Sets tile IDs for two objects.
;;; @prereq C is cleared.
;;; @param A The first tile ID.
;;; @param Y The OAM byte offset for the first of the two objects.
;;; @preserve X, Y, T0+
.PROC FuncA_Objects_SetTwoTileIdsForShape
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #1  ; carry bit is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    rts
.ENDPROC

;;; Draws a 2x2 shape centered on the current shape position, using the given
;;; first tile ID and the three subsequent tile IDs.  The caller can then
;;; further modify the objects if needed.
;;; @param A The first tile ID.
;;; @param Y The Flags_bObj value to set for each object.  If bObj::FlipH
;;;     and/or FlipV is set, then the order of the objects will be flipped.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the four objects.
;;; @preserve X, T2+
.EXPORT FuncA_Objects_Draw2x2Shape
.PROC FuncA_Objects_Draw2x2Shape
    pha  ; first tile ID
    tya  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X and T2+, returns C and Y
    pla  ; first tile ID
    bcs @done
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #1  ; carry bit is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Draws a 2x2 shape centered on the current shape position, using the given
;;; tile ID for all four objects, mirroring each around the shape position.
;;; The caller can then further modify the objects if needed.
;;; @param A The tile ID to use for all four objects.
;;; @param Y The Flags_bObj value to set for the top-left object.  The other
;;;     three objects will be mirrored from this starting value.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the four objects.
;;; @preserve X, T3+
.EXPORT FuncA_Objects_Draw2x2MirroredShape
.PROC FuncA_Objects_Draw2x2MirroredShape
    pha  ; tile ID
    sty T2  ; object flags
    tya  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X and T2+, returns C and Y
    pla  ; tile ID
    bcs @done
    ;; Set tile IDs.
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    ;; Set object flags.
    lda T2  ; object flags
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    eor #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    eor #bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    eor #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;; Draws a list of tiles, starting at the current shape position.
;;; @param YA Pointer to the sShapeTile array.
;;; @preserve X
.EXPORT FuncA_Objects_DrawShapeTiles
.PROC FuncA_Objects_DrawShapeTiles
    stya T5T4  ; sShapeTile array pointer
    ldy #0
    @loop:
    .assert sShapeTile::DeltaX_i8 = 0, error
    lda (T5T4), y  ; param: signed offset
    jsr FuncA_Objects_MoveShapeHorz  ; preserves X, Y, and T0+
    iny  ; now Y is 1 mod .sizeof(sShapeTile)
    .assert sShapeTile::DeltaY_i8 = 1, error
    lda (T5T4), y  ; param: signed offset
    jsr FuncA_Objects_MoveShapeVert  ; preserves X, Y, and T0+
    iny  ; now Y is 2 mod .sizeof(sShapeTile)
    .assert sShapeTile::Flags_bObj = 2, error
    lda (T5T4), y
    sta T3  ; object flags
    iny  ; now Y is 3 mod .sizeof(sShapeTile)
    .assert sShapeTile::Tile_u8 = 3, error
    lda (T5T4), y  ; param: tile ID
    sty T2  ; sShapeTile array byte offset
    ldy T3  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    ldy T2  ; sShapeTile array byte offset
    .assert .sizeof(sShapeTile) = 4, error
    iny  ; now Y is 0 mod .sizeof(sShapeTile)
    lda T3  ; object flags
    and #bObj::Final
    beq @loop
    rts
.ENDPROC

;;;=========================================================================;;;
