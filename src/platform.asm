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
.INCLUDE "macros.inc"
.INCLUDE "oam.inc"
.INCLUDE "platform.inc"
.INCLUDE "ppu.inc"

.IMPORT Func_KillAvatar
.IMPORT Func_TryPushAvatarHorz
.IMPORT Func_TryPushAvatarVert
.IMPORTZP Zp_AvatarCollided_ePlatform
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarPushDelta_i8
.IMPORTZP Zp_AvatarWaterDepth_u8
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte

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
.EXPORT Ram_PlatformTop_i16_0_arr, Ram_PlatformTop_i16_1_arr
Ram_PlatformTop_i16_0_arr: .res kMaxPlatforms
Ram_PlatformTop_i16_1_arr: .res kMaxPlatforms

;;; The room pixel Y-position of the bottom edge of each platform.
.EXPORT Ram_PlatformBottom_i16_0_arr, Ram_PlatformBottom_i16_1_arr
Ram_PlatformBottom_i16_0_arr: .res kMaxPlatforms
Ram_PlatformBottom_i16_1_arr: .res kMaxPlatforms

;;; The room pixel X-position of the left edge of each platform.
.EXPORT Ram_PlatformLeft_i16_0_arr, Ram_PlatformLeft_i16_1_arr
Ram_PlatformLeft_i16_0_arr: .res kMaxPlatforms
Ram_PlatformLeft_i16_1_arr: .res kMaxPlatforms

;;; The room pixel X-position of the right edge of each platform.
.EXPORT Ram_PlatformRight_i16_0_arr, Ram_PlatformRight_i16_1_arr
Ram_PlatformRight_i16_0_arr: .res kMaxPlatforms
Ram_PlatformRight_i16_1_arr: .res kMaxPlatforms

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Stores the room pixel position of the center of the platform in
;;; Zp_Point*_i16.  The platform's width and height must fit in one byte.
;;; @param Y The platform index.
;;; @preserve X, Y, Zp_Tmp*
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
;;; @preserve X, Y, Zp_Tmp*
.EXPORT Func_IsPointInPlatform
.PROC Func_IsPointInPlatform
_CheckPlatformLeft:
    lda Zp_PointX_i16 + 0
    cmp Ram_PlatformLeft_i16_0_arr, y
    lda Zp_PointX_i16 + 1
    sbc Ram_PlatformLeft_i16_1_arr, y
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    bmi _Outside
_CheckPlatformRight:
    lda Zp_PointX_i16 + 0
    cmp Ram_PlatformRight_i16_0_arr, y
    lda Zp_PointX_i16 + 1
    sbc Ram_PlatformRight_i16_1_arr, y
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    bpl _Outside
_CheckPlatformTop:
    lda Zp_PointY_i16 + 0
    cmp Ram_PlatformTop_i16_0_arr, y
    lda Zp_PointY_i16 + 1
    sbc Ram_PlatformTop_i16_1_arr, y
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    bmi _Outside
_CheckPlatformBottom:
    lda Zp_PointY_i16 + 0
    cmp Ram_PlatformBottom_i16_0_arr, y
    lda Zp_PointY_i16 + 1
    sbc Ram_PlatformBottom_i16_1_arr, y
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    bpl _Outside
_Inside:
    sec
    rts
_Outside:
    clc
    rts
.ENDPROC

;;; Checks if the point stored in Zp_PointX_i16 and Zp_PointY_i16 is inside any
;;; solid platform in the room.
;;; @return C Set if the point is in a solid platform, cleared otherwise.
;;; @return Y The platform index that was hit (if C is set).
;;; @preserve X, Zp_Tmp*
.EXPORT Func_IsPointInAnySolidPlatform
.PROC Func_IsPointInAnySolidPlatform
    ldy #kMaxPlatforms - 1
    @loop:
    lda Ram_PlatformType_ePlatform_arr, y
    cmp #kFirstSolidPlatformType
    blt @continue
    jsr Func_IsPointInPlatform  ; preserves X, Y, and Zp_Tmp*; returns C
    bcs @return
    @continue:
    dey
    .assert kMaxPlatforms <= $80, error
    bpl @loop
    @return:
    rts
