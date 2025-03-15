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

.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"

.IMPORT FuncA_Objects_Draw2x2MirroredShape
.IMPORT FuncA_Objects_SetShapePosToActorCenter

;;;=========================================================================;;;

;;; The OBJ tile ID used for drawing hidden square NPC actors.
kTileIdObjNpcSquare = $06

;;; The OBJ palette number used for hidden square NPC actors.
kPaletteObjNpcSquare = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a hidden square NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcSquare
.PROC FuncA_Objects_DrawActorNpcSquare
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    lda #kTileIdObjNpcSquare  ; param: tile ID
    ldy #bObj::Pri | kPaletteObjNpcSquare  ; param: object flags
    jmp FuncA_Objects_Draw2x2MirroredShape
.ENDPROC

;;;=========================================================================;;;
