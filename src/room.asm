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
.INCLUDE "room.inc"

.IMPORT DataC_Room_Short_sRoom
.IMPORT DataC_Room_Tall_sRoom
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
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

;;; TODO: Move these data tables into PRGA somewhere.
.SEGMENT "PRG8"

.LINECONT +
.DEFINE RoomPtrs \
    DataC_Room_Tall_sRoom, \
    DataC_Room_Short_sRoom
.LINECONT -

;;; Pointers to sRoom structs for all rooms in the game, indexed by eRoom
;;; values.
.PROC Data_Rooms_sRoom_ptr_0_arr
:   .lobytes RoomPtrs
    .assert * - :- = kNumRooms, error
.ENDPROC
.PROC Data_Rooms_sRoom_ptr_1_arr
:   .hibytes RoomPtrs
    .assert * - :- = kNumRooms, error
.ENDPROC

;;; PRGC bank numbers for all rooms in the game, indexed by eRoom values.
.EXPORT Data_RoomBanks_u8_arr
.PROC Data_RoomBanks_u8_arr
    .repeat kNumRooms, index
    .byte <.bank(.mid(index * 2, 1, {RoomPtrs}))
    .endrepeat
.ENDPROC

;;; Loads and initializes data for the specified room.
;;; @prereq The correct PRGC bank has been set for the room to be loaded.
;;; @param X The eRoom value for the room to load.
.EXPORT Func_LoadRoom
.PROC Func_LoadRoom
    ;; Get a pointer to the sRoom struct and store it in Zp_Tmp_ptr.
    lda Data_Rooms_sRoom_ptr_0_arr, x
    sta Zp_Tmp_ptr + 0
    lda Data_Rooms_sRoom_ptr_1_arr, x
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
    jsr Func_InitCurrentRoom
    jmp Func_InitAllMachines
.ENDPROC

;;; Calls the current room's Init_func_ptr function.
.PROC Func_InitCurrentRoom
    ldy #sRoomExt::Init_func_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
.ENDPROC

;;; Called when exiting the room via a door.
;;; @param X The bDoor value for the door the player went through.
;;; @return A The eRoom value for the room that should be loaded next.
.EXPORT Func_ExitCurrentRoom
.PROC Func_ExitCurrentRoom
    stx Zp_Tmp1_byte  ; bDoor value
    ;; Copy the current room's Exits_sDoor_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Exits_sDoor_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Find the sDoor entry for the bDoor the player went through.
    .assert sDoor::Exit_bDoor = 0, error
    ldy #0
    beq @find  ; unconditional
    @wrongSide:
    .repeat .sizeof(sDoor)
    iny
    .endrepeat
    @find:
    lda (Zp_Tmp_ptr), y  ; ExitSide_eDoor
    cmp Zp_Tmp1_byte  ; bDoor value
    bne @wrongSide
    .assert sDoor::PositionAdjust_i16 = 1, error
    iny
    lda (Zp_Tmp_ptr), y  ; PositionAdjust_i16 + 0
    iny
    clc
    .assert bDoor::EastWest = $80, error
    bit Zp_Tmp1_byte  ; bDoor value
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
    .assert sDoor::Destination_eRoom = 3, error
    iny
    lda (Zp_Tmp_ptr), y  ; Destination_eRoom
    rts
.ENDPROC

;;;=========================================================================;;;
