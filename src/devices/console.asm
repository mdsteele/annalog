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
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeRightHalfTile
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; The vertical object offset to apply for drawing floor and ceiling
;;; consoles/screens.
kFloorScreenOffset   = 0
kCeilingScreenOffset = 5

;;; OBJ tile IDs used for drawing console devices.
kTileIdObjConsoleOk  = $08
kTileIdObjConsoleErr = $09
kTileIdObjScreen     = kTileIdObjConsoleOk

;;; OBJ palette numbers used for drawing console/screen devices.
kPaletteObjConsoleOk  = 2
kPaletteObjConsoleErr = 1
kPaletteObjScreen     = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a ceiling console device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceConsoleCeiling
.PROC FuncA_Objects_DrawDeviceConsoleCeiling
    ldy #kCeilingScreenOffset  ; param: vertical offset
    .assert kCeilingScreenOffset < $80, error
    bpl FuncA_Objects_DrawDeviceConsole  ; unconditional; preserves X
.ENDPROC

;;; Draws a floor console device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceConsoleFloor
.PROC FuncA_Objects_DrawDeviceConsoleFloor
    ldy #kFloorScreenOffset  ; param: vertical offset
    fall FuncA_Objects_DrawDeviceConsole  ; preserves X
.ENDPROC

;;; Draws a console device.
;;; @param X The device index.
;;; @param Y The vertical offset for the object to draw.
;;; @preserve X
.PROC FuncA_Objects_DrawDeviceConsole
    jsr FuncA_Objects_SetShapePosForDeviceScreenWithOffset  ; preserves X
    ;; If the device is animating, blink the console screen quickly.
    lda Ram_DeviceAnim_u8_arr, x
    and #$04
    bne _Blank
    ;; Check the machine's status.
    ldy Ram_DeviceTarget_byte_arr, x  ; machine index
    lda Ram_MachineStatus_eMachine_arr, y
    cmp #eMachine::Error
    bne _Ok
_Error:
    ;; Blink the console screen slowly.
    lda Zp_FrameCounter_u8
    and #$08
    beq _Blank
    ;; Draw the error screen.
    ldy #kPaletteObjConsoleErr  ; param: object flags
    lda #kTileIdObjConsoleErr  ; param: tile ID
    .assert kTileIdObjConsoleErr > 0, error
    bne _Draw  ; unconditional
_Ok:
    ldy #kPaletteObjConsoleOk  ; param: object flags
    lda #kTileIdObjConsoleOk  ; param: tile ID
_Draw:
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
_Blank:
    rts
.ENDPROC

;;; Draws a red ceiling screen device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceScreenCeiling
.PROC FuncA_Objects_DrawDeviceScreenCeiling
    lda #kPaletteObjScreen  ; param: object flags
    ldy #kCeilingScreenOffset  ; param: vertical offset
    .assert kCeilingScreenOffset < $80, error
    bpl FuncA_Objects_DrawDeviceScreen  ; unconditional, preserves X
.ENDPROC

;;; Draws a fake floor console device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceFakeConsole
.PROC FuncA_Objects_DrawDeviceFakeConsole
    fall FuncA_Objects_DrawDeviceScreenGreen  ; preserves X
.ENDPROC

;;; Draws a green floor screen device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceScreenGreen
.PROC FuncA_Objects_DrawDeviceScreenGreen
    lda #kPaletteObjConsoleOk  ; param: object flags
    .assert kPaletteObjConsoleOk <> 0, error
    bne FuncA_Objects_DrawDeviceScreenFloor  ; unconditional, preserves X
.ENDPROC

;;; Draws a red floor screen device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceScreenRed
.PROC FuncA_Objects_DrawDeviceScreenRed
    lda #kPaletteObjScreen  ; param: object flags
    fall FuncA_Objects_DrawDeviceScreenFloor
.ENDPROC

;;; Draws a floor screen device.
;;; @param X The device index.
;;; @param A The bObj value for the object flags.
;;; @preserve X
.PROC FuncA_Objects_DrawDeviceScreenFloor
    ldy #kFloorScreenOffset  ; param: vertical offset
    fall FuncA_Objects_DrawDeviceScreen
.ENDPROC

;;; Draws a screen device.
;;; @param X The device index.
;;; @param Y The vertical offset for the object to draw.
;;; @param A The bObj value for the object flags.
;;; @preserve X
.PROC FuncA_Objects_DrawDeviceScreen
    pha  ; object flags
    jsr FuncA_Objects_SetShapePosForDeviceScreenWithOffset  ; preserves X
    pla  ; object flags
    tay  ; param: object flags
    lda #kTileIdObjScreen  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
.ENDPROC

;;; Sets the shape position for drawing a console or screen device with the
;;; given vertical offset.
;;; @param X The device index.
;;; @param Y The vertical offset for the object to draw.
;;; @preserve X
.PROC FuncA_Objects_SetShapePosForDeviceScreenWithOffset
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X and Y
    tya  ; param: vertical offset
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X
    jmp FuncA_Objects_MoveShapeRightHalfTile  ; preserves X
.ENDPROC

;;;=========================================================================;;;
