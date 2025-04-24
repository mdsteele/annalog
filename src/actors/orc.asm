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
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../sample.inc"
.INCLUDE "../tileset.inc"
.INCLUDE "orc.inc"

.IMPORT FuncA_Actor_AccelerateForward
.IMPORT FuncA_Actor_ApplyGravityWithTerminalVelocity
.IMPORT FuncA_Actor_ClampVelX
.IMPORT FuncA_Actor_FaceTowardsAvatar
.IMPORT FuncA_Actor_FaceTowardsPoint
.IMPORT FuncA_Actor_FaceTowardsVelXDir
.IMPORT FuncA_Actor_GetRoomBlockRow
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_InitActorProjAxe
.IMPORT FuncA_Actor_IsAvatarWithinHorzDistance
.IMPORT FuncA_Actor_IsAvatarWithinVertDistances
.IMPORT FuncA_Actor_IsInRoomBounds
.IMPORT FuncA_Actor_IsPointInRoomBounds
.IMPORT FuncA_Actor_LandOnTerrain
.IMPORT FuncA_Actor_MovePointTowardVelXDir
.IMPORT FuncA_Actor_NegateVelX
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Actor_SetVelXForward
.IMPORT FuncA_Actor_ZeroVelX
.IMPORT FuncA_Objects_BobActorShapePosUpAndDown
.IMPORT FuncA_Objects_Draw2x1Shape
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_GetNpcActorFlags
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT FuncA_Room_TurnProjectilesToSmoke
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetAngleFromPointToActor
.IMPORT Func_GetAngleFromPointToAvatar
.IMPORT Func_GetTerrainColumnPtrForPointX
.IMPORT Func_InitActorWithFlags
.IMPORT Func_InitActorWithState1
.IMPORT Func_IsActorWithinHorzDistanceOfPoint
.IMPORT Func_IsPointInAnySolidPlatform
.IMPORT Func_MovePointUpByA
.IMPORT Func_Noop
.IMPORT Func_PlaySfxSample
.IMPORT Func_PlaySfxThump
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetMachineIndex
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_SignedDivFrac
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorState4_byte_arr
.IMPORT Ram_ActorSubX_u8_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr

;;;=========================================================================;;;

;;; How many pixels in front of Gronta to spawn the axe actor when throwing.
kGrontaThrowOffset = 8

;;; How many frames Gronta should pause for, kneeling, after getting hit.
kGrontaInjuredFrames = 30
;;; How many frames Gronta should stay invincible for after completing Injured
;;; or SmashWaiting mode.
kGrontaInvincibleFrames = 30
;;; How many frames it takes Gronta wind up for a jump.
kGrontaJumpWindupFrames = 8
;;; How many frames it takes Gronta wind up to smash a machine.
kGrontaSmashWindupFrames = 50
;;; How many frames Gronta pauses for after smashing a machine.
kGrontaSmashRecoverFrames = 45
;;; How many frames it takes Gronta wind up for an axe throw.
kGrontaThrowWindupFrames = 15
;;; How many frames it takes Gronta to catch a returned axe projectile.
kGrontaThrowCatchFrames = 15

;;; How many pixels in front of its center an orc baddie actor checks for solid
;;; terrain to see if it needs to stop, when chasing/patrolling.
kOrcChaseStopDistance = 10
kOrcPatrolStopDistance = 20

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

.SEGMENT "PRGA_Room"

;;; Makes a Gronta actor begin a chasing action.
;;; @param A The bBadGronta value for the chase action.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_BadGrontaBeginChasing
.PROC FuncA_Room_BadGrontaBeginChasing
    sta Ram_ActorState3_byte_arr, x  ; goal (bBadGronta value)
    tay  ; bBadGronta value
    .assert bBadGronta::IsRun = $80, error
    bmi _BeginRunning
_BeginJumping:
    ;; Set Gronta to face in the direction she's jumping.
    .assert bBadGronta::JumpHorzMask = %00001111, error
    and #%00001000
    beq @setFlags
    lda #bObj::FlipH
    @setFlags:
    sta Ram_ActorFlags_bObj_arr, x
    ;; Prepare to jump.
    lda #eBadGronta::JumpWindup
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    lda #kGrontaJumpWindupFrames
    sta Ram_ActorState2_byte_arr, x  ; timer
    rts
_BeginRunning:
    lda #eBadGronta::Running
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    lda #0
    sta Ram_ActorState2_byte_arr, x  ; timer
    rts
.ENDPROC

;;; Makes a Gronta actor begin winding up to throw her axe.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT FuncA_Room_BadGrontaBeginThrowing
.PROC FuncA_Room_BadGrontaBeginThrowing
    lda #kGrontaThrowWindupFrames
    sta Ram_ActorState2_byte_arr, x  ; timer
    lda #eBadGronta::ThrowWindup
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    rts
.ENDPROC

;;; Makes a Gronta actor recover after smashing a machine.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT FuncA_Room_BadGrontaBeginSmashRecover
.PROC FuncA_Room_BadGrontaBeginSmashRecover
    lda #kGrontaSmashRecoverFrames
    sta Ram_ActorState2_byte_arr, x  ; timer
    lda #eBadGronta::SmashRecover
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    rts
.ENDPROC

