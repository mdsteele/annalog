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

.INCLUDE "../actor.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../tileset.inc"
.INCLUDE "solifuge.inc"
.INCLUDE "spider.inc"

.IMPORT FuncA_Actor_AccelerateForward
.IMPORT FuncA_Actor_ApplyGravity
.IMPORT FuncA_Actor_ClampVelX
.IMPORT FuncA_Actor_FaceOppositeDir
.IMPORT FuncA_Actor_FaceTowardsAvatar
.IMPORT FuncA_Actor_GetRoomBlockRow
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarWithinHorzDistance
.IMPORT FuncA_Actor_IsAvatarWithinVertDistances
.IMPORT FuncA_Actor_IsPointInRoomBounds
.IMPORT FuncA_Actor_LandOnTerrain
.IMPORT FuncA_Actor_MovePointTowardVelXDir
.IMPORT FuncA_Actor_SetPointAboveOrBelowActor
.IMPORT FuncA_Actor_ZeroVelX
.IMPORT FuncA_Actor_ZeroVelY
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_InitActorDefault
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointLeftByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_MovePointUpByA
.IMPORT Func_PlaySfxBaddieDeath
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr

;;;=========================================================================;;;

;;; How fast a solifuge baddie can move horizontally, in subpixels per frame.
kSolifugeMaxSpeedX = $180

;;; How many pixels in front of its center a solifuge baddie actor checks for
;;; solid terrain to see if it needs to stop.
kSolifugeStopDistance = 9

;;; The horizontal acceleration applied to a solifuge baddie actor when it's
;;; chasing the player avatar, in subpixels per frame per frame.
kSolifugeHorzAccel = 30

;;; How close the player avatar must be horizontally to the solifuge, in
;;; pixels, for it to jump.
kSolifugeJumpHorzProximity = $18

;;; The distance range that the avatar must be above the solifuge for the
;;; solifuge to jump.
kSolifugeMinDistBelowAvatarToJump = $08
kSolifugeMaxDistBelowAvatarToJump = $40

;;; The (signed, 16-bit) initial Y-velocity of a solifuge baddie actor when
;;; jumping, in subpixels per frame.
kSolifugeJumpVelocity = $ffff & -900

;;; The OBJ palette number used for drawing solifuge baddies.
kPaletteObjSolifuge = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes a solifuge baddie actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitActorBadSolifuge
.PROC Func_InitActorBadSolifuge
    ldy #eActor::BadSolifuge  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a solifuge baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadSolifuge
.PROC FuncA_Actor_TickBadSolifuge
    inc Ram_ActorState3_byte_arr, x  ; animation timer
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    lda Ram_ActorState1_byte_arr, x  ; bBadSolifuge value
    .assert bBadSolifuge::Steamed = $80, error
    bmi _Steamed
    and #bBadSolifuge::Jumping
    beq _MaybeJumpAtAvatar
