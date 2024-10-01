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
.INCLUDE "../actors/adult.inc"
.INCLUDE "../actors/child.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../portrait.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Hut_sTileset
.IMPORT DataA_Text0_MermaidHut1AlexPetition_Part1_u8_arr
.IMPORT DataA_Text0_MermaidHut1AlexPetition_Part2_u8_arr
.IMPORT DataA_Text0_MermaidHut1AlexPetition_Part3_u8_arr
.IMPORT DataA_Text0_MermaidHut1AlexPetition_Part4_u8_arr
.IMPORT DataA_Text0_MermaidHut1AlexPetition_Part5_u8_arr
.IMPORT DataA_Text0_MermaidHut1BreakerCrypt_Part1_u8_arr
.IMPORT DataA_Text0_MermaidHut1BreakerCrypt_Part2_u8_arr
.IMPORT DataA_Text0_MermaidHut1BreakerCrypt_Part3_u8_arr
.IMPORT DataA_Text0_MermaidHut1BreakerCrypt_Part4_u8_arr
.IMPORT DataA_Text0_MermaidHut1BreakerCrypt_Part5_u8_arr
.IMPORT DataA_Text0_MermaidHut1BreakerCrypt_Part6_u8_arr
.IMPORT DataA_Text0_MermaidHut1BreakerCrypt_Part7_u8_arr
.IMPORT DataA_Text0_MermaidHut1BreakerGarden_u8_arr
.IMPORT DataA_Text0_MermaidHut1Guard_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_FindYourFriends_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_FirstMeeting1_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_FirstMeeting2_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_FirstMeeting3_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_FirstMeeting4_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_GardenBossDead1_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_GardenBossDead2_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_GrantAsylum_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_HelpFarmers_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_KidsRescued1_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_KidsRescued2_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_OtherRuins_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_TempleBossDead1_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_TempleBossDead2_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_TempleBossDead3_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_TempleBossDead4_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_TempleBossDead5_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_TempleEntry_u8_arr
.IMPORT DataA_Text0_MermaidHut1Queen_TempleProblem_u8_arr
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeBig
.IMPORT Func_SetFlag
.IMPORT Main_Breaker_FadeBackToBreakerRoom
.IMPORT Ppu_ChrObjVillage
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_Next_eCutscene

;;;=========================================================================;;;

;;; The actor index for the mermaid guard in this room.
kGuardActorIndex = 0
;;; The actor index for Alex in this room.
kAlexActorIndex = 1
;;; The actor index for Queen Eirene in this room.
kEireneActorIndex = 2

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Hut1_sRoom
.PROC DataC_Mermaid_Hut1_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, bRoom::ReduceMusic | eArea::Mermaid
    d_byte MinimapStartRow_u8, 10
    d_byte MinimapStartCol_u8, 12
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjVillage)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Hut_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncA_Room_MermaidHut1_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_MermaidHut1_TickRoom
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/mermaid_hut1.room"
    .assert * - :- = 16 * 15, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $e0
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0010
    d_word Top_i16,   $00c4
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kGuardActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0040
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcAdult::MermaidGuardM
    D_END
    .assert * - :- = kAlexActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $00a8
    d_word PosY_i16, $00b8
    d_byte Param_byte, eNpcChild::AlexStanding
    D_END
    .assert * - :- = kEireneActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcQueen
    d_word PosX_i16, $00c0
    d_word PosY_i16, $00a8
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 3
    d_byte Target_byte, eDialog::MermaidHut1Guard
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eDialog::MermaidHut1Guard
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eDialog::MermaidHut1Queen
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 12
    d_byte Target_byte, eDialog::MermaidHut1Queen
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eRoom::MermaidVillage
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_MermaidHut1_EnterRoom
    ;; Alex should always start facing the queen, if he's in the room.
    lda #$ff
    sta Ram_ActorState2_byte_arr + kAlexActorIndex
    ;; If a breaker cutscene is playing, then the mermaid guard should face to
    ;; the right, and Eirene should face to the left.
    ldx Zp_Next_eCutscene
    .assert eCutscene::None = 0, error
    beq @done
    sta Ram_ActorState2_byte_arr + kGuardActorIndex
    sta Ram_ActorState2_byte_arr + kEireneActorIndex
    lda #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr + kEireneActorIndex
    @done:
_Alex:
    ;; If the Crypt breaker cutscene is playing, Alex should be in the room.
    cpx #eCutscene::MermaidHut1BreakerCrypt
    beq @keepAlex
    ;; If Alex has been rescued, but hasn't yet finished his petition to the
    ;; queen, he should be in the room.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperFreedKids
    beq @removeAlex
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidHut1AlexPetition
    beq @keepAlex
    @removeAlex:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kAlexActorIndex
    @keepAlex:
    rts