.ENDPROC

;;; Move the specified platform horizontally such that its left edge moves
;;; toward the goal position without overshooting it.
;;; @prereq Zp_PointX_i16 is set to the goal room-space pixel X-position.
;;; @param A The max distance to move by, in pixels (0-127).
;;; @param X The platform index.
;;; @return A The pixel delta that the platform actually moved by (signed).
;;; @return N Set if the platform moved left, cleared otherwise.
;;; @return Z Cleared if the platform moved, set if it didn't.
;;; @preserve X
.EXPORT Func_MovePlatformLeftTowardPointX
.PROC Func_MovePlatformLeftTowardPointX
    sta Zp_Tmp1_byte  ; max distance
    lda Zp_PointX_i16 + 0
    sub Ram_PlatformLeft_i16_0_arr, x
    sta Zp_Tmp2_byte  ; delta (lo)
    lda Zp_PointX_i16 + 1
    sbc Ram_PlatformLeft_i16_1_arr, x
    bmi _MoveLeft
_MoveRight:
    bne _MoveRightByMax
    lda Zp_Tmp2_byte  ; delta (lo)
    cmp Zp_Tmp1_byte  ; max distance
    blt _MoveByA
_MoveRightByMax:
    lda Zp_Tmp1_byte  ; max distance
    bpl _MoveByA  ; unconditional
_MoveLeft:
    cmp #$ff
    blt _MoveLeftByMax
    lda Zp_Tmp2_byte  ; delta (lo)
    add Zp_Tmp1_byte  ; max distance
    bcc _MoveLeftByMax
    lda Zp_Tmp2_byte  ; delta (lo)
    bmi _MoveByA  ; unconditional
_MoveLeftByMax:
    lda #0
    sub Zp_Tmp1_byte  ; max distance
_MoveByA:
    pha  ; move delta
    jsr Func_MovePlatformHorz  ; preserves X
    pla  ; move delta
    rts
.ENDPROC

;;; Moves the specified platform right or left by the specified delta.  If the
;;; player avatar is standing on the platform, it will be moved along with it.
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
    sty Zp_Tmp1_byte           ; move delta (hi)
_MovePlatform:
    ;; Move the platform's left edge.
    lda Ram_PlatformLeft_i16_0_arr, x
    add Zp_AvatarPushDelta_i8  ; move delta (lo)
    sta Ram_PlatformLeft_i16_0_arr, x
    lda Ram_PlatformLeft_i16_1_arr, x
    adc Zp_Tmp1_byte           ; move delta (hi)
    sta Ram_PlatformLeft_i16_1_arr, x
    ;; Move the platform's right edge.
    lda Ram_PlatformRight_i16_0_arr, x
    add Zp_AvatarPushDelta_i8  ; move delta (lo)
    sta Ram_PlatformRight_i16_0_arr, x
    lda Ram_PlatformRight_i16_1_arr, x
    adc Zp_Tmp1_byte           ; move delta (hi)
    sta Ram_PlatformRight_i16_1_arr, x
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
;;; the goal position without overshooting it.
;;; @prereq Zp_PointY_i16 is set to the goal room-space pixel Y-position.
;;; @param A The max distance to move by, in pixels (0-127).
;;; @param X The platform index.
;;; @return A The pixel delta that the platform actually moved by (signed).
;;; @return N Set if the platform moved up, cleared otherwise.
;;; @return Z Cleared if the platform moved, set if it didn't.
;;; @preserve X
.EXPORT Func_MovePlatformTopTowardPointY
.PROC Func_MovePlatformTopTowardPointY
    sta Zp_Tmp1_byte  ; max distance
    lda Zp_PointY_i16 + 0
    sub Ram_PlatformTop_i16_0_arr, x
    sta Zp_Tmp2_byte  ; delta (lo)
    lda Zp_PointY_i16 + 1
    sbc Ram_PlatformTop_i16_1_arr, x
    bmi _MoveUp
