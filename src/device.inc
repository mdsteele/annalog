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
kConsoleScreenTileIdOk  = $08
kConsoleScreenTileIdErr = $09
kLeverHandleTileIdDown  = $1e
kLeverHandleTileIdUp    = $1f

;;;=========================================================================;;;

;;; Types of devices in a room that the player can interact with while standing
;;; in front.
.ENUM eDevice
    None
    Console
    Lever
    Sign
.ENDENUM

;;;=========================================================================;;;
