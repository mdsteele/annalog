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
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "platform.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "terrain.inc"

.IMPORT FuncA_Avatar_CollideWithAllPlatformsHorz
.IMPORT FuncA_Avatar_CollideWithAllPlatformsVert
.IMPORT Func_GetTerrainColumnPtrForTileIndex
.IMPORT Func_HarmAvatar
.IMPORTZP Zp_AvatarAirborne_bool
.IMPORTZP Zp_AvatarCollided_ePlatform
.IMPORTZP Zp_AvatarExit_ePassage
.IMPORTZP Zp_AvatarLanding_u8
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarSubX_u8
.IMPORTZP Zp_AvatarSubY_u8
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_AvatarVelY_i16
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte

;;;=========================================================================;;;

.ZEROPAGE

;;; Parameter to functions that push the player avatar, to indicate how far and
;;; in what direction to push.
.EXPORTZP Zp_AvatarPushDelta_i8
Zp_AvatarPushDelta_i8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Attempts to move the player avatar horizontally by Zp_AvatarPushDelta_i8.
;;; Sets Zp_AvatarExit_ePassage if this causes the avatar to hit a horizontal
;;; passage.
.EXPORT FuncA_Avatar_TryPushHorz
.PROC FuncA_Avatar_TryPushHorz
    ldy #0
    .assert ePlatform::None = 0, error
    sty Zp_AvatarCollided_ePlatform
_Push:
    lda Zp_AvatarPushDelta_i8
    beq _Done
    bpl @nonnegative
    dey  ; now y is $ff
    @nonnegative:
    add Zp_AvatarPosX_i16 + 0
    sta Zp_AvatarPosX_i16 + 0
    tya
    adc Zp_AvatarPosX_i16 + 1
    sta Zp_AvatarPosX_i16 + 1
_DetectPassage:
    jsr FuncA_Avatar_DetectHorzPassage  ; if passage, clears Z and returns A
    sta Zp_AvatarExit_ePassage
    bne _Done
_DetectCollision:
    jsr FuncA_Avatar_CollideWithTerrainHorz
    jsr FuncA_Avatar_CollideWithAllPlatformsHorz
    lda Zp_AvatarCollided_ePlatform
    .assert ePlatform::None = 0, error
    beq _Done  ; no collision
_HandleCollision:
    ;; Set horizontal velocity and subpixel position to zero.
    ldx #0
    stx Zp_AvatarSubX_u8
    stx Zp_AvatarVelX_i16 + 0
    stx Zp_AvatarVelX_i16 + 1
    ;; Check for special platform effects.
    cmp #ePlatform::Harm
    bne @noHarm
    jsr Func_HarmAvatar
    @noHarm:
_Done:
    rts
.ENDPROC

;;; Detects if the player avatar has hit a horizontal passage.
;;; @return Z Cleared if the player avatar hit a passage, set otherwise.
;;; @return A The ePassage that the player avatar hit, or ePassage::None.
.PROC FuncA_Avatar_DetectHorzPassage
    ;; Check if the player avatar is moving to the left or to the right.
    bit Zp_AvatarPushDelta_i8
    bmi _Western
_Eastern:
    ;; Calculate the room pixel X-position where the avatar will be offscreen
    ;; to the right, storing the result in Zp_Tmp1_byte (lo) and A (hi).
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 0)
    add #<(kScreenWidthPx + kAvatarBoundingBoxLeft)
    sta Zp_Tmp1_byte  ; passage X-position (lo)
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 1)
    adc #>(kScreenWidthPx + kAvatarBoundingBoxLeft)
    ;; Compare the avatar's position to the offscreen position.
    cmp Zp_AvatarPosX_i16 + 1
    beq @checkLoByte
    bge _NoHitPassage
    @hitPassage:
    lda #ePassage::Eastern
    rts
    @checkLoByte:
    lda Zp_AvatarPosX_i16 + 0
    cmp Zp_Tmp1_byte  ; passage X-position (lo)
    bge @hitPassage
    blt _NoHitPassage  ; unconditional