;;; Makes a Gronta actor get hurt.
;;; @param X The actor index.
;;; @param A The machine index that Gronta should smash, or $ff for none.
;;; @preserve X
.EXPORT FuncA_Room_HarmBadGronta
.PROC FuncA_Room_HarmBadGronta
    sta Ram_ActorState3_byte_arr, x  ; goal (machine index to smash)
    lda #$ff  ; negative = indefinitely invincible
    sta Ram_ActorState4_byte_arr, x  ; invincibility frames
_SetMode:
    ldy Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    cpy #eBadGronta::JumpAirborne
    beq _Airborne
    cpy #eBadGronta::ThrowWaiting
    bne _Injured
_ThrowWaiting:
    ;; Remove the axe actor before switching Gronta to Injured mode.
    lda #eActor::ProjAxeBoomer  ; param: projectile type
    jsr FuncA_Room_TurnProjectilesToSmoke  ; preserves X
_Injured:
    lda #kGrontaInjuredFrames
    sta Ram_ActorState2_byte_arr, x  ; timer
    lda #eBadGronta::Injured
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    lda #0
    sta Ram_ActorVelX_i16_0_arr, x
    sta Ram_ActorVelX_i16_1_arr, x
    rts
_Airborne:
    ;; Gronta is airborne, so we can't put her in Injured mode yet.  Instead
    ;; make her face backwards for the rest of the jump, and she'll be put in
    ;; Injured mode when she lands.
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for an orc baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadGronta
.PROC FuncA_Actor_TickBadGronta
    ;; Decrement Gronta's temporary invincibility frames (if > 0).
    lda Ram_ActorState4_byte_arr, x  ; invincibility frames
    beq @done  ; not invincible
    bmi @done  ; indefinitely invincible
    dec Ram_ActorState4_byte_arr, x  ; invincibility frames
    @done:
_ExecMode:
    ;; Check for collision with player avatar.  The jump targets below can make
    ;; use of the returned C value.
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X, returns C
    ;; Execute mode-specific behavior.
    ldy Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBadGronta
    d_entry table, Idle,         Func_Noop
    d_entry table, Injured,      FuncA_Actor_TickBadGronta_Injured
    d_entry table, JumpWindup,   FuncA_Actor_TickBadGronta_JumpWindup
    d_entry table, JumpAirborne, FuncA_Actor_TickBadGronta_JumpAirborne
    d_entry table, Running,      FuncA_Actor_TickBadGronta_Running
    d_entry table, SmashWindup,  FuncA_Actor_TickBadGronta_SmashWindup
    d_entry table, SmashWaiting, Func_Noop
    d_entry table, SmashRecover, FuncA_Actor_TickBadGronta_SmashRecover
    d_entry table, ThrowWindup,  FuncA_Actor_TickBadGronta_ThrowWindup
    d_entry table, ThrowWaiting, Func_Noop
    d_entry table, ThrowCatch,   FuncA_Actor_TickBadGronta_ThrowCatch
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs per-frame updates for a Gronta baddie actor that's in Injured
;;; mode.
;;; @param C Set if Gronta just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGronta_Injured
    ;; Wait for the injured timer to expire.
    dec Ram_ActorState2_byte_arr, x  ; timer
    bne @done
    ;; If Gronta is supposed to smash the machine that injured her, switch to
    ;; SmashWindup mode; otherwise, switch to Idle mode.
    lda Ram_ActorState3_byte_arr, x  ; goal (machine index to smash)
    bmi @makeIdle  ; no machine to smash
    @smashMachine:
    lda #eBadGronta::SmashWindup
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    lda #kGrontaSmashWindupFrames
    sta Ram_ActorState2_byte_arr, x  ; timer
    rts
    @makeIdle:
    lda #eBadGronta::Idle
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    lda #kGrontaInvincibleFrames
    sta Ram_ActorState4_byte_arr, x  ; invincibility frames
    @done:
    rts
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
    lda Ram_ActorState3_byte_arr, x  ; goal (bBadGronta value)
    and #bBadGronta::RunGoalMask  ; goal tile horz
    .assert kTileWidthPx = (1 << 3), error
    .repeat 3
    asl a
    rol Zp_PointX_i16 + 1
    .endrepeat
    sta Zp_PointX_i16 + 0
    ;; Check if Gronta has reached the goal yet.
    .assert <kOrcMaxRunSpeed > 0, error
    lda #1 + >(kOrcMaxRunSpeed / 2)  ; param: distance
    jsr Func_IsActorWithinHorzDistanceOfPoint  ; preserves X, returns C
    bcs FuncA_Actor_TickBadGronta_ReachedGoal  ; preserves X
    ;; If not, make Gronta run toward the point.
    jsr FuncA_Actor_FaceTowardsPoint  ; preserves X
    ldya #kOrcMaxRunSpeed  ; param: speed
    jmp FuncA_Actor_SetVelXForward  ; preserves X
.ENDPROC

