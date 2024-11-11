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
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Hut_sTileset
.IMPORT DataA_Text1_MermaidHut5Marie_AfterCity1_u8_arr
.IMPORT DataA_Text1_MermaidHut5Marie_AfterCity2_u8_arr
.IMPORT DataA_Text1_MermaidHut5Marie_AfterCity3_u8_arr
.IMPORT DataA_Text1_MermaidHut5Marie_AfterCrypt1_u8_arr
.IMPORT DataA_Text1_MermaidHut5Marie_AfterCrypt2_u8_arr
.IMPORT DataA_Text1_MermaidHut5Marie_AfterMine_u8_arr
.IMPORT DataA_Text1_MermaidHut5Marie_AfterRescue1_u8_arr
.IMPORT DataA_Text1_MermaidHut5Marie_AfterRescue2_u8_arr
.IMPORT DataA_Text1_MermaidHut5Nora_AfterCity1_u8_arr
.IMPORT DataA_Text1_MermaidHut5Nora_AfterCity2_u8_arr
.IMPORT DataA_Text1_MermaidHut5Nora_AfterCrypt_u8_arr
.IMPORT DataA_Text1_MermaidHut5Nora_AfterMine_u8_arr
.IMPORT DataA_Text1_MermaidHut5Nora_AfterRescue_u8_arr
.IMPORT Data_Empty_sPlatform_arr
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjTown
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_ProgressFlags_arr

;;;=========================================================================;;;

;;; The actor index for Marie in this room.
kMarieActorIndex = 0
;;; The talk device indices for Marie in this room.
kMarieDeviceIndexLeft = 1
kMarieDeviceIndexRight = 0

;;; The actor index for Nora in this room.
kNoraActorIndex = 1
;;; The talk device indices for Nora in this room.
kNoraDeviceIndexLeft = 3
kNoraDeviceIndexRight = 2

;;; The actor index for Nina in this room.
kNinaActorIndex = 2

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Hut5_sRoom
.PROC DataC_Mermaid_Hut5_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, bRoom::ReduceMusic | eArea::Mermaid
    d_byte MinimapStartRow_u8, 11
    d_byte MinimapStartCol_u8, 13
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTown)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Hut_sTileset
    d_addr Platforms_sPlatform_arr_ptr, Data_Empty_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncA_Room_MermaidHut5_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/mermaid_hut5.room"
    .assert * - :- = 16 * 15, error
_Actors_sActor_arr:
:   .assert * - :- = kMarieActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0050
    d_word PosY_i16, $00b8
    d_byte Param_byte, eNpcChild::MarieStanding
    D_END
    .assert * - :- = kNoraActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0090
    d_word PosY_i16, $00b8
    d_byte Param_byte, eNpcChild::NoraStanding
    D_END
    .assert * - :- = kNinaActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcToddler
    d_word PosX_i16, $0080
    d_word PosY_i16, $00b8
    d_byte Param_byte, 55
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kMarieDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eDialog::MermaidHut5Marie
    D_END
    .assert * - :- = kMarieDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eDialog::MermaidHut5Marie
    D_END
    .assert * - :- = kNoraDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eDialog::MermaidHut5Nora
    D_END
    .assert * - :- = kNoraDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eDialog::MermaidHut5Nora
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eRoom::MermaidVillage
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_MermaidHut5_EnterRoom
    ;; Until the kids are rescued, they are in PrisonUpper, not here.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperFreedKids
    bne @keepKids
    @removeKids:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kMarieActorIndex
    sta Ram_ActorType_eActor_arr + kNoraActorIndex
    sta Ram_ActorType_eActor_arr + kNinaActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kMarieDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kMarieDeviceIndexRight
    sta Ram_DeviceType_eDevice_arr + kNoraDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kNoraDeviceIndexRight
    @keepKids:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_MermaidHut5Marie_sDialog
.PROC DataA_Dialog_MermaidHut5Marie_sDialog
    dlg_IfSet BreakerCity, _AfterCity_sDialog
    dlg_IfSet BreakerMine, _AfterMine_sDialog
    dlg_IfSet BreakerCrypt, _AfterCrypt_sDialog
_AfterRescue_sDialog:
    dlg_Text ChildMarie, DataA_Text1_MermaidHut5Marie_AfterRescue1_u8_arr
    dlg_Text ChildMarie, DataA_Text1_MermaidHut5Marie_AfterRescue2_u8_arr
    dlg_Done
_AfterCrypt_sDialog:
    dlg_Text ChildMarie, DataA_Text1_MermaidHut5Marie_AfterCrypt1_u8_arr
    dlg_Text ChildMarie, DataA_Text1_MermaidHut5Marie_AfterCrypt2_u8_arr
    dlg_Done
_AfterMine_sDialog:
    dlg_Text ChildMarie, DataA_Text1_MermaidHut5Marie_AfterMine_u8_arr
    dlg_Done
_AfterCity_sDialog:
    dlg_Text ChildMarie, DataA_Text1_MermaidHut5Marie_AfterCity1_u8_arr
    dlg_Text ChildMarie, DataA_Text1_MermaidHut5Marie_AfterCity2_u8_arr
    dlg_Text ChildMarie, DataA_Text1_MermaidHut5Marie_AfterCity3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidHut5Nora_sDialog
.PROC DataA_Dialog_MermaidHut5Nora_sDialog
    dlg_IfSet BreakerCity, _AfterCity_sDialog
    dlg_IfSet BreakerMine, _AfterMine_sDialog
    dlg_IfSet BreakerCrypt, _AfterCrypt_sDialog
_AfterRescue_sDialog:
    dlg_Text ChildNora, DataA_Text1_MermaidHut5Nora_AfterRescue_u8_arr
    dlg_Done
_AfterCrypt_sDialog:
    dlg_Text ChildNora, DataA_Text1_MermaidHut5Nora_AfterCrypt_u8_arr
    dlg_Done
_AfterMine_sDialog:
    dlg_Text ChildNora, DataA_Text1_MermaidHut5Nora_AfterMine_u8_arr
    dlg_Done
_AfterCity_sDialog:
    dlg_Text ChildNora, DataA_Text1_MermaidHut5Nora_AfterCity1_u8_arr
    dlg_Text ChildNora, DataA_Text1_MermaidHut5Nora_AfterCity2_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
