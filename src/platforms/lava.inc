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

;;; The gap between the top of the lava terrain and the top of the lava
;;; platform, in pixels.
kLavaPlatformOffsetPx = 3

;;; The room pixel position for the top of the lava terrain in short/tall rooms
;;; with lava.
kLavaTerrainTopShortRoom = $d0
kLavaTerrainTopTallRoom = $160

;;; The room pixel position for the top of the lava platform in short/tall
;;; rooms with lava.
kLavaPlatformTopShortRoom = kLavaTerrainTopShortRoom + kLavaPlatformOffsetPx
kLavaPlatformTopTallRoom  = kLavaTerrainTopTallRoom  + kLavaPlatformOffsetPx

;;; The height of a lava platform, in pixels.
kLavaPlatformHeightPx = $20

;;; BG tiles used for animated lava terrain.
kTileIdBgAnimLavaFirst = $44

;;;=========================================================================;;;
