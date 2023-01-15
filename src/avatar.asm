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

.IMPORT FuncA_Avatar_UpdateWaterDepth
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT Func_TryPushAvatarHorz
.IMPORT Func_TryPushAvatarVert
.IMPORTZP Zp_AvatarExit_ePassage
.IMPORTZP Zp_AvatarPushDelta_i8
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_P1ButtonsHeld_bJoypad
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; If the player stops holding the jump button while jumping, then the
;;; avatar's upward speed is immediately capped to this many pixels per frame.
kAvatarStopJumpSpeed = 1

;;; The horizontal acceleration applied to the player avatar when holding the
;;; left/right arrows, in subpixels per frame per frame.
kAvatarHorzAccel = 70

;;; The horizontal deceleration applied to the player avatar when holding
;;; neither the left nor right arrow, in subpixels per frame per frame.
kAvatarHorzDecelFast = 70

;;; The horizontal deceleration applied to the player avatar when holding the
;;; left/right arrows while moving too fast, in subpixels per frame per frame.
kAvatarHorzDecelSlow = 25

;;; The (signed, 16-bit) initial Y-velocity of the player avatar when jumping,
;;; in subpixels per frame.
kAvatarJumpVelocity = $ffff & -850

;;; How many frames to blink the screen when the avatar is almost healed.
kAvatarHealBlinkFrames = 14

;;;=========================================================================;;;

.ZEROPAGE

;;; The current X/Y positions of the player avatar, in room-space pixels.
.EXPORTZP Zp_AvatarPosX_i16, Zp_AvatarPosY_i16
Zp_AvatarPosX_i16: .res 2
Zp_AvatarPosY_i16: .res 2

;;; The current X/Y subpixel positions of the player avatar.
.EXPORTZP Zp_AvatarSubX_u8, Zp_AvatarSubY_u8
Zp_AvatarSubX_u8: .res 1
Zp_AvatarSubY_u8: .res 1

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

;;; If false ($00), then the player avatar is on solid ground; if true ($ff),
;;; then the avatar is in midair.  This value is only meaningful if the avatar
;;; is not in water (i.e. if Zp_AvatarWaterDepth_u8 is zero).
.EXPORTZP Zp_AvatarAirborne_bool
Zp_AvatarAirborne_bool: .res 1

;;; What mode the avatar is currently in (e.g. standing, jumping, etc.).
.EXPORTZP Zp_AvatarMode_eAvatar
Zp_AvatarMode_eAvatar: .res 1

;;; How many more frames the player avatar should stay in eAvatar::Landing mode
;;; (after landing from a jump).
.EXPORTZP Zp_AvatarLanding_u8
Zp_AvatarLanding_u8: .res 1

;;; If zero, the player avatar is at full health; otherwise, the avatar has
;;; been harmed, and will be back to full health in this many frames.
.EXPORTZP Zp_AvatarHarmTimer_u8
Zp_AvatarHarmTimer_u8: .res 1

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
    sta Zp_AvatarAirborne_bool
    txa  ; facing direction
    ora #kPaletteObjAvatarNormal
    sta Zp_AvatarFlags_bObj
    lda #0
    sta Zp_AvatarHarmTimer_u8
    sta Zp_AvatarLanding_u8
    sta Zp_AvatarSubX_u8
    sta Zp_AvatarSubY_u8
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    sta Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 1
    jsr FuncA_Avatar_UpdateWaterDepth
    ;; Determine whether the avatar is standing, hovering, or swimming.
    lda Zp_AvatarWaterDepth_u8
    bne @swimming
    bit Zp_AvatarAirborne_bool
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

;;; Updates the player avatar state based on the current joypad state.  Sets
;;; Zp_AvatarExit_ePassage if the avatar hits a passage.
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
    jsr FuncA_Avatar_ApplyDpad
    jsr FuncA_Avatar_ApplyJump
    @doneJoypad:
_RecoverFromLanding:
    lda Zp_AvatarLanding_u8
    beq @done
    dec Zp_AvatarLanding_u8
    @done:
_ApplyVelocity:
    ;; Move horizontally first, then vertically.
    jsr FuncA_Avatar_ApplyVelX
    lda Zp_AvatarExit_ePassage
    .assert ePassage::None = 0, error
    bne @done
    jsr FuncA_Avatar_ApplyVelY
    @done:
