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

;;; The initial value to set in Ram_DeviceAnim_u8_arr when animating various
;;; breaker devices.
.DEFINE kBreakerRisingDeviceAnimStart 63
kBreakerDoneDeviceAnimStart = 31

;;; The horizontal mod-16 offset within a breaker device's block that the
;;; player avatar should be positioned at when activing a breaker.
kBreakerAvatarOffset = $05

;;; OBJ tile IDs used for drawing breaker devices.
kTileIdObjBreakerFirst = $f0

;;;=========================================================================;;;
