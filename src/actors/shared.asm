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

.INCLUDE "../avatar.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"

.IMPORT FuncA_Actor_IsCollidingWithAvatar
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_Draw1x2Shape
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_MoveShapeUpHalfTile
.IMPORT Func_Cosine
.IMPORT Func_FindDeviceNearPoint
.IMPORT Func_HarmAvatar
.IMPORT Func_IsActorWithinHorzDistanceOfPoint
.IMPORT Func_IsActorWithinVertDistancesOfPoint
.IMPORT Func_IsPointInAnySolidPlatform
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointHorz
.IMPORT Func_MovePointLeftByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_MovePointUpByA
.IMPORT Func_MovePointVert
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Func_SignedAtan2
.IMPORT Func_SignedMult
.IMPORT Func_Sine
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Sets an actor's velocity using polar coordinates.
;;; @param A The angle, measured in increments of tau/256.
;;; @param X The actor index.
;;; @param Y The speed, in half-pixels per frame.
;;; @preserve X, T3+
.EXPORT Func_SetActorVelocityPolar
.PROC Func_SetActorVelocityPolar
    sty T2  ; speed
    pha  ; angle
    jsr Func_Cosine  ; preserves X and T0+, returns A
    ldy T2  ; param: speed multiplier
    jsr Func_SignedMult  ; preserves X and T2+, returns YA
    sta Ram_ActorVelX_i16_0_arr, x
    tya
    sta Ram_ActorVelX_i16_1_arr, x
    pla  ; param: angle
    jsr Func_Sine  ; preserves X and T0+, returns A
    ldy T2  ; param: speed multiplier
    jsr Func_SignedMult  ; preserves X and T2+, returns YA
    sta Ram_ActorVelY_i16_0_arr, x
    tya
    sta Ram_ActorVelY_i16_1_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Checks if the actor is colliding with the player avatar; if so, harms the
;;; avatar.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X
.EXPORT FuncA_Actor_HarmAvatarIfCollision
.PROC FuncA_Actor_HarmAvatarIfCollision
    ;; If there's no collision, we're done.
    jsr FuncA_Actor_IsCollidingWithAvatar  ; preserves X, returns C
    bcc @done
    ;; Face the player avatar towards the actor (so that the avatar will get
    ;; knocked back away from the actor, instead of through it).
    jsr FuncA_Actor_IsAvatarToLeftOrRight  ; preserves X, returns N
    bmi @faceRight
    @faceLeft:
    lda Zp_AvatarFlags_bObj
    ora #bObj::FlipH
    bne @setFlags  ; unconditional
    @faceRight:
    lda Zp_AvatarFlags_bObj
    and #<~bObj::FlipH
    @setFlags:
    sta Zp_AvatarFlags_bObj
    ;; Harm the avatar.
    jsr Func_HarmAvatar  ; preserves X
    sec
    @done:
    rts
.ENDPROC

;;; Determines if the actor is facing left/right toward the player avatar.
;;; @param X The actor index.
;;; @return C Set if the actor is facing the player avatar, cleared if not.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Actor_IsFacingAvatar
.PROC FuncA_Actor_IsFacingAvatar
    jsr FuncA_Actor_IsAvatarToLeftOrRight  ; preserves X, Y, and T0+, returns N
    bpl @avatarIsToTheRight
    @avatarIsToTheLeft:
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    beq @notFacing
    @facing:
    sec
    rts
    @avatarIsToTheRight:
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    beq @facing
    @notFacing:
    clc
    rts
.ENDPROC

;;; Determines if the player avatar is to the left of the actor or to the
;;; right.
;;; @param X The actor index.
;;; @return N Set if the avatar is to the left, cleared if it's to the right.
;;; @preserve X, Y, T0+
.PROC FuncA_Actor_IsAvatarToLeftOrRight
    lda Zp_AvatarPosX_i16 + 0
    cmp Ram_ActorPosX_i16_0_arr, x
    lda Zp_AvatarPosX_i16 + 1
    sbc Ram_ActorPosX_i16_1_arr, x
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    rts
.ENDPROC

