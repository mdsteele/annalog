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
.INCLUDE "../actors/townsfolk.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Hut_sTileset
.IMPORT FuncA_Dialog_AddQuestMarker
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Main_Breaker_FadeBackToBreakerRoom
.IMPORT Ppu_ChrObjVillage
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_Next_eCutscene

;;;=========================================================================;;;

;;; The actor index for the mermaid guard in this room.
kGuardActorIndex = 0
;;; The actor index for Alex in this room.
kAlexActorIndex = 1

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Hut1_sRoom
.PROC DataC_Mermaid_Hut1_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, eArea::Mermaid
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
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/mermaid_hut1.room"
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
    d_byte Type_eActor, eActor::NpcMermaid
    d_word PosX_i16, $0040
    d_word PosY_i16, $00c8
    d_byte Param_byte, kTileIdMermaidGuardMFirst
    D_END
    .assert * - :- = kAlexActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $00a8
    d_word PosY_i16, $00b8
    d_byte Param_byte, eNpcChild::AlexStanding
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaidQueen
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
    ;; If a breaker cutscene is playing, make sure that Alex and the mermaid
    ;; guard both face to the right.  If not, remove Alex.
    lda Zp_Next_eCutscene
    .assert eCutscene::None = 0, error
    beq @removeAlex
    lda #$ff
    sta Ram_ActorState2_byte_arr + kGuardActorIndex
    sta Ram_ActorState2_byte_arr + kAlexActorIndex
    ;; If this is the Crypt breaker cutscene specifically, Alex should stay;
    ;; otherwise, remove him.
    lda Zp_Next_eCutscene
    cmp #eCutscene::MermaidHut1BreakerCrypt
    beq @done
    @removeAlex:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kAlexActorIndex
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_MermaidHut1BreakerCrypt_sCutscene
.PROC DataA_Cutscene_MermaidHut1BreakerCrypt_sCutscene
    act_RunDialog eDialog::MermaidHut1BreakerCrypt1
    act_WaitFrames 30
    act_ShakeRoom 30
    act_WaitFrames 60
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexHolding
    act_RunDialog eDialog::MermaidHut1BreakerCrypt2
    act_JumpToMain Main_Breaker_FadeBackToBreakerRoom
.ENDPROC

.EXPORT DataA_Cutscene_MermaidHut1BreakerGarden_sCutscene
.PROC DataA_Cutscene_MermaidHut1BreakerGarden_sCutscene
    act_WaitFrames 60
    act_ShakeRoom 30
    act_WaitFrames 60
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
    ;; TODO: use a dialog function to fade to black and back
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_FirstMeeting3_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_FirstMeeting4_u8_arr
_GrantAsylum_sDialog:
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_GrantAsylum_u8_arr
    dlg_Func _HelpFramersFunc
_HelpFramersFunc:
    ldx #eFlag::MermaidHut1MetQueen  ; param: flag
    jsr FuncA_Dialog_AddQuestMarker
    ldya #_HelpFarmers_sDialog
    rts
_HelpFarmers_sDialog:
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_HelpFarmers_u8_arr
    dlg_Done
_GardenBossDead_sDialog:
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_GardenBossDead1_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_GardenBossDead2_u8_arr
_TempleProblem_sDialog:
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_TempleProblem_u8_arr
    dlg_Func _TempleEntryFunc
_TempleEntryFunc:
    ldx #eFlag::TempleEntryPermission  ; param: flag
    jsr FuncA_Dialog_AddQuestMarker
    ldya #_TempleEntry_sDialog
    rts
_TempleEntry_sDialog:
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
    dlg_Func _FindYourFriendsFunc
_FindYourFriendsFunc:
    ldx #eFlag::CoreSouthCorraWaiting  ; param: flag
    jsr FuncA_Dialog_AddQuestMarker
    ldya #_FindYourFriends_sDialog
    rts
_FindYourFriends_sDialog:
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_FindYourFriends_u8_arr
    dlg_Done
_KidsRescued_sDialog:
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_KidsRescued1_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1Queen_KidsRescued2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidHut1BreakerGarden_sDialog
.PROC DataA_Dialog_MermaidHut1BreakerGarden_sDialog
    dlg_Text MermaidEirene, DataA_Text0_MermaidHut1BreakerGarden_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidHut1BreakerCrypt1_sDialog