;;; Helper function for Gronta tick modes; stops her on the center of her
;;; current block and puts her into Idle mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGronta_ReachedGoal
    ;; If Gronta got hit while in midair and is now indefinitely invincible,
    ;; switch to Injured mode; otherwise switch to Idle mode.
    lda Ram_ActorState4_byte_arr, x  ; invincibility frames
    .assert eBadGronta::Idle = 0, error
    bmi @makeInjured  ; indefinitely invincible
    @makeIdle:
    lda #eBadGronta::Idle
    .assert eBadGronta::Idle = 0, error
    beq @setMode  ; unconditional
    @makeInjured:
    lda #kGrontaInjuredFrames
    sta Ram_ActorState2_byte_arr, x  ; timer
    lda #eBadGronta::Injured
    @setMode:
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
_AdjustPosition:
    ;; Adjust Gronta to be centered on her current block.
    lda #0
    sta Ram_ActorSubX_u8_arr, x
    lda Ram_ActorPosX_i16_0_arr, x
    .assert kBlockWidthPx = $10, error
    and #$f0
    ora #$08
    sta Ram_ActorPosX_i16_0_arr, x
    jmp FuncA_Actor_ZeroVelX  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a Gronta baddie actor that's in JumpAirborne
;;; mode.
;;; @param C Set if Gronta just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGronta_JumpAirborne
    ;; TODO: Check for side collisions with walls
    jsr FuncA_Actor_TickOrcAirborne  ; preserves X, returns C
    bcs FuncA_Actor_TickBadGronta_ReachedGoal  ; preserves X
    rts
.ENDPROC

;;; Performs per-frame updates for a Gronta baddie actor that's in JumpWindup
;;; mode.
;;; @param C Set if Gronta just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGronta_JumpWindup
    ;; Wait for the timer to expire.
    dec Ram_ActorState2_byte_arr, x  ; timer
    bne _Done
    ;; Set Gronta's initial vertical velocity.
    lda Ram_ActorState3_byte_arr, x  ; goal (bBadGronta value)
    .assert bBadGronta::JumpVertMask = $70, error
    div #$10
    tay  ; vertical offset index
    lda _JumpVelY_i16_0_arr8, y
    sta Ram_ActorVelY_i16_0_arr, x
    lda _JumpVelY_i16_1_arr8, y
    sta Ram_ActorVelY_i16_1_arr, x
    ;; Calculate Gronta's initial horizontal velocity so that she'll travel the
    ;; desired horizontal offset by the time she lands.
    lda _JumpFrames_u8_arr8, y
    tay  ; param: divisor
    lda Ram_ActorState3_byte_arr, x  ; goal (bBadGronta value)
    and #bBadGronta::JumpHorzMask  ; param: signed horz offset in blocks
    .assert bBadGronta::JumpHorzMask = $0f, error
    cmp #$08
    blt @nonnegHorz
    ora #$f0  ; sign-extend to eight bits
    @nonnegHorz:
    mul #kBlockWidthPx  ; param: dividend (signed horz offset in pixels)
    jsr Func_SignedDivFrac  ; preserves X, returns YA
    sta Ram_ActorVelX_i16_0_arr, x
    tya
    sta Ram_ActorVelX_i16_1_arr, x
    ;; Begin the jump.
    lda #eBadGronta::JumpAirborne
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    lda #$ff
    sta Ram_ActorState3_byte_arr, x  ; goal (machine index to smash)
    lda #eSample::JumpGronta  ; param: eSample to play
    jmp Func_PlaySfxSample  ; preserves X
_Done:
    rts
_JumpFrames_u8_arr8:
    .assert kAvatarGravity = 38, error
    .assert kBlockHeightPx = 16, error
    ;; round((v0 + sqrt(v0**2 + 2 * 38 * dy * 16 * 256)) / 38)
    .byte    31,    36,    34,    35,    34,    38,    42,    45
_JumpVelY_i16_0_arr8:
    .byte <-850, <-800, <-650, <-550, <-400, <-400, <-400, <-400
_JumpVelY_i16_1_arr8:
    .byte >-850, >-800, >-650, >-550, >-400, >-400, >-400, >-400
.ENDPROC

;;; Performs per-frame updates for a Gronta baddie actor that's in SmashWindup
;;; mode.
;;; @param C Set if Gronta just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGronta_SmashWindup
    ;; Face towards the machine that is to be smashed.
    stx T4  ; Gronta actor index
    lda Ram_ActorState3_byte_arr, x  ; goal (machine index to smash)
    tax  ; param: machine index
    jsr Func_SetMachineIndex  ; preserves T0+
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    sta T5  ; machine platform index
    tay  ; param: platform index
    jsr Func_SetPointToPlatformCenter  ; preserves T0+
    ldx T4  ; Gronta actor index
    jsr FuncA_Actor_FaceTowardsPoint  ; preserves X and T0+
    ;; Wait for the timer to expire.
    dec Ram_ActorState2_byte_arr, x  ; timer
    bne _Done
    ;; Try to place a new axe projectile in front of Gronta.
    lda #kGrontaThrowOffset  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X and T0+
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcc _InitAxe
_NoAxe:
    ldx T4  ; Gronta actor index
    .assert kMaxActors <= $80, error
    bpl _Done  ; unconditional