_ApplyGravity:
    ;; Update state now that the avatar is repositioned.
    jsr FuncA_Avatar_UpdateWaterDepth
    jsr FuncA_Avatar_ApplyGravity
_SetAvatarMode:
    ;; Check if the player avatar is in water.
    lda Zp_AvatarWaterDepth_u8
    bne _SetModeInWater
    bit Zp_AvatarAirborne_bool
    bpl _SetModeOnGround
_SetModeInAir:
    ;; The player avatar is airborne; set its mode based on its Y-velocity.
    lda Zp_AvatarVelY_i16 + 1
    bmi @jumping
    cmp #2
    blt @hovering
    lda #eAvatar::Falling
    bne @setAvatarMode  ; unconditional
    @jumping:
    lda #eAvatar::Jumping
    bne @setAvatarMode  ; unconditional
    @hovering:
    lda #eAvatar::Hovering
    @setAvatarMode:
    sta Zp_AvatarMode_eAvatar
    rts
_SetModeInWater:
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
    rts
_SetModeOnGround:
    lda Zp_AvatarLanding_u8
    beq @standOrRun
    @landing:
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Down
    bne @kneeling
    lda #eAvatar::Landing
    bne @setAvatarMode  ; unconditional
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
    bne @kneeling
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Down
    bne @kneeling
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Up
    bne @looking
    lda #eAvatar::Standing
    bne @setAvatarMode  ; unconditional
    @kneeling:
    lda #eAvatar::Kneeling
    bne @setAvatarMode  ; unconditional
    @looking:
    lda #eAvatar::Looking
    @setAvatarMode:
    sta Zp_AvatarMode_eAvatar
    rts
.ENDPROC

;;; Applies the player avatar's horizontal velocity and handles horizontal
;;; collisions.  Sets Zp_AvatarExit_ePassage if the avatar hits a horizontal
;;; passage.
.PROC FuncA_Avatar_ApplyVelX
    lda Zp_AvatarVelX_i16 + 0
    add Zp_AvatarSubX_u8
    sta Zp_AvatarSubX_u8
    lda Zp_AvatarVelX_i16 + 1
    adc #0
    sta Zp_AvatarPushDelta_i8
    jmp Func_TryPushAvatarHorz
.ENDPROC

;;; Applies the player avatar's vertical velocity and handles vertical
;;; collisions.  Sets Zp_AvatarExit_ePassage if the avatar hits a vertical
;;; passage.
.PROC FuncA_Avatar_ApplyVelY
    lda Zp_AvatarVelY_i16 + 0
    add Zp_AvatarSubY_u8
    sta Zp_AvatarSubY_u8
    lda Zp_AvatarVelY_i16 + 1
    adc #0
    sta Zp_AvatarPushDelta_i8
    jmp Func_TryPushAvatarVert
.ENDPROC

;;; Updates the player avatar's X-velocity and flags based on the D-pad
;;; left/right buttons.
.PROC FuncA_Avatar_ApplyDpad
    ;; Check D-pad left.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Left
    beq @noLeft
    ;; If left and right are both held, ignore both.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Right
    bne _NeitherLeftNorRight
    jmp FuncA_Avatar_ApplyDpadLeft
    @noLeft:
    ;; Check D-pad right.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Right
    beq @noRight
    jmp FuncA_Avatar_ApplyDpadRight
    @noRight:
_NeitherLeftNorRight:
    .assert * = FuncA_Avatar_DecelerateHorz, error, "fallthrough"
.ENDPROC

;;; Decelerates the player avatar's X-velocity toward zero.
.PROC FuncA_Avatar_DecelerateHorz
    lda Zp_AvatarVelX_i16 + 1
    bmi _MovingLeft
_MovingRight:
    bne @decel
    lda Zp_AvatarVelX_i16 + 0
    cmp #kAvatarHorzDecelFast
    blt _Stop
    @decel:
    lda Zp_AvatarVelX_i16 + 0
    sub #kAvatarHorzDecelFast
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    sbc #0
    sta Zp_AvatarVelX_i16 + 1
    rts
_MovingLeft:
    cmp #$ff
    bne @decel
    lda Zp_AvatarVelX_i16 + 0
    cmp #<-kAvatarHorzDecelFast
    bge _Stop
    @decel:
    lda Zp_AvatarVelX_i16 + 0
    add #kAvatarHorzDecelFast
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    adc #0
    sta Zp_AvatarVelX_i16 + 1
    rts
