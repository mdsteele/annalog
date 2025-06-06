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
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "scroll.inc"

.IMPORT FuncA_Terrain_FillNametables
.IMPORT FuncA_Terrain_TransferTileColumn
.IMPORT FuncA_Terrain_UpdateAndMarkMinimap
.IMPORT Func_FillLowerAttributeTable
.IMPORT Func_FillUpperAttributeTable
.IMPORT Func_SetPointToAvatarCenter
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; The higher the number, the more slowly the camera tracks towards the scroll
;;; goal.
.DEFINE kScrollXSlowdown 2
.DEFINE kScrollYSlowdown 2

;;; The maximum speed that the screen is allowed to scroll horizontally and
;;; vertically, in pixels per frame.
kMaxScrollXSpeed = 7
kMaxScrollYSpeed = 4

;;; Don't attempt to scroll horizontally if the PPU transfer buffer already has
;;; this many bytes or more in it (so we don't risk putting more in the buffer
;;; than can be processed in one VBlank).  The specific value chosen for this
;;; limit is somewhat arbitrary; but in particular, it's high to still allow
;;; for transferring a full window row (which takes $24 buffer bytes).
kScrollTransferThreshold = $30

;;;=========================================================================;;;

.ZEROPAGE

;;; The desired horizontal scroll position; i.e. the position, in room-space
;;; pixels, of the left edge of the screen.  Note that this is unsigned, to
;;; simplify the comparison logic (we never want to scroll past the left edge
;;; of the room anyway).  Rooms can be several screens wide, so this needs to
;;; be two bytes.
.EXPORTZP Zp_ScrollGoalX_u16
Zp_ScrollGoalX_u16: .res 2

;;; The desired vertical scroll position; i.e. the position, in room-space
;;; pixels, of the top edge of the screen.  Note that this is unsigned, to
;;; simplify the comparison logic (we never want to scroll past the top edge of
;;; the room anyway).
.EXPORTZP Zp_ScrollGoalY_u8
Zp_ScrollGoalY_u8: .res 1

;;; The current horizontal and vertical scroll position within the room.
.EXPORTZP Zp_RoomScrollX_u16
Zp_RoomScrollX_u16: .res 2
.EXPORTZP Zp_RoomScrollY_u8
Zp_RoomScrollY_u8: .res 1

;;; Scroll lock settings for the camera position.  Normally, the camera
;;; position (that is, Zp_RoomScroll*) will track towards the scroll goal
;;; (Zp_ScrollGoal*) each frame; however, if scrolling is locked horizontally
;;; and/or vertically, then the camera position will stay locked on that axis
;;; (though the scroll goal can continue to update).
.EXPORTZP Zp_Camera_bScroll
Zp_Camera_bScroll: .res 1

;;; If nonzero, the room will shake for this many more frames.
.EXPORTZP Zp_RoomShake_u8
Zp_RoomShake_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Shakes the room for the given number of frames.
;;; @param A How many frames to shake the room for.
;;; @preserve X, Y, T0+
.EXPORT Func_ShakeRoom
.PROC Func_ShakeRoom
    cmp Zp_RoomShake_u8
    blt @done
    sta Zp_RoomShake_u8
    @done:
    rts
.ENDPROC

;;; Sets the scroll goal from the player avatar's position, then updates the
;;; scroll position for next frame to move closer to that goal, transferring
;;; nametable updates for the current room as necessary.
.EXPORT FuncM_ScrollTowardsAvatar
.PROC FuncM_ScrollTowardsAvatar
    jmp_prga FuncA_Terrain_ScrollTowardsAvatar
.ENDPROC

;;; Updates the scroll position for next frame to move closer to
;;; Zp_ScrollGoalX_u16 and Zp_ScrollGoalY_u8, transferring nametable updates
;;; for the current room as necessary.
.EXPORT FuncM_ScrollTowardsGoal
.PROC FuncM_ScrollTowardsGoal
    jmp_prga FuncA_Terrain_ScrollTowardsGoal
.ENDPROC