.ENDPROC

.PROC FuncA_Room_MermaidHut1_TickRoom
    ;; If Alex is still petitioning the queen (he's been rescued, but hasn't
    ;; yet completed his petition), start that cutscene.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperFreedKids
    beq @done
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidHut1AlexPetition
    bne @done
    lda #eCutscene::MermaidHut1AlexPetition
    sta Zp_Next_eCutscene
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_MermaidHut1AlexPetition_sCutscene
.PROC DataA_Cutscene_MermaidHut1AlexPetition_sCutscene
    act_RunDialog eDialog::MermaidHut1AlexPetition
    ;; Make Alex walk to the edge of the platform.
    act_WalkNpcAlex kAlexActorIndex, $00a0
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_ForkStart 1, _SwimAvatar_sCutscene
    act_WaitFrames 6
    ;; Make Alex jump into the water.
    ;; TODO: play a sound for Alex jumping
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexWalking1
    act_SetActorVelX kAlexActorIndex, -$100
    act_SetActorVelY kAlexActorIndex, -$100
    act_SetCutsceneFlags bCutscene::TickAllActors
    act_RepeatFunc 20, _ApplyAlexGravity
    act_SetCutsceneFlags 0
    act_SetActorVelX kAlexActorIndex, 0
    act_SetActorVelY kAlexActorIndex, 0
    act_SetActorPosY kAlexActorIndex, $00c4
    ;; Make Alex swim to the door and exit the room.
    act_SwimNpcAlex kAlexActorIndex, $0077
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexSwimDoor
    act_WaitFrames 15
    act_CallFunc _RemoveAlex
    act_ContinueExploring
_SwimAvatar_sCutscene:
    act_SwimAvatar $0066
    act_SetAvatarFlags kPaletteObjAvatarNormal
    act_ForkStop $ff
_ApplyAlexGravity:
    lda #kAvatarGravity
    add Ram_ActorVelY_i16_0_arr + kAlexActorIndex
    sta Ram_ActorVelY_i16_0_arr + kAlexActorIndex
    lda #0
    adc Ram_ActorVelY_i16_1_arr + kAlexActorIndex
    sta Ram_ActorVelY_i16_1_arr + kAlexActorIndex
    rts
_RemoveAlex:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kAlexActorIndex
    ldx #eFlag::MermaidHut1AlexPetition  ; param: flag
    jmp Func_SetFlag
.ENDPROC

.EXPORT DataA_Cutscene_MermaidHut1BreakerCrypt_sCutscene
.PROC DataA_Cutscene_MermaidHut1BreakerCrypt_sCutscene
    act_RunDialog eDialog::MermaidHut1BreakerCrypt1
    act_WaitFrames 30
    act_CallFunc Func_PlaySfxExplodeBig
    act_ShakeRoom 30
    act_WaitFrames 20
    act_SetActorFlags kEireneActorIndex, 0
    act_WaitFrames 10
    act_SetActorFlags kGuardActorIndex, bObj::FlipH
    act_WaitFrames 10
    act_SetActorFlags kEireneActorIndex, bObj::FlipH
    act_WaitFrames 10
    act_SetActorFlags kGuardActorIndex, 0
    act_WaitFrames 40
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexHolding
    act_RunDialog eDialog::MermaidHut1BreakerCrypt2
    act_JumpToMain Main_Breaker_FadeBackToBreakerRoom
.ENDPROC

.EXPORT DataA_Cutscene_MermaidHut1BreakerGarden_sCutscene
.PROC DataA_Cutscene_MermaidHut1BreakerGarden_sCutscene
    act_WaitFrames 60
    act_CallFunc Func_PlaySfxExplodeBig
    act_ShakeRoom 30
    act_WaitFrames 20
    act_SetActorFlags kEireneActorIndex, 0
    act_WaitFrames 10
    act_SetActorFlags kGuardActorIndex, bObj::FlipH
    act_WaitFrames 10
    act_SetActorFlags kEireneActorIndex, bObj::FlipH
    act_WaitFrames 10
    act_SetActorFlags kGuardActorIndex, 0
    act_WaitFrames 40
    act_RunDialog eDialog::MermaidHut1BreakerGarden
    act_JumpToMain Main_Breaker_FadeBackToBreakerRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_MermaidHut1Guard_sDialog
.PROC DataA_Dialog_MermaidHut1Guard_sDialog
    dlg_Text AdultMan, DataA_Text0_MermaidHut1Guard_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidHut1Queen_sDialog
.PROC DataA_Dialog_MermaidHut1Queen_sDialog
    dlg_Func _InitialFunc
