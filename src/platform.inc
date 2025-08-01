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

;;; The maximum number of platforms that can exist at once in a room.
kMaxPlatforms = 16

;;;=========================================================================;;;

;;; Types of platform in a room.
.ENUM ePlatform
    None
    Zone   ; no physical interactions, just a region of the room
    Water  ; can swim in
    Solid  ; safe to stand on
    Spike  ; harmful on top and bottom, solid on sides
    Harm   ; harms the player avatar on contact (on all four sides)
    Kill   ; kills the player avatar on contact (on all four sides)
.ENDENUM

;;; Platform types greater than or equal to this are solid.
kFirstSolidPlatformType = ePlatform::Solid

;;; Platform types greater than or equal to this can harm or kill the player
;;; avatar on contact.
kFirstHarmfulPlatformType = ePlatform::Spike

;;;=========================================================================;;;

;;; Describes a platform's initial size and position.
.STRUCT sPlatform
    Type_ePlatform .byte
    ;; The width of the platform, in pixels.  Must be nonzero.
    WidthPx_u16    .word
    ;; The height of the platform, in pixels.  Must be nonzero.
    HeightPx_u8    .byte
    ;; The room pixel X-position of the left edge of the platform.
    Left_i16       .word
    ;; The room pixel Y-position of the top edge of the platform.
    Top_i16        .word
.ENDSTRUCT

;;;=========================================================================;;;
