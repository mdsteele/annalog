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
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"
.INCLUDE "../scroll.inc"

.IMPORT DataA_Room_Core_sTileset
.IMPORT Data_Empty_sDevice_arr
.IMPORT Data_Empty_sPlatform_arr
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjCity
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ProgressFlags_arr
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Camera_bScroll
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8

;;;=========================================================================;;;

;;; The actor index for the orc baddie in this room.
kOrcActorIndex = 0

;;; The room pixel X- and Y-positions where the scroll lock axis changes.
kScrollCutoffPosX = $01a8
kScrollCutoffPosY = $00c0

;;;=========================================================================;;;

.SEGMENT "PRGC_Core"

.EXPORT DataC_Core_West_sRoom
.PROC DataC_Core_West_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0110
    d_byte Flags_bRoom, bRoom::Tall | eArea::Core
    d_byte MinimapStartRow_u8, 2
    d_byte MinimapStartCol_u8, 10
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCity)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr Platforms_sPlatform_arr_ptr, Data_Empty_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, Data_Empty_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_CoreWest_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_CoreWest_UpdateScrollLock
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/core_west.room"
    .assert * - :- = 34 * 24, error
_Actors_sActor_arr:
:   .assert * - :- = kOrcActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadOrc
    d_word PosX_i16, $006a
    d_word PosY_i16, $00b8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadRhino
    d_word PosX_i16, $018c
    d_word PosY_i16, $00d8
    d_byte Param_byte, bObj::FlipH
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadRhino
    d_word PosX_i16, $018c
    d_word PosY_i16, $0118
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcBlinky
    d_word PosX_i16, $01f8
    d_word PosY_i16, $0078
    d_byte Param_byte, %01010101
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcBlinky
    d_word PosX_i16, $01f8
    d_word PosY_i16, $00a8
    d_byte Param_byte, %01010101
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcBlinky
    d_word PosX_i16, $0118
    d_word PosY_i16, $00c8
    d_byte Param_byte, %00111000
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcBlinky
    d_word PosX_i16, $01e8
    d_word PosY_i16, $0158
    d_byte Param_byte, %00011110
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::PrisonEast
    d_byte SpawnBlock_u8, 7
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CoreLock
    d_byte SpawnBlock_u8, 9
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::CoreJunction
    d_byte SpawnBlock_u8, 20
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_CoreWest_EnterRoom
    flag_bit Ram_ProgressFlags_arr, eFlag::PrisonUpperFreedKids
    beq @keepOrc
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kOrcActorIndex
    @keepOrc:
    fall FuncA_Room_CoreWest_UpdateScrollLock
.ENDPROC

.PROC FuncA_Room_CoreWest_UpdateScrollLock
    lda Zp_AvatarPosY_i16 + 0
    cmp #<kScrollCutoffPosY
    lda Zp_AvatarPosY_i16 + 1
    sbc #>kScrollCutoffPosY
    bge _LockHorz
    lda Zp_AvatarPosX_i16 + 0
    cmp #<kScrollCutoffPosX
    lda Zp_AvatarPosX_i16 + 1
    sbc #>kScrollCutoffPosX
    blt _LockVert
_LockHorz:
    ldax #$0110
    stax Zp_RoomScrollX_u16
    lda #bScroll::LockHorz
    sta Zp_Camera_bScroll
    rts
_LockVert:
    lda #0
    sta Zp_RoomScrollY_u8
    lda #bScroll::LockVert
    sta Zp_Camera_bScroll
    rts
.ENDPROC

;;;=========================================================================;;;
