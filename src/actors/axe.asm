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
.INCLUDE "../actors/orc.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "axe.inc"

.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_ZeroVel
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_FindActorWithType
.IMPORT Func_GetAngleFromPointToActor
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_InitActorWithFlags
.IMPORT Func_IsActorWithinDistanceOfPoint
.IMPORT Func_PlaySfxExplodeFracture
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetActorVelocityPolar
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_ShakeRoom
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState4_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; The speed of an axe projectile, in half-pixels per frame.
kProjAxeSpeed = 7

;;; Once an axe projectile has flown away from Gronta for this many frames,
;;; stop it in place.
kAxeAwayFrames = 50

;;; Once an axe projectile has paused for this many frames, return to Gronta.
kAxePauseFrames = 20

;;; How close an axe projectile must be to Gronta for her to catch in, in
;;; pixels.
kAxeCatchDistance = 8

;;; As an axe projectile spins, it spends (1 << kAxeAnimShift) frames in each
;;; spin position.
.DEFINE kAxeAnimShift 2

;;; The OBJ palette number used for axe projectile actors.
kPaletteObjAxe = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Initializes the specified actor as an axe projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The angle to throw at, measured in increments of tau/256.
;;; @param X The actor index.
;;; @param Y The actor type to set (ProjAxeBoomer or ProjAxeSmash).
;;; @preserve X, T3+
.EXPORT FuncA_Actor_InitActorProjAxe
.PROC FuncA_Actor_InitActorProjAxe
    pha  ; angle
    add #$40
    and #$80
    .assert bObj::FlipH = $40, error
    div #2  ; param: flags
    jsr Func_InitActorWithFlags  ; preserves X and T0+
    pla  ; param: angle
    ldy #kProjAxeSpeed  ; param: speed
    jmp Func_SetActorVelocityPolar  ; preserves X and T3+
.ENDPROC

;;; Performs per-frame updates for a boomerang axe projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjAxeBoomer
.PROC FuncA_Actor_TickProjAxeBoomer
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
_FindGronta:
    ;; Find the Gronta actor, and set the point to Gronta's position.  If for
    ;; some reason there's no Gronta actor in this room, then remove the axe
    ;; actor.
    stx T0  ; axe actor index
    lda #eActor::BadGronta  ; param: actor type to find
    jsr Func_FindActorWithType  ; preserves T0+, returns C and X
    bcc @foundGronta
    ldx T0  ; axe actor index
    bcs _RemoveAxe  ; unconditional
    @foundGronta:
    jsr Func_SetPointToActorCenter  ; preserves X and T0+
    stx T4  ; Gronta actor index
    ldx T0  ; axe actor index
_TickTimer:
    ;; Increment the axe's timer, then take action based on its new value.
    inc Ram_ActorState1_byte_arr, x  ; axe age in frames
    beq _CatchAxe
    lda Ram_ActorState1_byte_arr, x  ; axe age in frames
    cmp #kAxeAwayFrames + kAxePauseFrames
    bge _MoveTowardsGronta
    cmp #kAxeAwayFrames
    blt _Done
_PauseAxe:
    jmp FuncA_Actor_ZeroVel
_MoveTowardsGronta:
    ;; Set velocity to move towards Gronta.
    jsr Func_GetAngleFromPointToActor  ; preserves X and T4+, returns A
    eor #$80  ; param: angle
    ldy #kProjAxeSpeed  ; param: speed
    jsr Func_SetActorVelocityPolar  ; preserves X and T3+
    ;; If the axe is near Gronta, have her catch it.
    lda #kAxeCatchDistance  ; param: distance
    jsr Func_IsActorWithinDistanceOfPoint  ; preserves X and T1+, returns C
    bcc _Done
_CatchAxe:
    ldy T4  ; Gronta actor index
    lda #eBadGronta::ThrowCatch
    sta Ram_ActorState1_byte_arr, y  ; current Gronta mode
_RemoveAxe:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
_Done:
    rts
.ENDPROC

;;; Performs per-frame updates for a machine-smashing axe projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjAxeSmash
.PROC FuncA_Actor_TickProjAxeSmash
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    ;; Set velocity to move towards the goal platform.
    ldy Ram_ActorState2_byte_arr, x  ; param: goal platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X
    jsr Func_GetAngleFromPointToActor  ; preserves X, returns A
    eor #$80  ; param: angle
    ldy #kProjAxeSpeed  ; param: speed
    jsr Func_SetActorVelocityPolar  ; preserves X
    ;; Check if the axe has hit the platform.
    lda #8  ; param: distance
    jsr Func_IsActorWithinDistanceOfPoint  ; preserves X, returns C
    bcc _Done  ; no collision
    ;; The axe has hit the platform, so turn the axe into smoke.
    jsr Func_SetActorCenterToPoint  ; preserves X
    jsr Func_PlaySfxExplodeFracture  ; preserves X
    jsr Func_InitActorSmokeExplosion  ; preserves X
    lda #30  ; param: num frames
    jsr Func_ShakeRoom  ; preserves X
_MakeGrontaIdle:
    ;; Find Gronta, and put her into Idle mode.
    stx T0  ; axe actor index
    lda #eActor::BadGronta  ; param: actor type to find
    jsr Func_FindActorWithType  ; preserves T0+, returns C and X
    bcs @doneGronta  ; Gronta not found
    lda #eBadGronta::Idle
    sta Ram_ActorState1_byte_arr, x  ; current eBadGronta mode
    .assert eBadGronta::Idle = 0, error
    sta Ram_ActorState4_byte_arr, x  ; invincibility frames
    @doneGronta:
    ldx T0  ; axe actor index
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws an axe projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjAxe
.PROC FuncA_Objects_DrawActorProjAxe
    ;; Determine Flip* flags for the axe objects, storing them in Y.
    ldy #kPaletteObjAxe  ; param: object flags
    lda Zp_FrameCounter_u8
    and #$02 << kAxeAnimShift
    beq @noFlip
    ldy #kPaletteObjAxe | bObj::FlipHV  ; param: object flags
    @noFlip:
    ;; Draw the axe.
    lda #kTileIdObjProjAxeFirst  ; param: first tile ID
    jsr FuncA_Objects_Draw2x2Actor  ; preserves X, returns C and Y
    bcs @done
    ;; Move two of the four objects off-screen, so that only one diagonal or
    ;; the other is visible (and so that the axe has only one object per row).
    lda Zp_FrameCounter_u8
    div #1 << kAxeAnimShift
    lsr a  ; move bit 0 into C
    lda #$ff  ; an off-screen Y-position
    bcs @one
    @zero:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
    rts
    @one:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::YPos_u8, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
