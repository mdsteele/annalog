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
.IMPORT FuncA_Objects_MoveShapeRightHalfTile
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

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

;;; Draws a console device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceConsole
.PROC FuncA_Objects_DrawDeviceConsole
    ;; The the device is animating, blink the console screen quickly.
    lda Ram_DeviceAnim_u8_arr, x
    and #$04
    bne FuncA_Objects_DrawDeviceConsoleBlank  ; preserves X
    ;; Check the machine's status.
    ldy Ram_DeviceTarget_byte_arr, x  ; machine index
    lda Ram_MachineStatus_eMachine_arr, y
    cmp #eMachine::Error
    bne FuncA_Objects_DrawDeviceConsoleOk  ; preserves X
    fall FuncA_Objects_DrawDeviceConsoleErr  ; preserves X
.ENDPROC

;;; Draws a console device for a machine with an error.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawDeviceConsoleErr
    ;; Blink the console screen slowly.
    lda Zp_FrameCounter_u8
    and #$08
    beq FuncA_Objects_DrawDeviceConsoleBlank  ; preserves X
    ;; Draw the error screen.
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
    jsr FuncA_Objects_MoveShapeRightHalfTile  ; preserves X
    ldy #kPaletteObjConsoleErr  ; param: object flags
    lda #kTileIdObjConsoleErr  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
.ENDPROC

;;; Draws a console device whose screen is currently blank.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawDeviceConsoleBlank
    rts
.ENDPROC

;;; Draws a fake console device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceFakeConsole
.PROC FuncA_Objects_DrawDeviceFakeConsole
    fall FuncA_Objects_DrawDeviceConsoleOk  ; preserves X
.ENDPROC

;;; Draws a console device for a machine that doesn't have an error.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawDeviceConsoleOk
    ldy #kPaletteObjConsoleOk  ; param: object flags
    .assert kPaletteObjConsoleOk <> 0, error
    bne FuncA_Objects_DrawDeviceConsoleOrScreen  ; unconditional, preserves X
.ENDPROC

;;; Draws a screen device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceScreen
.PROC FuncA_Objects_DrawDeviceScreen
    ldy #kPaletteObjScreen  ; param: object flags
    fall FuncA_Objects_DrawDeviceConsoleOrScreen
.ENDPROC

;;; Draws a non-error console or screen device.
;;; @param X The device index.
;;; @param Y The bObj value for the object flags.
;;; @preserve X
.PROC FuncA_Objects_DrawDeviceConsoleOrScreen
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X and Y
    jsr FuncA_Objects_MoveShapeRightHalfTile  ; preserves X and Y
    lda #kTileIdObjScreen  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
.ENDPROC

;;;=========================================================================;;;
