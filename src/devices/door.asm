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
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_Oam_sObj_arr64

;;;=========================================================================;;;

;;; The number of animation frames a door device has (i.e. the number of
;;; distinct ways of drawing it).
kDoorNumAnimFrames = 6
;;; The number of VBlank frames per door animation frame.
.DEFINE kDoorAnimSlowdown 2
;;; The number of VBlank frames for a complete door animation (i.e. the value
;;; to store in Ram_DeviceAnim_u8_arr when animating the door).
kDoorAnimCountdown = kDoorNumAnimFrames * kDoorAnimSlowdown - 1

;;; OBJ tile IDs used for drawing door devices.
kTileIdObjDoorwayFull = $3a
kTileIdObjDoorwayHalf = $3b

;;; The OBJ palette number used for drawing door devices.
kPaletteObjDoorway = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Locks a door device, if not locked already.
;;; @param X The device index for the (locked or unlocked) door.
;;; @preserve Zp_Tmp*
.EXPORT Func_LockDoorDevice
.PROC Func_LockDoorDevice
    lda #eDevice::LockedDoor
    cmp Ram_DeviceType_eDevice_arr, x
    beq @done
    sta Ram_DeviceType_eDevice_arr, x
    lda #kDoorAnimCountdown
    sub Ram_DeviceAnim_u8_arr, x
    sta Ram_DeviceAnim_u8_arr, x
    @done:
    rts
.ENDPROC

;;; Unlocks a door device, if not unlocked already.
;;; @param X The device index for the (locked or unlocked) door.
;;; @preserve Zp_Tmp*
.EXPORT Func_UnlockDoorDevice
.PROC Func_UnlockDoorDevice
    lda #eDevice::UnlockedDoor
    cmp Ram_DeviceType_eDevice_arr, x
    beq @done
    sta Ram_DeviceType_eDevice_arr, x
    lda #kDoorAnimCountdown
    sub Ram_DeviceAnim_u8_arr, x
    sta Ram_DeviceAnim_u8_arr, x
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a locked door device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawLockedDoorDevice
.PROC FuncA_Objects_DrawLockedDoorDevice
    lda Ram_DeviceAnim_u8_arr, x
    bne FuncA_Objects_DrawDoorDevice  ; preserves X
    rts
.ENDPROC

;;; Draws an unlocked door device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawUnlockedDoorDevice
.PROC FuncA_Objects_DrawUnlockedDoorDevice
    lda #kDoorAnimCountdown
    sub Ram_DeviceAnim_u8_arr, x
    .assert * = FuncA_Objects_DrawDoorDevice, error, "fallthrough"
.ENDPROC

;;; Draws a locked or unlocked door device.
;;; @param A The animation value, from 0 (open) to kDoorAnimCountdown (closed).
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawDoorDevice
    ;; Calculate the door animation frame, from 0 to kDoorNumAnimFrames - 1.
    div #kDoorAnimSlowdown
    beq _Done
    ;; Start drawing from the bottom of the doorway.
    pha  ; half-tiles
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    lda #kTileWidthPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    pla  ; half-tiles
_Loop:
    pha  ; half-tiles
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @continue
    pla  ; half-tiles
    pha  ; half-tiles
    cmp #2
    blt @half
    @full:
    lda #kTileIdObjDoorwayFull
    bne @setTileId  ; unconditional
    @half:
    lda #kTileIdObjDoorwayHalf
    @setTileId:
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjDoorway
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    jsr FuncA_Objects_MoveShapeUpOneTile
    pla  ; half-tiles
    sub #2
    blt _Done
    bne _Loop
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;
