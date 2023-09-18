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
    CityFlowerOrcAttack
    CoreBossPowerUpCircuit
    CoreBossStartBattle
    CoreSouthCorraHelping
    MermaidHut1AlexPetition
    MermaidHut1BreakerCrypt
    MermaidHut1BreakerGarden
    MermaidVillageAlexLeave
    PrisonCellGetThrownIn
    PrisonUpperBreakerTemple
    PrisonUpperFreeAlex
    PrisonUpperFreeKids
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
    RoomTick      = %10000000  ; if set, room's Tick_func_ptr gets called
    AvatarRagdoll = %01000000  ; if set, player avatar uses ragdoll physics
.ENDSCOPE

;;; Actions that can be executed during a cutscene.
.ENUM eAction
    ;; Calls the specified function.  If the function clears C/Z, then the
    ;; current cutscene fork immediately continues on to the next action.  If
    ;; the function sets C/Z, then the current cutscene fork will immediately
    ;; start executing the specified sCutscene instead.
    BranchIfC          ; args: func ptr (2 bytes), sCutscene ptr (2 bytes)
    BranchIfZ          ; args: func ptr (2 bytes), sCutscene ptr (2 bytes)
    ;; Calls the specified function, then the current cutscene fork immediately
    ;; continues on to the next action.
    CallFunc           ; args: func ptr (2 bytes)
    ;; Ends the cutscene immediately, returning to explore mode, even if other
    ;; cutscene forks are still executing.
    ContinueExploring  ; args: (none)
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
    ;; Ends the cutscene immediately, jumping to the specified main, even if
    ;; other cutscene forks are still executing.
    JumpToMain         ; args: main ptr (2 bytes)
    ;; Queues up the specified music to play next, then the current cutscene
    ;; fork immediately continues on to the next action.
    PlayMusic          ; args: eMusic value
    ;; Suspends the current cutscene fork for the specified number of frames,
    ;; calling the specified function once each frame.
    RepeatFunc         ; args: number of frames, func ptr (2 bytes)
    ;; Starts the specified dialog, and suspends *all* cutscene forks while the
    ;; dialog runs.  The cutscene will continue once the dialog is done.
    RunDialog          ; args: eDialog value
    ;; Slowly scrolls the screen to the specified scroll-X position, suspending
    ;; the current fork until that scroll position is reached.
    ScrollSlowX        ; args: scroll-X goal (2 bytes)
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
    SetAvatarPosX      ; args: new X-position (2 bytes)
    SetAvatarPosY      ; args: new Y-position (2 bytes)
    SetAvatarPose      ; args: new eAvatar value
    SetAvatarState     ; args: new bAvatar value
    SetAvatarVelX      ; args: new X-velocity (2 bytes)
    SetAvatarVelY      ; args: new Y-velocity (2 bytes)
    ;; Sets the cutscene tick flags to the specified value, then the current
    ;; cutscene fork immediately continues on to the next action.
    SetCutsceneFlags   ; args: bCutscene value
    ;; Sets the camera scroll flags, then the current cutscene fork immediately
    ;; continues on to the next action.
    SetScrollFlags     ; args: bScroll value
    ;; Shakes the room by the specified amount, then the current cutscene fork
    ;; immediately continues on to the next action.
    ShakeRoom          ; args: num shake frames
    ;; Causes the specified actor to swim to the specified room pixel
    ;; X-position.  Suspends the current cutscene fork until the actor reaches
    ;; the goal position.
    SwimNpcAlex        ; args: actor index, goal X-position (2 bytes)
    ;; Suspends the current cutscene fork for the specified number of frames.
    WaitFrames         ; args: number of frames
    ;; Calls the specified function.  If the function clears C/Z, then the
    ;; current cutscene fork is suspended for one frame, and the function will
    ;; be called again next frame.  If the function sets C/Z, then the current
    ;; cutscene fork immediately continues on to the next action.
    WaitUntilC         ; args: func ptr (2 bytes); func must return C
    WaitUntilZ         ; args: func ptr (2 bytes); func must return Z
    ;; Causes the player avatar to walk to the specified room pixel X-position.
    ;; Suspends the current cutscene fork until the avatar reaches the goal
    ;; position.
    WalkAvatar         ; args: goal X-position (2 bytes)
    ;; Causes the specified actor to walk to the specified room pixel
    ;; X-position.  Suspends the current cutscene fork until the actor reaches
    ;; the goal position.
    WalkNpcAlex        ; args: actor index, goal X-position (2 bytes)
    WalkNpcBruno       ; args: actor index, goal X-position (2 bytes)
    WalkNpcNora        ; args: actor index, goal X-position (2 bytes)
    WalkNpcOrc         ; args: actor index, goal X-position (2 bytes)
    WalkNpcToddler     ; args: actor index, goal X-position (2 bytes)
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

