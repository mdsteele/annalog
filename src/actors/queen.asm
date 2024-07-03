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
.INCLUDE "queen.inc"

.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_GetNpcActorFlags
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_SetShapePosToActorCenter

;;;=========================================================================;;;

;;; OBJ palette numbers to use for drawing queen NPC actors.
kPaletteObjMermaidQueenBody = 0
kPaletteObjMermaidQueenHead = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a mermaid queen NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcQueen
.PROC FuncA_Objects_DrawActorNpcQueen
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
_TopHalf:
    jsr FuncA_Objects_GetNpcActorFlags  ; preserves X, returns A
    .assert kPaletteObjMermaidQueenHead <> 0, error
    ora #kPaletteObjMermaidQueenHead
    tay  ; param: object flags
    lda #kTileIdObjMermaidQueenFirst  ; param: first tile ID
    jsr FuncA_Objects_Draw2x2Shape  ; preserves X
_BottomHalf:
    lda #kTileHeightPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    ldy #kPaletteObjMermaidQueenBody  ; param: object flags
    lda #kTileIdObjMermaidQueenFirst + 4  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X
.ENDPROC

;;;=========================================================================;;;
