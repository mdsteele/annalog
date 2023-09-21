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
.INCLUDE "monitor.inc"

.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft

;;;=========================================================================;;;

;;; The OBJ palette number used for drawing monitor platforms.
kPaletteObjMonitor = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a platform that is a console monitor.  The platform width should be
;;; kBlockWidthPx and the platform height should be kBlockHeightPx.
;;; @param X The platform index.
.EXPORT FuncA_Objects_DrawMonitorPlatform
.PROC FuncA_Objects_DrawMonitorPlatform
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile  ; preserves X
    lda #kTileIdObjMonitorFirst  ; param: first tile ID
    ldy #kPaletteObjMonitor  ; param: flags
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X and T2+
.ENDPROC

;;;=========================================================================;;;
