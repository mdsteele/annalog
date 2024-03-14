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
.INCLUDE "devices/console.inc"
.INCLUDE "devices/dialog.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "spawn.inc"

.IMPORT FuncA_Avatar_InitMotionless
.IMPORT FuncA_Room_InitAllMachines
.IMPORT Func_TryPushAvatarVert
.IMPORT Ram_DeviceBlockCol_u8_arr
.IMPORT Ram_DeviceBlockRow_u8_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_LastSafe_bSpawn
.IMPORT Sram_LastSafe_eRoom
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarPushDelta_i8
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_Current_eRoom
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_Nearby_bDevice
.IMPORTZP Zp_Previous_eRoom

;;;=========================================================================;;;

;;; The horizontal mod-16 offset within a door device's block that the player
;;; avatar should be positioned at when entering the room via a door.
kDoorAvatarOffset = $08

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

;;; Sets the last spawn point to the nearby device in the current room.  If the
;;; current room is currently marked as safe, then the last safe point will
;;; also be set.
;;; @prereq Zp_Nearby_bDevice holds an active device.
;;; @preserve X, Y, T0+
.EXPORT Func_SetLastSpawnPointToActiveDevice
.PROC Func_SetLastSpawnPointToActiveDevice
    lda Zp_Nearby_bDevice
    and #bDevice::IndexMask
    ora #bSpawn::Device  ; param: bSpawn value
    .assert * = Func_SetLastSpawnPoint, error, "fallthrough"
.ENDPROC

;;; Sets the last spawn point to the specified point in the current room.  If
;;; the current room is currently marked as safe, then the last safe point will
;;; also be set.
;;; @param A The bSpawn value to set for the current room.
;;; @preserve X, Y, T0+
.EXPORT Func_SetLastSpawnPoint
.PROC Func_SetLastSpawnPoint
    sta Zp_LastPoint_bSpawn
    lda Zp_Current_eRoom
    sta Zp_LastPoint_eRoom
    bit Zp_Current_sRoom + sRoom::Flags_bRoom
    .assert bRoom::Unsafe = bProc::Negative, error
    bpl Func_UpdateLastSafePoint  ; preserves X, Y, and T0+
    rts
.ENDPROC

;;; If bRoom::Unsafe is set on (Zp_Current_sRoom + sRoom::Flags_bRoom), clears
;;; that flag and copies the last visited spawn point to the last safe point.
;;; @preserve X, Y, T0+
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
;;; @preserve X, Y, T0+
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
    pha  ; passage index
    jsr FuncA_Avatar_GetRoomPassages  ; returns T1T0
    ;; Compute the byte offset into Passages_sPassage_arr_ptr.
    pla  ; passage index
    mul #.sizeof(sPassage)
    tay  ; passage byte offset
    ;; Read fields out of the sPassage struct.
    .assert sPassage::Exit_bPassage = 0, error
    lda (T1T0), y
    and #bPassage::SideMask
    sta T4  ; ePassage value
    iny  ; now Y % .sizeof(sPassage) is 1
    iny  ; now Y % .sizeof(sPassage) is 2
    .assert sPassage::SpawnBlock_u8 = 2, error
    lda (T1T0), y  ; spawn block
    ;; Convert the spawn block row/col to a 16-bit room pixel position, storing
    ;; it in T3T2.
    ldx #0  ; set X to zero for later (and also for initializing T3)
    stx T3  ; spawn pixel position (hi)
    .assert kMaxRoomWidthBlocks <= $80, error
    .assert kTallRoomHeightBlocks <= $20, error
    asl a      ; A room block row/col fits in at most seven bits, so the first
    .repeat 3  ; ASL won't set the carry bit, so we only need to ROL the high
    asl a      ; byte after the second ASL.
    rol T3  ; spawn pixel position (hi)
    .endrepeat
    sta T2  ; spawn pixel position (lo)
    ;; Check what kind of passage this is.
    bit T4  ; ePassage value
    .assert bPassage::EastWest = bProc::Negative, error
    bmi _EastWest
_UpDown:
    ;; At this point, X is still zero.
    iny  ; now Y % .sizeof(sPassage) is 3
    .assert sPassage::SpawnAdjust_byte = 3, error
    lda (T1T0), y  ; spawn adjust
    and #$f0  ; high nibble holds signed horz offset in tiles (-7 to 7)
    cmp #$80  ; copy bit 7 into C
    .assert kTileWidthPx = 8, error
    ror a  ; now A holds signed horz offset in pixels, and C is clear
    adc #kTileWidthPx
    bpl @nonneg
    dex  ; now X is $ff
    @nonneg:
    add T2  ; spawn pixel position (lo)
    sta Zp_AvatarPosX_i16 + 0
    txa
    adc T3  ; spawn pixel position (hi)
    sta Zp_AvatarPosX_i16 + 1
    lda T4  ; ePassage value
    cmp #ePassage::Bottom
    beq _BottomEdge
