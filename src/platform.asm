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

.INCLUDE "avatar.inc"
.INCLUDE "cpu.inc"
.INCLUDE "macros.inc"
.INCLUDE "oam.inc"
.INCLUDE "platform.inc"
.INCLUDE "ppu.inc"

.IMPORT Func_KillAvatar
.IMPORT Func_TryPushAvatarHorz
.IMPORT Func_TryPushAvatarVert
.IMPORTZP Zp_AvatarCollided_ePlatform
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarPushDelta_i8
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

.ZEROPAGE

;;; The index of the platform that the player avatar is currently riding, or
;;; $ff for none.
.EXPORTZP Zp_AvatarPlatformIndex_u8
Zp_AvatarPlatformIndex_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Platform"

;;; The type for each platform in the room (or ePlatform::None for an empty
;;; slot).
.EXPORT Ram_PlatformType_ePlatform_arr
Ram_PlatformType_ePlatform_arr: .res kMaxPlatforms

;;; The room pixel Y-position of the top edge of each platform.
.EXPORT Ram_PlatformTop_i16_0_arr
Ram_PlatformTop_i16_0_arr: .res kMaxPlatforms
.EXPORT Ram_PlatformTop_i16_1_arr
Ram_PlatformTop_i16_1_arr: .res kMaxPlatforms

;;; The room pixel Y-position of the bottom edge of each platform.
.EXPORT Ram_PlatformBottom_i16_0_arr
Ram_PlatformBottom_i16_0_arr: .res kMaxPlatforms
.EXPORT Ram_PlatformBottom_i16_1_arr
Ram_PlatformBottom_i16_1_arr: .res kMaxPlatforms

;;; The room pixel X-position of the left edge of each platform.
.EXPORT Ram_PlatformLeft_i16_0_arr
Ram_PlatformLeft_i16_0_arr: .res kMaxPlatforms
.EXPORT Ram_PlatformLeft_i16_1_arr
Ram_PlatformLeft_i16_1_arr: .res kMaxPlatforms

;;; The room pixel X-position of the right edge of each platform.
.EXPORT Ram_PlatformRight_i16_0_arr
Ram_PlatformRight_i16_0_arr: .res kMaxPlatforms
.EXPORT Ram_PlatformRight_i16_1_arr
Ram_PlatformRight_i16_1_arr: .res kMaxPlatforms

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Stores the room pixel position of the top-left corner of the platform in
;;; Zp_Point*_i16.
;;; @param Y The platform index.
;;; @preserve X, Y, T0+
.EXPORT Func_SetPointToPlatformTopLeft
.PROC Func_SetPointToPlatformTopLeft
    lda Ram_PlatformLeft_i16_0_arr, y
    sta Zp_PointX_i16 + 0
    lda Ram_PlatformLeft_i16_1_arr, y
    sta Zp_PointX_i16 + 1
    lda Ram_PlatformTop_i16_0_arr, y
    sta Zp_PointY_i16 + 0
    lda Ram_PlatformTop_i16_1_arr, y
    sta Zp_PointY_i16 + 1
    rts
.ENDPROC

;;; Stores the room pixel position of the center of the platform in
;;; Zp_Point*_i16.  The platform's width and height must fit in one byte.
;;; @param Y The platform index.
;;; @preserve X, Y, T0+
.EXPORT Func_SetPointToPlatformCenter
.PROC Func_SetPointToPlatformCenter
    ;; Set X-position.
    lda Ram_PlatformRight_i16_0_arr, y
    sub Ram_PlatformLeft_i16_0_arr, y
    div #2
    adc Ram_PlatformLeft_i16_0_arr, y  ; use carry from div
    sta Zp_PointX_i16 + 0
    lda Ram_PlatformLeft_i16_1_arr, y
    adc #0
    sta Zp_PointX_i16 + 1
    ;; Set Y-position.
    lda Ram_PlatformBottom_i16_0_arr, y
    sub Ram_PlatformTop_i16_0_arr, y
    div #2
    adc Ram_PlatformTop_i16_0_arr, y  ; use carry from div
    sta Zp_PointY_i16 + 0
    lda Ram_PlatformTop_i16_1_arr, y
    adc #0
    sta Zp_PointY_i16 + 1
    rts
.ENDPROC

;;; Checks if the point stored in Zp_PointX_i16 and Zp_PointY_i16 is inside the
;;; platform.
;;; @param Y The platform index.
;;; @return C Set if the point is in the platform, cleared otherwise.
;;; @preserve X, Y, T0+
.EXPORT Func_IsPointInPlatform
.PROC Func_IsPointInPlatform
    jsr Func_IsPointInPlatformVert  ; preserves X, Y, and T0+; returns C
    bcs Func_IsPointInPlatformHorz  ; preserves X, Y, and T0+; returns C
    rts
.ENDPROC

;;; Checks if the horizontal point position in Zp_PointX_i16 is within the
;;; left/right sides of the platform (ignoring the top and bottom).
;;; @param Y The platform index.
;;; @return C Set if the point is horizontally within the platform.
;;; @preserve X, Y, T0+
.EXPORT Func_IsPointInPlatformHorz
.PROC Func_IsPointInPlatformHorz
_CheckPlatformLeft:
    lda Zp_PointX_i16 + 0
    cmp Ram_PlatformLeft_i16_0_arr, y
    lda Zp_PointX_i16 + 1
    sbc Ram_PlatformLeft_i16_1_arr, y
    bmi Func_ClearCForPointOutsidePlatform  ; preserves X, Y, T0+; returns C
_CheckPlatformRight:
    lda Zp_PointX_i16 + 0
    cmp Ram_PlatformRight_i16_0_arr, y
    lda Zp_PointX_i16 + 1
    sbc Ram_PlatformRight_i16_1_arr, y
    bpl Func_ClearCForPointOutsidePlatform  ; preserves X, Y, T0+; returns C