_InitAxe:
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    ldy T5  ; param: machine platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X and T0+
    jsr Func_GetAngleFromPointToActor  ; preserves X and T4+, returns A
    eor #$80  ; param: angle
    ldy #eActor::ProjAxeSmash  ; param: actor type
    jsr FuncA_Actor_InitActorProjAxe  ; preserves X and T3+
    lda T5  ; machine platform index
    sta Ram_ActorState2_byte_arr, x  ; goal platform index for axe
    ldx T4  ; Gronta actor index
    lda #eSample::JumpGronta  ; param: eSample to play
    jsr Func_PlaySfxSample  ; preserves X
    lda #eBadGronta::SmashWaiting
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
_Done:
    rts
.ENDPROC

;;; Performs per-frame updates for a Gronta baddie actor that's in SmashRecover
;;; mode.
;;; @param C Set if Gronta just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGronta_SmashRecover
    ;; SmashRecover and ThrowCatch have identical tick implementions (but are
    ;; drawn differently, so still need to be separate modes).
    fall FuncA_Actor_TickBadGronta_ThrowCatch  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a Gronta baddie actor that's in ThrowCatch
;;; mode.
;;; @param C Set if Gronta just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGronta_ThrowCatch
    dec Ram_ActorState2_byte_arr, x  ; timer
    bne @done
    lda #eBadGronta::Idle
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for a Gronta baddie actor that's in ThrowWindup
;;; mode.
;;; @param C Set if Gronta just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGronta_ThrowWindup
    jsr FuncA_Actor_FaceTowardsAvatar  ; preserves X
    ;; Wait for the timer to expire.
    dec Ram_ActorState2_byte_arr, x  ; timer
    bne _Done
    ;; Try to place a new axe projectile in front of Gronta.
    lda #kGrontaThrowOffset  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    stx T4  ; Gronta actor index
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcc _InitAxe
_NoAxe:
    ldx T4  ; Gronta actor index
    lda #eBadGronta::Idle
    .assert eBadGronta::Idle = 0, error
    beq _SetGrontaMode  ; unconditional
_InitAxe:
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    jsr Func_GetAngleFromPointToAvatar  ; preserves X and T4+, returns A
    ldy #eActor::ProjAxeBoomer  ; param: actor type
    jsr FuncA_Actor_InitActorProjAxe  ; preserves T3+
    ldx T4  ; Gronta actor index
    lda #kGrontaThrowCatchFrames
    sta Ram_ActorState2_byte_arr, x  ; timer
    lda #eSample::JumpGronta  ; param: eSample to play
    jsr Func_PlaySfxSample  ; preserves X
    lda #eBadGronta::ThrowWaiting
_SetGrontaMode:
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
_Done:
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
    ;; Check for collision with player avatar.  The jump targets below can make
    ;; use of the returned C value.
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X, returns C
    ;; Execute mode-specific behavior.
    ldy Ram_ActorState1_byte_arr, x  ; current eBadOrc mode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBadOrc
    d_entry table, Standing,      FuncA_Actor_TickBadOrc_Standing
    d_entry table, Chasing,       FuncA_Actor_TickBadOrc_Chasing
    d_entry table, Collapsing,    FuncA_Actor_TickBadOrc_Collapsing
    d_entry table, Escaping,      FuncA_Actor_TickBadOrc_Escaping
    d_entry table, Flinching,     FuncA_Actor_TickBadOrc_Flinching
    d_entry table, Patrolling,    FuncA_Actor_TickBadOrc_Patrolling
    d_entry table, Punching,      FuncA_Actor_TickBadOrc_Punching
    d_entry table, Jumping,       FuncA_Actor_TickBadOrc_Jumping
    d_entry table, TrapSurprised, FuncA_Actor_TickBadOrc_TrapSurprised
    d_entry table, TrapRunning,   FuncA_Actor_TickBadOrc_TrapRunning
    d_entry table, TrapPounding,  FuncA_Actor_TickBadOrc_TrapPounding
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Collapsing
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Collapsing
    .assert <kOrcMaxFallSpeed = 0, error
    lda #>kOrcMaxFallSpeed  ; param: terminal velocity
    jsr FuncA_Actor_ApplyGravityWithTerminalVelocity  ; preserves X
    lda #5  ; param: bounding box down
    jsr FuncA_Actor_LandOnTerrain  ; preserves X, returns C
    bcc @done
    jsr Func_PlaySfxThump  ; preserves X
    lda #eActor::NpcOrcSleeping
    sta Ram_ActorType_eActor_arr, x
    jmp FuncA_Actor_ZeroVelX  ; preserves X
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Escaping mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Escaping
    jsr FuncA_Actor_TickBadOrc_AccelerateForward  ; preserves X
    ;; Remove the orc once it leaves the room.
    jsr FuncA_Actor_IsInRoomBounds  ; preserves X, returns C
    bcs @done  ; still in the room
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Flinching
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Flinching
    ;; Decelerate.
    lda Ram_ActorVelX_i16_0_arr, x
    sub #15
    sta Ram_ActorVelX_i16_0_arr, x
    lda Ram_ActorVelX_i16_1_arr, x
    sbc #0
    bpl @setVelHi
    lda #0
    sta Ram_ActorVelX_i16_0_arr, x
    @setVelHi:
    sta Ram_ActorVelX_i16_1_arr, x
    ;; Once the mode timer expires, run out of the room.
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    bne @done
    lda #eBadOrc::Escaping
    sta Ram_ActorState1_byte_arr, x  ; current eBadOrc mode
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Standing mode.
;;; @param C Set if the orc just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Standing
    bcs FuncA_Actor_TickBadOrc_StartChasing  ; preserves X
    fall FuncA_Actor_TickBadOrc_StartChasingAvatarIfNear  ; preserves X
