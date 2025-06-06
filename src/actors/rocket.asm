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
.INCLUDE "../machines/launcher.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../program.inc"
.INCLUDE "rocket.inc"

.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_InitActorDefault
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_PlaySfxExplodeBig
.IMPORT Func_RemoveActor
.IMPORT Func_ShakeRoom
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_1_arr

;;;=========================================================================;;;

;;; The speed of a rocket projectile, in pixels per frame:
kRocketSpeed = 7

;;; OBJ tile IDs for rocket projectile actors.
kTileIdObjRocketHorz = kTileIdObjLauncherHorzFirst + 3
kTileIdObjRocketVert = kTileIdObjLauncherVertFirst + 3

;;; The OBJ palette number used for rocket projectile actors:
kPaletteObjRocket = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Initializes the specified actor as a rocket projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The eDir value for the rocket direction.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Machine_InitActorProjRocket
.PROC FuncA_Machine_InitActorProjRocket
    pha  ; eDir value
    ldy #eActor::ProjRocket  ; param: actor type
    jsr Func_InitActorDefault
    pla  ; eDir value
    tay  ; eDir value
_SetVelX:
    lda _VelX_i8_arr, y
    sta Ram_ActorVelX_i16_1_arr, x
    bpl @noFlip
    lda #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    @noFlip:
_SetVelY:
    lda _VelY_i8_arr, y
    sta Ram_ActorVelY_i16_1_arr, x
    bpl @noFlip
    lda Ram_ActorFlags_bObj_arr, x
    ora #bObj::FlipV
    sta Ram_ActorFlags_bObj_arr, x
    @noFlip:
    rts
_VelX_i8_arr:
    D_ARRAY .enum, eDir
    d_byte Up,   0
    d_byte Right, kRocketSpeed
    d_byte Down, 0
    d_byte Left, <-kRocketSpeed
    D_END
_VelY_i8_arr:
    D_ARRAY .enum, eDir
    d_byte Up, <-kRocketSpeed
    d_byte Right, 0
    d_byte Down, kRocketSpeed
    d_byte Left,  0
    D_END
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a rocket projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjRocket
.PROC FuncA_Actor_TickProjRocket
    inc Ram_ActorState1_byte_arr, x
    beq _Expire
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X, returns C
    bcs _Explode
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcc _Done
_ShakeAndExplode:
    lda #kRocketShakeFrames  ; param: num frames
    jsr Func_ShakeRoom  ; preserves X
_Explode:
    jsr Func_PlaySfxExplodeBig  ; preserves X
    jmp Func_InitActorSmokeExplosion  ; preserves X
_Expire:
    jmp Func_RemoveActor  ; preserves X
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a rocket projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjRocket
.PROC FuncA_Objects_DrawActorProjRocket
    lda Ram_ActorVelY_i16_1_arr, x
    beq @horz
    @vert:
    lda #kTileIdObjRocketVert  ; param: tile ID
    .assert kTileIdObjRocketVert > 0, error
    bne @draw  ; unconditional
    @horz:
    lda #kTileIdObjRocketHorz  ; param: tile ID
    @draw:
    ldy #kPaletteObjRocket  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