_Inside:
    sec
    rts
.ENDPROC

;;; Checks if the vertical point position in Zp_PointY_i16 is within the
;;; top/bottom sides of the platform (ignoring the left and right).
;;; @param Y The platform index.
;;; @return C Set if the point is vertically within the platform.
;;; @preserve X, Y, T0+
.EXPORT Func_IsPointInPlatformVert
.PROC Func_IsPointInPlatformVert
_CheckPlatformTop:
    lda Zp_PointY_i16 + 0
    cmp Ram_PlatformTop_i16_0_arr, y
    lda Zp_PointY_i16 + 1
    sbc Ram_PlatformTop_i16_1_arr, y
    bmi Func_ClearCForPointOutsidePlatform  ; preserves X, Y, T0+; returns C
_CheckPlatformBottom:
    lda Zp_PointY_i16 + 0
    cmp Ram_PlatformBottom_i16_0_arr, y
    lda Zp_PointY_i16 + 1
    sbc Ram_PlatformBottom_i16_1_arr, y
    bpl Func_ClearCForPointOutsidePlatform  ; preserves X, Y, T0+; returns C
_Inside:
    sec
    rts
.ENDPROC

;;; Helper function for Func_IsPointInPlatform and Func_IsPointInPlatformHorz;
;;; clears the C flag to indicate that the point is not in the platform.
;;; @return C Always cleared.
;;; @preserve X, Y, T0+
.PROC Func_ClearCForPointOutsidePlatform
    clc
    rts
.ENDPROC

;;; Checks if the point stored in Zp_PointX_i16 and Zp_PointY_i16 is inside any
;;; solid platform in the room.
;;; @return C Set if the point is in a solid platform, cleared otherwise.
;;; @return Y The platform index that was hit (if C is set).
;;; @preserve X, T0+
.EXPORT Func_IsPointInAnySolidPlatform
.PROC Func_IsPointInAnySolidPlatform
    ldy #kMaxPlatforms - 1
    @loop:
    lda Ram_PlatformType_ePlatform_arr, y
    cmp #kFirstSolidPlatformType
    blt @continue
    jsr Func_IsPointInPlatform  ; preserves X, Y, and T0+; returns C
    bcs @return
    @continue:
    dey
    .assert kMaxPlatforms <= $80, error
    bpl @loop
    ;; At this point, the C flag will be clear, either from the cmp (if
    ;; platform #0 is not solid) or from Func_IsPointInPlatform (if the point
    ;; isn't in platform #0).
    @return:
    rts
.ENDPROC

;;; Repositions the platform so that its top-left corner is at the point stored
;;; in Zp_PointX_i16 and Zp_PointY_i16.  This does not affect the player
;;; avatar.
;;; @param Y The platform index.
;;; @preserve X, Y, T2+
.EXPORT Func_SetPlatformTopLeftToPoint
.PROC Func_SetPlatformTopLeftToPoint
    jsr Func_SetPlatformTopToPointY  ; preserves X, Y, and T2+
    fall Func_SetPlatformLeftToPointX  ; preserves X, Y, and T2+
.ENDPROC

;;; Repositions the platform so that its left edge is at Zp_PointX_i16.  This
;;; does not affect the player avatar.
;;; @param Y The platform index.
;;; @preserve X, Y, T2+
.PROC Func_SetPlatformLeftToPointX
    ;; Calculate the delta from Left to PointX, storing the result in T1T0.
    lda Zp_PointX_i16 + 0
    sub Ram_PlatformLeft_i16_0_arr, y
    sta T0  ; delta (lo)
    lda Zp_PointX_i16 + 1
    sbc Ram_PlatformLeft_i16_1_arr, y
    sta T1  ; delta (hi)
    ;; Add the delta in T1T0 to Right.
    lda Ram_PlatformRight_i16_0_arr, y
    add T0  ; delta (lo)
    sta Ram_PlatformRight_i16_0_arr, y
    lda Ram_PlatformRight_i16_1_arr, y
    adc T1  ; delta (hi)
    sta Ram_PlatformRight_i16_1_arr, y
    ;; Copy PointX into Left.
    lda Zp_PointX_i16 + 0
    sta Ram_PlatformLeft_i16_0_arr, y
    lda Zp_PointX_i16 + 1
    sta Ram_PlatformLeft_i16_1_arr, y
    rts
.ENDPROC

;;; Repositions the platform so that its top edge is at Zp_PointY_i16.  This
;;; does not affect the player avatar.
;;; @param Y The platform index.
;;; @preserve X, Y, T2+
.EXPORT Func_SetPlatformTopToPointY
.PROC Func_SetPlatformTopToPointY
    ;; Calculate the delta from Top to PointY, storing the result in T1T0.
    lda Zp_PointY_i16 + 0
    sub Ram_PlatformTop_i16_0_arr, y
    sta T0  ; delta (lo)
    lda Zp_PointY_i16 + 1
    sbc Ram_PlatformTop_i16_1_arr, y
    sta T1  ; delta (hi)
    ;; Add the delta in T1T0 to Bottom.
    lda Ram_PlatformBottom_i16_0_arr, y
    add T0  ; delta (lo)
    sta Ram_PlatformBottom_i16_0_arr, y
    lda Ram_PlatformBottom_i16_1_arr, y
    adc T1  ; delta (hi)
    sta Ram_PlatformBottom_i16_1_arr, y
    ;; Copy PointY into Top.
    lda Zp_PointY_i16 + 0
    sta Ram_PlatformTop_i16_0_arr, y
    lda Zp_PointY_i16 + 1
    sta Ram_PlatformTop_i16_1_arr, y
    rts
.ENDPROC

;;; Move the specified platform horizontally such that its left edge moves
;;; toward the goal position without overshooting it.  This may push or carry
;;; the player avatar.
;;; @prereq Zp_PointX_i16 is set to the goal room-space pixel X-position.
;;; @param A The max distance to move by, in pixels (0-127).
;;; @param X The platform index.
;;; @return A The pixel delta that the platform actually moved by (signed).
;;; @return N Set if the platform moved left, cleared otherwise.
;;; @return Z Cleared if the platform moved, set if it didn't.
;;; @preserve X
.EXPORT Func_MovePlatformLeftTowardPointX
.PROC Func_MovePlatformLeftTowardPointX
    sta T0  ; max distance
    lda Zp_PointX_i16 + 0
    sub Ram_PlatformLeft_i16_0_arr, x
    sta T1  ; delta (lo)
    lda Zp_PointX_i16 + 1
    sbc Ram_PlatformLeft_i16_1_arr, x
    bmi _MoveLeft
_MoveRight:
    bne _MoveRightByMax
    lda T1  ; delta (lo)
    cmp T0  ; max distance
    blt _MoveByA
_MoveRightByMax:
    lda T0  ; max distance
    bpl _MoveByA  ; unconditional
_MoveLeft:
    cmp #$ff
    blt _MoveLeftByMax
    lda T1  ; delta (lo)
    add T0  ; max distance
    bcc _MoveLeftByMax
    lda T1  ; delta (lo)
    bmi _MoveByA  ; unconditional
_MoveLeftByMax:
    lda #0
    sub T0  ; max distance
_MoveByA:
    pha  ; move delta
    jsr Func_MovePlatformHorz  ; preserves X
    pla  ; move delta
    rts
.ENDPROC

;;; Moves the specified platform right or left by the specified delta.  This
;;; may push or carry the player avatar.
;;; @param A How many pixels to move the platform by (signed).
;;; @param X The platform index.
;;; @preserve X
.EXPORT Func_MovePlatformHorz
.PROC Func_MovePlatformHorz
    ;; Sign-extend the move delta to 16 bits.
    ldy #0
    ora #0
    beq _Return  ; delta is zero, so there's nothing to do
    bpl @nonnegative
    dey  ; now Y is $ff
    @nonnegative:
    sta Zp_AvatarPushDelta_i8  ; move delta (lo)
    sty T0                     ; move delta (hi)
_MovePlatform:
    ;; Move the platform's left edge.
    lda Ram_PlatformLeft_i16_0_arr, x
    add Zp_AvatarPushDelta_i8  ; move delta (lo)
    sta Ram_PlatformLeft_i16_0_arr, x
    lda Ram_PlatformLeft_i16_1_arr, x
    adc T0                     ; move delta (hi)
    sta Ram_PlatformLeft_i16_1_arr, x
    ;; Move the platform's right edge.
    lda Ram_PlatformRight_i16_0_arr, x
    add Zp_AvatarPushDelta_i8  ; move delta (lo)
    sta Ram_PlatformRight_i16_0_arr, x
    lda Ram_PlatformRight_i16_1_arr, x
    adc T0                     ; move delta (hi)
    sta Ram_PlatformRight_i16_1_arr, x
_CheckIfSolid:
    ;; If the platform type is non-solid, then we're done (no need to push or
    ;; carry the avatar).
    lda Ram_PlatformType_ePlatform_arr, x
    cmp #kFirstSolidPlatformType
    blt _Return
