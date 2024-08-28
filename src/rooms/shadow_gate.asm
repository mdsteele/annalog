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
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../fade.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT DataA_Text0_ShadowGateScreen_Page1_u8_arr
.IMPORT DataA_Text0_ShadowGateScreen_Page2_u8_arr
.IMPORT FuncA_Room_GetDarknessZoneFade
.IMPORT Func_Noop
.IMPORT Func_SetAndTransferBgFade
.IMPORT Func_WriteToUpperAttributeTable
.IMPORT Ppu_ChrObjShadow
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

.EXPORT DataC_Shadow_Gate_sRoom
.PROC DataC_Shadow_Gate_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, eArea::Shadow
    d_byte MinimapStartRow_u8, 12
    d_byte MinimapStartCol_u8, 8
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
    d_addr Enter_func_ptr, FuncA_Room_ShadowGate_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_ShadowGate_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_ShadowGate_TickRoom
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/shadow_gate.room"
    .assert * - :- = 18 * 15, error
_Platforms_sPlatform_arr:
:   ;; Darkness:
    .assert * - :- = kDarknessZonePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $7e
    d_byte HeightPx_u8, $f0
    d_word Left_i16,  $002d
    d_word Top_i16,   $0000
    D_END
    ;; Acid:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $a0
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0040
    d_word Top_i16,   $00ca
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadFlydrop
    d_word PosX_i16, $0080
    d_word PosY_i16, $0029
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ScreenRed
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eDialog::ShadowGateScreen
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::ShadowHall
    d_byte SpawnBlock_u8, 9
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::ShadowEntry
    d_byte SpawnBlock_u8, 9
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_ShadowGate_EnterRoom
    lda #eFade::Normal
    sta Zp_RoomState + sState::Terrain_eFade
    rts
.ENDPROC

.PROC FuncA_Room_ShadowGate_TickRoom
    ldy #eFade::Normal  ; param: fade level
    ldx #kDarknessZonePlatformIndex
    jsr FuncA_Room_GetDarknessZoneFade  ; returns Y
    sty Zp_RoomState + sState::Terrain_eFade
    jmp Func_SetAndTransferBgFade
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; @prereq Rendering is disabled.
.PROC FuncA_Terrain_ShadowGate_FadeInRoom
    lda Zp_RoomState + sState::Terrain_eFade
    sta Zp_GoalBg_eFade
    ;; Set two block rows of the upper nametable to use BG palette 2.
    ldx #5    ; param: num bytes to write
    ldy #$aa  ; param: attribute value
    lda #$32  ; param: initial byte offset
    jmp Func_WriteToUpperAttributeTable
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_ShadowGateScreen_sDialog
.PROC DataA_Dialog_ShadowGateScreen_sDialog
    dlg_Text Screen, DataA_Text0_ShadowGateScreen_Page1_u8_arr
    dlg_Text Screen, DataA_Text0_ShadowGateScreen_Page2_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
