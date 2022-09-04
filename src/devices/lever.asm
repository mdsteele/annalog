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

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_RoomState
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The number of animation frames a lever device has (i.e. the number of
;;; distinct ways of drawing it).
kLeverNumAnimFrames = 4
;;; The number of VBlank frames per lever animation frame.
.DEFINE kLeverAnimSlowdown 4
;;; The number of VBlank frames for a complete lever animation (i.e. the value
;;; to store in Ram_DeviceAnim_u8_arr when the lever is flipped).
kLeverAnimCountdown = kLeverNumAnimFrames * kLeverAnimSlowdown - 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Toggles a lever device to the other position, changing its state and
;;; initializing its animation.
;;; @param X The device index for the lever.
.EXPORT Func_ToggleLeverDevice
.PROC Func_ToggleLeverDevice
    lda #kLeverAnimCountdown
    sta Ram_DeviceAnim_u8_arr, x
    ldy Ram_DeviceTarget_u8_arr, x
    lda Ram_RoomState, y
    eor #$01
    sta Ram_RoomState, y
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a lever device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawLeverDevice
.PROC FuncA_Objects_DrawLeverDevice
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
_Animation:
    ;; Compute the animation frame number, storing it in Y.
    lda Ram_DeviceAnim_u8_arr, x
    div #kLeverAnimSlowdown
    sta Zp_Tmp1_byte  ; animation delta
    ldy Ram_DeviceTarget_u8_arr, x
    lda Ram_RoomState, y
    bne @leverIsOn
    @leverIsOff:
    lda Zp_Tmp1_byte  ; animation delta
    bpl @setAnimFrame  ; unconditional
    @leverIsOn:
    lda #kLeverNumAnimFrames - 1
    sub Zp_Tmp1_byte  ; animation delta
    @setAnimFrame:
    tay  ; animation frame
_AdjustPosition:
    ;; Adjust X-position for the lever handle.
    cpy #kLeverNumAnimFrames / 2
    blt @leftSide
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and Y
    @leftSide:
    ;; Adjust Y-position for the lever handle.
    lda Zp_ShapePosY_i16 + 0
    add #3
    sta Zp_ShapePosY_i16 + 0
    lda Zp_ShapePosY_i16 + 1
    adc #0
    sta Zp_ShapePosY_i16 + 1
_AllocateObject:
    tya
    pha  ; animation frame
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    pla  ; animation frame
    bcs @done
    stx Zp_Tmp1_byte  ; device index
    tax  ; animation frame
    lda #kLeverHandlePalette
    cpx #kLeverNumAnimFrames / 2
    blt @noFlip
    ora #bObj::FlipH
    @noFlip:
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda _LeverTileIds_u8_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ldx Zp_Tmp1_byte  ; device index
    @done:
    rts
_LeverTileIds_u8_arr:
    .byte kLeverHandleTileIdDown
    .byte kLeverHandleTileIdUp
    .byte kLeverHandleTileIdUp
    .byte kLeverHandleTileIdDown
    .assert * - _LeverTileIds_u8_arr = kLeverNumAnimFrames, error
.ENDPROC

;;;=========================================================================;;;
