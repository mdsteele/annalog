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

;;; State bytes for rotor machines:
;;;   * State1: The current rotation angle for the rotor wheel (0-255).
;;;   * State2: Unused.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; The size of a rotor machine's main platform, in pixels.
kRotorMachineWidthPx  = $10
kRotorMachineHeightPx = $0d

;;; The size of a rotor carriage platform, in pixels.
kRotorCarriageWidthPx  = $10
kRotorCarriageHeightPx = $08

;;; The CHR bank number containing the diagram for rotor machines.
kChrBankDiagramRotor = $0f

;;; BG tile IDs for rotor machine diagrams.
kTileIdBgDiagramRotorFirst = $e0

;;; OBJ tile IDs used for drawing rotor machines.
kTileIdObjRotorFirst = $88

;;;=========================================================================;;;