_CarryAvatarIfRiding:
    ;; If the player avatar is riding the platform, move the avatar as well.
    cpx Zp_AvatarPlatformIndex_u8
    bne @notRiding
    jmp Func_TryPushAvatarHorz  ; preserves X
    @notRiding:
_PushAvatarIfCollision:
    ;; If the avatar is fully above or below the platform, then the platform
    ;; isn't pushing it, so we're done.
    jsr Func_IsAvatarInPlatformVert  ; preserves X, returns Z
    beq _Return
    ;; Check if the platform is moving left or right.
    bit Zp_AvatarPushDelta_i8
    bpl _PushAvatarRightIfCollision
_PushAvatarLeftIfCollision:
    ;; If the avatar is fully to the right of the platform, then the platform
    ;; isn't pushing it, so we're done.
    jsr Func_AvatarDepthIntoPlatformRight  ; preserves X, returns Z
    beq _Return
    ;; If the avatar is fully to the left of the platform, then the platform
    ;; isn't pushing it, so we're done.
    jsr Func_AvatarDepthIntoPlatformLeft  ; preserves X, returns Z and A
    bne _PushAvatar
    rts
_PushAvatarRightIfCollision:
    ;; If the avatar is fully to the left of the platform, then the platform
    ;; isn't pushing it, so we're done.
    jsr Func_AvatarDepthIntoPlatformLeft  ; preserves X, returns Z
    beq _Return
    ;; If the avatar is fully to the right of the platform, then the platform
    ;; isn't pushing it, so we're done.
    jsr Func_AvatarDepthIntoPlatformRight  ; preserves X, returns Z and A
    beq _Return
_PushAvatar:
    ;; Otherwise, try to push the avatar out of the platform.
    sta Zp_AvatarPushDelta_i8
    jsr Func_TryPushAvatarHorz  ; preserves X
    ;; If the platform squashed the avatar into something else solid, kill the
    ;; avatar.
    lda Zp_AvatarCollided_ePlatform
    .assert ePlatform::None = 0, error
    beq _Return
    jmp Func_KillAvatar  ; preserves X
_Return:
    rts
.ENDPROC

