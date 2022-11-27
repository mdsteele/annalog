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
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; OBJ tile IDs used for drawing console devices.
kTileIdObjConsoleScreenOk  = $0a
kTileIdObjConsoleScreenErr = $0b

;;; OBJ palette numbers used for drawing console devices.
kPaletteObjConsoleScreenOk  = 2
kPaletteObjConsoleScreenErr = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a console device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawConsoleDevice
.PROC FuncA_Objects_DrawConsoleDevice
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
_AdjustPosition:
    ;; Adjust X-position for the console screen.
    lda #4  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    ;; Adjust Y-position for the console screen.
    inc Zp_ShapePosY_i16 + 0
    bne @noCarry
    inc Zp_ShapePosY_i16 + 1
    @noCarry:
_AllocateObject:
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @done
    sty Zp_Tmp1_byte  ; OAM offset
    ;; Determine if the machine has an error.
    ldy Ram_DeviceTarget_u8_arr, x  ; machine index
    lda Ram_MachineStatus_eMachine_arr, y
    ldy Zp_Tmp1_byte  ; OAM offset
    cmp #eMachine::Error
    beq @machineError
    @machineOk:
    lda #kPaletteObjConsoleScreenOk
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kTileIdObjConsoleScreenOk
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    rts
    @machineError:
    lda #kPaletteObjConsoleScreenErr
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kTileIdObjConsoleScreenErr
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;