.MACRO act_BranchIfC FUNC, SCUTSCENE
    .byte eAction::BranchIfC
    .addr FUNC
    .addr SCUTSCENE
.ENDMACRO

.MACRO act_BranchIfZ FUNC, SCUTSCENE
    .byte eAction::BranchIfZ
    .addr FUNC
    .addr SCUTSCENE
.ENDMACRO

.MACRO act_CallFunc FUNC
    .byte eAction::CallFunc
    .addr FUNC
.ENDMACRO

.MACRO act_ContinueExploring
    .byte eAction::ContinueExploring
.ENDMACRO

.MACRO act_ForkStart INDEX, SCUTSCENE
    .byte eAction::ForkStart, INDEX
    .addr SCUTSCENE
.ENDMACRO

.MACRO act_ForkStop INDEX
    .byte eAction::ForkStop, INDEX
.ENDMACRO

.MACRO act_JumpToMain MAIN
    .byte eAction::JumpToMain
    .addr MAIN
.ENDMACRO

.MACRO act_PlayMusic EMUSIC
    .byte eAction::PlayMusic
    .byte EMUSIC
.ENDMACRO

.MACRO act_RepeatFunc FRAMES, FUNC
    .byte eAction::RepeatFunc, FRAMES
    .addr FUNC
.ENDMACRO

.MACRO act_RunDialog EDIALOG
    .byte eAction::RunDialog, EDIALOG
.ENDMACRO

.MACRO act_ScrollSlowX GOALX
    .byte eAction::ScrollSlowX
    .word GOALX
.ENDMACRO

.MACRO act_SetActorFlags INDEX, BOBJ
    .byte eAction::SetActorFlags, INDEX, BOBJ
.ENDMACRO

.MACRO act_SetActorPosX INDEX, POSX
    .byte eAction::SetActorPosX, INDEX
    .word POSX
.ENDMACRO

.MACRO act_SetActorPosY INDEX, POSY
    .byte eAction::SetActorPosY, INDEX
    .word POSY
.ENDMACRO

.MACRO act_SetActorState1 INDEX, BYTE
    .byte eAction::SetActorState1, INDEX, BYTE
.ENDMACRO

.MACRO act_SetActorState2 INDEX, BYTE
    .byte eAction::SetActorState2, INDEX, BYTE
.ENDMACRO

.MACRO act_SetAvatarFlags BOBJ
    .byte eAction::SetAvatarFlags, BOBJ
.ENDMACRO

.MACRO act_SetAvatarPosX POSX
    .byte eAction::SetAvatarPosX
    .word POSX
.ENDMACRO

.MACRO act_SetAvatarPosY POSY
    .byte eAction::SetAvatarPosY
    .word POSY
.ENDMACRO

.MACRO act_SetAvatarPose EAVATAR
    .byte eAction::SetAvatarPose, EAVATAR
.ENDMACRO

.MACRO act_SetAvatarState BAVATAR
    .byte eAction::SetAvatarState, BAVATAR
.ENDMACRO

.MACRO act_SetAvatarVelX VELX
    .byte eAction::SetAvatarVelX
    .word VELX
.ENDMACRO

.MACRO act_SetAvatarVelY VELY
    .byte eAction::SetAvatarVelY
    .word VELY
.ENDMACRO

.MACRO act_SetCutsceneFlags BCUTSCENE
    .byte eAction::SetCutsceneFlags, BCUTSCENE
.ENDMACRO

.MACRO act_SetScrollFlags BSCROLL
    .byte eAction::SetScrollFlags, BSCROLL
.ENDMACRO

.MACRO act_ShakeRoom FRAMES
    .byte eAction::ShakeRoom, FRAMES
.ENDMACRO

.MACRO act_SwimNpcAlex INDEX, GOALX
    .byte eAction::SwimNpcAlex, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_WaitFrames FRAMES
    .byte eAction::WaitFrames, FRAMES
.ENDMACRO

.MACRO act_WaitUntilC FUNC
    .byte eAction::WaitUntilC
    .addr FUNC
.ENDMACRO

.MACRO act_WaitUntilZ FUNC
    .byte eAction::WaitUntilZ
    .addr FUNC
.ENDMACRO

.MACRO act_WalkAvatar GOALX
    .byte eAction::WalkAvatar
    .word GOALX
.ENDMACRO

.MACRO act_WalkNpcAlex INDEX, GOALX
    .byte eAction::WalkNpcAlex, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_WalkNpcBruno INDEX, GOALX
    .byte eAction::WalkNpcBruno, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_WalkNpcNora INDEX, GOALX
    .byte eAction::WalkNpcNora, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_WalkNpcOrc INDEX, GOALX
    .byte eAction::WalkNpcOrc, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_WalkNpcToddler INDEX, GOALX
    .byte eAction::WalkNpcToddler, INDEX
    .word GOALX
.ENDMACRO

;;;=========================================================================;;;
