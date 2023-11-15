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
.INCLUDE "smoke.inc"

.IMPORT FuncA_Actor_ApplyGravity
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_InitActorWithState1
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr

;;;=========================================================================;;;

;;; The OBJ tile ID for smoke fragment actors.
kTileIdObjFragment = kTileIdObjSmokeFirst + 5

;;; The OBJ palette number used for smoke fragment actors.
kPaletteObjFragment = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as a smoke fragment.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The number of frames before the fragment should expire.
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitActorSmokeFragment
.PROC Func_InitActorSmokeFragment
    ldy #eActor::SmokeFragment  ; param: actor type
    jmp Func_InitActorWithState1  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a smoke fragment actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickSmokeFragment
.PROC FuncA_Actor_TickSmokeFragment
    dec Ram_ActorState1_byte_arr, x  ; frames until expiration
    beq _Expire
    jmp FuncA_Actor_ApplyGravity  ; preserves X
_Expire:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a smoke fragment actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorSmokeFragment
.PROC FuncA_Objects_DrawActorSmokeFragment
    lda #kTileIdObjFragment  ; param: tile ID
    ldy #kPaletteObjFragment  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
