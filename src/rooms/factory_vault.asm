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
.INCLUDE "../actors/child.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../devices/dialog.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Factory_sTileset
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjVillage
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_ProgressFlags_arr

;;;=========================================================================;;;

;;; The actor index for Alex in this room.
kAlexActorIndex = 0
;;; The talk device indices for Alex in this room.
kAlexDeviceIndexRight = 0
kAlexDeviceIndexLeft  = 1

;;;=========================================================================;;;

.SEGMENT "PRGC_Factory"

.EXPORT DataC_Factory_Vault_sRoom
.PROC DataC_Factory_Vault_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0100
    d_byte Flags_bRoom, eArea::Factory
    d_byte MinimapStartRow_u8, 5
    d_byte MinimapStartCol_u8, 8
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjVillage)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Factory_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_FactoryVault_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/factory_vault.room"
    .assert * - :- = 33 * 15, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0110
    d_word Top_i16,   $00cc
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0110
    d_word Top_i16,   $00de
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kAlexActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0060
    d_word PosY_i16, $00a8
    d_byte Param_byte, eNpcChild::AlexStanding
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kAlexDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eDialog::FactoryVaultAlex1
    D_END
    .assert * - :- = kAlexDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eDialog::FactoryVaultAlex1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Screen
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 20
    d_byte Target_byte, eDialog::FactoryVaultScreen
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::FactoryLock
    d_byte SpawnBlock_u8, 11
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC
;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_FactoryVault_EnterRoom
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerLava
    beq @removeAlex
    flag_bit Sram_ProgressFlags_arr, eFlag::FactoryVaultTalkedToAlex
    beq @keepAlex
    @removeAlex:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kAlexActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexRight
    @keepAlex:
    rts
.ENDPROC
;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_FactoryVaultLookAtTank_sCutscene
.PROC DataA_Cutscene_FactoryVaultLookAtTank_sCutscene
    ;; Anna steps out of the way to the left.
    act_ForkStart 1, _WalkAvatar_sCutscene
    ;; Alex walks over to the big tank and kneels down for a closer look.
    act_WalkNpcAlex kAlexActorIndex, $007a
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 45
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexKneeling
    act_WaitFrames 60
    ;; Alex reads off the label on the tank.
    act_RunDialog eDialog::FactoryVaultAlex2
    ;; Alex walk over and looks at the tank from the right side.
    act_WalkNpcAlex kAlexActorIndex, $009c
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 10
    act_SetActorFlags kAlexActorIndex, bObj::FlipH
    act_WaitFrames 10
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexLooking
    act_WaitFrames 90
    ;; Alex walk over and looks at the tank from the left side.
    act_WalkNpcAlex kAlexActorIndex, $006c
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 10
    act_SetActorFlags kAlexActorIndex, 0
    act_WaitFrames 10
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexLooking
    act_WaitFrames 90
    ;; Alex thinks out loud for a bit.
    act_RunDialog eDialog::FactoryVaultAlex3
    ;; Alex walks back to where he was standing before and talks to Anna again.
    act_WalkNpcAlex kAlexActorIndex, $0060
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_SetActorState2 kAlexActorIndex, 0
    act_CallFunc _SetFlag
    act_RunDialog eDialog::FactoryVaultAlex1
    act_ContinueExploring
_WalkAvatar_sCutscene:
    act_WalkAvatar $0050 | kTalkRightAvatarOffset
    act_SetAvatarPose eAvatar::Standing
    act_SetAvatarFlags kPaletteObjAvatarNormal | 0
    act_ForkStop $ff
_SetFlag:
    ldx #eFlag::FactoryVaultTalkedToAlex  ; param: flag
    jmp Func_SetFlag
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_FactoryVaultAlex1_sDialog
.PROC DataA_Dialog_FactoryVaultAlex1_sDialog
    dlg_IfSet FactoryVaultTalkedToAlex, _CityGoal_sDialog
_LookAtThisPlace_sDialog:
    dlg_Text ChildAlex, DataA_Text2_FactoryVaultAlex1_Part1_u8_arr
    dlg_Text ChildAlex, DataA_Text2_FactoryVaultAlex1_Part2_u8_arr
    dlg_Cutscene eCutscene::FactoryVaultLookAtTank
_CityGoal_sDialog:
    dlg_Text ChildAlex, DataA_Text2_FactoryVaultAlex4_Part1_u8_arr
    dlg_Text ChildAlex, DataA_Text2_FactoryVaultAlex4_Part2_u8_arr
    dlg_Text ChildAlex, DataA_Text2_FactoryVaultAlex4_Part3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_FactoryVaultAlex2_sDialog
.PROC DataA_Dialog_FactoryVaultAlex2_sDialog
    dlg_Text ChildAlex, DataA_Text2_FactoryVaultAlex2_Part1_u8_arr
    dlg_Call FuncA_Dialog_FactoryVault_AlexStand
    dlg_Text ChildAlex, DataA_Text2_FactoryVaultAlex2_Part2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_FactoryVaultAlex3_sDialog
