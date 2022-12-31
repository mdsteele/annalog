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
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT FuncA_Terrain_CallRoomFadeIn
.IMPORT FuncA_Terrain_FillNametables
.IMPORT FuncA_Terrain_TransferTileColumn
.IMPORT FuncA_Terrain_UpdateAndMarkMinimap
.IMPORT Func_FillLowerAttributeTable
.IMPORT Func_FillUpperAttributeTable
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
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

;;; If true ($ff), the camera position (that is, Zp_RoomScroll*) will track
;;; towards the scroll goal (Zp_ScrollGoal*) each frame; if false ($00), then
;;; the camera position will stay locked (though the scroll goal can continue
;;; to update).
.EXPORTZP Zp_CameraCanScroll_bool
Zp_CameraCanScroll_bool: .res 1

;;; If nonzero, the room will shake for this many more frames.
.EXPORTZP Zp_RoomShake_u8
Zp_RoomShake_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Shakes the room for the given number of frames.
;;; @param A How many frames to shake the room for.
;;; @preserve X, Y, Zp_Tmp*
.EXPORT Func_ShakeRoom
.PROC Func_ShakeRoom
    cmp Zp_RoomShake_u8
    blt @done
    sta Zp_RoomShake_u8
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; Sets Zp_ScrollGoalX_u16 and Zp_ScrollGoalY_u8 such that the player avatar
;;; would be as close to the center of the screen as possible, while still
;;; keeping the scroll goal within the valid range for the current room.
.PROC FuncA_Terrain_SetScrollGoalFromAvatar
_SetScrollGoalY:
    ;; Calculate the maximum permitted scroll-Y and store it in Zp_Tmp1_byte.
    lda #0
    bit <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    .assert bRoom::Tall = bProc::Negative, error
    bpl @shortRoom
    lda #kTallRoomHeightBlocks * kBlockHeightPx - kScreenHeightPx
    @shortRoom:
    sta Zp_Tmp1_byte  ; max scroll-Y
    ;; Subtract half the screen height from the player avatar's Y-position,
    ;; storing the result in AX.
    lda Zp_AvatarPosY_i16 + 0
    sub #kScreenHeightPx / 2
    tax
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    ;; Clamp the result to within the permitted scroll-Y range.
    bmi @minGoal
    bne @maxGoal
    txa
    cmp Zp_Tmp1_byte  ; max scroll-Y
    blt @setGoalToA
    @maxGoal:
    lda Zp_Tmp1_byte  ; max scroll-Y
    jmp @setGoalToA
    @minGoal:
    lda #0
    @setGoalToA:
    sta Zp_ScrollGoalY_u8
_SetScrollGoalX:
    ;; Compute the signed 16-bit horizontal scroll goal, storing it in AX.
    lda Zp_AvatarPosX_i16 + 0
    sub #kScreenWidthPx / 2
    tax
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    ;; Check AX against the current room's MinScrollX_u8, and clamp if needed.
    bmi @minGoal  ; if AX is negative, clamp to min scroll value
    bne @notMin   ; min scroll is 8-bit, so if A > 0, then AX > min
    cpx <(Zp_Current_sRoom + sRoom::MinScrollX_u8)
    bge @notMin
    @minGoal:
    ldx <(Zp_Current_sRoom + sRoom::MinScrollX_u8)
    lda #0
    beq @setGoalToAX  ; unconditional
    @notMin:
    ;; Check AX against the current room's MaxScrollX_u16, and clamp if needed.
    cmp <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 1)
    blt @setGoalToAX
    bne @maxGoal
    cpx <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 0)
    blt @setGoalToAX
    @maxGoal:
    ldax <(Zp_Current_sRoom + sRoom::MaxScrollX_u16)
    @setGoalToAX:
    stax Zp_ScrollGoalX_u16
    rts
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
    bit Zp_CameraCanScroll_bool
    bpl @done
    lda Zp_ScrollGoalY_u8
    sta Zp_RoomScrollY_u8
    ldax Zp_ScrollGoalX_u16
    stax Zp_RoomScrollX_u16
    @done:
    jsr FuncA_Terrain_UpdateAndMarkMinimap
    ;; Calculate the index of the leftmost room tile column that should be in
    ;; the nametable.
    lda Zp_RoomScrollX_u16 + 0
    add #kTileWidthPx - 1
    sta Zp_Tmp1_byte
    lda Zp_RoomScrollX_u16 + 1
    adc #0
    .repeat 3
    lsr a
    ror Zp_Tmp1_byte
    .endrepeat
    lda Zp_Tmp1_byte  ; param: left block column index
    ;; Populate the nametables.
    jsr FuncA_Terrain_FillNametables
    jmp FuncA_Terrain_CallRoomFadeIn
