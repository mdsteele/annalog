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
.INCLUDE "dirt.inc"

.IMPORT FuncA_Actor_ApplyGravity
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_InitActorDefault
.IMPORT Func_SetActorVelocityPolar
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr

;;;=========================================================================;;;

;;; The speed of a dirt smoke, in half-pixels per frame.
kDirtSpeed = 6

;;; How many frames a dirt smoke lasts before being removed.
kDirtMaxAge = 36

;;; The OBJ palette number used for dirt smoke actors.
kPaletteObjDirt = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes the specified actor as a dirt smoke.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The angle to move at, measured in increments of tau/256.
;;; @param X The actor index.
;;; @preserve X, T3+
.EXPORT FuncA_Room_InitActorSmokeDirt
.PROC FuncA_Room_InitActorSmokeDirt
    pha  ; angle
    ldy #eActor::SmokeDirt  ; param: actor type
    jsr Func_InitActorDefault  ; preserves X and T0+
    ldy #kDirtSpeed  ; param: speed
    pla  ; param: angle
    jmp Func_SetActorVelocityPolar  ; preserves X and T3+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a dirt smoke actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickSmokeDirt
.PROC FuncA_Actor_TickSmokeDirt
    inc Ram_ActorState1_byte_arr, x  ; expiration timer
    lda Ram_ActorState1_byte_arr, x  ; expiration timer
    cmp #kDirtMaxAge
    bge _Expire
    jmp FuncA_Actor_ApplyGravity  ; preserves X
_Expire:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a dirt smoke actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorSmokeDirt
.PROC FuncA_Objects_DrawActorSmokeDirt
    lda Ram_ActorState1_byte_arr, x  ; expiration timer
    pha  ; expiration timer
    and #$18
    .assert bObj::FlipV = $80, error
    .assert bObj::FlipH = $40, error
    mul #8
    ora #kPaletteObjDirt
    tay  ; param: object flags
    pla  ; expiration timer
    cmp #kDirtMaxAge * 2 / 3
    blt @big
    @small:
    lda #kTileIdObjDirtFirst + 1  ; param: tile ID
    bne @draw  ; unconditional
    @big:
    lda #kTileIdObjDirtFirst + 0  ; param: tile ID
    @draw:
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
