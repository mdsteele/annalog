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
.INCLUDE "../actors/ghost.inc"
.INCLUDE "../actors/orc.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../fake.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/lava.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT FuncA_Objects_AnimateLavaTerrain
.IMPORT FuncA_Room_MakeNpcGhostDisappear
.IMPORT FuncA_Terrain_FadeInShortRoomWithLava
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsPointInPlatform
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetFlag
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Ppu_ChrObjShadow
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16

;;;=========================================================================;;;

;;; The actor index for the ghost in this room.
kGhostActorIndex = 0

;;; The platform index for the zone that makes the ghost disappear when the
;;; player avatar enters it.
kGhostTagZonePlatformIndex = 0

;;; The platform index for the wall that blocks the ghost tank at first.
kGhostWallPlatformIndex = 1

;;;=========================================================================;;;

;;; The tile row/col in the upper nametable for the top-left corner of the
;;; ghost wall's BG tiles.
kWallStartRow = 19
kWallStartCol = 12

;;; The PPU addresses for the start (left) of each row of the ghost wall's BG
;;; tiles.
.LINECONT +
Ppu_WallRow0Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kWallStartRow + 0) + kWallStartCol
Ppu_WallRow1Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kWallStartRow + 1) + kWallStartCol
Ppu_WallRow2Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kWallStartRow + 2) + kWallStartCol
Ppu_WallRow3Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kWallStartRow + 3) + kWallStartCol
Ppu_WallRow4Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kWallStartRow + 4) + kWallStartCol
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "PRGC_Shadow"

.EXPORT DataC_Shadow_Office_sRoom
.PROC DataC_Shadow_Office_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte Flags_bRoom, eArea::Shadow
    d_byte MinimapStartRow_u8, 14
    d_byte MinimapStartCol_u8, 3
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
    d_addr Enter_func_ptr, FuncA_Room_ShadowOffice_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_ShadowOffice_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_ShadowOffice_TickRoom
    d_addr Draw_func_ptr, FuncA_Objects_AnimateLavaTerrain
    D_END
_TerrainData:
:   .incbin "out/rooms/shadow_office.room"
    .assert * - :- = 17 * 15, error
_Platforms_sPlatform_arr:
:   .assert * - :- = kGhostTagZonePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $18
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0068
    d_word Top_i16,   $00b0
    D_END
    .assert * - :- = kGhostWallPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $0060
    d_word Top_i16,   $0090
    D_END
    ;; Lava:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $110
    d_byte HeightPx_u8, kLavaPlatformHeightPx
    d_word Left_i16,   $0000
    d_word Top_i16, kLavaPlatformTopShortRoom
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kGhostActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, $0074
    d_word PosY_i16, $01b3
    d_byte Param_byte, eNpcOrc::GhostStanding
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 2
    d_byte BlockCol_u8, 1
    d_byte Target_byte, eFake::CoreDump
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 2
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 2
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 3
    d_byte BlockCol_u8, 13
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 2
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ScreenGreen
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eDialog::ShadowOfficeTeleport
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ScreenGreen
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 12
    d_byte Target_byte, eDialog::ShadowOfficeTeleport
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eFake::InsufficientData
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 3
    d_byte Target_byte, eFake::Ethical
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eFake::NoPower
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::ShadowDescent
    d_byte SpawnBlock_u8, 11
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_ShadowOffice_TickRoom
_MaybeTagGhost:
    ;; If the avatar isn't in the tag zone, don't tag the ghost.
    jsr Func_SetPointToAvatarCenter
    ldy #kGhostTagZonePlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcc @done  ; avatar is not in the tag zone
    ;; Mark the ghost as tagged; if it already was, then we're done.
    ldx #eFlag::ShadowOfficeTaggedGhost  ; param: flag
    jsr Func_SetFlag  ; sets C if flag was already set
    bcs @done  ; ghost was already tagged
    ;; Make the ghost disappear.
    ldx #kGhostActorIndex  ; param: actor index
    ldy #eActor::BadGhostOrc  ; param: new actor type
    jmp FuncA_Room_MakeNpcGhostDisappear
    @done:
_MaybeRemoveWallAndRevealGhost:
    fall FuncA_Room_ShadowOffice_EnterRoom
.ENDPROC

.PROC FuncA_Room_ShadowOffice_EnterRoom
_MaybeRemoveWall:
    flag_bit Sram_ProgressFlags_arr, eFlag::ShadowOfficeRemovedWall
    beq _Return
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kGhostWallPlatformIndex
_MaybeRevealGhost:
    flag_bit Sram_ProgressFlags_arr, eFlag::ShadowOfficeTaggedGhost
    bne _Return
    lda #0
    sta Ram_ActorPosY_i16_1_arr + kGhostActorIndex
    rts
_Return:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

.PROC DataA_Terrain_ShadowOfficeTransfer_arr
    ;; Row 0:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_WallRow0Start  ; transfer destination
    .byte 6
    .byte $14, $8a, $8a, $8a, $8a, $15
    ;; Row 1:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_WallRow1Start  ; transfer destination
    .byte 6
    .byte $88, $87, $8b, $8b, $86, $89
    ;; Row 2:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_WallRow2Start  ; transfer destination
    .byte 6
    .byte $16, $17, $14, $15, $88, $89
    ;; Row 3:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_WallRow3Start  ; transfer destination
    .byte 6
    .byte $14, $8a, $84, $89, $88, $89
    ;; Row 4:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_WallRow4Start  ; transfer destination
    .byte 6
    .byte $16, $8b, $8b, $17, $16, $17
.ENDPROC

.PROC FuncA_Terrain_ShadowOffice_FadeInRoom
    flag_bit Sram_ProgressFlags_arr, eFlag::ShadowOfficeRemovedWall
    bne @noGhostWall
    ldax #DataA_Terrain_ShadowOfficeTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataA_Terrain_ShadowOfficeTransfer_arr)  ; param: data length
    jsr Func_BufferPpuTransfer
    @noGhostWall:
    jmp FuncA_Terrain_FadeInShortRoomWithLava
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_ShadowOfficeTeleport_sDialog
.PROC DataA_Dialog_ShadowOfficeTeleport_sDialog
    dlg_Call _TeleportAvatar
    dlg_Done
_TeleportAvatar:
    jsr _SpawnPoofOnAvatar
    lda Zp_AvatarPosX_i16 + 0
    bpl @teleportRight
    @teleportLeft:
    ;; TODO: If the player teleports a bunch of times in a row, instead
    ;; teleport the avatar over the lava.
    ldx #$48
    ldy #$58
    bne @setAvatarPos  ; unconditional
    @teleportRight:
    ldx #$c8
    ldy #$78
    @setAvatarPos:
    stx Zp_AvatarPosX_i16 + 0
    sty Zp_AvatarPosY_i16 + 0
_SpawnPoofOnAvatar:
    jsr Func_SetPointToAvatarCenter
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs @done
    jsr Func_SetActorCenterToPoint  ; preserves X
    jmp Func_InitActorSmokeExplosion
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