;;; Determines if the player avatar is above the actor or below actor.
;;; @param X The actor index.
;;; @return N Set if the avatar is above the actor, cleared if it's below.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Actor_IsAvatarAboveOrBelow
.PROC FuncA_Actor_IsAvatarAboveOrBelow
    lda Zp_AvatarPosY_i16 + 0
    cmp Ram_ActorPosY_i16_0_arr, x
    lda Zp_AvatarPosY_i16 + 1
    sbc Ram_ActorPosY_i16_1_arr, x
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    rts
.ENDPROC

;;; Sets or clears bObj::FlipH in the actor's flags so as to face the actor
;;; horizontally towards the player avatar.
;;; @param X The actor index.
;;; @return A The new bObj value that was set for the actor.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Actor_FaceTowardsAvatar
.PROC FuncA_Actor_FaceTowardsAvatar
    jsr FuncA_Actor_IsAvatarToLeftOrRight  ; preserves X, Y, T0+; returns N
    bpl @faceRight
    @faceLeft:
    lda Ram_ActorFlags_bObj_arr, x
    ora #bObj::FlipH
    bne @setFlags  ; unconditional
    @faceRight:
    lda Ram_ActorFlags_bObj_arr, x
    and #<~bObj::FlipH
    @setFlags:
    sta Ram_ActorFlags_bObj_arr, x
    rts
.ENDPROC

;;; Checks if the horizontal distance between the centers of the actor and the
;;; player avatar is within the given distance.
;;; @param A The distance to check for.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X
.EXPORT FuncA_Actor_IsAvatarWithinHorzDistance
.PROC FuncA_Actor_IsAvatarWithinHorzDistance
    pha  ; distance
    jsr Func_SetPointToAvatarCenter  ; preserves X
    pla  ; param: distance
    jmp Func_IsActorWithinHorzDistanceOfPoint  ; preserves X, returns C
.ENDPROC

;;; Checks if the vertical distance between the centers of the actor and the
;;; player avatar is within the given up/down distances.
;;; @param A The distance above the avatar to check for.
;;; @param Y The distance below the avatar to check for.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X
.EXPORT FuncA_Actor_IsAvatarWithinVertDistances
.PROC FuncA_Actor_IsAvatarWithinVertDistances
    pha  ; distance above avatar
    jsr Func_SetPointToAvatarCenter  ; preserves X and Y
    pla  ; param: distance above avatar
    jmp Func_IsActorWithinVertDistancesOfPoint  ; preserves X, returns C
.ENDPROC

;;; Returns the index of the device whose block the actor's center is in, if
;;; any.
;;; @param X The actor index.
;;; @return N Set if there was no device nearby, cleared otherwise.
;;; @return Y The device index of the nearby device, or $ff for none.
;;; @preserve X
.EXPORT FuncA_Actor_FindNearbyDevice
.PROC FuncA_Actor_FindNearbyDevice
    jsr Func_SetPointToActorCenter  ; preserves X
    jmp Func_FindDeviceNearPoint  ; preserves X, returns N and Y
.ENDPROC

;;; Returns the room block row index for the actor position.
;;; @param X The actor index.
;;; @return Y The room block row index.
;;; @preserve X
.EXPORT FuncA_Actor_GetRoomBlockRow
.PROC FuncA_Actor_GetRoomBlockRow
    lda Ram_ActorPosY_i16_1_arr, x
    sta T0
    lda Ram_ActorPosY_i16_0_arr, x
    .assert kBlockHeightPx = (1 << 4), error
    .repeat 4
    lsr T0
    ror a
    .endrepeat
    tay
    rts
.ENDPROC

;;; Checks if the actor's center position is colliding with solid terrain.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_CenterHitsTerrain
.PROC FuncA_Actor_CenterHitsTerrain
    jsr Func_SetPointToActorCenter  ; preserves X and T0+
    jmp Func_PointHitsTerrain  ; preserves X and T0+, returns C
.ENDPROC

;;; Checks if the actor's center position is colliding with solid terrain or a
;;; solid platform.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_CenterHitsTerrainOrSolidPlatform
.PROC FuncA_Actor_CenterHitsTerrainOrSolidPlatform
    jsr Func_SetPointToActorCenter  ; preserves X and T0+
    jsr Func_PointHitsTerrain  ; preserves X and T0+, returns C
    bcs @return
    jmp Func_IsPointInAnySolidPlatform  ; preserves X and T0+, returns C
    @return:
    rts
