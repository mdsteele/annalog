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

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightHalfTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr

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
kTileIdObjDoorwayFull = $06
kTileIdObjDoorwayHalf = $07

;;; The OBJ palette number used for drawing door devices.
kPaletteObjDoorway = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Locks a door device, if not locked already.
;;; @param X The device index for the (locked or unlocked) door.
;;; @preserve T0+
.EXPORT FuncA_Room_LockDoorDevice
.PROC FuncA_Room_LockDoorDevice
    lda #eDevice::Door1Locked  ; param: new device type
    .assert eDevice::Door1Unlocked > 0, error
    bne FuncA_Room_LockOrUnlockDoorDevice  ; unconditional; preserves T0+
.ENDPROC

;;; Unlocks a door device, if not unlocked already.
;;; @param X The device index for the (locked or unlocked) door.
;;; @preserve T0+
.EXPORT FuncA_Room_UnlockDoorDevice
.PROC FuncA_Room_UnlockDoorDevice
    lda #eDevice::Door1Unlocked  ; param: new device type
    fall FuncA_Room_LockOrUnlockDoorDevice  ; preserves T0+
.ENDPROC

;;; Locks or unlocks a door device, if not already in the desired state.
;;; @param A The device type to change to (Door1Locked or Door1Unlocked).
;;; @param X The device index for the door.
;;; @preserve T0+
.PROC FuncA_Room_LockOrUnlockDoorDevice
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
.EXPORT FuncA_Objects_DrawDeviceLockedDoor
.PROC FuncA_Objects_DrawDeviceLockedDoor
    lda Ram_DeviceAnim_u8_arr, x
    bne FuncA_Objects_DrawDeviceDoor  ; preserves X
    rts
.ENDPROC

;;; Draws an unlocked door device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceUnlockedDoor
.PROC FuncA_Objects_DrawDeviceUnlockedDoor
    lda #kDoorAnimCountdown
    sub Ram_DeviceAnim_u8_arr, x
    fall FuncA_Objects_DrawDeviceDoor
.ENDPROC

;;; Draws a locked or unlocked door device.
;;; @param A The animation value, from 0 (open) to kDoorAnimCountdown (closed).
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawDeviceDoor
    ;; Calculate the door animation frame, from 0 to kDoorNumAnimFrames - 1.
    div #kDoorAnimSlowdown
    beq _Done
    ;; Start drawing from the bottom of the doorway.
    pha  ; half-tiles
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X and T0+
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X and T0+
    jsr FuncA_Objects_MoveShapeRightHalfTile  ; preserves X and T0+
    pla  ; half-tiles
_Loop:
    pha  ; half-tiles
    cmp #2
    blt @half
    @full:
    lda #kTileIdObjDoorwayFull  ; param: tile ID
    bne @draw  ; unconditional
    @half:
    lda #kTileIdObjDoorwayHalf  ; param: tile ID
    @draw:
    ldy #kPaletteObjDoorway  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X and T0+
    pla  ; half-tiles
    sub #2
    blt _Done
    bne _Loop
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;