.ENDPROC

;;; If the player avatar is nearby the orc baddie actor, put the orc into
;;; Chasing mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_StartChasingAvatarIfNear
    ldy #kTileHeightPx * 3  ; param: distance above actor
    lda #kTileHeightPx      ; param: distance below actor
    jsr FuncA_Actor_IsAvatarWithinVertDistances  ; preserves X, returns C
    bcc @done
    lda #kBlockWidthPx * 5  ; param: distance
    jsr FuncA_Actor_IsAvatarWithinHorzDistance  ; preserves X, returns C
    bcs FuncA_Actor_TickBadOrc_StartChasing  ; preserves X
    @done:
    rts
.ENDPROC

;;; Puts an orc baddie actor into Chasing mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_StartChasing
    lda #eBadOrc::Chasing
    sta Ram_ActorState1_byte_arr, x  ; current eBadOrc mode
    lda #0
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    sta Ram_ActorState3_byte_arr, x  ; animation counter
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Punching mode.
;;; @param C Set if the orc just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Punching
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    beq FuncA_Actor_TickBadOrc_StartChasing  ; preserves X
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Jumping mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Jumping
    jsr FuncA_Actor_TickOrcAirborne  ; preserves X, returns C
    bcs FuncA_Actor_TickBadOrc_StartChasing  ; preserves X
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Patrolling
;;; mode.
;;; @param C Set if the orc just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Patrolling
    ;; If done patrolling, return to guarding.
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    bne _StillPatrolling
    lda #eBadOrc::Standing
    sta Ram_ActorState1_byte_arr, x  ; current eBadOrc mode
    jmp FuncA_Actor_ZeroVelX  ; preserves X
_StillPatrolling:
    jsr FuncA_Actor_TickBadOrc_AccelerateForward  ; preserves X
    ;; Turn around if blocked.
    lda #kOrcPatrolStopDistance  ; param: look-ahead distance
    jsr FuncA_Actor_IsOrcVelXBlocked  ; preserves X, returns C
    bcc @done  ; not blocked
    jsr FuncA_Actor_NegateVelX  ; preserves X
    jsr FuncA_Actor_FaceTowardsVelXDir  ; preserves X
    @done:
_WatchForAvatar:
    jmp FuncA_Actor_TickBadOrc_StartChasingAvatarIfNear  ; preserves X
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Chasing mode.
;;; @param C Set if the orc just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Chasing
    ;; If the orc catches the player avatar, pause briefly.
    bcc @noCollide
    jsr Func_PlaySfxThump  ; preserves X
    lda #eBadOrc::Punching
    sta Ram_ActorState1_byte_arr, x  ; current eBadOrc mode
    lda #kOrcPauseFrames
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    jmp FuncA_Actor_ZeroVelX  ; preserves X
    @noCollide:
_StopChasingIfAvatarEscapes:
    ;; If the player avatar gets far away vertically, start patrolling.
    ldy #kTileHeightPx * 5  ; param: distance above actor
    lda #kTileHeightPx * 3  ; param: distance below actor
    jsr FuncA_Actor_IsAvatarWithinVertDistances  ; preserves X, returns C
    bcs _KeepChasing
    lda #eBadOrc::Patrolling
    sta Ram_ActorState1_byte_arr, x  ; current eBadOrc mode
    lda #250
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    rts
_KeepChasing:
    jsr FuncA_Actor_FaceTowardsAvatar  ; preserves X
    jsr FuncA_Actor_TickBadOrc_AccelerateForward  ; preserves X
_StopIfBlocked:
    lda #kOrcChaseStopDistance  ; param: look-ahead distance
    jsr FuncA_Actor_IsOrcVelXBlocked  ; preserves X, returns C
    bcc @done
    jsr FuncA_Actor_ZeroVelX  ; preserves X
    @done:
