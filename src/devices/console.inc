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

;;; The number of VBlank frames to animate a console that's powering up.
kConsoleAnimCountdown = 31

;;; The horizontal mod-16 offset within a console device's block that the
;;; player avatar should be positioned at when using a console.
kConsoleAvatarOffset = $06

;;; OBJ tile IDs used for drawing console devices.
kTileIdObjConsoleOk  = $08
kTileIdObjConsoleErr = $09
kTileIdObjScreen     = kTileIdObjConsoleOk

;;; OBJ palette numbers used for drawing console/screen devices.
kPaletteObjConsoleOk  = 2
kPaletteObjConsoleErr = 1
kPaletteObjScreen     = 1

;;;=========================================================================;;;
