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
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "crate.inc"

.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr

;;;=========================================================================;;;

;;; The OBJ palette number used for drawing boulder and crate platforms.
kPaletteObjPlatformStack = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a platform that is a stack of one or more boulders.  The platform
;;; height should be a multiple of kBlockHeightPx.  If the platform type is
;;; non-solid, draws nothing.
;;; @param X The platform index.
.EXPORT FuncA_Objects_DrawBoulderPlatform
.PROC FuncA_Objects_DrawBoulderPlatform
    lda #kTileIdObjBoulderFirst  ; param: first tile ID
    .assert kTileIdObjBoulderFirst <> 0, error
    bne FuncA_Objects_Draw2x2PlatformStack  ; unconditional
.ENDPROC

;;; Draws a platform that is a stack of one or more wooden crates.  The
;;; platform height should be a multiple of kBlockHeightPx.  If the platform
;;; type is non-solid, draws nothing.
;;; @param X The platform index.
.EXPORT FuncA_Objects_DrawCratePlatform
.PROC FuncA_Objects_DrawCratePlatform
    lda #kTileIdObjCrateFirst  ; param: first tile ID
    fall FuncA_Objects_Draw2x2PlatformStack
.ENDPROC

;;; Draws a platform that is a stack of one or more 2x2 shapes.  The
;;; platform height should be a multiple of kBlockHeightPx.  If the platform
;;; type is non-solid, draws nothing.
;;; @param A The first tile ID for the repeated 2x2 shape.
;;; @param X The platform index.
.PROC FuncA_Objects_Draw2x2PlatformStack
    ;; If the platform isn't solid, we're done.
    ldy Ram_PlatformType_ePlatform_arr, x
    cpy #kFirstSolidPlatformType
    blt @done
    sta T2  ; first tile ID
    ;; Position the shape.
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X and T0+
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile  ; preserves X and T0+
    ;; Determine how many blocks tall the platform is.
    lda Ram_PlatformBottom_i16_0_arr, x
    sub Ram_PlatformTop_i16_0_arr, x
    div #kBlockHeightPx
    tax  ; platform height, in blocks
    @loop:
    lda T2  ; param: first tile ID
    ldy #kPaletteObjPlatformStack  ; param: flags
    jsr FuncA_Objects_Draw2x2Shape  ; preserves X and T2+
    lda #kBlockHeightPx
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X and T0+
    dex
    bne @loop
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
