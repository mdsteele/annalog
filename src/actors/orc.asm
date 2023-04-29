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
.INCLUDE "../avatar.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../terrain.inc"
.INCLUDE "orc.inc"

.IMPORT FuncA_Actor_FaceTowardsAvatar
.IMPORT FuncA_Actor_GetRoomBlockRow
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarWithinHorzDistance
.IMPORT FuncA_Actor_IsAvatarWithinVertDistances
.IMPORT FuncA_Actor_MovePointTowardVelXDir
.IMPORT FuncA_Actor_ZeroVelX
.IMPORT FuncA_Actor_ZeroVelY
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_GetNpcActorFlags
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_GetTerrainColumnPtrForPointX
.IMPORT Func_InitActorWithFlags
.IMPORT Func_MovePointDownByA
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr

;;;=========================================================================;;;

;;; How many pixels in front of its center an orc baddie actor checks for solid
;;; terrain to see if it needs to stop.
kOrcStopDistance = 10

;;; The horizontal acceleration applied to an orc baddie actor when it's
;;; chasing the player avatar, in subpixels per frame per frame.
kOrcChasingHorzAccel = 40

;;; How many frames the orc should pause for after catching the player avatar.
kOrcPauseFrames = 20

;;; OBJ tile IDs for drawing orc baddie actors.
kTileIdObjOrcHeadHigh     = kTileIdObjOrcStandingFirst +  0
kTileIdObjOrcHeadLow      = kTileIdObjOrcRunningFirst  +  0
kTileIdObjOrcFeetStanding = kTileIdObjOrcStandingFirst +  4
kTileIdObjOrcFeetRunning1 = kTileIdObjOrcRunningFirst  +  4
kTileIdObjOrcFeetRunning2 = kTileIdObjOrcRunningFirst  +  8
kTileIdObjOrcFeetRunning3 = kTileIdObjOrcRunningFirst  + 12

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes an orc baddie actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The flags to set.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT Func_InitActorBadOrc
.PROC Func_InitActorBadOrc
    ldy #eActor::BadOrc  ; param: actor type
    jmp Func_InitActorWithFlags
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for an orc baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadOrc
.PROC FuncA_Actor_TickBadOrc
    ;; Advance timers.
    inc Ram_ActorState3_byte_arr, x  ; animation counter
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    beq @doneTimer
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    @doneTimer:
    ;; TODO: check for horz collisions with walls, and bounce off
    ;; Check for collision with player avatar.  The jump targets below can make
    ;; use of the returned C value.
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X, returns C
    ;; Execute mode-specific behavior.
    ldy Ram_ActorState1_byte_arr, x  ; current mode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eBadOrc
    d_entry table, Standing, FuncA_Actor_TickBadOrc_Standing
    d_entry table, Chasing,  FuncA_Actor_TickBadOrc_Chasing
    d_entry table, Pausing,  FuncA_Actor_TickBadOrc_Pausing
    d_entry table, Jumping,  FuncA_Actor_TickBadOrc_Jumping
    D_END
.ENDREPEAT
.ENDPROC

;;; Puts an orc baddie actor into Chasing mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_StartChasing
    lda #eBadOrc::Chasing
    sta Ram_ActorState1_byte_arr, x  ; current mode
    lda #0
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    sta Ram_ActorState3_byte_arr, x  ; animation counter
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Standing mode.
;;; @param C Set if the orc just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Standing
    bcs FuncA_Actor_TickBadOrc_StartChasing
    ldy #kTileHeightPx * 3  ; param: distance above actor
    lda #kTileHeightPx      ; param: distance below actor
    jsr FuncA_Actor_IsAvatarWithinVertDistances  ; preserves X, returns C
    bcc @done
    lda #kBlockWidthPx * 5  ; param: distance
    jsr FuncA_Actor_IsAvatarWithinHorzDistance  ; preserves X, returns C
    bcs FuncA_Actor_TickBadOrc_StartChasing
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Standing mode.
;;; @param C Set if the orc just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Pausing
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    beq FuncA_Actor_TickBadOrc_StartChasing
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Chasing mode.
;;; @param C Set if the orc just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Chasing
    ;; If the orc catches the player avatar, pause briefly.
    bcc @noCollide
    jsr FuncA_Actor_ZeroVelX  ; preserves X
    lda #eBadOrc::Pausing
    sta Ram_ActorState1_byte_arr, x  ; current mode
    lda #kOrcPauseFrames
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    rts
    @noCollide:
