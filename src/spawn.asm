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
.INCLUDE "macros.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "spawn.inc"

.IMPORT FuncA_Avatar_InitMotionless
.IMPORT FuncA_Avatar_UpdateAndMarkMinimap
.IMPORT Ram_DeviceBlockCol_u8_arr
.IMPORT Ram_DeviceBlockRow_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_LastSafe_bSpawn
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

;;; How far from the edge of the screen to position the avatar when spawning at
;;; a passage.
kPassageSpawnMargin = 15

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Spawns the player avatar into the current room at the location specified by
;;; Sram_LastSafe_bSpawn.
;;; @prereq The room is loaded.
.EXPORT FuncA_Avatar_SpawnAtLastSafePoint
.PROC FuncA_Avatar_SpawnAtLastSafePoint
    ;; Check what kind of spawn point is set.
    lda Sram_LastSafe_bSpawn
    .assert bSpawn::IsPassage = bProc::Negative, error
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
    jmp FuncA_Avatar_FinishSpawn
_BottomEdge:
    lda <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bne @tall
    @short:
    ldx #kScreenHeightPx - kPassageSpawnMargin
    bne @finishBottom  ; unconditional
    @tall:
    ldax #kTallRoomHeightBlocks * kBlockHeightPx - kPassageSpawnMargin
    @finishBottom:
    stax Zp_AvatarPosY_i16
    lda #$ff  ; param: is airborne ($ff = true)
    ldx #0  ; param: facing direction (0 = right)
    jmp FuncA_Avatar_FinishSpawn
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
    jmp FuncA_Avatar_FinishSpawn
_WestEdge:
    lda <(Zp_Current_sRoom + sRoom::MinScrollX_u8)
    add #kPassageSpawnMargin
    sta Zp_AvatarPosX_i16 + 0
    lda #0
    sta Zp_AvatarPosX_i16 + 1
    lda #0  ; param: is airborne (0 = false)
    tax  ; param: facing direction (0 = right)
    jmp FuncA_Avatar_FinishSpawn
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
    jmp FuncA_Avatar_FinishSpawn
_DeviceOffset_u8_arr:
    D_ENUM eDevice
    d_byte None,    $08
    d_byte Console, $06
    d_byte Door,    $08
    d_byte Flower,  $08
    d_byte Lever,   $06
    d_byte Sign,    $06
    d_byte Upgrade, $08
    D_END
.ENDPROC

;;; Initializes the player avatar.
;;; @prereq The room is loaded.
;;; @prereq The avatar position has been initialized.
;;; @param A True ($ff) if airborne, false ($00) otherwise.
;;; @param X The facing direction (either 0 or bObj::FlipH).
.PROC FuncA_Avatar_FinishSpawn
    jsr FuncA_Avatar_InitMotionless
    jmp FuncA_Avatar_UpdateAndMarkMinimap
.ENDPROC

;;;=========================================================================;;;