;;; Move the specified platform vertically such that its top edge moves toward
;;; the goal position without overshooting it.  This may push or carry the
;;; player avatar.
;;; @prereq Zp_PointY_i16 is set to the goal room-space pixel Y-position.
;;; @param A The max distance to move by, in pixels (0-127).
;;; @param X The platform index.
;;; @return A The pixel delta that the platform actually moved by (signed).
;;; @return N Set if the platform moved up, cleared otherwise.
;;; @return Z Cleared if the platform moved, set if it didn't.
;;; @preserve X, T4+
.EXPORT Func_MovePlatformTopTowardPointY
.PROC Func_MovePlatformTopTowardPointY
    sta T0  ; max distance
    lda Zp_PointY_i16 + 0
    sub Ram_PlatformTop_i16_0_arr, x
    sta T1  ; delta (lo)
    lda Zp_PointY_i16 + 1
    sbc Ram_PlatformTop_i16_1_arr, x
    bmi _MoveUp
_MoveDown:
    bne _MoveDownByMax
    lda T1  ; delta (lo)
    cmp T0  ; max distance
    blt _MoveByA
_MoveDownByMax:
    lda T0  ; max distance
    bpl _MoveByA  ; unconditional
_MoveUp:
    cmp #$ff
    blt _MoveUpByMax
    lda T1  ; delta (lo)
    add T0  ; max distance
    bcc _MoveUpByMax
    lda T1  ; delta (lo)
    bmi _MoveByA  ; unconditional
_MoveUpByMax:
    lda #0
    sub T0  ; max distance
_MoveByA:
    pha  ; move delta
    jsr Func_MovePlatformVert  ; preserves X and T4+
    pla  ; move delta
    rts
.ENDPROC

;;; Moves the specified platform up or down by the specified delta.  This may
;;; push or carry the player avatar.
;;; @param A How many pixels to move the platform by (signed).
;;; @param X The platform index.
;;; @preserve X, T4+
.EXPORT Func_MovePlatformVert
.PROC Func_MovePlatformVert
    ;; Sign-extend the move delta to 16 bits.
    ldy #0
    ora #0
    beq _Return  ; delta is zero, so there's nothing to do
    bpl @nonnegative
    dey  ; now Y is $ff
    @nonnegative:
    sta Zp_AvatarPushDelta_i8  ; move delta (lo)
    tya                        ; move delta (hi)
    pha                        ; move delta (hi)
_CarryAvatarIfSwimming:
    ;; If the platform type is water, and the avatar is at the surface of this
    ;; water, then carry the avatar along with the water.  Note that we have to
    ;; do this *before* we move the platform, because the avatar will no longer
    ;; be at the surface.
    lda Ram_PlatformType_ePlatform_arr, x
    cmp #ePlatform::Water
    bne @done  ; this is not a water platform
    jsr Func_IsAvatarInWaterPlatform  ; preserves X and T2+, returns C and A
    bcc @done  ; avatar is not in this water platform
    tay  ; depth below surface
    bne @done  ; avatar is below the surface of the water
    jsr Func_TryPushAvatarVert  ; preserves X and T4+
    @done:
_MovePlatform:
    pla     ; move delta (hi)
    sta T0  ; move delta (hi)
    ;; Move the platform's top edge.
    lda Ram_PlatformTop_i16_0_arr, x
    add Zp_AvatarPushDelta_i8  ; move delta (lo)
    sta Ram_PlatformTop_i16_0_arr, x
    lda Ram_PlatformTop_i16_1_arr, x
    adc T0                     ; move delta (hi)
    sta Ram_PlatformTop_i16_1_arr, x
    ;; Move the platform's bottom edge.
    lda Ram_PlatformBottom_i16_0_arr, x
    add Zp_AvatarPushDelta_i8  ; move delta (lo)
    sta Ram_PlatformBottom_i16_0_arr, x
    lda Ram_PlatformBottom_i16_1_arr, x
    adc T0                     ; move delta (hi)
    sta Ram_PlatformBottom_i16_1_arr, x
_CheckIfSolid:
    ;; If the platform type is non-solid, then we're done (no need to push or
    ;; carry the avatar).
    lda Ram_PlatformType_ePlatform_arr, x
    cmp #kFirstSolidPlatformType
    blt _Return
_CarryAvatarIfRiding:
    ;; If the player avatar is riding the platform downwards, move the avatar
    ;; as well.  (If the avatar is riding the platform upwards, that will
    ;; instead be handled as a collision in the next section, in case the
    ;; avatar gets crushed against the ceiling.)
    cpx Zp_AvatarPlatformIndex_u8
    bne @notRiding
    bit Zp_AvatarPushDelta_i8
    bmi @notRiding
    jmp Func_TryPushAvatarVert  ; preserves X and T4+
    @notRiding:
_PushAvatarIfCollision:
    ;; If the avatar is fully to the left or to the right of the platform, then
    ;; the platform isn't pushing it, so we're done.
    jsr Func_IsAvatarInPlatformHorz  ; preserves X and T2+, returns Z
    beq _Return
    ;; Check if the platform is moving up or down.
    bit Zp_AvatarPushDelta_i8
    bpl _PushAvatarDownIfCollision
_PushAvatarUpIfCollision:
    ;; If the avatar is fully below the platform, then the platform isn't
    ;; pushing it, so we're done.
    jsr Func_AvatarDepthIntoPlatformBottom  ; preserves X, T2+; returns Z, A
    beq _Return
    ;; If the avatar is fully above the platform, then the platform isn't
    ;; pushing it, so we're done.
    jsr Func_AvatarDepthIntoPlatformTop  ; preserves X and T2+, returns Z
    bne _PushAvatar
    rts
_PushAvatarDownIfCollision:
    ;; If the avatar is fully above the platform, then the platform isn't
    ;; pushing it, so we're done.
    jsr Func_AvatarDepthIntoPlatformTop  ; preserves X and T2+, returns Z
    beq _Return
    ;; If the avatar is fully below the platform, then the platform isn't
    ;; pushing it, so we're done.
    jsr Func_AvatarDepthIntoPlatformBottom  ; preserves X, T2+; returns Z, A
    beq _Return
