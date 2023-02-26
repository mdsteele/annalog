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

.INCLUDE "avatar.inc"
.INCLUDE "cpu.inc"
.INCLUDE "device.inc"
.INCLUDE "devices/breaker.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "spawn.inc"

.IMPORT FuncA_Avatar_InitMotionless
.IMPORT FuncA_Room_InitAllMachines
.IMPORT Ram_DeviceBlockCol_u8_arr
.IMPORT Ram_DeviceBlockRow_u8_arr
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_LastSafe_bSpawn
.IMPORT Sram_LastSafe_eRoom
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Current_eRoom
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_Previous_eRoom
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp4_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

;;; How far from the edge of the screen to position the avatar when spawning at
;;; a passage.
kPassageSpawnMargin = 15

;;; Ensure that the bSpawn index mask is wide enough to include any device or
;;; passage index.
.ASSERT bSpawn::IndexMask + 1 >= kMaxDevices, error
.ASSERT bSpawn::IndexMask + 1 >= kMaxPassages, error

;;;=========================================================================;;;

.ZEROPAGE

;;; The last spawn point visited (whether safe or not).
Zp_LastPoint_bSpawn: .res 1
Zp_LastPoint_eRoom: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Sets the last spawn point to the specified point in the current room.  If
;;; the current room is currently marked as safe, then the last safe point will
;;; also be set.
;;; @param A The bSpawn value to set for the current room.
;;; @preserve X, Y, Zp_Tmp_*
.EXPORT Func_SetLastSpawnPoint
.PROC Func_SetLastSpawnPoint
    sta Zp_LastPoint_bSpawn
    lda Zp_Current_eRoom
    sta Zp_LastPoint_eRoom
    bit Zp_Current_sRoom + sRoom::Flags_bRoom
    .assert bRoom::Unsafe = bProc::Negative, error
    bpl Func_UpdateLastSafePoint  ; preserves X, Y, and Zp_Tmp_*
    rts
.ENDPROC

;;; If bRoom::Unsafe is set on (Zp_Current_sRoom + sRoom::Flags_bRoom), clears
;;; that flag and copies the last visited spawn point to the last safe point.
;;; @preserve X, Y, Zp_Tmp_*
.EXPORT Func_MarkRoomSafe
.PROC Func_MarkRoomSafe
    lda Zp_Current_sRoom + sRoom::Flags_bRoom
    .assert bRoom::Unsafe = bProc::Negative, error
    bmi @markSafe
    rts
    @markSafe:
    and #<~bRoom::Unsafe
    sta Zp_Current_sRoom + sRoom::Flags_bRoom
    .assert * = Func_UpdateLastSafePoint, error, "fallthrough"
.ENDPROC

;;; Copies Zp_LastPoint_* to Sram_LastSafe_*.
;;; @preserve X, Y, Zp_Tmp_*
.PROC Func_UpdateLastSafePoint
    ;; Enable writes to SRAM.
    lda #bMmc3PrgRam::Enable
    sta Hw_Mmc3PrgRamProtect_wo
    ;; Set the last safe point.
    lda Zp_LastPoint_bSpawn
    sta Sram_LastSafe_bSpawn
    lda Zp_LastPoint_eRoom
    sta Sram_LastSafe_eRoom
    ;; Disable writes to SRAM.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Spawns the player avatar into the last safe point.
;;; @prereq The last safe room is loaded.
.EXPORT FuncA_Avatar_SpawnAtLastSafePoint
.PROC FuncA_Avatar_SpawnAtLastSafePoint
    lda Sram_LastSafe_eRoom
    sta Zp_LastPoint_eRoom
    lda Sram_LastSafe_bSpawn
    sta Zp_LastPoint_bSpawn
    ;; Check what kind of spawn point is set.
    .assert bSpawn::Passage = bProc::Negative, error
    bmi _SpawnAtPassage
_SpawnAtDevice:
    and #bSpawn::IndexMask
    tax  ; param: device index
    jmp FuncA_Avatar_SpawnAtDevice
_SpawnAtPassage:
    and #bSpawn::IndexMask  ; param: passage index
    .assert * = FuncA_Avatar_SpawnAtPassage, error, "fallthrough"
.ENDPROC

