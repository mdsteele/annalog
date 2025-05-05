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
.INCLUDE "../sample.inc"
.INCLUDE "duck.inc"

.IMPORT FuncA_Actor_FaceOppositeDir
.IMPORT FuncA_Actor_FaceTowardsPoint
.IMPORT FuncA_Actor_IsCollidingWithAvatar
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Actor_SetPointToOtherActorCenter
.IMPORT FuncA_Actor_SetVelXForward
.IMPORT FuncA_Actor_ZeroVelX
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_GetRandomByte
.IMPORT Func_PlaySfxSample
.IMPORT Func_PointHitsTerrain
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorType_eActor_arr

;;;=========================================================================;;;

;;; A duck must be closer than this to food to start chasing it.
kDuckChaseProximity = $30

;;; A duck must be closer than this to food to start eating it.
kDuckEatProximity = 3

;;; How long it takes a duck actor to eat a food, in frames.
.DEFINE kDuckEatingFrames 32

;;; The minimum delay between quacks, in frames.
kDuckQuackCooldown = 60

;;; The OBJ palette number to use for duck NPC actors.
kPaletteObjNpcDuck = 0

;;;=========================================================================;;;

;;; Possible values for a duck NPC actor's State1 byte.
.ENUM eNpcDuck
    Wandering = 0  ; randomly move back and forth
    Chasing = 1    ; move towards the nearest food
    Eating = $ff   ; animate eating food
.ENDENUM

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a duck NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickNpcDuck
.PROC FuncA_Actor_TickNpcDuck
    lda Ram_ActorState3_byte_arr, x  ; quack cooldown
    beq @done
    dec Ram_ActorState3_byte_arr, x  ; quack cooldown
    @done:
_QuackAtAvatar:
    jsr FuncA_Actor_IsCollidingWithAvatar  ; preserves X, returns C
    bcc @done
    jsr _MaybeQuack  ; preserves X
    @done:
_CheckMode:
    lda Ram_ActorState1_byte_arr, x  ; current eNpcDuck mode
    .assert eNpcDuck::Wandering = 0, error
    beq _ContinueWandering
    .assert eNpcDuck::Eating >= $80, error
    .assert eNpcDuck::Chasing < $80, error
    bmi _ContinueEating
_ContinueChasing:
    jsr FuncA_Actor_FindNearestFood  ; preserves X, returns N, A, and Y
    bmi _StartWandering  ; no nearby food anymore
    cmp #kDuckChaseProximity
    bge _StartWandering  ; food is too far away
    cmp #kDuckEatProximity
    bge _MoveTowardsFood  ; food hasn't been reached yet
    ;; Start eating the food.
    jsr _MaybeQuack  ; preserves X
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, y
    lda #eNpcDuck::Eating
    sta Ram_ActorState1_byte_arr, x  ; current eNpcDuck mode
    lda #kDuckEatingFrames
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    jmp FuncA_Actor_ZeroVelX  ; preserves X
_MoveTowardsFood:
    jsr _MaybeQuack  ; preserves X
    jsr FuncA_Actor_SetPointToOtherActorCenter  ; preserves X
    jsr FuncA_Actor_FaceTowardsPoint  ; preserves X
    lda #$a0  ; param: speed (subpixels/frame)
    bne _SetSpeed  ; unconditional
_ContinueEating:
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    beq _StartWandering
    rts
_StartWandering:
    lda #eNpcDuck::Wandering
    sta Ram_ActorState1_byte_arr, x  ; current eNpcDuck mode
    .assert eNpcDuck::Wandering = 0, error
    sta Ram_ActorState2_byte_arr, x  ; mode timer
_ContinueWandering:
    ;; If there's a food nearby, start chasing it.
    jsr FuncA_Actor_FindNearestFood  ; preserves X, returns N, A, and Y
    bmi @noFood  ; no nearby food yet
    cmp #kDuckChaseProximity
    bge @noFood  ; food is too far away
    lda #eNpcDuck::Chasing
    sta Ram_ActorState1_byte_arr, x  ; current eNpcDuck mode
    rts
    @noFood:
    ;; If there is solid terrain ahead, turn the duck around.
    lda #8  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcs _DoTurnAround
    ;; Otherwise, decrement the mode timer, and change speed (possibly turning
    ;; around first) when it reaches zero.
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    beq _MaybeTurnAround
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    rts
_MaybeTurnAround:
    jsr Func_GetRandomByte  ; preserves X, returns A
    mod #4
    bne _PickNewSpeed  ; do not turn around
_DoTurnAround:
    jsr FuncA_Actor_FaceOppositeDir  ; preserves X
