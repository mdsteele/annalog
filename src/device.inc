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

;;; The maximum number of devices that can exist at once in a room.
kMaxDevices = 12

;;; The OBJ tile IDs used for various device objects.
kTileIdBreakerFirst     = $f0
kConsoleScreenTileIdOk  = $0a
kConsoleScreenTileIdErr = $0b
kTileIdDoorwayFull      = $3a
kTileIdDoorwayHalf      = $3b
kFlowerTileIdTop        = $0c
kFlowerTileIdBottom     = $0d
kTileIdPaper            = $06

;;; The OBJ palette numbers used for various device objects.
kBreakerPalette          = 0
kConsoleScreenPaletteOk  = 2
kConsoleScreenPaletteErr = 1
kDoorwayPalette          = 0
kFlowerPaletteTop        = 1
kFlowerPaletteBottom     = 2
kPaperPalette            = 0
kUpgradePalette          = 0

;;; The initial value to set in Ram_DeviceAnim_u8_arr when animating various
;;; devices.
kBreakerRisingDeviceAnimStart = 63
kBreakerDoneDeviceAnimStart = 31
kUpgradeDeviceAnimStart = 23

;;; The horizontal mod-16 offset within a breaker device's block that the
;;; player avatar should be positioned at when activing a breaker.
kBreakerAvatarOffset = $05

;;;=========================================================================;;;

;;; Types of devices in a room.
.ENUM eDevice
    ;; Non-interactive device types; these generally act as temporary
    ;; placeholders for interactive devices.
    None           ; empty slot
    BreakerDone    ; circuit breaker, after being activated
    BreakerRising  ; circuit breaker, rising out of the ground
    LockedDoor
    Placeholder    ; invisible and does nothing
    Teleporter     ; invisible spawn point for teleport field machines
    ;; Interactive device types.  The player can interact with these by
    ;; pressing the B button while standing in front of them.
    BreakerReady   ; circuit breaker, ready to be activated
    Console
    Flower
    LeverCeiling
    LeverFloor
    OpenDoorway
    Paper          ; initiate dialogue with the avatar's back to the camera
    Sign           ; initiate dialogue with the avatar's back to the camera
    TalkLeft       ; initiate dialogue with the avatar facing to the left
    TalkRight      ; initiate dialogue with the avatar facing to the right
    UnlockedDoor
    Upgrade
    NUM_VALUES
.ENDENUM

;;; eDevice values less than this represent device types that can't be used
;;; with the B button.
kFirstInteractiveDeviceType = eDevice::BreakerReady

;;;=========================================================================;;;

;;; Static information about a given device.
.STRUCT sDevice
    ;; The type of this device.
    Type_eDevice .byte
    ;; The room block row for this device.
    BlockRow_u8  .byte
    ;; The room block column for this device.
    BlockCol_u8  .byte
    ;; The "target" for this device, whose meaning depends on the device type:
    ;;   * For breakers, this is the eFlag::Breaker* value.
    ;;   * For consoles, this is the machine index (i.e. the index into the
    ;;     current room's sRoom::Machines_sMachine_arr_ptr).
    ;;   * For doors, this is the eRoom value for the destination room.
    ;;   * For flowers, this is the eFlag::Flower* value.
    ;;   * For levers, this is the byte offset into Ram_RoomState for the
    ;;     lever's state value (0 or 1).
    ;;   * For paper/sign/talk devices, this is the dialog index (i.e. the
    ;;     index into the room's sRoomExt::Dialogs_sDialog_ptr_arr_ptr).
    ;;   * For teleporters, this is the eRoom value for the destination room.
    ;;   * For upgrades, this is the eFlag::Upgrade* value.
    Target_u8    .byte
.ENDSTRUCT

;;;=========================================================================;;;
