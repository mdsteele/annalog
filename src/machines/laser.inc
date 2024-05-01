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

;;; State bytes for laser machines:
;;;   * Slowdown: The number of frames remaining for the laser beam, or zero if
;;;     no laser beam is currently being fired.
;;;   * State1: The color setting of the laser (0-9).  If even, the laser beam
;;;     will be red; if odd, the laser beam will be green.
;;;   * State2: The lo byte of the Y-position for the bottom of the laser beam.
;;;   * State3: The hi byte of the Y-position for the bottom of the laser beam.

;;; The size of a laser machine's main platform, in pixels.
kLaserMachineWidthPx  = $10
kLaserMachineHeightPx = $0f

;;; The CHR bank number containing the diagram for laser machines.
kChrBankDiagramLaser = $0e

;;; BG tile IDs for laser machine diagrams.
kTileIdBgDiagramLaserFirst = $f0

;;; The first tile ID use for drawing laser machines.
kTileIdObjLaserFirst = $dc

;;;=========================================================================;;;
