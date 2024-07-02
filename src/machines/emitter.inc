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

;;; State bytes for emitter machines:
;;;   * Slowdown: Nonzero if the emitter beam is currently firing.
;;;   * GoalHorz: For EmitterX machines, this is the column (starting from the
;;;     left) that the beam will emit from.
;;;   * GoalVert: For EmitterY machines, this is the row (starting from the
;;;     top) that the beam will emit from.
;;;   * State1: The actual value (0-9) stored in the machine's X/Y register.
;;;   * State2: Unused.
;;;   * State3: Unused.

;;; The machine indices that must be used for emitter machines.
kEmitterXMachineIndex = 0
kEmitterYMachineIndex = 1

;;; The platform index for the forcefield created by emitter machines.
kEmitterForcefieldPlatformIndex = 0
;;; The platform index for the region that the forcefield can appear in.
kEmitterRegionPlatformIndex = 1

;;; The CHR bank numbers containing the diagrams for emitter machines.
kChrBankDiagramEmitterX = $13
kChrBankDiagramEmitterY = $13

;;; BG tile IDs for emitter machine diagrams.
kTileIdBgDiagramEmitterXFirst = $e0
kTileIdBgDiagramEmitterYFirst = $f0

;;; OBJ tile IDs used for drawing emitter machines.
kTileIdObjEmitterFirst = $82

;;; The OBJ tile ID for the indicator light on an emitter machine.
kTileIdObjEmitterLight = $81

;;;=========================================================================;;;
