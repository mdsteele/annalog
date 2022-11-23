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
.INCLUDE "../ppu.inc"
.INCLUDE "townsfolk.inc"

.IMPORT FuncA_Objects_Alloc2x1Shape
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a mermaid NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickNpcMermaid
.PROC FuncA_Actor_TickNpcMermaid
    .assert * = FuncA_Actor_TickNpcChild, error, "fallthrough"
.ENDPROC

;;; Performs per-frame updates for a mermaid queen NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickNpcMermaidQueen
.PROC FuncA_Actor_TickNpcMermaidQueen
    .assert * = FuncA_Actor_TickNpcChild, error, "fallthrough"
.ENDPROC

;;; Performs per-frame updates for an adult NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickNpcAdult
.PROC FuncA_Actor_TickNpcAdult
    .assert * = FuncA_Actor_TickNpcChild, error, "fallthrough"
.ENDPROC

;;; Performs per-frame updates for a child NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickNpcChild
.PROC FuncA_Actor_TickNpcChild
    ;; TODO: instead of using tick, just always draw the NPC facing the avatar
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

;;; Draws an adult NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcAdult
.PROC FuncA_Objects_DrawActorNpcAdult
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    lda Ram_ActorState1_byte_arr, x  ; param: first tile ID
    jmp FuncA_Objects_Draw2x3ActorShape  ; preserves X
.ENDPROC

;;; Draws a child NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcChild
.PROC FuncA_Objects_DrawActorNpcChild
    ;; TODO: always use palette 1
    lda Ram_ActorState1_byte_arr, x  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
.ENDPROC

;;; Draws a mermaid NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcMermaid
.PROC FuncA_Objects_DrawActorNpcMermaid
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
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
    lda Ram_ActorState1_byte_arr, x  ; param: first tile ID
    jmp FuncA_Objects_Draw2x3ActorShape  ; preserves X
_VertOffset_u8_arr8:
    .byte 0, 0, 0, 1, 2, 2, 2, 1
.ENDPROC

;;; Draws a mermaid queen NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcMermaidQueen
.PROC FuncA_Objects_DrawActorNpcMermaidQueen
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
_TopHalf:
    lda Ram_ActorFlags_bObj_arr, x
    ora #1
    tay  ; param: object flags
    lda #kTileIdMermaidQueenFirst  ; param: first tile ID
    jsr FuncA_Objects_Draw2x2Shape  ; preserves X
_BottomHalf:
    lda #kTileHeightPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    ldy #0  ; param: object flags
    lda #kTileIdMermaidQueenFirst + 4  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X
.ENDPROC

;;; Draws the specified actor, using the given first tile ID and the five
;;; subsequent tile IDs.
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
    adc #2  ; carry flag is already clear
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
    adc #1  ; carry flag is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    adc #2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @doneTop:
    rts
.ENDPROC

;;;=========================================================================;;;