_Stop:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    rts
.ENDPROC

;;; Updates the player avatar's X-velocity and flags given that the D-pad left
;;; button is held.
.PROC FuncA_Avatar_ApplyDpadLeft
    ;; Face the player avatar to the left.
    lda #bObj::FlipH | kPaletteObjAvatarNormal
    sta Zp_AvatarFlags_bObj
_DetermineLimit:
    ;; Determine the (negative) X-velocity limit in pixels/frame, storing it in
    ;; Zp_Tmp1_byte.
    lda Zp_AvatarWaterDepth_u8
    beq @inAir
    @inWater:
    .assert <kAvatarMaxWaterSpeedHorz = 0, error
    lda #>-kAvatarMaxWaterSpeedHorz
    bne @setLimit  ; unconditional
    @inAir:
    .assert <kAvatarMaxAirSpeedHorz = 0, error
    lda #>-kAvatarMaxAirSpeedHorz
    @setLimit:
    sta Zp_Tmp1_byte  ; negative X-vel limit (pixels/frame)
_AccelOrDecel:
    ;; If the avatar is moving to the right, or moving to the left slower than
    ;; the limit, then accelerate.  Otherwise, decelerate.
    lda Zp_AvatarVelX_i16 + 1
    bpl _AccelerateTowardsLimit
    cmp Zp_Tmp1_byte  ; negative X-vel limit (pixels/frame)
    bge _AccelerateTowardsLimit
_DecelerateTowardsLimit:
    ;; Slowly decelerate, up to the (negative) velocity limit at maximum.
    lda Zp_AvatarVelX_i16 + 0
    add #kAvatarHorzDecelSlow
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    adc #0
    cmp Zp_Tmp1_byte  ; negitive X-vel limit (pixels/frame)
    blt @noClamp
    @clamp:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_Tmp1_byte  ; negitive X-vel limit (pixels/frame)
    @noClamp:
    sta Zp_AvatarVelX_i16 + 1
    rts
_AccelerateTowardsLimit:
    ;; Accelerate to the left, down to the (negative) velocity limit at
    ;; minimum.
    lda Zp_AvatarVelX_i16 + 0
    sub #kAvatarHorzAccel
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    sbc #0
    bpl @noClamp
    cmp Zp_Tmp1_byte  ; negative X-vel limit (pixels/frame)
    bge @noClamp
    @clamp:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_Tmp1_byte  ; negative X-vel limit (pixels/frame)
    @noClamp:
    sta Zp_AvatarVelX_i16 + 1
    rts
.ENDPROC

;;; Updates the player avatar's X-velocity and flags given that the D-pad right
;;; button is held.
.PROC FuncA_Avatar_ApplyDpadRight
    ;; Face the player avatar to the right.
    lda #kPaletteObjAvatarNormal
    sta Zp_AvatarFlags_bObj
_DetermineLimit:
    ;; Determine the (positive) X-velocity limit in pixels/frame, storing it in
    ;; Zp_Tmp1_byte.
    lda Zp_AvatarWaterDepth_u8
    beq @inAir
    @inWater:
    .assert <kAvatarMaxWaterSpeedHorz = 0, error
    lda #>kAvatarMaxWaterSpeedHorz
    bne @setLimit  ; unconditional
    @inAir:
    .assert <kAvatarMaxAirSpeedHorz = 0, error
    lda #>kAvatarMaxAirSpeedHorz
    @setLimit:
    sta Zp_Tmp1_byte  ; positive X-vel limit (pixels/frame)
_AccelOrDecel:
    ;; If the avatar is moving to the left, or moving to the right slower than
    ;; the limit, then accelerate.  Otherwise, decelerate.
    lda Zp_AvatarVelX_i16 + 1
    bmi _AccelerateTowardsLimit
    cmp Zp_Tmp1_byte  ; positive X-vel limit (pixels/frame)
    blt _AccelerateTowardsLimit
_DecelerateTowardsLimit:
    ;; Slowly decelerate, down to the (positive) velocity limit at minimum.
    lda Zp_AvatarVelX_i16 + 0
    sub #kAvatarHorzDecelSlow
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    sbc #0
    cmp Zp_Tmp1_byte  ; positive X-vel limit (pixels/frame)
    bge @noClamp
    @clamp:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_Tmp1_byte  ; positive X-vel limit (pixels/frame)
    @noClamp:
    sta Zp_AvatarVelX_i16 + 1
    rts