;;; Sets Zp_ScrollGoalX_u16 and Zp_ScrollGoalY_u8 such that the position stored
;;; in Zp_Point*_i16 would be as close to the center of the screen as possible,
;;; while still keeping the scroll goal within the valid range for the current
;;; room.
.EXPORT Func_SetScrollGoalFromPoint
.PROC Func_SetScrollGoalFromPoint
_SetScrollGoalY:
    ;; Calculate the maximum permitted scroll-Y and store it in T0.
    lda #0
    bit Zp_Current_sRoom + sRoom::Flags_bRoom
    .assert bRoom::Tall = bProc::Overflow, error
    bvc @shortRoom
    lda #kTallRoomHeightBlocks * kBlockHeightPx - kScreenHeightPx
    @shortRoom:
    sta T0  ; max scroll-Y
    ;; Subtract half the screen height from the point's Y-position, storing the
    ;; result in AX.
    lda Zp_PointY_i16 + 0
    sub #kScreenHeightPx / 2
    tax
    lda Zp_PointY_i16 + 1
    sbc #0
    ;; Clamp the result to within the permitted scroll-Y range.
    bpl @notMinGoal
    @minGoal:
    lda #0
    beq @setGoalToA  ; unconditional
    @notMinGoal:
    bne @maxGoal
    txa
    cmp T0  ; max scroll-Y
    blt @setGoalToA
    @maxGoal:
    lda T0  ; max scroll-Y
    @setGoalToA:
    sta Zp_ScrollGoalY_u8
_SetScrollGoalX:
    ;; Compute the signed 16-bit horizontal scroll goal, storing it in AX.
    lda Zp_PointX_i16 + 0
    sub #kScreenWidthPx / 2
    tax
    lda Zp_PointX_i16 + 1
    sbc #0
    ;; Check AX against the current room's MinScrollX_u8, and clamp if needed.
    bmi @minGoal  ; if AX is negative, clamp to min scroll value
    bne @notMin   ; min scroll is 8-bit, so if A > 0, then AX > min
    cpx Zp_Current_sRoom + sRoom::MinScrollX_u8
    bge @notMin
    @minGoal:
    ldx Zp_Current_sRoom + sRoom::MinScrollX_u8
    lda #0
    beq @setGoalToAX  ; unconditional
    @notMin:
    ;; Check AX against the current room's MaxScrollX_u16, and clamp if needed.
    cmp Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 1
    blt @setGoalToAX
    bne @maxGoal
    cpx Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 0
    blt @setGoalToAX
    @maxGoal:
    ldax Zp_Current_sRoom + sRoom::MaxScrollX_u16
    @setGoalToAX:
    stax Zp_ScrollGoalX_u16
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; Sets Zp_ScrollGoalX_u16 and Zp_ScrollGoalY_u8 such that the player avatar
;;; would be as close to the center of the screen as possible, while still
;;; keeping the scroll goal within the valid range for the current room.
.PROC FuncA_Terrain_SetScrollGoalFromAvatar
    jsr Func_SetPointToAvatarCenter
    jmp Func_SetScrollGoalFromPoint
.ENDPROC

;;; Sets up room scrolling and populates nametables for explore mode.  Called
;;; just before fading in the screen (e.g. when entering the room or
;;; unpausing).
.EXPORT FuncA_Terrain_InitRoomScrollAndNametables
.PROC FuncA_Terrain_InitRoomScrollAndNametables
    ;; Fill the attribute tables.
    ldy #$00  ; param: fill byte
    jsr Func_FillUpperAttributeTable  ; preserves Y
    jsr Func_FillLowerAttributeTable
    ;; Initialize the scroll position.
    jsr FuncA_Terrain_SetScrollGoalFromAvatar
    bit Zp_Camera_bScroll
    .assert bScroll::LockHorz = bProc::Negative, error
    bmi @lockHorz
    ldax Zp_ScrollGoalX_u16
    stax Zp_RoomScrollX_u16
    @lockHorz:
    .assert bScroll::LockVert = bProc::Overflow, error
    bvs @lockVert
    lda Zp_ScrollGoalY_u8
    sta Zp_RoomScrollY_u8
    @lockVert:
    lda Zp_Camera_bScroll
    and #bScroll::LockMap
    bne @lockMap
    jsr FuncA_Terrain_UpdateAndMarkMinimap
    @lockMap:
    ;; Calculate the index of the leftmost room tile column that should be in
    ;; the nametable.
    lda Zp_RoomScrollX_u16 + 0
    add #kTileWidthPx - 1
    sta T0
    lda Zp_RoomScrollX_u16 + 1
    adc #0
    .repeat 3
    lsr a
    ror T0
    .endrepeat
    lda T0  ; param: left block column index
    ;; Populate the nametables.
    jsr FuncA_Terrain_FillNametables
    fall FuncA_Terrain_CallRoomFadeIn
.ENDPROC

;;; Calls the current room's FadeIn_func_ptr function.
.PROC FuncA_Terrain_CallRoomFadeIn
    ldy #sRoomExt::FadeIn_func_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    jmp (T1T0)
.ENDPROC

;;; Sets the scroll goal from the player avatar's position, then updates the
;;; scroll position for next frame to move closer to that goal, transferring
;;; nametable updates for the current room as necessary.
.PROC FuncA_Terrain_ScrollTowardsAvatar
    jsr FuncA_Terrain_SetScrollGoalFromAvatar
    fall FuncA_Terrain_ScrollTowardsGoal
