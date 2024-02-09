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

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64

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
    ;; Allocate the object.
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
    lda #4  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @done
    sty T0  ; OAM offset
    ;; Determine if the machine has an error.
    ldy Ram_DeviceTarget_byte_arr, x  ; machine index
    lda Ram_MachineStatus_eMachine_arr, y
    ldy T0  ; OAM offset
    cmp #eMachine::Error
    beq @machineError
    @machineOk:
    lda #kPaletteObjConsoleOk
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kTileIdObjConsoleOk
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    rts
    @machineError:
    lda #kPaletteObjConsoleErr
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kTileIdObjConsoleErr
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
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