;;; Spawns the player avatar into the current room at the specified passage.
;;; @prereq The room is loaded.
;;; @param A The passage index in the current room.
.PROC FuncA_Avatar_SpawnAtPassage
    sta Zp_Tmp1_byte  ; passage index
    ;; Copy the current room's Passages_sPassage_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Passages_sPassage_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Compute the byte offset into Passages_sPassage_arr_ptr.
    .assert .sizeof(sPassage) = 3, error
    lda Zp_Tmp1_byte  ; passage index
    mul #2  ; this will clear the carry flag, since passage index is < $80
    adc Zp_Tmp1_byte  ; passage index
    tay
    ;; Read fields out of the sPassage struct.
    .assert sPassage::Exit_bPassage = 0, error
    lda (Zp_Tmp_ptr), y
    and #bPassage::SideMask
    sta Zp_Tmp1_byte  ; ePassage value
    iny
    iny
    .assert sPassage::SpawnBlock_u8 = 2, error
    lda (Zp_Tmp_ptr), y  ; spawn block
    ;; Convert the spawn block row/col to a 16-bit room pixel position, storing
    ;; it in YA.
    ldy #0
    sty Zp_Tmp2_byte
    .assert kMaxRoomWidthBlocks <= $80, error
    .assert kTallRoomHeightBlocks <= $20, error
    asl a      ; A room block row/col fits in at most seven bits, so the first
    .repeat 3  ; ASL won't set the carry bit, so we only need to ROL the high
    asl a      ; byte after the second ASL.
    rol Zp_Tmp2_byte
    .endrepeat
    ldy Zp_Tmp2_byte
    ;; Check what kind of passage this is.
    bit Zp_Tmp1_byte  ; ePassage value
    .assert bPassage::EastWest = bProc::Negative, error
    bmi _EastWest
_UpDown:
    ora #kTileWidthPx
    stya Zp_AvatarPosX_i16
    lda Zp_Tmp1_byte  ; ePassage value
    cmp #ePassage::Bottom
    beq _BottomEdge
_TopEdge:
    lda #kTileHeightPx + 1
    sta Zp_AvatarPosY_i16 + 0
    lda #0
    sta Zp_AvatarPosY_i16 + 1
    lda #$ff  ; param: is airborne ($ff = true)
    ldx #0  ; param: facing direction (0 = right)
    beq _Finish  ; unconditional
_BottomEdge:
    bit <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    .assert bRoom::Tall = bProc::Overflow, error
    bvs @tall
    @short:
    ldx #kScreenHeightPx - kPassageSpawnMargin
    lda #0
    beq @finishBottom  ; unconditional
    @tall:
    ldax #kTallRoomHeightBlocks * kBlockHeightPx - kPassageSpawnMargin
    @finishBottom:
    stax Zp_AvatarPosY_i16
    lda #$ff  ; param: is airborne ($ff = true)
    ldx #0  ; param: facing direction (0 = right)
    beq _Finish  ; unconditional
_EastWest:
    ora #kBlockHeightPx - kAvatarBoundingBoxDown
    stya Zp_AvatarPosY_i16
    lda Zp_Tmp1_byte  ; ePassage value
    cmp #ePassage::Western
    beq _WestEdge
_EastEdge:
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 0)
    add #kScreenWidthPx - kPassageSpawnMargin
    sta Zp_AvatarPosX_i16 + 0
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 1)
    adc #0
    sta Zp_AvatarPosX_i16 + 1
    lda #0  ; param: is airborne (0 = false)
    ldx #bObj::FlipH  ; param: facing direction (FlipH = left)
    bne _Finish  ; unconditional
_WestEdge:
    lda <(Zp_Current_sRoom + sRoom::MinScrollX_u8)
    add #kPassageSpawnMargin
    sta Zp_AvatarPosX_i16 + 0
    lda #0
    sta Zp_AvatarPosX_i16 + 1
    lda #0  ; param: is airborne (0 = false)
    tax  ; param: facing direction (0 = right)
_Finish:
    jmp FuncA_Avatar_InitMotionless
.ENDPROC

;;; Called when entering a new room via a door device.  Marks the entrance door
;;; as the last spawn point and positions the player avatar at that door.
;;; @prereq The new room is loaded, and Zp_Previous_eRoom is initialized.
.EXPORT FuncA_Avatar_EnterRoomViaDoor
.PROC FuncA_Avatar_EnterRoomViaDoor
    ;; Find the corresponding door (of any type) to enter from in the new room.
    ldx #kMaxDevices - 1
    @loop:
    lda Ram_DeviceType_eDevice_arr, x
    cmp #eDevice::LockedDoor
    beq @door
    cmp #eDevice::OpenDoorway
    beq @door
    cmp #eDevice::UnlockedDoor
    bne @continue
    @door:
    lda Ram_DeviceTarget_u8_arr, x
    cmp Zp_Previous_eRoom
    beq @break
    @continue:
    dex
    .assert kMaxDevices <= $80, error
    bpl @loop
    inx
    @break:
    ;; Update the the last spawn point.
    txa  ; door device index
    ora #bSpawn::Device  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint  ; preserves X
    ;; Spawn the avatar.
    .assert * = FuncA_Avatar_SpawnAtDevice, error, "fallthrough"
