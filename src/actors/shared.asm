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

.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"

.IMPORT FuncA_Actor_IsCollidingWithAvatar
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT Func_HarmAvatar
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

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

;;; Determines if the player avatar is to the left of the actor or to the
;;; right.
;;; @param X The actor index.
;;; @return N Set if the avatar is to the left, cleared if it's to the right.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Actor_IsAvatarToLeftOrRight
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

;;; Sets or clears bObj::FlipH in the actor's flags so as to face the actor
;;; horizontally towards the player avatar.
;;; @param X The actor index.
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

;;; Returns the room tile column index for the actor position.
;;; @param X The actor index.
;;; @return A The room tile column index.
;;; @preserve X
.EXPORT FuncA_Actor_GetRoomTileColumn
.PROC FuncA_Actor_GetRoomTileColumn
    lda Ram_ActorPosX_i16_1_arr, x
    sta T0
    lda Ram_ActorPosX_i16_0_arr, x
    .assert kTileWidthPx = (1 << 3), error
    .repeat 3
    lsr T0
    ror a
    .endrepeat
    rts
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

;;; Draws a 1x1-tile actor, with the tile centered on the actor position.
;;; @param A The tile ID.
;;; @param X The actor index.
;;; @param Y The OBJ palette to use when drawing the actor.
;;; @preserve X
.EXPORT FuncA_Objects_Draw1x1Actor
.PROC FuncA_Objects_Draw1x1Actor
    pha  ; tile ID
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X and Y
    ;; Adjust position.
    jsr FuncA_Objects_MoveShapeLeftHalfTile  ; preserves X and Y
    lda #kTileHeightPx / 2
    jsr FuncA_Objects_MoveShapeUpByA  ; preserves X and Y
    ;; Draw object.
    tya
    ora Ram_ActorFlags_bObj_arr, x
    tay  ; param: object flags
    pla  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
.ENDPROC

;;; Allocates and populates OAM slots for the specified actor, using the given
;;; first tile ID and the three subsequent tile IDs.  The caller can then
;;; further modify the objects if needed.
;;; @param A The first tile ID.
;;; @param X The actor index.
;;; @param Y The OBJ palette to use when drawing the actor.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the four objects.
;;; @preserve X
.EXPORT FuncA_Objects_Draw2x2Actor
.PROC FuncA_Objects_Draw2x2Actor
    pha  ; first tile ID
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X and Y
    tya
    ora Ram_ActorFlags_bObj_arr, x
    tay  ; param: object flags
    pla  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X, returns C and Y
.ENDPROC

;;;=========================================================================;;;
