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
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "platform.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "terrain.inc"

.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT FuncA_Avatar_CollideWithAllPlatformsHorz
.IMPORT FuncA_Avatar_CollideWithAllPlatformsVert
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT Func_Terrain_GetColumnPtrForTileIndex
.IMPORT Ram_DeviceBlockCol_u8_arr
.IMPORT Ram_DeviceBlockRow_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Sram_Minimap_u16_arr
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_NearbyDevice_u8
.IMPORTZP Zp_P1ButtonsHeld_bJoypad
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_ScrollXHi_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte

;;;=========================================================================;;;

;;; How fast the player avatar is allowed to move, in pixels per frame.
kAvatarMaxSpeedX = 2
kAvatarMaxSpeedY = 5

;;; If the player stops holding the jump button while jumping, then the
;;; avatar's upward speed is immediately capped to this many pixels per frame.
kAvatarStopJumpSpeed = 1

;;; The horizontal acceleration applied to the player avatar when holding the
;;; left/right arrows, in subpixels per frame per frame.
kAvatarHorzAccel = 70

;;; The (signed, 16-bit) initial velocity of the player avatar when jumping, in
;;; subpixels per frame.
kAvatarJumpVelocity = $ffff & -810

;;; The vertical acceleration applied to the player avatar when in midair, in
;;; subpixels per frame per frame.
kAvatarGravity = 48

;;; The OBJ palette number to use for the player avatar.
kAvatarPalette = 1

;;;=========================================================================;;;

.ZEROPAGE

;;; The current X/Y positions of the player avatar, in room-space pixels.
.EXPORTZP Zp_AvatarPosX_i16, Zp_AvatarPosY_i16
Zp_AvatarPosX_i16: .res 2
Zp_AvatarPosY_i16: .res 2

;;; The current minimap cell that the avatar is in.
.EXPORTZP Zp_AvatarMinimapRow_u8, Zp_AvatarMinimapCol_u8
Zp_AvatarMinimapRow_u8: .res 1
Zp_AvatarMinimapCol_u8: .res 1

;;; The current velocity of the player avatar, in subpixels per frame.
.EXPORTZP Zp_AvatarVelX_i16, Zp_AvatarVelY_i16
Zp_AvatarVelX_i16: .res 2
Zp_AvatarVelY_i16: .res 2

;;; The object flags to apply for the player avatar.  In particular, if
;;; bObj::FlipH is set, then the avatar will face left instead of right.
Zp_AvatarFlags_bObj: .res 1

;;; What mode the avatar is currently in (e.g. standing, jumping, etc.).
.EXPORTZP Zp_AvatarMode_eAvatar
Zp_AvatarMode_eAvatar: .res 1

;;; How many more frames the player avatar should stay in eAvatar::Landing mode
;;; (after landing from a jump).
Zp_AvatarRecover_u8: .res 1

;;; Temporary variable that records whether the player avatar has just collided
;;; with something.
.EXPORTZP Zp_AvatarCollided_bool
Zp_AvatarCollided_bool: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Positions the player avatar such that it is standing still, facing to the
;;; right, in front of device number Zp_NearbyDevice_u8 in the current room.
.EXPORT Func_Avatar_PositionAtNearbyDevice
.PROC Func_Avatar_PositionAtNearbyDevice
    ;; Position the avatar in front of device number Zp_NearbyDevice_u8.
    ldx Zp_NearbyDevice_u8
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
    ora #$06
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
    lda #eAvatar::Standing
    sta Zp_AvatarMode_eAvatar
    lda #0
    sta Zp_AvatarRecover_u8
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    sta Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 1
    lda #kAvatarPalette
    sta Zp_AvatarFlags_bObj
    rts
.ENDPROC

;;; Recomputes Zp_AvatarMinimapRow_u8 and Zp_AvatarMinimapCol_u8 from the
;;; avatar's current position and room, then (if necessary) updates SRAM to
;;; mark that minimap cell as explored.
.EXPORT Func_UpdateAndMarkMinimap
.PROC Func_UpdateAndMarkMinimap
_UpdateMinimapRow:
    ldy <(Zp_Current_sRoom + sRoom::MinimapStartRow_u8)
    bit <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bpl @upperHalf
    @tall:
    lda Zp_AvatarPosY_i16 + 1
    bmi @upperHalf
    bne @lowerHalf
    lda Zp_AvatarPosY_i16 + 0
    cmp #(kTallRoomHeightBlocks / 2) * kBlockHeightPx
    blt @upperHalf
    @lowerHalf:
    iny
    @upperHalf:
    sty Zp_AvatarMinimapRow_u8