_MoveDown:
    bne _MoveDownByMax
    lda Zp_Tmp2_byte  ; delta (lo)
    cmp Zp_Tmp1_byte  ; max distance
    blt _MoveByA
_MoveDownByMax:
    lda Zp_Tmp1_byte  ; max distance
    bpl _MoveByA  ; unconditional
_MoveUp:
    cmp #$ff
    blt _MoveUpByMax
    lda Zp_Tmp2_byte  ; delta (lo)
    add Zp_Tmp1_byte  ; max distance
    bcc _MoveUpByMax
    lda Zp_Tmp2_byte  ; delta (lo)
    bmi _MoveByA  ; unconditional
_MoveUpByMax:
    lda #0
    sub Zp_Tmp1_byte  ; max distance
_MoveByA:
    pha  ; move delta
    jsr Func_MovePlatformVert  ; preserves X
    pla  ; move delta
    rts
.ENDPROC

;;; Moves the specified platform up or down by the specified delta.  If the
;;; player avatar is standing on the platform, it will be moved along with it.
;;; @param A How many pixels to move the platform by (signed).
;;; @param X The platform index.
;;; @preserve X
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
    sty Zp_Tmp1_byte           ; move delta (hi)
_MovePlatform:
    ;; Move the platform's top edge.
    lda Ram_PlatformTop_i16_0_arr, x
    add Zp_AvatarPushDelta_i8  ; move delta (lo)
    sta Ram_PlatformTop_i16_0_arr, x
    lda Ram_PlatformTop_i16_1_arr, x
    adc Zp_Tmp1_byte           ; move delta (hi)
    sta Ram_PlatformTop_i16_1_arr, x
    ;; Move the platform's bottom edge.
    lda Ram_PlatformBottom_i16_0_arr, x
    add Zp_AvatarPushDelta_i8  ; move delta (lo)
    sta Ram_PlatformBottom_i16_0_arr, x
    lda Ram_PlatformBottom_i16_1_arr, x
    adc Zp_Tmp1_byte           ; move delta (hi)
    sta Ram_PlatformBottom_i16_1_arr, x
_CarryAvatarIfRiding:
    ;; If the player avatar is riding the platform downwards, move the avatar
    ;; as well.  (If the avatar is riding the platform upwards, that will
    ;; instead be handled as a collision in the next section, in case the
    ;; avatar gets crushed against the ceiling.)
    cpx Zp_AvatarPlatformIndex_u8
    bne @notRidingDown
    bit Zp_AvatarPushDelta_i8
    bmi @notRidingDown
    jmp Func_TryPushAvatarVert  ; preserves X
    @notRidingDown:
_PushAvatarIfCollision:
    ;; If the avatar is fully to the left or to the right of the platform, then
    ;; the platform isn't pushing it, so we're done.
    jsr Func_IsAvatarInPlatformHorz  ; preserves X, returns Z
    beq _Return
    ;; Check if the platform is moving up or down.
    bit Zp_AvatarPushDelta_i8
    bpl _PushAvatarDownIfCollision
_PushAvatarUpIfCollision:
    ;; If the avatar is fully below the platform, then the platform isn't
    ;; pushing it, so we're done.
    jsr Func_AvatarDepthIntoPlatformBottom  ; preserves X, returns Z and A
    beq _Return
    ;; If the avatar is fully above the platform, then the platform isn't
    ;; pushing it, so we're done.
    jsr Func_AvatarDepthIntoPlatformTop  ; preserves X, returns Z
    bne _PushAvatar
    rts
_PushAvatarDownIfCollision:
    ;; If the avatar is fully above the platform, then the platform isn't
    ;; pushing it, so we're done.
    jsr Func_AvatarDepthIntoPlatformTop  ; preserves X, returns Z
    beq _Return
    ;; If the avatar is fully below the platform, then the platform isn't
    ;; pushing it, so we're done.
    jsr Func_AvatarDepthIntoPlatformBottom  ; preserves X, returns Z and A
    beq _Return
