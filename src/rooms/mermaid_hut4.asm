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
.INCLUDE "../device.inc"
.INCLUDE "../devices/flower.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Hut_sTileset
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT Func_CountDeliveredFlowers
.IMPORT Func_DropFlower
.IMPORT Func_IsFlagSet
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Func_UnlockDoorDevice
.IMPORT Ppu_ChrObjVillage
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_CarryingFlower_eFlag
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_DialogAnsweredYes_bool
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; The device index for the door leading to the cellar.
kCellarDoorDeviceIndex = 3

;;; An enum for numbers of flowers that can be collected.  This enum exists
;;; only for the benefit of a D_TABLE macro below.
.ENUM eNumFlowers
    Zero
    One
    Two
    Three
    Four
    Five
    Six
    Seven
    Eight
    Nine
    Ten
    Eleven
    Twelve
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Hut4_sRoom
.PROC DataC_Mermaid_Hut4_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, eArea::Mermaid
    d_byte MinimapStartRow_u8, 11
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
    d_addr Enter_func_ptr, FuncC_Mermaid_Hut4_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Mermaid_Hut4_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/data/mermaid_hut4.room"
    .assert * - :- = 16 * 15, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $50
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0020
    d_word Top_i16,   $00c4
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0090
    d_word PosY_i16, $00a8
    d_byte Param_byte, kTileIdMermaidFloristFirst
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eDialog::MermaidHut4Florist
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eDialog::MermaidHut4Florist
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eRoom::MermaidVillage
    D_END
    .assert * - :- = kCellarDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Locked
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eRoom::MermaidCellar
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

;;;=========================================================================;;;

.PROC FuncC_Mermaid_Hut4_EnterRoom
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidHut4OpenedCellar
    beq @done
    lda #eDevice::Door1Unlocked
    sta Ram_DeviceType_eDevice_arr + kCellarDoorDeviceIndex
    @done:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for this room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Mermaid_Hut4_DrawRoom
    ldx #kFirstFlowerFlag
    @loop:
    jsr Func_IsFlagSet  ; preserves X, sets Z if flag is not set
    beq @continue
    jsr FuncC_Mermaid_Hut4_DrawFlower  ; preserves X
    @continue:
    inx
    .assert kLastFlowerFlag < $ff, error
    cpx #kLastFlowerFlag + 1
    blt @loop
    rts
.ENDPROC

;;; Allocates and populates OAM slots for one delivered flower.
;;; @prereq PRGA_Objects is loaded.
;;; @param X The eFlag value for the flower.
;;; @preserve X
.PROC FuncC_Mermaid_Hut4_DrawFlower
    ;; Determine the position for the object.
    txa
    sub #kFirstFlowerFlag
    tay
    lda _PosX_u8_arr, y
    sta Zp_ShapePosX_i16 + 0
    lda _PosY_u8_arr, y
    sub Zp_RoomScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda #0
    sta Zp_ShapePosX_i16 + 1
    sta Zp_ShapePosY_i16 + 1
    ;; Draw the object.
    lda #kTileIdObjFlowerTop  ; param: tile ID
    ldy #kPaletteObjFlowerTop  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
_PosX_u8_arr:
    .byte $54, $64, $74, $84, $94, $a4, $54, $64, $74, $84, $94, $a4
    .assert * - _PosX_u8_arr = kNumFlowerFlags, error
_PosY_u8_arr:
    .byte $50, $50, $50, $50, $50, $50, $70, $70, $70, $70, $70, $70
    .assert * - _PosY_u8_arr = kNumFlowerFlags, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_MermaidHut4Florist_sDialog
.PROC DataA_Dialog_MermaidHut4Florist_sDialog
    dlg_Func _InitialDialogFunc
_InitialDialogFunc:
    ;; If Anna is carrying a flower, deliver it.
    lda Sram_CarryingFlower_eFlag
    beq @notCarryingFlower
    ldya #_BroughtFlower_sDialog
    rts
    @notCarryingFlower:
    ;; Otherwise, if Anna has already met the florist, repeat the florist's
    ;; last message.
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidHut4MetFlorist
    bne _CountFlowersFunc
    ;; Otherwise, play the conversation for meeting the florist.
    ldya #_MeetFlorist_sDialog
    rts
_MeetFlorist_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Meet1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Meet2_u8_arr
    dlg_Func _QuestionFunc
