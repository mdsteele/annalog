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
.INCLUDE "smoke.inc"

.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Ram_ActorState1_byte_arr
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; The OBJ tile ID for blinky NPC actors.
kTileIdObjBlinky = kTileIdObjSmokeFirst + 5

;;; The OBJ palette number used for blinky NPC actors.
kPaletteObjBlinky = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a blinky NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcBlinky
.PROC FuncA_Objects_DrawActorNpcBlinky
    lda Zp_FrameCounter_u8
    div #8
    mod #8
    tay
    lda Data_PowersOfTwo_u8_arr8, y
    and Ram_ActorState1_byte_arr, x
    beq @done
    ldy #kPaletteObjBlinky  ; param: object flags
    lda #kTileIdObjBlinky  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
