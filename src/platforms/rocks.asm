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

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr

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
    jsr FuncA_Objects_StartDrawRocksPlatform  ; preserves X, returns C and T2
    bcc @done
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
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and T0+
    @startLoop:
    jsr FuncA_Objects_DrawRocksPlatformTile  ; preserves X and T2+
    dex
    bne @loop
    rts
.ENDPROC

;;; Draws a vertical (1xN) rocks platform.  The platform is assumed to be an
;;; integer number of tiles high and one tile wide.  If the platform type is
;;; non-solid, draws nothing.
;;; @param X The platform index.
.EXPORT FuncA_Objects_DrawRocksPlatformVert
.PROC FuncA_Objects_DrawRocksPlatformVert
    jsr FuncA_Objects_StartDrawRocksPlatform  ; preserves X, returns C and T2
    bcc @done
    ;; Determine how many tiles tall the platform is.
    lda Ram_PlatformBottom_i16_0_arr, x
    sub Ram_PlatformTop_i16_0_arr, x
    div #kTileHeightPx
    tax  ; platform width, in tiles
    ;; Draw the objects.
    bne @startLoop
    @done:
    rts
    @loop:
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X and T0+
    @startLoop:
    jsr FuncA_Objects_DrawRocksPlatformTile  ; preserves X and T2+
    dex
    bne @loop
    rts
.ENDPROC

;;; Determines if a rocks platform should be drawn, and if so, sets the shape
;;; position to the top-left corner of the platform, and returns the starting
;;; tile ID for the rocks.
;;; @param X The platform index.
;;; @return C Set if the platform should be drawn.
;;; @return T2 The starting tile ID.
;;; @preserve X
.PROC FuncA_Objects_StartDrawRocksPlatform
    ;; If the platform isn't solid, we're done.
    lda Ram_PlatformType_ePlatform_arr, x
    cmp #kFirstSolidPlatformType
    blt @return
    ;; Position the shape.
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    ;; Determine which rocks tile to start with.
    lda Ram_PlatformLeft_i16_0_arr, x
    eor Ram_PlatformTop_i16_0_arr, x
    .assert kTileWidthPx = kTileHeightPx, error
    div #kTileWidthPx
    and #$01
    .assert kTileIdObjRocksFirst .mod 2 = 0, error
    ora #kTileIdObjRocksFirst
    sta T2  ; starting tile ID
    sec  ; set C to indicate that the platform should be drawn
    @return:
    rts
.ENDPROC

;;; Draws one tile of a rocks platform, at the current shape position.
;;; @param X The index of this rock tile within the platform.
;;; @param T2 The starting tile ID.
;;; @preserve X, T2+
.PROC FuncA_Objects_DrawRocksPlatformTile
    txa  ; rock index
    and #$01
    eor T2  ; starting tile ID
    ldy #kPaletteObjRocks  ; param: objects flags
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
.ENDPROC

;;;=========================================================================;;;
