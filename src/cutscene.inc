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

;;; A sCutscene struct is a variable-length sequence of one or more actions,
;;; where each action consists of an eAction byte followed by zero or more arg
;;; bytes (depending on the eAction value).
;;;
;;; A cutscene can have up to kMaxForks concurrent forks of execution.  When a
;;; cutscene starts, fork 0 (the "main" fork) starts executing the cutscene,
;;; and all other forks are initially halted.  The other forks can be started
;;; and stopped throughout the cutscene; if the main fork is ever stopped, then
;;; the cutscene immediately ends and the game will return to explore mode.
;;; During each frame, each fork executes in order (starting with fork 0),
;;; switching to the next fork only once it reaches an action that suspends the
;;; fork for one or more frames.

;;; The maximum number of cutscene forks, including the main fork.
kMaxForks = 4

;;;=========================================================================;;;

;;; The list of cutscenes in the game.
.ENUM eCutscene
    None
    CoreBossPowerUpCircuit
    MermaidHut1BreakerGarden
    PrisonCellGetThrownIn
    PrisonUpperBreakerTemple
    SharedFadeBackToBreakerRoom  ; TODO: get rid of this
    SharedTeleportIn
    SharedTeleportOut
    TempleNaveAlexBoosting
    TownHouse2WakeUp
    TownOutdoorsGetCaught
    TownOutdoorsOrcAttack
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; Flags to control which tick functions are called during a cutscene.
.SCOPE bCutscene
    AvatarRagdoll = %01000000  ; if set, player avatar uses ragdoll physics
.ENDSCOPE

;;; Actions that can be executed during a cutscene.
.ENUM eAction
    ;; Ends the cutscene immediately, returning to explore mode, even if other
    ;; cutscene forks are still executing.
    ContinueExploring  ; args: (none)
    ;; Ends the cutscene immediately, jumping to the specified main, even if
    ;; other cutscene forks are still executing.
    JumpToMain         ; args: main ptr (2 bytes)
    ;; Sets the specified cutscene fork to start executing the specified
    ;; sCutscene struct, then the current fork immediately continues on to the
    ;; next action.  If the current fork performs a ForkStart on itself, it
    ;; will immediately start executing the new sCutscene.
    ForkStart          ; args: fork index, sCutscene ptr (2 bytes)
    ;; Halts the specified cutscene fork.  If the main fork is halted, the
    ;; cutscene ends immediately, returning to explore mode, even if other
    ;; forks are still executing.  Otherwise, if the halted fork wasn't the
    ;; current fork, then the current fork immediately continues on to the next
    ;; action.
    ForkStop           ; args: fork index (or $ff for current fork)
    ;; Calls the specified function, then the current cutscene fork immediately
    ;; continues on to the next action.
    CallFunc           ; args: func ptr (2 bytes)
    ;; Sets a field on the specified actor to the specified value, then the
    ;; current cutscene fork immediately continues on to the next action.
    SetActorFlags      ; args: actor index, new bObj value
    SetActorPosX       ; args: actor index, new X-position (2 bytes)
    SetActorPosY       ; args: actor index, new Y-position (2 bytes)
    SetActorState1     ; args: actor index, new byte value
    SetActorState2     ; args: actor index, new byte value
    ;; Sets a field on the player avatar to the specified value, then the
    ;; current cutscene fork immediately continues on to the next action.
    SetAvatarFlags     ; args: new bObj value
    SetAvatarPose      ; args: new eAvatar value
    ;; Sets the cutscene tick flags to the specified value, then the current
    ;; cutscene fork immediately continues on to the next action.
    SetCutsceneFlags   ; args: bCutscene value
    ;; Shakes the room by the specified amount, then the current cutscene fork
    ;; immediately continues on to the next action.
    ShakeRoom          ; args: num shake frames
    ;; Starts the specified dialog, and suspends *all* cutscene forks while the
    ;; dialog runs.  The cutscene will continue once the dialog is done.
    RunDialog          ; args: eDialog value
    ;; Suspends the current cutscene fork for the specified number of frames.
    WaitFrames         ; args: number of frames
    ;; Calls the specified function.  If the function clears C/Z, then the
    ;; current cutscene fork is suspended for one frame, and the function will
    ;; be called again next frame.  If the function sets C/Z, then the current
    ;; cutscene fork immediately continues on to the next action.
    WaitUntilC         ; args: func ptr (2 bytes); func must return C
    WaitUntilZ         ; args: func ptr (2 bytes); func must return Z
    ;; Causes the specified actor to walk to the specified room pixel
    ;; X-position.  Suspends the current cutscene fork until the actor reaches
    ;; the goal position.
    WalkAlex           ; args: actor index, goal X-position (2 bytes)
    WalkNpcOrc         ; args: actor index, goal X-position (2 bytes)
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;