_UpdateMinimapCol:
    lda Zp_AvatarPosX_i16 + 1
    bmi @leftSide
    cmp <(Zp_Current_sRoom + sRoom::MinimapWidth_u8)
    blt @middle
    @rightSide:
    ldx <(Zp_Current_sRoom + sRoom::MinimapWidth_u8)
    dex
    txa
    @middle:
    add <(Zp_Current_sRoom + sRoom::MinimapStartCol_u8)
    bcc @setCol  ; unconditional
    @leftSide:
    lda <(Zp_Current_sRoom + sRoom::MinimapStartCol_u8)
    @setCol:
    sta Zp_AvatarMinimapCol_u8
_MarkMinimap:
    ;; Determine the bitmask to use for Sram_Minimap_u16_arr, and store it in
    ;; Zp_Tmp1_byte.
    lda Zp_AvatarMinimapRow_u8
    tay
    and #$07
    tax
    lda Data_PowersOfTwo_u8_arr8, x
    sta Zp_Tmp1_byte  ; mask
    ;; Calculate the byte offset into Sram_Minimap_u16_arr and store it in X.
    lda Zp_AvatarMinimapCol_u8
    mul #2
    tax  ; byte index into Sram_Minimap_u16_arr
    cpy #$08
    blt @loByte
    inx
    @loByte:
    ;; Check if minimap needs to be updated.
    lda Sram_Minimap_u16_arr, x
    ora Zp_Tmp1_byte  ; mask
    cmp Sram_Minimap_u16_arr, x
    beq @done
    ;; Enable writes to SRAM.
    ldy #bMmc3PrgRam::Enable
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Update minimap.
    sta Sram_Minimap_u16_arr, x
    ;; Disable writes to SRAM.
    ldy #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sty Hw_Mmc3PrgRamProtect_wo
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Updates the player avatar state based on the current joypad state.
;;; @return Z Cleared if the player avatar hit a door, set otherwise.
;;; @return A The eDoor that the player avatar hit, or eDoor::None for none.
.EXPORT FuncA_Avatar_ExploreMove
.PROC FuncA_Avatar_ExploreMove
    jsr FuncA_Avatar_ApplyJoypad
.PROC _ApplyVelX
    ldy #0
    sty Zp_AvatarCollided_bool
    lda Zp_AvatarVelX_i16 + 1
    bpl @nonnegative
    dey  ; now y is $ff
    @nonnegative:
    lda Zp_AvatarVelX_i16 + 1
    add Zp_AvatarPosX_i16 + 0
    sta Zp_AvatarPosX_i16 + 0
    tya
    adc Zp_AvatarPosX_i16 + 1
    sta Zp_AvatarPosX_i16 + 1
.ENDPROC
.PROC _DetectHorzDoor
    lda Zp_AvatarVelX_i16 + 1
    bmi _Western
_Eastern:
    ;; Calculate the room pixel X-position where the avatar will be offscreen
    ;; to the right, storing the result in Zp_Tmp1_byte (lo) and A (hi).
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 0)
    add #<(kScreenWidthPx + kAvatarBoundingBoxLeft)
    sta Zp_Tmp1_byte
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 1)
    adc #>(kScreenWidthPx + kAvatarBoundingBoxLeft)
    ;; Compare the avatar's position to the offscreen position.
    cmp Zp_AvatarPosX_i16 + 1
    beq @checkLoByte
    bge _NoHitDoor
    @hitDoor:
    lda #eDoor::Eastern
    rts
    @checkLoByte:
    lda Zp_AvatarPosX_i16 + 0
    cmp Zp_Tmp1_byte  ; door X-position (lo)
    bge @hitDoor
    blt _NoHitDoor  ; unconditional
