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

.INCLUDE "device.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "spawn.inc"

.IMPORT DataA_Room_Banks_u8_arr
.IMPORT FuncA_Avatar_SpawnAtDevice
.IMPORT FuncA_Fade_Out
.IMPORT FuncA_Room_Load
.IMPORT Func_SetLastSpawnPoint
.IMPORT Main_Explore_Continue
.IMPORT Main_Explore_FadeIn
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORTZP Zp_NextCutscene_main_ptr

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Cutscene mode for teleporting the player avatar out of the current room.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @prereq There is a Teleport device in the current room.
.EXPORT Main_CutsceneTeleportOut
.PROC Main_CutsceneTeleportOut
    ;; TODO: animate avatar disappearing
_FadeOut:
    jsr_prga FuncA_Fade_Out
_LoadDestinationRoom:
    jsr_prga FuncA_Avatar_GetTeleportDestinationRoom  ; returns X
    prga_bank #<.bank(DataA_Room_Banks_u8_arr)
    prgc_bank DataA_Room_Banks_u8_arr, x
    jsr FuncA_Room_Load
    jsr_prga FuncA_Avatar_EnterRoomViaTeleporter
_FadeIn:
    ldya #Main_CutsceneTeleportIn
    stya Zp_NextCutscene_main_ptr
    jmp Main_Explore_FadeIn
.ENDPROC

;;; Cutscene mode for teleporting the player avatar into the current room.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
.PROC Main_CutsceneTeleportIn
    ;; TODO: animate avatar appearing
    jmp Main_Explore_Continue
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Called when entering a new room via a teleporter.  Marks the entrance
;;; teleporter as the last spawn point, positions the player avatar at that
;;; teleporter, and finally calls the room's Enter_func_ptr.
;;; @prereq The new room is loaded.
;;; @prereq There is a Teleport device in the new room.
.PROC FuncA_Avatar_EnterRoomViaTeleporter
    jsr FuncA_Avatar_FindTeleportDevice  ; returns X
    .assert bSpawn::IsPassage <> 0, error
    txa  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint  ; preserves X
    jmp FuncA_Avatar_SpawnAtDevice
.ENDPROC

;;; Finds the device index of the Teleport device in the current room.
;;; @prereq There is a Teleport device in the current room.
;;; @return X The Teleport device index.
.PROC FuncA_Avatar_FindTeleportDevice
    ldx #0
    @loop:
    lda Ram_DeviceType_eDevice_arr, x
    cmp #eDevice::Teleporter
    beq @found
    inx
    bne @loop  ; unconditional-ish
    @found:
    rts
.ENDPROC

;;; Returns the destination room for the Teleport device in the current room.
;;; @prereq There is a Teleport device in the current room.
;;; @return X The eRoom value for the destination room.
.PROC FuncA_Avatar_GetTeleportDestinationRoom
    jsr FuncA_Avatar_FindTeleportDevice  ; returns X
    lda Ram_DeviceTarget_u8_arr, x
    tax
    rts
.ENDPROC

;;;=========================================================================;;;