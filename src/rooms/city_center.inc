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

;;; The number of digits in the combination key that must be transferred by
;;; semaphore.
.DEFINE kNumSemaphoreKeyDigits 10

;;; Defines shared room state data for the CityCenter and CityBuilding2 rooms.
.STRUCT sCityCenterState
    ;; The combination that must be entered into the lock to unlock the door.
    Key_u8_arr  .res kNumSemaphoreKeyDigits
    ;; For CityCenter only, the combination currently entered into the door.
    Lock_u8_arr .res kNumSemaphoreKeyDigits
    ;; For CityBuilding2 only, the number of digits that have stopped spinning
    ;; so far.
    NumDigitsSet_u8 .byte
    ;; For CityBuilding2 only, how many more frames until the next digit stops
    ;; spinning.
    SpinTimer_u8 .byte
.ENDSTRUCT

;;; OBJ tile IDs for drawing key combination digits.
kTileIdObjComboFirst = $9c

;;;=========================================================================;;;
