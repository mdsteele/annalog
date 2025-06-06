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

;;; Settings for camera scrolling in explore mode.
.SCOPE bScroll
    LockHorz = %10000000  ; if set, horizontal scrolling is locked
    LockVert = %01000000  ; if set, vertical scrolling is locked
    LockMap  = %00100000  ; if set, the minimap won't be updated
.ENDSCOPE

;;; If the room shake has at least this many frames left, the shake amplitude
;;; is increased.
kBigShakeFrames = 17

;;; If the room shake has at least this many frames left, the shake amplitude
;;; is greatly increased.
kHugeShakeFrames = 41

;;;=========================================================================;;;
