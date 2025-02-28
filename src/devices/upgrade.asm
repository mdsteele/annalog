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
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"

.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT FuncA_Objects_SetUpgradeTileIds
.IMPORT Func_PlaySfxPoof
.IMPORT Func_SetPointToDeviceCenter
.IMPORT Func_SpawnExplosionAtPoint
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr

;;;=========================================================================;;;

;;; The initial value to set in Ram_DeviceAnim_u8_arr when animating an upgrade
;;; device.
kUpgradeDeviceAnimStart = 23

;;; The OBJ palette number to use for drawing upgrade devices.
kPaletteObjUpgrade = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Spawns an upgrade device at the given device index (which should be a
;;; Placeholder device with the upgrade's eFlag as its target).  Also spawns a
;;; puff-of-smoke actor and plays a sound effect for the upgrade.
;;; @param Y The device index.
.EXPORT FuncA_Room_SpawnUpgradeDevice
.PROC FuncA_Room_SpawnUpgradeDevice
    lda #eDevice::Upgrade
    sta Ram_DeviceType_eDevice_arr, y
    lda #kUpgradeDeviceAnimStart
    sta Ram_DeviceAnim_u8_arr, y
    jsr Func_SetPointToDeviceCenter
    jsr Func_SpawnExplosionAtPoint
    jmp Func_PlaySfxPoof
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws an upgrade device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceUpgrade
.PROC FuncA_Objects_DrawDeviceUpgrade
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
_AdjustPosition:
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X
    ldy Ram_DeviceAnim_u8_arr, x
    lda _YOffsets_u8_arr, y
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X
_AllocateObjects:
    lda #kPaletteObjUpgrade  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @done
    lda Ram_DeviceTarget_byte_arr, x  ; param: eFlag value
    jmp FuncA_Objects_SetUpgradeTileIds  ; preserves X
    @done:
    rts
_YOffsets_u8_arr:
    ;; [12 - int(round(40 * x * (1-x))) for x in (y/24. for y in range(24))]
    .byte 12, 10, 9, 8, 6, 5, 4, 4, 3, 3, 2, 2
    .byte 2, 2, 2, 3, 3, 4, 4, 5, 6, 8, 9, 10
    .assert * - _YOffsets_u8_arr = kUpgradeDeviceAnimStart + 1, error
.ENDPROC

;;;=========================================================================;;;