.ENDPROC

;;; Spawns the player avatar into the current room at the specified device.
;;; @prereq The room is loaded.
;;; @param X The device index in the current room.
.EXPORT FuncA_Avatar_SpawnAtDevice
.PROC FuncA_Avatar_SpawnAtDevice
    ;; Position the avatar in front of the device.
    lda #0
    sta Zp_AvatarPosX_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
    lda Ram_DeviceBlockCol_u8_arr, x
    .assert kMaxRoomWidthBlocks <= $80, error
    asl a      ; Since kMaxRoomWidthBlocks <= $80, the device block col fits in
    .repeat 3  ; seven bits, so the first ASL won't set the carry bit, so we
    asl a      ; only need to ROL (Zp_AvatarPosX_i16 + 1) after the second ASL.
    rol Zp_AvatarPosX_i16 + 1
    .endrepeat
    ldy Ram_DeviceType_eDevice_arr, x
    ora _DeviceOffset_u8_arr, y
    sta Zp_AvatarPosX_i16 + 0
    lda Ram_DeviceBlockRow_u8_arr, x
    .assert kTallRoomHeightBlocks <= $20, error
    asl a  ; Since kTallRoomHeightBlocks <= $20, the device block row fits in
    asl a  ; five bits, so the first three ASL's won't set the carry bit, so
    asl a  ; we only need to ROL (Zp_AvatarPosY_i16 + 1) after the fourth ASL.
    asl a
    rol Zp_AvatarPosY_i16 + 1
    ora #kBlockHeightPx - kAvatarBoundingBoxDown
    sta Zp_AvatarPosY_i16 + 0
    ;; Make the avatar stand still, facing to the right.
    lda #0  ; param: is airborne (0 = false)
    tax  ; param: facing direction (0 = right)
    jmp FuncA_Avatar_InitMotionless
_DeviceOffset_u8_arr:
    D_ENUM eDevice
    d_byte None,          $08
    d_byte BreakerDone,   kBreakerAvatarOffset
    d_byte BreakerRising, kBreakerAvatarOffset
    d_byte LockedDoor,    $08
    d_byte Placeholder,   $08
    d_byte Teleporter,    $08
    d_byte BreakerReady,  kBreakerAvatarOffset
    d_byte Console,       $06
    d_byte Flower,        $08
    d_byte LeverCeiling,  $06
    d_byte LeverFloor,    $06
    d_byte OpenDoorway,   $08
    d_byte Paper,         $06
    d_byte Sign,          $06
    d_byte TalkLeft,      $0a
    d_byte TalkRight,     $06
    d_byte UnlockedDoor,  $08
    d_byte Upgrade,       $08
    D_END
.ENDPROC

;;; Called when exiting the room via a passage.  Marks the exit passage as the
;;; last spawn point (in case this room is safe and the destination room turns
;;; out to be unsafe).  Returns the origin passage spawn block and the
;;; destination room number.
;;; @param X The calculated bPassage value for the passage the player went
;;;     through (which includes SideMask and ScreenMask only).
;;; @return A The SpawnBlock_u8 value for the origin room.
;;; @return X The eRoom value for the destination room.
.EXPORT FuncA_Avatar_ExitRoomViaPassage
.PROC FuncA_Avatar_ExitRoomViaPassage
    stx Zp_Tmp1_byte  ; calculated bPassage value
    ;; Copy the current room's Passages_sPassage_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Passages_sPassage_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Find the sPassage entry for the bPassage the player went through.
    ldy #0
    sty Zp_Tmp2_byte  ; passage index
    beq @find  ; unconditional
    @wrongSide:
    .repeat .sizeof(sPassage)
    iny
    .endrepeat
    inc Zp_Tmp2_byte  ; passage index
    @find:
    .assert sPassage::Exit_bPassage = 0, error
    lda (Zp_Tmp_ptr), y
    and #bPassage::SideMask | bPassage::ScreenMask
    cmp Zp_Tmp1_byte  ; calculated bPassage value
    bne @wrongSide
    lda Zp_Tmp2_byte  ; passage index
    ora #bSpawn::Passage  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint  ; preserves Y and Zp_Tmp_*
    iny
    .assert sPassage::Destination_eRoom = 1, error
    lda (Zp_Tmp_ptr), y  ; Destination_eRoom
    tax
    iny
    .assert sPassage::SpawnBlock_u8 = 2, error
    lda (Zp_Tmp_ptr), y  ; SpawnBlock_u8
    rts
