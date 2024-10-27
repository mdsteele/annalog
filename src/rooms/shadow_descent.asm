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
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/barrier.inc"
.INCLUDE "../platforms/lava.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT FuncA_Objects_AnimateLavaTerrain
.IMPORT FuncA_Terrain_FadeInTallRoomWithLava
.IMPORT FuncC_Shadow_DrawBarrierPlatform
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjShadow1
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarPosY_i16

;;;=========================================================================;;;

;;; The index of the passage that leads to the ShadowDrill room.
kDrillPassageIndex = 1

;;; The index of the passage that leads to the ShadowDepths room.
kDepthsPassageIndex = 3

;;; The room pixel Y-position of the center of the passage that leads to the
;;; ShadowDrill room.
kDrillPassageCenterY = $0050

;;; The platform indices for the barriers that lock the player avatar out of
;;; the ShadowDepths until the ghosts are tagged.
kBarrier1PlatformIndex = 0
kBarrier2PlatformIndex = 1

;;; The room pixel Y-positions for the tops of the barrier platforms when they
;;; are fully open or fully shut.
kBarrierShutTop = $0130
kBarrierOpenTop = kBarrierShutTop - kBarrierPlatformHeightPx

;;;=========================================================================;;;

.SEGMENT "PRGC_Shadow"

.EXPORT DataC_Shadow_Descent_sRoom
.PROC DataC_Shadow_Descent_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Shadow
    d_byte MinimapStartRow_u8, 13
    d_byte MinimapStartCol_u8, 4
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjShadow1)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Shadow_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_ShadowDescent_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_FadeInTallRoomWithLava
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Shadow_Descent_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/shadow_descent.room"
    .assert * - :- = 18 * 24, error
_Platforms_sPlatform_arr:
:   .assert * - :- = kBarrier1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBarrierPlatformWidthPx
    d_byte HeightPx_u8, kBarrierPlatformHeightPx
    d_word Left_i16,  $00e0
    d_word Top_i16, kBarrierShutTop
    D_END
    .assert * - :- = kBarrier2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBarrierPlatformWidthPx
    d_byte HeightPx_u8, kBarrierPlatformHeightPx
    d_word Left_i16,  $00e8
    d_word Top_i16, kBarrierShutTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0060
    d_word Top_i16,   $0078
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00b0
    d_word Top_i16,   $0078
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0070
    d_word Top_i16,   $0090
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00a0
    d_word Top_i16,   $0090
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0080
    d_word Top_i16,   $0110
    D_END
    ;; Lava:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $120
    d_byte HeightPx_u8, kLavaPlatformHeightPx
    d_word Left_i16,   $0000
    d_word Top_i16, kLavaPlatformTopTallRoom
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadFlydrop
    d_word PosX_i16, $0090
    d_word PosY_i16, $0039
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrubFire
    d_word PosX_i16, $0098
    d_word PosY_i16, $00b8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrubFire
    d_word PosX_i16, $00a0
    d_word PosY_i16, $00f8
    d_byte Param_byte, bObj::FlipH
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 15
    d_byte Target_byte, eFlag::PaperJerome20
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::ShadowFlower
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- = kDrillPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::ShadowDrill
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::ShadowOffice
    d_byte SpawnBlock_u8, 20
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- = kDepthsPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::ShadowDepths
    d_byte SpawnBlock_u8, 20
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Shadow_Descent_DrawRoom
    ldx #kBarrier1PlatformIndex
    jsr FuncC_Shadow_DrawBarrierPlatform
    ldx #kBarrier2PlatformIndex
    jsr FuncC_Shadow_DrawBarrierPlatform
    jmp FuncA_Objects_AnimateLavaTerrain
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncA_Room_ShadowDescent_EnterRoom
    ;; If entering from ShadowDepths, raise both barriers.  (Normally, it
    ;; should be impossible to reach ShadowDepths without first raising both
    ;; barriers, so this is just a safety measure.)
    cmp #bSpawn::Passage | kDepthsPassageIndex
    beq _RaiseBothBarriers
    ;; If entering from the ShadowDrill room, and gravity is still reversed,
    ;; un-reverse it.
    cmp #bSpawn::Passage | kDrillPassageIndex
    bne @done  ; not entering from ShadowDrill room
    lda Zp_AvatarFlags_bObj
    .assert bObj::FlipV = $80, error
    bpl @done  ; gravity is already normal
    ;; Restore normal gravity.
    and #<~bObj::FlipV
    sta Zp_AvatarFlags_bObj
    ;; Invert the avatar's Y-position within the passage.
    lda #<(kDrillPassageCenterY * 2)
    sub Zp_AvatarPosY_i16 + 0
    sta Zp_AvatarPosY_i16 + 0
    lda #>(kDrillPassageCenterY * 2)
    sbc Zp_AvatarPosY_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
    @done:
_MaybeRaiseBarriers:
    ldy #ePlatform::Zone
    flag_bit Sram_ProgressFlags_arr, eFlag::ShadowHeartTaggedGhost
    beq @keepBarrier1
    sty Ram_PlatformType_ePlatform_arr + kBarrier1PlatformIndex
    @keepBarrier1:
    flag_bit Sram_ProgressFlags_arr, eFlag::ShadowOfficeTaggedGhost
    beq @keepBarrier2
    sty Ram_PlatformType_ePlatform_arr + kBarrier2PlatformIndex
    @keepBarrier2:
    rts
_RaiseBothBarriers:
    ldy #ePlatform::Zone
    sty Ram_PlatformType_ePlatform_arr + kBarrier1PlatformIndex
    sty Ram_PlatformType_ePlatform_arr + kBarrier2PlatformIndex
    rts
.ENDPROC

;;;=========================================================================;;;