.ENDPROC

;;; Updates the scroll position for next frame to move closer to
;;; Zp_ScrollGoalX_u16 and Zp_ScrollGoalY_u8, transferring nametable updates
;;; for the current room as necessary.
.PROC FuncA_Terrain_ScrollTowardsGoal
    ;; If scrolling is vertically locked, don't scroll vertically (but still
    ;; allow camera shake to work).
    bit Zp_Camera_bScroll
    .assert bScroll::LockVert = bProc::Overflow, error
    bvs _ShakeScrollY
_TrackScrollYTowardsGoal:
    ;; Compute the delta from the current scroll-Y position to the goal
    ;; position, storing it in A.
    lda Zp_ScrollGoalY_u8
    sub Zp_RoomScrollY_u8
    beq @done  ; delta is zero, so no need to scroll vertically
    blt @goalLessThanCurr
    ;; If the delta is positive, then we need to scroll down.  Divide the delta
    ;; by (1 << kScrollYSlowdown) to get the amount we'll scroll by this frame,
    ;; but cap it at a maximum of kMaxScrollYSpeed and a minimum of 1.
    @goalMoreThanCurr:
    .repeat kScrollYSlowdown
    lsr a
    .endrepeat
    bne @clampPositive
    lda #1
    bne @scrollByA  ; unconditional
    @clampPositive:
    cmp #kMaxScrollYSpeed
    blt @scrollByA
    lda #kMaxScrollYSpeed
    bne @scrollByA  ; unconditional
    ;; If the delta is negative, then we need to scroll up.  Divide the
    ;; (negative) delta by (1 << kScrollYSlowdown), roughly, to get the amount
    ;; we'll scroll by this frame, but cap it at a minimum of
    ;; -kMaxScrollYSpeed.  (Because of how we do the division, we will always
    ;; scroll by a nonzero amount here.)
    @goalLessThanCurr:
    .repeat kScrollYSlowdown
    sec
    ror a
    .endrepeat
    cmp #<-kMaxScrollYSpeed
    bge @scrollByA
    lda #<-kMaxScrollYSpeed
    ;; Add A to the current scroll-Y position.
    @scrollByA:
    add Zp_RoomScrollY_u8
    sta Zp_RoomScrollY_u8
    @done:
_ClampScrollY:
    ;; Calculate the visible height of the screen (the part not covered by the
    ;; window), and store it in T0.
    lda Zp_WindowTop_u8
    cmp #kScreenHeightPx
    blt @windowVisible
    lda #kScreenHeightPx
    @windowVisible:
    sta T0  ; visible screen height
    ;; Calculate the maximum permitted scroll-Y and store it in T1.
    lda #kScreenHeightPx
    bit Zp_Current_sRoom + sRoom::Flags_bRoom
    .assert bRoom::Tall = bProc::Overflow, error
    bvc @shortRoom
    lda #<(kTallRoomHeightBlocks * kBlockHeightPx)
    @shortRoom:
    sub T0  ; visible screen height
    sta T1  ; max scroll-Y
    ;; Clamp Zp_RoomScrollY_u8 to no more than the permitted value.
    lda Zp_RoomScrollY_u8
    cmp T1  ; max scroll-Y
    blt @done
    lda T1  ; max scroll-Y
    sta Zp_RoomScrollY_u8
    @done:
_ShakeScrollY:
    ;; Check if the room is currently shaking.
    lda Zp_RoomShake_u8
    beq @done
    dec Zp_RoomShake_u8
    cmp #kHugeShakeFrames
    bge @hugeShake
    cmp #kBigShakeFrames
    bge @bigShake
    @smallShake:
    ;; Replace bit 0 of Zp_RoomScrollY_u8 with bit 1 of Zp_RoomShake_u8.
    lsr Zp_RoomScrollY_u8
    lsr a
    lsr a
    rol Zp_RoomScrollY_u8
    bcc @done  ; unconditional
    @hugeShake:
    ;; Replace bit 2 of Zp_RoomScrollY_u8 with bit 1 of Zp_RoomShake_u8.
    and #%00000010
    asl a
    sta T0
    lda Zp_RoomScrollY_u8
    and #%11111011
    jmp @oraT0
    @bigShake:
    ;; Replace bit 1 of Zp_RoomScrollY_u8 with bit 1 of Zp_RoomShake_u8.
    and #%00000010
    sta T0
    lda Zp_RoomScrollY_u8
    and #%11111101
    @oraT0:
    ora T0
    sta Zp_RoomScrollY_u8
    @done:
