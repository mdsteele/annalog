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
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_MermaidAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_MermaidAreaName_u8_arr
.IMPORT DataA_Room_Hut_sTileset
.IMPORT FuncA_Dialog_AddQuestMarker
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjTownsfolk
.IMPORT Sram_ProgressFlags_arr

;;;=========================================================================;;;

;;; The dialog indices for the mermaids in this room.
kMermaidGuardDialogIndex = 0
kMermaidQueenDialogIndex = 1

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Hut1_sRoom
.PROC DataC_Mermaid_Hut1_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 10
    d_byte MinimapStartCol_u8, 12
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTownsfolk)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_MermaidAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_MermaidAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Hut_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    .linecont +
    d_addr Dialogs_sDialog_ptr_arr_ptr, \
           DataA_Dialog_MermaidHut1_sDialog_ptr_arr
    .linecont -
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Init_func_ptr, Func_Noop
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/mermaid_hut1.room"
    .assert * - :- = 16 * 16, error
_Platforms_sPlatform_arr:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $e0
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0010
    d_word Top_i16,   $00c4
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_byte TileRow_u8, 25
    d_byte TileCol_u8, 8
    d_byte Param_byte, kTileIdMermaidGuardMFirst
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaidQueen
    d_byte TileRow_u8, 21
    d_byte TileCol_u8, 24
    d_byte Param_byte, 0
    D_END
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 3
    d_byte Target_u8, kMermaidGuardDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_u8, kMermaidGuardDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 11
    d_byte Target_u8, kMermaidQueenDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 12
    d_byte Target_u8, kMermaidQueenDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 7
    d_byte Target_u8, eRoom::MermaidVillage
    D_END
    .byte eDevice::None
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the MermaidHut1 room.
.PROC DataA_Dialog_MermaidHut1_sDialog_ptr_arr
:   .assert * - :- = kMermaidGuardDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_MermaidHut1_MermaidGuard_sDialog
    .assert * - :- = kMermaidQueenDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_MermaidHut1_MermaidQueen_sDialog
.ENDPROC

.PROC DataA_Dialog_MermaidHut1_MermaidGuard_sDialog
    .word ePortrait::Man
    .byte "All hail Queen Eirene!#"
    .word ePortrait::Done
.ENDPROC

.PROC DataA_Dialog_MermaidHut1_MermaidQueen_sDialog
    .addr _InitialFunc
_InitialFunc:
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidHut1MetQueen
    bne @grantAsylum
    @firstMeeting:
    ldya #_FirstMeeting_sDialog
    rts
    @grantAsylum:
    ldya #_GrantAsylum_sDialog
    rts
_FirstMeeting_sDialog:
    .word ePortrait::Mermaid
    .byte "So, you must be the$"
    .byte "human I've heard is$"
    .byte "running around.#"
    .word ePortrait::Mermaid
    .byte "Humans belong on the$"
    .byte "surface, not here. So$"
    .byte "what are you doing$"
    .byte "down here among us?#"
    ;; TODO: use a dialog function to fade to black and back
    .word ePortrait::Mermaid
    .byte "...I see. So the orcs$"
    .byte "attacked, and now you$"
    .byte "are a refugee. This$"
    .byte "complicates things.#"
    .word ePortrait::Mermaid
    .byte "I will be honest. I do$"
    .byte "not trust humans.$"
    .byte "However, I don't care$"
    .byte "for the orcs either.#"
_GrantAsylum_sDialog:
    .word ePortrait::Mermaid
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
    .word ePortrait::Mermaid
    .byte "Speak with our farmers$"
    .byte "in this village. They$"
    .byte "have a problem a human$"
    .byte "could perhaps solve.#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;
