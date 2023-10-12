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
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Temple_sTileset
.IMPORT FuncC_Temple_DrawColumnPlatform
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Func_ShakeRoom
.IMPORT Ppu_ChrObjTemple
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for the mermaid in this room.
kMermaidActorIndex = 0
;;; The talk devices indices for the mermaid in this room.
kMermaidDeviceIndexLeft = 1
kMermaidDeviceIndexRight = 0

;;; The platform index for the movable column in this room.
kColumnPlatformIndex = 1

;;; The minimum and maximum Y-positions for the top of the movable column
;;; platform.
kColumnPlatformMinTop = $140
kColumnPlatformMaxTop = $160

;;; How many frames it takes for the movable column to move one pixel.
kColumnPlatformSlowdown = 3

;;; How much to shake the room (each frame) when the movable column moves.
kColumnShakeFrames = 10

;;; Various OBJ tile IDs used for drawing the movable column.
kTileIdObjColumnFirst  = $9a
kTileIdObjColumnCorner = kTileIdObjColumnFirst + 0
kTileIdObjColumnSide   = kTileIdObjColumnFirst + 1

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; How many more frames before the movable column can move another pixel.
    ColumnSlowdown_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Temple"

.EXPORT DataC_Temple_Entry_sRoom
.PROC DataC_Temple_Entry_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $0008
    d_byte Flags_bRoom, bRoom::Tall | eArea::Temple
    d_byte MinimapStartRow_u8, 7
    d_byte MinimapStartCol_u8, 5
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTemple)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Temple_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Temple_Entry_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Temple_Entry_TickRoom
    d_addr Draw_func_ptr, FuncC_Temple_Entry_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/temple_entry.room"
    .assert * - :- = 18 * 24, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $c0
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0030
    d_word Top_i16,   $0154
    D_END
    .assert * - :- = kColumnPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $0040
    d_word Top_i16, kColumnPlatformMaxTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00b0
    d_word Top_i16,   $0168
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kMermaidActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_word PosX_i16, $0070
    d_word PosY_i16, $0158
    d_byte Param_byte, kTileIdMermaidGuardFFirst
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleVert
    d_word PosX_i16, $00a8
    d_word PosY_i16, $0098
    d_byte Param_byte, bObj::FlipV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_word PosX_i16, $00d0
    d_word PosY_i16, $00c8
    d_byte Param_byte, bObj::FlipHV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadToad
    d_word PosX_i16, $0080
    d_word PosY_i16, $0100
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kMermaidDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eDialog::TempleEntryMermaid
    D_END
    .assert * - :- = kMermaidDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eDialog::TempleEntryMermaid
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::TempleFoyer
    d_byte SpawnBlock_u8, 6
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::GardenHallway
    d_byte SpawnBlock_u8, 19
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Temple_Entry_EnterRoom
_MaybeRemoveMermaid:
    ;; If the temple breaker has been activated, then remove the mermaid from
    ;; this room, and mark the column as raised (although normally, you can't
    ;; reach the breaker without first raising the column).
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerTemple
    beq @done
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kMermaidActorIndex
    .assert eDevice::None = eActor::None, error
    sta Ram_DeviceType_eDevice_arr + kMermaidDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kMermaidDeviceIndexRight
    ldx #eFlag::TempleEntryColumnRaised  ; param: flag
    jsr Func_SetFlag
    @done:
_MaybeRaiseColumn:
    ;; If the column has been raised before, raise it.
    flag_bit Sram_ProgressFlags_arr, eFlag::TempleEntryColumnRaised
    beq @done
    lda #<kColumnPlatformMinTop
    sta Ram_PlatformTop_i16_0_arr + kColumnPlatformIndex
    lda #>kColumnPlatformMinTop
    sta Ram_PlatformTop_i16_1_arr + kColumnPlatformIndex
    @done:
    rts
.ENDPROC

.PROC FuncC_Temple_Entry_TickRoom
    ;; If the column-raised flag is set, move the column upward towards its
    ;; highest position.
    flag_bit Sram_ProgressFlags_arr, eFlag::TempleEntryColumnRaised
    beq @done
    ;; Move the column by one pixel every kColumnPlatformSlowdown frames.
    lda Zp_RoomState + sState::ColumnSlowdown_u8
    bne @slowdown
    lda #kColumnPlatformSlowdown
    sta Zp_RoomState + sState::ColumnSlowdown_u8
    ldax #kColumnPlatformMinTop
    stax Zp_PointY_i16
    lda #1  ; param: move speed
    ldx #kColumnPlatformIndex  ; param: platform index
    jsr Func_MovePlatformTopTowardPointY  ; returns Z
    beq @done
    lda #kColumnShakeFrames  ; param: num frames
    jmp Func_ShakeRoom
    @slowdown:
    dec Zp_RoomState + sState::ColumnSlowdown_u8
    @done:
    rts
.ENDPROC

;;; Draw function for the TempleEntry room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Temple_Entry_DrawRoom
    ldx #kColumnPlatformIndex  ; param: platform index
    jmp FuncC_Temple_DrawColumnPlatform
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_TempleEntryMermaid_sDialog
.PROC DataA_Dialog_TempleEntryMermaid_sDialog
    dlg_Text MermaidGuardF, DataA_Text0_TempleEntryMermaid_Intro_u8_arr
    dlg_Func _CheckPermissionFunc
_CheckPermissionFunc:
    flag_bit Sram_ProgressFlags_arr, eFlag::TempleEntryPermission
    bne _RaiseColumnFunc
    ldya #_NoPermission_sDialog
    rts
_NoPermission_sDialog:
    dlg_Text MermaidGuardF, DataA_Text0_TempleEntryMermaid_NoPermission_u8_arr
    dlg_Done
_RaiseColumnFunc:
    ldx #eFlag::TempleEntryColumnRaised  ; param: flag
    jsr Func_SetFlag
    ldya #_Enter_sDialog
    rts
_Enter_sDialog:
    dlg_Text MermaidGuardF, DataA_Text0_TempleEntryMermaid_Enter_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_TempleEntryMermaid_Intro_u8_arr
    .byte "I am guarding the$"
    .byte "entrance to the temple$"
    .byte "you see above us.#"
.ENDPROC

.PROC DataA_Text0_TempleEntryMermaid_NoPermission_u8_arr
    .byte "I cannot help you to$"
    .byte "enter it without the$"
    .byte "queen's permission.#"
.ENDPROC

.PROC DataA_Text0_TempleEntryMermaid_Enter_u8_arr
    .byte "Our queen has sent$"
    .byte "word: I am to allow$"
    .byte "you to enter.#"
.ENDPROC

;;;=========================================================================;;;
