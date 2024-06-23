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

;;; How many bullets must hit a breakable glass tank platform to destroy it.
kNumHitsToBreakGlass = 4

;;; How many frames to blink a breakable glass tank platform for when resetting
;;; it.
kBreakableGlassBlinkFrames = 28

;;; The size of a glass tank platform, in pixels.
kGlassPlatformWidthPx  = $08
kGlassPlatformHeightPx = $10

;;; OBJ tile IDs for drawing glass tank platforms.
kTileIdObjGlassFirst = $80

;;;=========================================================================;;;
