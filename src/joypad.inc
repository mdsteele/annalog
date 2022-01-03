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

;;; Player 1 controller data.  Write #1 here to populate the shift registers
;;; for *both* controllers, then write zero here to allow subsequently reading
;;; one bit at a time from each of Hw_Joypad1_rw and Hw_Joypad2_ro. See
;;; https://wiki.nesdev.org/w/index.php/Standard_controller for details.
Hw_Joypad1_rw = $4016

;;; Player 2 controller data.
Hw_Joypad2_ro = $4017

;;;=========================================================================;;;

.SCOPE bJoypad
    AButton = %10000000
    BButton = %01000000
    Select  = %00100000
    Start   = %00010000
    Up      = %00001000
    Down    = %00000100
    Left    = %00000010
    Right   = %00000001
.ENDSCOPE

;;;=========================================================================;;;
