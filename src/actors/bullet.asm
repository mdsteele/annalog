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
.INCLUDE "../program.inc"
.INCLUDE "bullet.inc"
.INCLUDE "particle.inc"

.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_InitActorDefault
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_ConsoleMachineIndex_u8

;;;=========================================================================;;;

;;; The speed of a bullet projectile, in pixels per frame:
kProjBulletSpeed = 6

;;; OBJ tile IDs for bullet projectile actors.
kTileIdObjBulletVert = kTileIdObjBulletFirst + 0
kTileIdObjBulletHorz = kTileIdObjBulletFirst + 1

;;; The OBJ palette number used for bullet projectile actors:
kPaletteObjBullet = 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as a bullet projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The eDir value for the bullet direction.
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitActorProjBullet
.PROC Func_InitActorProjBullet
    pha  ; eDir value
    ldy #eActor::ProjBullet  ; param: actor type
    jsr Func_InitActorDefault
    pla  ; eDir value
    tay  ; eDir value
    lda _VelX_i8_arr, y
    sta Ram_ActorVelX_i16_1_arr, x
    lda _VelY_i8_arr, y
    sta Ram_ActorVelY_i16_1_arr, x
    rts
_VelX_i8_arr:
    D_ARRAY .enum, eDir
    d_byte Up,   0
    d_byte Right, kProjBulletSpeed
    d_byte Down, 0
    d_byte Left, <-kProjBulletSpeed
    D_END
_VelY_i8_arr:
    D_ARRAY .enum, eDir
    d_byte Up, <-kProjBulletSpeed
    d_byte Right, 0
    d_byte Down, kProjBulletSpeed
    d_byte Left,  0
    D_END
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a bullet projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjBullet
.PROC FuncA_Actor_TickProjBullet
    inc Ram_ActorState1_byte_arr, x
    beq _Expire
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X, returns C
    bcs _Expire
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcc _Done
_Expire:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; If the console window is open, turns all bullet projectiles into smoke
;;; particles.  If the console window is closed, does nothing.  This should be
;;; called from room tick functions in rooms containing minigun machines.
.EXPORT FuncA_Room_RemoveAllBulletsIfConsoleOpen
.PROC FuncA_Room_RemoveAllBulletsIfConsoleOpen
    lda Zp_ConsoleMachineIndex_u8
    bmi @done
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::ProjBullet
    bne @continue
    lda #eActor::SmokeParticle
    sta Ram_ActorType_eActor_arr, x
    lda #kSmokeParticleNumFrames / 2
    sta Ram_ActorState1_byte_arr, x  ; particle age in frames
    @continue:
    dex
    bpl @loop
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a bullet projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjBullet
.PROC FuncA_Objects_DrawActorProjBullet
    lda Ram_ActorVelY_i16_1_arr, x
    beq @horz
    @vert:
    lda #kTileIdObjBulletVert  ; param: tile ID
    .assert kTileIdObjBulletVert > 0, error
    bne @draw  ; unconditional
    @horz:
    lda #kTileIdObjBulletHorz  ; param: tile ID
    @draw:
    ldy #kPaletteObjBullet  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
