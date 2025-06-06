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

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_Draw2x2MirroredShape
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr

;;;=========================================================================;;;

;;; Various OBJ tile IDs used for drawing cracked columns.
kTileIdObjColumnCrackedMiddleFirst = kTileIdObjPlatformColumnFirst + 0
kTileIdObjColumnCrackedTop         = kTileIdObjPlatformColumnFirst + 4
kTileIdObjColumnCrackedBottom      = kTileIdObjPlatformColumnFirst + 5

;;; Various OBJ tile IDs used for drawing movable columns.
kTileIdObjColumnCorner = kTileIdObjPlatformColumnFirst + 6
kTileIdObjColumnSide   = kTileIdObjPlatformColumnFirst + 7

;;; The OBJ palette number to use for drawing columns.
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
    jsr _DrawColumnBlock  ; returns C and Y
    bcs @done  ; no objects were allocated
    lda #kTileIdObjColumnCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
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
    jsr _DrawColumnBlock  ; preserves X
    @continue:
    dex
    bne @loop
_Done:
    rts
_DrawColumnBlock:
    lda #kTileIdObjColumnSide  ; param: tile ID
    ldy #kPaletteObjColumn | bObj::Pri  ; param: object flags
    jmp FuncA_Objects_Draw2x2MirroredShape  ; preserves X, returns C and Y
.ENDPROC

;;; Draws a cracked column platform.
;;; @prereq PRGA_Objects is loaded.
;;; @param A The blink timer for the breakable floor.
;;; @param Y How many bullets have hit the column (0-3).
;;; @param X The platform index.
.EXPORT FuncC_Temple_DrawColumnCrackedPlatform
.PROC FuncC_Temple_DrawColumnCrackedPlatform
    ;; If the column platform is blinking for reset, alternate between drawing
    ;; it as it is and drawing it at full health (no hits).
    and #$04
    beq @noBlink
    ldy #0
    @noBlink:
    tya  ; num hits
    .assert kTileIdObjColumnCrackedMiddleFirst .mod 4 = 0, error
    ora #kTileIdObjColumnCrackedMiddleFirst
    pha  ; cracked tile ID
    ;; Top:
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldy #kPaletteObjColumn  ; param: object flags
    lda #kTileIdObjColumnCrackedTop  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape
    ;; Upper-middle:
    jsr FuncA_Objects_MoveShapeDownOneTile
    ldy #kPaletteObjColumn  ; param: object flags
    pla  ; param: tile ID
    pha  ; cracked tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    ;; Lower-middle:
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    ldy #kPaletteObjColumn | bObj::FlipV  ; param: object flags
    pla  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    ;; Bottom:
    jsr FuncA_Objects_MoveShapeDownOneTile
    ldy #kPaletteObjColumn  ; param: object flags
    lda #kTileIdObjColumnCrackedBottom  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;;=========================================================================;;;
