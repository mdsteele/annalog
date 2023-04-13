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

.INCLUDE "../cpu.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../terrain.inc"
.INCLUDE "firefly.inc"

.IMPORT FuncA_Actor_FaceTowardsAvatar
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarToLeftOrRight
.IMPORT FuncA_Actor_IsAvatarWithinVertDistances
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_Cosine
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjFireball
.IMPORT Func_MovePointLeftByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; How many frames a firefly baddie actor must wait between shots.
kFireflyCooldownFrames = 20

;;; How close, in pixels, the player avatar must be vertically to the firefly
;;; in order for the firefly to shoot.
kFireflyVertProximity = 15

;;; How many pixels in front of the firefly actor center to spawn a fireball.
kFireflyFireballHorzOffset = 8

;;; The OBJ palette number to use for drawing firefly baddie actors.
kPaletteObjFirefly = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a firefly baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadFirefly
.PROC FuncA_Actor_TickBadFirefly
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
_UpdateVelY:
    lda Ram_ActorState2_byte_arr, x  ; param: angle
    jsr Func_Cosine  ; preserves X, returns A
    ldy #0
    asl a
    sta Ram_ActorVelY_i16_0_arr, x
    bcc @nonneg
    dey  ; now Y is $ff
    @nonneg:
    tya
    sta Ram_ActorVelY_i16_1_arr, x
_UpdateAngleAndFace:
    inc Ram_ActorState2_byte_arr, x  ; angle
    lda Ram_ActorState2_byte_arr, x  ; angle
    and #$7f
    cmp #$40
    bne @done
    jsr FuncA_Actor_FaceTowardsAvatar  ; preserves X
    @done:
_ReturnIfStillCoolingDown:
    lda Ram_ActorState1_byte_arr, x  ; cooldown
    beq @readyToShoot
    dec Ram_ActorState1_byte_arr, x  ; cooldown
    rts
    @readyToShoot:
_ReturnIfAvatarNotVerticallyNearby:
    ldy #kFireflyVertProximity  ; param: distance below avatar
    tya  ; param: distance above avatar
    jsr FuncA_Actor_IsAvatarWithinVertDistances  ; preserves X, returns C
    bcc _Return
_ReturnIfAvatarNotInFront:
    lda Ram_ActorFlags_bObj_arr, x
    sta T0  ; firefly actor flags
    jsr FuncA_Actor_IsAvatarToLeftOrRight  ; preserves X and T0+, returns N
    bpl @avatarIsToTheRight
    @avatarIsToTheLeft:
    bit T0  ; firefly actor flags
    .assert bObj::FlipH = bProc::Overflow, error
    bvc _Return
    bvs @avatarIsInFront  ; unconditional
    @avatarIsToTheRight:
    bit T0  ; firefly actor flags
    .assert bObj::FlipH = bProc::Overflow, error
    bvs _Return
    @avatarIsInFront:
_ShootFireball:
    jsr Func_SetPointToActorCenter  ; preserves X and T0+
    stx T2  ; firefly actor index
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs @done
    ;; Set the fireball position just in front of the firefly actor.
    lda #kFireflyFireballHorzOffset  ; param: offset
    bit T0  ; firefly actor flags
    .assert bObj::FlipH = bProc::Overflow, error
    bvc @adjustRight
    @adjustLeft:
    jsr Func_MovePointLeftByA  ; preserves X and T0+
    jmp @doneAdjust
    @adjustRight:
    jsr Func_MovePointRightByA  ; preserves X and T0+
    @doneAdjust:
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    ;; Set the fireball aim angle depending on which way the firefly is facing.
    lda #$00  ; param: aim angle ($00 = to the right)
    bit T0  ; firefly actor flags
    .assert bObj::FlipH = bProc::Overflow, error
    bvc @setAngle
    lda #$80  ; param: aim angle ($80 = to the left)
    @setAngle:
    jsr Func_InitActorProjFireball  ; preserves T2+
    ;; Set the firefly cooldown angle and restore the X register.
    ldx T2  ; firefly actor index
    lda #kFireflyCooldownFrames
    sta Ram_ActorState1_byte_arr, x  ; cooldown
    @done:
    ldx T2  ; firefly actor index
_Return:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a firefly baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadFirefly
.PROC FuncA_Objects_DrawActorBadFirefly
    lda Zp_FrameCounter_u8
    and #$04
    .assert kTileIdObjFireflyFirst .mod $08 = 0, error
    ora #kTileIdObjFireflyFirst  ; param: first tile ID
    ldy #kPaletteObjFirefly  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
