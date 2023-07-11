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
.INCLUDE "../cpu.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../terrain.inc"
.INCLUDE "firefly.inc"

.IMPORT FuncA_Actor_FaceTowardsAvatar
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarWithinVertDistances
.IMPORT FuncA_Actor_IsFacingAvatar
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_Cosine
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjFireball
.IMPORT Func_InitActorWithFlags
.IMPORT Func_SetActorCenterToPoint
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

.SEGMENT "PRGA_Room"

;;; Initializes a firefly baddie actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The bBadFirefly param.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorBadFirefly
.PROC FuncA_Room_InitActorBadFirefly
    pha  ; bBadFirefly param
    and #bBadFirefly::FlipH
    beq @noFlip
    lda #bObj::FlipH
    @noFlip:
    ldy #eActor::BadFirefly
    jsr Func_InitActorWithFlags  ; preserves X
    pla  ; bBadFirefly param
    and #bBadFirefly::ThetaMask
    sta Ram_ActorState2_byte_arr, x  ; angle
    rts
.ENDPROC

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
    jsr FuncA_Actor_IsFacingAvatar  ; preserves X, returns C
    bcc _Return
_ShootFireball:
    lda #kFireflyFireballHorzOffset  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X and T0+
    ;; Set the fireball aim angle depending on which way the firefly is facing.
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    .assert bObj::FlipH = $40, error
    asl a
    sta T0  ; aim angle ($00 for right, or $80 for left)
    ;; Allocate the fireball.
    stx T2  ; firefly actor index
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs @done
    ;; Set the fireball position just in front of the firefly actor.
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    lda T0  ; param: aim angle ($00 for right, or $80 for left)
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