_Western:
    ;; If the avatar's X-position is negative, then we definitely hit the
    ;; western passage (although this should not happen in practice).  On the
    ;; other hand, if the hi byte of the avatar's X-position is greater than
    ;; zero, then we definitely didn't hit the western passage.
    lda Zp_AvatarPosX_i16 + 1
    bmi @hitPassage
    bne _NoHitPassage
    ;; Calculate the room pixel X-position where the avatar will be fully
    ;; hidden by the one-tile-wide mask on the left side of the screen, storing
    ;; the result in A.
    lda <(Zp_Current_sRoom + sRoom::MinScrollX_u8 + 0)
    add #kTileWidthPx - kAvatarBoundingBoxRight
    ;; Compare the avatar's position to the offscreen position.  By this point,
    ;; we already know that the hi byte of the avatar's position is zero.
    cmp Zp_AvatarPosX_i16 + 0
    blt _NoHitPassage
    @hitPassage:
    lda #ePassage::Western
    rts
_NoHitPassage:
    lda #ePassage::None
    rts
.ENDPROC

;;; Checks for horizontal collisions between the player avatar and the room
;;; terrain.  If any collision occurs, updates the avatar's X-position and sets
;;; Zp_AvatarCollided_ePlatform to ePlatform::Solid.
;;; @prereq Zp_AvatarPushDelta_i8 holds a nonzero horz delta for the avatar.
.PROC FuncA_Avatar_CollideWithTerrainHorz
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
    bit Zp_AvatarPushDelta_i8
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
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp1_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    bge @solid
    ldy Zp_Tmp2_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    blt @done
    ;; We've hit the right wall, so set horizontal position to just to the left
    ;; of the wall we hit.
    @solid:
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
    ;; Indicate that we hit solid terrain.
    lda #ePlatform::Solid
    sta Zp_AvatarCollided_ePlatform
    @done:
    rts
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
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
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
    ;; Indicate that we hit solid terrain.
    lda #ePlatform::Solid
    sta Zp_AvatarCollided_ePlatform
    @done:
    rts
.ENDPROC

;;; Attempts to move the player avatar vertically by Zp_AvatarPushDelta_i8.
;;; Sets Zp_AvatarExit_ePassage if this causes the avatar to hit a vertical
;;; passage.
.EXPORT FuncA_Avatar_TryPushVert
.PROC FuncA_Avatar_TryPushVert
    ldy #0
    .assert ePlatform::None = 0, error
    sty Zp_AvatarCollided_ePlatform
_ApplyVelocity:
    lda Zp_AvatarPushDelta_i8
    bpl @nonnegative
    dey  ; now y is $ff
    @nonnegative:
    add Zp_AvatarPosY_i16 + 0
    sta Zp_AvatarPosY_i16 + 0
    tya
    adc Zp_AvatarPosY_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
_DetectPassage:
    jsr FuncA_Avatar_DetectVertPassage  ; if passage, clears Z and returns A
    sta Zp_AvatarExit_ePassage
    bne _NowAirborne
