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
.INCLUDE "orc.inc"

.IMPORT FuncA_Actor_FaceTowardsAvatar
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarWithinHorzDistance
.IMPORT FuncA_Actor_IsAvatarWithinVertDistances
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr

;;;=========================================================================;;;

;;; The horizontal acceleration applied to an orc baddie actor when it's
;;; chasing the player avatar, in subpixels per frame per frame.
kOrcChasingHorzAccel = 40

;;; How fast an orc baddie can run, in subpixels per frame.
kOrcMaxSpeedHorz = $0260

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

;;; Performs per-frame updates for an orc baddie actor that's in Standing mode.
;;; @param C Set if the orc just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Standing
    bcs @startChasing
    ldy #kTileHeightPx * 3  ; param: distance above actor
    lda #kTileHeightPx      ; param: distance below actor
    jsr FuncA_Actor_IsAvatarWithinVertDistances  ; preserves X, returns C
    bcc @done
    lda #kBlockWidthPx * 5  ; param: distance
    jsr FuncA_Actor_IsAvatarWithinHorzDistance  ; preserves X, returns C
    bcc @done
    @startChasing:
    lda #eBadOrc::Chasing
    sta Ram_ActorState1_byte_arr, x  ; current mode
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Standing mode.
;;; @param C Set if the orc just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Pausing
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    bne @done
    lda #eBadOrc::Chasing
    sta Ram_ActorState1_byte_arr, x  ; current mode
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Chasing mode.
;;; @param C Set if the orc just collided with the player avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Chasing
    ;; If the orc catches the player avatar, pause briefly.
    bcc @noCollide
    lda #0
    sta Ram_ActorVelX_i16_0_arr, x
    sta Ram_ActorVelX_i16_1_arr, x
    lda #eBadOrc::Pausing
    sta Ram_ActorState1_byte_arr, x  ; current mode
    lda #kOrcPauseFrames
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    rts
    @noCollide:
    ;; If the player avatar gets far away vertically, stop chasing.
    ldy #kTileHeightPx * 5  ; param: distance above actor
    lda #kTileHeightPx * 3  ; param: distance below actor
    jsr FuncA_Actor_IsAvatarWithinVertDistances  ; preserves X, returns C
    bcs _KeepChasing
_StopChasing:
    ;; TODO: Don't halt immediately; go into a Patrol mode for a few seconds.
    ;; TODO: When Patrol timer ends, decelerate into Standing mode.
    lda #0
    sta Ram_ActorVelX_i16_0_arr, x
    sta Ram_ActorVelX_i16_1_arr, x
    .assert eBadOrc::Standing = 0, error
    sta Ram_ActorState1_byte_arr, x  ; current mode
    rts
_KeepChasing:
    jsr FuncA_Actor_FaceTowardsAvatar  ; preserves X, returns A
    ldy #0
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
    cmp #<kOrcMaxSpeedHorz
    lda Ram_ActorVelX_i16_1_arr, x
    sbc #>kOrcMaxSpeedHorz
    blt @done
    lda #<kOrcMaxSpeedHorz
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>kOrcMaxSpeedHorz
    .assert >kOrcMaxSpeedHorz > 0, error
    bne @setHi  ; unconditional
    @negative:
    lda Ram_ActorVelX_i16_0_arr, x
    cmp #<-kOrcMaxSpeedHorz
    lda Ram_ActorVelX_i16_1_arr, x
    sbc #>-kOrcMaxSpeedHorz
    bge @done
    lda #<-kOrcMaxSpeedHorz
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>-kOrcMaxSpeedHorz
    @setHi:
    sta Ram_ActorVelX_i16_1_arr, x
    @done:
    ;; TODO: sometimes jump at player avatar
    rts
.ENDPROC

;;; Performs per-frame updates for an orc baddie actor that's in Jumping mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadOrc_Jumping
    ;; TODO: apply gravity
    ;; TODO: check for collision with floor; resume Chasing upon landing
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws an orc baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadOrc
.PROC FuncA_Objects_DrawActorBadOrc
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
_DeterminePose:
    lda Ram_ActorState1_byte_arr, x  ; current mode
    .assert eBadOrc::Standing = 0, error
    beq @standing
    cmp #eBadOrc::Chasing
    beq @chasing
    cmp #eBadOrc::Pausing
    beq @pausing
    @jumping:
    ldy #2
    bpl @setPose  ; unconditional
    @pausing:
    ldy #0
    bpl @setPose  ; unconditional
    @standing:
    ldy #4
    bpl @setPose  ; unconditional
    @chasing:
    lda Ram_ActorState3_byte_arr, x  ; animation counter
    div #8
    and #$03
    tay
    @setPose:
_Draw:
    sty T2  ; pose index
    ;; Draw feet:
    lda _TileIdFeetRunning_u8_arr, y  ; param: first tile ID
    ldy Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jsr FuncA_Objects_Draw2x2Shape  ; preserves X and T2+
    ;; Draw head:
    lda #kBlockHeightPx
    jsr FuncA_Objects_MoveShapeUpByA  ; preserves X and T0+
    ldy T2  ; pose index
    lda _TileIdHeadRunning_u8_arr, y  ; param: first tile ID
    ldy Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X
_TileIdHeadRunning_u8_arr:
    .byte kTileIdObjOrcHeadLow
    .byte kTileIdObjOrcHeadHigh
    .byte kTileIdObjOrcHeadLow
    .byte kTileIdObjOrcHeadHigh
    .byte kTileIdObjOrcHeadHigh
_TileIdFeetRunning_u8_arr:
    .byte kTileIdObjOrcFeetRunning1
    .byte kTileIdObjOrcFeetRunning2
    .byte kTileIdObjOrcFeetRunning3
    .byte kTileIdObjOrcFeetRunning2
    .byte kTileIdObjOrcFeetStanding
.ENDPROC

;;;=========================================================================;;;