_AlreadyJumping:
    jsr FuncA_Actor_BadSolifugeHitsCeiling  ; preserves X, returns C
    bcc @notBlockedAbove
    ;; If the solifuge is blocked above, then zero its Y-velocity and position
    ;; it just below the ceiling (by aligning it within the terrain block row
    ;; that the solifuge's feet are in).
    @blockedAbove:
    jsr FuncA_Actor_ZeroVelY  ; preserves X
    jsr Func_SetPointToActorCenter  ; preserves X
    lda #kBadSolifugeBoundingBoxDown  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X
    lda Zp_PointY_i16 + 0
    .assert kBlockHeightPx = $10, error
    and #$f0
    .assert kBadSolifugeBoundingBoxUp < $10, error
    ora #kBadSolifugeBoundingBoxUp
    sta Zp_PointY_i16 + 0
    jsr Func_SetActorCenterToPoint  ; preserves X
    @notBlockedAbove:
    ;; Apply gravity.
    jsr FuncA_Actor_ApplyGravity  ; preserves X
    ;; Handle landing on the floor.
    lda #kBadSolifugeBoundingBoxDown  ; param: bounding box down
    jsr FuncA_Actor_LandOnTerrain  ; preserves X, returns C
    bcc _ChaseAvatar
    lda #0
    sta Ram_ActorState1_byte_arr, x  ; bBadSolifuge value
    beq _ChaseAvatar  ; unconditional
_Steamed:
    jsr FuncA_Actor_ApplyGravity  ; preserves X
    ;; Check if the steamed solifuge is moving up or down.
    lda Ram_ActorVelY_i16_1_arr, x
    bpl @movingDown
    ;; If the steamed solifuge hits the ceiling while moving up, kill it.
    @movingUp:
    jsr FuncA_Actor_BadSolifugeHitsCeiling  ; preserves X, returns C
    bcc @done
    jsr Func_PlaySfxBaddieDeath  ; preserves X
    jmp Func_InitActorSmokeExplosion  ; preserves X
    ;; If the steamed solifuge hits the floor while going down, land.
    @movingDown:
    lda #kBadSolifugeBoundingBoxDown  ; param: bounding box down
    jsr FuncA_Actor_LandOnTerrain  ; preserves X, returns C
    bcc @done
    lda #0
    sta Ram_ActorState1_byte_arr, x  ; bBadSolifuge value
    @done:
    rts
_MaybeJumpAtAvatar:
    jsr FuncA_Actor_GetRoomBlockRow  ; preserves X, returns Y
    tya  ; room block row
    sta Ram_ActorState2_byte_arr, x  ; grounded room block row
    ;; Decide if the solifuge should jump.
    lda #kSolifugeJumpHorzProximity  ; param: distance
    jsr FuncA_Actor_IsAvatarWithinHorzDistance  ; preserves X, returns C
    bcc @done  ; avatar is too far away horizontally
    lda Ram_ActorPosY_i16_0_arr, x
    sub Zp_AvatarPosY_i16 + 0
    sta T0  ; avatar dist above solifuge (lo)
    lda Ram_ActorPosY_i16_1_arr, x
    sbc Zp_AvatarPosY_i16 + 1
    bne @done  ; avatar is either below solifuge, or very far above
    lda T0  ; avatar dist above solifuge
    cmp #kSolifugeMinDistBelowAvatarToJump
    blt @done  ; avatar is only barely above solifuge
    cmp #kSolifugeMaxDistBelowAvatarToJump
    bge @done  ; avatar is too far above solifuge
    ;; Make the solifuge jump.
    lda #bBadSolifuge::Jumping
    sta Ram_ActorState1_byte_arr, x  ; bBadSolifuge value
    lda #<kSolifugeJumpVelocity
    sta Ram_ActorVelY_i16_0_arr, x
    lda #>kSolifugeJumpVelocity
    sta Ram_ActorVelY_i16_1_arr, x
    @done:
_ChaseAvatar:
    ldy #$3c  ; param: distance below avatar
    lda #$0c  ; param: distance above avatar
    jsr FuncA_Actor_IsAvatarWithinVertDistances  ; preserves X, returns C
    bcc @noChase
    jsr FuncA_Actor_FaceTowardsAvatar  ; preserves X
    @noChase:
    lda #kSolifugeHorzAccel  ; param: acceleration
    jsr FuncA_Actor_AccelerateForward  ; preserves X
    ldya #kSolifugeMaxSpeedX  ; param: max speed
    jsr FuncA_Actor_ClampVelX  ; preserves X
_StopIfBlockedHorz:
    ;; Set Zp_Point* to just in front of the solifuge's feet.
    jsr Func_SetPointToActorCenter  ; preserves X
    lda #kSolifugeStopDistance  ; param: look-ahead distance
    jsr FuncA_Actor_MovePointTowardVelXDir  ; preserves X
    lda #kBadSolifugeBoundingBoxDown - 1  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X
    ;; Don't allow the solifuge to move horizontally out of bounds.
    jsr FuncA_Actor_IsPointInRoomBounds  ; preserves X, returns C
    bcc @blocked
    ;; If there is terrain in front of the solifuge's feet, it's blocked.
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcs @blocked  ; wall in front of feet is solid, so solifuge is blocked
    ;; If there is terrain in front of the solifuge's head, it's blocked.
    lda #kBadSolifugeBoundingBoxUp + kBadSolifugeBoundingBoxDown - 1  ; param
    jsr Func_MovePointUpByA  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcs @blocked  ; wall in front of head is solid, so solifuge is blocked
    ;; Check the wall at ground level in front of the solifuge (even if it's in
    ;; midair).
    ldy Ram_ActorState2_byte_arr, x  ; grounded room block row
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    bge @blocked  ; wall at ground level is solid, so solifuge is blocked
    ;; Check the floor at ground level in front of the solifuge.
    iny
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    bge @done  ; floor at ground level is solid, so solifuge *isn't* blocked
    @blocked:
    jsr FuncA_Actor_ZeroVelX  ; preserves X
    jmp FuncA_Actor_FaceOppositeDir  ; preserves X
    @done:
    rts
.ENDPROC

;;; Determines if a solifuge baddie actor is hitting the ceiling (on either of
;;; its bounding box's upper two corners).
;;; @param X The actor index.
;;; @return C Set if the top of solifuge is hitting solid terrain.
;;; @preserve X
.PROC FuncA_Actor_BadSolifugeHitsCeiling
    ;; Check for solid terrain above each of the two upper corners of the
    ;; solifuge.
    lda #<-kBadSolifugeBoundingBoxUp
    jsr FuncA_Actor_SetPointAboveOrBelowActor  ; preserves X
    lda #kBadSolifugeBoundingBoxSide  ; param: offset
    jsr Func_MovePointLeftByA  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcs @return
    lda #kBadSolifugeBoundingBoxSide * 2 - 1  ; param: offset
    jsr Func_MovePointRightByA  ; preserves X
    jmp Func_PointHitsTerrain  ; preserves X, returns C
    @return:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a solifuge baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadSolifuge
.PROC FuncA_Objects_DrawActorBadSolifuge
    lda Ram_ActorState3_byte_arr, x  ; animation timer
    and #$08
    div #4
    ora #kTileIdObjBadSpiderFirst  ; param: first tile ID
    ldy #kPaletteObjSolifuge | bObj::FlipV  ; param: object flags
    jsr FuncA_Objects_Draw2x2Actor  ; preserves X, returns C and Y
    bcs @done
    lda Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