_PrepareToScrollHorz:
    ;; If scrolling is horizontally locked, don't scroll horizontally.
    bit Zp_Camera_bScroll
    .assert bScroll::LockHorz = bProc::Negative, error
    bmi _UpdateMinimap
    ;; If the PPU transfer buffer already has a fair bit of data in it, don't
    ;; scroll horizontally this frame.
    lda Zp_PpuTransferLen_u8
    cmp #kScrollTransferThreshold
    bge _UpdateMinimap
    ;; Calculate the index of the leftmost room tile column that is currently
    ;; in the nametable, and put that index in T0.
    lda Zp_RoomScrollX_u16 + 0
    add #kTileWidthPx - 1
    sta T0
    lda Zp_RoomScrollX_u16 + 1
    adc #0
    .repeat 3
    lsr a
    ror T0
    .endrepeat
_TrackScrollXTowardsGoal:
    ldy #0
    ;; Compute the delta from the current scroll-X position to the goal
    ;; position, storing it in T1 (lo) and A (hi).
    lda Zp_ScrollGoalX_u16 + 0
    sub Zp_RoomScrollX_u16 + 0
    sta T1  ; delta (lo)
    lda Zp_ScrollGoalX_u16 + 1
    sbc Zp_RoomScrollX_u16 + 1
    bmi @goalLessThanCurr
    ;; If the delta is non-negative, then we may need to scroll to the right.
    ;; If the hi byte of the delta is nonzero, then just scroll by the maximum
    ;; amount.
    @goalMoreThanCurr:
    .assert kMaxScrollXSpeed << kScrollXSlowdown < $100, error
    bne @maxScroll  ; delta is >= $100, so scroll right by max amount
    ;; Otherwise, we can just consider the lo byte of the delta.  If the delta
    ;; is actually zero, then we don't need to scroll horizontally at all.
    lda T1  ; delta (lo)
    beq @done
    ;; Divide the (positive) delta by (1 << kScrollXSlowdown) to get the amount
    ;; we'll scroll by this frame, but cap it at a maximum of kMaxScrollXSpeed
    ;; and a minimum of 1.
    .repeat kScrollXSlowdown
    lsr a
    .endrepeat
    bne @clampPositive
    lda #1
    bne @scrollByYA  ; unconditional
    @clampPositive:
    cmp #kMaxScrollXSpeed
    blt @scrollByYA
    @maxScroll:
    lda #kMaxScrollXSpeed
    bne @scrollByYA  ; unconditional
    ;; If the delta is negative, then we need to scroll to the left.  Divide
    ;; the (negative) delta by (1 << kScrollXSlowdown), roughly, to get the
    ;; amount we'll scroll by this frame, but cap it at a minimum of
    ;; -kMaxScrollXSpeed.  (Because of how we do the division, we will always
    ;; scroll by a nonzero amount here.)
    @goalLessThanCurr:
    dey  ; now Y is $ff
    cmp #$ff
    bne @minScroll  ; delta is <= -$100, so scroll left by max amount
    lda T1  ; delta (lo)
    .repeat kScrollXSlowdown
    sec
    ror a
    .endrepeat
    cmp #<-kMaxScrollXSpeed
    bge @scrollByYA
    @minScroll:
    lda #<-kMaxScrollXSpeed
    ;; Add YA to the current scroll-X position.
    @scrollByYA:
    add Zp_RoomScrollX_u16 + 0
    sta Zp_RoomScrollX_u16 + 0
    tya
    adc Zp_RoomScrollX_u16 + 1
    sta Zp_RoomScrollX_u16 + 1
    @done:
_UpdateNametable:
    ;; Calculate the index of the leftmost room tile column that should now be
    ;; in the nametable, and put that index in T1.
    lda Zp_RoomScrollX_u16 + 0
    add #kTileWidthPx - 1
    sta T1
    lda Zp_RoomScrollX_u16 + 1
    adc #0
    .repeat 3
    lsr a
    ror T1
    .endrepeat
    ;; Determine if we need to update the nametable; if so, set A to the index
    ;; of the room tile column that should be loaded.
    lda T1  ; new leftmost room tile column
    cmp T0  ; old leftmost room tile column
    beq @doneTransfer
    bmi @doTransfer
    add #kScreenWidthTiles - 1
    @doTransfer:
    jsr FuncA_Terrain_TransferTileColumn
    @doneTransfer:
_UpdateMinimap:
    lda Zp_Camera_bScroll
    and #bScroll::LockMap
    bne @lockMap
    jmp FuncA_Terrain_UpdateAndMarkMinimap
    @lockMap:
    rts
.ENDPROC

;;;=========================================================================;;;
