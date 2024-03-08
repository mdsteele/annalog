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

;;; State bytes for semaphore machines:
;;;   * GoalHorz: The current array index for lock combination input/output.
;;;   * GoalVert: The vertical goal position for the movable actuator (0 or 1).
;;;   * State1: The current bSemaphoreFlag state for the lower flag.
;;;   * State2: The current bSemaphoreFlag state for the upper flag.
;;;   * State3: The current upward vertical offset of the movable actuator, in
;;;     pixels (0-16).
;;;   * State4: Unused.

;;; The number of digits in the combination key that must be transferred by
;;; semaphore.
.DEFINE kNumSemaphoreKeyDigits 5

;;; The CHR bank numbers containing the diagrams for semaphore machines.
kChrBankDiagramSemaphoreComm = $0a
kChrBankDiagramSemaphoreKey  = $0b
kChrBankDiagramSemaphoreLock = $0b

;;; BG tile IDs for semaphore machine diagrams.
kTileIdBgDiagramSemaphoreCommFirst = $f0
kTileIdBgDiagramSemaphoreKeyFirst  = $e0
kTileIdBgDiagramSemaphoreLockFirst = $f0

;;; OBJ tile IDs used for drawing semaphore machines.
kTileIdObjSemaphoreFirst = $80

;;;=========================================================================;;;

;;; State bits for one flag of a semaphore machine.
.SCOPE bSemaphoreFlag
    MoveOut   = %10000000  ; if set, the flag is moving out rather than in
    AngleMask = %00001111  ; bits used for the flag's angle (0=in to 15=out)
.ENDSCOPE

;;;=========================================================================;;;
