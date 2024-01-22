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

;;; State bytes for Gronta baddies:
;;;   * State1: The eBadGronta value for Gronta's current behavior mode.
;;;   * State2: A timer for the current mode that increments or decrements each
;;;     frame, depending on the mode.
;;;   * State3: For Running mode, this is the goal X-position, measured in room
;;;     tiles.
;;;   * State4: An invincibility timer; when nonzero, Gronta cannot be harmed,
;;;     and the timer decrements each frame.

;;; State bytes for orc baddies:
;;;   * State1: The eBadOrc value for the orc's current behavior mode.
;;;   * State2: A timer for the current mode that decrements each frame when
;;;     nonzero.
;;;   * State3: An animation counter that increments each frame (wrapping
;;;     around after 255).
;;;   * State4: Unused.

;;; State bytes for orc NPCs:
;;;   * Param: The initial eNpcOrc value to use.
;;;   * State1: The eNpcOrc value for the orc's current pose.
;;;   * State2: Boolean; If true ($ff), the NPC uses Ram_ActorFlags_bObj_arr
;;;     unchanged; if false ($00), the NPC is automatically drawn facing the
;;;     player avatar.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;;=========================================================================;;;

;;; Possible values for a Gronta baddie actor's State1 byte.
.ENUM eBadGronta
    Standing      ; standing, waiting for a new mode to be set
    Running       ; running towards a goal position
    Jumping       ; airborne while jumping
    ThrowWindup   ; winding up an axe throw
    ThrowWaiting  ; waiting for the axe to return
    ThrowCatch    ; catching a returned axe
    NUM_VALUES
.ENDENUM

;;; Possible values for an orc baddie actor's State1 byte.
.ENUM eBadOrc
    Standing  ; standing guard
    Chasing   ; chasing player avatar
    Pausing   ; pausing for a short time
    Jumping   ; jumping towards player avatar
    NUM_VALUES
.ENDENUM

;;; Possible values for an orc NPC actor's State1 byte.
.ENUM eNpcOrc
    ;; Non-Gronta (gray palette for head):
    GruntRunning1
    GruntRunning2
    GruntRunning3
    GruntRunning4
    GruntStanding
    GruntThrowing1
    GruntThrowing2
    GhostStanding
    ;; Gronta (red palette for head):
    GrontaRunning1
    GrontaRunning2
    GrontaRunning3
    GrontaRunning4
    GrontaArmsRaised
    GrontaJumping
    GrontaStanding
    GrontaThrowing
    NUM_VALUES
.ENDENUM

;;; eNpcOrc values greater than or equal to this are Gronta.
kNpcOrcFirstGronta = eNpcOrc::GrontaRunning1

;;; How far an orc actor's bounding box extends in each direction from the
;;; actor's center position.
kOrcBoundingBoxUp   = 17
kOrcBoundingBoxDown =  8
kOrcBoundingBoxSide =  6

;;; How fast an orc baddie can run/fall, in subpixels per frame.
kOrcMaxRunSpeed  = $0260
kOrcMaxFallSpeed = $0500

;;; The (signed, 16-bit) initial Y-velocity of an orc actor when jumping, in
;;; subpixels per frame.
kOrcJumpVelocity = $ffff & -600

;;; Tile IDs for drawing orc baddie/NPC actors.
kTileIdObjOrcGhostFirst          = $b0
kTileIdObjOrcGrontaJumpingFirst  = $c4
kTileIdObjOrcGrontaRunningFirst  = $b0
kTileIdObjOrcGrontaStandingFirst = $a0
kTileIdObjOrcGrontaThrowingFirst = $c0
kTileIdObjOrcGruntRunningFirst   = $b0
kTileIdObjOrcGruntStandingFirst  = $88
kTileIdObjOrcGruntThrowingFirst  = $c0

;;;=========================================================================;;;
