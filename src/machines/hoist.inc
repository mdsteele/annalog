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

;;; State bytes for hoist machines:
;;;   * State1: Unused.
;;;   * State2: Unused.
;;;   * State3: Unused.

;;; The size of a hoist machine's main platform, in pixels.
kHoistMachineWidthPx  = $10
kHoistMachineHeightPx = $10

;;; The CHR bank numbers containing the diagrams for hoist machines.
kChrBankDiagramHoistLeft  = $05
kChrBankDiagramHoistRight = $05

;;; BG tile IDs for hoist machine diagrams.
kTileIdBgDiagramHoistLeftFirst  = $e0
kTileIdBgDiagramHoistRightFirst = $f0

;;; Tile IDs for drawing hoist machines.
kTileIdObjMachineHoistKnot      = $81
kTileIdObjMachineHoistRopeFirst = $84
kTileIdObjMachineHoistPulley    = kTileIdObjMachineHoistRopeFirst + 0
kTileIdObjMachineHoistSpindle   = kTileIdObjMachineHoistRopeFirst + 1
kTileIdObjMachineHoistRopeDiag  = kTileIdObjMachineHoistRopeFirst + 2
kTileIdObjMachineHoistRopeVert  = kTileIdObjMachineHoistRopeFirst + 3

;;; The OBJ palette number to use for drawing hoist ropes.
kPaletteObjMachineHoistRope = 0

;;;=========================================================================;;;
