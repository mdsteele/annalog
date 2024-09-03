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
.INCLUDE "../actors/orc.inc"
.INCLUDE "../device.inc"
.INCLUDE "../fade.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/lava.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT FuncA_Objects_AnimateCircuitIfBreakerActive
.IMPORT FuncA_Objects_SetUpLavaAnimationIrq
.IMPORT FuncA_Room_GetDarknessZoneFade
.IMPORT FuncA_Terrain_FadeInShortRoomWithLava
.IMPORT Func_SetAndTransferBgFade
.IMPORT Ppu_ChrObjShadow
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_GoalBg_eFade
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The platform index for the zone of darkness in this room.
kDarknessZonePlatformIndex = 0

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current fade level for this room's terrain.
    Terrain_eFade .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Shadow"

.EXPORT DataC_Shadow_Depths_sRoom
.PROC DataC_Shadow_Depths_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $410
    d_byte Flags_bRoom, eArea::Shadow
    d_byte MinimapStartRow_u8, 14
    d_byte MinimapStartCol_u8, 5
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjShadow)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Shadow_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_ShadowDepths_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_ShadowDepths_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_ShadowDepths_TickRoom
    d_addr Draw_func_ptr, FuncC_Shadow_Depths_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/shadow_depths1.room"
    .incbin "out/rooms/shadow_depths2.room"
    .incbin "out/rooms/shadow_depths3.room"
    .assert * - :- = 81 * 15, error
_Platforms_sPlatform_arr:
:   ;; Darkness:
    .assert * - :- = kDarknessZonePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $b0
    d_byte HeightPx_u8, $40
    d_word Left_i16,  $0130
    d_word Top_i16,   $0078
    D_END
    ;; Lava:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $510
    d_byte HeightPx_u8, kLavaPlatformHeightPx
    d_word Left_i16,   $0000
    d_word Top_i16, kLavaPlatformTopShortRoom
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0078
    d_word PosY_i16, $00b5
    d_byte Param_byte, eNpcAdult::GhostWoman
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $00b8
    d_word PosY_i16, $00b5
    d_byte Param_byte, eNpcAdult::GhostMan
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0148
    d_word PosY_i16, $0045
    d_byte Param_byte, eNpcAdult::GhostMan
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $01d8
    d_word PosY_i16, $0055
    d_byte Param_byte, eNpcAdult::GhostWoman
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $01b0
    d_word PosY_i16, $0058
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0248
    d_word PosY_i16, $0085
    d_byte Param_byte, eNpcAdult::GhostMan
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0250
    d_word PosY_i16, $00b8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0278
    d_word PosY_i16, $00b5
    d_byte Param_byte, eNpcAdult::GhostWoman
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $02a8
    d_word PosY_i16, $0095
    d_byte Param_byte, eNpcAdult::GhostMan
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0310
    d_word PosY_i16, $0068
    d_byte Param_byte, bObj::FlipH
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0330
    d_word PosY_i16, $00b8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0348
    d_word PosY_i16, $0045
    d_byte Param_byte, eNpcAdult::GhostWoman
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0348
    d_word PosY_i16, $0085
    d_byte Param_byte, eNpcAdult::GhostMan
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $03a8
    d_word PosY_i16, $0045
    d_byte Param_byte, eNpcAdult::GhostMan
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $03a8
    d_word PosY_i16, $0085
    d_byte Param_byte, eNpcAdult::GhostWoman
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 71
    d_byte Target_byte, eFlag::PaperJerome32
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 75
    d_byte Target_byte, eRoom::BossShadow
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::ShadowDescent
    d_byte SpawnBlock_u8, 11
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Shadow_Depths_DrawRoom
_AnimateCircuit:
    ldx #eFlag::BreakerShadow  ; param: breaker flag
    jsr FuncA_Objects_AnimateCircuitIfBreakerActive
_SetUpIrq:
    jmp FuncA_Objects_SetUpLavaAnimationIrq
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_ShadowDepths_EnterRoom
    lda #eFade::Normal
    sta Zp_RoomState + sState::Terrain_eFade
_ChangeActorsIfBossIsDead:
    ;; If the boss is dead, remove all the ghosts, and turn the grubs into fire
    ;; grubs.
    flag_bit Sram_ProgressFlags_arr, eFlag::BossShadow
    beq @done
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::NpcAdult
    beq @remove
    cmp #eActor::BadGrub
    bne @continue
    lda #eActor::BadGrubFire
    .assert eActor::BadGrubFire > 0, error
    bne @setType  ; unconditional
    @remove:
    lda #eActor::None
    @setType:
    sta Ram_ActorType_eActor_arr, x
    @continue:
    dex
    .assert kMaxActors <= $80, error
    bpl @loop
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_ShadowDepths_TickRoom
    ldy #eFade::Normal  ; param: fade level
    ldx #kDarknessZonePlatformIndex
    jsr FuncA_Room_GetDarknessZoneFade  ; returns Y
    sty Zp_RoomState + sState::Terrain_eFade
    jmp Func_SetAndTransferBgFade
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; @prereq Rendering is disabled.
.PROC FuncA_Terrain_ShadowDepths_FadeInRoom
    lda Zp_RoomState + sState::Terrain_eFade
    sta Zp_GoalBg_eFade
    jmp FuncA_Terrain_FadeInShortRoomWithLava
.ENDPROC

;;;=========================================================================;;;
