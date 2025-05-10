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
.INCLUDE "adult.inc"
.INCLUDE "ghost.inc"
.INCLUDE "orc.inc"

.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT FuncA_Actor_ClampVelX
.IMPORT FuncA_Actor_ClampVelY
.IMPORT FuncA_Actor_FaceTowardsAvatar
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Actor_ZeroVel
.IMPORT FuncA_Actor_ZeroVelY
.IMPORT FuncA_Objects_BobActorShapePosUpAndDown
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_Draw2x3TownsfolkShape
.IMPORT FuncA_Objects_MoveShapeHorz
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_MoveShapeVert
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_Cosine
.IMPORT Func_DivMod
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetAngleFromPointToAvatar
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorProjFireball
.IMPORT Func_InitActorWithState1
.IMPORT Func_MovePointUpByA
.IMPORT Func_Noop
.IMPORT Func_PlaySfxShootFire
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SignedMult
.IMPORT Func_Sine
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorState4_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

;;; The maximum speed that a ghost baddie is allowed to move, in pixels per
;;; frame.
kBadGhostMaxMoveSpeed = 2

;;; The acceleration rate of a ghost baddie in SpecialMoving mode, in subpixels
;;; per frame per frame.
kBadGhostSpecialMovingAccel = 50

;;; How many frames it takes a ghost baddie actor to appear or disappear.
kBadGhostAppearFrames = 45
;;; How long a ghost baddie is stunned for before disappearing when it is
;;; injured, in frames.
kBadGhostInjuredFrames = 120
;;; How long between a ghost baddie's movement cycles, in frames.
kBadGhostMoveFrames = 180
;;; How long a mermaid ghost attack salvo lasts, in frames.
kBadGhostMermaidAttackFrames = 100
;;; How long an orc ghost poses after attacking, in frames.
kBadGhostOrcAttackFrames = 70
;;; How long a ghost baddie pauses between appearing and executing its special
;;; attack, in frames.
kBadGhostSpecialWaitingFrames = 90

;;; Bounds for the room block cols/rows that can be set as goal positions for a
;;; ghost baddie.
kBadGhostGoalPosFirstCol =  3
kBadGhostGoalPosFirstRow =  3
kBadGhostGoalPosNumCols  = 10
kBadGhostGoalPosNumRows  =  7

;;; OBJ palette numbers for drawing ghost baddies.
kPaletteObjBadGhostNormal = 0
kPaletteObjBadGhostHurt   = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Turns an NPC mermaid ghost or orc ghost into a ghost baddie, and then makes
;;; it disappear.
;;; @param X The actor index.
;;; @param Y The new actor type for the ghost (BadGhostMermaid or BadGhostOrc).
.EXPORT FuncA_Room_MakeNpcGhostDisappear
.PROC FuncA_Room_MakeNpcGhostDisappear
    lda #eBadGhost::Disappearing  ; param: eBadGhost value
    jsr Func_InitActorWithState1  ; preserves X
_FaceAvatar:
    ;; Make the ghost baddie face the player avatar.  (We can't just save and
    ;; restore the NPC actor's previous bObj flags, because the NPC might have
    ;; just had flags of 0, and be using State2 = 0 to automatically be drawn
    ;; facing the avatar.)
    lda Zp_AvatarPosX_i16 + 0
    cmp Ram_ActorPosX_i16_0_arr, x
    lda Zp_AvatarPosX_i16 + 1
    sbc Ram_ActorPosX_i16_1_arr, x
    bpl @done  ; actor should face right, which is the default
    lda #bObj::FlipH  ; make actor face left
    sta Ram_ActorFlags_bObj_arr, x
    @done:
_PlaySound:
    ;; TODO: Play a sound for the ghost disappearing
    rts
.ENDPROC

;;; Makes a mermaid/orc ghost baddie appear and begin attacking.
;;; @prereq The ghost is in eBadGhost::Absent mode.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_MakeBadGhostAppearForAttack
.PROC FuncA_Room_MakeBadGhostAppearForAttack
    lda #eBadGhost::AppearForAttack  ; param: eBadGhost::AppearFor* value
    fall FuncA_Room_MakeBadGhostAppear  ; preserves X
.ENDPROC