_QuestionFunc:
    bit Zp_DialogAnsweredYes_bool
    bmi @yes
    @no:
    ldya #_NeverMind_sDialog
    rts
    @yes:
    ldx #eFlag::MermaidHut4MetFlorist  ; param: flag
    jsr Func_SetFlag
    ldya #_Zero_sDialog
    rts
_NeverMind_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_NeverMind1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_NeverMind2_u8_arr
    dlg_Done
_BroughtFlower_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Brought_u8_arr
    dlg_Func _DeliverFlowerFunc
_DeliverFlowerFunc:
    ;; Mark that the player has met the florist (i.e. if the player brings a
    ;; flower before the initial meeting conversation, then we just won't do
    ;; that conversation).
    ldx #eFlag::MermaidHut4MetFlorist  ; param: flag
    jsr Func_SetFlag
    ;; Mark the carried flower as delivered.
    ldx Sram_CarryingFlower_eFlag  ; param: flag
    jsr Func_SetFlag
    ;; Mark the player as no longer carrying a flower.
    jsr Func_DropFlower
_CountFlowersFunc:
    jsr Func_CountDeliveredFlowers  ; returns A
    tax  ; num delivered flowers
    lda _DialogTable_ptr_0_arr, x
    ldy _DialogTable_ptr_1_arr, x
    rts
.REPEAT 2, table
    D_TABLE_LO table, _DialogTable_ptr_0_arr
    D_TABLE_HI table, _DialogTable_ptr_1_arr
    D_TABLE eNumFlowers
    d_entry table, Zero,   _Zero_sDialog
    d_entry table, One,    _One_sDialog
    d_entry table, Two,    _Two_sDialog
    d_entry table, Three,  _Three_sDialog
    d_entry table, Four,   _Four_sDialog
    d_entry table, Five,   _Five_sDialog
    d_entry table, Six,    _Six_sDialog
    d_entry table, Seven,  _Seven_sDialog
    d_entry table, Eight,  _Eight_sDialog
    d_entry table, Nine,   _Nine_sDialog
    d_entry table, Ten,    _Ten_sDialog
    d_entry table, Eleven, _Eleven_sDialog
    d_entry table, Twelve, _Twelve_sDialog
    D_END
.ENDREPEAT
_Zero_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Zero1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Zero2_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Zero3_u8_arr
    dlg_Done
_One_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_One1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_One2_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_One3_u8_arr
    dlg_Done
_Two_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Two1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Two2_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Two3_u8_arr
    dlg_Done
_Three_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Three1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Three2_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Three3_u8_arr
    dlg_Done
_Four_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Four1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Four2_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Four3_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Four4_u8_arr
    dlg_Done
_Five_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Five1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Five2_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Five3_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Five4_u8_arr
    dlg_Done
_Six_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Six1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Six2_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Six3_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Six4_u8_arr
    dlg_Done
_Seven_sDialog:
    ;; TODO
_Eight_sDialog:
    ;; TODO
_Nine_sDialog:
    ;; TODO
_Ten_sDialog:
    ;; TODO
_Eleven_sDialog:
    ;; TODO
_Twelve_sDialog:
    dlg_Func _TwelveFunc
_TwelveFunc:
    ldx #kCellarDoorDeviceIndex  ; param: device index
    jsr Func_UnlockDoorDevice
    ldx #eFlag::MermaidHut4OpenedCellar  ; param: flag
    jsr Func_SetFlag
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpBeep
    bne @allDone
    @openCellar:
    ldya #_OpenCellar_sDialog
    rts
    @allDone:
    ldya #_AllDone_sDialog
    rts
_OpenCellar_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Twelve1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Twelve2_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Twelve3_u8_arr
_AllDone_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_AllDone_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text1"

