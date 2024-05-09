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

;;; State bytes for blaster machines:
;;;   * Slowdown: Unused.
;;;   * State1: The relative goal angle for the mirrors, in increments of
;;;     tau/16.
;;;   * State2: Unused.
;;;   * State3: The current animation angle for the mirrors, which ticks each
;;;     frame toward (State1 * kBlasterMirrorAnimSlowdown).

;;; The size of a blaster machine's main platform, in pixels.
kBlasterMachineWidthPx  = $10
kBlasterMachineHeightPx = $10

;;; The number of frames between mirror angles when animating a blaster mirror.
.DEFINE kBlasterMirrorAnimSlowdown 2

;;; The CHR bank number containing the diagram for blaster machines.
kChrBankDiagramBlaster = $0f

;;; BG tile IDs for blaster machine diagrams.
kTileIdBgDiagramBlasterFirst = $f0

;;; OBJ tile IDs used for drawing blaster machines.
kTileIdObjBlasterFirst = $98
kTileIdObjMirrorFirst  = $d0

;;;=========================================================================;;;