_Western:
    ;; If the avatar's X-position is negative, then we definitely hit the
    ;; western door (although this should not happen in practice).  On the
    ;; other hand, if the hi byte of the avatar's X-position is greater than
    ;; zero, then we definitely didn't hit the western door.
    lda Zp_AvatarPosX_i16 + 1
    bmi @hitDoor
    bne _NoHitDoor
    ;; Calculate the room pixel X-position where the avatar will be fully
    ;; hidden by the one-tile-wide mask on the left side of the screen, storing
    ;; the result in A.
    lda <(Zp_Current_sRoom + sRoom::MinScrollX_u8 + 0)
    add #kTileWidthPx - kAvatarBoundingBoxRight
    ;; Compare the avatar's position to the offscreen position.  By this point,
    ;; we already know that the hi byte of the avatar's position is zero.
    cmp Zp_AvatarPosX_i16 + 0
    blt _NoHitDoor
    @hitDoor:
    lda #eDoor::Western
    rts
_NoHitDoor:
.ENDPROC
.PROC _DetectHorzCollisionWithTerrain
    ;; Calculate the room block row index that the avatar's feet are in, and
    ;; store it in Zp_Tmp1_byte.
    lda Zp_AvatarPosY_i16 + 0
    add #kAvatarBoundingBoxDown - 1
    sta Zp_Tmp1_byte
    lda Zp_AvatarPosY_i16 + 1
    adc #0
    .repeat 4
    lsr a
    ror Zp_Tmp1_byte
    .endrepeat
    ;; Calculate the room block row index that the avatar's head is in, and
    ;; store it in Zp_Tmp2_byte.
    lda Zp_AvatarPosY_i16 + 0
    sub #kAvatarBoundingBoxUp
    sta Zp_Tmp2_byte
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    .repeat 4
    lsr a
    ror Zp_Tmp2_byte
    .endrepeat
    ;; Check if the player is moving to the left or to the right.
    lda Zp_AvatarVelX_i16 + 1
    bmi _MovingLeft
_MovingRight:
    ;; Calculate the room tile column index at the avatar's right side, and
    ;; store it in Zp_Tmp3_byte.
    lda Zp_AvatarPosX_i16 + 0
    add #kAvatarBoundingBoxRight + 1
    sta Zp_Tmp3_byte
    lda Zp_AvatarPosX_i16 + 1
    adc #0
    .repeat 3
    lsr a
    ror Zp_Tmp3_byte
    .endrepeat
    ;; Check for tile collisions.
    lda Zp_Tmp3_byte  ; param: room tile column index (right side of avatar)
    jsr Func_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp1_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    bge @solid
    ldy Zp_Tmp2_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    blt _Done
    ;; We've hit the right wall, so set horizontal position to just to the left
    ;; of the wall we hit.
    @solid:
    lda #$ff
    sta Zp_AvatarCollided_bool
    lda #0
    .repeat 3
    asl Zp_Tmp3_byte
    rol a
    .endrepeat
    tax
    lda Zp_Tmp3_byte
    sub #kAvatarBoundingBoxRight
    sta Zp_AvatarPosX_i16 + 0
    txa
    sbc #0
    sta Zp_AvatarPosX_i16 + 1
    jmp _Done
_MovingLeft:
    ;; Calculate the room tile column index to the left of the avatar, and
    ;; store it in Zp_Tmp3_byte.
    lda Zp_AvatarPosX_i16 + 0
    sub #kAvatarBoundingBoxLeft + 1
    sta Zp_Tmp3_byte
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    .repeat 3
    lsr a
    ror Zp_Tmp3_byte
    .endrepeat
    ;; Check for tile collisions.
    lda Zp_Tmp3_byte  ; param: room tile column index (left side of avatar)
    jsr Func_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp1_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    bge @solid
    ldy Zp_Tmp2_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    blt @done
    ;; We've hit the left wall, so set horizontal position to just to the right
    ;; of the wall we hit.
    @solid:
    lda #$ff
    sta Zp_AvatarCollided_bool
    lda #0
    .repeat 3
    asl Zp_Tmp3_byte
    rol a
    .endrepeat
    tax
    lda Zp_Tmp3_byte
    add #kTileWidthPx + kAvatarBoundingBoxLeft
    sta Zp_AvatarPosX_i16 + 0
    txa
    adc #0
    sta Zp_AvatarPosX_i16 + 1
    @done:
