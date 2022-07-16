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
.IMPORT FuncA_Avatar_UpdateAndMarkMinimap
.IMPORT FuncA_Avatar_UpdateWaterDepth
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT Func_Terrain_GetColumnPtrForTileIndex
.IMPORT Ppu_ChrObjAnnaNormal
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Sram_CarryingFlower_eFlag
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_P1ButtonsHeld_bJoypad
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte

;;;=========================================================================;;;

;;; How fast the player avatar is allowed to move, in pixels per frame.
kAvatarMaxAirSpeedX = 2
kAvatarMaxAirSpeedY = 5
kAvatarMaxWaterSpeedX = 1
kAvatarMaxWaterSpeedY = 2

;;; If the player stops holding the jump button while jumping, then the
;;; avatar's upward speed is immediately capped to this many pixels per frame.
kAvatarStopJumpSpeed = 1

;;; The horizontal acceleration applied to the player avatar when holding the
;;; left/right arrows, in subpixels per frame per frame.
kAvatarHorzAccel = 70

;;; The (signed, 16-bit) initial Y-velocity of the player avatar when jumping,
;;; in subpixels per frame.
kAvatarJumpVelocity = $ffff & -810

;;; The (signed, 16-bit) initial Y-velocity to set for the player avatar when
;;; it takes damage and is temporarily stunned.
kAvatarStunVelY = $ffff & -300

;;; The OBJ palette numbers to use for the player avatar.
kAvatarPaletteNormal = 1
kAvatarPaletteDeath  = 3

;;; How many frames to blink the screen when the avatar is almost healed.
kAvatarHealBlinkFrames = 14

;;;=========================================================================;;;

.ZEROPAGE

;;; The current X/Y positions of the player avatar, in room-space pixels.
.EXPORTZP Zp_AvatarPosX_i16, Zp_AvatarPosY_i16
Zp_AvatarPosX_i16: .res 2
Zp_AvatarPosY_i16: .res 2

;;; The current X/Y subpixel positions of the player avatar.
Zp_AvatarSubX_u8: .res 1

;;; The current velocity of the player avatar, in subpixels per frame.
.EXPORTZP Zp_AvatarVelX_i16, Zp_AvatarVelY_i16
Zp_AvatarVelX_i16: .res 2
Zp_AvatarVelY_i16: .res 2

;;; The object flags to apply for the player avatar.  In particular, if
;;; bObj::FlipH is set, then the avatar will face left instead of right.
.EXPORTZP Zp_AvatarFlags_bObj
Zp_AvatarFlags_bObj: .res 1

;;; How far below the surface of the water the player avatar is, in pixels.  If
;;; the avatar is not in water, this is zero.  If the avatar is more than $ff
;;; pixels underwater, this is $ff.
.EXPORTZP Zp_AvatarWaterDepth_u8
Zp_AvatarWaterDepth_u8: .res 1

;;; What mode the avatar is currently in (e.g. standing, jumping, etc.).
.EXPORTZP Zp_AvatarMode_eAvatar
Zp_AvatarMode_eAvatar: .res 1

;;; How many more frames the player avatar should stay in eAvatar::Landing mode
;;; (after landing from a jump).
Zp_AvatarRecover_u8: .res 1

;;; Temporary variable that records what kind of wall/platform the player
;;; avatar has just collided with (if any).
.EXPORTZP Zp_AvatarCollided_ePlatform
Zp_AvatarCollided_ePlatform: .res 1

;;; If zero, the player avatar is at full health; otherwise, the avatar has
;;; been harmed, and will be back to full health in this many frames.
.EXPORTZP Zp_AvatarHarmTimer_u8
Zp_AvatarHarmTimer_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Deals damage to the player avatar, stunning them.
;;; @preserve X
.EXPORT Func_HarmAvatar
.PROC Func_HarmAvatar
    lda Zp_AvatarHarmTimer_u8
    ;; If the player avatar is at full health, stun and damage them.
    beq _Harm
    ;; Otherwise, if the player avatar is no longer still invincible from the
    ;; last time they took damage, kill them.
    cmp #kAvatarHarmHealFrames - kAvatarHarmInvincibileFrames
    blt Func_KillAvatar
    rts
