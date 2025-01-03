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
.INCLUDE "acid.inc"

.IMPORT FuncA_Actor_TickProjEmber
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_InitActorDefault

;;;=========================================================================;;;

;;; The OBJ palette number used for acid projectile actors.
kPaletteObjProjAcid = 2

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Initializes the specified actor as an acid projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_InitActorProjAcid
.PROC FuncA_Actor_InitActorProjAcid
    ldy #eActor::ProjAcid  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X and T0+
.ENDPROC

;;; Performs per-frame updates for an acid projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjAcid := FuncA_Actor_TickProjEmber

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws an acid projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjAcid
.PROC FuncA_Objects_DrawActorProjAcid
    lda #kTileIdObjProjAcid  ; param: tile ID
    ldy #kPaletteObjProjAcid  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