.PROC DataA_Dialog_MermaidHut1BreakerCrypt1_sDialog
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

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_MermaidHut1Guard_u8_arr
    .byte "All hail Queen Eirene!#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_FirstMeeting1_u8_arr
    .byte "So, you must be the$"
    .byte "human I've heard is$"
    .byte "running around.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_FirstMeeting2_u8_arr
    .byte "Humans belong on the$"
    .byte "surface, not here. So$"
    .byte "what are you doing$"
    .byte "down here among us?#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_FirstMeeting3_u8_arr
    .byte "...I see. So the orcs$"
    .byte "attacked, and now you$"
    .byte "are a refugee. This$"
    .byte "complicates things.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_FirstMeeting4_u8_arr
    .byte "I will be honest: I do$"
    .byte "not trust humans.$"
    .byte "However, I don't care$"
    .byte "for the orcs either.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_GrantAsylum_u8_arr
    .byte "I will grant you safe$"
    .byte "asylum in our village,$"
    .byte "on one condition: that$"
    .byte "you help us in return.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_HelpFarmers_u8_arr
    .byte "Speak with our farmers$"
    .byte "in this village. They$"
    .byte "have a problem a human$"
    .byte "could perhaps solve.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_GardenBossDead1_u8_arr
    .byte "I heard you helped our$"
    .byte "farmers. And you even$"
    .byte "survived. I thank you.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_GardenBossDead2_u8_arr
    .byte "Perhaps...perhaps you$"
    .byte "could help us with one$"
    .byte "more problem.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_TempleProblem_u8_arr
    .byte "There's a temple west$"
    .byte "of the gardens. It's$"
    .byte "very important to us.$"
    .byte "At least, it once was.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_TempleEntry_u8_arr
    .byte "I'd like you to visit$"
    .byte "the temple. The guards$"
    .byte "east of my hut can$"
    .byte "tell you more.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_TempleBossDead1_u8_arr
    .byte "I take it that you've$"
    .byte "seen the whole of the$"
    .byte "ruined temple? Maybe$"
    .byte "now you understand.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_TempleBossDead2_u8_arr
    .byte "Our two peoples built$"
    .byte "it together, centuries$"
    .byte "ago. It was to be a$"
    .byte "symbol of peace.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_TempleBossDead3_u8_arr
    .byte "But before long, the$"
    .byte "humans desecrated it$"
    .byte "into a mechanized$"
    .byte "fortress instead.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_TempleBossDead4_u8_arr
    .byte "Humans are just like$"
    .byte "the orcs. Violent and$"
    .byte "untrustworthy, despite$"
    .byte "our best efforts.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_TempleBossDead5_u8_arr
    .byte "But enough. My scouts$"
    .byte "tell me there is a way$"
    .byte "for you to reach your$"
    .byte "fellow villagers.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_OtherRuins_u8_arr
    .byte "There are...another$"
    .byte "kind of ruins buried$"
    .byte "just above our humble$"
    .byte "vale. Older ones.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_FindYourFriends_u8_arr
    .byte "If you climb upwards$"
    .byte "through there, you may$"
    .byte "be able to find and$"
    .byte "rescue your friends.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_KidsRescued1_u8_arr
    .byte "The children from your$"
    .byte "village have arrived$"
    .byte "safely. I have granted$"
    .byte "them asylum for now.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1Queen_KidsRescued2_u8_arr
    .byte "You can find them in$"
    .byte "the southeastern hut$"
    .byte "of this village.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1BreakerGarden_u8_arr
    .byte "What the...What did$"
    .byte "that human just do!?#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1BreakerCrypt_Part1_u8_arr
    .byte "Why are you so afraid$"
    .byte "of the old technology,$"
    .byte "anyway? Why won't you$"
    .byte "help us revive it?#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1BreakerCrypt_Part2_u8_arr
    .byte "More technology gives$"
    .byte "you more power. And$"
    .byte "too much power always,$"
    .byte "always corrupts.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1BreakerCrypt_Part3_u8_arr
    .byte "Don't take MY word for$"
    .byte "it. Human civilization$"
    .byte "collapsed! You can't$"
    .byte "be trusted with it.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1BreakerCrypt_Part4_u8_arr
    .byte "So what, we should all$"
    .byte "go back to being poor,$"
    .byte "and spending winters$"
    .byte "trying not to starve?#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1BreakerCrypt_Part5_u8_arr
    .byte "If high civilization$"
    .byte "failed last time, we$"
    .byte "should learn from it,$"
    .byte "and try again!#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1BreakerCrypt_Part6_u8_arr
    .byte "If you had learned$"
    .byte "anything, you would$"
    .byte "give up on this path.$"
    .byte "It's a dead end.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut1BreakerCrypt_Part7_u8_arr
    .byte "And if you'd learned$"
    .byte "anything about humans,$"
    .byte "you'd know that we$"
    .byte "NEVER give up.#"
.ENDPROC

;;;=========================================================================;;;
