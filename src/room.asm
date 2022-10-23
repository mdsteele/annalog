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

.INCLUDE "actor.inc"
.INCLUDE "cpu.inc"
.INCLUDE "device.inc"
.INCLUDE "macros.inc"
.INCLUDE "platform.inc"
.INCLUDE "room.inc"
.INCLUDE "tileset.inc"

.IMPORT DataC_Core_Elevator_sRoom
.IMPORT DataC_Crypt_Boss_sRoom
.IMPORT DataC_Crypt_East_sRoom
.IMPORT DataC_Crypt_Flower_sRoom
.IMPORT DataC_Crypt_Gallery_sRoom
.IMPORT DataC_Crypt_Landing_sRoom
.IMPORT DataC_Crypt_South_sRoom
.IMPORT DataC_Crypt_Tomb_sRoom
.IMPORT DataC_Crypt_West_sRoom
.IMPORT DataC_Factory_Center_sRoom
.IMPORT DataC_Factory_Elevator_sRoom
.IMPORT DataC_Garden_Boss_sRoom
.IMPORT DataC_Garden_Crossroad_sRoom
.IMPORT DataC_Garden_East_sRoom
.IMPORT DataC_Garden_Flower_sRoom
.IMPORT DataC_Garden_Hallway_sRoom
.IMPORT DataC_Garden_Landing_sRoom
.IMPORT DataC_Garden_Shaft_sRoom
.IMPORT DataC_Garden_Shrine_sRoom
.IMPORT DataC_Garden_Tower_sRoom
.IMPORT DataC_Garden_Tunnel_sRoom
.IMPORT DataC_Lava_East_sRoom
.IMPORT DataC_Lava_Flower_sRoom
.IMPORT DataC_Lava_Shaft_sRoom
.IMPORT DataC_Lava_Station_sRoom
.IMPORT DataC_Lava_Teleport_sRoom
.IMPORT DataC_Lava_West_sRoom
.IMPORT DataC_Mermaid_Cellar_sRoom
.IMPORT DataC_Mermaid_Drain_sRoom
.IMPORT DataC_Mermaid_East_sRoom
.IMPORT DataC_Mermaid_Elevator_sRoom
.IMPORT DataC_Mermaid_Entry_sRoom
.IMPORT DataC_Mermaid_Flower_sRoom
.IMPORT DataC_Mermaid_Hut1_sRoom
.IMPORT DataC_Mermaid_Hut2_sRoom
.IMPORT DataC_Mermaid_Hut3_sRoom
.IMPORT DataC_Mermaid_Hut4_sRoom
.IMPORT DataC_Mermaid_Hut5_sRoom
.IMPORT DataC_Mermaid_Hut6_sRoom
.IMPORT DataC_Mermaid_Village_sRoom
.IMPORT DataC_Mine_Collapse_sRoom
.IMPORT DataC_Mine_Pit_sRoom
.IMPORT DataC_Prison_Cell_sRoom
.IMPORT DataC_Prison_Escape_sRoom
.IMPORT DataC_Prison_Flower_sRoom
.IMPORT DataC_Shadow_Teleport_sRoom
.IMPORT DataC_Temple_Entry_sRoom
.IMPORT DataC_Temple_Pit_sRoom
.IMPORT DataC_Town_House1_sRoom
.IMPORT DataC_Town_House2_sRoom
.IMPORT DataC_Town_Outdoors_sRoom
.IMPORT Func_InitActor
.IMPORT Func_InitAllMachines
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceBlockCol_u8_arr
.IMPORT Ram_DeviceBlockRow_u8_arr
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformRight_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORTZP Zp_AvatarPlatformIndex_u8
.IMPORTZP Zp_CameraCanScroll_bool
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_HudMachineIndex_u8
.IMPORTZP Zp_RoomIsSafe_bool
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

