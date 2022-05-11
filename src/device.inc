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
kMaxDevices = 8

;;; The OBJ tile IDs used for various device objects.
kConsoleScreenTileIdOk  = $0a
kConsoleScreenTileIdErr = $0b
kFlowerTileIdTop        = $0c
kFlowerTileIdBottom     = $0d
kLeverHandleTileIdDown  = $0e
kLeverHandleTileIdUp    = $0f

;;; The OBJ palette numbers used for various device objects.
kConsoleScreenPaletteOk  = 2
kConsoleScreenPaletteErr = 1
kFlowerPaletteTop        = 1
kFlowerPaletteBottom     = 2
kLeverHandlePalette      = 0
kUpgradePalette          = 0

;;; The initial value to set in Ram_DeviceAnim_u8_arr when animating an upgrade
;;; device.
kUpgradeDeviceAnimStart = 23

;;;=========================================================================;;;

;;; Types of devices in a room that the player can interact with while standing
;;; in front.
.ENUM eDevice
    None
    Console
    Door
    Flower
    Lever
    Sign
    Upgrade
    NUM_VALUES
.ENDENUM

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
    ;;   * For consoles, this is the machine index (i.e. the index into the
    ;;     current room's sRoom::Machines_sMachine_arr_ptr).
    ;;   * For doors, this is the eRoom value for the destination room.
    ;;   * For levers, this is the byte offset into Ram_RoomState for the
    ;;     lever's state value (0 or 1).
    ;;   * For signs, this is the dialog index (i.e. the index into the current
    ;;     room's sRoomExt::Dialogs_sDialog_ptr_arr_ptr).
    ;;   * For upgrades, this is the eFlag value.
    Target_u8    .byte
.ENDSTRUCT

;;;=========================================================================;;;