;;; Makes a mermaid/orc ghost baddie appear in the specified mode.
;;; @prereq The ghost is in eBadGhost::Absent mode.
;;; @param A The eBadGhost::AppearFor* mode to set.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_MakeBadGhostAppear
.PROC FuncA_Room_MakeBadGhostAppear
    sta Ram_ActorState1_byte_arr, x  ; eBadGhost mode
    lda #kBadGhostAppearFrames
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Injures a ghost baddie.
;;; @prereq The ghost baddie is in a vulnerable mode.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Machine_InjureBadGhost
.PROC FuncA_Machine_InjureBadGhost
    ;; If the ghost is currently doing a special attack, switch to the
    ;; corresponding injured state (so that the special attack can continue
    ;; depsite the injury).
    lda Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    cmp #eBadGhost::SpecialMoving
    beq @specialMoving
    cmp #eBadGhost::SpecialWaiting
    beq @specialWaiting
    ;; In all other cases, switch to InjuredAttacking mode (and zero the mode
    ;; timer), which will interrupt and cancel the ghost's attack pattern.
    lda #0
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    lda #eBadGhost::InjuredAttacking
    .assert eBadGhost::InjuredAttacking <> 0, error
    bne @setState  ; unconditional
    @specialMoving:
    lda #eBadGhost::InjuredSpecMove
    .assert eBadGhost::InjuredSpecMove <> 0, error
    bne @setState  ; unconditional
    @specialWaiting:
    lda #eBadGhost::InjuredSpecWait
    @setState:
    sta Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    ;; TODO: set goal pos to current position plus offset towards room center
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for an orc ghost baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadGhostMermaid
.PROC FuncA_Actor_TickBadGhostMermaid
    ldy Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, t
    D_TABLE_LO t, _JumpTable_ptr_0_arr
    D_TABLE_HI t, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBadGhost
    d_entry t, Absent,           Func_Noop
    d_entry t, AppearForAttack,  FuncA_Actor_TickBadGhost_AppearForAttack
    d_entry t, AppearForMerge,   FuncA_Actor_TickBadGhost_AppearForMerge
    d_entry t, AppearForSpecial, FuncA_Actor_TickBadGhost_AppearForSpecial
    d_entry t, Disappearing,     FuncA_Actor_TickBadGhost_Disappearing
    d_entry t, InjuredAttacking, FuncA_Actor_TickBadGhost_InjuredAttacking
    d_entry t, InjuredSpecMove,  FuncA_Actor_TickBadGhostMermaid_SpecialMoving
    d_entry t, InjuredSpecWait,  FuncA_Actor_TickBadGhost_SpecialWaiting
    d_entry t, AttackMoving,     FuncA_Actor_TickBadGhost_AttackMoving
    d_entry t, AttackShooting,   FuncA_Actor_TickBadGhostMermaid_AttackShooting
    d_entry t, SpecialMoving,    FuncA_Actor_TickBadGhostMermaid_SpecialMoving
    d_entry t, SpecialWaiting,   FuncA_Actor_TickBadGhost_SpecialWaiting
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs per-frame updates for an orc ghost baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadGhostOrc
.PROC FuncA_Actor_TickBadGhostOrc
    ldy Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, t
    D_TABLE_LO t, _JumpTable_ptr_0_arr
    D_TABLE_HI t, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBadGhost
    d_entry t, Absent,           Func_Noop
    d_entry t, AppearForAttack,  FuncA_Actor_TickBadGhost_AppearForAttack
    d_entry t, AppearForMerge,   FuncA_Actor_TickBadGhost_AppearForMerge
    d_entry t, AppearForSpecial, FuncA_Actor_TickBadGhost_AppearForSpecial
    d_entry t, Disappearing,     FuncA_Actor_TickBadGhost_Disappearing
    d_entry t, InjuredAttacking, FuncA_Actor_TickBadGhost_InjuredAttacking
    d_entry t, InjuredSpecMove,  FuncA_Actor_TickBadGhostOrc_SpecialMoving
    d_entry t, InjuredSpecWait,  FuncA_Actor_TickBadGhost_SpecialWaiting
    d_entry t, AttackMoving,     FuncA_Actor_TickBadGhost_AttackMoving
    d_entry t, AttackShooting,   FuncA_Actor_TickBadGhostOrc_AttackShooting
    d_entry t, SpecialMoving,    FuncA_Actor_TickBadGhostOrc_SpecialMoving
    d_entry t, SpecialWaiting,   FuncA_Actor_TickBadGhost_SpecialWaiting
    D_END
.ENDREPEAT
.ENDPROC

