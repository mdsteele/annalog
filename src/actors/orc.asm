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
.INCLUDE "../tileset.inc"
.INCLUDE "orc.inc"

.IMPORT FuncA_Actor_FaceTowardsAvatar
.IMPORT FuncA_Actor_FaceTowardsPoint
.IMPORT FuncA_Actor_GetRoomBlockRow
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarWithinHorzDistance
.IMPORT FuncA_Actor_IsAvatarWithinVertDistances
.IMPORT FuncA_Actor_MovePointTowardVelXDir
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Actor_SetVelXForward
.IMPORT FuncA_Actor_ZeroVelX
.IMPORT FuncA_Actor_ZeroVelY
.IMPORT FuncA_Objects_BobActorShapePosUpAndDown
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_GetNpcActorFlags
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetTerrainColumnPtrForPointX
.IMPORT Func_InitActorProjAxe
.IMPORT Func_InitActorWithFlags
.IMPORT Func_InitActorWithState1
.IMPORT Func_IsActorWithinHorzDistanceOfPoint
.IMPORT Func_MovePointDownByA
.IMPORT Func_Noop
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SignedAtan2
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
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr

;;;=========================================================================;;;

;;; How many pixels in front of Gronta to spawn the axe actor when throwing.
kGrontaThrowOffset = 8

;;; How many frames it takes Gronta to catch a returned axe projectile.
kGrontaCatchFrames = 15

;;; How many pixels in front of its center an orc baddie actor checks for solid
;;; terrain to see if it needs to stop.
kOrcStopDistance = 10

;;; The horizontal acceleration applied to an orc baddie actor when it's
;;; chasing the player avatar, in subpixels per frame per frame.
kOrcChasingHorzAccel = 40

;;; How many frames the orc should pause for after catching the player avatar.
kOrcPauseFrames = 20

;;; OBJ tile IDs for drawing orc baddie/NPC actors.
kTileIdObjOrcGrontaHeadHigh     = kTileIdObjOrcGrontaStandingFirst +  0
kTileIdObjOrcGrontaHeadLow      = kTileIdObjOrcGrontaRunningFirst  +  0
kTileIdObjOrcGrontaFeetRunning1 = kTileIdObjOrcGrontaRunningFirst  +  4
kTileIdObjOrcGrontaFeetRunning2 = kTileIdObjOrcGrontaRunningFirst  +  8
kTileIdObjOrcGrontaFeetRunning3 = kTileIdObjOrcGrontaRunningFirst  + 12
kTileIdObjOrcGruntHeadHigh      = kTileIdObjOrcGruntStandingFirst  +  0
kTileIdObjOrcGruntHeadLow       = kTileIdObjOrcGruntRunningFirst   +  0
kTileIdObjOrcGruntFeetStanding  = kTileIdObjOrcGruntStandingFirst  +  4
kTileIdObjOrcGruntFeetRunning1  = kTileIdObjOrcGruntRunningFirst   +  4
kTileIdObjOrcGruntFeetRunning2  = kTileIdObjOrcGruntRunningFirst   +  8
kTileIdObjOrcGruntFeetRunning3  = kTileIdObjOrcGruntRunningFirst   + 12

;;; The OBJ palette number to use for Gronta's head.
kPaletteObjGrontaHead = 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes a Gronta baddie actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The flags to set.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT Func_InitActorBadGronta
.PROC Func_InitActorBadGronta
    ldy #eActor::BadGronta  ; param: actor type
    jmp Func_InitActorWithFlags
.ENDPROC

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

