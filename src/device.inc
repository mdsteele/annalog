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

;;;=========================================================================;;;

;;; Types of devices in a room.
.ENUM eDevice
    ;; Non-interactive device types; these generally act as temporary
    ;; placeholders for interactive devices.
    None           ; empty slot
    BreakerDone    ; circuit breaker, after being activated
    BreakerRising  ; circuit breaker, rising out of the ground
    FlowerInert    ; a flower that can't be picked
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
    ;;   * For levers, this is the byte offset into Zp_RoomState for the
    ;;     lever's state value (0 or 1).
    ;;   * For paper/sign/talk devices, this is the eDialog value.
    ;;   * For teleporters, this is the eRoom value for the destination room.
    ;;   * For upgrades, this is the eFlag::Upgrade* value.
    Target_u8    .byte
.ENDSTRUCT

;;;=========================================================================;;;
