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

;;; State bytes for mermaid/orc ghost baddies:
;;;   * Param: The initial eBadGhost value to set for State1.
;;;   * Flags: The bObj::FlipH bit is set if the ghost is facing left, or
;;;     cleared if it is facing right.
;;;   * State1: The eBadGhost value for the ghost's current behavior mode.
;;;   * State2: A timer for the current mode that increments or decrements each
;;;     frame, depending on the mode.
;;;   * State3: A mode-specific counter (e.g. how many more times to move, or
;;;     how many more fireballs to shoot).
;;;   * State4: Unused.

;;;=========================================================================;;;

;;; Possible values for a ghost baddie actor's State1 byte.
.ENUM eBadGhost
    Absent            ; invisible, waiting for a new mode to be set
    ;; Appearing/disappearing modes (ghost flickers, and cannot be injured):
    AppearForAttack   ; reappearing; will become AttackShooting
    AppearForMerge    ; reappearing; will become Absent
    AppearForSpecial  ; reappearing; will become SpecialMoving
    Disappearing      ; disappearing; will become Absent
    ;; Injured modes (ghost flashes, and cannot be injured):
    Injured           ; flashing red; will become Disappearing
    ;; Vulnerable modes (ghost is solid gray, and can be injured):
    AttackMoving      ; moving; will become Disappearing
    AttackShooting    ; shooting fire; will become AttackMoving
    SpecialMoving     ; moving offscreen as part of a special attack
    SpecialWaiting    ; a short delay between appearing and a special attack
    NUM_VALUES
.ENDENUM

;;; eBadGhost values less this represent states where the ghost is absent,
;;; disappearing, or reappearing, and should thus be drawn flickering (if at
;;; all).
kBadGhostFirstSolid = eBadGhost::Injured

;;; eBadGhost values less than this represent states where the ghost is
;;; invincible and cannot be injured.
kBadGhostFirstVulnerable = eBadGhost::AttackMoving

;;;=========================================================================;;;
