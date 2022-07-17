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

.IMPORT FuncA_Objects_Draw1x2Actor
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorState_byte_arr

;;;=========================================================================;;;

;;; The first tile ID for toddler actors.
kToddlerFirstTileId = $80

;;; How fast a toddler walks, in pixels per frame.
kToddlerSpeed = 1
;;; How long a toddler walks before turning around, in frames.
kToddlerTime = 100

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a toddler townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickToddler
.PROC FuncA_Actor_TickToddler
    dec Ram_ActorState_byte_arr, x
    bne @move
    @turnAround:
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    lda #kToddlerTime
    sta Ram_ActorState_byte_arr, x
    @move:
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne @moveLeft
    @moveRight:
    lda Ram_ActorPosX_i16_0_arr, x
    add #kToddlerSpeed
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_ActorPosX_i16_1_arr, x
    adc #0
    sta Ram_ActorPosX_i16_1_arr, x
    rts
    @moveLeft:
    lda Ram_ActorPosX_i16_0_arr, x
    sub #kToddlerSpeed
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_ActorPosX_i16_1_arr, x
    sbc #0
    sta Ram_ActorPosX_i16_1_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a toddler townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawToddlerActor
.PROC FuncA_Objects_DrawToddlerActor
    lda Ram_ActorState_byte_arr, x
    and #$08
    beq @draw
    lda #$02
    @draw:
    ;; Assert that we can use ORA instead of ADD.
    .assert kToddlerFirstTileId & $02 = 0, error
    ora #kToddlerFirstTileId
    jmp FuncA_Objects_Draw1x2Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