_MaybeJump:
    ;; TODO: sometimes jump at player avatar
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in TrapSurprised
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_TrapSurprised
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    bne @finish
    lda #eBadOrc::TrapRunning
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    @finish:
    jmp FuncA_Actor_BadOrcTrappedStop  ; preserves X
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in TrapRunning
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_TrapRunning
    jsr FuncA_Actor_TickBadOrc_AccelerateForward  ; preserves X
    lda #kOrcTrappedDistance  ; param: look-ahead distance
    jsr FuncA_Actor_IsOrcFacingDirBlocked  ; preserves X, returns C
    bcc @done  ; not blocked
    lda #eBadOrc::TrapPounding
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    jmp FuncA_Actor_BadOrcTrappedStop  ; preserves X
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in TrapPounding
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_TrapPounding
    lda Ram_ActorState3_byte_arr, x  ; animation counter
    and #$1f
    cmp #$10
    bne @finish
    lda #eSample::AnvilF  ; param: eSample to play
    jsr Func_PlaySfxSample  ; preserves X
    @finish:
    fall FuncA_Actor_BadOrcTrappedStop  ; preserves X
.ENDPROC

;;; Zeroes the orc's X-velocity, and if the orc is blocked closely in front
;;; (e.g. by a prison gate platform that it's intersecting), backs the orc up
;;; by one pixel.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_BadOrcTrappedStop
    lda #kOrcTrappedDistance  ; param: look-ahead distance
    jsr FuncA_Actor_IsOrcFacingDirBlocked  ; preserves X, returns C
    bcc @notBlocked
    lda #<-1  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    @notBlocked:
    jmp FuncA_Actor_ZeroVelX  ; preserves X
.ENDPROC

;;; Checks whether an orc actor can run forward along the ground in the
;;; direction it's facing.
;;; @param A The look-ahead distance, in pixels.
;;; @param X The actor index.
;;; @param C Set if the orc cannot keep moving along its horizontal velocity.
;;; @preserve X
.PROC FuncA_Actor_IsOrcFacingDirBlocked
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jmp FuncA_Actor_IsOrcPointBlocked  ; preserves X, returns C
.ENDPROC

;;; Checks whether an orc actor can run forward along the ground in the
;;; direction of its current horizontal velocity.
;;; @param A The look-ahead distance, in pixels.
;;; @param X The actor index.
;;; @param C Set if the orc cannot keep moving along its horizontal velocity.
;;; @preserve X
.PROC FuncA_Actor_IsOrcVelXBlocked
    pha  ; look-ahead distance
    jsr Func_SetPointToActorCenter  ; preserves X
    pla  ; param: look-ahead distance
    jsr FuncA_Actor_MovePointTowardVelXDir  ; preserves X
    fall FuncA_Actor_IsOrcPointBlocked  ; preserves X, returns C
.ENDPROC

;;; Checks whether an orc actor can run forward along the ground, using the
;;; currently-set look-ahead point to check terrain.
;;; @prereq Zp_PointX_i16 is set to one side of the orc.
;;; @prereq Zp_PointY_i16 is set to the orc actor's Y-position (that is, it is
;;;     centered on the bottom half of the orc).
;;; @param X The actor index.
;;; @param C Set if the orc cannot keep moving along its horizontal velocity.
;;; @preserve X
.PROC FuncA_Actor_IsOrcPointBlocked
    jsr FuncA_Actor_IsPointInRoomBounds  ; preserves X, returns C
    bcc _IsBlocked
_CheckTerrain:
    jsr Func_GetTerrainColumnPtrForPointX  ; preserves X
    jsr FuncA_Actor_GetRoomBlockRow  ; preserves X, returns Y
    ;; Check the wall in front of the orc's feet.
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    bge _IsBlocked  ; wall is solid
    ;; Check the wall in front of the orc's head.
    dey
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    bge _IsBlocked  ; wall is solid
    ;; Check the floor in front of the orc.
    iny
    iny
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    blt _IsBlocked  ; floor is not solid
_CheckPlatforms:
    ;; Check for platforms in front of the orc's head.
    lda #kBlockHeightPx  ; param: offset
    jsr Func_MovePointUpByA  ; preserves X
    jsr Func_IsPointInAnySolidPlatform  ; preserves X, returns C
    bcs _IsBlocked
_NotBlocked:
    clc
    rts
_IsBlocked:
    sec
    rts
.ENDPROC

;;; Accelerates the orc baddie in its current facing direction, up to its
;;; maximum running speed.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_AccelerateForward
    lda #kOrcChasingHorzAccel  ; param: acceleration
    jsr FuncA_Actor_AccelerateForward  ; preserves X
    ldya #kOrcMaxRunSpeed  ; param: max speed
    jmp FuncA_Actor_ClampVelX  ; preserves X
.ENDPROC

;;; Performs per-frame updates for an orc or Gronta actor that's airborne.
;;; @param X The actor index.
;;; @return C Set if the actor has landed on the floor.
;;; @preserve X
.PROC FuncA_Actor_TickOrcAirborne
    .assert <kOrcMaxFallSpeed = 0, error
    lda #>kOrcMaxFallSpeed  ; param: terminal velocity
    jsr FuncA_Actor_ApplyGravityWithTerminalVelocity  ; preserves X
    lda #kOrcBoundingBoxDown  ; param: bounding box down
    jmp FuncA_Actor_LandOnTerrain  ; preserves X, returns C
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a sleeping orc NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcOrcSleeping
.PROC FuncA_Objects_DrawActorNpcOrcSleeping
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    lda #3  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA  ; preserves X
    lda #kTileIdObjOrcGruntSleepingFirst + 2  ; param: first tile ID
    ldy #0  ; param: object flags
    jsr FuncA_Objects_Draw2x1Shape  ; preserves X
    lda #kTileWidthPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeLeftByA  ; preserves X
    lda #kTileIdObjOrcGruntSleepingFirst + 0  ; param: first tile ID
    ldy #0  ; param: object flags
    jmp FuncA_Objects_Draw2x1Shape  ; preserves X