.LINECONT +
.DEFINE RoomPtrs \
    DataC_Core_Elevator_sRoom, \
    DataC_Crypt_Boss_sRoom, \
    DataC_Crypt_East_sRoom, \
    DataC_Crypt_Flower_sRoom, \
    DataC_Crypt_Gallery_sRoom, \
    DataC_Crypt_Landing_sRoom, \
    DataC_Crypt_South_sRoom, \
    DataC_Crypt_Tomb_sRoom, \
    DataC_Crypt_West_sRoom, \
    DataC_Factory_Center_sRoom, \
    DataC_Factory_Elevator_sRoom, \
    DataC_Garden_Boss_sRoom, \
    DataC_Garden_Crossroad_sRoom, \
    DataC_Garden_East_sRoom, \
    DataC_Garden_Flower_sRoom, \
    DataC_Garden_Hallway_sRoom, \
    DataC_Garden_Landing_sRoom, \
    DataC_Garden_Shaft_sRoom, \
    DataC_Garden_Shrine_sRoom, \
    DataC_Garden_Tower_sRoom, \
    DataC_Garden_Tunnel_sRoom, \
    DataC_Lava_East_sRoom, \
    DataC_Lava_Flower_sRoom, \
    DataC_Lava_Shaft_sRoom, \
    DataC_Lava_Station_sRoom, \
    DataC_Lava_Teleport_sRoom, \
    DataC_Lava_West_sRoom, \
    DataC_Mermaid_Cellar_sRoom, \
    DataC_Mermaid_Drain_sRoom, \
    DataC_Mermaid_East_sRoom, \
    DataC_Mermaid_Elevator_sRoom, \
    DataC_Mermaid_Entry_sRoom, \
    DataC_Mermaid_Flower_sRoom, \
    DataC_Mermaid_Hut1_sRoom, \
    DataC_Mermaid_Hut2_sRoom, \
    DataC_Mermaid_Hut3_sRoom, \
    DataC_Mermaid_Hut4_sRoom, \
    DataC_Mermaid_Hut5_sRoom, \
    DataC_Mermaid_Hut6_sRoom, \
    DataC_Mermaid_Village_sRoom, \
    DataC_Mine_Collapse_sRoom, \
    DataC_Mine_Pit_sRoom, \
    DataC_Prison_Cell_sRoom, \
    DataC_Prison_Escape_sRoom, \
    DataC_Prison_Flower_sRoom, \
    DataC_Shadow_Teleport_sRoom, \
    DataC_Temple_Entry_sRoom, \
    DataC_Temple_Pit_sRoom, \
    DataC_Town_House1_sRoom, \
    DataC_Town_House2_sRoom, \
    DataC_Town_Outdoors_sRoom
.LINECONT -

;;;=========================================================================;;;

.ZEROPAGE

;;; The room number for the previously-loaded room.
.EXPORTZP Zp_Previous_eRoom
Zp_Previous_eRoom: .res 1

;;; The room number for the currently-loaded room.
.EXPORTZP Zp_Current_eRoom
Zp_Current_eRoom: .res 1

;;; Data for the currently-loaded room.
.EXPORTZP Zp_Current_sRoom
Zp_Current_sRoom: .tag sRoom

;;; The currently-loaded tileset.
.EXPORTZP Zp_Current_sTileset
Zp_Current_sTileset: .tag sTileset

;;;=========================================================================;;;

.SEGMENT "RAM_Room"

;;; A chunk of RAM that each room can divvy up however it wants to store state
;;; specific to that room, such as:
;;;   * Position/register/etc. data for machines in that room
;;;   * State variables for cutscenes or other room scripts
;;;   * Mutable terrain data (for sufficiently small rooms)
;;; This RAM is automatically zeroed just before a room is loaded, but can be
;;; further initialized by room/machine Init functions.
.EXPORT Ram_RoomState
Ram_RoomState: .res kRoomStateSize

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Pointers to sRoom structs for all rooms in the game, indexed by eRoom
;;; values.
.PROC DataA_Room_Table_sRoom_ptr_0_arr
:   .lobytes RoomPtrs
    .assert * - :- = eRoom::NUM_VALUES, error
.ENDPROC
.PROC DataA_Room_Table_sRoom_ptr_1_arr
:   .hibytes RoomPtrs
    .assert * - :- = eRoom::NUM_VALUES, error
.ENDPROC

;;; PRGC bank numbers for all rooms in the game, indexed by eRoom values.
.EXPORT DataA_Room_Banks_u8_arr
.PROC DataA_Room_Banks_u8_arr
    .repeat eRoom::NUM_VALUES, index
    .byte <.bank(.mid(index * 2, 1, {RoomPtrs}))
    .endrepeat