.PROC DataA_Text1_MermaidHut4Florist_Meet1_u8_arr
    .byte "Ah...you must be that$"
    .byte "human that I've been$"
    .byte "hearing about.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Meet2_u8_arr
    .byte "I don't suppose you'd$"
    .byte "like to do me a favor?%"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_NeverMind1_u8_arr
    .byte "Yes, well, I suppose$"
    .byte "you must be very busy,$"
    .byte "running around and$"
    .byte "causing trouble.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_NeverMind2_u8_arr
    .byte "Come back if you ever$"
    .byte "change your mind.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Zero1_u8_arr
    .byte "As you can see, my$"
    .byte "home is looking rather$"
    .byte "drab. Could you bring$"
    .byte "me a flower?#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Zero2_u8_arr
    .byte "If you go east from$"
    .byte "this village and then$"
    .byte "up a bit, you'll find$"
    .byte "the one I want.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Zero3_u8_arr
    .byte "It's very delicate.$"
    .byte "Don't get hurt and$"
    .byte "break it, or you'll$"
    .byte "have to get another.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Brought_u8_arr
    .byte "Ah, I see you've$"
    .byte "brought me a flower!$"
    .byte "How kind of you.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_One1_u8_arr
    .byte "It does look nice up$"
    .byte "there, don't you$"
    .byte "think?#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_One2_u8_arr
    .byte "Only...it seems lonely$"
    .byte "by itself. I suppose$"
    .byte "you'll need to find$"
    .byte "some more.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_One3_u8_arr
    .byte "Not from where you got$"
    .byte "this one, of course.$"
    .byte "You'll have to look$"
    .byte "elsewhere.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Two1_u8_arr
    .byte "You may be wondering$"
    .byte "why our queen doesn't$"
    .byte "trust humans. I assure$"
    .byte "you, she has reasons.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Two2_u8_arr
    .byte "Truth be told, I don't$"
    .byte "trust humans either.$"
    .byte "Though your bringing$"
    .byte "me flowers does help.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Two3_u8_arr
    .byte "Perhaps I could$"
    .byte "trouble you to find$"
    .byte "another? I would so$"
    .byte "appreciate it.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Three1_u8_arr
    .byte "Humans and mermaids$"
    .byte "used to be close$"
    .byte "friends, you know.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Three2_u8_arr
    .byte "But humans were never$"
    .byte "able to shed their$"
    .byte "violent ways, the way$"
    .byte "we mermaids have.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Three3_u8_arr
    .byte "And not just violence.$"
    .byte "Shortsightedness in$"
    .byte "general. Which is why$"
    .byte "so few humans remain.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Four1_u8_arr
    .byte "I suppose there's no$"
    .byte "hiding it: by now you$"
    .byte "have seen the complex$"
    .byte "above our vale.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Four2_u8_arr
    .byte "Unlike our temple,$"
    .byte "it was built by humans$"
    .byte "alone. It predates$"
    .byte "even us mermaids.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Four3_u8_arr
    .byte "And who knows? If not$"
    .byte "for it, perhaps human$"
    .byte "civilization could$"
    .byte "have survived.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Four4_u8_arr
    .byte "Probably not, though.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Five1_u8_arr
    .byte "We've noticed you've$"
    .byte "been restoring power$"
    .byte "to those ancient$"
    .byte "circuits, one by one.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Five2_u8_arr
    .byte "The queen isn't happy$"
    .byte "about it. But we are a$"
    .byte "people of peace, and$"
    .byte "she promised you aid.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Five3_u8_arr
    .byte "If you really want to$"
    .byte "doom your people all$"
    .byte "over again, I suppose$"
    .byte "that's your choice.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Five4_u8_arr
    .byte "But woe be upon you if$"
    .byte "you bring that down on$"
    .byte "us mermaids as well.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Six1_u8_arr
    .byte "Did you know there$"
    .byte "used to be a human$"
    .byte "city near here,$"
    .byte "centuries ago?#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Six2_u8_arr
    .byte "It was once the center$"
    .byte "of everything around$"
    .byte "here. A shining beacon$"
    .byte "on a hill.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Six3_u8_arr
    .byte "The humans reveled in$"
    .byte "all that they had$"
    .byte "built: civilization,$"
    .byte "sophistication.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Six4_u8_arr
    .byte "Now it's all forgotten$"
    .byte "and forever buried$"
    .byte "under the rubble.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Twelve1_u8_arr
    .byte "And that makes an even$"
    .byte "dozen! How lovely. I$"
    .byte "do appreciate all your$"
    .byte "help, young one.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Twelve2_u8_arr
    .byte "In exchange for this$"
    .byte "gift of beauty...I'd$"
    .byte "like to give you the$"
    .byte "gift of music.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_Twelve3_u8_arr
    .byte "I'll unlock my cellar.$"
    .byte "You may take what you$"
    .byte "find there.#"
.ENDPROC

.PROC DataA_Text1_MermaidHut4Florist_AllDone_u8_arr
    .byte "Perhaps this gift will$"
    .byte "give you a better use$"
    .byte "for all those terrible$"
    .byte "machines.#"
.ENDPROC

;;;=========================================================================;;;