_PushAvatar:
    ;; Otherwise, try to push the avatar out of the platform.
    sta Zp_AvatarPushDelta_i8
    jsr Func_TryPushAvatarVert  ; preserves X and T4+
    ;; If the platform squashed the avatar into something else solid, kill the
    ;; avatar.
    lda Zp_AvatarCollided_ePlatform
    .assert ePlatform::None = 0, error
    beq _Return
    jmp Func_KillAvatar  ; preserves X and T0+
_Return:
    rts
.ENDPROC

;;; Checks for horizontal collisions between the player avatar and all
;;; platforms.  If any collision occurs, updates the avatar's X-position and
;;; sets Zp_AvatarCollided_ePlatform to the hit platform's type.
;;; @prereq Zp_AvatarPushDelta_i8 holds a nonzero horz delta for the avatar.
;;; @preserve T2+
.EXPORT Func_AvatarCollideWithAllPlatformsHorz
.PROC Func_AvatarCollideWithAllPlatformsHorz
    ldx #kMaxPlatforms - 1
    @loop:
    lda Ram_PlatformType_ePlatform_arr, x
    cmp #kFirstSolidPlatformType
    blt @continue
    jsr Func_AvatarCollideWithOnePlatformHorz  ; preserves X and T2+
    @continue:
    dex
    .assert kMaxPlatforms <= $80, error
    bpl @loop
    rts
.ENDPROC

;;; Checks for horizontal collisions between the player avatar and the
;;; specified platform.  If a collision occurs, updates the avatar's X-position
;;; and sets Zp_AvatarCollided_ePlatform to the platform's type.
;;; @prereq Zp_AvatarPushDelta_i8 holds a nonzero horz delta for the avatar.
;;; @param X The platform index.
;;; @preserve X, T2+
.PROC Func_AvatarCollideWithOnePlatformHorz
    jsr Func_IsAvatarInPlatformVert  ; preserves X and T2+, returns Z
    beq _Return
    ;; Check if the player avatar is moving to the left or to the right.
    bit Zp_AvatarPushDelta_i8
    bmi _MovingLeft
_MovingRight:
    ;; Check right edge of platform.
    lda Ram_PlatformRight_i16_1_arr, x
    cmp Zp_AvatarPosX_i16 + 1
    blt _Return
    bne @rightEdgeHit
    lda Ram_PlatformRight_i16_0_arr, x
    cmp Zp_AvatarPosX_i16 + 0
    blt _Return
    @rightEdgeHit:
    ;; Check left edge of platform.
    lda Ram_PlatformLeft_i16_0_arr, x
    sub #kAvatarBoundingBoxRight
    sta T0  ; platform left edge - bbox (lo)
    lda Ram_PlatformLeft_i16_1_arr, x
    sbc #0
    sta T1  ; platform left edge - bbox (hi)
    cmp Zp_AvatarPosX_i16 + 1
    blt @leftEdgeHit
    bne _Return
    lda T0  ; platform left edge - bbox (lo)
    cmp Zp_AvatarPosX_i16 + 0
    beq @leftEdgeHit
    bge _Return
    @leftEdgeHit:
    ;; We've hit the left edge of this platform, so set horizontal position to
    ;; just to the right of the platform we hit.
    lda T0  ; platform left edge - bbox (lo)
    sta Zp_AvatarPosX_i16 + 0
    lda T1  ; platform left edge - bbox (hi)
    sta Zp_AvatarPosX_i16 + 1
    jmp _Collided
_MovingLeft:
    ;; Check left edge of platform.
    lda Zp_AvatarPosX_i16 + 1
    cmp Ram_PlatformLeft_i16_1_arr, x
    blt _Return
    bne @leftEdgeHit
    lda Zp_AvatarPosX_i16 + 0
    cmp Ram_PlatformLeft_i16_0_arr, x
    blt _Return
    @leftEdgeHit:
    ;; Check right edge of platform.
    lda Ram_PlatformRight_i16_0_arr, x
    add #kAvatarBoundingBoxLeft
    sta T0  ; platform right edge + bbox (lo)
    lda Ram_PlatformRight_i16_1_arr, x
    adc #0
    sta T1  ; platform right edge + bbox (hi)
    cmp Zp_AvatarPosX_i16 + 1
    blt _Return
    bne @rightEdgeHit
    lda T0
    cmp Zp_AvatarPosX_i16 + 0
    blt _Return
    @rightEdgeHit:
    ;; We've hit the right edge of this platform, so set horizontal position to
    ;; just to the right of the platform we hit.
    lda T0  ; platform right edge + bbox (lo)
    sta Zp_AvatarPosX_i16 + 0
    lda T1  ; platform right edge + bbox (hi)
    sta Zp_AvatarPosX_i16 + 1
_Collided:
    lda Ram_PlatformType_ePlatform_arr, x
    sta Zp_AvatarCollided_ePlatform
_Return:
    rts
.ENDPROC

;;; Checks for vertical collisions between the player avatar and all platforms.
;;; If any collision occurs, updates the avatar's Y-position and sets
;;; Zp_AvatarCollided_ePlatform to the hit platform's type.  Also updates
;;; Zp_AvatarPlatformIndex_u8.
;;; @prereq Zp_AvatarPushDelta_i8 holds a nonzero vert delta for the avatar.
;;; @preserve T2+
.EXPORT Func_AvatarCollideWithAllPlatformsVert
.PROC Func_AvatarCollideWithAllPlatformsVert
    lda #$ff
    sta Zp_AvatarPlatformIndex_u8
    ldx #kMaxPlatforms - 1
    @loop:
    lda Ram_PlatformType_ePlatform_arr, x
    cmp #kFirstSolidPlatformType
    blt @continue
    jsr Func_AvatarCollideWithOnePlatformVert  ; preserves X and T2+
    @continue:
    dex
    .assert kMaxPlatforms <= $80, error
    bpl @loop
    rts