_Harm:
    jsr Func_DropFlower  ; preserves X
    ;; Mark the avatar as damaged.
    lda #kAvatarHarmHealFrames
    sta Zp_AvatarHarmTimer_u8
    ;; Make the avatar go flying backwards.
    lda #eAvatar::Jumping
    sta Zp_AvatarMode_eAvatar
    lda #<kAvatarStunVelY
    sta Zp_AvatarVelY_i16 + 0
    lda #>kAvatarStunVelY
    sta Zp_AvatarVelY_i16 + 1
    ;; Set the avatar's X-velocity depending on which way its facing.
    .assert bObj::FlipH = bProc::Overflow, error
    bit Zp_AvatarFlags_bObj
    bvc @facingRight
    @facingLeft:
    lda #kAvatarMaxAirSpeedX
    bne @setVelX  ; unconditional
    @facingRight:
    lda #$ff & -kAvatarMaxAirSpeedX
    @setVelX:
    sta Zp_AvatarVelX_i16 + 1
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    rts
.ENDPROC

;;; Kills the player avatar.
;;; @preserve X
.EXPORT Func_KillAvatar
.PROC Func_KillAvatar
    lda Zp_AvatarFlags_bObj
    and #<~bObj::PaletteMask
    ora #kAvatarPaletteDeath
    sta Zp_AvatarFlags_bObj
    jsr Func_DropFlower  ; preserves X
    lda #kAvatarHarmDeath
    sta Zp_AvatarHarmTimer_u8
    rts
.ENDPROC

;;; If the player avatar is carrying a flower, drops the flower.  Otherwise,
;;; does nothing.
;;; @preserve X
.PROC Func_DropFlower
    lda Sram_CarryingFlower_eFlag
    beq @done
    chr10_bank #<.bank(Ppu_ChrObjAnnaNormal)
    ;; Enable writes to SRAM.
    lda #bMmc3PrgRam::Enable
    sta Hw_Mmc3PrgRamProtect_wo
    ;; Mark the player as no longer carrying a flower.
    lda #0
    sta Sram_CarryingFlower_eFlag
    ;; Disable writes to SRAM.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Initializes most variables for the player avatar, except for position.  The
;;; avatar's velocity will be set to zero.
;;; @prereq The room is loaded.
;;; @prereq The avatar position has been initialized.
;;; @param A True ($ff) if airborne, false ($00) otherwise.
;;; @param X The facing direction (either 0 or bObj::FlipH).
.EXPORT FuncA_Avatar_InitMotionless
.PROC FuncA_Avatar_InitMotionless
    pha  ; is airborne
    txa  ; facing direction
    ora #kAvatarPaletteNormal
    sta Zp_AvatarFlags_bObj
    lda #0
    sta Zp_AvatarHarmTimer_u8
    sta Zp_AvatarRecover_u8
    sta Zp_AvatarSubX_u8
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    sta Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 1
    jsr FuncA_Avatar_UpdateWaterDepth
    ;; Determine whether the avatar is standing, hovering, or swimming.
    pla  ; is airborne
    ldx Zp_AvatarWaterDepth_u8
    bne @swimming
    tax  ; is airborne
    bmi @hovering
    @standing:
    lda #eAvatar::Standing
    bne @setMode  ; unconditional
    @hovering:
    lda #eAvatar::Hovering
    bne @setMode  ; unconditional
    @swimming:
    lda #eAvatar::Swimming1
    @setMode:
    sta Zp_AvatarMode_eAvatar
    rts
.ENDPROC

;;; Updates the player avatar state based on the current joypad state.
;;; @return Z Cleared if the player avatar hit a passage, set otherwise.
;;; @return A The ePassage that the player avatar hit, or ePassage::None.
.EXPORT FuncA_Avatar_ExploreMove
.PROC FuncA_Avatar_ExploreMove
    ;; Apply healing.
    ldx Zp_AvatarHarmTimer_u8
    beq @doneHealing
    dex
    stx Zp_AvatarHarmTimer_u8
    ;; If the avatar isn't stunned, apply joypad controls.
    cpx #kAvatarHarmHealFrames - kAvatarHarmStunFrames
    bge @doneJoypad
    @doneHealing:
    jsr FuncA_Avatar_ApplyJoypad
    @doneJoypad:
    ;; Move horizontally first, then vertically.
    jsr FuncA_Avatar_MoveHorz  ; if passage, clears Z and returns A
    bne @return
    jsr FuncA_Avatar_MoveVert  ; if passage, clears Z and returns A
    bne @return
    ;; Update state now that the avatar is repositioned.
    jsr FuncA_Avatar_UpdateWaterDepth
    jsr FuncA_Avatar_UpdateAndMarkMinimap
    jsr FuncA_Avatar_ApplyGravity
    ;; Indicate that no passage was hit.
    lda #ePassage::None
    @return:
    rts
.ENDPROC

