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

;;; The list of cutscenes in the game.
.ENUM eCutscene
    None
    CoreBossPowerUpCircuit
    MermaidHut1BreakerGarden
    PrisonCellGetThrownIn
    SharedFadeBackToBreakerRoom  ; TODO: get rid of this
    SharedTeleportIn
    SharedTeleportOut
    TempleNaveAlexBoosting
    TownHouse2WakeUp
    TownOutdoorsGetCaught
    TownOutdoorsOrcAttack
    NUM_VALUES
.ENDENUM

;;; Flags to control which tick functions are called during a cutscene.
.SCOPE bCutscene
    AvatarRagdoll = %01000000  ; if set, player avatar uses ragdoll physics
.ENDSCOPE

;;; Actions that can be executed during a cutscene.
.ENUM eAction
    ;; Terminal actions:
    ContinueExploring  ; args: (none)
    JumpToMain         ; args: main ptr (2 bytes)
    ;; Zero-frame actions:
    CallFunc           ; args: func ptr (2 bytes)
    SetActorFlags      ; args: actor index, new bObj value
    SetActorState1     ; args: actor index, new byte value
    SetActorState2     ; args: actor index, new byte value
    SetAvatarFlags     ; args: new bObj value
    SetAvatarPose      ; args: new eAvatar value
    SetCutsceneFlags   ; args: bCutscene value
    ShakeRoom          ; args: num shake frames
    ;; Multi-frame actions:
    RunDialog          ; args: eDialog value
    WaitFrames         ; args: number of frames
    WaitUntilC         ; args: func ptr (2 bytes); func must return C
    WaitUntilZ         ; args: func ptr (2 bytes); func must return Z
    WalkAlex           ; args: actor index, goal X-position (2 bytes)
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;
