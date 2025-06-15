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

;;; State bytes for rocket launcher machines:
;;;   * Slowdown: Unused.
;;;   * State1: The number of rockets currently carried by the launcher machine
;;;     (0 or 1).
;;;   * State2: Unused.
;;;   * State3: Unused.

;;; The size of a launcher machine's main platform, in pixels.
kLauncherMachineWidthPx  = $10
kLauncherMachineHeightPx = $10

;;; The CHR bank numbers containing the diagrams for launcher machines.
kChrBankDiagramLauncherDown = $0c
kChrBankDiagramLauncherLeft = $0c

;;; BG tile IDs for launcher machine diagrams.
kTileIdBgDiagramLauncherDownFirst = $e0
kTileIdBgDiagramLauncherLeftFirst = $f0

;;; OBJ tile IDs used for drawing launcher machines.
kTileIdObjLauncherHorzFirst = $90
kTileIdObjLauncherVertFirst = $90

;;;=========================================================================;;;
