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

;;; State bytes for minigun machines:
;;;   * State1: A counter that gets incremented every time the minigun fires a
;;;     shot.  Used to offset the lateral position of each bullet fired.
;;;   * State2: A counter that decrements each frame, and is set each time the
;;;     minigun fires a shot.  Used to animate the rotation of the minigun
;;;     barrel.
;;;   * State3: Unused.

;;; The size of a minigun machine's main platform, in pixels.
kMinigunMachineWidthPx  = $20
kMinigunMachineHeightPx = $10

;;; The CHR bank numbers containing the diagrams for minigun machines.
kChrBankDiagramMinigunDown  = $07
kChrBankDiagramMinigunLeft  = $08
kChrBankDiagramMinigunRight = $08
kChrBankDiagramMinigunUp    = $07

;;; BG tile IDs for minigun machine diagrams.
kTileIdBgDiagramMinigunDownFirst  = $f0
kTileIdBgDiagramMinigunLeftFirst  = $e0
kTileIdBgDiagramMinigunRightFirst = $f0
kTileIdBgDiagramMinigunUpFirst    = $e0

;;; Various OBJ tile IDs used for drawing minigun machines.
kTileIdObjMinigunHorzFirst = $d0
kTileIdObjMinigunVertFirst = $d8

;;;=========================================================================;;;
