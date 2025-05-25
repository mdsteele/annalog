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
.INCLUDE "../ppu.inc"
.INCLUDE "smoke.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeLeftOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorDefault
.IMPORT Func_RemoveActor
.IMPORT Func_SetActorCenterToPoint
.IMPORT Ram_ActorState1_byte_arr

;;;=========================================================================;;;

;;; How long a smoke actor animates before disappearing, in frames.
kSmokeNumFrames = 12

;;; The OBJ palette number used for smoke explosion actors.
kPaletteObjExplosion = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Spawns a new smoke explosion actor (if possible), starting it at the
;;; room pixel position stored in Zp_PointX_i16 and Zp_PointY_i16.
;;; @preserve T0+
.EXPORT Func_SpawnExplosionAtPoint
.PROC Func_SpawnExplosionAtPoint
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcc @spawn
    rts
    @spawn:
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    fall Func_InitActorSmokeExplosion  ; preserves T0+
.ENDPROC

;;; Initializes the specified actor as a smoke explosion.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT Func_InitActorSmokeExplosion
.PROC Func_InitActorSmokeExplosion
    ldy #eActor::SmokeExplosion  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a smoke explosion actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickSmokeExplosion
.PROC FuncA_Actor_TickSmokeExplosion
    inc Ram_ActorState1_byte_arr, x
    lda Ram_ActorState1_byte_arr, x
    cmp #kSmokeNumFrames
    blt @done
    jmp Func_RemoveActor  ; preserves X
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a smoke explosion actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorSmokeExplosion
.PROC FuncA_Objects_DrawActorSmokeExplosion
_BottomRight:
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    lda Ram_ActorState1_byte_arr, x  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    jsr _DrawSmokeParticle  ; preserves X
_BottomLeft:
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    jsr FuncA_Objects_MoveShapeLeftOneTile
    lda Ram_ActorState1_byte_arr, x  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X
    jsr _DrawSmokeParticle  ; preserves X
_TopLeft:
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    jsr FuncA_Objects_MoveShapeUpOneTile
    lda Ram_ActorState1_byte_arr, x
    add #kTileWidthPx  ; param: offset
    jsr FuncA_Objects_MoveShapeLeftByA  ; preserves X
    jsr _DrawSmokeParticle  ; preserves X
_TopRight:
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    lda Ram_ActorState1_byte_arr, x
    add #kTileHeightPx  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA  ; preserves X
_DrawSmokeParticle:
    lda Ram_ActorState1_byte_arr, x
    div #2
    add #kTileIdObjSmokeFirst  ; param: tile ID
    ldy #kPaletteObjExplosion  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
.ENDPROC

;;;=========================================================================;;;