.PROC DataA_Dialog_FactoryVaultAlex3_sDialog
    dlg_Text ChildAlex, DataA_Text2_FactoryVaultAlex3_Part1_u8_arr
    dlg_Call FuncA_Dialog_FactoryVault_AlexStand
    dlg_Text ChildAlex, DataA_Text2_FactoryVaultAlex3_Part2_u8_arr
    dlg_Call _LookLeft
    dlg_Text ChildAlex, DataA_Text2_FactoryVaultAlex3_Part3_u8_arr
    dlg_Text ChildAlex, DataA_Text2_FactoryVaultAlex3_Part4_u8_arr
    dlg_Done
_LookLeft:
    lda #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr + kAlexActorIndex
    rts
.ENDPROC

.PROC FuncA_Dialog_FactoryVault_AlexStand
    lda #eNpcChild::AlexStanding
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    rts
.ENDPROC

.EXPORT DataA_Dialog_FactoryVaultScreen_sDialog
.PROC DataA_Dialog_FactoryVaultScreen_sDialog
    dlg_Text Screen, DataA_Text2_FactoryVaultScreen_Page1_u8_arr
    dlg_Text Screen, DataA_Text2_FactoryVaultScreen_Page2_u8_arr
    dlg_Text Screen, DataA_Text2_FactoryVaultScreen_Page3_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text2"

.PROC DataA_Text2_FactoryVaultAlex1_Part1_u8_arr
    .byte "Anna, you're back!$"
    .byte "Would you look at this$"
    .byte "place? It opened up$"
    .byte "while you were gone.#"
.ENDPROC

.PROC DataA_Text2_FactoryVaultAlex1_Part2_u8_arr
    .byte "I think we finally$"
    .byte "found what the ancient$"
    .byte "humans were building$"
    .byte "in this factory.#"
.ENDPROC

.PROC DataA_Text2_FactoryVaultAlex2_Part1_u8_arr
    .byte "Hmm, it's got a label.$"
    .byte "Let's see...$"
    .byte "`Human Mutation Tank$"
    .byte " Serial No. 94209382'#"
.ENDPROC

.PROC DataA_Text2_FactoryVaultAlex2_Part2_u8_arr
    .byte "Human...mutation?#"
.ENDPROC

.PROC DataA_Text2_FactoryVaultAlex3_Part1_u8_arr
    .byte "Anna...remember how$"
    .byte "you found out that the$"
    .byte "first mermaids were$"
    .byte "created by humans?#"
.ENDPROC

.PROC DataA_Text2_FactoryVaultAlex3_Part2_u8_arr
    .byte "If I'm understanding$"
    .byte "this right...it looks$"
    .byte "like those mermaids$"
    .byte "were made FROM humans.#"
.ENDPROC

.PROC DataA_Text2_FactoryVaultAlex3_Part3_u8_arr
    .byte "This was all centuries$"
    .byte "ago. And now we're two$"
    .byte "different peoples. But$"
    .byte "why do any of that?#"
.ENDPROC

.PROC DataA_Text2_FactoryVaultAlex3_Part4_u8_arr
    .byte "They had practically$"
    .byte "unlimited technology$"
    .byte "and knowledge. So why$"
    .byte "this? I don't get it.#"
.ENDPROC

.PROC DataA_Text2_FactoryVaultAlex4_Part1_u8_arr
    .byte "Well, if you got the$"
    .byte "pass into the sewers$"
    .byte "opened up, then the$"
    .byte "city is our next goal.#"
.ENDPROC

.PROC DataA_Text2_FactoryVaultAlex4_Part2_u8_arr
    .byte "The orcs are already$"
    .byte "there, looking for$"
    .byte "something. I'm not$"
    .byte "exactly sure what.#"
.ENDPROC

.PROC DataA_Text2_FactoryVaultAlex4_Part3_u8_arr
    .byte "Whatever it is, we've$"
    .byte "got to find it first!#"
.ENDPROC

.PROC DataA_Text2_FactoryVaultScreen_Page1_u8_arr
    .byte "ERROR: Gene mutation$"
    .byte "tank production line$"
    .byte "has been stalled.#"
.ENDPROC

.PROC DataA_Text2_FactoryVaultScreen_Page2_u8_arr
    .byte "Current batch: Q6382A$"
    .byte "Designated for:$"
    .byte "  Volunteer group 922$"
    .byte "  <Mermaid Aspect>#"
.ENDPROC

.PROC DataA_Text2_FactoryVaultScreen_Page3_u8_arr
    .byte "Due date: 2245 Feb 21$"
    .byte "Overdue by: 495 years$"
    .byte "Report to supervisor$"
    .byte "for instructions.#"
.ENDPROC

;;;=========================================================================;;;
