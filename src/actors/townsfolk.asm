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
.IMPORT FuncA_Objects_BobActorShapePosUpAndDown
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_GetNpcActorFlags
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_Oam_sObj_arr64

;;;=========================================================================;;;

;;; OBJ palette numbers to use for drawing various townsfolks NPC actors.
kPaletteObjAdult            = 0
kPaletteObjMermaid          = 0
kPaletteObjMermaidQueenBody = 0
kPaletteObjMermaidQueenHead = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws an adult NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcAdult
.PROC FuncA_Objects_DrawActorNpcAdult
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    jsr FuncA_Objects_GetNpcActorFlags  ; preserves X, returns A
    .assert kPaletteObjAdult = 0, error
    tay  ; param: object flags
    lda Ram_ActorState1_byte_arr, x  ; param: first tile ID
    jmp FuncA_Objects_Draw2x3TownsfolkShape  ; preserves X
.ENDPROC

;;; Draws a mermaid NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcMermaid
.PROC FuncA_Objects_DrawActorNpcMermaid
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    jsr FuncA_Objects_BobActorShapePosUpAndDown  ; preserves X
    ;; Draw the actor.
    jsr FuncA_Objects_GetNpcActorFlags  ; preserves X, returns A
    .assert kPaletteObjMermaid = 0, error
    tay  ; param: object flags
    lda Ram_ActorState1_byte_arr, x  ; param: first tile ID
    cmp #kFirst2x4MermaidTileId
    blt FuncA_Objects_Draw2x3TownsfolkShape  ; preserves X
    jmp FuncA_Objects_Draw2x4TownsfolkShape  ; preserves X
.ENDPROC

;;; Draws a mermaid queen NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcMermaidQueen
.PROC FuncA_Objects_DrawActorNpcMermaidQueen
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
_TopHalf:
    jsr FuncA_Objects_GetNpcActorFlags  ; preserves X, returns A
    .assert kPaletteObjMermaidQueenHead <> 0, error
    ora #kPaletteObjMermaidQueenHead
    tay  ; param: object flags
    lda #kTileIdMermaidQueenFirst  ; param: first tile ID
    jsr FuncA_Objects_Draw2x2Shape  ; preserves X
_BottomHalf:
    lda #kTileHeightPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    ldy #kPaletteObjMermaidQueenBody  ; param: object flags
    lda #kTileIdMermaidQueenFirst + 4  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X
.ENDPROC

;;; Draws a 2x3-tile shape, using the given first tile ID and the five
;;; subsequent tile IDs.
;;; @prereq The shape position has been initialized.
;;; @param A The first tile ID.
;;; @param Y The object flags to use.
;;; @preserve X
.EXPORT FuncA_Objects_Draw2x3TownsfolkShape
.PROC FuncA_Objects_Draw2x3TownsfolkShape
    sta T2  ; first tile ID
    sty T3  ; object flags
_BottomThird:
    tya  ; param: object flags
    jsr FuncA_Objects_Alloc2x1Shape  ; preserves X and T2+, returns C and Y
    bcs @doneBottom
    lda T2  ; first tile ID
    adc #2  ; carry flag is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #3
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    @doneBottom:
_TopTwoThirds:
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X and T0+
    lda T3  ; param: object flags
    ;; TODO: This could just be Draw2x2Shape if we re-ordered the tiles.
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X and T2+, returns C and Y
    bcs @doneTop
    lda T2  ; first tile ID
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

;;; Draws a 2x4-tile shape, using the given first tile ID and the seven
;;; subsequent tile IDs.
;;; @prereq The shape position has been initialized.
;;; @param A The first tile ID.
;;; @param Y The object flags to use.
;;; @preserve X
.PROC FuncA_Objects_Draw2x4TownsfolkShape
    sta T2  ; first tile ID
    sty T3  ; object flags
_TopHalf:
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X, Y, and T0+
    lda T2  ; param: first tile ID
    jsr FuncA_Objects_Draw2x2Shape  ; preserves X and T2+
_BottomHalf:
    lda #kTileHeightPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X and T0+
    lda T2  ; first tile ID
    add #4  ; param: first tile ID
    ldy T3  ; param: object flags
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X
.ENDPROC

;;;=========================================================================;;;
