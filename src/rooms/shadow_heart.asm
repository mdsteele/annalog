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
.INCLUDE "../device.inc"
.INCLUDE "../fade.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/emitter.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/force.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT FuncA_Machine_EmitterTryAct
.IMPORT FuncA_Machine_EmitterXWriteReg
.IMPORT FuncA_Machine_EmitterYWriteReg
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawEmitterXMachine
.IMPORT FuncA_Objects_DrawEmitterYMachine
.IMPORT FuncA_Objects_DrawForcefieldPlatform
.IMPORT FuncA_Room_GetDarknessZoneFade
.IMPORT FuncA_Room_MachineEmitterXInitReset
.IMPORT FuncA_Room_MachineEmitterYInitReset
.IMPORT FuncA_Room_MakeNpcGhostDisappear
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MachineEmitterReadReg
.IMPORT Func_SetAndTransferBgFade
.IMPORT Func_SetFlag
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Func_WriteToUpperAttributeTable
.IMPORT Ppu_ChrObjShadow1
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_GoalBg_eFade
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for the ghost in this room.
kGhostActorIndex = 0

;;; The platform index for the zone that makes the ghost disappear when the
;;; player avatar enters it.
kGhostTagZonePlatformIndex = 4

;;; The platform indices for the zones of darkness in this room.
kDarkZone1PlatformIndex = 5
kDarkZone2PlatformIndex = 6
kDarkZone3PlatformIndex = 7

;;;=========================================================================;;;

;;; The platform index for the ShadowHeartEmitterX machine.
kEmitterXPlatformIndex = 2
;;; The platform index for the ShadowHeartEmitterY machine.
kEmitterYPlatformIndex = 3

;;; The initial positions of the emitter beams.
kEmitterXInitRegX = 4
kEmitterYInitRegY = 2

;;; The minimum room pixel X/Y-positions for the top-left of the forcefield
;;; platform.
kForcefieldMinPlatformLeft = $0040
kForcefieldMinPlatformTop  = $0030

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current fade level for this room's terrain.
    Terrain_eFade .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Shadow"

.EXPORT DataC_Shadow_Heart_sRoom
.PROC DataC_Shadow_Heart_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0110
    d_byte Flags_bRoom, eArea::Shadow
    d_byte MinimapStartRow_u8, 13
    d_byte MinimapStartCol_u8, 7
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
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
    d_addr Enter_func_ptr, FuncA_Room_ShadowHeart_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_ShadowHeart_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_ShadowHeart_TickRoom
    d_addr Draw_func_ptr, FuncC_Shadow_Heart_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/shadow_heart.room"
    .assert * - :- = 33 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kEmitterXMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::ShadowHeartEmitterX
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteE
    d_byte Status_eDiagram, eDiagram::EmitterX
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, 0, 0, "X", 0
    d_byte MainPlatform_u8, kEmitterXPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_ShadowHeartEmitterX_InitReset
    d_addr ReadReg_func_ptr, Func_MachineEmitterReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_EmitterXWriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_EmitterTryAct
    d_addr Tick_func_ptr, FuncA_Machine_ReachedGoal
    d_addr Draw_func_ptr, FuncC_Shadow_HeartEmitterX_Draw
    d_addr Reset_func_ptr, FuncA_Room_ShadowHeartEmitterX_InitReset
    D_END
    .assert * - :- = kEmitterYMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::ShadowHeartEmitterY
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteF
    d_byte Status_eDiagram, eDiagram::EmitterY
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kEmitterYPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_ShadowHeartEmitterY_InitReset
    d_addr ReadReg_func_ptr, Func_MachineEmitterReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_EmitterYWriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_EmitterTryAct
    d_addr Tick_func_ptr, FuncA_Machine_ReachedGoal
    d_addr Draw_func_ptr, FuncC_Shadow_HeartEmitterY_Draw
    d_addr Reset_func_ptr, FuncA_Room_ShadowHeartEmitterY_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .linecont +
    .assert * - :- = kEmitterForcefieldPlatformIndex * .sizeof(sPlatform), \
            error
    .linecont -
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kForcefieldPlatformWidth
    d_byte HeightPx_u8, kForcefieldPlatformHeight
    d_word Left_i16, kForcefieldMinPlatformLeft
    d_word Top_i16, kForcefieldMinPlatformTop
    D_END
    .assert * - :- = kEmitterRegionPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $a0
    d_byte HeightPx_u8, $60
    d_word Left_i16, kForcefieldMinPlatformLeft
    d_word Top_i16, kForcefieldMinPlatformTop
    D_END
    .assert * - :- = kEmitterXPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00d8
    d_word Top_i16,   $0018
    D_END
    .assert * - :- = kEmitterYPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0028
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kGhostTagZonePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $01e0
    d_word Top_i16,   $0070
    D_END
    ;; Darkness:
    .assert * - :- = kDarkZone1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $90
    d_byte HeightPx_u8, $f0
    d_word Left_i16,  $0130
    d_word Top_i16,   $0000
    D_END
    .assert * - :- = kDarkZone2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $70
    d_byte HeightPx_u8, $70
    d_word Left_i16,  $01a0
    d_word Top_i16,   $0080
    D_END
    .assert * - :- = kDarkZone3PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $f0
    d_word Left_i16,  $0060
    d_word Top_i16,   $0000
    D_END
    ;; Acid:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $1c0
    d_byte HeightPx_u8,  $20
    d_word Left_i16,   $0040
    d_word Top_i16,    $00ca
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kGhostActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $01e4
    d_word PosY_i16, $0071
    d_byte Param_byte, eNpcAdult::MermaidGhost
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGooGreen
    d_word PosX_i16, $00d8
    d_word PosY_i16, $0038
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGooGreen
    d_word PosX_i16, $00a8
    d_word PosY_i16, $0068
    d_byte Param_byte, bObj::FlipHV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGooGreen
    d_word PosX_i16, $0048
    d_word PosY_i16, $0088
    d_byte Param_byte, bObj::FlipHV
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eFlag::PaperJerome04
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 4
    d_byte Target_byte, kEmitterYMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kEmitterXMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::ShadowTrap
    d_byte SpawnBlock_u8, 10
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Shadow_Heart_DrawRoom
    ldx #kEmitterForcefieldPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawForcefieldPlatform
.ENDPROC

.PROC FuncC_Shadow_HeartEmitterX_Draw
    ldx Ram_MachineGoalHorz_u8_arr + kEmitterXMachineIndex
    ldy _BeamLength_u8_arr, x  ; param: beam length in tiles
    jmp FuncA_Objects_DrawEmitterXMachine
_BeamLength_u8_arr:
    .byte 18, 20, 20, 20, 16, 20, 20, 20, 20, 18
.ENDPROC

.PROC FuncC_Shadow_HeartEmitterY_Draw
    ldy #24  ; param: beam length in tiles
    jmp FuncA_Objects_DrawEmitterYMachine
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_ShadowHeart_EnterRoom
    lda #eFade::Normal
    sta Zp_RoomState + sState::Terrain_eFade
_MaybeRemoveGhost:
    flag_bit Sram_ProgressFlags_arr, eFlag::ShadowHeartTaggedGhost
    beq @done
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kGhostActorIndex
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_ShadowHeart_TickRoom
_MaybeTagGhost:
    ;; If the avatar isn't in the tag zone, don't tag the ghost.
    jsr Func_SetPointToAvatarCenter
    ldy #kGhostTagZonePlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcc @done  ; avatar is not in the tag zone
    ;; Mark the ghost as tagged; if it already was, then we're done.
    ldx #eFlag::ShadowHeartTaggedGhost  ; param: flag
    jsr Func_SetFlag  ; sets C if flag was already set
    bcs @done  ; ghost was already tagged
    ;; Make the ghost disappear.
    ldx #kGhostActorIndex  ; param: actor index
    ldy #eActor::BadGhostMermaid  ; param: new actor type
    jsr FuncA_Room_MakeNpcGhostDisappear
    @done:
_SetTerrainFade:
    ldy #eFade::Normal  ; param: fade level
    ldx #kDarkZone3PlatformIndex
    @loop:
    jsr FuncA_Room_GetDarknessZoneFade  ; preserves X, returns Y
    dex
    .assert kDarkZone3PlatformIndex - 1 = kDarkZone2PlatformIndex, error
    .assert kDarkZone2PlatformIndex - 1 = kDarkZone1PlatformIndex, error
    cpx #kDarkZone1PlatformIndex
    bge @loop
    sty Zp_RoomState + sState::Terrain_eFade
    jmp Func_SetAndTransferBgFade
.ENDPROC

.PROC FuncA_Room_ShadowHeartEmitterX_InitReset
    lda #kEmitterXInitRegX  ; param: X register value
    jmp FuncA_Room_MachineEmitterXInitReset
.ENDPROC

.PROC FuncA_Room_ShadowHeartEmitterY_InitReset
    lda #kEmitterYInitRegY  ; param: X register value
    jmp FuncA_Room_MachineEmitterYInitReset
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

.PROC FuncA_Terrain_ShadowHeart_FadeInRoom
    lda Zp_RoomState + sState::Terrain_eFade
    sta Zp_GoalBg_eFade
    ;; Set two block rows of the upper nametable to use BG palette 2.
    ldx #8    ; param: num bytes to write
    ldy #$aa  ; param: attribute value
    lda #$30  ; param: initial byte offset
    jmp Func_WriteToUpperAttributeTable
.ENDPROC

;;;=========================================================================;;;
