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
.INCLUDE "grenade.inc"

.IMPORT FuncA_Actor_ApplyGravity
.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsInRoomBounds
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_FindActorWithType
.IMPORT Func_InitActorDefault
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_PlaySfxExplodeSmall
.IMPORT Func_RemoveActor
.IMPORT Func_ShakeRoom
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr

;;;=========================================================================;;;

;;; The OBJ palette number used for grenade projectile actors.
kPaletteObjProjGrenade = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Initializes the specified actor as a grenade projectile.  The grenade can
;;; be aimed in one of four initial angles:
;;;   * 0: Low angle, to the right.
;;;   * 1: High angle, to the right.
;;;   * 2: Low angle, to the left.
;;;   * 3: High angle, to the left.
;;; @prereq The actor's pixel position have already been initialized.
;;; @param A The aim angle (0-3).
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Machine_InitActorProjGrenade
.PROC FuncA_Machine_InitActorProjGrenade
    pha  ; aim angle index
    ldy #eActor::ProjGrenade  ; param: actor type
    jsr Func_InitActorDefault  ; preserves X
    pla  ; aim angle index
    tay  ; aim angle index
    ;; Initialize Y-velocity:
    lda _InitVelY_i16_0_arr, y
    sta Ram_ActorVelY_i16_0_arr, x
    lda _InitVelY_i16_1_arr, y
    sta Ram_ActorVelY_i16_1_arr, x
    ;; Adjust initial Y-position:
    mul #2
    add Ram_ActorPosY_i16_0_arr, x
    sta Ram_ActorPosY_i16_0_arr, x
    lda #$ff  ; initial Y-velocity is always negative
    adc Ram_ActorPosY_i16_1_arr, x
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Initialize X-velocity:
    lda #0
    sta T0
    lda _InitVelX_i16_1_arr, y
    sta Ram_ActorVelX_i16_1_arr, x
    bpl @nonnegative
    dec T0  ; now T0 is $ff
    @nonnegative:
    ;; Adjust X-position:
    mul #2
    add Ram_ActorPosX_i16_0_arr, x
    sta Ram_ActorPosX_i16_0_arr, x
    lda T0
    adc Ram_ActorPosX_i16_1_arr, x
    sta Ram_ActorPosX_i16_1_arr, x
    rts
_InitVelX_i16_1_arr:
    .byte 4, 3, ($ff & -4), ($ff & -3)
_InitVelY_i16_0_arr:
    .byte <($ffff & -480), <($ffff & -760)
    .byte <($ffff & -480), <($ffff & -760)
_InitVelY_i16_1_arr:
    .byte >($ffff & -480), >($ffff & -760)
    .byte >($ffff & -480), >($ffff & -760)
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Finds a grenade actor in the room (if any) and returns its index, or sets
;;; the C flag if there isn't any grenade actor right now.
;;; @return C Set if no grenade was found.
;;; @return X The index of the grenade actor (if any).
;;; @preserve Y, T0+
.EXPORT FuncA_Room_FindGrenadeActor
.PROC FuncA_Room_FindGrenadeActor
    lda #eActor::ProjGrenade  ; param: actor type to find
    jmp Func_FindActorWithType  ; preserves Y and T0+, returns C and X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a grenade projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjGrenade
.PROC FuncA_Actor_TickProjGrenade
    inc Ram_ActorState1_byte_arr, x
    beq _Explode
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X, returns C
    bcs _Explode
    jsr FuncA_Actor_IsInRoomBounds  ; preserves X, returns C
    bcc _Remove
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcs _ShakeAndExplode
    jmp FuncA_Actor_ApplyGravity  ; preserves X
_ShakeAndExplode:
    lda #kGrenadeShakeFrames  ; param: num frames
    jsr Func_ShakeRoom  ; preserves X
_Explode:
    jsr Func_PlaySfxExplodeSmall  ; preserves X
    jmp Func_InitActorSmokeExplosion  ; preserves X
_Remove:
    jmp Func_RemoveActor  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a grenade projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjGrenade
.PROC FuncA_Objects_DrawActorProjGrenade
    lda Ram_ActorState1_byte_arr, x
    div #4
    and #$03
    add #kTileIdObjProjGrenadeFirst
    ldy #kPaletteObjProjGrenade  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