_DetectCollision:
    jsr FuncA_Avatar_CollideWithTerrainVert
    jsr FuncA_Avatar_CollideWithAllPlatformsVert
    ;; If no vertical collision occurred, then the avatar is now airborne
    ;; (unless it's in water, but that will be detected later).
    lda Zp_AvatarCollided_ePlatform
    .assert ePlatform::None = 0, error
    beq _NowAirborne
_HandleCollision:
    ldx Zp_AvatarVelY_i16 + 1
    stx Zp_Tmp1_byte  ; old Y-velocity (hi)
    ;; Set vertical velocity and subpixel position to zero.
    ldx #0
    stx Zp_AvatarSubY_u8
    stx Zp_AvatarVelY_i16 + 0
    stx Zp_AvatarVelY_i16 + 1
    ;; Check for special platform effects.
    cmp #ePlatform::Harm
    bne @noHarm
    jsr Func_HarmAvatar
    @noHarm:
    ;; If this was a downward collision, the avatar is now grounded.  If it was
    ;; an upward collision, the avatar must be airborne.
    bit Zp_AvatarPushDelta_i8
    bpl _NowGrounded
_NowAirborne:
    lda #$ff
    sta Zp_AvatarAirborne_bool
    rts
_NowGrounded:
    bit Zp_AvatarAirborne_bool
    bpl @done
    @wasAirborne:
    ldx Zp_Tmp1_byte  ; old Y-velocity (hi)
    bmi @nowGrounded
    lda DataA_Avatar_LandingFrames_u8_arr, x
    sta Zp_AvatarLanding_u8
    @nowGrounded:
    lda #0
    sta Zp_AvatarAirborne_bool
    @done:
    rts
.ENDPROC

;;; Detects if the player avatar has hit a horizontal passage.
;;; @return Z Cleared if the player avatar hit a passage, set otherwise.
;;; @return A The ePassage that the player avatar hit, or ePassage::None.
.PROC FuncA_Avatar_DetectVertPassage
    ;; Check if the player avatar is moving up or down.
    bit Zp_AvatarPushDelta_i8
    bmi _Top
_Bottom:
    ;; Calculate the room pixel Y-position where the avatar will be touching
    ;; the bottom edge of the room, storing the result in Zp_Tmp1_byte (lo) and
    ;; A (hi).
    bit <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    .assert bRoom::Tall = bProc::Negative, error
    bmi @tall
    @short:
    ldx #kScreenHeightPx - kAvatarBoundingBoxDown
    lda #0
    beq @finishHeight  ; unconditional
    @tall:
    ldax #kTallRoomHeightBlocks * kBlockHeightPx - kAvatarBoundingBoxDown
    @finishHeight:
    stx Zp_Tmp1_byte  ; passage Y-position (lo)
    ;; Compare the avatar's position to the passage position.
    cmp Zp_AvatarPosY_i16 + 1
    beq @checkLoByte
    bge _NoHitPassage
    @hitPassage:
    lda #ePassage::Bottom
    rts
    @checkLoByte:
    lda Zp_AvatarPosY_i16 + 0
    cmp Zp_Tmp1_byte  ; passage Y-position (lo)
    bge @hitPassage
    blt _NoHitPassage  ; unconditional
_Top:
    ;; If the avatar's Y-position is negative, then we definitely hit the top
    ;; passage (although this should not happen in practice).  On the other
    ;; hand, if the hi byte of the avatar's Y-position is greater than zero,
    ;; then we definitely didn't hit the western passage.
    lda Zp_AvatarPosY_i16 + 1
    bmi @hitPassage
    bne _NoHitPassage
    ;; Check if the top of the avatar is touching the top of the room.  By this
    ;; point, we already know that the hi byte of the avatar's position is
    ;; zero.
    lda #kAvatarBoundingBoxUp
    cmp Zp_AvatarPosY_i16 + 0
    blt _NoHitPassage
    @hitPassage:
    lda #ePassage::Top
    rts
_NoHitPassage:
    lda #ePassage::None
    rts
.ENDPROC

;;; Checks for vertical collisions between the player avatar and the room
;;; terrain.  If any collision occurs, updates the avatar's Y-position and
;;; sets Zp_AvatarCollided_ePlatform to ePlatform::Solid.
.PROC FuncA_Avatar_CollideWithTerrainVert
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
    lda Zp_AvatarPushDelta_i8
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
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    bge @solid
    lda Zp_Tmp2_byte  ; param: room tile column index (right side of avatar)
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
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
    ;; Indicate that we hit solid terrain.
    lda #ePlatform::Solid
    sta Zp_AvatarCollided_ePlatform
    @done:
    rts
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
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    bge @solid
    lda Zp_Tmp2_byte  ; param: room tile column index (right side of avatar)
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    blt @done
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
    ;; Indicate that we hit solid terrain.
    lda #ePlatform::Solid
    sta Zp_AvatarCollided_ePlatform
    @done:
    rts
.ENDPROC

;;; Maps from non-negative (Zp_AvatarVelY_i16 + 1) values to the value to set
;;; for Zp_AvatarLanding_u8.  The higher the downward speed, the longer the
;;; recovery time.
.PROC DataA_Avatar_LandingFrames_u8_arr
:   .byte 0, 0, 8, 8, 12, 18
    .assert * - :- = 1 + >kAvatarMaxAirSpeedVert, error
.ENDPROC

;;;=========================================================================;;;
