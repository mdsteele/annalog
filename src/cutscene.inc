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
    ;; @begin SORTED
    CityCenterBreakerCity
    CityFlowerOrcAttack
    CityOutskirtsLook
    CoreBossFinaleReactivate
    CoreBossFinaleSelfDestruct
    CoreBossGrontaDefeated
    CoreBossPowerUpCircuit
    CoreBossStartBattle
    CoreLockBreakerShadow
    CoreSouthCorraHelping
    FactoryEastCorraHelping
    FactoryElevatorWaitUp
    FactoryVaultLookAtTank
    GardenShrineBreakerMine
    MermaidHut1AlexPetition
    MermaidHut1BreakerCrypt
    MermaidHut1BreakerGarden
    MermaidSpringFixConsole
    MermaidVillageAlexLeave
    PrisonCellGetThrownIn
    PrisonUpperBreakerTemple
    PrisonUpperFreeAlex
    PrisonUpperFreeKids
    PrisonUpperLoosenBrick
    PrisonUpperWaitUp
    SewerPoolFeedDucks
    SharedFlipBreaker
    SharedTeleportIn
    SharedTeleportOut
    TempleEntryWaitUp
    TempleNaveAlexBoosting
    TownHouse2WakeUp
    TownHouse4BreakerLava
    TownOutdoorsFinaleGaveRemote1
    TownOutdoorsFinaleGaveRemote3
    TownOutdoorsFinaleGaveRemote5
    TownOutdoorsFinaleReactivate1
    TownOutdoorsFinaleReactivate3
    TownOutdoorsFinaleReactivate5
    TownOutdoorsFinaleYearsLater
    TownOutdoorsGetCaught
    TownOutdoorsOrcAttack
    TownSkyFinaleGaveRemote2
    TownSkyFinaleGaveRemote4
    TownSkyFinaleGaveRemote6
    TownSkyFinaleReactivate2
    TownSkyFinaleReactivate4
    TownSkyFinaleReactivate6
    ;; @end SORTED
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; Flags to control which tick functions are called during a cutscene.
.SCOPE bCutscene
    RoomTick      = %10000000  ; if set, room's Tick_func_ptr gets called
    AvatarRagdoll = %01000000  ; if set, player avatar uses ragdoll physics
    TickAllActors = %00100000  ; if set, tick all actors, not just smoke
.ENDSCOPE

;;; Actions that can be executed during a cutscene.
.ENUM eAction
    ;; @begin SORTED
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
    ;; other cutscene forks are still executing.  The main is permitted to be
    ;; in PRGA_Cutscene.
    JumpToMain         ; args: main ptr (2 bytes)
    ;; Causes the player avatar to run/swim/walk to the specified room pixel
    ;; X-position.  Suspends the current cutscene fork until the avatar reaches
    ;; the goal position.
    MoveAvatarRun      ; args: goal X-position (2 bytes)
    MoveAvatarSwim     ; args: goal X-position (2 bytes)
    MoveAvatarWalk     ; args: goal X-position (2 bytes)
    ;; Causes the specified actor to swim/walk to the specified room pixel
    ;; X-position.  Suspends the current cutscene fork until the actor reaches
    ;; the goal position.
    MoveNpcAdultWalk   ; args: actor index, goal X-position (2 bytes)
    MoveNpcAlexSwim    ; args: actor index, goal X-position (2 bytes)
    MoveNpcAlexWalk    ; args: actor index, goal X-position (2 bytes)
    MoveNpcBrunoWalk   ; args: actor index, goal X-position (2 bytes)
    MoveNpcGrontaWalk  ; args: actor index, goal X-position (2 bytes)
    MoveNpcMarieWalk   ; args: actor index, goal X-position (2 bytes)
    MoveNpcNinaWalk    ; args: actor index, goal X-position (2 bytes)
    MoveNpcNoraWalk    ; args: actor index, goal X-position (2 bytes)
    MoveNpcOrcWalk     ; args: actor index, goal X-position (2 bytes)
    ;; Queues up the specified music/SFX to play next, then the current
    ;; cutscene fork immediately continues on to the next action.
    PlayMusic          ; args: eMusic value
    PlaySfxSample      ; args: eSample value
    ;; Suspends the current cutscene fork for the specified number of frames,
    ;; calling the specified function once each frame, with X set to the number
    ;; of times the function has already been called (so, ranging from zero
    ;; inclusive to num_frames exclusive).
    RepeatFunc         ; args: number of frames, func ptr (2 bytes)
    ;; Starts the specified dialog, and suspends *all* cutscene forks while the
    ;; dialog runs.  The cutscene will continue once the dialog is done.
    RunDialog          ; args: eDialog value
    ;; Slowly scrolls the screen to the specified scroll-X or scroll-Y
    ;; position, suspending the current fork until that scroll position is
    ;; reached.
    ScrollSlowX        ; args: scroll-X goal (2 bytes)
    ScrollSlowY        ; args: scroll-Y goal (1 byte)
    ;; Sets a field on the specified actor to the specified value, then the
    ;; current cutscene fork immediately continues on to the next action.
    SetActorFlags      ; args: actor index, new bObj value
    SetActorPosX       ; args: actor index, new X-position (2 bytes)
    SetActorPosY       ; args: actor index, new Y-position (2 bytes)
    SetActorState1     ; args: actor index, new byte value
    SetActorState2     ; args: actor index, new byte value
    SetActorState3     ; args: actor index, new byte value
    SetActorState4     ; args: actor index, new byte value
    SetActorVelX       ; args: actor index, new X-velocity (2 bytes)
    SetActorVelY       ; args: actor index, new Y-velocity (2 bytes)
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
    ;; Sets a field on the specified device to the specified value, then the
    ;; current cutscene fork immediately continues on to the next action.
    SetDeviceAnim      ; args: device index, new anim value
    ;; Sets the camera scroll flags, then the current cutscene fork immediately
    ;; continues on to the next action.
    SetScrollFlags     ; args: bScroll value
    ;; Shakes the room by the specified amount, then the current cutscene fork
    ;; immediately continues on to the next action.
    ShakeRoom          ; args: num shake frames
    ;; Suspends the current cutscene fork for the specified number of frames.
    WaitFrames         ; args: number of frames
    ;; Calls the specified function.  If the function clears C/Z, then the
    ;; current cutscene fork is suspended for one frame, and the function will
    ;; be called again next frame.  If the function sets C/Z, then the current
    ;; cutscene fork immediately continues on to the next action.
    WaitUntilC         ; args: func ptr (2 bytes); func must return C
    WaitUntilZ         ; args: func ptr (2 bytes); func must return Z
    ;; @end SORTED
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

