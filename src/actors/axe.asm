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
.IMPORT Func_InitActorWithFlags
.IMPORT Func_SetActorVelocityPolar
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; The speed of an axe projectile, in half-pixels per frame.
kProjAxeSpeed = 6

;;; Once an axe projectile has flown away from Gronta for this many frames,
;;; stop it in place.
kAxeAwayFrames = 60

;;; Once an axe projectile has paused for this many frames, return to Gronta.
kAxePauseFrames = 30

;;; As an axe projectile spins, it spends (1 << kAxeAnimShift) frames in each
;;; spin position.
.DEFINE kAxeAnimShift 2

;;; The OBJ palette number used for axe projectile actors.
kPaletteObjAxe = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as an axe projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The angle to throw at, measured in increments of tau/256.
;;; @param X The actor index.
;;; @preserve X, T3+
.EXPORT Func_InitActorProjAxe
.PROC Func_InitActorProjAxe
    pha  ; angle
    add #$40
    and #$80
    .assert bObj::FlipH = $40, error
    div #2  ; param: flags
    ldy #eActor::ProjAxe  ; param: actor type
    jsr Func_InitActorWithFlags  ; preserves X and T0+
    pla  ; param: angle
    ldy #kProjAxeSpeed  ; param: speed
    jmp Func_SetActorVelocityPolar  ; preserves X and T3+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for an axe projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjAxe
.PROC FuncA_Actor_TickProjAxe
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
_FindGronta:
    ;; Find the actor index for Gronta, storing it in Y.  If for some reason
    ;; there's no Gronta actor in this room, then remove the axe actor.
    stx T0  ; axe actor index
    lda #eActor::BadGronta  ; param: actor type to find
    jsr Func_FindActorWithType  ; preserves T0+, returns C and X
    txa  ; Gronta actor index (if any)
    tay  ; Gronta actor index (if any)
    ldx T0  ; axe actor index
    bcs _RemoveAxe
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
    ;; TODO: Set velocity to move towards Gronta.
    ;; TODO: If near Gronta, catch axe.
_CatchAxe:
    lda #eBadGronta::ThrowCatch
    sta Ram_ActorState1_byte_arr, y  ; current Gronta mode
_RemoveAxe:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
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