.ENDPROC

;;; Checks for vertical collisions between the player avatar and the specified
;;; platform.  If a collision occurs, updates the avatar's Y-position and sets
;;; Zp_AvatarCollided_ePlatform to the platform's type.
;;; @prereq Zp_AvatarPushDelta_i8 holds a nonzero vert delta for the avatar.
;;; @param X The platform index.
;;; @preserve X, T2+
.PROC Func_AvatarCollideWithOnePlatformVert
    jsr Func_IsAvatarInPlatformHorz  ; preserves X and T2+, returns Z
    beq _Return
    ;; Check if the player avatar is moving up or down.
    lda Zp_AvatarPushDelta_i8
    bmi _MovingUp
    bne _MovingDown
    bit Zp_AvatarFlags_bObj
    .assert bObj::FlipV = bProc::Negative, error
    bpl _MovingDown  ; normal gravity; treat no vertical movement as "down"
_MovingUp:
    ;; Check top edge of platform.
    lda Zp_AvatarPosY_i16 + 1
    cmp Ram_PlatformTop_i16_1_arr, x
    blt _Return
    bne @topEdgeHit
    lda Zp_AvatarPosY_i16 + 0
    cmp Ram_PlatformTop_i16_0_arr, x
    blt _Return
    @topEdgeHit:
    ;; Check bottom edge of platform.
    bit Zp_AvatarFlags_bObj
    .assert bObj::FlipV = bProc::Negative, error
    bpl @normalGravity
    @reverseGravity:
    lda #kAvatarBoundingBoxFeet + 1
    .assert kAvatarBoundingBoxFeet > 0, error
    bne @doneBoundingBox  ; unconditional
    @normalGravity:
    lda #kAvatarBoundingBoxHead
    @doneBoundingBox:
    add Ram_PlatformBottom_i16_0_arr, x
    sta T0  ; platform bottom edge + bbox (lo)
    lda #0
    adc Ram_PlatformBottom_i16_1_arr, x
    sta T1  ; platform bottom edge + bbox (hi)
    cmp Zp_AvatarPosY_i16 + 1
    blt _Return
    bne @bottomEdgeHit
    lda T0
    cmp Zp_AvatarPosY_i16 + 0
    blt _Return
    @bottomEdgeHit:
    ;; We've hit the bottom edge of this platform, so set vertical position to
    ;; just below the platform we hit.
    lda T0  ; platform bottom edge + bbox (lo)
    sta Zp_AvatarPosY_i16 + 0
    lda T1  ; platform bottom edge + bbox (hi)
    sta Zp_AvatarPosY_i16 + 1
    ;; If gravity is reversed, the avatar is now riding this platform.
    bit Zp_AvatarFlags_bObj
    .assert bObj::FlipV = bProc::Negative, error
    bpl _Collided  ; gravity is normal, so avatar isn't riding platform above
_RidingPlatform:
    stx Zp_AvatarPlatformIndex_u8
_Collided:
    lda Ram_PlatformType_ePlatform_arr, x
    sta Zp_AvatarCollided_ePlatform
_Return:
    rts
_MovingDown:
    ;; Check bottom edge of platform.
    lda Ram_PlatformBottom_i16_1_arr, x
    cmp Zp_AvatarPosY_i16 + 1
    blt _Return
    bne @bottomEdgeHit
    lda Ram_PlatformBottom_i16_0_arr, x
    cmp Zp_AvatarPosY_i16 + 0
    blt _Return
    @bottomEdgeHit:
    ;; Check top edge of platform.
    bit Zp_AvatarFlags_bObj
    .assert bObj::FlipV = bProc::Negative, error
    bpl @normalGravity
    @reverseGravity:
    lda #kAvatarBoundingBoxHead
    .assert kAvatarBoundingBoxHead > 0, error
    bne @doneBoundingBox  ; unconditional
    @normalGravity:
    lda #kAvatarBoundingBoxFeet
    @doneBoundingBox:
    rsub Ram_PlatformTop_i16_0_arr, x
    sta T0  ; platform top edge - bbox (lo)
    lda Ram_PlatformTop_i16_1_arr, x
    sbc #0
    sta T1  ; platform top edge - bbox (hi)
    cmp Zp_AvatarPosY_i16 + 1
    blt @topEdgeHit
    bne _Return
    lda T0  ; platform top edge - bbox (lo)
    cmp Zp_AvatarPosY_i16 + 0
    beq @topEdgeHit
    bge _Return
    @topEdgeHit:
    ;; We've hit the top edge of this platform, so set vertical position to
    ;; just above the platform we hit.
    lda T0  ; platform top edge - bbox (lo)
    sta Zp_AvatarPosY_i16 + 0
    lda T1  ; platform top edge - bbox (hi)
    sta Zp_AvatarPosY_i16 + 1
    ;; If gravity is normal, the avatar is now riding this platform.
    bit Zp_AvatarFlags_bObj
    .assert bObj::FlipV = bProc::Negative, error
    bpl _RidingPlatform
    bmi _Collided  ; unconditional
.ENDPROC

;;; Determines whether both (1) the bottom of the avatar is below the top of
;;; the platform, and (2) the top of the avatar is above the bottom of the
;;; platform.
;;; @param X The platform index.
;;; @return Z Cleared if the avatar is within the platform vertically.
;;; @preserve X, T2+
.PROC Func_IsAvatarInPlatformVert
    jsr Func_AvatarDepthIntoPlatformBottom  ; preserves X and T2+, returns Z
    bne @checkTop
    rts
    @checkTop:
    fall Func_AvatarDepthIntoPlatformTop  ; preserves X and T2+, returns Z
.ENDPROC

