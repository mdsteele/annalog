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

.IMPORT FuncA_Actor_ApplyGravity
.IMPORT FuncA_Actor_ZeroVel
.IMPORT FuncA_Objects_DrawActorSmokeFragment
.IMPORT Func_InitActorWithState1
.IMPORT Func_RemoveActor
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr

;;;=========================================================================;;;

;;; If the food is at or below this room pixel Y-position, it's considered to
;;; be in the water.  This is hardcoded to the water line for the SewerPool
;;; room, since that is the only room that food actors are used in.
kWaterLine = $00b5

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

;;; Initializes the specified actor as a food projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The number of frames before the food should expire.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Cutscene_InitActorProjFood
.PROC FuncA_Cutscene_InitActorProjFood
    ldy #eActor::ProjFood  ; param: actor type
    jmp Func_InitActorWithState1  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a food projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjFood
.PROC FuncA_Actor_TickProjFood
    dec Ram_ActorState1_byte_arr, x  ; frames until expiration
    beq _Expire
    ;; If the food is above the water line, fall under gravity, otherwise bob
    ;; in the water.
    lda Ram_ActorPosY_i16_1_arr, x
    .assert >kWaterLine = 0, error
    bmi _Fall
    bne _BobInWater
    lda Ram_ActorPosY_i16_0_arr, x
    cmp #<kWaterLine
    blt _Fall
_BobInWater:
    lda #$ff
    sta Ram_ActorState2_byte_arr, x  ; is-in-water boolean
    jsr FuncA_Actor_ZeroVel  ; preserves X
    lda Ram_ActorState1_byte_arr, x  ; frames until expiration
    mod #$10
    bne @done
    lda Ram_ActorPosY_i16_0_arr, x
    cmp #<kWaterLine
    beq @down
    @up:
    dec Ram_ActorPosY_i16_0_arr, x
    rts
    @down:
    inc Ram_ActorPosY_i16_0_arr, x
    @done:
    rts
_Fall:
    jmp FuncA_Actor_ApplyGravity  ; preserves X
_Expire:
    jmp Func_RemoveActor  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a food projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjFood := FuncA_Objects_DrawActorSmokeFragment

;;;=========================================================================;;;
