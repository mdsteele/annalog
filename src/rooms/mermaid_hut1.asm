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
.IMPORT Sram_ProgressFlags_arr

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
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Hut_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
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
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_word PosX_i16, $0040
    d_word PosY_i16, $00c8
    d_byte Param_byte, kTileIdMermaidGuardMFirst
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
    d_byte Target_u8, eDialog::MermaidHut1Guard
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_u8, eDialog::MermaidHut1Guard
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 11
    d_byte Target_u8, eDialog::MermaidHut1Queen
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 12
    d_byte Target_u8, eDialog::MermaidHut1Queen
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 7
    d_byte Target_u8, eRoom::MermaidVillage
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_MermaidHut1BreakerGarden_sCutscene
.PROC DataA_Cutscene_MermaidHut1BreakerGarden_sCutscene
    .byte eAction::WaitFrames, 60
    .byte eAction::ShakeRoom, 30
    .byte eAction::WaitFrames, 60
    .byte eAction::RunDialog, eDialog::MermaidHut1BreakerGarden
    .byte eAction::JumpToMain
    .addr Main_Breaker_FadeBackToBreakerRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_MermaidHut1Guard_sDialog
.PROC DataA_Dialog_MermaidHut1Guard_sDialog
    .word ePortrait::AdultMan
    .byte "All hail Queen Eirene!#"
    .word ePortrait::Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidHut1Queen_sDialog
.PROC DataA_Dialog_MermaidHut1Queen_sDialog
    .addr _InitialFunc
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
    jmp _Quest3Func
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
    ldya #_GardenBossDefeated_sDialog
    rts
    @templeProblem:
    ldya #_TempleProblem_sDialog
    rts
_Quest3Func:
    flag_bit Sram_ProgressFlags_arr, eFlag::CoreSouthCorraWaiting
    bne @otherRuins
    ldya #_TempleBossDefeated_sDialog
    rts
    @otherRuins:
    ldya #_OtherRuins_sDialog
    rts
_FirstMeeting_sDialog:
    .word ePortrait::MermaidEirene
    .byte "So, you must be the$"
    .byte "human I've heard is$"
    .byte "running around.#"
    .word ePortrait::MermaidEirene
    .byte "Humans belong on the$"
    .byte "surface, not here. So$"
    .byte "what are you doing$"
    .byte "down here among us?#"
    ;; TODO: use a dialog function to fade to black and back
    .word ePortrait::MermaidEirene
    .byte "...I see. So the orcs$"
    .byte "attacked, and now you$"
    .byte "are a refugee. This$"
    .byte "complicates things.#"
    .word ePortrait::MermaidEirene
    .byte "I will be honest: I do$"
    .byte "not trust humans.$"
    .byte "However, I don't care$"
    .byte "for the orcs either.#"
_GrantAsylum_sDialog:
    .word ePortrait::MermaidEirene
    .byte "I will grant you safe$"
    .byte "asylum in our village,$"
    .byte "on one condition: that$"
    .byte "you help us in return.#"
    .addr _HelpFramersFunc
_HelpFramersFunc:
    ldx #eFlag::MermaidHut1MetQueen  ; param: flag
    jsr FuncA_Dialog_AddQuestMarker
    ldya #_HelpFarmers_sDialog
    rts
_HelpFarmers_sDialog:
    .word ePortrait::MermaidEirene
    .byte "Speak with our farmers$"
    .byte "in this village. They$"
    .byte "have a problem a human$"
    .byte "could perhaps solve.#"
    .word ePortrait::Done
_GardenBossDefeated_sDialog:
    .word ePortrait::MermaidEirene
    .byte "I heard you helped our$"
    .byte "farmers. And you even$"
    .byte "survived. I thank you.#"
    .word ePortrait::MermaidEirene
    .byte "Perhaps...perhaps you$"
    .byte "could help us with one$"
    .byte "more problem.#"
_TempleProblem_sDialog:
    .word ePortrait::MermaidEirene
    .byte "There's a temple west$"
    .byte "of the gardens. It's$"
    .byte "very important to us.$"
    .byte "At least, it once was.#"
    .addr _TemplePermissionFunc
_TemplePermissionFunc:
    ldx #eFlag::TempleEntryPermission  ; param: flag
    jsr FuncA_Dialog_AddQuestMarker
    ldya #_TemplePermission_sDialog
    rts
_TemplePermission_sDialog:
    .word ePortrait::MermaidEirene
    .byte "I'd like you to visit$"
    .byte "the temple. The guards$"
    .byte "east of my hut can$"
    .byte "tell you more.#"
    .word ePortrait::Done
_TempleBossDefeated_sDialog:
    .word ePortrait::MermaidEirene
    .byte "I take it that you've$"
    .byte "seen the whole of the$"
    .byte "ruined temple? Maybe$"
    .byte "now you understand.#"
    .word ePortrait::MermaidEirene
    .byte "Our two peoples built$"
    .byte "it together, centuries$"
    .byte "ago. It was to be a$"
    .byte "symbol of peace.#"
    .word ePortrait::MermaidEirene
    .byte "But before long, the$"
    .byte "humans desecrated it$"
    .byte "into a mechanized$"
    .byte "fortress instead.#"
    .word ePortrait::MermaidEirene
    .byte "Humans are just like$"
    .byte "the orcs. Violent and$"
    .byte "untrustworthy, despite$"
    .byte "our best efforts.#"
    .word ePortrait::MermaidEirene
    .byte "But enough. My scouts$"
    .byte "tell me there is a way$"
    .byte "for you to reach your$"
    .byte "fellow villagers.#"
_OtherRuins_sDialog:
    .word ePortrait::MermaidEirene
    .byte "There are...another$"
    .byte "kind of ruins buried$"
    .byte "just above our humble$"
    .byte "vale. Older ones.#"
    .addr _FindYourFriendsFunc
_FindYourFriendsFunc:
    ldx #eFlag::CoreSouthCorraWaiting  ; param: flag
    jsr FuncA_Dialog_AddQuestMarker
    ldya #_FindYourFriends_sDialog
    rts
_FindYourFriends_sDialog:
    .word ePortrait::MermaidEirene
    .byte "If you climb upwards$"
    .byte "through there, you may$"
    .byte "be able to find and$"
    .byte "rescue your friends.#"
    .word ePortrait::Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidHut1BreakerGarden_sDialog
.PROC DataA_Dialog_MermaidHut1BreakerGarden_sDialog
    .word ePortrait::MermaidEirene
    .byte "What the...What did$"
    .byte "that human just do!?#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;
