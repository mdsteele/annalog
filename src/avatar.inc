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
kAvatarHarmInvincibleFrames = 60

;;; How many frames to blink the screen when the avatar is almost healed.
kAvatarHealBlinkFrames = 14

;;; If Zp_AvatarHarmTimer_u8 is set to this, then the avatar has been killed
;;; and we should go to death mode.
kAvatarHarmDeath = $ff
.ASSERT kAvatarHarmDeath > kAvatarHarmHealFrames, error

;;; The OBJ palette numbers to use for the player avatar.
kPaletteObjAvatarNormal = 1
kPaletteObjAvatarDeath  = 3

;;;=========================================================================;;;

;;; State bits for the player avatar.
.SCOPE bAvatar
    Airborne  = %10000000  ; if set, the avatar is in midair
    Swimming  = %01000000  ; if set, the avatar is in water
    Jumping   = %00100000  ; set during upward jump; release A button to slow
    DepthMask = %00011111  ; bits used for water depth
    LandMask  = %00011111  ; bits used for landing timer
.ENDSCOPE

;;;=========================================================================;;;

;;; Poses that the player avatar can be in.
.ENUM eAvatar
    Hidden     ; not drawn (e.g. for cutscenes)
    Standing   ; (grounded) standing still on the ground
    Looking    ; (grounded) standing still and looking upward
    Reaching   ; (grounded) standing still and reaching upward
    Straining  ; (grounded) standing still and reaching way upward
    Kneeling   ; (grounded) kneeling down on the ground
    Landing    ; (grounded) just landed from a jump
    Reading    ; (grounded) facing away from camera (e.g. to read a sign)
    Running1   ; (grounded) running along the ground (1st frame)
    Running2   ; (grounded) running along the ground (2nd and 4th frames)
    Running3   ; (grounded) running along the ground (3rd frame)
    Swimming1  ; (swimming) swimming in water (1st frame)
    Swimming2  ; (swimming) swimming in water (2nd frame)
    SwimDoor   ; (swimming) facing into a doorway while swimming
    Jumping    ; (airborne) jumping up
    Hovering   ; (airborne) mid-jump hang time
    Falling    ; (airborne) falling down
    Slumping   ; (sleeping) falling down unconscious
    Sleeping   ; (sleeping) lying down unconscious
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;
