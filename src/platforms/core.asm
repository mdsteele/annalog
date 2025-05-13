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

.INCLUDE "../machines/shared.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "core.inc"

.IMPORT FuncA_Objects_DrawShapeTiles
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft

;;;=========================================================================;;;

.LINECONT +
.ASSERT kCoreInnerPlatformWidthPx = \
    kTileWidthPx * kCoreInnerPlatformWidthTiles, error
.ASSERT kCoreOuterPlatformWidthPx = \
    kTileWidthPx * kCoreOuterPlatformWidthTiles, error
.LINECONT -

;;; OBJ tile IDs used for drawing core platforms.
kTileIdObjCoreTop    = kTileIdObjMachineSurfaceHorz
kTileIdObjCoreCorner = kTileIdObjPlatformCoreFirst + 0
kTileIdObjCoreDiag   = kTileIdObjPlatformCoreFirst + 1
kTileIdObjCoreSide   = kTileIdObjPlatformCoreFirst + 2
kTileIdObjCoreStripe = kTileIdObjPlatformCoreFirst + 3
kTileIdObjCoreMiddle = kTileIdObjPlatformCoreFirst + 4
kTileIdObjCoreLight  = kTileIdObjPlatformCoreFirst + 5

;;; OBJ palette numbers used for drawing core platforms.
kPaletteObjCorePlatform = 0
kPaletteObjCoreLight    = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws objects for the top two tile rows of the power core inner platform.
.EXPORT FuncA_Objects_DrawCoreInnerPlatform
.PROC FuncA_Objects_DrawCoreInnerPlatform
    ldx #kCoreInnerPlatformIndex
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldya #_Tiles_sShapeTile_arr  ; param: sShapeTile arr ptr
    jmp FuncA_Objects_DrawShapeTiles
_Tiles_sShapeTile_arr:
    ;; First row:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreCorner
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreTop
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreDiag
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreTop
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreTop
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform | bObj::FlipH
    d_byte Tile_u8, kTileIdObjCoreCorner
    D_END
    ;; Second row:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <(kTileWidthPx * -5)
    d_byte DeltaY_i8, kTileHeightPx
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreSide
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreMiddle
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreStripe
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCoreLight
    d_byte Tile_u8, kTileIdObjCoreLight
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreMiddle
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform | bObj::FlipH | bObj::Final
    d_byte Tile_u8, kTileIdObjCoreSide
    D_END
.ENDPROC

;;; Draws objects for the top two tile rows of the power core outer platform.
.EXPORT FuncA_Objects_DrawCoreOuterPlatform
.PROC FuncA_Objects_DrawCoreOuterPlatform
    ldx #kCoreOuterPlatformIndex
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldya #_Tiles_sShapeTile_arr  ; param: sShapeTile arr ptr
    jmp FuncA_Objects_DrawShapeTiles
_Tiles_sShapeTile_arr:
    ;; First row:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreCorner
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreTop
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreDiag
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreTop
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreTop
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreTop
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreTop
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform | bObj::FlipH
    d_byte Tile_u8, kTileIdObjCoreCorner
    D_END
    ;; Second row:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <(kTileWidthPx * -7)
    d_byte DeltaY_i8, kTileHeightPx
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreSide
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreMiddle
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreStripe
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreMiddle
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreMiddle
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreMiddle
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform
    d_byte Tile_u8, kTileIdObjCoreMiddle
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjCorePlatform | bObj::FlipH | bObj::Final
    d_byte Tile_u8, kTileIdObjCoreSide
    D_END
.ENDPROC

;;;=========================================================================;;;
