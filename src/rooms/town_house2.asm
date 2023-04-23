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

.INCLUDE "../actor.inc"
.INCLUDE "../actors/townsfolk.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"

.IMPORT DataA_Room_House_sTileset
.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_Noop
.IMPORT Main_Explore_Continue
.IMPORT Ppu_ChrObjTown
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarMode_eAvatar
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarVelY_i16
.IMPORTZP Zp_NextCutscene_main_ptr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The device index for the doorway in this room.
kDoorDeviceIndex = 2

;;; The room pixel position for Anna when she's sleeping on the bed.
kAnnaSleepPositionX = $bd
kAnnaSleepPositionY = $c1

;;; CutsceneTimer_u8 values for various phases of the cutscene.
kCutsceneTimerSleeping = 150
kCutsceneTimerKneeling = 20 + kCutsceneTimerSleeping

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; A timer used for animating the cutscene in this room.
    CutsceneTimer_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Town"

.EXPORT DataC_Town_House2_sRoom
.PROC DataC_Town_House2_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, eArea::Town
    d_byte MinimapStartRow_u8, 0
    d_byte MinimapStartCol_u8, 11
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTown)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_House_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncC_Town_House2_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/town_house2.room"
    .assert * - :- = 16 * 16, error
_Platforms_sPlatform_arr:
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0080
    d_word PosY_i16, $00c8
    d_byte Param_byte, kTileIdAdultWomanFirst
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 7
    d_byte Target_u8, eDialog::TownHouse2Stela
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 8
    d_byte Target_u8, eDialog::TownHouse2Stela
    D_END
    .assert * - :- = kDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 5
    d_byte Target_u8, eRoom::TownOutdoors
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

;;; Room init function for the TownHouse2 room.
;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncC_Town_House2_EnterRoom
    ;; The doorway is the only way into this room, so if the player avatar
    ;; didn't enter this room via the door, then we must have just started a
    ;; new game, in which case we should start the opening cutscene.
    cmp #bSpawn::Device | kDoorDeviceIndex
    beq @done
    lda #eAvatar::Sleeping
    sta Zp_AvatarMode_eAvatar
    lda #kAnnaSleepPositionX
    sta Zp_AvatarPosX_i16 + 0
    lda #kAnnaSleepPositionY
    sta Zp_AvatarPosY_i16 + 0
    lda #bObj::FlipH | kPaletteObjAvatarNormal
    sta Zp_AvatarFlags_bObj
    ldya #MainC_Town_House2Cutscene
    stya Zp_NextCutscene_main_ptr
    @done:
    rts
.ENDPROC

.PROC MainC_Town_House2Cutscene
_GameLoop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
_WakeUp:
    inc Zp_RoomState + sState::CutsceneTimer_u8
    lda Zp_RoomState + sState::CutsceneTimer_u8
    cmp #kCutsceneTimerSleeping
    blt _GameLoop
    cmp #kCutsceneTimerKneeling
    bge _ResumeExploring
    @kneeling:
    lda #eAvatar::Kneeling
    sta Zp_AvatarMode_eAvatar
    bne _GameLoop  ; unconditional
_ResumeExploring:
    lda #<-1
    sta Zp_AvatarVelY_i16 + 1
    jmp Main_Explore_Continue
.ENDPROC

.EXPORT DataC_Town_TownHouse2Stela_sDialog
.PROC DataC_Town_TownHouse2Stela_sDialog
    .word ePortrait::Woman
    .byte "Can't sleep, Anna?#"
    .word ePortrait::Woman
    .byte "Your brother Alex is$"
    .byte "up late, too.#"
    .word ePortrait::Woman
    .byte "I think he went$"
    .byte "outside somewhere. Why$"
    .byte "don't you go find him?#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;
