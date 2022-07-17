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
.INCLUDE "grenade.inc"

.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_InitSmokeActor
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState_byte_arr
.IMPORT Ram_ActorSubX_u8_arr
.IMPORT Ram_ActorSubY_u8_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as a grenade.  The grenade can be aimed in
;;; one of four initial angles:
;;;   * 0: Low angle, to the right.
;;;   * 1: High angle, to the right.
;;;   * 2: Low angle, to the left.
;;;   * 3: High angle, to the left.
;;; @prereq The actor's pixel position have already been initialized.
;;; @param A The aim angle (0-3).
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitGrenadeActor
.PROC Func_InitGrenadeActor
    tay  ; aim angle index
    ;; Initialize state:
    lda #eActor::Grenade
    sta Ram_ActorType_eActor_arr, x
    lda #0
    sta Ram_ActorSubX_u8_arr, x
    sta Ram_ActorSubY_u8_arr, x
    sta Ram_ActorState_byte_arr, x
    sta Ram_ActorFlags_bObj_arr, x
    ;; Initialize X-velocity:
    sta Ram_ActorVelX_i16_0_arr, x
    sta Zp_Tmp1_byte
    lda _InitVelX_i16_1_arr, y
    sta Ram_ActorVelX_i16_1_arr, x
    bpl @nonnegative
    dec Zp_Tmp1_byte  ; now Zp_Tmp1_byte is $ff
    @nonnegative:
    ;; Adjust X-position:
    mul #2
    add Ram_ActorPosX_i16_0_arr, x
    sta Ram_ActorPosX_i16_0_arr, x
    lda Zp_Tmp1_byte
    adc Ram_ActorPosX_i16_1_arr, x
    sta Ram_ActorPosX_i16_1_arr, x
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
    rts
_InitVelX_i16_1_arr:
    .byte 4, 3, ($ff & -4), ($ff & -3)
_InitVelY_i16_0_arr:
    .byte <($ffff & -520), <($ffff & -760)
    .byte <($ffff & -520), <($ffff & -760)
_InitVelY_i16_1_arr:
    .byte >($ffff & -520), >($ffff & -760)
    .byte >($ffff & -520), >($ffff & -760)
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a grenade actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickGrenade
.PROC FuncA_Actor_TickGrenade
    inc Ram_ActorState_byte_arr, x
    beq _Explode
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X, returns C
    bcs _Explode
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcs _Explode
_ApplyGravity:
    lda #kAvatarGravity
    add Ram_ActorVelY_i16_0_arr, x
    sta Ram_ActorVelY_i16_0_arr, x
    lda #0
    adc Ram_ActorVelY_i16_1_arr, x
    sta Ram_ActorVelY_i16_1_arr, x
    rts
_Explode:
    ;; TODO: play a sound
    jmp Func_InitSmokeActor  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a grenade actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawGrenadeActor
.PROC FuncA_Objects_DrawGrenadeActor
    lda Ram_ActorState_byte_arr, x
    div #4
    and #$03
    add #kGrenadeFirstTileId
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
