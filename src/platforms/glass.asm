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
.INCLUDE "../platform.inc"
.INCLUDE "glass.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft

;;;=========================================================================;;;

;;; The OBJ palette number used for drawing glass tank platforms.
kPaletteObjGlass = 0

;;;=========================================================================;;;

.SEGMENT "PRGC_Shadow"

;;; Draws a glass tank platform.
;;; @prereq PRGA_Objects is loaded.
;;; @param A The blink timer for the breakable floor.
;;; @param Y How many bullets have hit the glass (0-3).
;;; @param X The platform index.
.EXPORT FuncC_Shadow_DrawGlassPlatform
.PROC FuncC_Shadow_DrawGlassPlatform
    ;; If the glass platform is blinking for reset, alternate between drawing
    ;; it as it is and drawing it at full health (no hits).
    and #$04
    beq @noBlink
    ldy #0
    @noBlink:
    cpy #kNumHitsToBreakGlass
    bge @done  ; glass is fully broken
    sty T2  ; num hits
    ;; Draw the platform.
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves Y and T0+
    lda T2  ; num hits
    .assert kTileIdObjGlassFirst .mod 4 = 0, error
    ora #kTileIdObjGlassFirst + 0  ; param: tile ID
    ldy #kPaletteObjGlass  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves T2+
    jsr FuncA_Objects_MoveShapeDownOneTile
    lda T2  ; num hits
    .assert kTileIdObjGlassFirst .mod 4 = 0, error
    ora #kTileIdObjGlassFirst + 4  ; param: tile ID
    ldy #kPaletteObjGlass  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape  ; preserves T2+
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