;;; Chooses a random goal position for the ghost baddie within the BossShadow
;;; room, and stores it in State4.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_PickRandomGoalPos
    ;; Choose a random goal row.
    jsr Func_GetRandomByte  ; preserves X, returns A
    ldy #kBadGhostGoalPosNumRows  ; param: divisor
    jsr Func_DivMod  ; preserves X, returns remainder in A
    add #kBadGhostGoalPosFirstRow
    sta T2  ; goal row
    ;; Choose a random goal column.
    jsr Func_GetRandomByte  ; preserves X and T0+, returns A
    ldy #kBadGhostGoalPosNumCols  ; param: divisor
    jsr Func_DivMod  ; preserves X and T2+, returns remainder in A
    add #kBadGhostGoalPosFirstCol
    ;; TODO: Try again if this position is inside a solid forcefield platform.
    ;; Pack column and row into State4.
    mul #$10
    ora T2  ; goal row
    sta Ram_ActorState4_byte_arr, x  ; goal position
    rts
.ENDPROC

;;; Unpacks the goal position encoded in State4 for the ghost baddie, and
;;; stores the position in Zp_Point*_i16.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_SetPointToGoalPos
    lda #0
    sta Zp_PointX_i16 + 1
    sta Zp_PointY_i16 + 1
    ;; The hi nibble of State4 holds the room block column index for the goal
    ;; X-position.  Replace the lo nibble with kTileWidthPx to get a goal
    ;; X-position in the middle of the block column.
    lda Ram_ActorState4_byte_arr, x  ; goal position
    .assert kBlockWidthPx = $10, error
    and #$f0
    ora #kTileWidthPx
    sta Zp_PointX_i16 + 0
    ;; The lo nibble of State4 holds the room block row index for the goal
    ;; Y-position.  Left-shift by four bits while setting the hi bit of the lo
    ;; nibble, so as to get a goal Y-position in the middle of the block row.
    lda Ram_ActorState4_byte_arr, x  ; goal position
    .assert kBlockHeightPx = $10, error
    sec
    rol a
    mul #$08
    sta Zp_PointY_i16 + 0
    rts
.ENDPROC

;;; Chooses a random goal position for the ghost baddie within the BossShadow
;;; room, and stores it in State4, then sets the ghost's room pixel position to
;;; that new goal position and makes the ghost face the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_SetCenterToRandomGoalPos
    jsr FuncA_Actor_TickBadGhost_PickRandomGoalPos  ; preserves X
    jsr FuncA_Actor_TickBadGhost_SetPointToGoalPos  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    jmp FuncA_Actor_FaceTowardsAvatar  ; preserves X
.ENDPROC

;;; Makes the ghost baddie actor move towards its current goal position by one
;;; frame, slowing down as it approaches its goal.
;;; @prereq The hi bytes of the ghost's X/Y position values are both zero.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_MoveTowardsGoalPos
    jsr FuncA_Actor_FaceTowardsAvatar  ; preserves X
    jsr FuncA_Actor_TickBadGhost_SetPointToGoalPos  ; preserves X
_AccelerateTowardGoalX:
    ;; Compute the (signed) delta from the boss's current X-position to its
    ;; goal X-position, in pixels, and store double its value in T1T0.
    lda Zp_PointX_i16 + 0
    sub Ram_ActorPosX_i16_0_arr, x
    sta T0  ; delta (lo)
    lda Zp_PointX_i16 + 1
    sbc Ram_ActorPosX_i16_1_arr, x
    asl T0  ; 2x delta (lo)
    rol a
    sta T1  ; 2x delta (hi)
    ;; Use the doubled position delta in pixels as an acceleration in subpixels
    ;; per frame, adding it to the ghost's current velocity, storing the
    ;; accelerated velocity in both T1T0 and AT2.
    lda T0  ; acceleration (lo)
    add Ram_ActorVelX_i16_0_arr, x
    sta T0  ; accelerated X-velocity (lo)
    sta T2  ; accelerated X-velocity (lo)
    lda T1  ; acceleration (hi)
    adc Ram_ActorVelX_i16_1_arr, x
    sta T1  ; accelerated X-velocity (hi)
    ;; Divide the acceleration velocity in AT2 by 8 to get a (negative) drag
    ;; force, storing it in T3T2.
    .repeat 3
    cmp #$80  ; copy bit 7 into C
    ror a   ; accelerated X-velocity (hi)
    ror T2  ; accelerated X-velocity (lo)
    .endrepeat
    sta T3  ; drag force (hi)
    ;; Subtract the (negative) drag force in T3T2 from the acceleration
    ;; velocity in T1T0 to get the dragged velocity.
    lda T0  ; accelerated X-velocity (lo)
    sub T2  ; drag force (lo)
    sta Ram_ActorVelX_i16_0_arr, x
    lda T1  ; accelerated X-velocity (hi)
    sbc T3  ; drag force (hi)
    sta Ram_ActorVelX_i16_1_arr, x
    ;; Clamp the dragged velocity to get the final new velocity for this frame.
    ldya #kBadGhostMaxMoveSpeed * $100  ; param: max speed
    jsr FuncA_Actor_ClampVelX  ; preserves X