.ENDPROC

;;; Called when entering a new room via a passage.  Marks the entrance passage
;;; as the last spawn point, and repositions the player avatar based on the
;;; size of the new room and the difference between the origin/destination
;;; passages' SpawnBlock_u8 values.
;;; @prereq The new room is loaded, and Zp_Previous_eRoom is initialized.
;;; @param X The (calculated) origin bPassage value.
;;; @param Y The SpawnBlock_u8 for the origin passage in the previous room.
.EXPORT FuncA_Avatar_EnterRoomViaPassage
.PROC FuncA_Avatar_EnterRoomViaPassage
    txa  ; origin bPassage value (calculated)
    and #bPassage::ScreenMask
    sta Zp_Tmp4_byte  ; origin passage's screen number
    sty Zp_Tmp1_byte  ; origin passage's SpawnBlock_u8
_FindDestinationPassage:
    ;; Copy the current room's Passages_sPassage_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Passages_sPassage_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Loop through the sPassage entries in the new room until we find a match.
    ;; (Note that we simply assume that we'll find one; there's no check for
    ;; the end of the sPassage array.)
    ldy #0
    sty Zp_Tmp3_byte  ; passage index
    @loop:
    ;; Store the destination passage's bPassage value for later.
    .assert sPassage::Exit_bPassage = 0, error
    lda (Zp_Tmp_ptr), y
    iny  ; now Y % .sizeof(sPassage) is 1
    sta Zp_Tmp2_byte  ; destination bPassage value
    ;; If this destination passage has the SameScreen bit set, then the two
    ;; passages must have the same screen number in order to count as a match.
    and #bPassage::SameScreen
    beq @screenMatches  ; SameScreen bit not set, so any screen number is fine
    lda Zp_Tmp2_byte  ; destination bPassage value
    and #bPassage::ScreenMask
    cmp Zp_Tmp4_byte  ; origin passage's screen number
    beq @screenMatches
    iny  ; now Y % .sizeof(sPassage) is 2
    bne @doesNotMatch  ; unconditional
    @screenMatches:
    ;; In order for the passages to match, the destination passage's eRoom must
    ;; be the room that the origin passage was in.
    .assert sPassage::Destination_eRoom = 1, error
    lda (Zp_Tmp_ptr), y
    iny  ; now Y % .sizeof(sPassage) is 2
    cmp Zp_Previous_eRoom
    beq @foundMatch
    ;; If the passages don't match, then move on to the next potential
    ;; destination passage.
    @doesNotMatch:
    iny  ; now Y % .sizeof(sPassage) is 3
    .assert .sizeof(sPassage) = 3, error
    inc Zp_Tmp3_byte  ; passage index
    bne @loop  ; unconditional
    @foundMatch:
    ;; Update the the last spawn point.
    lda Zp_Tmp3_byte  ; passage index
    ora #bSpawn::Passage  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint  ; preserves Y and Zp_Tmp_*
    ;; Prepare to adjust position.
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
    bit Zp_Tmp2_byte  ; destination bPassage value
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
    lda Zp_Tmp2_byte  ; destination bPassage value
    and #bPassage::SideMask
    cmp #ePassage::Bottom
    beq @bottomEdge
    @topEdge:
    lda #kTileHeightPx + 1
    sta Zp_AvatarPosY_i16 + 0
    lda #0
    sta Zp_AvatarPosY_i16 + 1
    rts
    @bottomEdge:
    bit <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    .assert bRoom::Tall = bProc::Overflow, error
    bvs @tall
    @short:
    ldx #kScreenHeightPx - (kAvatarBoundingBoxDown + 1)
    lda #0
    beq @finishBottom  ; unconditional
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
    lda Zp_Tmp2_byte  ; destination bPassage value
    and #bPassage::SideMask
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

.SEGMENT "PRGA_Room"

;;; Initializes state for all machines in the current room, then calls the
;;; current room's Enter_func_ptr with the last spawn point as an argument.
.EXPORT FuncA_Room_InitAllMachinesAndCallRoomEnter
.PROC FuncA_Room_InitAllMachinesAndCallRoomEnter
    jsr FuncA_Room_InitAllMachines
    .assert * = FuncA_Room_CallRoomEnter, error, "fallthrough"
.ENDPROC

;;; Calls the current room's Enter_func_ptr with the last spawn point as an
;;; argument.
.PROC FuncA_Room_CallRoomEnter
    ldy #sRoomExt::Enter_func_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    lda Zp_LastPoint_bSpawn  ; param: spawn point
    jmp (Zp_Tmp_ptr)
.ENDPROC

;;;=========================================================================;;;
