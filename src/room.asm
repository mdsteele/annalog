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
.INCLUDE "avatar.inc"
.INCLUDE "cpu.inc"
.INCLUDE "device.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "platform.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "tileset.inc"

.IMPORT DataC_Crypt_Flower_sRoom
.IMPORT DataC_Crypt_Landing_sRoom
.IMPORT DataC_Garden_Boss_sRoom
.IMPORT DataC_Garden_Landing_sRoom
.IMPORT DataC_Garden_Shrine_sRoom
.IMPORT DataC_Garden_Tower_sRoom
.IMPORT DataC_Garden_Tunnel_sRoom
.IMPORT DataC_Mermaid_Flower_sRoom
.IMPORT DataC_Mermaid_House1_sRoom
.IMPORT DataC_Prison_Cell_sRoom
.IMPORT DataC_Prison_Escape_sRoom
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
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_HudMachineIndex_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

.LINECONT +
.DEFINE RoomPtrs \
    DataC_Crypt_Flower_sRoom, \
    DataC_Crypt_Landing_sRoom, \
    DataC_Garden_Boss_sRoom, \
    DataC_Garden_Landing_sRoom, \
    DataC_Garden_Shrine_sRoom, \
    DataC_Garden_Tower_sRoom, \
    DataC_Garden_Tunnel_sRoom, \
    DataC_Mermaid_Flower_sRoom, \
    DataC_Mermaid_House1_sRoom, \
    DataC_Prison_Cell_sRoom, \
    DataC_Prison_Escape_sRoom, \
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
_ClearHud:
    lda #$ff
    sta Zp_HudMachineIndex_u8
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

;;; Called when exiting the room via a passage.  Determines the origin passage
;;; spawn block and the destination room number.
;;; @param X The bPassage value for the passage the player went through.
;;; @return A The SpawnBlock_u8 value for the origin room.
;;; @return X The eRoom value for the destination room.
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
    ldy #0
    beq @find  ; unconditional
    @wrongSide:
    .repeat .sizeof(sPassage)
    iny
    .endrepeat
    @find:
    .assert sPassage::Exit_bPassage = 0, error
    lda (Zp_Tmp_ptr), y  ; Exit_ePassage
    cmp Zp_Tmp1_byte  ; bPassage value
    bne @wrongSide
    iny
    .assert sPassage::Destination_eRoom = 1, error
    lda (Zp_Tmp_ptr), y  ; Destination_eRoom
    tax
    iny
    .assert sPassage::SpawnBlock_u8 = 2, error
    lda (Zp_Tmp_ptr), y  ; SpawnBlock_u8
    rts
.ENDPROC

;;; Called when entering the room via a passage.  Repositions the avatar based
;;; on the size of the new room and the difference between the origin and
;;; destination passages' SpawnBlock_u8 values.
;;; @prereq The current room is loaded, and Zp_Previous_eRoom is initialized.
;;; @param A The SpawnBlock_u8 for the origin passage in the previous room.
.EXPORT FuncA_Room_EnterViaPassage
.PROC FuncA_Room_EnterViaPassage
    sta Zp_Tmp1_byte  ; origin passage's SpawnBlock_u8
_FindDestinationPassage:
    ;; Copy the current room's Passages_sPassage_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Passages_sPassage_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Find the sPassage entry in the new room whose Destination_eRoom is
    ;; Zp_Previous_eRoom.
    ldy #0
    @loop:
    .assert sPassage::Exit_bPassage = 0, error
    lda (Zp_Tmp_ptr), y  ; destination passage's Exit_bPassage
    and #bPassage::SideMask
    sta Zp_Tmp2_byte  ; destination ePassage value
    iny
    .assert sPassage::Destination_eRoom = 1, error
    lda (Zp_Tmp_ptr), y
    iny
    cmp Zp_Previous_eRoom
    beq @found
    iny
    .assert .sizeof(sPassage) = 3, error
    bne @loop  ; unconditional
    @found:
    .assert sPassage::SpawnBlock_u8 = 2, error
    lda (Zp_Tmp_ptr), y  ; destination passage's SpawnBlock_u8
_AdjustPosition:
    ;; Compute the (signed, 16-bit) perpendicular pixel position adjustment,
    ;; storing the lo byte in A and the hi byte in Zp_Tmp1_byte.
    ldy #0
    sub Zp_Tmp1_byte  ; origin passage's SpawnBlock_u8
    bpl @nonnegative
    dey  ; now Y is $ff
    @nonnegative:
    sty Zp_Tmp1_byte  ; perpendicular position adjust (hi)
    .repeat 4
    asl a
    rol Zp_Tmp1_byte  ; perpendicular position adjust (hi)
    .endrepeat
    ;; Determine if the passage is east/west or up/down.
    bit Zp_Tmp2_byte  ; destination ePassage value
    .assert bPassage::EastWest = bProc::Negative, error
    bmi _EastWest
_UpDown:
    ;; Adjust the horizontal position.
    add Zp_AvatarPosX_i16 + 0
    sta Zp_AvatarPosX_i16 + 0
    lda Zp_Tmp1_byte  ; perpendicular position adjust (hi)
    adc Zp_AvatarPosX_i16 + 1
    sta Zp_AvatarPosX_i16 + 1
    ;; Set the vertical position.
    lda Zp_Tmp2_byte  ; destination ePassage value
    cmp #ePassage::Bottom
    beq @bottomEdge
    @topEdge:
    lda #kTileHeightPx + 1
    sta Zp_AvatarPosY_i16 + 0
    lda #0
    sta Zp_AvatarPosY_i16 + 1
    rts
    @bottomEdge:
    lda <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bne @tall
    @short:
    ldx #kScreenHeightPx - (kAvatarBoundingBoxDown + 1)
    bne @finishBottom  ; unconditional
    @tall:
    ldax #kTallRoomHeightBlocks * kBlockHeightPx - (kAvatarBoundingBoxDown + 1)
    @finishBottom:
    stax Zp_AvatarPosY_i16
    rts
_EastWest:
    ;; Adjust the vertical position.
    add Zp_AvatarPosY_i16 + 0
    sta Zp_AvatarPosY_i16 + 0
    lda Zp_Tmp1_byte  ; perpendicular position adjust (hi)
    adc Zp_AvatarPosY_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
    ;; Set the horizontal position.
    lda Zp_Tmp2_byte  ; destination ePassage value
    cmp #ePassage::Western
    beq @westEdge
    @eastEdge:
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 0)
    add #kScreenWidthPx - 8
    sta Zp_AvatarPosX_i16 + 0
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 1)
    adc #0
    sta Zp_AvatarPosX_i16 + 1
    rts
    @westEdge:
    lda <(Zp_Current_sRoom + sRoom::MinScrollX_u8)
    add #8
    sta Zp_AvatarPosX_i16 + 0
    lda #0
    sta Zp_AvatarPosX_i16 + 1
    rts
.ENDPROC

;;;=========================================================================;;;