_AccelerateTowardGoalY:
    ;; Compute the (signed) delta from the boss's current X-position to its
    ;; goal X-position, in pixels, and store double its value in T1T0.
    lda Zp_PointY_i16 + 0
    sub Ram_ActorPosY_i16_0_arr, x
    sta T0  ; delta (lo)
    lda Zp_PointY_i16 + 1
    sbc Ram_ActorPosY_i16_1_arr, x
    asl T0  ; 2x delta (lo)
    rol a
    sta T1  ; 2x delta (hi)
    ;; Use the doubled position delta in pixels as an acceleration in subpixels
    ;; per frame, adding it to the ghost's current velocity, storing the
    ;; accelerated velocity in both T1T0 and AT2.
    lda T0  ; acceleration (lo)
    add Ram_ActorVelY_i16_0_arr, x
    sta T0  ; accelerated Y-velocity (lo)
    sta T2  ; accelerated Y-velocity (lo)
    lda T1  ; acceleration (hi)
    adc Ram_ActorVelY_i16_1_arr, x
    sta T1  ; accelerated Y-velocity (hi)
    ;; Divide the acceleration velocity in AT2 by 8 to get a (negative) drag
    ;; force, storing it in T3T2.
    .repeat 3
    cmp #$80  ; copy bit 7 into C
    ror a   ; accelerated Y-velocity (hi)
    ror T2  ; accelerated Y-velocity (lo)
    .endrepeat
    sta T3  ; drag force (hi)
    ;; Subtract the (negative) drag force in T3T2 from the acceleration
    ;; velocity in T1T0 to get the dragged velocity.
    lda T0  ; accelerated Y-velocity (lo)
    sub T2  ; drag force (lo)
    sta Ram_ActorVelY_i16_0_arr, x
    lda T1  ; accelerated Y-velocity (hi)
    sbc T3  ; drag force (hi)
    sta Ram_ActorVelY_i16_1_arr, x
    ;; Clamp the dragged velocity to get the final new velocity for this frame.
    ldya #kBadGhostMaxMoveSpeed * $100  ; param: max speed
    jmp FuncA_Actor_ClampVelY  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a mermaid/orc ghost baddie actor that's in
;;; Disappearing mode.
;;;   * When initializing this mode, set the State2 timer to zero.  The State3
;;;     counter is ignored.
;;;   * The State2 timer increments each frame from zero to
;;;     kBadGhostAppearFrames, at which point the ghost switches to Absent
;;;     mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_Disappearing
    ;; Increment timer until it reaches its end value.
    inc Ram_ActorState2_byte_arr, x  ; mode timer
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    cmp #kBadGhostAppearFrames
    blt @done
    ;; When the timer finishes, make the ghost absent and clear its timer.
    lda #eBadGhost::Absent
    sta Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    .assert eBadGhost::Absent = 0, error
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    @done:
    jmp FuncA_Actor_ZeroVel  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a mermaid/orc ghost baddie actor that's in
;;; Injured mode.
;;;   * When initializing this mode, set the State2 timer to zero.  The State3
;;;     counter is ignored.
;;;   * The State2 timer increments each frame from zero to
;;;     kBadGhostInjuredFrames, at which point the ghost switches to
;;;     Disappearing mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_InjuredAttacking
    ;; TODO: If timer is zero, pick a new goal position that's a bit to the
    ;; side of the current goal position.
    jsr FuncA_Actor_TickBadGhost_MoveTowardsGoalPos  ; preserves X
