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

.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT FuncA_Objects_Draw2x3Actor
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorState_byte_arr
.IMPORTZP Zp_AvatarPosX_i16

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for an adult townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickAdult
.PROC FuncA_Actor_TickAdult
    .assert * = FuncA_Actor_TickChild, error, "fallthrough"
.ENDPROC

;;; Performs per-frame updates for a child townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickChild
.PROC FuncA_Actor_TickChild
    lda Ram_ActorPosX_i16_1_arr, x
    cmp Zp_AvatarPosX_i16 + 1
    blt @faceRight
    bne @faceLeft
    lda Ram_ActorPosX_i16_0_arr, x
    cmp Zp_AvatarPosX_i16 + 0
    blt @faceRight
    @faceLeft:
    lda #bObj::FlipH
    bne @setFlags  ; unconditional
    @faceRight:
    lda #0
    @setFlags:
    sta Ram_ActorFlags_bObj_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for an adult townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawAdultActor
.PROC FuncA_Objects_DrawAdultActor
    lda Ram_ActorState_byte_arr, x  ; param: first tile ID
    jmp FuncA_Objects_Draw2x3Actor  ; preserves X
.ENDPROC

;;; Allocates and populates OAM slots for a child townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawChildActor
.PROC FuncA_Objects_DrawChildActor
    lda Ram_ActorState_byte_arr, x  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