_AccelerateTowardsLimit:
    ;; Accelerate to the right, up to the (positive) velocity limit at maximum.
    lda Zp_AvatarVelX_i16 + 0
    add #kAvatarHorzAccel
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    adc #0
    bmi @noClamp
    cmp Zp_Tmp1_byte  ; positive X-vel limit (pixels/frame)
    blt @noClamp
    @clamp:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_Tmp1_byte  ; positive X-vel limit (pixels/frame)
    @noClamp:
    sta Zp_AvatarVelX_i16 + 1
    rts
.ENDPROC

;;; Updates the player avatar's Y-velocity based on the jump button.
.PROC FuncA_Avatar_ApplyJump
    ;; Check whether the avatar can jump right now.
    lda Zp_AvatarWaterDepth_u8
    beq _NotInWater
    cmp #1
    beq _Grounded  ; floating on surface of water; allow jumping as if grounded
    rts  ; avatar is underwater and cannot jump
_NotInWater:
    bit Zp_AvatarAirborne_bool
    bmi _Airborne
_Grounded:
    ;; If the player presses the jump button while grounded, start a jump.
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::AButton = bProc::Negative, error
    bpl @noJump
    ;; TODO: play a jumping sound
    ldax #kAvatarJumpVelocity
    stax Zp_AvatarVelY_i16
    lda #$ff
    sta Zp_AvatarAirborne_bool
    @noJump:
    rts
_Airborne:
    ;; If the player stops holding the jump button while airborne, cap the
    ;; upward speed to kAvatarStopJumpSpeed (that is, the Y velocity will be
    ;; greater than or equal to -kAvatarStopJumpSpeed).
    ;; TODO: This interacts poorly with being pushed up by e.g. steam.
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
    ;; Calculate the max upward speed in pixels/frame: either (depth - 1) or
    ;; >kAvatarMaxWaterSpeedUp, whichever is less.
    dey
    .assert <kAvatarMaxWaterSpeedUp = 0, error
    cpy #>kAvatarMaxWaterSpeedUp
    blt @setMaxUpwardSpeed
    ldy #>kAvatarMaxWaterSpeedUp
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
    ;; If moving upward, cap upward velocity.
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
    sta Zp_AvatarVelY_i16 + 1
    sta $ff
    cmp #>kAvatarMaxWaterSpeedDown
    blt @done
    bne @clampDown
    lda Zp_AvatarVelY_i16 + 0
    cmp #<kAvatarMaxWaterSpeedDown
    blt @done
    @clampDown:
    lda #<kAvatarMaxWaterSpeedDown
    sta Zp_AvatarVelY_i16 + 0
    lda #>kAvatarMaxWaterSpeedDown
    sta Zp_AvatarVelY_i16 + 1
    @done:
    rts
_InAir:
    ;; Only apply gravity if the player avatar is airborne.
    bit Zp_AvatarAirborne_bool
    bpl @noGravity
    ;; Accelerate the player avatar downwards.
    lda #kAvatarGravity
    add Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 0
    lda #0
    adc Zp_AvatarVelY_i16 + 1
    ;; If moving downward, check for terminal velocity:
    bmi @setVelYHi
    .assert <kAvatarMaxAirSpeedVert = 0, error
    cmp #>kAvatarMaxAirSpeedVert
    blt @setVelYHi
    lda #0
    sta Zp_AvatarVelY_i16 + 0
    lda #>kAvatarMaxAirSpeedVert
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
_DrawObjects:
    jsr FuncA_Objects_SetShapePosToAvatarCenter
    lda Zp_AvatarMode_eAvatar  ; param: first tile ID
    ldy Zp_AvatarFlags_bObj  ; param: object flags
    jmp FuncA_Objects_Draw2x2Shape
_Done:
    rts
.ENDPROC

;;; Sets Zp_ShapePosX_i16 and Zp_ShapePosY_i16 to the screen-space position of
;;; the player avatar.
;;; @preserve X, Y, Zp_Tmp*
.EXPORT FuncA_Objects_SetShapePosToAvatarCenter
.PROC FuncA_Objects_SetShapePosToAvatarCenter
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
    rts
.ENDPROC

;;;=========================================================================;;;