_IncrementTimer:
    inc Ram_ActorState2_byte_arr, x  ; mode timer
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    cmp #kBadGhostInjuredFrames
    blt @done
    ;; When the timer finishes, make the ghost disappear and clear its timer.
    lda #eBadGhost::Disappearing
    sta Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    lda #0
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for a mermaid/orc ghost baddie actor that's in
;;; AppearForMerge mode.
;;;   * When initializing this mode, set the State2 timer to
;;;     kBadGhostAppearFrames.  The State3 counter is ignored.
;;;   * The State2 timer decrements each frame from kBadGhostAppearFrames to
;;;     zero, at which point the mermaid ghost switches to Absent mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_AppearForMerge
    lda #$64  ; room block row 4, column 6
    sta Ram_ActorState4_byte_arr, x  ; goal position
    jsr FuncA_Actor_TickBadGhost_SetPointToGoalPos  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    ;; Decrement timer until it reaches zero.
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    bne @done
    ;; Switch modes.  The timer is already at zero.
    lda #eBadGhost::Absent
    sta Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    @done:
    jmp FuncA_Actor_ZeroVel  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a mermaid/orc ghost baddie actor that's in
;;; AppearForAttack mode.
;;;   * When initializing this mode, set the State2 timer to
;;;     kBadGhostAppearFrames.  The State3 counter is ignored.
;;;   * The State2 timer decrements each frame from kBadGhostAppearFrames to
;;;     zero, at which point the mermaid ghost switches to AttackShooting mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_AppearForAttack
    lda #eBadGhost::AttackShooting  ; param: mode to switch to
    .assert eBadGhost::AttackShooting > 0, error
    bne FuncA_Actor_TickBadGhost_AppearThenChangeModes  ; unconditional
.ENDPROC

;;; Performs per-frame updates for a mermaid/orc ghost baddie actor that's in
;;; AppearForSpecial mode.
;;;   * When initializing this mode, set the State2 timer to
;;;     kBadGhostAppearFrames.  The State3 counter is ignored.
;;;   * The State2 timer decrements each frame from kBadGhostAppearFrames to
;;;     zero, at which point the mermaid ghost switches to SpecialWaiting mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_AppearForSpecial
    lda #eBadGhost::SpecialWaiting  ; param: mode to switch to
    fall FuncA_Actor_TickBadGhost_AppearThenChangeModes  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a mermaid/orc ghost baddie actor that's in
;;; an AppearFor* mode.  Once the ghost has fully appeared, switches to the
;;; specified mode, with the State2 timer set to zero.
;;; @param A The eBadGhost mode to switch to once the ghost appears.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_AppearThenChangeModes
    pha  ; mode to switch to
_InitialTeleport:
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    cmp #kBadGhostAppearFrames
    blt @done
    jsr FuncA_Actor_TickBadGhost_SetCenterToRandomGoalPos  ; preserves X
    @done:
_DecrementTimer:
    pla  ; mode to switch to
    ;; Decrement timer until it reaches zero.
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    bne @done
    ;; Switch modes.  The timer is already at zero.
    sta Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    @done:
    jmp FuncA_Actor_ZeroVel  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a mermaid ghost baddie actor that's in
;;; AttackMoving mode.
;;;   * When initializing this mode, set the State2 timer to zero, and the
;;;     State3 counter to the number of times to move before disappearing.
;;;   * The State2 timer decrements each frame until it's zero.
;;;   * Each time the State2 timer is zero, the ghost dodges to a new location,
;;;     State3, the State3 counter is decremented, and the timer is set again.
;;;   * When the State2 timer and the State3 counter are both zero, the mermaid
;;;     ghost switches to Disappearing mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_AttackMoving
    jsr FuncA_Actor_TickBadGhost_MoveTowardsGoalPos  ; preserves X
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    beq _TimerExpired
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    rts
_TimerExpired:
    lda Ram_ActorState3_byte_arr, x  ; mode counter
    beq _ChangeMode
_PickNewGoal:
    dec Ram_ActorState3_byte_arr, x  ; mode counter
    lda #kBadGhostMoveFrames
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    jmp FuncA_Actor_TickBadGhost_PickRandomGoalPos  ; preserves X
_ChangeMode:
    ;; At this point, the State2 timer is already zero.
    lda #eBadGhost::Disappearing
    sta Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    rts
.ENDPROC

;;; Performs per-frame updates for a mermaid ghost baddie actor that's in
;;; AttackShooting mode.
;;;   * When initializing this mode, set the State2 timer to zero.  The State3
;;;     counter is ignored.
;;;   * The State2 timer increments each frame until it it reaches
;;;     kBadGhostMermaidAttackFrames, at which point the mermaid ghost switches
;;;     to AttackMoving mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhostMermaid_AttackShooting
    jsr FuncA_Actor_FaceTowardsAvatar  ; preserves X