;;; Determines if the bottom of the avatar is below the top of the platform,
;;; and if so, by how much.
;;; @param X The platform index.
;;; @return A How far to push the avatar vertically to get it out (-127-0).
;;; @return Z Set if the avatar is fully above the platform.
;;; @preserve X, T2+
.EXPORT Func_AvatarDepthIntoPlatformTop
.PROC Func_AvatarDepthIntoPlatformTop
    bit Zp_AvatarFlags_bObj
    .assert bObj::FlipV = bProc::Negative, error
    bpl @normalGravity
    @reverseGravity:
    lda #kAvatarBoundingBoxHead  ; bounding box down
    bne @setBoundingBox  ; unconditional
    @normalGravity:
    lda #kAvatarBoundingBoxFeet  ; bounding box down
    @setBoundingBox:
    ;; Calculate the room pixel Y-position of the bottom of the avatar.
    add Zp_AvatarPosY_i16 + 0
    sta T0  ; bottom of avatar (lo)
    lda Zp_AvatarPosY_i16 + 1
    adc #0
    sta T1  ; bottom of avatar (hi)
    ;; Compare the bottom of the avatar to the top of the platform.
    lda T0  ; bottom of avatar (lo)
    sub Ram_PlatformTop_i16_0_arr, x
    tay  ; depth (lo)
    lda T1  ; bottom of avatar (hi)
    sbc Ram_PlatformTop_i16_1_arr, x
    bmi Func_AvatarNotInPlatform  ; preserves X and T0+, returns A and Z
    bne Func_AvatarAtMinPlatformDepth  ; preserves X and T0+, returns A and Z
    cpy #127
    bge Func_AvatarAtMinPlatformDepth  ; preserves X and T0+, returns A and Z
    ;; Set A equal to -Y.
    dey
    tya
    eor #$ff
    rts
.ENDPROC

;;; Determines if the top of the avatar is above the bottom of the platform,
;;; and if so, by how much.
;;; @param X The platform index.
;;; @return A How far to push the avatar vertically to get it out (0-127).
;;; @return Z Set if the avatar is fully below the platform.
;;; @preserve X, T2+
.EXPORT Func_AvatarDepthIntoPlatformBottom
.PROC Func_AvatarDepthIntoPlatformBottom
    bit Zp_AvatarFlags_bObj
    .assert bObj::FlipV = bProc::Negative, error
    bpl @normalGravity
    @reverseGravity:
    lda #kAvatarBoundingBoxFeet  ; bounding box up
    bne @setBoundingBox  ; unconditional
    @normalGravity:
    lda #kAvatarBoundingBoxHead  ; bounding box up
    @setBoundingBox:
    ;; Calculate the room pixel Y-position of top of the avatar.
    rsub Zp_AvatarPosY_i16 + 0
    sta T0  ; top of avatar (lo)
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    sta T1  ; top of avatar (hi)
    ;; Compare the top of avatar to the bottom of the platform.
    lda Ram_PlatformBottom_i16_0_arr, x
    sub T0  ; top of avatar (lo)
    tay  ; depth (lo)
    lda Ram_PlatformBottom_i16_1_arr, x
    sbc T1  ; top of avatar (hi)
    bmi Func_AvatarNotInPlatform  ; preserves X and T0+, returns A and Z
    bne Func_AvatarAtMaxPlatformDepth  ; preserves X and T0+, returns A and Z
    cpy #127
    bge Func_AvatarAtMaxPlatformDepth  ; preserves X and T0+, returns A and Z
    tya  ; depth (lo)
    rts
.ENDPROC

;;; Helper function for Func_AvatarDepthIntoPlatform* functions.  Returns a
;;; depth of 127, with Z cleared to indicate that the player avatar is within
;;; the platform along that direction.
;;; @return A Always 127.
;;; @return Z Always cleared.
;;; @preserve X, T0+
.PROC Func_AvatarAtMaxPlatformDepth
    lda #127
    rts
.ENDPROC

;;; Helper function for Func_AvatarDepthIntoPlatform* functions.  Returns a
;;; depth of -127, with Z cleared to indicate that the player avatar is within
;;; the platform along that direction.
;;; @return A Always -127.
;;; @return Z Always cleared.
;;; @preserve X, T0+
.PROC Func_AvatarAtMinPlatformDepth
    lda #<-127
    rts
.ENDPROC

;;; Helper function for Func_AvatarDepthIntoPlatform* functions.  Returns a
;;; depth of zero, with Z set to indicate that the player avatar is fully
;;; outside the platform along that direction.
;;; @return A Always zero.
;;; @return Z Always set.
;;; @preserve X, T0+
.PROC Func_AvatarNotInPlatform
    lda #0
    rts
.ENDPROC

;;; Determines whether both (1) the right side of the avatar is to the right of
;;; the left side of the platform, and (2) the left side of the avatar is to
;;; the left of the right side of the platform.
;;; @param X The platform index.
;;; @return Z Cleared if the avatar is within the platform horizontally.
;;; @preserve X, T2+
.EXPORT Func_IsAvatarInPlatformHorz
.PROC Func_IsAvatarInPlatformHorz
    jsr Func_AvatarDepthIntoPlatformRight  ; preserves X and T2+, returns Z
    bne @checkLeft
    rts
    @checkLeft:
    fall Func_AvatarDepthIntoPlatformLeft  ; preserves X and T2+, returns Z
.ENDPROC