.MACRO act_MoveAvatarRun GOALX
    .byte eAction::MoveAvatarRun
    .word GOALX
.ENDMACRO

.MACRO act_MoveAvatarSwim GOALX
    .byte eAction::MoveAvatarSwim
    .word GOALX
.ENDMACRO

.MACRO act_MoveAvatarWalk GOALX
    .byte eAction::MoveAvatarWalk
    .word GOALX
.ENDMACRO

.MACRO act_MoveNpcAdultWalk INDEX, GOALX
    .byte eAction::MoveNpcAdultWalk, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_MoveNpcAlexSwim INDEX, GOALX
    .byte eAction::MoveNpcAlexSwim, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_MoveNpcAlexWalk INDEX, GOALX
    .byte eAction::MoveNpcAlexWalk, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_MoveNpcBrunoWalk INDEX, GOALX
    .byte eAction::MoveNpcBrunoWalk, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_MoveNpcGrontaWalk INDEX, GOALX
    .byte eAction::MoveNpcGrontaWalk, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_MoveNpcMarieWalk INDEX, GOALX
    .byte eAction::MoveNpcMarieWalk, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_MoveNpcNinaWalk INDEX, GOALX
    .byte eAction::MoveNpcNinaWalk, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_MoveNpcNoraWalk INDEX, GOALX
    .byte eAction::MoveNpcNoraWalk, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_MoveNpcOrcWalk INDEX, GOALX
    .byte eAction::MoveNpcOrcWalk, INDEX
    .word GOALX
.ENDMACRO

.MACRO act_PlayMusic EMUSIC
    .byte eAction::PlayMusic
    .byte EMUSIC
.ENDMACRO

.MACRO act_PlaySfxSample ESAMPLE
    .byte eAction::PlaySfxSample
    .byte ESAMPLE
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

.MACRO act_ScrollSlowY GOALY
    .byte eAction::ScrollSlowY
    .byte GOALY
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

.MACRO act_SetActorState3 INDEX, BYTE
    .byte eAction::SetActorState3, INDEX, BYTE
.ENDMACRO

.MACRO act_SetActorState4 INDEX, BYTE
    .byte eAction::SetActorState4, INDEX, BYTE
.ENDMACRO

.MACRO act_SetActorVelX INDEX, VELX
    .byte eAction::SetActorVelX, INDEX
    .word $ffff & (VELX)
.ENDMACRO

.MACRO act_SetActorVelY INDEX, VELY
    .byte eAction::SetActorVelY, INDEX
    .word $ffff & (VELY)
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
    .word $ffff & (VELX)
.ENDMACRO

.MACRO act_SetAvatarVelY VELY
    .byte eAction::SetAvatarVelY
    .word $ffff & (VELY)
.ENDMACRO

.MACRO act_SetDeviceAnim INDEX, ANIM
    .byte eAction::SetDeviceAnim, INDEX, ANIM
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

;;;=========================================================================;;;
