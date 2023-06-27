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
.INCLUDE "force.inc"

.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; The OBJ palette number used for drawing forcefield platforms.
kPaletteObjForcefield = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws forcefield platform.  The platform should be exactly one block in
;;; size.  If the platform type is non-solid, draws nothing.
;;; @param X The platform index.
.EXPORT FuncA_Objects_DrawForcefieldPlatform
.PROC FuncA_Objects_DrawForcefieldPlatform
    ;; If the platform isn't solid, we're done.
    ldy Ram_PlatformType_ePlatform_arr, x
    cpy #kFirstSolidPlatformType
    blt @done
    ;; Only draw the forcefield every other frame.
    lda Zp_FrameCounter_u8
    lsr a
    bcc @done
    and #$07
    .assert kTileIdObjForcefieldFirst .mod $08 = 0, error
    ora #kTileIdObjForcefieldFirst
    sta T2  ; tile ID
    ;; Allocate the objects.
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X and T0+
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile  ; preserves X and T0+
    lda #kPaletteObjForcefield  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X and T2+, returns C and Y
    bcs @done
    ;; Set tile IDs.
    lda T2  ; tile ID
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    ;; Set object flags.
    lda #kPaletteObjForcefield | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kPaletteObjForcefield | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kPaletteObjForcefield | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