_Done:
.ENDPROC
    jsr FuncA_Avatar_CollideWithAllPlatformsHorz
.PROC _HandleHorzCollision
    ;; If there was a horizontal collision, set horizontal velocity to zero.
    bit Zp_AvatarCollided_bool
    bpl @noCollision
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    @noCollision:
.ENDPROC
.PROC _ApplyVelY
    ldy #0
    sty Zp_AvatarCollided_bool
    lda Zp_AvatarVelY_i16 + 1
    bpl @nonnegative
    dey  ; now y is $ff
    @nonnegative:
    lda Zp_AvatarVelY_i16 + 1
    add Zp_AvatarPosY_i16 + 0
    sta Zp_AvatarPosY_i16 + 0
    tya
    adc Zp_AvatarPosY_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
.ENDPROC
.PROC _DetectVertDoor
    ;; TODO: Implement top/bottom doors.
.ENDPROC
.PROC _DetectVertCollisionWithTerrain
    ;; Calculate the room tile column index that the avatar's left side is in,
    ;; and store it in Zp_Tmp1_byte.
    lda Zp_AvatarPosX_i16 + 0
    sub #kAvatarBoundingBoxLeft
    sta Zp_Tmp1_byte
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    .repeat 3
    lsr a
    ror Zp_Tmp1_byte
    .endrepeat
    ;; Calculate the room tile column index at the avatar's right side is in,
    ;; and store it in Zp_Tmp2_byte.
    lda Zp_AvatarPosX_i16 + 0
    add #kAvatarBoundingBoxRight - 1
    sta Zp_Tmp2_byte
    lda Zp_AvatarPosX_i16 + 1
    adc #0
    .repeat 3
    lsr a
    ror Zp_Tmp2_byte
    .endrepeat
    ;; Check if the player is moving up or down.
    lda Zp_AvatarVelY_i16 + 1
    bpl _MovingDown
_MovingUp:
    ;; Calculate the room block row index just above the avatar's head, and
    ;; store it in Zp_Tmp3_byte.
    lda Zp_AvatarPosY_i16 + 0
    sub #kAvatarBoundingBoxUp + 1
    sta Zp_Tmp3_byte
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    .repeat 4
    lsr a
    ror Zp_Tmp3_byte
    .endrepeat
    ;; Check for tile collisions.
    lda Zp_Tmp1_byte  ; param: room tile column index (left side of avatar)
    jsr Func_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    bge @solid
    lda Zp_Tmp2_byte  ; param: room tile column index (right side of avatar)
    jsr Func_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    blt @done
    @solid:
    ;; We've hit the ceiling, so set vertical position to just below the
    ;; ceiling we hit.
    lda #0
    .repeat 4
    asl Zp_Tmp3_byte  ; room block row index (top of avatar)
    rol a
    .endrepeat
    tax
    lda Zp_Tmp3_byte
    add #kBlockHeightPx + kAvatarBoundingBoxUp
    sta Zp_AvatarPosY_i16 + 0
    txa
    adc #0
    sta Zp_AvatarPosY_i16 + 1
    lda #$ff
    sta Zp_AvatarCollided_bool
    @done:
    jmp _Done
_MovingDown:
    ;; Calculate the room block row index just below the avatar's feet, and
    ;; store it in Zp_Tmp3_byte.
    lda Zp_AvatarPosY_i16 + 0
    add #kAvatarBoundingBoxDown
    sta Zp_Tmp3_byte
    lda Zp_AvatarPosY_i16 + 1
    adc #0
    .repeat 4
    lsr a
    ror Zp_Tmp3_byte
    .endrepeat
    ;; Check for tile collisions.
    lda Zp_Tmp1_byte  ; param: room tile column index (left side of avatar)
    jsr Func_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    bge @solid
    lda Zp_Tmp2_byte  ; param: room tile column index (right side of avatar)
    jsr Func_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    bge @solid
    @empty:
    ;; There's no floor beneath us, so start falling.
    lda Zp_AvatarVelY_i16 + 1
    cmp #2
    blt @floating
    lda #eAvatar::Falling
    bne @setMode  ; unconditional
    @floating:
    lda #eAvatar::Floating
    @setMode:
    sta Zp_AvatarMode_eAvatar
    jmp _Done
    @solid:
    ;; Set vertical position to just above the floor we hit.
    lda #0
    .repeat 4
    asl Zp_Tmp3_byte
    rol a
    .endrepeat
    tax
    lda Zp_Tmp3_byte
    sub #kAvatarBoundingBoxDown
    sta Zp_AvatarPosY_i16 + 0
    txa
    sbc #0
    sta Zp_AvatarPosY_i16 + 1
    lda #$ff
    sta Zp_AvatarCollided_bool
