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
.INCLUDE "../oam.inc"
.INCLUDE "spine.inc"

.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_Cosine
.IMPORT Func_InitActorWithState1
.IMPORT Func_SignedMult
.IMPORT Func_Sine
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr

;;;=========================================================================;;;

;;; The speed of a spine, in half-pixels per frame.
kSpineSpeed = 7

;;; The OBJ palette number used for spine actors.
kPaletteObjSpine = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes the specified actor as a spine projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The angle to fire at, measured in increments of tau/256.
;;; @param X The actor index.
;;; @preserve X, T2+
.EXPORT FuncA_Room_InitActorProjSpine
.PROC FuncA_Room_InitActorProjSpine
    ldy #eActor::ProjSpine  ; param: actor type
    jsr Func_InitActorWithState1  ; preserves X and T0+
_InitFlags:
    lda Ram_ActorState1_byte_arr, x  ; spine angle
    add #$08
    asl a
    rol a
    rol a
    and #$03
    tay
    lda _Flags_bObj_arr4, y
    sta Ram_ActorFlags_bObj_arr, x
_InitVelX:
    lda Ram_ActorState1_byte_arr, x  ; spine angle
    jsr Func_Cosine  ; preserves X and T0+, returns A
    ldy #kSpineSpeed  ; param: multiplier
    jsr Func_SignedMult  ; preserves X and T2+, returns YA
    sta Ram_ActorVelX_i16_0_arr, x
    tya
    sta Ram_ActorVelX_i16_1_arr, x
_InitVelY:
    lda Ram_ActorState1_byte_arr, x  ; spine angle
    jsr Func_Sine  ; preserves X and T0+, returns A
    ldy #kSpineSpeed  ; param: multiplier
    jsr Func_SignedMult  ; preserves X and T2+, returns YA
    sta Ram_ActorVelY_i16_0_arr, x
    tya
    sta Ram_ActorVelY_i16_1_arr, x
    rts
_Flags_bObj_arr4:
    .byte 0, bObj::FlipH, bObj::FlipHV, bObj::FlipV
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a spine projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjSpine
.PROC FuncA_Actor_TickProjSpine
    inc Ram_ActorState2_byte_arr, x  ; projectile age in frames
    beq _Expire
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X, returns C
    bcs _Expire
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcc _Return
_Expire:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
_Return:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a spine projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjSpine
.PROC FuncA_Objects_DrawActorProjSpine
    lda Ram_ActorState1_byte_arr, x  ; spine angle
    add #$08
    div #$10
    and #$07
    tay
    lda _TileId_u8_arr8, y  ; param: tile ID
    ldy #kPaletteObjSpine  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
_TileId_u8_arr8:
    .byte kTileIdObjProjSpineFirst + 2
    .byte kTileIdObjProjSpineFirst + 2
    .byte kTileIdObjProjSpineFirst + 2
    .byte kTileIdObjProjSpineFirst + 1
    .byte kTileIdObjProjSpineFirst + 0
    .byte kTileIdObjProjSpineFirst + 1
    .byte kTileIdObjProjSpineFirst + 2
    .byte kTileIdObjProjSpineFirst + 2
.ENDPROC

;;;=========================================================================;;;