_ShootProjectile:
    ;; Shoot a fireball every 16 frames.
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    mod #16
    cmp #15
    bne @done
    ;; Position the point in fromt of the mermaid ghost's hands.
    lda #8  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    lda #4  ; param: offset
    jsr Func_MovePointUpByA  ; preserves X
    ;; Shoot a fireball towards the player avatar.
    stx T4  ; mermaid ghost actor index
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs @break  ; no room for any more projectiles
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    jsr Func_GetAngleFromPointToAvatar  ; preserves X and T4+, returns A
    sta T0  ; center angle
    ;; Randomize the fireball angle +/- 4 binary degrees.
    jsr Func_GetRandomByte  ; preserves T0+, returns A
    mod #8
    sub #4
    add T0  ; center angle
    jsr Func_InitActorProjFireball  ; preserves T3+
    jsr Func_PlaySfxShootFire  ; preserves T0+
    @break:
    ldx T4  ; mermaid ghost actor index
    @done:
_IncrementTimer:
    lda #kBadGhostMermaidAttackFrames  ; param: total attack frames
    .assert kBadGhostMermaidAttackFrames > 0, error
    bne FuncA_Actor_TickBadGhost_IncrementAttackTimer  ; unconditional
.ENDPROC

;;; Performs per-frame updates for an orc ghost baddie actor that's in
;;; AttackShooting mode.
;;;   * When initializing this mode, set the State2 timer to zero.  The State3
;;;     counter is ignored.
;;;   * The State2 timer increments each frame until it it reaches
;;;     kBadGhostOrcAttackFrames, at which point the orc ghost switches to
;;;     Disappearing mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhostOrc_AttackShooting
_ShootProjectiles:
    ;; If the timer is still at zero, fire a ring of projectiles.
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    bne @done
    ;; Choose a random angle delta of -1 or 1.
    jsr Func_GetRandomByte  ; preserves X, returns A
    mod #2  ; now A is 0 or 1
    mul #2  ; now A is 0 or 2
    tay     ; now Y is 0 or 2
    dey     ; now Y is -1 or 1
    sty T5  ; angle delta
    ;; Fire a ring of projectiles.
    jsr Func_SetPointToActorCenter  ; preserves X
    stx T4  ; orc ghost actor index
    lda #10  ; starting angle
    @loop:
    sta T3  ; current angle
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs @break  ; no room for any more projectiles
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    lda T3  ; param: angle
    jsr Func_InitActorProjFireball  ; preserves X and T3+
    lda T5  ; angle delta
    sta Ram_ActorState4_byte_arr, x  ; angle delta
    lda T3  ; param: angle
    add #43  ; tau/6 (approximately)
    bcc @loop
    @break:
    ldx T4  ; orc ghost actor index
    jsr Func_PlaySfxShootFire  ; preserves X
    @done:
_IncrementTimer:
    lda #kBadGhostOrcAttackFrames  ; param: total attack frames
    fall FuncA_Actor_TickBadGhost_IncrementAttackTimer  ; preserves X
.ENDPROC

;;; Helper function for the FuncA_Actor_TickBadGhost*_AttackShooting functions
;;; above.  Increments the State2 timer, and when the timer reaches the
;;; specified value, switches to AttackMoving mode.
;;; @param A The total attack duration, in frames.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_IncrementAttackTimer
    ;; Increment timer until it reaches its end value.
    inc Ram_ActorState2_byte_arr, x  ; mode timer
    cmp Ram_ActorState2_byte_arr, x  ; mode timer
    bne @done
    ;; When the timer finishes, make the ghost start moving around.
    lda #eBadGhost::AttackMoving
    sta Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    lda #0
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    ;; Dodge 0-2 times before disappearing.
    jsr Func_GetRandomByte  ; preserves X, returns A
    mod #4
    tay
    lda _Times_u8_arr4, y
    sta Ram_ActorState3_byte_arr, x  ; mode counter
    @done:
    rts
_Times_u8_arr4:
    .byte 0, 1, 1, 2
.ENDPROC

