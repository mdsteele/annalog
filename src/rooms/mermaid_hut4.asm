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
.IMPORT Func_CountDeliveredFlowers
.IMPORT Func_DropFlower
.IMPORT Func_IsFlagSet
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Func_UnlockDoorDevice
.IMPORT Ppu_ChrObjVillage
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Sram_CarryingFlower_eFlag
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_DialogAnsweredYes_bool
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte

;;;=========================================================================;;;

;;; The device index for the door leading to the cellar.
kCellarDoorDeviceIndex = 3

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
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Mermaid_Hut4_DrawRoom
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
    D_END
_TerrainData:
:   .incbin "out/data/mermaid_hut4.room"
    .assert * - :- = 16 * 16, error
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
    d_byte Target_u8, eDialog::MermaidHut4Florist
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 9
    d_byte Target_u8, eDialog::MermaidHut4Florist
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_u8, eRoom::MermaidVillage
    D_END
    .assert * - :- = kCellarDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LockedDoor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 11
    d_byte Target_u8, eRoom::MermaidCellar
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

;;;=========================================================================;;;

.PROC FuncC_Mermaid_Hut4_EnterRoom
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidHut4OpenedCellar
    beq @done
    lda #eDevice::UnlockedDoor
    sta Ram_DeviceType_eDevice_arr + kCellarDoorDeviceIndex
    @done:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for this room.
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
;;; @param X The eFlag value for the flower.
;;; @preserve X
.PROC FuncC_Mermaid_Hut4_DrawFlower
    ;; Determine the position for the object.
    txa
    sub #kFirstFlowerFlag
    tay
    lda _PosX_u8_arr, y
    sta Zp_Tmp1_byte  ; X-pos
    lda _PosY_u8_arr, y
    sub Zp_RoomScrollY_u8
    sta Zp_Tmp2_byte  ; Y-pos
    ;; Allocate the object.
    ldy Zp_OamOffset_u8
    lda Zp_Tmp1_byte  ; X-pos
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    lda Zp_Tmp2_byte  ; Y-pos
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    lda #kTileIdObjFlowerTop
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjFlowerTop
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    tya
    add #.sizeof(sObj)
    sta Zp_OamOffset_u8
    rts
_PosX_u8_arr:
    .byte $54, $64, $74, $84, $94, $a4, $54, $64, $74, $84, $94, $a4
    .assert * - _PosX_u8_arr = kNumFlowerFlags, error
_PosY_u8_arr:
    .byte $4f, $4f, $4f, $4f, $4f, $4f, $6f, $6f, $6f, $6f, $6f, $6f
    .assert * - _PosY_u8_arr = kNumFlowerFlags, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_MermaidHut4Florist_sDialog
.PROC DataA_Dialog_MermaidHut4Florist_sDialog
    .addr _InitialDialogFunc
_InitialDialogFunc:
    lda Sram_CarryingFlower_eFlag
    beq @notCarryingFlower
    ldya #_BroughtFlower_sDialog
    rts
    @notCarryingFlower:
    jsr Func_CountDeliveredFlowers  ; returns A and Z
    bne @hasDeliveredSomeFlowers
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidHut4MetFlorist
    bne @hasMetFlorist
    ldya #_MeetFlorist_sDialog
    rts
    @hasMetFlorist:
    ldya #_NoFlowersYet_sDialog
    rts
    @hasDeliveredSomeFlowers:
    cmp #kNumFlowerFlags
    bge @hasDeliveredAllFlowers
    ldya #_WantMoreFlowers_sDialog
    rts
    @hasDeliveredAllFlowers:
    jsr FuncA_Dialog_MermaidHut4_OpenCellarDoor
    ldya #_AllDone_sDialog
    rts
_MeetFlorist_sDialog:
    .word ePortrait::Florist
    .byte "Ah...you must be that$"
    .byte "human that I've been$"
    .byte "hearing about.#"
    .word ePortrait::Florist
    .byte "I don't suppose you'd$"
    .byte "like to do me a favor?%"
    .addr _QuestionFunc