;;; Initializes an orc NPC actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The eNpcOrc value.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT Func_InitActorNpcOrc
.PROC Func_InitActorNpcOrc
    ldy #eActor::NpcOrc  ; param: actor type
    jmp Func_InitActorWithState1
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for an orc baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadGronta
.PROC FuncA_Actor_TickBadGronta
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
    D_TABLE .enum, eBadGronta
    d_entry table, Standing,     Func_Noop
    d_entry table, Running,      FuncA_Actor_TickBadGronta_Running
    d_entry table, ThrowWindup,  FuncA_Actor_TickBadGronta_ThrowWindup
    d_entry table, ThrowWaiting, Func_Noop
    d_entry table, ThrowCatch,   FuncA_Actor_TickBadGronta_ThrowCatch
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs per-frame updates for a Gronta baddie actor that's in Running
;;; mode.
;;; @param C Set if Gronta just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGronta_Running
    inc Ram_ActorState2_byte_arr, x  ; timer
    ;; Store the goal X-position in Zp_PointX_i16.
    lda #0
    sta Zp_PointX_i16 + 1
    lda Ram_ActorState3_byte_arr, x  ; goal tile horz
    .assert kTileWidthPx = (1 << 3), error
    .repeat 3
    asl a
    rol Zp_PointX_i16 + 1
    .endrepeat
    sta Zp_PointX_i16 + 0
    ;; Check if Gronta has reached the goal yet.
    .assert <kOrcMaxRunSpeed > 0, error
    lda #>kOrcMaxRunSpeed + 1  ; param: distance
    jsr Func_IsActorWithinHorzDistanceOfPoint  ; preserves X, returns C
    bcs @reachedGoal
    ;; If not, make Gronta run toward the point.
    jsr FuncA_Actor_FaceTowardsPoint  ; preserves X
    ldya #kOrcMaxRunSpeed  ; param: speed
    jmp FuncA_Actor_SetVelXForward  ; preserves X
    ;; Once the goal has been reached, make Gronta stand there.
    @reachedGoal:
    lda #eBadGronta::Standing
    sta Ram_ActorState1_byte_arr, x  ; current mode
    jmp FuncA_Actor_ZeroVelX  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a Gronta baddie actor that's in ThrowWindup
;;; mode.
;;; @param C Set if Gronta just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGronta_ThrowWindup
    jsr FuncA_Actor_FaceTowardsAvatar  ; preserves X
    dec Ram_ActorState2_byte_arr, x  ; timer
    bne _Done
    lda #kGrontaThrowOffset  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    stx T5  ; Gronta actor index
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcc _InitAxe
_NoAxe:
    ldx T5  ; Gronta actor index
    lda #eBadGronta::Standing
    .assert eBadGronta::Standing = 0, error
    beq _SetGrontaMode  ; unconditional
_InitAxe:
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    stx T4  ; axe actor index
    ;; TODO: factor this out (from here to the Func_SignedAtan2 call)
    lda Zp_AvatarPosX_i16 + 0
    sub Zp_PointX_i16 + 0
    sta T0  ; horz delta from axe to avatar (lo)
    lda Zp_AvatarPosX_i16 + 1
    sbc Zp_PointX_i16 + 1
    .repeat 3
    lsr a
    ror T0  ; horz delta from axe to avatar (lo)
    .endrepeat
    lda Zp_AvatarPosY_i16 + 0
    sub Zp_PointY_i16 + 0
    sta T1  ; vert delta from axe to avatar (lo)
    lda Zp_AvatarPosY_i16 + 1
    sbc Zp_PointY_i16 + 1
    .repeat 3
    lsr a
    ror T1  ; vert delta from axe to avatar (lo)
    .endrepeat
    lda T0  ; param: horz delta (signed)
    ldy T1  ; param: vert delta (signed)
    jsr Func_SignedAtan2  ; preserves T4+, returns A (param: axe angle)
    ldx T4  ; param: axe actor index
    jsr Func_InitActorProjAxe  ; preserves T3+
    ldx T5  ; Gronta actor index
    lda #kGrontaCatchFrames
    sta Ram_ActorState2_byte_arr, x  ; timer
    lda #eBadGronta::ThrowWaiting
_SetGrontaMode:
    sta Ram_ActorState1_byte_arr, x  ; current mode
_Done:
    rts
.ENDPROC

;;; Performs per-frame updates for a Gronta baddie actor that's in ThrowCatch
;;; mode.
;;; @param C Set if Gronta just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGronta_ThrowCatch
    dec Ram_ActorState2_byte_arr, x  ; timer
    bne @done
    lda #eBadGronta::Standing
    sta Ram_ActorState1_byte_arr, x  ; current mode
    @done:
    rts
.ENDPROC

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
    D_TABLE .enum, eBadOrc
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
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    bge @stop
    ;; If the wall in front of the orc's head is solid, stop in place.
    dey
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    bge @stop
    ;; If the floor in front of the orc is not solid, stop in place.
    iny
    iny
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
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

;;; Draws a Gronta baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadGronta
.PROC FuncA_Objects_DrawActorBadGronta
    ldy Ram_ActorFlags_bObj_arr, x  ; param: object flags
    lda Ram_ActorState1_byte_arr, x  ; current mode
    .assert eBadGronta::Standing = 0, error
    beq @standing
    cmp #eBadGronta::Running
    beq @running
    cmp #eBadGronta::ThrowWaiting
    beq @throwing
    @armsRaised:
    lda #eNpcOrc::GrontaArmsRaised  ; param: pose
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @throwing:
    lda #eNpcOrc::GrontaThrowing  ; param: pose
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @standing:
    lda #eNpcOrc::GrontaStanding  ; param: pose
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @running:
    lda Ram_ActorState2_byte_arr, x  ; timer
    div #8
    and #$03
    .assert eNpcOrc::GrontaRunning1 .mod 4 = 0, error
    ora #eNpcOrc::GrontaRunning1  ; param: pose
    .assert eNpcOrc::GrontaRunning1 > 0, error
    bne FuncA_Objects_DrawActorOrcInPose  ; unconditional
