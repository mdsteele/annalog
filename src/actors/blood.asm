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
.INCLUDE "blood.inc"

.IMPORT FuncA_Actor_ApplyGravity
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_InitActorWithState1
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr

;;;=========================================================================;;;

;;; The room pixel Y-position at which blood smoke disappears.
kBloodFloorY = $d0

;;; The OBJ palette number used for blood smoke actors.
kPaletteObjBlood = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes the specified actor as a blood smoke.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The OBJ tile ID to use.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT FuncA_Room_InitActorSmokeBlood
.PROC FuncA_Room_InitActorSmokeBlood
    ldy #eActor::SmokeBlood  ; param: actor type
    jmp Func_InitActorWithState1  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a blood smoke actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickSmokeBlood
.PROC FuncA_Actor_TickSmokeBlood
    inc Ram_ActorState2_byte_arr, x  ; expiration timer
    beq _Expire
    lda Ram_ActorPosY_i16_0_arr, x
    cmp #kBloodFloorY
    bge _Expire
    jmp FuncA_Actor_ApplyGravity  ; preserves X
_Expire:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a blood smoke actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorSmokeBlood
.PROC FuncA_Objects_DrawActorSmokeBlood
    lda Ram_ActorState2_byte_arr, x  ; expiration timer
    and #$18
    .assert bObj::FlipV = $80, error
    .assert bObj::FlipH = $40, error
    mul #8
    ora #kPaletteObjBlood
    tay  ; param: object flags
    lda Ram_ActorState1_byte_arr, x  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
