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
.INCLUDE "../ppu.inc"
.INCLUDE "rocks.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The OBJ palette number used for rocks platforms.
kPaletteObjRocks = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a horizontal (Nx1) rocks platform.  The platform is assumed to be an
;;; integer number of tiles wide (from 1 to at most 8) and one tile high.  If
;;; the platform type is non-solid, draws nothing.
;;; @param X The platform index.
.EXPORT FuncA_Objects_DrawRocksPlatformHorz
.PROC FuncA_Objects_DrawRocksPlatformHorz
    ;; If the platform isn't solid, we're done.
    lda Ram_PlatformType_ePlatform_arr, x
    cmp #kFirstSolidPlatformType
    blt @done
    ;; Position the shape.
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    ;; Determine which rocks tile to start with.
    lda Ram_PlatformRight_i16_0_arr, x
    eor Ram_PlatformTop_i16_0_arr, x
    .assert kTileWidthPx = kTileHeightPx, error
    div #kTileWidthPx
    and #$01
    .assert kTileIdObjRocksFirst .mod 2 = 0, error
    ora #kTileIdObjRocksFirst
    sta Zp_Tmp1_byte  ; base tile ID
    ;; Determine how many tiles wide the platform is.
    lda Ram_PlatformRight_i16_0_arr, x
    sub Ram_PlatformLeft_i16_0_arr, x
    div #kTileWidthPx
    tax  ; platform width, in tiles
    ;; Draw the objects.
    bne @startLoop
    @done:
    rts
    @loop:
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and Zp_Tmp*
    @startLoop:
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X and Zp_Tmp*, returns C and Y
    bcs @continue
    txa
    and #$01
    eor Zp_Tmp1_byte  ; base tile ID
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjRocks
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    dex
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;
