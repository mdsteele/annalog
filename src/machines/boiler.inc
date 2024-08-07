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

;;; State bytes for boiler machines:
;;;   * State1: The current angle of the valve, which tends toward
;;;     MachineGoalHorz * kBoilerValveAnimSlowdown.
;;;   * State2: A cooldown timer for drawing the ignition flame.
;;;   * State3: Unused.

;;; The number of frames between valve angles when animating a boiler valve.
.DEFINE kBoilerValveAnimSlowdown 4

;;; The CHR bank number containing the diagram for boiler machines.
kChrBankDiagramBoiler = $0e

;;; BG tile IDs for boiler machine diagrams.
kTileIdBgDiagramBoilerFirst = $e0

;;; Various OBJ tile IDs used for drawing boiler machines.
kTileIdObjBoilerFlameFirst = $8c
kTileIdObjValveFirst       = $bb

;;;=========================================================================;;;
