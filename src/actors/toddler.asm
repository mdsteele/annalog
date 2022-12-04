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
.INCLUDE "../cpu.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "toddler.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_InitActorWithState1
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_Oam_sObj_arr64

;;;=========================================================================;;;

;;; How fast a toddler walks, in pixels per frame.
kToddlerSpeed = 1
;;; How long a toddler walks before turning around, in frames.
kToddlerTime = 64

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes a toddler NPC actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The bNpcToddler param.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorNpcToddler
.PROC FuncA_Room_InitActorNpcToddler
    pha  ; bNpcToddler bits
    and #bNpcToddler::DistMask  ; param: state byte
    ldy #eActor::NpcToddler  ; param: actor type
    jsr Func_InitActorWithState1  ; preserves X
    pla  ; bNpcToddler bits
    .assert bNpcToddler::Pri = bProc::Negative, error
    bpl @done
    lda #bObj::Pri
    sta Ram_ActorFlags_bObj_arr, x
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a toddler NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickNpcToddler
.PROC FuncA_Actor_TickNpcToddler
    dec Ram_ActorState1_byte_arr, x
    bne @move
    @turnAround:
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    lda #kToddlerTime
    sta Ram_ActorState1_byte_arr, x
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

;;; Draws a toddler NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcToddler
.PROC FuncA_Objects_DrawActorNpcToddler
    lda Ram_ActorState1_byte_arr, x
    and #$08
    beq @draw
    lda #$02
    @draw:
    ;; Assert that we can use ORA instead of ADD.
    .assert kTileIdObjToddlerFirst & $02 = 0, error
    ora #kTileIdObjToddlerFirst
    jmp FuncA_Objects_Draw1x2Actor  ; preserves X
.ENDPROC

;;; Allocates and populates OAM slots for the specified actor, using the given
;;; first tile ID and the subsequent tile ID.
;;; @param A The first tile ID.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_Draw1x2Actor
    pha  ; first tile ID
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    jsr FuncA_Objects_MoveShapeLeftHalfTile  ; preserves X
    ;; Allocate lower object.
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X
    bcs @doneLower
    pla  ; first tile ID
    pha  ; first tile ID
    adc #1  ; carry bit is already clear
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda Ram_ActorFlags_bObj_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @doneLower:
    ;; Allocate upper object.
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X
    pla  ; first tile ID
    bcs @doneUpper
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda Ram_ActorFlags_bObj_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @doneUpper:
    rts
.ENDPROC

;;;=========================================================================;;;
