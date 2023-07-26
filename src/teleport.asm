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

.INCLUDE "avatar.inc"
.INCLUDE "cutscene.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "spawn.inc"
.INCLUDE "teleport.inc"

.IMPORT FuncA_Avatar_SpawnAtDevice
.IMPORT FuncM_SwitchPrgcAndLoadRoom
.IMPORT Func_FadeOutToBlack
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetLastSpawnPoint
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Main_Explore_EnterRoom
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_Next_eCutscene

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for leaving the current room via a teleporter and entering the next
;;; room.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @prereq There is a Teleporter device in the current room.
.PROC Main_GoThroughTeleporter
    jsr Func_FadeOutToBlack
    ldx Ram_DeviceTarget_byte_arr + kTeleporterDeviceIndex  ; param: eRoom
    jsr FuncM_SwitchPrgcAndLoadRoom
    jsr_prga FuncA_Avatar_EnterRoomViaTeleporter
    jmp Main_Explore_EnterRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_SharedTeleportOut_sCutscene
.PROC DataA_Cutscene_SharedTeleportOut_sCutscene
    act_SetAvatarPose eAvatar::Hidden
    act_CallFunc _MakeSmokePuff
    act_WaitFrames 60
    act_JumpToMain Main_GoThroughTeleporter
_MakeSmokePuff:
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @done
    jsr Func_SetPointToAvatarCenter  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    jmp Func_InitActorSmokeExplosion
    @done:
    rts
.ENDPROC

.EXPORT DataA_Cutscene_SharedTeleportIn_sCutscene
.PROC DataA_Cutscene_SharedTeleportIn_sCutscene
    act_WaitFrames 30
    ;; TODO: spawn a teleport zap actor
    act_ContinueExploring
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Called when entering a new room via a teleporter.  Marks the entrance
;;; teleporter as the last spawn point and positions the player avatar at that
;;; teleporter.  Also sets up the "teleport in" cutscene.
;;; @prereq The new room is loaded.
;;; @prereq There is a Teleporter device in the new room.
.PROC FuncA_Avatar_EnterRoomViaTeleporter
    lda #bSpawn::Device | kTeleporterDeviceIndex  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint
    ldx #kTeleporterDeviceIndex  ; param: device index
    jsr FuncA_Avatar_SpawnAtDevice
_InitCutsceneState:
    lda #eAvatar::Hidden
    sta Zp_AvatarPose_eAvatar
    lda #eCutscene::SharedTeleportIn
    sta Zp_Next_eCutscene
    rts
.ENDPROC

;;;=========================================================================;;;