_TopEdge:
    lda #0
    sta Zp_AvatarPosY_i16 + 1
    ;; If the bottom three bits of SpawnAdjust_byte have nonzero value N, then
    ;; make the player avatar stand in terrain block row N of the room.  If
    ;; they are zero, place the avatar in midair in row zero.
    lda (T1T0), y  ; spawn adjust
    and #$07
    beq @airborne
    @standing:
    mul #kBlockHeightPx  ; clears the carry bit
    adc #kBlockHeightPx - kAvatarBoundingBoxDown
    sta Zp_AvatarPosY_i16 + 0
    ldx #0  ; param: bAvatar value
    beq _SetFaceDirForTopOrBottomPassage  ; unconditional
    @airborne:
    lda #kTileHeightPx + 1
    sta Zp_AvatarPosY_i16 + 0
    ldx #bAvatar::Airborne  ; param: bAvatar value
    bne _SetFaceDirForTopOrBottomPassage  ; unconditional
_BottomEdge:
    ;; Get the height of the room in pixels, storing the lo byte in X and the
    ;; high byte in (Zp_AvatarPosY_i16 + 1).
    bit <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    .assert bRoom::Tall = bProc::Overflow, error
    bvs @tall
    @short:
    ldax #kScreenHeightPx
    bpl @finishBottom  ; unconditional
    @tall:
    ldax #kTallRoomHeightBlocks * kBlockHeightPx
    @finishBottom:
    sta Zp_AvatarPosY_i16 + 1  ; room height (hi)
    ;; If the bottom three bits of SpawnAdjust_byte have nonzero value N, then
    ;; make the player avatar stand on top of the bottom N blocks rows of the
    ;; room.  If those bits are zero, place the avatar in midair near the
    ;; bottom of the room.
    lda (T1T0), y  ; spawn adjust
    and #$07
    beq @airborne
    @standing:
    mul #kBlockHeightPx  ; clears the carry bit
    adc #kAvatarBoundingBoxDown
    sta T4  ; upward adjustment in pixels
    txa  ; room height (lo)
    sub T4  ; upward adjustment in pixels
    sta Zp_AvatarPosY_i16 + 0
    lda Zp_AvatarPosY_i16 + 1  ; room height (hi)
    sbc #0
    sta Zp_AvatarPosY_i16 + 1
    ldx #0  ; param: bAvatar value
    beq _SetFaceDirForTopOrBottomPassage  ; unconditional
    ;; When spawning the player avatar in mid-air near the bottom edge of the
    ;; room, subtract a small margin from the room height to get the avatar's
    ;; Y-position.
    @airborne:
    txa  ; room height (lo)
    sub #kPassageSpawnMargin
    sta Zp_AvatarPosY_i16 + 0
    ;; The hi byte of the room height is already in (Zp_AvatarPosY_i16 + 1),
    ;; and it's still correct post-subtraction (enforced by below assertions).
    .linecont +
    .assert >(kScreenHeightPx - kPassageSpawnMargin) = >kScreenHeightPx, error
    .assert >(kTallRoomHeightBlocks * kBlockHeightPx - kPassageSpawnMargin) = \
            >(kTallRoomHeightBlocks * kBlockHeightPx), error
    .linecont -
    ldx #bAvatar::Airborne  ; param: bAvatar value
_SetFaceDirForTopOrBottomPassage:
    ;; If bit 3 of SpawnAdjust_byte is set, make the player avatar face left;
    ;; otherwise, make the player avatar face right.
    lda (T1T0), y  ; spawn adjust
    and #$08  ; bit 3 determines the facing direction
    .assert bObj::FlipH = $40, error
    mul #8  ; param: facing direction
    bpl _Finish  ; unconditional
_EastWest:
    lda T2  ; spawn pixel position (lo)
    ora #kBlockHeightPx - kAvatarBoundingBoxDown
    sta Zp_AvatarPosY_i16 + 0
    lda T3  ; spawn pixel position (hi)
    sta Zp_AvatarPosY_i16 + 1
    lda T4  ; ePassage value
    cmp #ePassage::Western
    beq _WestEdge
_EastEdge:
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 0)
    add #kScreenWidthPx - kPassageSpawnMargin
    sta Zp_AvatarPosX_i16 + 0
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 1)
    adc #0
    sta Zp_AvatarPosX_i16 + 1
    ldx #0  ; param: bAvatar value
    lda #bObj::FlipH  ; param: facing direction (FlipH = left)
    bne _Finish  ; unconditional
