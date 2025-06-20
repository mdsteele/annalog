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

;;; State bytes for rocket reloader machines:
;;;   * Slowdown: Unused.
;;;   * State1: The number of rockets currently carried by the reloader machine
;;;     (0 or 1).
;;;   * State2: An animation timer for picking up ammo, which decrements each
;;;     frame when nonzero.
;;;   * State3: Unused.

;;; The size of a reloader machine's main platform, in pixels.
kReloaderMachineWidthPx  = $10
kReloaderMachineHeightPx = $10

;;; How many frames a realoder machine spends per ACT operation.
kReloaderActCountdown = 16

;;; The CHR bank number containing the diagram for reloader machines.
kChrBankDiagramReloader = $10

;;; BG tile IDs for reloader machine diagrams.
kTileIdBgDiagramReloaderFirst = $f0

;;; OBJ tile IDs used for drawing reloader machines.
kTileIdObjReloaderFirst = $86
kTileIdObjReloaderRocketVert = kTileIdObjReloaderFirst + 2

;;;=========================================================================;;;