.ENDPROC

;;; Sets the scroll goal from the player avatar's position, then updates the
;;; scroll position for next frame to move closer to that goal, transferring
;;; nametable updates for the current room as necessary.
.EXPORT FuncA_Terrain_ScrollTowardsAvatar
.PROC FuncA_Terrain_ScrollTowardsAvatar
    jsr FuncA_Terrain_SetScrollGoalFromAvatar
    .assert * = FuncA_Terrain_ScrollTowardsGoal, error, "fallthrough"
.ENDPROC

;;; Updates the scroll position for next frame to move closer to
;;; Zp_ScrollGoalX_u16 and Zp_ScrollGoalY_u8, transferring nametable updates
;;; for the current room as necessary.
.EXPORT FuncA_Terrain_ScrollTowardsGoal
.PROC FuncA_Terrain_ScrollTowardsGoal
    bit Zp_CameraCanScroll_bool
    bmi @canScroll
    rts
    @canScroll:
_TrackScrollYTowardsGoal:
    ;; Compute the delta from the current scroll-Y position to the goal
    ;; position, storing it in A.
    lda Zp_ScrollGoalY_u8
    sub Zp_RoomScrollY_u8
    blt @goalLessThanCurr
    ;; If the delta is positive, then we need to scroll down.  Divide the delta
    ;; by (1 << kScrollYSlowdown) to get the amount we'll scroll by this frame,
    ;; but cap it at a maximum of kMaxScrollYSpeed.
    @goalMoreThanCurr:
    .repeat kScrollYSlowdown
    lsr a
    .endrepeat
    cmp #kMaxScrollYSpeed
    blt @scrollByA
    lda #kMaxScrollYSpeed
    bne @scrollByA  ; unconditional
    ;; If the delta is negative, then we need to scroll up.  Divide the
    ;; (negative) delta by (1 << kScrollYSlowdown), roughly, to get the amount
    ;; we'll scroll by this frame, but cap it at a minimum of
    ;; -kMaxScrollYSpeed.
    @goalLessThanCurr:
    .repeat kScrollYSlowdown
    sec
    ror a
    .endrepeat
    cmp #$ff & -kMaxScrollYSpeed
    bge @scrollByA
    lda #$ff & -kMaxScrollYSpeed
    ;; Add A to the current scroll-Y position.
    @scrollByA:
    add Zp_RoomScrollY_u8
    sta Zp_RoomScrollY_u8
    @doneScrollVert:
_ClampScrollY:
    ;; Calculate the visible height of the screen (the part not covered by the
    ;; window), and store it in Zp_Tmp1_byte.
    lda Zp_WindowTop_u8
    cmp #kScreenHeightPx
    blt @windowVisible
    lda #kScreenHeightPx
    @windowVisible:
    sta Zp_Tmp1_byte  ; visible screen height
    ;; Calculate the maximum permitted scroll-Y and store it in Zp_Tmp2_byte.
    lda #kScreenHeightPx
    bit <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    .assert bRoom::Tall = bProc::Negative, error
    bpl @shortRoom
    lda #<(kTallRoomHeightBlocks * kBlockHeightPx)
    @shortRoom:
    sub Zp_Tmp1_byte  ; visible screen height
    sta Zp_Tmp2_byte  ; max scroll-Y
    ;; Clamp Zp_RoomScrollY_u8 to no more than the permitted value.
    lda Zp_RoomScrollY_u8
    cmp Zp_Tmp2_byte  ; max scroll-Y
    blt @done
    lda Zp_Tmp2_byte  ; max scroll-Y
    sta Zp_RoomScrollY_u8
    @done:
