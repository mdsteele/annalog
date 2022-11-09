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

.INCLUDE "../device.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"

.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The number of VBlank frames per pixel that a rising breaker device moves.
.DEFINE kBreakerRisingSlowdown 4

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a rising (not yet ready to activate)
;;; breaker device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawBreakerRisingDevice
.PROC FuncA_Objects_DrawBreakerRisingDevice
    ldy #kTileIdBreakerFirst  ; param: first tile ID
    lda Ram_DeviceAnim_u8_arr, x
    div #kBreakerRisingSlowdown
    add #kTileHeightPx  ; param: vertical offset
    bne FuncA_Objects_DrawBreakerDevice  ; unconditional
.ENDPROC

;;; Allocates and populates OAM slots for a ready-to-activate breaker device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawBreakerReadyDevice
.PROC FuncA_Objects_DrawBreakerReadyDevice
    ldy #kTileIdBreakerFirst  ; param: first tile ID
    lda #kTileHeightPx  ; param: vertical offset
    bne FuncA_Objects_DrawBreakerDevice  ; unconditional
.ENDPROC

;;; Allocates and populates OAM slots for an already-activated breaker device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawBreakerDoneDevice
.PROC FuncA_Objects_DrawBreakerDoneDevice
    lda Ram_DeviceAnim_u8_arr, x
    .assert kBreakerDoneDeviceAnimStart = $1f, error
    lsr a
    and #$0c
    sta Zp_Tmp1_byte
    lda #kTileIdBreakerFirst + $0c
    sub Zp_Tmp1_byte
    tay  ; param: first tile ID
    lda #kTileHeightPx  ; param: vertical offset
    .assert * = FuncA_Objects_DrawBreakerDevice, error, "fallthrough"
.ENDPROC

;;; Allocates and populates OAM slots for a breaker device.
;;; @param A The vertical offset from the top of the device to the center of
;;;     the shape to draw.
;;; @param X The device index.
;;; @param Y The first tile ID for the breaker shape to draw.
;;; @preserve X
.PROC FuncA_Objects_DrawBreakerDevice
    ;; Position the shape:
    pha  ; vertical offset
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X and Y
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and Y
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and Y
    pla  ; param: vertical offset
    pha  ; vertical offset
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X and Y
    ;; Allocate objects:
    tya  ; first tile ID
    pha  ; first tile ID
    lda #bObj::Pri | kBreakerPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    pla  ; first tile ID
    bcs @done
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #1  ; carry flag is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    pla  ; vertical offset
    pha  ; vertical offset
    cmp #kTileHeightPx * 2
    blt @done
    lda #$ff
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
    @done:
    pla  ; vertical offset
    rts
.ENDPROC

;;;=========================================================================;;;