_WestEdge:
    lda <(Zp_Current_sRoom + sRoom::MinScrollX_u8)
    add #kPassageSpawnMargin
    sta Zp_AvatarPosX_i16 + 0
    lda #0  ; param: facing direction (0 = right)
    sta Zp_AvatarPosX_i16 + 1
    tax  ; param: bAvatar value
_Finish:
    jmp FuncA_Avatar_InitMotionless
.ENDPROC

;;; Called when entering a new room via a door device.  Marks the entrance door
;;; as the last spawn point and positions the player avatar at that door.
;;; @prereq The new room is loaded, and Zp_Previous_eRoom is initialized.
;;; @param Y The device type of the origin door from the previous room.
.EXPORT FuncA_Avatar_EnterRoomViaDoor
.PROC FuncA_Avatar_EnterRoomViaDoor
    ;; Find the corresponding door to enter from in the new room.
    ldx #kMaxDevices - 1
    @loop:
    lda Ram_DeviceType_eDevice_arr, x
    cpy #eDevice::Door2Open
    beq @door2
    cpy #eDevice::Door3Open
    beq @door3
    @door1:
    cmp #eDevice::Door1Locked
    beq @foundDoor
    cmp #eDevice::Door1Open
    beq @foundDoor
    cmp #eDevice::Door1Unlocked
    beq @foundDoor
    bne @continue  ; unconditional
    @door2:
    cmp #eDevice::Door2Open
    beq @foundDoor
    bne @continue  ; unconditional
    @door3:
    cmp #eDevice::Door3Open
    bne @continue
    @foundDoor:
    lda Ram_DeviceTarget_byte_arr, x
    cmp Zp_Previous_eRoom
    beq _FoundMatchingDoor
    @continue:
    dex
    .assert kMaxDevices <= $80, error
    bpl @loop
    inx  ; this should never happen, but at least make device index valid
_FoundMatchingDoor:
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
    lda #0  ; param: facing direction (0 = right)
    tax  ; param: bAvatar value
    jsr FuncA_Avatar_InitMotionless
_CheckForShallowWater:
    ;; Check if the avatar has spawned in water, just below the surface.
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvc @done  ; not in water
    lda Zp_AvatarState_bAvatar
    and #bAvatar::DepthMask
    cmp #kTileHeightPx
    bge @done  ; deep in the water
    ;; If the avatar is just below the water's surface, push the avatar up to
    ;; the surface (by negating the depth and using that as the push delta).
    eor #$ff
    tax
    inx
    stx Zp_AvatarPushDelta_i8
    jmp Func_TryPushAvatarVert
    @done:
    rts
_DeviceOffset_u8_arr:
    D_ARRAY .enum, eDevice
    d_byte None,          $08
    d_byte Boiler,        $08
    d_byte BreakerDone,   kBreakerAvatarOffset
    d_byte BreakerRising, kBreakerAvatarOffset
    d_byte Door1Locked,   kDoorAvatarOffset
    d_byte FlowerInert,   $08
    d_byte Mousehole,     $08
    d_byte Placeholder,   $08
    d_byte Teleporter,    $08
    d_byte BreakerReady,  kBreakerAvatarOffset
    d_byte Console,       kConsoleAvatarOffset
    d_byte Door1Open,     kDoorAvatarOffset
    d_byte Door1Unlocked, kDoorAvatarOffset
    d_byte Door2Open,     kDoorAvatarOffset
    d_byte Door3Open,     kDoorAvatarOffset
    d_byte Flower,        $08
    d_byte LeverCeiling,  $06
    d_byte LeverFloor,    $06
    d_byte Paper,         kReadingAvatarOffset
    d_byte Screen,        kConsoleAvatarOffset
    d_byte Sign,          kReadingAvatarOffset
    d_byte TalkLeft,      $0b
    d_byte TalkRight,     $05
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
    stx T2  ; calculated bPassage value
    jsr FuncA_Avatar_GetRoomPassages  ; preserves T2+, returns T1T0
    ;; Find the sPassage entry for the bPassage the player went through.
    ldy #0
    sty T3  ; passage index
    beq @find  ; unconditional
    @wrongSide:
    .repeat .sizeof(sPassage)
    iny
    .endrepeat
    inc T3  ; passage index
    @find:
    .assert sPassage::Exit_bPassage = 0, error
    lda (T1T0), y
    and #bPassage::SideMask | bPassage::ScreenMask
    cmp T2  ; calculated bPassage value
    bne @wrongSide
    lda T3  ; passage index
    ora #bSpawn::Passage  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint  ; preserves Y and T0+
    iny
    .assert sPassage::Destination_eRoom = 1, error
    lda (T1T0), y  ; Destination_eRoom
    tax
    iny
    .assert sPassage::SpawnBlock_u8 = 2, error
    lda (T1T0), y  ; SpawnBlock_u8
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
    sta T3  ; origin passage's screen number
    sty T2  ; origin passage's SpawnBlock_u8
