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
.INCLUDE "device.inc"
.INCLUDE "macros.inc"
.INCLUDE "platform.inc"
.INCLUDE "room.inc"
.INCLUDE "tileset.inc"

.IMPORT DataC_Prison_Cell_sRoom
.IMPORT DataC_Prison_Escape_sRoom
.IMPORT DataC_Prison_Tall_sRoom
.IMPORT DataC_Prison_Tunnel_sRoom
.IMPORT DataC_Town_Outdoors_sRoom
.IMPORT Func_InitAllMachines
.IMPORT Ram_ActorFlags_bObj_arr
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
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

.LINECONT +
.DEFINE RoomPtrs \
    DataC_Prison_Cell_sRoom, \
    DataC_Prison_Escape_sRoom, \
    DataC_Prison_Tunnel_sRoom, \
    DataC_Prison_Tall_sRoom, \
    DataC_Town_Outdoors_sRoom
.LINECONT -

;;;=========================================================================;;;

.ZEROPAGE

;;; The currently-loaded room.
.EXPORTZP Zp_Current_sRoom
Zp_Current_sRoom: .tag sRoom

;;; The currently-loaded tileset.
.EXPORTZP Zp_Current_sTileset
Zp_Current_sTileset: .tag sTileset

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Pointers to sRoom structs for all rooms in the game, indexed by eRoom
;;; values.
.PROC DataA_Room_Table_sRoom_ptr_0_arr
:   .lobytes RoomPtrs
    .assert * - :- = kNumRooms, error
.ENDPROC
.PROC DataA_Room_Table_sRoom_ptr_1_arr
:   .hibytes RoomPtrs
    .assert * - :- = kNumRooms, error
.ENDPROC

;;; PRGC bank numbers for all rooms in the game, indexed by eRoom values.
.EXPORT DataA_Room_Banks_u8_arr
.PROC DataA_Room_Banks_u8_arr
    .repeat kNumRooms, index
    .byte <.bank(.mid(index * 2, 1, {RoomPtrs}))
    .endrepeat
.ENDPROC

;;; Loads and initializes data for the specified room.
;;; @prereq The correct PRGC bank has been set for the room to be loaded.
;;; @param X The eRoom value for the room to load.
.EXPORT FuncA_Room_Load
.PROC FuncA_Room_Load
    ;; Get a pointer to the sRoom struct and store it in Zp_Tmp_ptr.
    lda DataA_Room_Table_sRoom_ptr_0_arr, x
    sta Zp_Tmp_ptr + 0
    lda DataA_Room_Table_sRoom_ptr_1_arr, x
    sta Zp_Tmp_ptr + 1
_CopyRoomStruct:
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
    .assert sPlatform::WidthPx_u8 = 1, error
    lda (Zp_Tmp_ptr), y
    beq @copyDone
    sta Zp_Tmp1_byte  ; platform width
    iny
    .assert sPlatform::HeightPx_u8 = 2, error
    lda (Zp_Tmp_ptr), y
    sta Zp_Tmp2_byte  ; platform height
    iny
    .assert sPlatform::Left_i16 = 3, error
    lda (Zp_Tmp_ptr), y
    sta Ram_PlatformLeft_i16_0_arr, x
    add Zp_Tmp1_byte  ; platform width
    sta Ram_PlatformRight_i16_0_arr, x
    iny
    lda (Zp_Tmp_ptr), y
    sta Ram_PlatformLeft_i16_1_arr, x
    adc #0
    sta Ram_PlatformRight_i16_1_arr, x
    iny
    .assert sPlatform::Top_i16 = 5, error
    lda (Zp_Tmp_ptr), y
    sta Ram_PlatformTop_i16_0_arr, x
    add Zp_Tmp2_byte  ; platform height
    sta Ram_PlatformBottom_i16_0_arr, x
    iny
    lda (Zp_Tmp_ptr), y
    sta Ram_PlatformTop_i16_1_arr, x
    adc #0
    sta Ram_PlatformBottom_i16_1_arr, x
    iny
    .assert .sizeof(sPlatform) = 7, error
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
    ;; State:
    .assert sActor::State_byte = 3, error
    lda (Zp_Tmp_ptr), y
    iny
    sta Ram_ActorState_byte_arr, x
    lda #0
    sta Ram_ActorFlags_bObj_arr, x
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
_CallInit:
    jsr FuncA_Room_InitCurrentRoom
    jmp Func_InitAllMachines
.ENDPROC

;;; Calls the current room's Init_func_ptr function.
.PROC FuncA_Room_InitCurrentRoom
    ldy #sRoomExt::Init_func_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
.ENDPROC

;;; Called when exiting the room via a passage.  Shifts the avatar position
;;; perpendicular to the passage direction, and determines the destination room
;;; number.
;;; @param X The bPassage value for the passage the player went through.
;;; @return A The eRoom value for the room that should be loaded next.
.EXPORT FuncA_Room_ExitViaPassage
.PROC FuncA_Room_ExitViaPassage
    stx Zp_Tmp1_byte  ; bPassage value
    ;; Copy the current room's Passages_sPassage_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Passages_sPassage_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Find the sPassage entry for the bPassage the player went through.
    .assert sPassage::Exit_bPassage = 0, error
    ldy #0
    beq @find  ; unconditional
    @wrongSide:
    .repeat .sizeof(sPassage)
    iny
    .endrepeat
    @find:
    lda (Zp_Tmp_ptr), y  ; ExitSide_ePassage
    cmp Zp_Tmp1_byte  ; bPassage value
    bne @wrongSide
    .assert sPassage::PositionAdjust_i16 = 1, error
    iny
    lda (Zp_Tmp_ptr), y  ; PositionAdjust_i16 + 0
    iny
    clc
    .assert bPassage::EastWest = $80, error
    bit Zp_Tmp1_byte  ; bPassage value
    bpl @upDown
    @eastWest:
    adc Zp_AvatarPosY_i16 + 0
    sta Zp_AvatarPosY_i16 + 0
    lda (Zp_Tmp_ptr), y  ; PositionAdjust_i16 + 1
    adc Zp_AvatarPosY_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
    jmp @returnDestination
    @upDown:
    ;; TODO: add PositionAdjust_i16 to Zp_AvatarPosX_i16
    @returnDestination:
    .assert sPassage::Destination_eRoom = 3, error
    iny
    lda (Zp_Tmp_ptr), y  ; Destination_eRoom
    rts
.ENDPROC

;;;=========================================================================;;;