.ENDPROC

;;; Sets Zp_PointY_i16 to the vertical center of the actor, and sets
;;; Zp_PointX_i16 to a position A pixels in front of the horizontal center of
;;; the actor, based on the FlipH bit of the actor's flags.
;;; @param A How many pixels in front to place the point (signed).
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_SetPointInFrontOfActor
.PROC FuncA_Actor_SetPointInFrontOfActor
    tay  ; param: offset
    jsr Func_SetPointToActorCenter  ; preserves X, Y, and T0+
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    beq @noNegate
    dey
    tya
    eor #$ff
    tay
    @noNegate:
    tya  ; param: offset
    jmp Func_MovePointHorz  ; preserves X and T0+
.ENDPROC

;;; Sets Zp_PointX_i16 to the horizontal center of the actor, and sets
;;; Zp_PointY_i16 to a position A pixels above/below the vertical center of the
;;; actor, based on the FlipV bit of the actor's flags.
;;; @param A How many pixels above/below to place the point (signed).
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_SetPointAboveOrBelowActor
.PROC FuncA_Actor_SetPointAboveOrBelowActor
    tay  ; param: offset
    jsr Func_SetPointToActorCenter  ; preserves X, Y, and T0+
    lda Ram_ActorFlags_bObj_arr, x
    .assert bObj::FlipV = bProc::Negative, error
    bpl @noNegate
    dey
    tya
    eor #$ff
    tay
    @noNegate:
    tya  ; param: offset
    jmp Func_MovePointVert  ; preserves X and T0+
.ENDPROC

;;; Sets Zp_PointX_i16 and Zp_PointY_i16 to be offset from the center of the
;;; actor by the given number of pixels in the given direction.
;;; @param A The number of pixels to offset by (unsigned).
;;; @param Y The eDir value for the direction to offset the point in.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_SetPointInDirFromActor
.PROC FuncA_Actor_SetPointInDirFromActor
    pha  ; offset
    jsr Func_SetPointToActorCenter  ; preserves X, Y, and T0+
    pla  ; offset
    cpy #eDir::Left
    jeq Func_MovePointLeftByA  ; preserves X and T0+
    cpy #eDir::Right
    jeq Func_MovePointRightByA  ; preserves X and T0+
    cpy #eDir::Down
    jeq Func_MovePointDownByA  ; preserves X and T0+
    jmp Func_MovePointUpByA  ; preserves X and T0+
.ENDPROC

;;; Moves Zp_PointX_i16 left or right by the given number of pixels, in the
;;; direction of the actor's X-velocity.
;;; @param A The number of pixels to shift by (unsigned).
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_MovePointTowardVelXDir
.PROC FuncA_Actor_MovePointTowardVelXDir
    ldy Ram_ActorVelX_i16_1_arr, x
    bpl @movingRight
    @movingLeft:
    jmp Func_MovePointLeftByA  ; preserves X and T0+
    @movingRight:
    jmp Func_MovePointRightByA  ; preserves X and T0+
.ENDPROC

;;; If the actor is facing right, sets its X-velocity to the given speed; if
;;; the actor is facing left, sets it to the negative of that speed.
;;; @param YA The speed to set (signed), in subpixels per frame.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_SetVelXForward
.PROC FuncA_Actor_SetVelXForward
    sta Ram_ActorVelX_i16_0_arr, x
    tya
    sta Ram_ActorVelX_i16_1_arr, x
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne FuncA_Actor_NegateVelX  ; preserves X and T0+
    rts
.ENDPROC

;;; If the actor is facing down, sets its Y-velocity to the given speed; if the
;;; actor is facing up, sets it to the negative of that speed.
;;; @param YA The speed to set (signed), in subpixels per frame.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_SetVelYUpOrDown
.PROC FuncA_Actor_SetVelYUpOrDown
    sta Ram_ActorVelY_i16_0_arr, x
    tya
    sta Ram_ActorVelY_i16_1_arr, x
    lda Ram_ActorFlags_bObj_arr, x
    .assert bObj::FlipV = bProc::Negative, error
    bmi FuncA_Actor_NegateVelY  ; preserves X and T0+
    rts
