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
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_House_sTileset
.IMPORT Data_Empty_sPlatform_arr
.IMPORT FuncA_Room_PlaySfxMetallicClang
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjVillage
.IMPORT Ram_ActorState1_byte_arr
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for the blacksmith in this room.
kSmithActorIndex = 0

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; A timer for controlling the smith's hammering animation.
    HammerTimer_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Town"

.EXPORT DataC_Town_House3_sRoom
.PROC DataC_Town_House3_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, eArea::Town
    d_byte MinimapStartRow_u8, 0
    d_byte MinimapStartCol_u8, 12
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
    d_addr Enter_func_ptr, FuncC_Town_House3_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Town_House3_TickRoom
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/town_house3.room"
    .assert * - :- = 16 * 15, error
_Actors_sActor_arr:
:   .assert * - :- = kSmithActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $00a0
    d_word PosY_i16, $00c8
    d_byte Param_byte, kTileIdAdultSmith1
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eRoom::TownOutdoors
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eDialog::TownHouse3Smith
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eDialog::TownHouse3Smith
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC FuncC_Town_House3_EnterRoom
    lda #45
    sta Zp_RoomState + sState::HammerTimer_u8
    rts
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Town_House3_TickRoom
    ;; If the player avatar is near the smith (i.e. in the right half of the
    ;; room), then have the smith lower his hammer.
    lda Zp_AvatarPosX_i16 + 0
    bmi @lowerHammer
    ;; Otherwise, have the smith periodically strike the anvil with his hammer.
    @farFromSmith:
    inc Zp_RoomState + sState::HammerTimer_u8
    lda Zp_RoomState + sState::HammerTimer_u8
    cmp #70
    beq @strikeHammer
    cmp #50
    bne @done
    @raiseHammer:
    lda #kTileIdAdultSmith2
    .assert kTileIdAdultSmith2 > 0, error
    bne @setSmithState  ; unconditional
    @strikeHammer:
    jsr FuncA_Room_PlaySfxMetallicClang
    @lowerHammer:
    lda #0
    sta Zp_RoomState + sState::HammerTimer_u8
    lda #kTileIdAdultSmith1
    @setSmithState:
    sta Ram_ActorState1_byte_arr + kSmithActorIndex
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_TownHouse3Smith_sDialog
.PROC DataA_Dialog_TownHouse3Smith_sDialog
    dlg_Text AdultSmith, DataA_Text0_TownHouse3Smith_Part1_u8_arr
    dlg_Text AdultSmith, DataA_Text0_TownHouse3Smith_Part2_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_TownHouse3Smith_Part1_u8_arr
    .byte "You lookin' fer yer$"
    .byte "brother? Haven't seen$"
    .byte "`im. Probably pokin'$"
    .byte "around somewhere.#"
.ENDPROC

.PROC DataA_Text0_TownHouse3Smith_Part2_u8_arr
    .byte "That boy's a good$"
    .byte "apprentice. Good smith$"
    .byte "someday. Too curious$"
    .byte "fer `is own good, tho.#"
.ENDPROC

;;;=========================================================================;;;
