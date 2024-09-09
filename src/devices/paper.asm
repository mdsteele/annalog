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

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeRightHalfTile
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT Func_IsFlagSet
.IMPORT Ram_DeviceTarget_byte_arr

;;;=========================================================================;;;

;;; OBJ tile IDs used for drawing paper devices.
kTileIdObjPaperCollected    = $0c
kTileIdObjPaperNotCollected = $0d

;;; The OBJ palette number to use for drawing paper devices.
kPaletteObjPaper = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a paper device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDevicePaper
.PROC FuncA_Objects_DrawDevicePaper
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
    jsr FuncA_Objects_MoveShapeRightHalfTile  ; preserves X
    lda Ram_DeviceTarget_byte_arr, x  ; eFlag::Paper* value
    stx T0  ; device index
    tax  ; param: flag
    jsr Func_IsFlagSet  ; preserves T0+, returns Z
    beq @notCollected
    @collected:
    lda #kTileIdObjPaperCollected  ; param: tile ID
    bne @doneTileId  ; unconditional
    @notCollected:
    lda #kTileIdObjPaperNotCollected  ; param: tile ID
    @doneTileId:
    ldx T0  ; device index
    ldy #kPaletteObjPaper  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
.ENDPROC

;;;=========================================================================;;;