.ENDPROC

;;; Loads and initializes data for the specified room.
;;; @prereq The correct PRGC bank has been set for the room to be loaded.
;;; @param X The eRoom value for the room to load.
.EXPORT FuncA_Room_Load
.PROC FuncA_Room_Load
    lda Zp_Current_eRoom
    sta Zp_Previous_eRoom
    stx Zp_Current_eRoom
_CopyRoomStruct:
    ;; Get a pointer to the sRoom struct and store it in Zp_Tmp_ptr.
    lda DataA_Room_Table_sRoom_ptr_0_arr, x
    sta Zp_Tmp_ptr + 0
    lda DataA_Room_Table_sRoom_ptr_1_arr, x
    sta Zp_Tmp_ptr + 1
    ;; Copy the sRoom struct into Zp_Current_sRoom.
    ldy #.sizeof(sRoom) - 1
    .assert .sizeof(sRoom) <= $80, error
    @loop:
    lda (Zp_Tmp_ptr), y
    sta Zp_Current_sRoom, y
    dey
    bpl @loop
_CopyTilesetStruct:
    ;; Copy the current room's Terrain_sTileset_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Terrain_sTileset_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Copy the sTileset struct into Zp_Current_sTileset.
    ldy #.sizeof(sTileset) - 1
    .assert .sizeof(sTileset) <= $80, error
    @loop:
    lda (Zp_Tmp_ptr), y
    sta Zp_Current_sTileset, y
    dey
    bpl @loop
_ClearRoomState:
    .assert kRoomStateSize = $100, error
    lda #0
    tax
    @loop:
    sta Ram_RoomState, x
    inx
    bne @loop
_LoadPlatforms:
    ;; Copy the current room's Platforms_sPlatform_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Platforms_sPlatform_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Copy room platform structs into platform RAM.
    ldx #0  ; platform index
    ldy #0  ; byte offset into Platforms_sPlatform_arr_ptr
    @copyLoop:
    .assert sPlatform::Type_ePlatform = 0, error
    lda (Zp_Tmp_ptr), y
    .assert ePlatform::None = 0, error
    beq @copyDone
    sta Ram_PlatformType_ePlatform_arr, x
    iny
    .assert sPlatform::WidthPx_u16 = 1, error
    lda (Zp_Tmp_ptr), y
    sta Zp_Tmp1_byte  ; platform width (lo)
    iny
    lda (Zp_Tmp_ptr), y
    sta Zp_Tmp2_byte  ; platform width (hi)
    iny
    .assert sPlatform::HeightPx_u8 = 3, error
    lda (Zp_Tmp_ptr), y
    sta Zp_Tmp3_byte  ; platform height
    iny
    .assert sPlatform::Left_i16 = 4, error
    lda (Zp_Tmp_ptr), y
    sta Ram_PlatformLeft_i16_0_arr, x
    add Zp_Tmp1_byte  ; platform width (lo)
    sta Ram_PlatformRight_i16_0_arr, x
    iny
    lda (Zp_Tmp_ptr), y
    sta Ram_PlatformLeft_i16_1_arr, x
    adc Zp_Tmp2_byte  ; platform width (hi)
    sta Ram_PlatformRight_i16_1_arr, x
    iny
    .assert sPlatform::Top_i16 = 6, error
    lda (Zp_Tmp_ptr), y
    sta Ram_PlatformTop_i16_0_arr, x
    add Zp_Tmp3_byte  ; platform height
    sta Ram_PlatformBottom_i16_0_arr, x
    iny
    lda (Zp_Tmp_ptr), y
    sta Ram_PlatformTop_i16_1_arr, x
    adc #0
    sta Ram_PlatformBottom_i16_1_arr, x
    iny
    .assert .sizeof(sPlatform) = 8, error
    inx
    bne @copyLoop  ; unconditional
    ;; Clear remaining slots in platform RAM.
    @clearLoop:
    sta Ram_PlatformType_ePlatform_arr, x  ; A is already ePlatform::None
    inx
    @copyDone:
    cpx #kMaxPlatforms
    blt @clearLoop
