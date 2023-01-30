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

.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_RoomState
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte

;;;=========================================================================;;;

;;; OBJ tile IDs used for drawing lever handles.
kTileIdObjLeverHandleDown = $0e
kTileIdObjLeverHandleUp   = $0f

;;; The OBJ palette number used for drawing lever handles.
kPaletteObjLeverHandle = 0

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
    lda Zp_RoomState, y
    eor #$01
    sta Zp_RoomState, y
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a ceiling-mounted lever device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawLeverCeilingDevice
.PROC FuncA_Objects_DrawLeverCeilingDevice
    ldy #kPaletteObjLeverHandle | bObj::FlipV  ; param: flags
    bne FuncA_Objects_DrawLeverDevice  ; unconditional
.ENDPROC

;;; Draws a floor-mounted lever device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawLeverFloorDevice
.PROC FuncA_Objects_DrawLeverFloorDevice
    ldy #kPaletteObjLeverHandle  ; param: flags
    .assert * = FuncA_Objects_DrawLeverDevice, error, "fallthrough"
.ENDPROC

;;; Draws a lever device.
;;; @param X The device index.
;;; @param Y The base object flags to use (modulo bObj::FlipH).
;;; @preserve X
.PROC FuncA_Objects_DrawLeverDevice
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X and Y
    sty Zp_Tmp2_byte  ; object flags
_Animation:
    ;; Compute the animation frame number, storing it in Y.
    lda Ram_DeviceAnim_u8_arr, x
    div #kLeverAnimSlowdown
    sta Zp_Tmp1_byte  ; animation delta
    ldy Ram_DeviceTarget_u8_arr, x
    lda Zp_RoomState, y
    bne @leverIsOn
    @leverIsOff:
    lda Zp_Tmp1_byte  ; animation delta
    bpl @setAnimFrame  ; unconditional
    @leverIsOn:
    lda #kLeverNumAnimFrames - 1
    sub Zp_Tmp1_byte  ; animation delta
    @setAnimFrame:
    sta Zp_Tmp1_byte  ; animation frame
_AdjustPosition:
    ;; Adjust X-position for the lever handle.
    cmp #kLeverNumAnimFrames / 2
    blt @leftSide
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and Zp_Tmp*
    @leftSide:
    ;; Adjust Y-position for the lever handle.
    bit Zp_Tmp2_byte  ; object flags
    .assert bObj::FlipV = bProc::Negative, error
    bpl @floor
    @ceiling:
    lda #5
    bne @moveDown  ; unconditional
    @floor:
    lda #3
    @moveDown:
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X and Zp_Tmp*
_AllocateObject:
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X and Zp_Tmp*, returns C and Y
    bcs @done
    stx Zp_Tmp3_byte  ; device index
    ldx Zp_Tmp1_byte  ; animation frame
    lda Zp_Tmp2_byte  ; object flags
    cpx #kLeverNumAnimFrames / 2
    blt @noFlip
    eor #bObj::FlipH
    @noFlip:
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda _LeverTileIds_u8_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ldx Zp_Tmp3_byte  ; device index
    @done:
    rts
_LeverTileIds_u8_arr:
    .byte kTileIdObjLeverHandleDown
    .byte kTileIdObjLeverHandleUp
    .byte kTileIdObjLeverHandleUp
    .byte kTileIdObjLeverHandleDown
    .assert * - _LeverTileIds_u8_arr = kLeverNumAnimFrames, error
.ENDPROC

;;;=========================================================================;;;
