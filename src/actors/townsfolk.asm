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

.IMPORT FuncA_Objects_Alloc2x1Shape
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_PositionActorShape
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorState_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a mermaid townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickMermaid
.PROC FuncA_Actor_TickMermaid
    .assert * = FuncA_Actor_TickChild, error, "fallthrough"
.ENDPROC

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
    jsr FuncA_Objects_PositionActorShape  ; preserves X
    lda Ram_ActorState_byte_arr, x  ; param: first tile ID
    jmp FuncA_Objects_Draw2x3ActorShape  ; preserves X
.ENDPROC

;;; Allocates and populates OAM slots for a child townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawChildActor
.PROC FuncA_Objects_DrawChildActor
    lda Ram_ActorState_byte_arr, x  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
.ENDPROC

;;; Allocates and populates OAM slots for a mermaid townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawMermaidActor
.PROC FuncA_Objects_DrawMermaidActor
    jsr FuncA_Objects_PositionActorShape  ; preserves X
    ;; Adjust vertical position (to make the mermaid bob in the water).
    stx Zp_Tmp1_byte  ; actor index
    lda Zp_FrameCounter_u8
    div #8
    add Zp_Tmp1_byte  ; actor index
    and #$07
    tay
    lda Zp_ShapePosY_i16 + 0
    sub _VertOffset_u8_arr8, y
    sta Zp_ShapePosY_i16 + 0
    lda Zp_ShapePosY_i16 + 1
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Draw the actor.
    lda Ram_ActorState_byte_arr, x  ; param: first tile ID
    jmp FuncA_Objects_Draw2x3ActorShape  ; preserves X
_VertOffset_u8_arr8:
    .byte 0, 0, 0, 1, 2, 2, 2, 1
.ENDPROC

;;; Allocates and populates OAM slots for the specified actor, using the given
;;; first tile ID and the five subsequent tile IDs.
;;; @prereq The shape position has been initialized.
;;; @param A The first tile ID.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_Draw2x3ActorShape
    pha  ; first tile ID
_BottomThird:
    lda Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jsr FuncA_Objects_Alloc2x1Shape  ; preserves X, returns C and Y
    bcs @doneBottom
    pla  ; first tile ID
    pha  ; first tile ID
    add #2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #3
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    @doneBottom:
_TopTwoThirds:
    jsr FuncA_Objects_MoveShapeUpOneTile
    lda Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    pla  ; first tile ID
    bcs @doneTop
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    adc #2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @doneTop:
    rts
.ENDPROC

;;;=========================================================================;;;