;;; Applies the avatar's horizontal velocity and handles horizontal collisions.
;;; @return Z Cleared if the player avatar hit a passage, set otherwise.
;;; @return A The ePassage that the player avatar hit, or ePassage::None.
.PROC FuncA_Avatar_MoveHorz
    ldy #0
    .assert ePlatform::None = 0, error
    sty Zp_AvatarCollided_ePlatform
_ApplyVelocity:
    lda Zp_AvatarVelX_i16 + 0
    add Zp_AvatarSubX_u8
    sta Zp_AvatarSubX_u8
    lda Zp_AvatarVelX_i16 + 1
    bpl @nonnegative
    dey  ; now y is $ff
    @nonnegative:
    adc Zp_AvatarPosX_i16 + 0
    sta Zp_AvatarPosX_i16 + 0
    tya
    adc Zp_AvatarPosX_i16 + 1
    sta Zp_AvatarPosX_i16 + 1
_DetectPassage:
    jsr FuncA_Avatar_DetectHorzPassage  ; if passage, clears Z and returns A
    bne _Return
_DetectCollision:
    jsr FuncA_Avatar_CollideWithTerrainHorz
    jsr FuncA_Avatar_CollideWithAllPlatformsHorz
_HandleCollision:
    ;; If there was a horizontal collision, set horizontal velocity and
    ;; subpixel position to zero.
    lda Zp_AvatarCollided_ePlatform
    .assert ePlatform::None = 0, error
    beq @doneCollision
    ldx #0
    stx Zp_AvatarVelX_i16 + 0
    stx Zp_AvatarVelX_i16 + 1
    stx Zp_AvatarSubX_u8
    ;; Check for special platform effects.
    cmp #ePlatform::Harm
    bne @doneCollision
    jsr Func_HarmAvatar
    @doneCollision:
    ;; Indicate that no passage was hit.
    lda #ePassage::None
_Return:
    rts
.ENDPROC

;;; Detects if the player avatar has hit a horizontal passage.
;;; @return Z Cleared if the player avatar hit a passage, set otherwise.
;;; @return A The ePassage that the player avatar hit, or ePassage::None.
.PROC FuncA_Avatar_DetectHorzPassage
    lda Zp_AvatarVelX_i16 + 1
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
;;; terrain.  If any collision occurs, updates the avatar's X-position and
;;; sets Zp_AvatarCollided_ePlatform to ePlatform::Solid.
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

;;; Applies the avatar's vertical velocity and handles vertical collisions.
;;; @return Z Cleared if the player avatar hit a passage, set otherwise.
;;; @return A The ePassage that the player avatar hit, or ePassage::None.
.PROC FuncA_Avatar_MoveVert
    ldy #0
    .assert ePlatform::None = 0, error
    sty Zp_AvatarCollided_ePlatform
_ApplyVelocity:
    lda Zp_AvatarVelY_i16 + 1
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
    beq @noPassage
    rts
    @noPassage:
_DetectCollision:
    jsr FuncA_Avatar_CollideWithTerrainVert
    jsr FuncA_Avatar_CollideWithAllPlatformsVert
    ;; Check if the player avatar is in water.
    lda Zp_AvatarWaterDepth_u8
    bne _DetectCollisionInWater
_DetectCollisionInAir:
    ;; Check if a vertical collision occurred.
    lda Zp_AvatarCollided_ePlatform
    .assert ePlatform::None = 0, error
    bne _HandleCollisionInAir
    ;; The avatar is not in water, and there was no vertical collision, so the
    ;; avatar is now airborne.  Set the avatar's mode based on its Y-velocity.
    lda Zp_AvatarVelY_i16 + 1
    bmi @jumping
    cmp #2
    blt @hovering
    lda #eAvatar::Falling
    .assert eAvatar::Falling > 0, error
    bne @setAvatarMode  ; unconditional
    @jumping:
    lda #eAvatar::Jumping
    .assert eAvatar::Jumping > 0, error
    bne @setAvatarMode  ; unconditional
    @hovering:
    lda #eAvatar::Hovering
    @setAvatarMode:
    sta Zp_AvatarMode_eAvatar
    .assert eAvatar::Hovering > 0, error
    bne _DoneWithCollision  ; unconditional