_PushAvatar:
    ;; Otherwise, try to push the avatar out of the platform.
    sta Zp_AvatarPushDelta_i8
    jsr Func_TryPushAvatarVert  ; preserves X
    ;; If the platform squashed the avatar into something else solid, kill the
    ;; avatar.
    lda Zp_AvatarCollided_ePlatform
    .assert ePlatform::None = 0, error
    beq _Return
    jmp Func_KillAvatar  ; preserves X
_Return:
    rts
.ENDPROC

;;; Checks for horizontal collisions between the player avatar and all
;;; platforms.  If any collision occurs, updates the avatar's X-position and
;;; sets Zp_AvatarCollided_ePlatform to the hit platform's type.
;;; @prereq Zp_AvatarPushDelta_i8 holds a nonzero horz delta for the avatar.
.EXPORT Func_AvatarCollideWithAllPlatformsHorz
.PROC Func_AvatarCollideWithAllPlatformsHorz
    ldx #kMaxPlatforms - 1
    @loop:
    lda Ram_PlatformType_ePlatform_arr, x
    cmp #kFirstSolidPlatformType
    blt @continue
    jsr Func_AvatarCollideWithOnePlatformHorz  ; preserves X
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
;;; @preserve X
.PROC Func_AvatarCollideWithOnePlatformHorz
    jsr Func_IsAvatarInPlatformVert  ; preserves X, returns Z
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
    sta Zp_Tmp1_byte  ; platform left edge - bbox (lo)
    lda Ram_PlatformLeft_i16_1_arr, x
    sbc #0
    sta Zp_Tmp2_byte  ; platform left edge - bbox (hi)
    cmp Zp_AvatarPosX_i16 + 1
    blt @leftEdgeHit
    bne _Return
    lda Zp_Tmp1_byte  ; platform left edge - bbox (lo)
    cmp Zp_AvatarPosX_i16 + 0
    beq @leftEdgeHit
    bge _Return
    @leftEdgeHit:
    ;; We've hit the left edge of this platform, so set horizontal position to
    ;; just to the right of the platform we hit.
    lda Zp_Tmp1_byte  ; platform left edge - bbox (lo)
    sta Zp_AvatarPosX_i16 + 0
    lda Zp_Tmp2_byte  ; platform left edge - bbox (hi)
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
    sta Zp_Tmp1_byte  ; platform right edge + bbox (lo)
    lda Ram_PlatformRight_i16_1_arr, x
    adc #0
    sta Zp_Tmp2_byte  ; platform right edge + bbox (hi)
    cmp Zp_AvatarPosX_i16 + 1
    blt _Return
    bne @rightEdgeHit
    lda Zp_Tmp1_byte
    cmp Zp_AvatarPosX_i16 + 0
    blt _Return
    @rightEdgeHit:
    ;; We've hit the right edge of this platform, so set horizontal position to
    ;; just to the right of the platform we hit.
    lda Zp_Tmp1_byte  ; platform right edge + bbox (lo)
    sta Zp_AvatarPosX_i16 + 0
    lda Zp_Tmp2_byte  ; platform right edge + bbox (hi)
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
.EXPORT Func_AvatarCollideWithAllPlatformsVert
.PROC Func_AvatarCollideWithAllPlatformsVert
    lda #$ff
    sta Zp_AvatarPlatformIndex_u8
    ldx #kMaxPlatforms - 1
    @loop:
    lda Ram_PlatformType_ePlatform_arr, x
    cmp #kFirstSolidPlatformType
    blt @continue
    jsr Func_AvatarCollideWithOnePlatformVert  ; preserves X
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
;;; @preserve X
.PROC Func_AvatarCollideWithOnePlatformVert
    jsr Func_IsAvatarInPlatformHorz  ; preserves X, returns Z
    beq _Return
    ;; Check if the player is moving up or down.
    bit Zp_AvatarPushDelta_i8
    bpl _MovingDown
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
    lda Ram_PlatformBottom_i16_0_arr, x
    add #kAvatarBoundingBoxUp
    sta Zp_Tmp1_byte  ; platform bottom edge + bbox (lo)
    lda Ram_PlatformBottom_i16_1_arr, x
    adc #0
    sta Zp_Tmp2_byte  ; platform bottom edge + bbox (hi)
    cmp Zp_AvatarPosY_i16 + 1
    blt _Return
    bne @bottomEdgeHit
    lda Zp_Tmp1_byte
    cmp Zp_AvatarPosY_i16 + 0
    blt _Return
    @bottomEdgeHit:
    ;; We've hit the bottom edge of this platform, so set vertical position to
    ;; just below the platform we hit.
    lda Zp_Tmp1_byte  ; platform bottom edge + bbox (lo)
    sta Zp_AvatarPosY_i16 + 0
    lda Zp_Tmp2_byte  ; platform bottom edge + bbox (hi)
    sta Zp_AvatarPosY_i16 + 1
    jmp _Collided
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
    lda Ram_PlatformTop_i16_0_arr, x
    sub #kAvatarBoundingBoxDown
    sta Zp_Tmp1_byte  ; platform top edge - bbox (lo)
    lda Ram_PlatformTop_i16_1_arr, x
    sbc #0
    sta Zp_Tmp2_byte  ; platform top edge - bbox (hi)
    cmp Zp_AvatarPosY_i16 + 1
    blt @topEdgeHit
    bne _Return
    lda Zp_Tmp1_byte  ; platform top edge - bbox (lo)
    cmp Zp_AvatarPosY_i16 + 0
    beq @topEdgeHit
    bge _Return
    @topEdgeHit:
    ;; We've hit the top edge of this platform, so set vertical position to
    ;; just above the platform we hit.
    lda Zp_Tmp1_byte  ; platform top edge - bbox (lo)
    sta Zp_AvatarPosY_i16 + 0
    lda Zp_Tmp2_byte  ; platform top edge - bbox (hi)
    sta Zp_AvatarPosY_i16 + 1
    ;; Record that the avatar is now riding this platform.
    stx Zp_AvatarPlatformIndex_u8