.ENDPROC

;;; Draws a Gronta baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadGronta
.PROC FuncA_Objects_DrawActorBadGronta
    ;; If Gronta is temporarily invincible, blink the objects.
    lda Ram_ActorState4_byte_arr, x  ; invincibility frames
    beq @visible  ; not invincible
    lda Zp_FrameCounter_u8
    and #$02
    beq @visible
    rts
    @visible:
_ChoosePose:
    ldy Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    cpy #eBadGronta::Running
    beq @running
    cpy #eBadGronta::JumpWindup
    beq @jumpWindup
    cpy #eBadGronta::JumpAirborne
    bne @basic
    @jumpAirborne:
    lda Ram_ActorVelY_i16_1_arr, x
    bmi @airborneRising
    @basic:
    lda _Poses_eNpcOrc_arr, y  ; param: pose
    .assert eNpcOrc::NUM_VALUES <= $80, error
    bpl _SetPose  ; unconditional
    @jumpWindup:
    lda Ram_ActorState2_byte_arr, x  ; timer
    cmp #kGrontaJumpWindupFrames * 3 / 4
    bge @basic
    cmp #kGrontaJumpWindupFrames * 1 / 4
    blt @basic
    lda #eNpcOrc::GrontaCrouching  ; param: pose
    bpl _SetPose  ; unconditional
    @airborneRising:
    lda #eNpcOrc::GrontaRunning3  ; param: pose
    bpl _SetPose  ; unconditional
    @running:
    lda Ram_ActorState2_byte_arr, x  ; timer
    div #8
    and #$03
    .assert eNpcOrc::GrontaRunning1 .mod 4 = 0, error
    ora #eNpcOrc::GrontaRunning1  ; param: pose
_SetPose:
    ldy Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jmp FuncA_Objects_DrawActorOrcInPose
_Poses_eNpcOrc_arr:
    D_ARRAY .enum, eBadGronta
    d_byte Idle,         eNpcOrc::GrontaStanding
    d_byte Injured,      eNpcOrc::GrontaKneeling
    d_byte JumpWindup,   eNpcOrc::GrontaStanding
    d_byte JumpAirborne, eNpcOrc::GrontaJumping
    d_byte Running,      eNpcOrc::GrontaRunning1
    d_byte SmashWindup,  eNpcOrc::GrontaAxeRaised
    d_byte SmashWaiting, eNpcOrc::GrontaThrowing
    d_byte SmashRecover, eNpcOrc::GrontaThrowing
    d_byte ThrowWindup,  eNpcOrc::GrontaAxeRaised
    d_byte ThrowWaiting, eNpcOrc::GrontaThrowing
    d_byte ThrowCatch,   eNpcOrc::GrontaAxeRaised
    D_END
.ENDPROC

;;; Draws an orc baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadOrc
.PROC FuncA_Objects_DrawActorBadOrc
    ldy Ram_ActorFlags_bObj_arr, x  ; param: object flags
    lda Ram_ActorState1_byte_arr, x  ; current eBadOrc mode
    .assert eBadOrc::Standing = 0, error
    beq @standing
    cmp #eBadOrc::Punching
    beq @punching
    cmp #eBadOrc::TrapSurprised
    beq @surprised
    cmp #eBadOrc::TrapPounding
    beq @pounding
    cmp #eBadOrc::Collapsing
    beq @kneeling
    cmp #eBadOrc::Flinching
    beq @surprised
    cmp #eBadOrc::Jumping
    bne @running
    @jumping:
    lda #eNpcOrc::GruntRunning3  ; param: pose
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @surprised:
    @punching:
    lda #eNpcOrc::GruntThrowing1  ; param: pose
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @standing:
    lda #eNpcOrc::GruntStanding  ; param: pose
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @kneeling:
    lda #eNpcOrc::GruntKneeling  ; param: pose
    bpl FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @pounding:
    lda Ram_ActorState3_byte_arr, x  ; animation counter
    div #16
    and #$01  ; param: pose
    .assert eNpcOrc::GruntThrowing1 .mod 2 = 0, error
    ora #eNpcOrc::GruntThrowing1
    .assert eNpcOrc::GruntThrowing1 <> 0, error
    bne FuncA_Objects_DrawActorOrcInPose  ; unconditional
    @running:
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
    fall FuncA_Objects_DrawActorOrcInPose
.ENDPROC