_Done:
.ENDPROC
    jsr FuncA_Avatar_CollideWithAllPlatformsVert
.PROC _HandleVertCollision
    ;; Check if there was a vertical collision (with terrain or platforms).
    bit Zp_AvatarCollided_bool
    bpl @noCollision
    ;; If the avatar was moving down, it needs to land.
    lda Zp_AvatarVelY_i16 + 1
    bmi @doneLanding
    ;; We've hit a floor, so update the avatar mode.
    lda Zp_AvatarMode_eAvatar
    cmp #kFirstAirborneAvatarMode
    bge @wasAirborne
    lda Zp_AvatarRecover_u8
    beq @standOrRun
    dec Zp_AvatarRecover_u8
    bne @landing
    @standOrRun:
    lda Zp_AvatarVelX_i16 + 1
    beq @standing
    lda Zp_FrameCounter_u8
    and #$08
    bne @running2
    @running1:
    lda #eAvatar::Running1
    bne @setAvatarMode  ; unconditional
    @running2:
    lda #eAvatar::Running2
    bne @setAvatarMode  ; unconditional
    @standing:
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Down
    bne @ducking
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Up
    bne @looking
    lda #eAvatar::Standing
    bne @setAvatarMode  ; unconditional
    @ducking:
    lda #eAvatar::Ducking
    bne @setAvatarMode  ; unconditional
    @looking:
    lda #eAvatar::Looking
    bne @setAvatarMode  ; unconditional
    @wasAirborne:
    ldx Zp_AvatarVelY_i16 + 1
    lda DataA_Avatar_RecoverFrames_u8_arr, x
    beq @standOrRun
    sta Zp_AvatarRecover_u8
    @landing:
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Down
    bne @ducking
    lda #eAvatar::Landing
    @setAvatarMode:
    sta Zp_AvatarMode_eAvatar
    @doneLanding:
    ;; Set vertical velocity to zero.
    lda #0
    sta Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 1
    @noCollision:
.ENDPROC
    jsr Func_UpdateAndMarkMinimap
    jsr FuncA_Avatar_ApplyGravity
    lda #eDoor::None  ; indicate that no door was hit
    rts
.ENDPROC

;;; Maps from non-negative (Zp_AvatarVelY_i16 + 1) values to the value to set
;;; for Zp_AvatarRecover_u8.  The higher the downward speed, the longer the
;;; recovery time.
.PROC DataA_Avatar_RecoverFrames_u8_arr
:   .byte 0, 0, 8, 8, 12, 18
    .assert * - :- = kAvatarMaxSpeedY + 1, error
.ENDPROC

;;; Updates the player avatar's velocity and flags based on controller input
;;; (left/right and jump).
.PROC FuncA_Avatar_ApplyJoypad
_JoypadLeft:
    ;; Check D-pad left.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Left
    beq @noLeft
    ;; If left and right are both held, ignore both.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Right
    bne _NeitherLeftNorRight
    ;; Accelerate to the left.
    lda Zp_AvatarVelX_i16 + 0
    sub #kAvatarHorzAccel
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    sbc #0
    bpl @noMax
    cmp #$ff & (1 - kAvatarMaxSpeedX)
    bge @noMax
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda #$ff & -kAvatarMaxSpeedX
    @noMax:
    sta Zp_AvatarVelX_i16 + 1
    lda #kAvatarPalette | bObj::FlipH
    sta Zp_AvatarFlags_bObj
    bne _DoneLeftRight  ; unconditional
    @noLeft:
