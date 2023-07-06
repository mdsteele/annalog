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
kMaxDevices = 16

;;;=========================================================================;;;

;;; Types of devices in a room.
.ENUM eDevice
    ;; Non-interactive device types; these generally act as temporary
    ;; placeholders for interactive devices.
    None           ; empty slot
    BreakerDone    ; circuit breaker, after being activated
    BreakerRising  ; circuit breaker, rising out of the ground
    Door1Locked    ; leads to another Door1*; can't be entered until unlocked
    FlowerInert    ; a flower that can't be picked
    Mousehole      ; used by rodent baddies
    Placeholder    ; invisible and does nothing
    Teleporter     ; invisible spawn point for teleport field machines
    ;; Interactive device types.  The player can interact with these by
    ;; pressing the B button while standing in front of them.
    BreakerReady   ; circuit breaker, ready to be activated
    Console        ; operates a machine
    Door1Open      ; leads to another Door1*; is never locked
    Door1Unlocked  ; leads to another Door1*; can be locked by room scripts
    Door2Open      ; leads to another Door2*; is never locked
    Flower
    LeverCeiling
    LeverFloor
    Paper          ; initiates dialogue with the avatar's back to the camera
    Screen         ; initiates dialogue with the avatar's back to the camera
    Sign           ; initiates dialogue with the avatar's back to the camera
    TalkLeft       ; initiates dialogue with the avatar facing to the left
    TalkRight      ; initiates dialogue with the avatar facing to the right
    Upgrade
    NUM_VALUES
.ENDENUM

;;; eDevice values less than this represent device types that can't be used
;;; with the B button.
kFirstInteractiveDeviceType = eDevice::BreakerReady

;;;=========================================================================;;;

;;; Describes a nearby device (if any).
.SCOPE bDevice
    NoneNearby = %10000000  ; if set, other bits should be ignored
    Active     = %01000000  ; if set, the nearby device is being actively used
    IndexMask  = %00001111  ; bits used for the nearby device index
.ENDSCOPE

;;; Ensure that the bDevice index mask is wide enough to include any device
;;; index.
.ASSERT bDevice::IndexMask + 1 >= kMaxDevices, error

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
    ;;   * For mouseholes, this the bMousehole value.
    ;;   * For paper/screen/sign/talk devices, this is the eDialog value.
    ;;   * For teleporters, this is the eRoom value for the destination room.
    ;;   * For upgrades, this is the eFlag::Upgrade* value.
    Target_byte    .byte
.ENDSTRUCT

;;;=========================================================================;;;