.ENDPROC

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
    lda #eNpcOrc::GruntRunning3  ; param: pose
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @pausing:
    lda #eNpcOrc::GruntThrowing1  ; param: pose
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @standing:
    lda #eNpcOrc::GruntStanding  ; param: pose
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @chasing:
    lda Ram_ActorState3_byte_arr, x  ; animation counter
    div #8
    and #$03  ; param: pose
    .assert eNpcOrc::GruntRunning1 = 0, error
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
    sty T3  ; feet object flags
    cmp #kNpcOrcFirstGronta
    blt @notGronta
    tya
    ora #kPaletteObjGrontaHead
    tay
    @notGronta:
    sty T4  ; head object flags
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X and T0+
    lda T2  ; pose index
    cmp #eNpcOrc::GhostStanding
    bne @notGhost
    jsr FuncA_Objects_BobActorShapePosUpAndDown  ; preserves X and T1+
    @notGhost:
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
    ldy T4  ; param: object flags
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X
_TileIdHead_u8_arr:
    D_ARRAY .enum, eNpcOrc
    d_byte GruntRunning1,    kTileIdObjOrcGruntHeadLow
    d_byte GruntRunning2,    kTileIdObjOrcGruntHeadHigh
    d_byte GruntRunning3,    kTileIdObjOrcGruntHeadLow
    d_byte GruntRunning4,    kTileIdObjOrcGruntHeadHigh
    d_byte GruntStanding,    kTileIdObjOrcGruntHeadHigh
    d_byte GruntThrowing1,   kTileIdObjOrcGruntThrowingFirst  + $00
    d_byte GruntThrowing2,   kTileIdObjOrcGruntThrowingFirst  + $08
    d_byte GhostStanding,    kTileIdObjOrcGhostFirst          + $00
    d_byte GrontaRunning1,   kTileIdObjOrcGrontaHeadLow
    d_byte GrontaRunning2,   kTileIdObjOrcGrontaHeadHigh
    d_byte GrontaRunning3,   kTileIdObjOrcGrontaHeadLow
    d_byte GrontaRunning4,   kTileIdObjOrcGrontaHeadHigh
    d_byte GrontaArmsRaised, kTileIdObjOrcGrontaStandingFirst + $04
    d_byte GrontaJumping,    kTileIdObjOrcGrontaStandingFirst + $04
    d_byte GrontaStanding,   kTileIdObjOrcGrontaHeadHigh
    d_byte GrontaThrowing,   kTileIdObjOrcGrontaHeadLow
    D_END
_TileIdFeet_u8_arr:
    D_ARRAY .enum, eNpcOrc
    d_byte GruntRunning1,    kTileIdObjOrcGruntFeetRunning1
    d_byte GruntRunning2,    kTileIdObjOrcGruntFeetRunning2
    d_byte GruntRunning3,    kTileIdObjOrcGruntFeetRunning3
    d_byte GruntRunning4,    kTileIdObjOrcGruntFeetRunning2
    d_byte GruntStanding,    kTileIdObjOrcGruntFeetStanding
    d_byte GruntThrowing1,   kTileIdObjOrcGruntThrowingFirst  + $04
    d_byte GruntThrowing2,   kTileIdObjOrcGruntThrowingFirst  + $0c
    d_byte GhostStanding,    kTileIdObjOrcGhostFirst          + $04
    d_byte GrontaRunning1,   kTileIdObjOrcGrontaFeetRunning1
    d_byte GrontaRunning2,   kTileIdObjOrcGrontaFeetRunning2
    d_byte GrontaRunning3,   kTileIdObjOrcGrontaFeetRunning3
    d_byte GrontaRunning4,   kTileIdObjOrcGrontaFeetRunning2
    d_byte GrontaArmsRaised, kTileIdObjOrcGrontaStandingFirst + $0c
    d_byte GrontaJumping,    kTileIdObjOrcGrontaJumpingFirst
    d_byte GrontaStanding,   kTileIdObjOrcGrontaStandingFirst + $08
    d_byte GrontaThrowing,   kTileIdObjOrcGrontaThrowingFirst
    D_END
.ENDPROC

;;;=========================================================================;;;