_QuestionFunc:
    bit Zp_DialogAnsweredYes_bool
    bmi @yes
    @no:
    ldya #_NeverMind_sDialog
    rts
    @yes:
    ldx #eFlag::MermaidHut4MetFlorist  ; param: flag
    jsr Func_SetFlag
    ldya #_NoFlowersYet_sDialog
    rts
_NeverMind_sDialog:
    .word ePortrait::Florist
    .byte "Yes, well, I suppose$"
    .byte "you must be very busy,$"
    .byte "running around and$"
    .byte "causing trouble.#"
    .word ePortrait::Florist
    .byte "Come back if you ever$"
    .byte "change your mind.#"
    .word ePortrait::Done
_NoFlowersYet_sDialog:
    .word ePortrait::Florist
    .byte "As you can see, my$"
    .byte "home is looking rather$"
    .byte "drab. Could you bring$"
    .byte "me a flower?#"
    .word ePortrait::Florist
    .byte "If you go east from$"
    .byte "this village and then$"
    .byte "up a bit, you'll find$"
    .byte "the one I want.#"
    .word ePortrait::Florist
    .byte "It's very delicate.$"
    .byte "Don't get hurt and$"
    .byte "break it, or you'll$"
    .byte "have to get another.#"
    .word ePortrait::Done
_BroughtFlower_sDialog:
    .word ePortrait::Florist
    .byte "Ah, I see you've$"
    .byte "brought me a flower!$"
    .byte "How kind of you.#"
    .addr _DeliverFlowerFunc
_DeliverFlowerFunc:
    ;; Mark the carried flower as delivered.
    ldx Sram_CarryingFlower_eFlag  ; param: flag
    jsr Func_SetFlag
    ;; Mark the player as no longer carrying a flower.
    jsr Func_DropFlower
    ;; Check if we have all the flowers yet.
    jsr Func_CountDeliveredFlowers  ; returns A and Z
    cmp #kNumFlowerFlags
    bge @allFlowersDelivered
    ldya #_WantMoreFlowers_sDialog
    rts
    @allFlowersDelivered:
    jsr FuncA_Dialog_MermaidHut4_OpenCellarDoor
    ldya #_DeliveredLastFlower_sDialog
    rts
_WantMoreFlowers_sDialog:
    .word ePortrait::Florist
    .byte "It does look nice up$"
    .byte "there, don't you$"
    .byte "think?#"
    .word ePortrait::Florist
    .byte "Only...it seems lonely$"
    .byte "by itself. I suppose$"
    .byte "you'll need to find$"
    .byte "some more.#"
    .word ePortrait::Florist
    .byte "Not from where you got$"
    .byte "this one, of course.$"
    .byte "You'll have to look$"
    .byte "elsewhere.#"
    .word ePortrait::Done
_DeliveredLastFlower_sDialog:
    .word ePortrait::Florist
    .byte "And that makes an even$"
    .byte "dozen! How lovely. I$"
    .byte "do appreciate all your$"
    .byte "help, young one.#"
    .word ePortrait::Florist
    .byte "In exchange for this$"
    .byte "gift of beauty...I'd$"
    .byte "like to give you the$"
    .byte "gift of music.#"
    .word ePortrait::Florist
    .byte "I'll unlock my cellar.$"
    .byte "You may take what you$"
    .byte "find there.#"
_AllDone_sDialog:
    .word ePortrait::Florist
    .byte "Perhaps this gift will$"
    .byte "give you a better use$"
    .byte "for all those terrible$"
    .byte "machines.#"
    .word ePortrait::Done
.ENDPROC

;;; Unlocks the cellar door in this room, and sets the flag indicating that the
;;; door is open.
.PROC FuncA_Dialog_MermaidHut4_OpenCellarDoor
    ldx #kCellarDoorDeviceIndex  ; param: device index
    jsr Func_UnlockDoorDevice
    ldx #eFlag::MermaidHut4OpenedCellar  ; param: flag
    jmp Func_SetFlag
.ENDPROC

;;;=========================================================================;;;
