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
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "spawn.inc"
.INCLUDE "teleport.inc"

.IMPORT FuncA_Actor_TickAllActors
.IMPORT FuncA_Avatar_SpawnAtDevice
.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncA_Room_SetPointToAvatarCenter
.IMPORT FuncM_SwitchPrgcAndLoadRoom
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_FadeOutToBlack
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetLastSpawnPoint
.IMPORT Func_TickAllDevices
.IMPORT Main_Explore_Continue
.IMPORT Main_Explore_EnterRoom
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORTZP Zp_AvatarMode_eAvatar
.IMPORTZP Zp_NextCutscene_main_ptr

;;;=========================================================================;;;

;;; How long to wait for various phases of the teleport out/in cutscenes.
kTeleportFramesUntilFadeOut = 60
kTeleportFramesUntilAvatarAppears = 30

;;;=========================================================================;;;

.ZEROPAGE

;;; The number of remaining frames in the current teleport cutscene phase.
Zp_TeleportTimer_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Cutscene mode for teleporting the player avatar out of the current room.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @prereq There is a Teleporter device in the current room.
.EXPORT Main_CutsceneTeleportOut
.PROC Main_CutsceneTeleportOut
    jsr_prga FuncA_Room_InitTeleportOutCutscene
    jsr FuncM_TeleportWaitForTimer
    jsr Func_FadeOutToBlack
    .assert * = Main_GoThroughTeleporter, error, "fallthrough"
.ENDPROC

;;; Mode for leaving the current room via a teleporter and entering the next
;;; room.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @prereq There is a Teleporter device in the current room.
.PROC Main_GoThroughTeleporter
    ldx Ram_DeviceTarget_u8_arr + kTeleporterDeviceIndex
    jsr FuncM_SwitchPrgcAndLoadRoom
    jsr_prga FuncA_Avatar_EnterRoomViaTeleporter
    jmp Main_Explore_EnterRoom
.ENDPROC

;;; Cutscene mode for teleporting the player avatar into the current room.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
.PROC Main_CutsceneTeleportIn
    jsr FuncM_TeleportWaitForTimer
    ;; TODO: make teleport zap actor
    jmp Main_Explore_Continue
.ENDPROC

;;; Waits for Zp_TeleportTimer_u8 frames (while decrementing it down to zero).
;;; Ticks actors and devices, but not machines, the room, or the player avatar.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
.PROC FuncM_TeleportWaitForTimer
    @loop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr_prga FuncA_Actor_TickAllActors
    jsr Func_TickAllDevices
    dec Zp_TeleportTimer_u8
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes state for the cutscene that plays when the player avatar
;;; teleports out of a room.
.PROC FuncA_Room_InitTeleportOutCutscene
_HideAvatar:
    lda #eAvatar::Hidden
    sta Zp_AvatarMode_eAvatar
_MakeSmokePuff:
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @done
    jsr FuncA_Room_SetPointToAvatarCenter  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    jsr Func_InitActorSmokeExplosion
    @done:
_InitCutsceneState:
    lda #kTeleportFramesUntilFadeOut
    sta Zp_TeleportTimer_u8
    rts
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
    sta Zp_AvatarMode_eAvatar
    ldya #Main_CutsceneTeleportIn
    stya Zp_NextCutscene_main_ptr
    lda #kTeleportFramesUntilAvatarAppears
    sta Zp_TeleportTimer_u8
    rts
.ENDPROC

;;;=========================================================================;;;