_StopChasingIfAvatarEscapes:
    ;; If the player avatar gets far away vertically, stop chasing.
    ldy #kTileHeightPx * 5  ; param: distance above actor
    lda #kTileHeightPx * 3  ; param: distance below actor
    jsr FuncA_Actor_IsAvatarWithinVertDistances  ; preserves X, returns C
    bcs _KeepChasing
    ;; TODO: Don't halt immediately; go into a Patrol mode for a few seconds.
    ;; TODO: When Patrol timer ends, decelerate into Standing mode.
    jsr FuncA_Actor_ZeroVelX  ; preserves X
    lda #eBadOrc::Standing
    sta Ram_ActorState1_byte_arr, x  ; current mode
    rts
_KeepChasing:
    jsr FuncA_Actor_FaceTowardsAvatar  ; preserves X, returns A
    and #bObj::FlipH
    beq @accelerateRight
    @accelerateLeft:
    lda Ram_ActorVelX_i16_0_arr, x
    sub #<kOrcChasingHorzAccel
    sta Ram_ActorVelX_i16_0_arr, x
    lda Ram_ActorVelX_i16_1_arr, x
    sbc #>kOrcChasingHorzAccel
    jmp @finish
    @accelerateRight:
    lda Ram_ActorVelX_i16_0_arr, x
    add #<kOrcChasingHorzAccel
    sta Ram_ActorVelX_i16_0_arr, x
    lda Ram_ActorVelX_i16_1_arr, x
    adc #>kOrcChasingHorzAccel
    @finish:
    sta Ram_ActorVelX_i16_1_arr, x
_ClampVelocity:
    bmi @negative
    @positive:
    lda Ram_ActorVelX_i16_0_arr, x
    cmp #<kOrcMaxRunSpeed
    lda Ram_ActorVelX_i16_1_arr, x
    sbc #>kOrcMaxRunSpeed
    blt @done
    lda #<kOrcMaxRunSpeed
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>kOrcMaxRunSpeed
    .assert >kOrcMaxRunSpeed > 0, error
    bne @setHi  ; unconditional
    @negative:
    lda Ram_ActorVelX_i16_0_arr, x
    cmp #<-kOrcMaxRunSpeed
    lda Ram_ActorVelX_i16_1_arr, x
    sbc #>-kOrcMaxRunSpeed
    bge @done
    lda #<-kOrcMaxRunSpeed
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>-kOrcMaxRunSpeed
    @setHi:
    sta Ram_ActorVelX_i16_1_arr, x
    @done:
_StopIfBlockedByTerrain:
    jsr Func_SetPointToActorCenter  ; preserves X
    lda #kOrcStopDistance  ; param: offset
    jsr FuncA_Actor_MovePointTowardVelXDir  ; preserves X
    ;; TODO: If a prison gate is in front of the orc, switch to Pounding mode.
    jsr Func_GetTerrainColumnPtrForPointX  ; preserves X
    jsr FuncA_Actor_GetRoomBlockRow  ; preserves X, returns Y
    ;; If the wall in front of the orc's feet is solid, stop in place.
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    bge @stop
    ;; If the wall in front of the orc's head is solid, stop in place.
    dey
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    bge @stop
    ;; If the floor in front of the orc is not solid, stop in place.
    iny
    iny
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    bge @done
    @stop:
    jsr FuncA_Actor_ZeroVelX  ; preserves X
    @done:
_MaybeJump:
    ;; TODO: sometimes jump at player avatar
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Jumping mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Jumping
_ApplyGravity:
    ;; Accelerate the actor downwards.
    lda #kAvatarGravity
    add Ram_ActorVelY_i16_0_arr, x
    sta Ram_ActorVelY_i16_0_arr, x
    lda #0
    adc Ram_ActorVelY_i16_1_arr, x
    ;; If moving downward, check for terminal velocity:
    bmi @setVelYHi
    .assert <kOrcMaxFallSpeed = 0, error
    cmp #>kOrcMaxFallSpeed
    blt @setVelYHi
    lda #0
    sta Ram_ActorVelY_i16_0_arr, x
    lda #>kAvatarMaxAirSpeedVert
    @setVelYHi:
    sta Ram_ActorVelY_i16_1_arr, x
