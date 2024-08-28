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
.IMPORT DataA_Text1_MermaidHut4Florist_AllDone_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Brought_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Eight1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Eight2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Eight3_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Eight4_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Eleven1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Eleven2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Eleven3_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Eleven4_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Five1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Five2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Five3_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Five4_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Four1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Four2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Four3_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Four4_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Meet1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Meet2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_NeverMind1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_NeverMind2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Nine1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Nine2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Nine3_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Nine4_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_One1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_One2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_One3_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Seven1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Seven2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Seven3_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Seven4_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Six1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Six2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Six3_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Six4_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Ten1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Ten2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Ten3_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Ten4_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Three1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Three2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Three3_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Twelve1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Twelve2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Twelve3_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Two1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Two2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Two3_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Zero1_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Zero2_u8_arr
.IMPORT DataA_Text1_MermaidHut4Florist_Zero3_u8_arr
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
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

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
:   .incbin "out/rooms/mermaid_hut4.room"
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
    d_byte Param_byte, eNpcAdult::MermaidFlorist
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
    dlg_Func @func
    @func:
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
    dlg_IfYes _Zero_sDialog
_NeverMind_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_NeverMind1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_NeverMind2_u8_arr
    dlg_Done
_BroughtFlower_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Brought_u8_arr
    ;; Mark that the player has met the florist (i.e. if the player brings a
    ;; flower before the initial meeting conversation, then we just won't do
    ;; that conversation).
    dlg_Call _MetFlorist
    dlg_Func _DeliverFlowerFunc
_DeliverFlowerFunc:
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
    D_TABLE 13
    d_entry table, 0,    _Zero_sDialog
    d_entry table, 1,     _One_sDialog
    d_entry table, 2,     _Two_sDialog
    d_entry table, 3,   _Three_sDialog
    d_entry table, 4,    _Four_sDialog
    d_entry table, 5,    _Five_sDialog
    d_entry table, 6,     _Six_sDialog
    d_entry table, 7,   _Seven_sDialog
    d_entry table, 8,   _Eight_sDialog
    d_entry table, 9,    _Nine_sDialog
    d_entry table, 10,    _Ten_sDialog
    d_entry table, 11, _Eleven_sDialog
    d_entry table, 12, _Twelve_sDialog
    D_END
.ENDREPEAT
_MetFlorist:
    ldx #eFlag::MermaidHut4MetFlorist  ; param: flag
    jmp Func_SetFlag
_Zero_sDialog:
    dlg_Call _MetFlorist
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
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Seven1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Seven2_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Seven3_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Seven4_u8_arr
    dlg_Done
_Eight_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Eight1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Eight2_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Eight3_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Eight4_u8_arr
    dlg_Done
_Nine_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Nine1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Nine2_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Nine3_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Nine4_u8_arr
    dlg_Done
_Ten_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Ten1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Ten2_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Ten3_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Ten4_u8_arr
    dlg_Done
_Eleven_sDialog:
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Eleven1_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Eleven2_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Eleven3_u8_arr
    dlg_Text MermaidFlorist, DataA_Text1_MermaidHut4Florist_Eleven4_u8_arr
    dlg_Done
_Twelve_sDialog:
    dlg_Func @func
    @func:
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