_JoypadRight:
    ;; Check D-pad right.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Right
    beq @noRight
    ;; Accelerate to the right.
    lda Zp_AvatarVelX_i16 + 0
    add #kAvatarHorzAccel
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    adc #0
    bmi @noMax
    cmp #kAvatarMaxSpeedX
    blt @noMax
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda #kAvatarMaxSpeedX
    @noMax:
    sta Zp_AvatarVelX_i16 + 1
    lda #kAvatarPalette
    sta Zp_AvatarFlags_bObj
    .assert kAvatarPalette > 0, error
    bne _DoneLeftRight  ; unconditional
    @noRight:
_NeitherLeftNorRight:
    ;; Decelerate.
    lda Zp_AvatarVelX_i16 + 1
    bmi @negative
    bne @positive
    lda Zp_AvatarVelX_i16 + 0
    cmp #kAvatarHorzAccel
    blt @stop
    @positive:
    ldy #$ff & -kAvatarHorzAccel
    ldx #$ff
    bne @decel  ; unconditional
    @negative:
    ldy #kAvatarHorzAccel
    ldx #0
    beq @decel  ; unconditional
    @stop:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    beq _DoneLeftRight  ; unconditional
    @decel:
    tya
    add Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 0
    txa
    adc Zp_AvatarVelX_i16 + 1
    sta Zp_AvatarVelX_i16 + 1
_DoneLeftRight:
    lda Zp_AvatarMode_eAvatar
    cmp #kFirstAirborneAvatarMode
    bge _Airborne
_Grounded:
    ;; If the player presses the jump button while grounded, start a jump.
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::AButton
    beq _DoneJump
    ;; TODO: play a jumping sound
    ldax #kAvatarJumpVelocity
    stax Zp_AvatarVelY_i16
    lda #eAvatar::Jumping
    sta Zp_AvatarMode_eAvatar
    bne _DoneJump  ; unconditional
_Airborne:
    ;; If the player stops holding the jump button while airborne, cap the
    ;; upward speed to kAvatarStopJumpSpeed (that is, the Y velocity will be
    ;; greater than or equal to -kAvatarStopJumpSpeed).
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::AButton
    bne _DoneJump
    lda Zp_AvatarVelY_i16 + 1
    bpl _DoneJump
    cmp #$ff & -kAvatarStopJumpSpeed
    bge _DoneJump
    lda #$ff & -kAvatarStopJumpSpeed
    sta Zp_AvatarVelY_i16 + 1
    lda #$00
    sta Zp_AvatarVelY_i16 + 0
_DoneJump:
    rts
.ENDPROC

;;; Updates the player avatar's Y-velocity to apply gravity.
.PROC FuncA_Avatar_ApplyGravity
    ;; Only apply gravity if the player avatar is airborne.
    lda Zp_AvatarMode_eAvatar
    cmp #kFirstAirborneAvatarMode
    blt @noGravity
    ;; Accelerate the player avatar downwards.
    lda #kAvatarGravity
    add Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 0
    lda #0
    adc Zp_AvatarVelY_i16 + 1
    ;; If moving downward, check for terminal velocity:
    bmi @setVelYHi
    cmp #kAvatarMaxSpeedY
    blt @setVelYHi
    lda #0
    sta Zp_AvatarVelY_i16 + 0
    lda #kAvatarMaxSpeedY
    @setVelYHi:
    sta Zp_AvatarVelY_i16 + 1
    @noGravity:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the player avatar.
.EXPORT FuncA_Objects_DrawPlayerAvatar
.PROC FuncA_Objects_DrawPlayerAvatar
    ;; Calculate screen-space Y-position.
    lda Zp_AvatarPosY_i16 + 0
    sub Zp_PpuScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Calculate screen-space X-position.
    lda Zp_AvatarPosX_i16 + 0
    sub Zp_PpuScrollX_u8
    sta Zp_ShapePosX_i16 + 0
    lda Zp_AvatarPosX_i16 + 1
    sbc Zp_ScrollXHi_u8
    sta Zp_ShapePosX_i16 + 1
    ;; Allocate objects.
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs _Done
_ObjectFlags:
    lda Zp_AvatarFlags_bObj
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    and #bObj::FlipH
    bne _ObjectTilesFacingLeft
_ObjectTilesFacingRight:
    lda Zp_AvatarMode_eAvatar
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
_Done:
    rts
_ObjectTilesFacingLeft:
    lda Zp_AvatarMode_eAvatar
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    rts
.ENDPROC

;;;=========================================================================;;;