_InitialFunc:
    ;; First quest: Defeat the Garden boss.
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerGarden
    beq _Quest1Func
    ;; To be safe, set the "met queen" flag (although normally, you can't reach
    ;; the garden breaker without first having met the queen).
    ldx #eFlag::MermaidHut1MetQueen  ; param: flag
    jsr Func_SetFlag
    ;; Second quest: Defeat the Temple boss.
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerTemple
    beq _Quest2Func
    ;; To be safe, set the "temple permission" flag (although normally, you
    ;; can't reach the temple breaker without first getting permission).
    ldx #eFlag::TempleEntryPermission  ; param: flag
    jsr Func_SetFlag
    ;; Third quest: Rescue Alex and the other children.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperFreedKids
    beq _Quest3Func
    ;; To be safe, set the "Corra waiting" flag (although normally, you can't
    ;; rescue the kids without first meeting up with Corra).
    ldx #eFlag::CoreSouthCorraWaiting  ; param: flag
    jsr Func_SetFlag
    ;; Once quests are done, give other dialog.
    ;; TODO: Change the queen's dialog as the game progresses.
    ldya #_KidsRescued_sDialog
    rts
_Quest1Func:
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidHut1MetQueen
    bne @grantAsylum
    ldya #_FirstMeeting_sDialog
    rts
    @grantAsylum:
    ldya #_GrantAsylum_sDialog
    rts
_Quest2Func:
    flag_bit Sram_ProgressFlags_arr, eFlag::TempleEntryPermission
    bne @templeProblem
    ldya #_GardenBossDead_sDialog
    rts
    @templeProblem:
    ldya #_TempleProblem_sDialog
    rts
_Quest3Func:
    flag_bit Sram_ProgressFlags_arr, eFlag::CoreSouthCorraWaiting
    bne @otherRuins
    ldya #_TempleBossDead_sDialog
    rts
    @otherRuins:
    ldya #_OtherRuins_sDialog
    rts
_FirstMeeting_sDialog:
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_FirstMeeting1_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_FirstMeeting2_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_FirstMeeting3_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_FirstMeeting4_u8_arr
_GrantAsylum_sDialog:
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_GrantAsylum_u8_arr
    dlg_Quest MermaidHut1MetQueen
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_HelpFarmers_u8_arr
    dlg_Done
_GardenBossDead_sDialog:
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_GardenBossDead1_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_GardenBossDead2_u8_arr
_TempleProblem_sDialog:
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_TempleProblem_u8_arr
    dlg_Quest TempleEntryPermission
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_TempleEntry_u8_arr
    dlg_Done
_TempleBossDead_sDialog:
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_TempleBossDead1_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_TempleBossDead2_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_TempleBossDead3_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_TempleBossDead4_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_TempleBossDead5_u8_arr
_OtherRuins_sDialog:
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_OtherRuins_u8_arr
    dlg_Quest CoreSouthCorraWaiting
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_FindYourFriends_u8_arr
    dlg_Done
_KidsRescued_sDialog:
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_KidsRescued1_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_KidsRescued2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidHut1BreakerGarden_sDialog
.PROC DataA_Dialog_MermaidHut1BreakerGarden_sDialog
    dlg_Text MermaidEireneShout, DataA_Text0_MermaidHut1BreakerGarden_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidHut1AlexPetition_sDialog
.PROC DataA_Dialog_MermaidHut1AlexPetition_sDialog
    .assert kTileIdBgPortraitAlexFirst = kTileIdBgPortraitEireneFirst, error
    dlg_Text ChildAlex, DataA_Text0_MermaidHut1AlexPetition_Part1_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1AlexPetition_Part2_u8_arr
    dlg_Text ChildAlex, DataA_Text0_MermaidHut1AlexPetition_Part3_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1AlexPetition_Part4_u8_arr
    dlg_Text ChildAlex, DataA_Text0_MermaidHut1AlexPetition_Part5_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidHut1BreakerCrypt1_sDialog
.PROC DataA_Dialog_MermaidHut1BreakerCrypt1_sDialog
    .assert kTileIdBgPortraitAlexFirst = kTileIdBgPortraitEireneFirst, error
    dlg_Text ChildAlex, DataA_Text0_MermaidHut1BreakerCrypt_Part1_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1BreakerCrypt_Part2_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1BreakerCrypt_Part3_u8_arr
    dlg_Text ChildAlex, DataA_Text0_MermaidHut1BreakerCrypt_Part4_u8_arr
    dlg_Text ChildAlex, DataA_Text0_MermaidHut1BreakerCrypt_Part5_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1BreakerCrypt_Part6_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidHut1BreakerCrypt2_sDialog
.PROC DataA_Dialog_MermaidHut1BreakerCrypt2_sDialog
    dlg_Text ChildAlex, DataA_Text0_MermaidHut1BreakerCrypt_Part7_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