_DetectCollisionInWater:
    ;; The player avatar is in water, so set its mode to Swimming.
    lda Zp_FrameCounter_u8
    and #$10
    bne @swimming2
    @swimming1:
    lda #eAvatar::Swimming1
    bne @setAvatarMode  ; unconditional
    @swimming2:
    lda #eAvatar::Swimming2
    @setAvatarMode:
    sta Zp_AvatarMode_eAvatar
    ;; Check if a vertical collision occurred.
    lda Zp_AvatarCollided_ePlatform
    .assert ePlatform::None = 0, error
    bne _FinishCollision
    beq _DoneWithCollision  ; unconditional
_HandleCollisionInAir:
    ;; Check if the avatar is moving up or down.
    lda Zp_AvatarVelY_i16 + 1
    bpl _HandleDownwardCollisionInAir
_HandleUpwardCollisionInAir:
    lda #eAvatar::Hovering
    sta Zp_AvatarMode_eAvatar
    .assert eAvatar::Hovering > 0, error
    bne _FinishCollision  ; unconditional
_HandleDownwardCollisionInAir:
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
    lda Zp_AvatarHarmTimer_u8
    bne @ducking
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
_FinishCollision:
    ;; Set vertical velocity to zero.
    lda #0
    sta Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 1
    ;; Check for special platform effects.
    lda Zp_AvatarCollided_ePlatform
    cmp #ePlatform::Harm
    bne _DoneWithCollision
    jsr Func_HarmAvatar
_DoneWithCollision:
    ;; Indicate that no passage was hit.
    lda #ePlatform::None
    rts
.ENDPROC

;;; Detects if the player avatar has hit a horizontal passage.
;;; @return Z Cleared if the player avatar hit a passage, set otherwise.
;;; @return A The ePassage that the player avatar hit, or ePassage::None.
.PROC FuncA_Avatar_DetectVertPassage
    lda Zp_AvatarVelY_i16 + 1
    bmi _Top
_Bottom:
    ;; Calculate the room pixel Y-position where the avatar will be touching
    ;; the bottom edge of the room, storing the result in Zp_Tmp1_byte (lo) and
    ;; A (hi).
    lda <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bne @tall
    @short:
    ldx #kScreenHeightPx - kAvatarBoundingBoxDown
    bne @finishHeight  ; unconditional
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
;;; for Zp_AvatarRecover_u8.  The higher the downward speed, the longer the
;;; recovery time.
.PROC DataA_Avatar_RecoverFrames_u8_arr
:   .byte 0, 0, 8, 8, 12, 18
    .assert * - :- = kAvatarMaxAirSpeedY + 1, error
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
    ;; Determine velocity limit.
    lda Zp_AvatarWaterDepth_u8
    beq @inAir
    @inWater:
    lda #$ff & -kAvatarMaxWaterSpeedX
    bne @setLimit  ; unconditional
    @inAir:
    lda #$ff & -kAvatarMaxAirSpeedX
    @setLimit:
    sta Zp_Tmp1_byte  ; min X-vel
    ;; Accelerate to the left.
    lda Zp_AvatarVelX_i16 + 0
    sub #kAvatarHorzAccel
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    sbc #0
    bpl @noMax
    cmp Zp_Tmp1_byte  ; min X-vel
    bge @noMax
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_Tmp1_byte  ; min X-vel
    @noMax:
    sta Zp_AvatarVelX_i16 + 1
    lda #bObj::FlipH | kAvatarPaletteNormal
    sta Zp_AvatarFlags_bObj
    bne _DoneLeftRight  ; unconditional
    @noLeft:
_JoypadRight:
    ;; Check D-pad right.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Right
    beq @noRight
    ;; Determine velocity limit.
    lda Zp_AvatarWaterDepth_u8
    beq @inAir
    @inWater:
    lda #kAvatarMaxWaterSpeedX
    bne @setLimit  ; unconditional
    @inAir:
    lda #kAvatarMaxAirSpeedX
    @setLimit:
    sta Zp_Tmp1_byte  ; max X-vel
    ;; Accelerate to the right.
    lda Zp_AvatarVelX_i16 + 0
    add #kAvatarHorzAccel
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    adc #0
    bmi @noMax
    cmp Zp_Tmp1_byte  ; max X-vel
    blt @noMax
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_Tmp1_byte  ; max X-vel
    @noMax:
    sta Zp_AvatarVelX_i16 + 1
    lda #kAvatarPaletteNormal
    sta Zp_AvatarFlags_bObj
    .assert kAvatarPaletteNormal > 0, error
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
    lda Zp_AvatarWaterDepth_u8
    beq _NotInWater
    cmp #1
    beq _Grounded
    bne _DoneJump  ; unconditional
_NotInWater:
    lda Zp_AvatarMode_eAvatar
    cmp #kFirstAirborneAvatarMode
    bge _Airborne
