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

;;; The device index, in teleporter rooms, for the Teleporter device where the
;;; player avatar should spawn when teleporting into the room.
kTeleporterDeviceIndex = 0

;;; How many frames the room shakes for during a full-power teleport zap.
kTeleportShakeFrames = 20

;;; The number of VBlank frames per animation shape of the teleporter zap
;;; effect.
.DEFINE kTeleportZapSlowdown 4

;;; The number of distinct animation shapes in the teleporter zap effect.
kTeleportZapNumAnimShapes = 6

;;; The number of VBlank frames to animate a teleporter zap, for either a full
;;; or partial zap.
kTeleporterAnimFull    = kTeleportZapSlowdown * kTeleportZapNumAnimShapes - 1
kTeleporterAnimPartial = kTeleportZapSlowdown * 4 - 1

;;;=========================================================================;;;