_LoadActors:
    ;; Copy the current room's Actors_sActor_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Actors_sActor_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Copy room actor structs into actor RAM.
    ldx #0  ; actor index
    ldy #0  ; byte offset into Actors_sActor_arr_ptr
    @copyLoop:
    ;; Actor type:
    .assert sActor::Type_eActor = 0, error
    lda (Zp_Tmp_ptr), y
    .assert eActor::None = 0, error
    beq @copyDone
    sta Ram_ActorType_eActor_arr, x
    iny
    ;; Y-position:
    lda #0
    sta Ram_ActorPosY_i16_1_arr, x
    .assert sActor::TileRow_u8 = 1, error
    lda (Zp_Tmp_ptr), y
    iny
    .repeat 3
    asl a
    rol Ram_ActorPosY_i16_1_arr, x
    .endrepeat
    sta Ram_ActorPosY_i16_0_arr, x
    ;; X-position:
    lda #0
    sta Ram_ActorPosX_i16_1_arr, x
    .assert sActor::TileCol_u8 = 2, error
    lda (Zp_Tmp_ptr), y
    iny
    .repeat 3
    asl a
    rol Ram_ActorPosX_i16_1_arr, x
    .endrepeat
    sta Ram_ActorPosX_i16_0_arr, x
    ;; Temporarily store param byte as actor state byte:
    .assert sActor::Param_byte = 3, error
    lda (Zp_Tmp_ptr), y
    iny
    sta Ram_ActorState_byte_arr, x
    ;; Continue to next sActor entry.
    .assert .sizeof(sActor) = 4, error
    inx
    bne @copyLoop  ; unconditional
    ;; Clear remaining slots in actor RAM.
    @clearLoop:
    sta Ram_ActorType_eActor_arr, x  ; A is already eActor::None
    inx
    @copyDone:
    cpx #kMaxActors
    blt @clearLoop
    ;; Call all actor init functions, using the param bytes we stored in
    ;; Ram_ActorState_byte_arr.
    dex
    @initLoop:
    lda Ram_ActorState_byte_arr, x
    jsr Func_InitActor  ; preserves X
    dex
    .assert kMaxActors < $80, error
    bpl @initLoop
_LoadDevices:
    ;; Copy the current room's Devices_sDevice_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Devices_sDevice_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Copy room device structs into device RAM.
    ldx #0  ; device index
    ldy #0  ; byte offset into Devices_sDevice_arr_ptr
    @copyLoop:
    .assert sDevice::Type_eDevice = 0, error
    lda (Zp_Tmp_ptr), y
    .assert eDevice::None = 0, error
    beq @copyDone
    sta Ram_DeviceType_eDevice_arr, x
    iny
    .assert sDevice::BlockRow_u8 = 1, error
    lda (Zp_Tmp_ptr), y
    sta Ram_DeviceBlockRow_u8_arr, x
    iny
    .assert sDevice::BlockCol_u8 = 2, error
    lda (Zp_Tmp_ptr), y
    sta Ram_DeviceBlockCol_u8_arr, x
    iny
    .assert sDevice::Target_u8 = 3, error
    lda (Zp_Tmp_ptr), y
    sta Ram_DeviceTarget_u8_arr, x
    iny
    .assert .sizeof(sDevice) = 4, error
    lda #0
    sta Ram_DeviceAnim_u8_arr, x
    inx
    bne @copyLoop  ; unconditional
    ;; Clear remaining slots in device RAM.
    @clearLoop:
    sta Ram_DeviceType_eDevice_arr, x  ; A is already eDevice::None
    inx
    @copyDone:
    cpx #kMaxDevices
    blt @clearLoop
_SetVars:
    lda #$ff
    sta Zp_AvatarPlatformIndex_u8
    sta Zp_CameraCanScroll_bool
    sta Zp_ConsoleMachineIndex_u8
    sta Zp_HudMachineIndex_u8
    sta Zp_RoomIsSafe_bool
_CallInit:
    jsr FuncA_Room_CallRoomInit
    jmp Func_InitAllMachines
.ENDPROC

;;; Calls the current room's Init_func_ptr function.
.PROC FuncA_Room_CallRoomInit
    ldy #sRoomExt::Init_func_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
.ENDPROC

;;;=========================================================================;;;
