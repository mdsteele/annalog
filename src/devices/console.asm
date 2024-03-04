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
.IMPORT FuncA_Objects_MoveShapeRightByA
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
.EXPORT FuncA_Objects_DrawConsoleDevice
.PROC FuncA_Objects_DrawConsoleDevice
    lda Ram_DeviceAnim_u8_arr, x
    and #$04
    bne @done
    ;; Position the shape.
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
    lda #4  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    ;; Check the machine's status.
    ldy Ram_DeviceTarget_byte_arr, x  ; machine index
    lda Ram_MachineStatus_eMachine_arr, y
    cmp #eMachine::Error
    beq @machineError
    @machineOk:
    ldy #kPaletteObjConsoleOk  ; param: object flags
    lda #kTileIdObjConsoleOk  ; param: tile ID
    .assert kTileIdObjConsoleOk > 0, error
    bne @drawShape  ; unconditional
    ;; If the machine has an error, blink the console screen.
    @machineError:
    lda Zp_FrameCounter_u8
    and #$08
    beq @done
    ldy #kPaletteObjConsoleErr  ; param: object flags
    lda #kTileIdObjConsoleErr  ; param: tile ID
    @drawShape:
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
    @done:
    rts
.ENDPROC

;;; Draws a screen device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawScreenDevice
.PROC FuncA_Objects_DrawScreenDevice
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
    lda #4  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    ldy #kPaletteObjScreen  ; param: object flags
    lda #kTileIdObjScreen  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
.ENDPROC

;;;=========================================================================;;;