_Collided:
    lda Ram_PlatformType_ePlatform_arr, x
    sta Zp_AvatarCollided_ePlatform
_Return:
    rts
.ENDPROC

;;; Determines whether both (1) the bottom of the avatar is below the top of
;;; the platform, and (2) the top of the avatar is above the bottom of the
;;; platform.
;;; @param X The platform index.
;;; @return Z Cleared if the avatar is within the platform horizontally.
;;; @preserve X
.PROC Func_IsAvatarInPlatformVert
    jsr Func_AvatarDepthIntoPlatformBottom  ; preserves X, returns Z
    bne @checkTop
    rts
    @checkTop:
    .assert * = Func_AvatarDepthIntoPlatformTop, error, "fallthrough"
.ENDPROC

;;; Determines if the bottom of the avatar is below the top of the platform,
;;; and if so, by how much.
;;; @param X The platform index.
;;; @return A How far to push the avatar vertically to get it out (-127-0).
;;; @return Z Set if the avatar is fully above the platform.
;;; @preserve X
.PROC Func_AvatarDepthIntoPlatformTop
    ;; Calculate the room pixel Y-position of the bottom of the avatar.
    lda Zp_AvatarPosY_i16 + 0
    add #kAvatarBoundingBoxDown
    sta Zp_Tmp1_byte  ; bottom of avatar (lo)
    lda Zp_AvatarPosY_i16 + 1
    adc #0
    sta Zp_Tmp2_byte  ; bottom of avatar (hi)
    ;; Compare the bottom of the avatar to the top of the platform.
    lda Zp_Tmp1_byte  ; bottom of avatar (lo)
    sub Ram_PlatformTop_i16_0_arr, x
    tay  ; depth (lo)
    lda Zp_Tmp2_byte  ; bottom of avatar (hi)
    sbc Ram_PlatformTop_i16_1_arr, x
    bmi _NotInPlatform
    bne _MaxDepth
    cpy #127
    bge _MaxDepth
    ;; Set A equal to -Y.
    dey
    tya
    eor #$ff
    rts