_ShakeScrollY:
    ;; Check if the room is currently shaking.
    lda Zp_RoomShake_u8
    beq @done
    dec Zp_RoomShake_u8
    ;; If the room is shaking, replace bit 0 of Zp_RoomScrollY_u8 with bit 1 of
    ;; Zp_FrameCounter_u8.
    lsr Zp_RoomScrollY_u8
    lda Zp_FrameCounter_u8
    lsr a
    lsr a
    rol Zp_RoomScrollY_u8
    @done:
_PrepareToScrollHorz:
    ;; Calculate the index of the leftmost room tile column that is currently
    ;; in the nametable, and put that index in Zp_Tmp1_byte.
    lda Zp_RoomScrollX_u16 + 0
    add #kTileWidthPx - 1
    sta Zp_Tmp1_byte
    lda Zp_RoomScrollX_u16 + 1
    adc #0
    .repeat 3
    lsr a
    ror Zp_Tmp1_byte
    .endrepeat
_TrackScrollXTowardsGoal:
    ldy #0
    ;; Compute the delta from the current scroll-X position to the goal
    ;; position, storing it in Zp_Tmp2_byte (lo) and A (hi).
    lda Zp_ScrollGoalX_u16 + 0
    sub Zp_RoomScrollX_u16 + 0
    sta Zp_Tmp2_byte  ; delta (lo)
    lda Zp_ScrollGoalX_u16 + 1
    sbc Zp_RoomScrollX_u16 + 1
    bmi @goalLessThanCurr
    ;; If the delta is positive, then we need to scroll to the right.  Divide
    ;; the delta by (1 << kScrollXSlowdown) to get the amount we'll scroll by
    ;; this frame, but cap it at a maximum of kMaxScrollXSpeed.
    @goalMoreThanCurr:
    .assert kMaxScrollXSpeed << kScrollXSlowdown < $100, error
    bne @maxScroll
    lda Zp_Tmp2_byte  ; delta (lo)
    .repeat kScrollXSlowdown
    lsr a
    .endrepeat
    cmp #kMaxScrollXSpeed
    blt @scrollByYA
    @maxScroll:
    lda #kMaxScrollXSpeed
    bne @scrollByYA  ; unconditional
    ;; If the delta is negative, then we need to scroll to the left.  Divide
    ;; the (negative) delta by (1 << kScrollXSlowdown), roughly, to get the
    ;; amount we'll scroll by this frame, but cap it at a minimum of
    ;; -kMaxScrollXSpeed.
    @goalLessThanCurr:
    dey  ; now Y is $ff
    cmp #$ff
    bne @minScroll
    lda Zp_Tmp2_byte  ; delta (lo)
    .repeat kScrollXSlowdown
    sec
    ror a
    .endrepeat
    cmp #$ff & -kMaxScrollXSpeed
    bge @scrollByYA
    @minScroll:
    lda #$ff & -kMaxScrollXSpeed
    ;; Add YA to the current scroll-X position.
    @scrollByYA:
    add Zp_RoomScrollX_u16 + 0
    sta Zp_RoomScrollX_u16 + 0
    tya
    adc Zp_RoomScrollX_u16 + 1
    sta Zp_RoomScrollX_u16 + 1
_UpdateNametable:
    ;; Calculate the index of the leftmost room tile column that should now be
    ;; in the nametable, and put that index in Zp_Tmp2_byte.
    lda Zp_RoomScrollX_u16 + 0
    add #kTileWidthPx - 1
    sta Zp_Tmp2_byte
    lda Zp_RoomScrollX_u16 + 1
    adc #0
    .repeat 3
    lsr a
    ror Zp_Tmp2_byte
    .endrepeat
    ;; Determine if we need to update the nametable; if so, set A to the index
    ;; of the room tile column that should be loaded.
    lda Zp_Tmp2_byte  ; new leftmost room tile column
    cmp Zp_Tmp1_byte  ; old leftmost room tile column
    beq @doneTransfer
    bmi @doTransfer
    add #kScreenWidthTiles - 1
    @doTransfer:
    jsr FuncA_Terrain_TransferTileColumn
    @doneTransfer:
    jmp FuncA_Terrain_UpdateAndMarkMinimap
.ENDPROC

;;;=========================================================================;;;
