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
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_House_sTileset
.IMPORT DataA_Text0_TownHouse6Elder_Part1_u8_arr
.IMPORT DataA_Text0_TownHouse6Elder_Part2_u8_arr
.IMPORT Data_Empty_sPlatform_arr
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjVillage
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for Elder Roman in this room.
kElderActorIndex = 0

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; A timer for controlling Elder Roman's rocking chair.
    RockingTimer_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Town"

.EXPORT DataC_Town_House6_sRoom
.PROC DataC_Town_House6_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, bRoom::ReduceMusic | eArea::Town
    d_byte MinimapStartRow_u8, 0
    d_byte MinimapStartCol_u8, 15
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjVillage)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_House_sTileset
    d_addr Platforms_sPlatform_arr_ptr, Data_Empty_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncC_Town_House6_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Town_House6_TickRoom
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/town_house6.room"
    .assert * - :- = 16 * 15, error
_Actors_sActor_arr:
:   .assert * - :- = kElderActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0060
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcAdult::HumanElder1
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eDialog::TownHouse6Elder
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eDialog::TownHouse6Elder
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eRoom::TownOutdoors
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC FuncC_Town_House6_EnterRoom
    lda #$ff
    sta Ram_ActorState2_byte_arr + kElderActorIndex
    rts
.ENDPROC

.PROC FuncC_Town_House6_TickRoom
    inc Zp_RoomState + sState::RockingTimer_u8
    lda Zp_RoomState + sState::RockingTimer_u8
    and #$20
    beq @forth
    @back:
    lda #eNpcAdult::HumanElder2
    .assert eNpcAdult::HumanElder2 > 0, error
    bne @setState
    @forth:
    lda #eNpcAdult::HumanElder1
    @setState:
    sta Ram_ActorState1_byte_arr + kElderActorIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_TownHouse6Elder_sDialog
.PROC DataA_Dialog_TownHouse6Elder_sDialog
    dlg_Text AdultElder, DataA_Text0_TownHouse6Elder_Part1_u8_arr
    dlg_Text AdultElder, DataA_Text0_TownHouse6Elder_Part2_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