_MaxDepth:
    lda #<-127
    rts
_NotInPlatform:
    lda #0
    rts
.ENDPROC

;;; Determines if the top of the avatar is above the bottom of the platform,
;;; and if so, by how much.
;;; @param X The platform index.
;;; @return A How far to push the avatar vertically to get it out (0-127).
;;; @return Z Set if the avatar is fully below the platform.
;;; @preserve X
.PROC Func_AvatarDepthIntoPlatformBottom
    ;; Calculate the room pixel Y-position of top of the avatar.
    lda Zp_AvatarPosY_i16 + 0
    sub #kAvatarBoundingBoxUp
    sta Zp_Tmp1_byte  ; top of avatar (lo)
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    sta Zp_Tmp2_byte  ; top of avatar (hi)
    ;; Compare the top of avatar to the bottom of the platform.
    lda Ram_PlatformBottom_i16_0_arr, x
    sub Zp_Tmp1_byte  ; top of avatar (lo)
    tay  ; depth (lo)
    lda Ram_PlatformBottom_i16_1_arr, x
    sbc Zp_Tmp2_byte  ; top of avatar (hi)
    bmi _NotInPlatform
    bne _MaxDepth
    cpy #127
    bge _MaxDepth
    tya  ; depth (lo)
    rts
_MaxDepth:
    lda #127
    rts
_NotInPlatform:
    lda #0
    rts
.ENDPROC

;;; Determines whether both (1) the right side of the avatar is to the right of
;;; the left side of the platform, and (2) the left side of the avatar is to
;;; the left of the right side of the platform.
;;; @param X The platform index.
;;; @return Z Cleared if the avatar is within the platform horizontally.
;;; @preserve X
.PROC Func_IsAvatarInPlatformHorz
    jsr Func_AvatarDepthIntoPlatformRight  ; preserves X, returns Z
    bne @checkLeft
    rts
    @checkLeft:
    .assert * = Func_AvatarDepthIntoPlatformLeft, error, "fallthrough"
.ENDPROC

;;; Determines if the avatar's right side is to the right of the platform's
;;; left side, and if so, by how much.
;;; @param X The platform index.
;;; @return A How far to push the avatar horizontally to get it out (-127-0).
;;; @return Z Set if the avatar is fully to the left of the platform.
;;; @preserve X
.PROC Func_AvatarDepthIntoPlatformLeft
    ;; Calculate the room pixel X-position of the avatar's right side.
    lda Zp_AvatarPosX_i16 + 0
    add #kAvatarBoundingBoxRight
    sta Zp_Tmp1_byte  ; avatar's right side (lo)
    lda Zp_AvatarPosX_i16 + 1
    adc #0
    sta Zp_Tmp2_byte  ; avatar's right side (hi)
    ;; Compare the avatar's right side to the platform's left side.
    lda Zp_Tmp1_byte  ; avatar's right side (lo)
    sub Ram_PlatformLeft_i16_0_arr, x
    tay  ; depth (lo)
    lda Zp_Tmp2_byte  ; avatar's right side (hi)
    sbc Ram_PlatformLeft_i16_1_arr, x
    bmi _NotInPlatform
    bne _MaxDepth
    cpy #127
    bge _MaxDepth
    ;; Set A equal to -Y.
    dey
    tya
    eor #$ff
    rts
_MaxDepth:
    lda #<-127
    rts
_NotInPlatform:
    lda #0
    rts
.ENDPROC