_Grounded:
    ;; If the player presses the jump button while grounded, start a jump.
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::AButton = bProc::Negative, error
    bpl _DoneJump
    ;; TODO: play a jumping sound
    ldax #kAvatarJumpVelocity
    stax Zp_AvatarVelY_i16
    lda #eAvatar::Jumping
    sta Zp_AvatarMode_eAvatar
    .assert eAvatar::Jumping > 0, error
    bne _DoneJump  ; unconditional
_Airborne:
    ;; If the player stops holding the jump button while airborne, cap the
    ;; upward speed to kAvatarStopJumpSpeed (that is, the Y velocity will be
    ;; greater than or equal to -kAvatarStopJumpSpeed).
    bit Zp_P1ButtonsHeld_bJoypad
    .assert bJoypad::AButton = bProc::Negative, error
    bmi _DoneJump
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
    ldy Zp_AvatarWaterDepth_u8
    beq _InAir
_InWater:
    ;; Calculate the max upward speed: depth - 1 or kAvatarMaxWaterSpeedY,
    ;; whichever is less.
    dey
    cpy #kAvatarMaxWaterSpeedY
    blt @setMaxUpwardSpeed
    ldy #kAvatarMaxWaterSpeedY
    @setMaxUpwardSpeed:
    sty Zp_Tmp1_byte  ; max upward speed
    ;; Accelerate the player avatar upwards.
    lda Zp_AvatarVelY_i16 + 0
    sub #kAvatarBouyancy
    sta Zp_AvatarVelY_i16 + 0
    lda Zp_AvatarVelY_i16 + 1
    sbc #0
    ;; Check if the player avatar is now moving upwards or downwards.
    bpl @movingDown
    ;; If moving upward, cap velocity at 1 - depth.
    @movingUp:
    sta Zp_AvatarVelY_i16 + 1
    add Zp_Tmp1_byte  ; max upward speed
    bcs @done
    lda #0
    sta Zp_AvatarVelY_i16 + 0
    sub Zp_Tmp1_byte  ; max upward speed
    sta Zp_AvatarVelY_i16 + 1
    rts
    ;; If moving downward, check for terminal velocity:
    @movingDown:
    cmp #kAvatarMaxWaterSpeedY
    blt @setVelYHi
    lda #0
    sta Zp_AvatarVelY_i16 + 0
    lda #kAvatarMaxWaterSpeedY
    @setVelYHi:
    sta Zp_AvatarVelY_i16 + 1
    @done:
    rts
_InAir:
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
    cmp #kAvatarMaxAirSpeedY
    blt @setVelYHi
    lda #0
    sta Zp_AvatarVelY_i16 + 0
    lda #kAvatarMaxAirSpeedY
    @setVelYHi:
    sta Zp_AvatarVelY_i16 + 1
    @noGravity:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the player avatar.  Also sets
;;; Zp_Render_bPpuMask appropriately for the player avatar's health.
.EXPORT FuncA_Objects_DrawPlayerAvatar
.PROC FuncA_Objects_DrawPlayerAvatar
    ;; Tint the screen red if the avatar is not at full health.
    lda Zp_AvatarHarmTimer_u8
    beq @whiteScreen
    cmp #kAvatarHealBlinkFrames
    bge @redScreen
    and #$02
    bne @whiteScreen
    @redScreen:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain | bPpuMask::EmphRed
    bne @setRender  ; unconditional
    @whiteScreen:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    @setRender:
    sta Zp_Render_bPpuMask
    ;; If the avatar is temporarily invinvible, blink the objects.
    lda Zp_AvatarHarmTimer_u8
    cmp #kAvatarHarmDeath
    beq @notInvincible
    cmp #kAvatarHarmHealFrames - kAvatarHarmInvincibileFrames
    blt @notInvincible
    lda Zp_FrameCounter_u8
    and #$02
    bne _Done
    @notInvincible:
_GetPosition:
    ;; Calculate screen-space Y-position.
    lda Zp_AvatarPosY_i16 + 0
    sub Zp_RoomScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Calculate screen-space X-position.
    lda Zp_AvatarPosX_i16 + 0
    sub Zp_RoomScrollX_u16 + 0
    sta Zp_ShapePosX_i16 + 0
    lda Zp_AvatarPosX_i16 + 1
    sbc Zp_RoomScrollX_u16 + 1
    sta Zp_ShapePosX_i16 + 1
_DrawObjects:
    lda Zp_AvatarFlags_bObj  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs _Done
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
.ENDPROC

;;;=========================================================================;;;
