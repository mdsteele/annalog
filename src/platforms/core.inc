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

;;; The number of VBlank frames per pixel moved when a core platform is rising.
.DEFINE kCorePlatformSlowdown 4

;;; Platform indices for various parts of the core.
kFinalTerminalPlatformIndex = 0
kCoreInnerPlatformIndex     = 1
kCoreOuterPlatformIndex     = 2

;;; The width of each core platform.
kCoreInnerPlatformWidthTiles = 6
kCoreOuterPlatformWidthTiles = 8
kCoreInnerPlatformWidthPx = $30
kCoreOuterPlatformWidthPx = $40

;;; OBJ tile IDs for drawing power core platforms.
kTileIdObjPlatformCoreFirst = $80

;;;=========================================================================;;;