;;; Determines if the avatar's left side is to the left of the platform's right
;;; side, and if so, by how much.
;;; @param X The platform index.
;;; @return A How far to push the avatar horizontally to get it out (0-127).
;;; @return Z Set if the avatar is fully to the right of the platform.
;;; @preserve X
.PROC Func_AvatarDepthIntoPlatformRight
    ;; Calculate the room pixel X-position of the avatar's left side.
    lda Zp_AvatarPosX_i16 + 0
    sub #kAvatarBoundingBoxLeft
    sta Zp_Tmp1_byte  ; avatar's left side (lo)
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    sta Zp_Tmp2_byte  ; avatar's left side (hi)
    ;; Compare the avatar's left side to the platform's right side.
    lda Ram_PlatformRight_i16_0_arr, x
    sub Zp_Tmp1_byte  ; avatar's left side (lo)
    tay  ; depth (lo)
    lda Ram_PlatformRight_i16_1_arr, x
    sbc Zp_Tmp2_byte  ; avatar's left side (hi)
    bmi _NotInPlatform
    bne _MaxDepth
    cpy #127
    bge _MaxDepth
    tya  ; depth (lo)
    rts
_MaxDepth:
    lda #127
    rts
_NotInPlatform:
    lda #0
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Checks whether the player avatar is currently in water, and updates
;;; Zp_AvatarWaterDepth_u8 accordingly.
.EXPORT FuncA_Avatar_UpdateWaterDepth
.PROC FuncA_Avatar_UpdateWaterDepth
    ldx #kMaxPlatforms - 1
    @loop:
    lda Ram_PlatformType_ePlatform_arr, x
    cmp #ePlatform::Water
    bne @continue
    jsr FuncA_Avatar_IsInWaterPlatform  ; preserves X, returns A and Z
    bne @done
    @continue:
    dex
    .assert kMaxPlatforms <= $80, error
    bpl @loop
    lda #0  ; not in water
    @done:
    sta Zp_AvatarWaterDepth_u8
    rts
.ENDPROC

;;; Checks whether the player avatar is currently in the specified Water
;;; platform.  If not, sets Z; otherwise, clears Z and returns how far below
;;; the surface the avatar is.
;;; @param X The platform index.
;;; @return A The avatar's depth below the surface.
;;; @return Z Set if the avatar is not in this Water platform.
;;; @preserve X
.PROC FuncA_Avatar_IsInWaterPlatform
    ;; Check left edge of platform.
    lda Zp_AvatarPosX_i16 + 1
    cmp Ram_PlatformLeft_i16_1_arr, x
    blt _NotInWater
    bne @leftEdgeHit
    lda Zp_AvatarPosX_i16 + 0
    cmp Ram_PlatformLeft_i16_0_arr, x
    blt _NotInWater
    @leftEdgeHit:
    ;; Check right edge of platform.
    lda Ram_PlatformRight_i16_1_arr, x
    cmp Zp_AvatarPosX_i16 + 1
    blt _NotInWater
    bne @rightEdgeHit
    lda Ram_PlatformRight_i16_0_arr, x
    cmp Zp_AvatarPosX_i16 + 0
    blt _NotInWater
    @rightEdgeHit:
    ;; Check bottom edge of platform.
    lda Ram_PlatformBottom_i16_1_arr, x
    cmp Zp_AvatarPosY_i16 + 1
    blt _NotInWater
    bne @bottomEdgeHit
    lda Ram_PlatformBottom_i16_0_arr, x
    cmp Zp_AvatarPosY_i16 + 0
    blt _NotInWater
    @bottomEdgeHit:
    ;; Check top edge of platform.
    lda Zp_AvatarPosY_i16 + 0
    sub Ram_PlatformTop_i16_0_arr, x
    sta Zp_Tmp1_byte  ; distance below water (lo)
    lda Zp_AvatarPosY_i16 + 1
    sbc Ram_PlatformTop_i16_1_arr, x
    bmi _NotInWater
    bne _MaxDepth
    lda Zp_Tmp1_byte  ; distance below water (lo)
    rts
_MaxDepth:
    lda #$ff
    rts
_NotInWater:
    lda #0
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Populates Zp_ShapePosX_i16 and Zp_ShapePosY_i16 with the screen position of
;;; the top-left corner of the specified platform.
;;; @param X The platform index.
;;; @preserve X, Y, Zp_Tmp*
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
