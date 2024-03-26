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

.IMPORT DataA_Room_Hut_sTileset
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjVillage

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Hut3_sRoom
.PROC DataC_Mermaid_Hut3_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, eArea::Mermaid
    d_byte MinimapStartRow_u8, 11
    d_byte MinimapStartCol_u8, 11
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
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/mermaid_hut3.room"
    .assert * - :- = 16 * 15, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $a0
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0030
    d_word Top_i16,   $00c4
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_word PosX_i16, $0040
    d_word PosY_i16, $00c8
    d_byte Param_byte, kTileIdMermaidDaphneFirst
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_word PosX_i16, $00a0
    d_word PosY_i16, $00c8
    d_byte Param_byte, kTileIdMermaidPhoebeFirst
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 3
    d_byte Target_byte, eDialog::MermaidHut3Daphne
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eDialog::MermaidHut3Daphne
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eDialog::MermaidHut3Phoebe
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eDialog::MermaidHut3Phoebe
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eRoom::MermaidVillage
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_MermaidHut3Daphne_sDialog
.PROC DataA_Dialog_MermaidHut3Daphne_sDialog
    dlg_Text MermaidDaphne, DataA_Text0_MermaidHut3Daphne_Intro_u8_arr
    dlg_IfSet MermaidSpringUnplugged, _HotSpringClosed_sDialog
_HotSpringOpen_sDialog:
    dlg_Text MermaidDaphne, DataA_Text0_MermaidHut3Daphne_Open_u8_arr
    dlg_Done
_HotSpringClosed_sDialog:
    dlg_Text MermaidDaphne, DataA_Text0_MermaidHut3Daphne_Closed_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidHut3Phoebe_sDialog
.PROC DataA_Dialog_MermaidHut3Phoebe_sDialog
    dlg_Text MermaidPhoebe, DataA_Text0_MermaidHut3Phoebe_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_MermaidHut3Daphne_Intro_u8_arr
    .byte "There's a natural hot$"
    .byte "spring just east of$"
    .byte "this village.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut3Daphne_Open_u8_arr
    .byte "The water is heated by$"
    .byte "magma flows far below.$"
    .byte "It's a great place to$"
    .byte "relax.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut3Daphne_Closed_u8_arr
    .byte "Unfortunately, all the$"
    .byte "water got drained out$"
    .byte "somehow. So now we$"
    .byte "can't use it.#"
.ENDPROC

.PROC DataA_Text0_MermaidHut3Phoebe_u8_arr
    .byte "You're so lucky that$"
    .byte "you get to go on an$"
    .byte "adventure. I'm stuck$"
    .byte "here at home.#"
.ENDPROC

;;;=========================================================================;;;
