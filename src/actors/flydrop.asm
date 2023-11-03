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
.INCLUDE "flydrop.inc"

.IMPORT FuncA_Actor_FaceTowardsAvatar
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarAboveOrBelow
.IMPORT FuncA_Actor_IsAvatarWithinHorzDistance
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Actor_SetVelXForward
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorProjAcid
.IMPORT Func_InitActorWithFlags
.IMPORT Func_MovePointDownByA
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetActorCenterToPoint
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; How fast the flydrop flies, in subpixels per frame.
kFlydropSpeed = $0190

;;; How many pixels in front of its center a flydrop actor checks for solid
;;; terrain to see if it needs to turn around.
kFlydropTurnDistance = 12

;;; How many frames after turning before the flydrop can randomly turn again.
kFlydropRandomTurnCooldownFrames = 30

;;; How many frames after dropping acid before the flydrop can drop more.
kFlydropAcidCooldownFrames = 30

;;; How close the player avatar must be horizontally in order for the flydrop
;;; to drop acid, in pixels.
kFlydropHorzProximity = $30

;;; The OBJ palette number to use for drawing flydrop baddie actors.
kPaletteObjFlydrop = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes a flydrop baddie actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A Zero if the flydrop should face right, or bObj::FlipH for left.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorBadFlydrop
.PROC FuncA_Room_InitActorBadFlydrop
    ldy #eActor::BadFlydrop  ; param: actor type
    jsr Func_InitActorWithFlags  ; preserves X
    lda #kFlydropRandomTurnCooldownFrames
    sta Ram_ActorState2_byte_arr, x  ; random turn cooldown
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a flydrop baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadFlydrop
.PROC FuncA_Actor_TickBadFlydrop
_DropAcid:
    ;; Don't drop acid if the cooldown hasn't expired yet.
    lda Ram_ActorState1_byte_arr, x  ; acid cooldown
    beq @maybeDropAcid
    dec Ram_ActorState1_byte_arr, x  ; acid cooldown
    .assert kFlydropAcidCooldownFrames <= $80, error
    bpl @done  ; unconditional
    ;; Don't drop acid if the player avatar isn't horizontally nearby.
    @maybeDropAcid:
    lda #kFlydropHorzProximity  ; param: distance
    jsr FuncA_Actor_IsAvatarWithinHorzDistance  ; preserves X, returns C
    bcc @done
    ;; Don't drop acid if the player avatar is above the flydrop.
    jsr FuncA_Actor_IsAvatarAboveOrBelow  ; preserves X, returns N
    bmi @done
    ;; Set the starting position for the acid.
    lda #6  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    lda #6  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X
    ;; Spawn an acid projectile.
    stx T0  ; flydrop actor index
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs @noAcid
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    jsr Func_InitActorProjAcid  ; preserves X and T0+
    ;; Give the acid projectile a random X-velocity from -0.5 to +0.5 pixels
    ;; per frame.
    ldy #0
    jsr Func_GetRandomByte  ; preserves X, Y, and T0+, returns A and N
    bpl @setVel
    dey
    @setVel:
    sta Ram_ActorVelX_i16_0_arr, x
    tya
    sta Ram_ActorVelX_i16_1_arr, x
    ;; Set the flydrop baddie's acid cooldown.
    ldx T0  ; flydrop actor index
    lda #kFlydropAcidCooldownFrames
    sta Ram_ActorState1_byte_arr, x  ; acid cooldown
    @noAcid:
    ldx T0  ; flydrop actor index
    @done:
_CheckTerrain:
    ;; Check the terrain in front of the flydrop.  If it's solid, turn around.
    lda #kFlydropTurnDistance  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcs _TurnAround
_TurnRandomly:
    ;; If the flydrop hasn't turned around for a while (turn cooldown is zero),
    ;; then there's a chance to turn randomly.
    lda Ram_ActorState2_byte_arr, x  ; random turn cooldown
    beq @maybeTurn
    ;; Otherwise, decrement the turn cooldown and continue forward.
    dec Ram_ActorState2_byte_arr, x  ; random turn cooldown
    .assert kFlydropRandomTurnCooldownFrames <= $80, error
    bpl _SetVelocity  ; unconditional
    ;; Once the turn cooldown is zero, the flydrop has a 1-in-64 chance to turn
    ;; on a given frame.  If it does decide to turn, it has a 50-50 chance to
    ;; either turn around, or turn to face the player avatar (which may mean
    ;; effectively staying in the same direction).
    @maybeTurn:
    jsr Func_GetRandomByte  ; preserves X, returns A
    lsr a  ; push bottom bit into carry
    and #$3f  ; 1 in 64 chance to be zero
    bne _SetVelocity  ; don't turn
    bcc _TurnAround  ; turn around or face avatar, based on bottom random bit
    jsr FuncA_Actor_FaceTowardsAvatar  ; preserves X
    jmp _SetVelocity
_TurnAround:
    ;; Make the flydrop face the opposite direction.
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    lda #kFlydropRandomTurnCooldownFrames
    sta Ram_ActorState2_byte_arr, x  ; random turn cooldown
_SetVelocity:
    ldya #kFlydropSpeed  ; param: speed
    jsr FuncA_Actor_SetVelXForward  ; preserves X
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a flydrop baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadFlydrop
.PROC FuncA_Objects_DrawActorBadFlydrop
    lda Zp_FrameCounter_u8
    and #$04
    .assert kTileIdObjFlydropFirst .mod $08 = 0, error
    ora #kTileIdObjFlydropFirst  ; param: first tile ID
    ldy #kPaletteObjFlydrop  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