;;; Performs per-frame updates for a mermaid ghost baddie actor that's in
;;; SpecialMoving mode.
;;;   * When initializing this mode, the State2 timer and State3 counter are
;;;     ignored.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhostMermaid_SpecialMoving
    ;; Accelerate upwards.
    lda Ram_ActorVelY_i16_0_arr, x
    sub #kBadGhostSpecialMovingAccel
    sta Ram_ActorVelY_i16_0_arr, x
    lda Ram_ActorVelY_i16_1_arr, x
    sbc #0
    sta Ram_ActorVelY_i16_1_arr, x
    ;; Once the mermaid ghost is off the top of the screen, switch to Absent
    ;; mode and zero its velocity.
    lda Ram_ActorPosY_i16_1_arr, x
    bpl @done  ; ghost is on-screen or below the bottom of the screen
    lda #eBadGhost::Absent
    sta Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    jmp FuncA_Actor_ZeroVelY  ; preserves X
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for an orc ghost baddie actor that's in
;;; SpecialMoving mode.
;;;   * When initializing this mode, the State2 timer and State3 counter are
;;;     ignored.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhostOrc_SpecialMoving
    ;; Accelerate downwards.
    lda Ram_ActorVelY_i16_0_arr, x
    add #kBadGhostSpecialMovingAccel
    sta Ram_ActorVelY_i16_0_arr, x
    lda Ram_ActorVelY_i16_1_arr, x
    adc #0
    sta Ram_ActorVelY_i16_1_arr, x
    ;; Once the orc ghost is off the bottom of the screen, switch to Absent
    ;; mode and zero its velocity.
    lda Ram_ActorPosY_i16_1_arr, x
    bmi @done  ; ghost is above the top of the screen
    beq @done  ; ghost is on-screen
    lda #eBadGhost::Absent
    sta Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    jmp FuncA_Actor_ZeroVelY  ; preserves X
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for a mermaid/orc ghost baddie actor that's in
;;; SpecialWaiting or InjuredSpecWait mode.
;;;   * When initializing this mode, set the State2 timer to zero.  The State3
;;;     counter is ignored.
;;;   * The State2 timer increments each frame from zero to
;;;     kBadGhostSpecialWaitingFrames, at which point the ghost switches to
;;;     SpecialMoving or InjuredSpecMove mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_SpecialWaiting
    ;; Increment timer until it reaches its end value.
    inc Ram_ActorState2_byte_arr, x  ; mode timer
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    cmp #kBadGhostSpecialWaitingFrames
    blt @done
    ;; When the timer finishes, switch to SpecialMoving (from SpecialWaiting)
    ;; or InjuredSpecMove (from InjuredSpecWait) mode.
    .assert eBadGhost::SpecialWaiting - 1 = eBadGhost::SpecialMoving, error
    .assert eBadGhost::InjuredSpecWait - 1 = eBadGhost::InjuredSpecMove, error
    dec Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a mermaid ghost baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadGhostMermaid
.PROC FuncA_Objects_DrawActorBadGhostMermaid
    jsr FuncA_Objects_SetShapePosToBadGhostCenter  ; preserves X; returns Y, Z
    beq FuncA_Objects_DrawActorBadGhostAbsent  ; preserves X
    lda _FirstTileId_u8_arr, y  ; param: first tile ID
    jsr FuncA_Objects_GetBadGhostObjectFlags  ; preserves A and X, returns Y
    jmp FuncA_Objects_Draw2x3TownsfolkShape  ; preserves X
_FirstTileId_u8_arr:
    D_ARRAY .enum, eBadGhost
    d_byte Absent,           kTileIdObjMermaidGhostFirst + 0
    d_byte AppearForAttack,  kTileIdObjMermaidGhostFirst + 0
    d_byte AppearForMerge,   kTileIdObjMermaidGhostFirst + 0
    d_byte AppearForSpecial, kTileIdObjMermaidGhostFirst + 0
    d_byte Disappearing,     kTileIdObjMermaidGhostFirst + 0
    d_byte InjuredAttacking, kTileIdObjMermaidGhostFirst + 6
    d_byte InjuredSpecMove,  kTileIdObjMermaidGhostFirst + 6
    d_byte InjuredSpecWait,  kTileIdObjMermaidGhostFirst + 0
    d_byte AttackMoving,     kTileIdObjMermaidGhostFirst + 0
    d_byte AttackShooting,   kTileIdObjMermaidGhostFirst + 6
    d_byte SpecialMoving,    kTileIdObjMermaidGhostFirst + 6
    d_byte SpecialWaiting,   kTileIdObjMermaidGhostFirst + 0
    D_END
.ENDPROC

;;; Draws a ghost baddie actor that's absent (invisible).  In other words, this
;;; is a no-op.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_DrawActorBadGhostAbsent
    rts
.ENDPROC

