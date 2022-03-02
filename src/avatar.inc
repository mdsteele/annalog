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

;;; Modes that the player avatar can be in.  The number for each of these enum
;;; values is the starting tile ID to use for the avatar objects when the
;;; avatar is in that mode.
.ENUM eAvatar
    Standing = $20  ; (grounded) standing still on the ground
    Looking  = $24  ; (grounded) standing still and looking upward
    Ducking  = $28  ; (grounded) crouching still on the ground
    Landing  = $2c  ; (grounded) just landed from a jump
    Reading  = $30  ; (grounded) facing away from camera (e.g. to read a sign)
    Running1 = $34  ; (grounded) running along the ground (1st frame)
    Running2 = $38  ; (grounded) running along the ground (2nd frame)
    Jumping  = $3c  ; (airborne) jumping up
    Floating = $40  ; (airborne) mid-jump hang time
    Falling  = $44  ; (airborne) falling down
.ENDENUM

;;; Any eAvatar modes greater than or equal to this are considered airborne.
kFirstAirborneAvatarMode = eAvatar::Jumping

;;;=========================================================================;;;