_FindDestinationPassage:
    jsr FuncA_Avatar_GetRoomPassages  ; preserves T2+, returns T1T0
    ;; Loop through the sPassage entries in the new room until we find a match.
    ;; (Note that we simply assume that we'll find one; there's no check for
    ;; the end of the sPassage array.)
    ldy #0
    sty T4  ; passage index
    @loop:
    ;; Store the destination passage's bPassage value for later.
    .assert sPassage::Exit_bPassage = 0, error
    lda (T1T0), y
    iny  ; now Y % .sizeof(sPassage) is 1
    sta T5  ; destination bPassage value
    ;; If this destination passage has the SameScreen bit set, then the two
    ;; passages must have the same screen number in order to count as a match.
    and #bPassage::SameScreen
    beq @screenMatches  ; SameScreen bit not set, so any screen number is fine
    lda T5  ; destination bPassage value
    and #bPassage::ScreenMask
    cmp T3  ; origin passage's screen number
    beq @screenMatches
    iny  ; now Y % .sizeof(sPassage) is 2
    bne @doesNotMatch  ; unconditional
    @screenMatches:
    ;; In order for the passages to match, the destination passage's eRoom must
    ;; be the room that the origin passage was in.
    .assert sPassage::Destination_eRoom = 1, error
    lda (T1T0), y
    iny  ; now Y % .sizeof(sPassage) is 2
    cmp Zp_Previous_eRoom
    beq @foundMatch
    ;; If the passages don't match, then move on to the next potential
    ;; destination passage.
    @doesNotMatch:
    iny  ; now Y % .sizeof(sPassage) is 3
    .assert .sizeof(sPassage) = 4, error
    iny  ; now Y % .sizeof(sPassage) is 0
    inc T4  ; passage index
    bne @loop  ; unconditional
    @foundMatch:
    ;; Update the the last spawn point.
    lda T4  ; passage index
    ora #bSpawn::Passage  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint  ; preserves Y and T0+
    ;; Prepare to adjust position.
    .assert sPassage::SpawnBlock_u8 = 2, error
    lda (T1T0), y  ; destination passage's SpawnBlock_u8
_AdjustPosition:
    ;; Compute the (signed, 16-bit) perpendicular pixel position adjustment,
    ;; storing the lo byte in A and the hi byte in T6.
    ldy #0
    sub T2  ; origin passage's SpawnBlock_u8
    bpl @nonnegative
    dey  ; now Y is $ff
    @nonnegative:
    sty T6  ; perpendicular position adjust (hi)
    .repeat 4
    asl a
    rol T6  ; perpendicular position adjust (hi)
    .endrepeat
    ;; Determine if the passage is east/west or up/down.
    bit T5  ; destination bPassage value
    .assert bPassage::EastWest = bProc::Negative, error
    bmi _EastWest
_UpDown:
    ;; Adjust the horizontal position.
    add Zp_AvatarPosX_i16 + 0
    sta Zp_AvatarPosX_i16 + 0
    lda T6  ; perpendicular position adjust (hi)
    adc Zp_AvatarPosX_i16 + 1
    sta Zp_AvatarPosX_i16 + 1
    ;; Set the vertical position.
    lda T5  ; destination bPassage value
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
    lda T6  ; perpendicular position adjust (hi)
    adc Zp_AvatarPosY_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
    ;; Set the horizontal position.
    lda T5  ; destination bPassage value
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

;;; Returns the current room's Passages_sPassage_arr_ptr.
;;; @return T1T0 The pointer to the passages array.
;;; @preserve X, T2+
.PROC FuncA_Avatar_GetRoomPassages
    ldy #sRoomExt::Passages_sPassage_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes state for all machines in the current room, then calls the
;;; current room's Enter_func_ptr with the last spawn point as an argument.
;;; @prereq Static room data is loaded and avatar is positioned.
.EXPORT FuncA_Room_InitAllMachinesAndCallRoomEnter
.PROC FuncA_Room_InitAllMachinesAndCallRoomEnter
    jsr FuncA_Room_InitAllMachines
    ;; Call the current room's Enter_func_ptr with the last spawn point as an
    ;; argument.
    ldy #sRoomExt::Enter_func_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    lda Zp_LastPoint_bSpawn  ; param: spawn point
    jmp (T1T0)
.ENDPROC

;;;=========================================================================;;;
