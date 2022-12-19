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
.INCLUDE "column.inc"

.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr

;;;=========================================================================;;;

;;; Various OBJ tile IDs used for drawing the movable column.
kTileIdObjColumnCorner = kTileIdObjColumnFirst + 0
kTileIdObjColumnSide   = kTileIdObjColumnFirst + 1

;;; The OBJ palette number to use for drawing the movable column.
kPaletteObjColumn = 0

;;;=========================================================================;;;

.SEGMENT "PRGC_Temple"

;;; Draws a movable column platform.  The platform height should be a multiple
;;; of kBlockHeightPx.
;;; @prereq PRGA_Objects is loaded.
;;; @param X The platform index.
.EXPORT FuncC_Temple_DrawColumnPlatform
.PROC FuncC_Temple_DrawColumnPlatform
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
_ColumnTop:
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile  ; preserves X
    lda #kPaletteObjColumn | bObj::Pri  ; param: obj flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @done
    lda #kTileIdObjColumnCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdObjColumnSide
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda #kPaletteObjColumn | bObj::Pri | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @done:
_ColumnBody:
    ;; Determine how many blocks tall the platform is.
    lda Ram_PlatformBottom_i16_0_arr, x
    sub Ram_PlatformTop_i16_0_arr, x
    div #kBlockHeightPx
    tax  ; total platform height, in blocks
    beq _Done
    bne @continue  ; unconditional
    @loop:
    lda #kBlockHeightPx  ; param: move delta
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X
    lda #kPaletteObjColumn | bObj::Pri  ; param: obj flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @continue
    lda #kTileIdObjColumnSide
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda #kPaletteObjColumn | bObj::Pri | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @continue:
    dex
    bne @loop
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;