;;; Determines if the avatar's right side is to the right of the platform's
;;; left side, and if so, by how much.
;;; @param X The platform index.
;;; @return A How far to push the avatar horizontally to get it out (-127-0).
;;; @return Z Set if the avatar is fully to the left of the platform.
;;; @preserve X, T2+
.EXPORT Func_AvatarDepthIntoPlatformLeft
.PROC Func_AvatarDepthIntoPlatformLeft
    ;; Calculate the room pixel X-position of the avatar's right side.
    lda Zp_AvatarPosX_i16 + 0
    add #kAvatarBoundingBoxRight
    sta T0  ; avatar's right side (lo)
    lda Zp_AvatarPosX_i16 + 1
    adc #0
    sta T1  ; avatar's right side (hi)
    ;; Compare the avatar's right side to the platform's left side.
    lda T0  ; avatar's right side (lo)
    sub Ram_PlatformLeft_i16_0_arr, x
    tay  ; depth (lo)
    lda T1  ; avatar's right side (hi)
    sbc Ram_PlatformLeft_i16_1_arr, x
    bmi Func_AvatarNotInPlatform  ; preserves X and T0+, returns A and Z
    bne Func_AvatarAtMinPlatformDepth  ; preserves X and T0+, returns A and Z
    cpy #127
    bge Func_AvatarAtMinPlatformDepth  ; preserves X and T0+, returns A and Z
    ;; Set A equal to -Y.
    dey
    tya
    eor #$ff
    rts
.ENDPROC

;;; Determines if the avatar's left side is to the left of the platform's right
;;; side, and if so, by how much.
;;; @param X The platform index.
;;; @return A How far to push the avatar horizontally to get it out (0-127).
;;; @return Z Set if the avatar is fully to the right of the platform.
;;; @preserve X, T2+
.EXPORT Func_AvatarDepthIntoPlatformRight
.PROC Func_AvatarDepthIntoPlatformRight
    ;; Calculate the room pixel X-position of the avatar's left side.
    lda Zp_AvatarPosX_i16 + 0
    sub #kAvatarBoundingBoxLeft
    sta T0  ; avatar's left side (lo)
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    sta T1  ; avatar's left side (hi)
    ;; Compare the avatar's left side to the platform's right side.
    lda Ram_PlatformRight_i16_0_arr, x
    sub T0  ; avatar's left side (lo)
    tay  ; depth (lo)
    lda Ram_PlatformRight_i16_1_arr, x
    sbc T1  ; avatar's left side (hi)
    bmi Func_AvatarNotInPlatform  ; preserves X and T0+, returns A and Z
    bne Func_AvatarAtMaxPlatformDepth  ; preserves X and T0+, returns A and Z
    cpy #127
    bge Func_AvatarAtMaxPlatformDepth  ; preserves X and T0+, returns A and Z
    tya  ; depth (lo)
    rts
.ENDPROC

;;; Checks whether the player avatar is currently in the specified Water
;;; platform.  If not, clears C; otherwise, sets C and returns how far below
;;; the surface the avatar is (clamped to bAvatar::DepthMask at most).
;;; @param X The platform index.
;;; @return C Set if the avatar is in this Water platform.
;;; @return A The avatar's depth below the surface.
;;; @preserve X, T2+
.PROC Func_IsAvatarInWaterPlatform
    ;; Check the left, right, and bottom edges of the water platform.
    jsr Func_IsAvatarInPlatformHorz  ; preserves X and T2+, returns Z
    beq _NotInWater
    jsr Func_AvatarDepthIntoPlatformBottom  ; preserves X, T2+; returns Z
    beq _NotInWater
    ;; Check top edge of platform.
    lda Zp_AvatarPosY_i16 + 0
    sub Ram_PlatformTop_i16_0_arr, x
    sta T0  ; distance below water (lo)
    lda Zp_AvatarPosY_i16 + 1
    sbc Ram_PlatformTop_i16_1_arr, x
    bmi _NotInWater
    bne @maxDepth
    lda T0  ; distance below water (lo)
    cmp #bAvatar::DepthMask
    blt @setDepth
    @maxDepth:
    lda #bAvatar::DepthMask
    @setDepth:
    sec
    rts
_NotInWater:
    clc
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Checks whether the player avatar is currently in water, and updates
;;; Zp_AvatarState_bAvatar accordingly.
;;; @return C Set if the player avatar has just entered the water.
.EXPORT FuncA_Avatar_UpdateWaterDepth
.PROC FuncA_Avatar_UpdateWaterDepth
    ldx #kMaxPlatforms - 1
    @loop:
    lda Ram_PlatformType_ePlatform_arr, x
    cmp #ePlatform::Water
    bne @continue
    jsr Func_IsAvatarInWaterPlatform  ; preserves X, returns C and A
    bcs _InWater
    @continue:
    dex
    .assert kMaxPlatforms <= $80, error
    bpl @loop
_NotInWater:
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvc @done
    lda #bAvatar::Airborne
    sta Zp_AvatarState_bAvatar
    @done:
    clc  ; clear C since the avatar is not swimming
    rts
_InWater:
    ;; At this point, the C flag is set.  If the player avatar was already
    ;; swimming, then clear the C flag to indicate no change in swimming state.
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvc @updateState  ; avatar wasn't already swimming, so leave C set
    clc  ; clear C to indicate that avatar was already swimming
    @updateState:
    ora #bAvatar::Swimming
    sta Zp_AvatarState_bAvatar
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Populates Zp_ShapePosX_i16 and Zp_ShapePosY_i16 with the screen position of
;;; the top-left corner of the specified platform.
;;; @param X The platform index.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.PROC FuncA_Objects_SetShapePosToPlatformTopLeft
    ;; Calculate top edge in screen space.
    lda Ram_PlatformTop_i16_0_arr, x
    sub Zp_RoomScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda Ram_PlatformTop_i16_1_arr, x
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Calculate left edge in screen space.
    lda Ram_PlatformLeft_i16_0_arr, x
    sub Zp_RoomScrollX_u16 + 0
    sta Zp_ShapePosX_i16 + 0
    lda Ram_PlatformLeft_i16_1_arr, x
    sbc Zp_RoomScrollX_u16 + 1
    sta Zp_ShapePosX_i16 + 1
    rts
.ENDPROC

;;;=========================================================================;;;
