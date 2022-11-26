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

;;; For this game, the "window" refers to the bottom portion of the lower
;;; nametable, which we use HBlank IRQs to scroll into view from the bottom of
;;; the screen.

;;;=========================================================================;;;

;;; The nametable tile row (of the lower nametable) that the window starts on.
kWindowStartRow = 19

;;; The largest number of tile rows that we ever draw to the window.
kWindowMaxNumRows = 11

;;; How many pixels of blank space we keep between the bottom of the window's
;;; bottom border and the bottom of the screen.  This margin should be at least
;;; 12 pixels to avoid any of the window border being hidden by TV overscan
;;; (see https://wiki.nesdev.org/w/index.php/Overscan).  However, it must be
;;; less than 16 pixels in order to prevent the explore mode scroll-Y from
;;; leaving the upper nametable when the window is fully open and the player is
;;; at the bottom of a tall room.
kWindowMarginBottomPx = 12

;;; Tile IDs for drawing pieces of the window border.
kWindowTileIdBlank       = $00
kWindowTileIdTopLeft     = $3a
kWindowTileIdTopRight    = $3b
kWindowTileIdBottomLeft  = $3c
kWindowTileIdBottomRight = $3d
kWindowTileIdHorz        = $3e
kWindowTileIdVert        = $3f

;;;=========================================================================;;;
