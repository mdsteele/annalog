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

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeLeftOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_InitActorDefault
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_Oam_sObj_arr64

;;;=========================================================================;;;

;;; How long a smoke actor animates before disappearing, in frames.
kSmokeNumFrames = 12

;;; The first tile ID for the smoke particle animation.
kSmokeFirstTileId = $1a

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as a smoke cloud.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitActorProjSmoke
.PROC Func_InitActorProjSmoke
    ldy #eActor::ProjSmoke  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a smoke cloud actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjSmoke
.PROC FuncA_Actor_TickProjSmoke
    inc Ram_ActorState1_byte_arr, x
    lda Ram_ActorState1_byte_arr, x
    cmp #kSmokeNumFrames
    blt @done
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a smoke cloud actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjSmoke
.PROC FuncA_Objects_DrawActorProjSmoke
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
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X
    bcs @done
    lda Ram_ActorState1_byte_arr, x
    div #2
    add #kSmokeFirstTileId
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda Ram_ActorFlags_bObj_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
