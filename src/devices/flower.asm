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
.INCLUDE "../mmc3.inc"
.INCLUDE "../oam.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT Func_IsFlagSet
.IMPORT Ppu_ChrObjAnnaFlower
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Sram_CarryingFlower_eFlag
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The number of VBlank frames to animate a respawning flower.
kFlowerAnimCountdown = 48

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Removes a flower device, and marks the player avatar as carrying that
;;; flower.
;;; @param X The device index for the flower.
.EXPORT Func_PickUpFlowerDevice
.PROC Func_PickUpFlowerDevice
    chr10_bank #<.bank(Ppu_ChrObjAnnaFlower)
    lda Ram_DeviceTarget_u8_arr, x
    ;; Enable writes to SRAM.
    ldy #bMmc3PrgRam::Enable
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Set the currently-carried flower.
    sta Sram_CarryingFlower_eFlag
    ;; Disable writes to SRAM.
    ldy #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Remove flower device (for now).
    lda #eDevice::Placeholder
    sta Ram_DeviceType_eDevice_arr, x
    rts
.ENDPROC

;;; If the specified flower device's flower is currently being carried or has
;;; already been delivered, then changes the device into a placeholder.  This
;;; should be called from room init functions.
;;; @param X The device index for the flower.
.EXPORT Func_RemoveFlowerDeviceIfCarriedOrDelivered
.PROC Func_RemoveFlowerDeviceIfCarriedOrDelivered
    ;; If the player avatar is carrying the flower, remove the device.
    lda Ram_DeviceTarget_u8_arr, x  ; flower eFlag value
    cmp Sram_CarryingFlower_eFlag
    beq @remove
    ;; If the flower has already been delivered, remove the device.
    stx Zp_Tmp1_byte  ; device index
    tax  ; param: eFlag value
    jsr Func_IsFlagSet  ; preserves Zp_Tmp*, clears Z if flag is set
    beq @done
    ldx Zp_Tmp1_byte  ; device index
    ;; Remove the device.
    @remove:
    lda #eDevice::Placeholder
    sta Ram_DeviceType_eDevice_arr, x
    @done:
    rts
.ENDPROC

;;; If the specified placeholder device's flower is no longer being carried and
;;; hasn't been delivered, then changes the device type back to flower and
;;; animates the flower reappearing.  Does nothing if the device is already a
;;; flower.  This should be called from room tick functions.
;;; @param X The device index for the flower.
.EXPORT Func_RespawnFlowerDeviceIfDropped
.PROC Func_RespawnFlowerDeviceIfDropped
    ;; If the device is already a flower, there's nothing to do.
    lda Ram_DeviceType_eDevice_arr, x
    cmp #eDevice::Flower
    beq @done
    ;; If the player avatar is carrying the flower, don't respawn it.
    lda Ram_DeviceTarget_u8_arr, x  ; flower eFlag value
    cmp Sram_CarryingFlower_eFlag
    beq @done
    ;; If the flower has already been delivered, don't respawn it.
    stx Zp_Tmp1_byte  ; device index
    tax  ; param: eFlag value
    jsr Func_IsFlagSet  ; preserves Zp_Tmp*, clears Z if flag is set
    bne @done
    ldx Zp_Tmp1_byte  ; device index
    ;; Respawn the flower.
    lda #eDevice::Flower
    sta Ram_DeviceType_eDevice_arr, x
    lda #kFlowerAnimCountdown
    sta Ram_DeviceAnim_u8_arr, x
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a flower device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawFlowerDevice
.PROC FuncA_Objects_DrawFlowerDevice
    lda Ram_DeviceAnim_u8_arr, x
    and #$02
    bne _Return
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
_AdjustPosition:
    ;; Adjust X-position for the flower.
    lda Zp_ShapePosX_i16 + 0
    add #4
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    adc #0
    sta Zp_ShapePosX_i16 + 1
_AllocateUpperObject:
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @done
    lda #kFlowerPaletteTop
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kFlowerTileIdTop
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
_AllocateLowerObject:
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @done
    lda #kFlowerPaletteBottom
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kFlowerTileIdBottom
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
_Return:
    rts
.ENDPROC

;;;=========================================================================;;;
