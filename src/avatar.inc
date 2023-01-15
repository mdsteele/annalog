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

;;; How far the player avatar's bounding box extends in each direction from the
;;; avatar's position.
kAvatarBoundingBoxUp = 7
kAvatarBoundingBoxDown = 8
kAvatarBoundingBoxLeft = 5
kAvatarBoundingBoxRight = 5

;;;=========================================================================;;;

;;; How fast the player avatar is allowed to move, in subpixels per frame.
kAvatarMaxAirSpeedHorz   = $200
kAvatarMaxAirSpeedVert   = $500
kAvatarMaxWaterSpeedHorz = $100
kAvatarMaxWaterSpeedUp   = $200
kAvatarMaxWaterSpeedDown = $160

;;; The upward acceleration applied to the player avatar when in water, in
;;; subpixels per frame per frame.
kAvatarBouyancy = 20

;;; The downward acceleration applied to the player avatar when in midair, in
;;; subpixels per frame per frame.
.DEFINE kAvatarGravity 38

;;; How long it takes the player avatar to heal after taking damage, in frames.
kAvatarHarmHealFrames = 240

;;; How long the player avatar is stunned after taking damage, in frames.
kAvatarHarmStunFrames = 20

;;; How long the player avatar stays invincible after taking damage, in frames.
kAvatarHarmInvincibileFrames = 60

;;; If Zp_AvatarHarmTimer_u8 is set to this, then the avatar has been killed
;;; and we should go to death mode.
kAvatarHarmDeath = $ff
.ASSERT kAvatarHarmDeath > kAvatarHarmHealFrames, error

;;; The OBJ palette numbers to use for the player avatar.
kPaletteObjAvatarNormal = 1
kPaletteObjAvatarDeath  = 3

;;;=========================================================================;;;

;;; Modes that the player avatar can be in.  The number for each of these enum
;;; values is the starting tile ID to use for the avatar objects when the
;;; avatar is in that mode.
.ENUM eAvatar
    Standing  = $40  ; (grounded) standing still on the ground
    Looking   = $44  ; (grounded) standing still and looking upward
    Reaching  = $48  ; (grounded) standing still and reaching upward
    Straining = $4c  ; (grounded) standing still and reaching way upward
    Kneeling  = $50  ; (grounded) kneeling down on the ground
    Landing   = $54  ; (grounded) just landed from a jump
    Reading   = $58  ; (grounded) facing away from camera (e.g. to read a sign)
    Running1  = $5c  ; (grounded) running along the ground (1st frame)
    Running2  = $60  ; (grounded) running along the ground (2nd frame)
    Swimming1 = $64  ; (swimming) swimming in water (1st frame)
    Swimming2 = $68  ; (swimming) swimming in water (2nd frame)
    Jumping   = $6c  ; (airborne) jumping up
    Hovering  = $70  ; (airborne) mid-jump hang time
    Falling   = $74  ; (airborne) falling down
    Sleeping  = $78  ; (sleeping) lying down unconscious
.ENDENUM

;;;=========================================================================;;;
