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
;;;   * Param: The initial flags to set (0 or bObj::FlipH).
;;;   * Flags: The bObj::FlipH bit is set if Gronta is facing left, or cleared
;;;     if she is facing right.
;;;   * State1: The eBadGronta value for Gronta's current behavior mode.
;;;   * State2: A timer for the current mode that increments or decrements each
;;;     frame, depending on the mode.
;;;   * State3: For JumpWindup and Running mode, this stores a bBadGronta value
;;;     encoding the goal delta or position.  For Injured, JumpAirborne,
;;;     SmashWindup, and SmashWaiting, this stores the machine index of the
;;;     machine to smash, or $ff for none.  For all other modes, this is
;;;     unused.
;;;   * State4: An signed invincibility timer.  When nonzero, Gronta cannot be
;;;     harmed.  When strictly positive, decrements each frame; when negative,
;;;     stays unchanged (keeping Gronta invincible indefinitely, until one of
;;;     her modes changes the value).

;;; State bytes for orc baddies:
;;;   * Param: The initial flags to set (0 or bObj::FlipH).
;;;   * Flags: The bObj::FlipH bit is set if the orc is facing left, or cleared
;;;     if they are facing right.
;;;   * State1: The eBadOrc value for the orc's current behavior mode.
;;;   * State2: A timer for the current mode that decrements each frame when
;;;     nonzero.
;;;   * State3: An animation counter that increments each frame (wrapping
;;;     around after 255).
;;;   * State4: Unused.

;;; State bytes for orc NPCs:
;;;   * Param: The initial eNpcOrc value to use.
;;;   * Flags: The bObj::FlipH bit is set if the orc is facing left, or cleared
;;;     if they are facing right.
;;;   * State1: The eNpcOrc value for the orc's current pose.
;;;   * State2: Boolean; If true ($ff), the NPC uses Ram_ActorFlags_bObj_arr
;;;     unchanged; if false ($00), the NPC is automatically drawn facing the
;;;     player avatar.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;;=========================================================================;;;

;;; The maximum number of blocks that a Gronta baddie actor can jump up by.
kBadGrontaMaxJumpUpBlocks = 2

;;; Possible values for a Gronta baddie actor's State1 byte.
.ENUM eBadGronta
    Idle          ; standing, waiting for a new mode to be set
    Injured       ; pausing briefly after getting hit
    JumpWindup    ; getting ready to jump
    JumpAirborne  ; airborne while jumping
    Running       ; running towards a goal position
    SmashWindup   ; getting ready to throw an axe at a machine
    SmashWaiting  ; waiting for the axe to destroy the machine
    ThrowWindup   ; getting ready to throw an axe at the player avatar
    ThrowWaiting  ; waiting for the axe to return
    ThrowCatch    ; catching a returned axe
    NUM_VALUES
.ENDENUM

;;; Describes a chasing action Gronta can perform.
.SCOPE bBadGronta
    IsRun        = %10000000  ; if set, run; if cleared, jump
    RunGoalMask  = %01111111  ; bits used for the running goal position
    JumpVertMask = %01110000  ; bits used for the jump's vertical offset
    JumpHorzMask = %00001111  ; bits used for the jump's horizontal offset
.ENDSCOPE

;;; Possible values for an orc baddie actor's State1 byte.
.ENUM eBadOrc
    Standing       ; standing guard
    Chasing        ; chasing the player avatar
    Patrolling     ; running to and fro after losing sight of the player avatar
    Punching       ; pausing for a short time after hitting the player avatar
    Jumping        ; jumping towards the player avatar
    TrapSurprised  ; surprised after being locked in a prison cell
    TrapRunning    ; running to the gate after being locked in a prison cell
    TrapPounding   ; pounding on the gate after being locked in a prison cell
    NUM_VALUES
.ENDENUM

;;; Possible values for an orc NPC actor's State1 byte.
.ENUM eNpcOrc
    ;; Non-Gronta (gray palette for head):
    GruntRunning1
    GruntRunning2
    GruntRunning3
    GruntRunning4
    GruntThrowing1
    GruntThrowing2
    GruntStanding
    GhostStanding
    ;; Gronta (red palette for head):
    GrontaRunning1
    GrontaRunning2
    GrontaRunning3
    GrontaRunning4
    GrontaArmsRaised
    GrontaCrouching
    GrontaJumping
    GrontaKneeling
    GrontaParley
    GrontaStanding
    GrontaThrowing
    EireneParley
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

;;; The gap, in pixels, between the center of an orc baddie and the gate in
;;; front of it when it is pounding while trapped.
kOrcTrappedDistance = 7

;;; Tile IDs for drawing orc baddie/NPC actors.
kTileIdObjOrcGhostFirst          = $d0
kTileIdObjOrcGrontaCrouchFirst   = $f0
kTileIdObjOrcGrontaJumpingFirst  = $c4
kTileIdObjOrcGrontaParleyFirst   = $9c
kTileIdObjOrcGrontaRunningFirst  = $b0
kTileIdObjOrcGrontaStandingFirst = $a0
kTileIdObjOrcGrontaThrowingFirst = $c0
kTileIdObjOrcGruntRunningFirst   = $b0
kTileIdObjOrcGruntStandingFirst  = $88
kTileIdObjOrcGruntThrowingFirst  = $c0
kTileIdObjEireneParleyFirst      = $90

;;;=========================================================================;;;
