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
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../oam.inc"
.INCLUDE "flower.inc"

.IMPORT FuncA_Avatar_PlaySfxPickUpFlower
.IMPORT FuncA_Objects_DrawShapeTiles
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT Func_IsFlagSet
.IMPORT Func_PlaySfxBreakFlower
.IMPORT Func_SaveProgress
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjAnnaFlower
.IMPORT Ppu_ChrObjAnnaNormal
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_CarryingFlower_eFlag
.IMPORTZP Zp_CarryingFlower_eFlag

;;;=========================================================================;;;

;;; The number of VBlank frames to animate a respawning flower.
kFlowerAnimCountdown = 48

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; If the player avatar is carrying a flower, breaks the flower.  Otherwise,
;;; does nothing.
;;; @preserve X, Y, T0+
.EXPORT Func_BreakFlowerIfAny
.PROC Func_BreakFlowerIfAny
    lda Zp_CarryingFlower_eFlag
    beq @done
    jsr Func_PlaySfxBreakFlower  ; preserves X, Y, and T0+
    main_chr10_bank Ppu_ChrObjAnnaNormal
    ;; Enable writes to SRAM.
    lda #bMmc3PrgRam::Enable
    sta Hw_Mmc3PrgRamProtect_wo
    ;; Mark Anna as no longer carrying a flower.  To prevent the human player
    ;; from resetting the NES to undo dropping the flower, also immediately
    ;; update the save file to remove the carried flower.  We don't need to
    ;; save other transient progress at this time; if the human player resets
    ;; the NES now, it will just undo their progress since the last save point,
    ;; except that Anna will not be carrying a flower, which is fine.
    lda #eFlag::None
    sta Zp_CarryingFlower_eFlag
    sta Sram_CarryingFlower_eFlag
    ;; Disable writes to SRAM.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Removes a flower device, and marks the player avatar as carrying that
;;; flower.
;;; @param X The device index for the flower.
.EXPORT FuncA_Avatar_PickUpFlowerDevice
.PROC FuncA_Avatar_PickUpFlowerDevice
    main_chr10_bank Ppu_ChrObjAnnaFlower
    ;; Set the currently-carried flower.
    lda Ram_DeviceTarget_byte_arr, x
    sta Zp_CarryingFlower_eFlag
    ;; Remove flower device (for now).
    lda #eDevice::Placeholder
    sta Ram_DeviceType_eDevice_arr, x
    jmp FuncA_Avatar_PlaySfxPickUpFlower
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Removes the carried flower (if any) and marks it as delivered, then saves
;;; the game.
.EXPORT FuncA_Dialog_DeliverFlowerAndSaveProgress
.PROC FuncA_Dialog_DeliverFlowerAndSaveProgress
    ;; If Anna is carrying a flower, mark it as delivered and remove it.
    ldx Zp_CarryingFlower_eFlag  ; param: flag
    .assert eFlag::None = 0, error
    beq @doneFlower
    jsr Func_SetFlag
    lda #eFlag::None
    sta Zp_CarryingFlower_eFlag
    main_chr10_bank Ppu_ChrObjAnnaNormal
    @doneFlower:
    jmp Func_SaveProgress
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; If the specified flower device's flower is currently being carried or has
;;; already been delivered, then changes the device into a placeholder.  This
;;; should be called from flower room Enter_func_ptr functions.
.EXPORT FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
.PROC FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
    ;; If this flower has already been delivered, remove the device.
    ldx Ram_DeviceTarget_byte_arr + kFlowerDeviceIndex  ; param: flower eFlag
    jsr Func_IsFlagSet  ; clears Z if flag is set
    bne _RemoveFlower
    ;; If the player avatar is not carrying any flower, keep the device.
    lda Zp_CarryingFlower_eFlag
    beq _KeepFlower
    ;; If the player avatar is carrying this flower, remove the device.
    cmp Ram_DeviceTarget_byte_arr + kFlowerDeviceIndex  ; flower eFlag
    beq _RemoveFlower
    ;; Otherwise, the player avatar must be carrying some other flower, in
    ;; which case we should make this room's flower non-interactive for now.
    lda #eDevice::FlowerInert
    sta Ram_DeviceType_eDevice_arr + kFlowerDeviceIndex
    rts
_RemoveFlower:
    lda #eDevice::Placeholder
    sta Ram_DeviceType_eDevice_arr + kFlowerDeviceIndex
_KeepFlower:
    rts
.ENDPROC

;;; If the specified placeholder device's flower is no longer being carried and
;;; hasn't been delivered, then changes the device type back to flower and
;;; animates the flower reappearing.  Does nothing if the device is already a
;;; flower.  This should be called from flower room tick functions.
.EXPORT FuncA_Room_RespawnFlowerDeviceIfDropped
.PROC FuncA_Room_RespawnFlowerDeviceIfDropped
    ;; If the player avatar is still carrying a flower, there's nothing to do.
    lda Zp_CarryingFlower_eFlag
    bne @done
    ;; If this device is already an interactive flower, there's nothing to do.
    lda Ram_DeviceType_eDevice_arr + kFlowerDeviceIndex
    cmp #eDevice::Flower
    beq @done
    ;; If this device is a non-interactive flower, make it interactive.
    cmp #eDevice::FlowerInert
    beq @makeIntoFlower
    ;; If the flower has already been delivered, don't respawn it.
    ldx Ram_DeviceTarget_byte_arr + kFlowerDeviceIndex  ; param: flower eFlag
    jsr Func_IsFlagSet  ; clears Z if flag is set
    bne @done
    ;; Respawn the flower.
    lda #kFlowerAnimCountdown
    sta Ram_DeviceAnim_u8_arr + kFlowerDeviceIndex
    @makeIntoFlower:
    lda #eDevice::Flower
    sta Ram_DeviceType_eDevice_arr + kFlowerDeviceIndex
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Shape tile data for drawing flower devices (and the dormant state of flower
;;; baddies).
.EXPORT DataA_Objects_FlowerShape_sShapeTile_arr
.PROC DataA_Objects_FlowerShape_sShapeTile_arr
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-4
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjFlowerBottom
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, <-8
    d_byte Flags_bObj, kPaletteObjFlowerTop | bObj::Final
    d_byte Tile_u8, kTileIdObjFlowerTop
    D_END
.ENDPROC

;;; Draws a flower device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceFlower
.PROC FuncA_Objects_DrawDeviceFlower
    lda Ram_DeviceAnim_u8_arr, x
    and #$02
    beq @draw
    rts
    @draw:
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile  ; preserves X
    ldya #DataA_Objects_FlowerShape_sShapeTile_arr  ; param: sShapeTile arr ptr
    jmp FuncA_Objects_DrawShapeTiles  ; preserves X
.ENDPROC

;;;=========================================================================;;;