.ENDPROC

;;; Negates the actor's X-velocity.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Actor_NegateVelX
.PROC FuncA_Actor_NegateVelX
    lda #0
    sub Ram_ActorVelX_i16_0_arr, x
    sta Ram_ActorVelX_i16_0_arr, x
    lda #0
    sbc Ram_ActorVelX_i16_1_arr, x
    sta Ram_ActorVelX_i16_1_arr, x
    rts
.ENDPROC

;;; Negates the actor's Y-velocity.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Actor_NegateVelY
.PROC FuncA_Actor_NegateVelY
    lda #0
    sub Ram_ActorVelY_i16_0_arr, x
    sta Ram_ActorVelY_i16_0_arr, x
    lda #0
    sbc Ram_ActorVelY_i16_1_arr, x
    sta Ram_ActorVelY_i16_1_arr, x
    rts
.ENDPROC

;;; Sets the actor's X- and Y-velocities to zero.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Actor_ZeroVel
.PROC FuncA_Actor_ZeroVel
    jsr FuncA_Actor_ZeroVelY  ; preserves X, Y, and T0+
    fall FuncA_Actor_ZeroVelX  ; preserves X, Y, and T0+
.ENDPROC

;;; Sets the actor's X-velocity to zero.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Actor_ZeroVelX
.PROC FuncA_Actor_ZeroVelX
    lda #0
    sta Ram_ActorVelX_i16_0_arr, x
    sta Ram_ActorVelX_i16_1_arr, x
    rts
.ENDPROC

;;; Sets the actor's Y-velocity to zero.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Actor_ZeroVelY
.PROC FuncA_Actor_ZeroVelY
    lda #0
    sta Ram_ActorVelY_i16_0_arr, x
    sta Ram_ActorVelY_i16_1_arr, x
    rts
.ENDPROC

;;; Accelerates the actor downward.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Actor_ApplyGravity
.PROC FuncA_Actor_ApplyGravity
    lda #kAvatarGravity
    add Ram_ActorVelY_i16_0_arr, x
    sta Ram_ActorVelY_i16_0_arr, x
    lda #0
    adc Ram_ActorVelY_i16_1_arr, x
    sta Ram_ActorVelY_i16_1_arr, x
    rts
.ENDPROC

;;; Calculates the angle from the center of the actor to the position stored in
;;; Zp_Point*_i16.
;;; @param X The actor index.
;;; @return A The angle, measured in increments of tau/256.
;;; @preserve X, T4+
.EXPORT FuncA_Actor_GetAngleToPoint
.PROC FuncA_Actor_GetAngleToPoint
_HorzDelta:
    lda Zp_PointX_i16 + 0
    sub Ram_ActorPosX_i16_0_arr, x
    sta T0  ; horz delta from actor to point (lo)
    lda Zp_PointX_i16 + 1
    sbc Ram_ActorPosX_i16_1_arr, x
    .repeat 3
    lsr a
    ror T0  ; horz delta from actor to point (lo)
    .endrepeat
_VertDelta:
    lda Zp_PointY_i16 + 0
    sub Ram_ActorPosY_i16_0_arr, x
    sta T1  ; vert delta from actor to point (lo)
    lda Zp_PointY_i16 + 1
    sbc Ram_ActorPosY_i16_1_arr, x
    .repeat 3
    lsr a
    ror T1  ; vert delta from actor to point (lo)
    .endrepeat
_Atan2:
    lda T0  ; param: horz delta (signed)
    ldy T1  ; param: vert delta (signed)
    jmp Func_SignedAtan2  ; preserves X and T4+, returns A
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Sets Zp_ShapePosX_i16 and Zp_ShapePosY_i16 to the screen-space position of
;;; the specified actor.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_SetShapePosToActorCenter
.PROC FuncA_Objects_SetShapePosToActorCenter
    ;; Calculate screen-space Y-position.
    lda Ram_ActorPosY_i16_0_arr, x
    sub Zp_RoomScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda Ram_ActorPosY_i16_1_arr, x
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Calculate screen-space X-position.
    lda Ram_ActorPosX_i16_0_arr, x
    sub Zp_RoomScrollX_u16 + 0
    sta Zp_ShapePosX_i16 + 0
    lda Ram_ActorPosX_i16_1_arr, x
    sbc Zp_RoomScrollX_u16 + 1
    sta Zp_ShapePosX_i16 + 1
    rts
