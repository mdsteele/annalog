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
.IMPORT FuncA_Room_PlaySfxSpawnUpgrade
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceBlockCol_u8_arr
.IMPORT Ram_DeviceBlockRow_u8_arr
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
_SmokePuff:
    ;; Create a puff of smoke over the upgrade device.
    jsr Func_FindEmptyActorSlot  ; preserves Y, sets C on failure, returns X
    bcs @done
    lda #0
    sta Ram_ActorPosX_i16_1_arr, x
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Set the smoke Y-position.
    lda Ram_DeviceBlockRow_u8_arr, y
    .assert kTallRoomHeightBlocks <= $20, error
    asl a  ; Since kTallRoomHeightBlocks <= $20, the device block row fits in
    asl a  ; five bits, so the first three ASL's won't set the carry bit, so
    asl a  ; we only need to ROL the Ram_ActorPosY_i16_1 after the fourth ASL.
    asl a
    rol Ram_ActorPosY_i16_1_arr, x
    adc #kTileHeightPx
    sta Ram_ActorPosY_i16_0_arr, x
    ;; Set the smoke X-position.
    lda Ram_DeviceBlockCol_u8_arr, y
    .assert kMaxRoomWidthBlocks <= $80, error
    asl a      ; Since kMaxRoomWidthBlocks <= $80, the device block col fits in
    .repeat 3  ; seven bits, so the first ASL won't set the carry bit, so we
    asl a      ; only need to ROL the Ram_ActorPosX_i16_1 after the second ASL.
    rol Ram_ActorPosX_i16_1_arr, x
    .endrepeat
    adc #kTileWidthPx
    sta Ram_ActorPosX_i16_0_arr, x
    ;; Spawn the smoke.
    jsr Func_InitActorSmokeExplosion
    @done:
_PlaySound:
    jmp FuncA_Room_PlaySfxSpawnUpgrade
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