;;; Draws an orc ghost baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadGhostOrc
.PROC FuncA_Objects_DrawActorBadGhostOrc
    jsr FuncA_Objects_SetShapePosToBadGhostCenter  ; preserves X; returns Y, Z
    beq FuncA_Objects_DrawActorBadGhostAbsent  ; preserves X
    ;; Draw feet:
    lda _FirstTileId_u8_arr, y  ; param: first tile ID
    jsr _DrawPart  ; preserves X
    ;; Draw head:
    lda #kBlockHeightPx
    jsr FuncA_Objects_MoveShapeUpByA  ; preserves X and T0+
    lda #kTileIdObjOrcGhostFirst + 0  ; param: first tile ID
_DrawPart:
    jsr FuncA_Objects_GetBadGhostObjectFlags  ; preserves A and X, returns Y
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X
_FirstTileId_u8_arr:
    D_ARRAY .enum, eBadGhost
    d_byte Absent,           kTileIdObjOrcGhostFirst + 4
    d_byte AppearForAttack,  kTileIdObjOrcGhostFirst + 4
    d_byte AppearForMerge,   kTileIdObjOrcGhostFirst + 4
    d_byte AppearForSpecial, kTileIdObjOrcGhostFirst + 4
    d_byte Disappearing,     kTileIdObjOrcGhostFirst + 4
    d_byte InjuredAttacking, kTileIdObjOrcGhostFirst + 8
    d_byte InjuredSpecMove,  kTileIdObjOrcGhostFirst + 8
    d_byte InjuredSpecWait,  kTileIdObjOrcGhostFirst + 4
    d_byte AttackMoving,     kTileIdObjOrcGhostFirst + 4
    d_byte AttackShooting,   kTileIdObjOrcGhostFirst + 8
    d_byte SpecialMoving,    kTileIdObjOrcGhostFirst + 8
    d_byte SpecialWaiting,   kTileIdObjOrcGhostFirst + 4
    D_END
.ENDPROC

;;; Sets the shape position for a ghost baddie actor, taking its current mode
;;; into account (and also returning that mode, for convenience).
;;; @param X The actor index.
;;; @return Y The actor's current eBadGhost mode.
;;; @return Z Set if the ghost is in Absent mode, and thus should not be drawn.
;;; @preserve X
.PROC FuncA_Objects_SetShapePosToBadGhostCenter
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    jsr FuncA_Objects_BobActorShapePosUpAndDown  ; preserves X
    ldy Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    .assert eBadGhost::Absent = 0, error
    beq @done  ; Z is set: ghost is absent
    cpy #kBadGhostFirstSolid
    blt @displace
    tya  ; clears Z: ghost is not absent
    rts
    @displace:
    ;; Horizontal displacement:
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    mul #2
    sta T2  ; displacement radius
    mul #8
    bit Data_PowersOfTwo_u8_arr8 + 4
    beq @setAngle
    eor #$80
    @setAngle:
    pha  ; param: displacement angle
    jsr Func_Cosine  ; preserves X, T0+; returns A (param: signed multiplicand)
    ldy T2  ; displacement radius (param: unsigned multiplier)
    jsr Func_SignedMult  ; preserves X and T2+; returns YA
    tya  ; param: signed offset
    jsr FuncA_Objects_MoveShapeHorz  ; preserves X and T0+
    ;; Vertical displacement:
    pla  ; angle
    jsr Func_Sine  ; preserves X, T0+; returns A (param: signed multiplicand)
    ldy T2  ; displacement radius (param: unsigned multiplier)
    jsr Func_SignedMult  ; preserves X, returns YA
    tya  ; param: signed offset
    jsr FuncA_Objects_MoveShapeVert  ; preserves X
    ;; Set up Y and Z return values again:
    ldy Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    @done:
    rts
.ENDPROC

;;; Returns the object flags to use when drawing the ghost baddie actor.
;;; @param X The actor index.
;;; @return Y The object flags to use.
;;; @preserve A, X
.PROC FuncA_Objects_GetBadGhostObjectFlags
    pha  ; old A value
    lda #kPaletteObjBadGhostNormal
    ldy Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    cpy #kBadGhostFirstSolid
    blt @finish  ; ghost is appearing/disappearing/absent
    cpy #kBadGhostFirstVulnerable
    bge @finish  ; ghost is not injured
    lda Zp_FrameCounter_u8
    and #$02
    .assert kPaletteObjBadGhostNormal = 0, error
    beq @finish
    lda #kPaletteObjBadGhostHurt
    @finish:
    ora Ram_ActorFlags_bObj_arr, x
    tay  ; object flags
    pla  ; old A value
    rts
.ENDPROC

;;;=========================================================================;;;
