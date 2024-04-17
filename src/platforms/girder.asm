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
.INCLUDE "../ppu.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformRight_i16_0_arr

;;;=========================================================================;;;

;;; The OBJ palette number used for FuncA_Objects_DrawGirderPlatform.
kPaletteObjGirder = 0
;;; The OBJ tile ID used for FuncA_Objects_DrawGirderPlatform.
kTileIdObjGirder = $04

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots to draw an Nx1 girder for the specified
;;; platform.  The platform is assumed to be an integer number of tiles wide
;;; (from 1 to at most 8) and one tile high.  When this function returns,
;;; Zp_ShapePosX_i16 and Zp_ShapePosY_i16 will be positioned for the rightmost
;;; tile of the girder (whether or not that tile was actually drawn).
;;; @param X The platform index.
.EXPORT FuncA_Objects_DrawGirderPlatform
.PROC FuncA_Objects_DrawGirderPlatform
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    ;; Determine how many tiles wide the platform is.
    lda Ram_PlatformRight_i16_0_arr, x
    sub Ram_PlatformLeft_i16_0_arr, x
    div #kTileWidthPx
    tax  ; platform width, in tiles
    ;; Allocate the objects.
    bne @startLoop
    rts
    @loop:
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X
    @startLoop:
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @continue
    lda #kTileIdObjGirder
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjGirder
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    dex
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;