_CheckForFloor:
    ;; Check if the orc has hit the floor.
    jsr Func_SetPointToActorCenter  ; preserves X
    lda #kOrcBoundingBoxDown  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcc @noCollision
    ;; Move the orc upwards to be on top of the floor.
    lda Zp_PointY_i16 + 0
    and #$f0
    sub #kOrcBoundingBoxDown
    sta Ram_ActorPosY_i16_0_arr, x
    lda Zp_PointY_i16 + 1
    sbc #0
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Exit jumping mode.
    jsr FuncA_Actor_ZeroVelY  ; preserves X
    jmp FuncA_Actor_TickBadOrc_StartChasing
    @noCollision:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws an orc baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadOrc
.PROC FuncA_Objects_DrawActorBadOrc
    ldy Ram_ActorFlags_bObj_arr, x  ; param: object flags
    lda Ram_ActorState1_byte_arr, x  ; current mode
    .assert eBadOrc::Standing = 0, error
    beq @standing
    cmp #eBadOrc::Chasing
    beq @chasing
    cmp #eBadOrc::Pausing
    beq @pausing
    @jumping:
    lda #eNpcOrc::Running3  ; param: pose
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @pausing:
    lda #eNpcOrc::Running2  ; param: pose
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @standing:
    lda #eNpcOrc::Standing  ; param: pose
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @chasing:
    lda Ram_ActorState3_byte_arr, x  ; animation counter
    div #8
    and #$03  ; param: pose
    .assert eNpcOrc::Running1 = 0, error
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
.ENDPROC

;;; Draws an orc NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcOrc
.PROC FuncA_Objects_DrawActorNpcOrc
    jsr FuncA_Objects_GetNpcActorFlags  ; preserves X, returns A
    tay  ; param: object flags
    lda Ram_ActorState1_byte_arr, x  ; param: pose
    .assert * = FuncA_Objects_DrawActorOrcInPose, error, "fallthrough"
.ENDPROC

;;; Draws an orc actor in the specified pose.
;;; @param A The eNpcOrc value for the pose.
;;; @param X The actor index.
;;; @param Y The bObj flags to use.
;;; @preserve X
.PROC FuncA_Objects_DrawActorOrcInPose
    sta T2  ; pose index
    sty T3  ; object flags
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X and T0+
    ;; Draw feet:
    ldy T2  ; pose index
    lda _TileIdFeet_u8_arr, y  ; param: first tile ID
    ldy T3  ; param: object flags
    jsr FuncA_Objects_Draw2x2Shape  ; preserves X and T2+
    ;; Draw head:
    lda #kBlockHeightPx
    jsr FuncA_Objects_MoveShapeUpByA  ; preserves X and T0+
    ldy T2  ; pose index
    lda _TileIdHead_u8_arr, y  ; param: first tile ID
    ldy T3  ; param: object flags
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X
_TileIdHead_u8_arr:
    D_ENUM eNpcOrc
    d_byte Running1, kTileIdObjOrcHeadLow
    d_byte Running2, kTileIdObjOrcHeadHigh
    d_byte Running3, kTileIdObjOrcHeadLow
    d_byte Running4, kTileIdObjOrcHeadHigh
    d_byte Standing, kTileIdObjOrcHeadHigh
    D_END
_TileIdFeet_u8_arr:
    D_ENUM eNpcOrc
    d_byte Running1, kTileIdObjOrcFeetRunning1
    d_byte Running2, kTileIdObjOrcFeetRunning2
    d_byte Running3, kTileIdObjOrcFeetRunning3
    d_byte Running4, kTileIdObjOrcFeetRunning2
    d_byte Standing, kTileIdObjOrcFeetStanding
    D_END
.ENDPROC

;;;=========================================================================;;;