.ENDPROC

;;; Adjusts Zp_ShapePosY_i16 to make the actor appear to bob up and down e.g.
;;; in water.
;;; @param X The actor index.
;;; @preserve X, T1+
.EXPORT FuncA_Objects_BobActorShapePosUpAndDown
.PROC FuncA_Objects_BobActorShapePosUpAndDown
    stx T0  ; actor index
    lda Zp_FrameCounter_u8
    div #8
    add T0  ; actor index
    and #$07
    tay
    lda _VertOffset_u8_arr8, y  ; param: offset
    jmp FuncA_Objects_MoveShapeUpByA  ; preserves X and T0+
_VertOffset_u8_arr8:
    .byte 0, 0, 0, 1, 2, 2, 2, 1
.ENDPROC

;;; Returns the object flags to use for drawing the specified NPC actor.
;;; @param X The actor index.
;;; @return A The bObj flags (excluding palette) to use for drawing the NPC.
;;; @preserve X
.EXPORT FuncA_Objects_GetNpcActorFlags
.PROC FuncA_Objects_GetNpcActorFlags
    lda Ram_ActorFlags_bObj_arr, x
    ;; If State2 is true ($ff), use ActorFlags unchanged.
    ldy Ram_ActorState2_byte_arr, x  ; "use flags" boolean
    bmi @return
    ;; Otherwise, only use the bObj::Pri bit from ActorFlags; ignore the flip
    ;; flags and make the actor face towards the avatar.
    and #bObj::Pri
    sta T0  ; bObj::Pri bit
    lda Zp_AvatarPosX_i16 + 0
    cmp Ram_ActorPosX_i16_0_arr, x
    lda Zp_AvatarPosX_i16 + 1
    sbc Ram_ActorPosX_i16_1_arr, x
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    bpl @faceRight
    @faceLeft:
    lda #bObj::FlipH
    ora T0  ; bObj::Pri bit
    rts
    @faceRight:
    lda T0  ; bObj::Pri bit
    @return:
    rts
.ENDPROC

;;; Draws a 1x1-tile actor, with the tile centered on the actor position.
;;; @param A The tile ID.
;;; @param X The actor index.
;;; @param Y The OBJ palette to use when drawing the actor.
;;; @preserve X
.EXPORT FuncA_Objects_Draw1x1Actor
.PROC FuncA_Objects_Draw1x1Actor
    pha  ; tile ID
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X and Y
    jsr FuncA_Objects_MoveShapeLeftHalfTile  ; preserves X and Y
    jsr FuncA_Objects_MoveShapeUpHalfTile  ; preserves X and Y
    ;; Draw object.
    tya
    eor Ram_ActorFlags_bObj_arr, x
    tay  ; param: object flags
    pla  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
.ENDPROC

;;; Allocates and populates OAM slots for the specified actor, using the given
;;; first tile ID and the subsequent tile ID.
;;; @param A The first tile ID.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_Draw1x2Actor
.PROC FuncA_Objects_Draw1x2Actor
    tay  ; first tile ID
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X and Y
    jsr FuncA_Objects_MoveShapeLeftHalfTile  ; preserves X and Y
    tya  ; param: first tile ID
    ldy Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jmp FuncA_Objects_Draw1x2Shape  ; preserves X
.ENDPROC

;;; Allocates and populates OAM slots for the specified actor, using the given
;;; first tile ID and the three subsequent tile IDs.  The caller can then
;;; further modify the objects if needed.
;;; @param A The first tile ID.
;;; @param X The actor index.
;;; @param Y The OBJ palette to use when drawing the actor.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the four objects.
;;; @preserve X, T2+
.EXPORT FuncA_Objects_Draw2x2Actor
.PROC FuncA_Objects_Draw2x2Actor
    pha  ; first tile ID
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X, Y, and T0+
    tya
    eor Ram_ActorFlags_bObj_arr, x
    tay  ; param: object flags
    pla  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X and T2+, returns C and Y
.ENDPROC

;;;=========================================================================;;;
