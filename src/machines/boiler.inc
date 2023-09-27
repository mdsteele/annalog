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
;;;   * State1: The current angle of valve #1, which tends toward
;;;     MachineGoalVert * kBoilerValveAnimSlowdown.
;;;   * State2: The current angle of valve #2, which tends toward
;;;     MachineGoalHorz * kBoilerValveAnimSlowdown.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; The number of frames between valve angles when animating a boiler valve.
.DEFINE kBoilerValveAnimSlowdown 2

;;; How many frames a boiler machine spends for various operations.
kBoilerActCountdown = 32

;;; Various OBJ tile IDs used for drawing boiler machines.
kTileIdObjValveFirst  = $9c

;;;=========================================================================;;;
