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
.INCLUDE "../irq.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"
.INCLUDE "mine_burrow.inc"

.IMPORT DataA_Room_Mine_sTileset
.IMPORT FuncA_Objects_AnimateCircuitIfBreakerActive
.IMPORT FuncA_Room_PlaySfxRumbling
.IMPORT Func_IsPointInPlatform
.IMPORT Func_Noop
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Func_ShakeRoom
.IMPORT Int_SetChr04ToParam3ThenLatchWindowFromParam4
.IMPORT Ppu_ChrObjMine
.IMPORT Ram_ProgressFlags_arr
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; How many frames to rumble the room for when the player avatar enters a new
;;; rumble zone.
kRumbleFrames = 120

;;; The screen pixel Y-position at which the water IRQ should change the CHR04
;;; bank.
kWaterChr04IrqY = $80

;;; One of the three rumble zones in this room.
.ENUM eRumble
    West
    Center
    East
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The rumble zone that the player avatar most recently entered.
    Last_eRumble   .byte
    ;; How many more frames to rumble for.
    RumbleTimer_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Mine"

.EXPORT DataC_Mine_Burrow_sRoom
.PROC DataC_Mine_Burrow_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0100
    d_byte Flags_bRoom, eArea::Mine
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 18
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjMine)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Mine_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Mine_Burrow_TickRoom
    d_addr Draw_func_ptr, FuncC_Mine_Burrow_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/mine_burrow.room"
    .assert * - :- = 33 * 15, error
_Platforms_sPlatform_arr:
:   ;; Rumble zones, indexed by eRumble:
    .assert * - :- <= eRumble::West * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $90
    d_byte HeightPx_u8, $f0
    d_word Left_i16,  $0020
    d_word Top_i16,   $0000
    D_END
    .assert * - :- <= eRumble::Center * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $90
    d_word Left_i16,  $00e0
    d_word Top_i16,   $0060
    D_END
    .assert * - :- <= eRumble::East * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $50
    d_word Left_i16,  $0170
    d_word Top_i16,   $0010
    D_END
    .assert * - :- <= eRumble::NUM_VALUES * .sizeof(sPlatform), error
    ;; Water:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0050
    d_word Top_i16,   $00c4
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16,   $00d6
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $b0
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0100
    d_word Top_i16,   $00de
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $00a8
    d_word PosY_i16, $00a8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $00d8
    d_word PosY_i16, $0058
    d_byte Param_byte, bObj::FlipH
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0110
    d_word PosY_i16, $0038
    d_byte Param_byte, bObj::FlipH
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0138
    d_word PosY_i16, $00c8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $01c0
    d_word PosY_i16, $00b8
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kMineBurrowDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 3
    d_byte Target_byte, eRoom::BossMine
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::MineCollapse
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Mine_Burrow_TickRoom
_RumbleRoom:
    lda Zp_RoomState + sState::RumbleTimer_u8
    beq @done
    dec Zp_RoomState + sState::RumbleTimer_u8
    mod #4
    bne @done
    lda #2  ; param: num frames
    jsr Func_ShakeRoom
    lda #4  ; param: num frames
    jsr FuncA_Room_PlaySfxRumbling
    @done:
_CheckForNewRumbleZone:
    ;; Once the boss has been defeated, don't rumble anymore.
    flag_bit Ram_ProgressFlags_arr, eFlag::BossMine
    bne _Return
    ;; Find the rumble zone that the player avatar is in, if any.
    jsr Func_SetPointToAvatarCenter
    ldy #eRumble::NUM_VALUES - 1
    @loop:
    jsr Func_IsPointInPlatform  ; preserves Y
    bcs _MaybeStartRumbling
    dey
    .assert eRumble::NUM_VALUES <= $80, error
    bpl @loop
    ;; If the player avatar is not in any rumble zone, we're done.
_Return:
    rts
_MaybeStartRumbling:
    ;; If the player avatar is in the same rumble zone as before, do nothing.
    cpy Zp_RoomState + sState::Last_eRumble
    beq _Return
    ;; Otherwise, start rumbling.
    sty Zp_RoomState + sState::Last_eRumble
    lda #kRumbleFrames
    sta Zp_RoomState + sState::RumbleTimer_u8
    rts
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Mine_Burrow_DrawRoom
_SetUpWaterIrq:
    lda Zp_Chr04Bank_u8
    sta Zp_Buffered_sIrq + sIrq::Param3_byte  ; water CHR04 bank
    ;; Compute the IRQ latch value to set between the top of the water
    ;; animation zone and the top of the window (if any), and set that as
    ;; Param4_byte.
    lda Zp_Buffered_sIrq + sIrq::Latch_u8
    sub #kWaterChr04IrqY + 1
    blt @done  ; window top is above water animation zone top
    sta Zp_Buffered_sIrq + sIrq::Param4_byte  ; window latch
    ;; Set up our own sIrq struct to handle water animation.
    lda #kWaterChr04IrqY
    sta Zp_Buffered_sIrq + sIrq::Latch_u8
    ldax #Int_SetChr04ToParam3ThenLatchWindowFromParam4
    stax Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr
    @done:
_AnimateCircuit:
    ldx #eFlag::BreakerMine  ; param: breaker flag
    jmp FuncA_Objects_AnimateCircuitIfBreakerActive
.ENDPROC

;;;=========================================================================;;;