;;; Draws an orc actor in the specified pose.
;;; @param A The eNpcOrc value for the pose.
;;; @param X The actor index.
;;; @param Y The bObj flags to use.
;;; @preserve X
.PROC FuncA_Objects_DrawActorOrcInPose
    sta T2  ; pose index
    sty T3  ; feet object flags
    ;; Special case: for eNpcOrc::GrontaLaughing1, automatically animate
    ;; between GrontaLaughing1 and GrontaLaughing2.
    cmp #eNpcOrc::GrontaLaughing1
    bne @doneLaugh
    lda Zp_FrameCounter_u8
    and #$08
    bne @doneLaugh
    .assert eNpcOrc::GrontaLaughing1 + 1 = eNpcOrc::GrontaLaughing2, error
    inc T2  ; now eNpcOrc::GrontaLaughing2
    @doneLaugh:
    ;; Determine object flags for the head.
    lda T2  ; pose index
    cmp #kNpcOrcFirstGronta
    blt @notGronta
    tya
    ora #kPaletteObjGrontaHead
    tay
    @notGronta:
    sty T4  ; head object flags
    ;; Set shape position:
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
    d_byte GruntThrowing1,   kTileIdObjOrcGruntThrowingFirst  + $00
    d_byte GruntThrowing2,   kTileIdObjOrcGruntThrowingFirst  + $08
    d_byte GruntStanding,    kTileIdObjOrcGruntHeadHigh
    d_byte GruntKneeling,    kTileIdObjOrcGruntThrowingFirst  + $00
    d_byte GhostStanding,    kTileIdObjOrcGhostFirst          + $00
    d_byte GrontaArmsRaised, kTileIdObjOrcGrontaParleyFirst   + $00
    d_byte GrontaAxeRaised,  kTileIdObjOrcGrontaStandingFirst + $04
    d_byte GrontaCrouching,  kTileIdObjOrcGrontaCrouchFirst   + $00
    d_byte GrontaJumping,    kTileIdObjOrcGrontaStandingFirst + $04
    d_byte GrontaKneeling,   kTileIdObjOrcGrontaCrouchFirst   + $00
    d_byte GrontaParley,     kTileIdObjOrcGrontaHeadHigh
    d_byte GrontaStanding,   kTileIdObjOrcGrontaHeadHigh
    d_byte GrontaRunning1,   kTileIdObjOrcGrontaHeadLow
    d_byte GrontaRunning2,   kTileIdObjOrcGrontaHeadHigh
    d_byte GrontaRunning3,   kTileIdObjOrcGrontaHeadLow
    d_byte GrontaRunning4,   kTileIdObjOrcGrontaHeadHigh
    d_byte GrontaLaughing1,  kTileIdObjOrcGrontaLaughingFirst + $00
    d_byte GrontaLaughing2,  kTileIdObjOrcGrontaLaughingFirst + $08
    d_byte GrontaThrowing,   kTileIdObjOrcGrontaHeadLow
    d_byte EireneParley,     kTileIdObjEireneParleyFirst      + $00
    D_END
_TileIdFeet_u8_arr:
    D_ARRAY .enum, eNpcOrc
    d_byte GruntRunning1,    kTileIdObjOrcGruntFeetRunning1
    d_byte GruntRunning2,    kTileIdObjOrcGruntFeetRunning2
    d_byte GruntRunning3,    kTileIdObjOrcGruntFeetRunning3
    d_byte GruntRunning4,    kTileIdObjOrcGruntFeetRunning2
    d_byte GruntThrowing1,   kTileIdObjOrcGruntThrowingFirst  + $04
    d_byte GruntThrowing2,   kTileIdObjOrcGruntThrowingFirst  + $0c
    d_byte GruntStanding,    kTileIdObjOrcGruntFeetStanding
    d_byte GruntKneeling,    kTileIdObjOrcGruntKneelingFirst
    d_byte GhostStanding,    kTileIdObjOrcGhostFirst          + $04
    d_byte GrontaArmsRaised, kTileIdObjOrcGrontaStandingFirst + $0c
    d_byte GrontaAxeRaised,  kTileIdObjOrcGrontaStandingFirst + $0c
    d_byte GrontaCrouching,  kTileIdObjOrcGrontaCrouchFirst   + $04
    d_byte GrontaJumping,    kTileIdObjOrcGrontaJumpingFirst
    d_byte GrontaKneeling,   kTileIdObjOrcGrontaCrouchFirst   + $08
    d_byte GrontaParley,     kTileIdObjOrcGrontaParleyFirst   + $04
    d_byte GrontaStanding,   kTileIdObjOrcGrontaStandingFirst + $08
    d_byte GrontaRunning1,   kTileIdObjOrcGrontaFeetRunning1
    d_byte GrontaRunning2,   kTileIdObjOrcGrontaFeetRunning2
    d_byte GrontaRunning3,   kTileIdObjOrcGrontaFeetRunning3
    d_byte GrontaRunning4,   kTileIdObjOrcGrontaFeetRunning2
    d_byte GrontaLaughing1,  kTileIdObjOrcGrontaLaughingFirst + $04
    d_byte GrontaLaughing2,  kTileIdObjOrcGrontaLaughingFirst + $0c
    d_byte GrontaThrowing,   kTileIdObjOrcGrontaThrowingFirst
    d_byte EireneParley,     kTileIdObjEireneParleyFirst      + $04
    D_END
.ENDPROC

;;;=========================================================================;;;