_PickNewSpeed:
    ;; Wander for a random amount of time between about 1-2 seconds.
    jsr Func_GetRandomByte  ; preserves X, returns A
    mod #$40
    ora #$40
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    ;; Pick a new speed.
    jsr Func_GetRandomByte  ; preserves X, returns A
    mod #4
    tay
    lda _Speed_u8_arr4, y  ; param: speed (lo)
_SetSpeed:
    ldy #0                 ; param: speed (hi)
    jmp FuncA_Actor_SetVelXForward  ; preserves X
_MaybeQuack:
    lda Ram_ActorState3_byte_arr, x  ; quack cooldown
    bne @done  ; quacked recently
    lda #kDuckQuackCooldown
    sta Ram_ActorState3_byte_arr, x  ; quack cooldown
    lda #eSample::QuackDuck  ; param: eSample to play
    jmp Func_PlaySfxSample  ; preserves X
    @done:
    rts
_Speed_u8_arr4:
    .byte $10, $20, $40, $60
.ENDPROC

;;; Returns the actor index of the nearest food (that's in water) to the duck.
;;; @param X The duck actor index.
;;; @return N Set if there's no food nearby.
;;; @return Y The actor index of the nearby food, if any.
;;; @return A The distance to the nearby food, if any (unsigned).
;;; @preserve X
.PROC FuncA_Actor_FindNearestFood
    lda #$ff
    sta T2  ; actor index of closest food
    sta T1  ; min unsigned distance
    ldy #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, y
    ;; Check if actor Y is a food actor that's in the water; if not, skip it.
    cmp #eActor::ProjFood
    bne @continue
    lda Ram_ActorState2_byte_arr, y  ; is-in-water boolean
    bpl @continue  ; not in water yet
    ;; Calculate the unsigned horizontal distance betweeen the duck and the
    ;; food.  If the distance is >= $100, skip this food actor.
    lda Ram_ActorPosX_i16_0_arr, y
    sub Ram_ActorPosX_i16_0_arr, x
    sta T0  ; signed distance (lo)
    lda Ram_ActorPosX_i16_1_arr, y
    sbc Ram_ActorPosX_i16_1_arr, x
    beq @checkDist  ; signed distance is >= 0 and < $100, so all set
    bpl @continue   ; signed distance is >= $100, so skip this food
    cmp #$ff
    bne @continue   ; signed distance is < -$100, so skip this food
    lda T0  ; signed distance (lo)
    beq @continue   ; signed distance is exactly -$100, so skip this food
    rsub #0         ; signed distance is > -$100 and < 0, so negate it
    sta T0  ; unsigned distance
    ;; If the unsigned distance to this food is the lowest we've found so far,
    ;; record it as the new best candiate.
    @checkDist:
    lda T0  ; unsigned distance
    cmp T1  ; min unsigned distance
    bge @continue  ; this food isn't any closer
    sta T1  ; min unsigned distance
    sty T2  ; actor index of closest food
    @continue:
    dey
    .assert kMaxActors <= $80, error
    bpl @loop
    ;; Return the best food actor index and distance.  If no food was found,
    ;; then Y will be $ff and N will be set.
    lda T1  ; min unsigned distance
    ldy T2  ; actor index of closest food
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a duck NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcDuck
.PROC FuncA_Objects_DrawActorNpcDuck
    lda Ram_ActorState1_byte_arr, x  ; current eNpcDuck mode
    .assert eNpcDuck::Eating >= $80, error
    bmi @eating
    @notEating:
    lda #kTileIdObjNpcDuckFirst + 0  ; param: tile ID
    .assert kTileIdObjNpcDuckFirst + 0 > 0, error
    bne @draw  ; unconditional
    @eating:
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    div #kDuckEatingFrames / 8
    tay
    lda _EatingTileId_u8_arr, y  ; param: tile ID
    @draw:
    ldy #kPaletteObjNpcDuck  ; param: obj palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
_EatingTileId_u8_arr:
    .byte kTileIdObjNpcDuckFirst + 1
    .byte kTileIdObjNpcDuckFirst + 1
    .byte kTileIdObjNpcDuckFirst + 2
    .byte kTileIdObjNpcDuckFirst + 2
    .byte kTileIdObjNpcDuckFirst + 3
    .byte kTileIdObjNpcDuckFirst + 3
    .byte kTileIdObjNpcDuckFirst + 3
    .byte kTileIdObjNpcDuckFirst + 2
    .byte kTileIdObjNpcDuckFirst + 1
.ENDPROC

;;;=========================================================================;;;
