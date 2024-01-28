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
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"

.IMPORT DataA_Room_House_sTileset
.IMPORT Data_Empty_sPlatform_arr
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjTown
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_Next_eCutscene

;;;=========================================================================;;;

;;; The device index for the doorway in this room.
kDoorDeviceIndex = 2

;;; The room pixel position for Anna when she's sleeping on the bed.
kAnnaSleepPositionX = $bd
kAnnaSleepPositionY = $c1

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
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_House_sTileset
    d_addr Platforms_sPlatform_arr_ptr, Data_Empty_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncC_Town_House2_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/town_house2.room"
    .assert * - :- = 16 * 15, error
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
    d_byte Target_byte, eDialog::TownHouse2Stela
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eDialog::TownHouse2Stela
    D_END
    .assert * - :- = kDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eRoom::TownOutdoors
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
    sta Zp_AvatarPose_eAvatar
    lda #kAnnaSleepPositionX
    sta Zp_AvatarPosX_i16 + 0
    lda #kAnnaSleepPositionY
    sta Zp_AvatarPosY_i16 + 0
    lda #bObj::FlipH | kPaletteObjAvatarNormal
    sta Zp_AvatarFlags_bObj
    lda #eCutscene::TownHouse2WakeUp
    sta Zp_Next_eCutscene
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_TownHouse2WakeUp_sCutscene
.PROC DataA_Cutscene_TownHouse2WakeUp_sCutscene
    act_WaitFrames 150
    act_SetAvatarPose eAvatar::Slumping
    act_WaitFrames 60
    act_SetAvatarPose eAvatar::Kneeling
    act_WaitFrames 15
    act_SetAvatarVelY $ff00
    act_ContinueExploring
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_TownHouse2Stela_sDialog
.PROC DataA_Dialog_TownHouse2Stela_sDialog
    dlg_Text AdultWoman, DataA_Text0_TownHouse2Stela_Page1_u8_arr
    dlg_Text AdultWoman, DataA_Text0_TownHouse2Stela_Page2_u8_arr
    dlg_Text AdultWoman, DataA_Text0_TownHouse2Stela_Page3_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_TownHouse2Stela_Page1_u8_arr
    .byte "Can't sleep, Anna?#"
.ENDPROC

.PROC DataA_Text0_TownHouse2Stela_Page2_u8_arr
    .byte "Your brother Alex is$"
    .byte "up late, too.#"
.ENDPROC

.PROC DataA_Text0_TownHouse2Stela_Page3_u8_arr
    .byte "I think he went$"
    .byte "outside somewhere. Why$"
    .byte "don't you go find him?#"
.ENDPROC

;;;=========================================================================;;;
