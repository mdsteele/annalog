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
.INCLUDE "oam.inc"
.INCLUDE "platform.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "sample.inc"

.IMPORT FuncA_Avatar_UpdateWaterDepth
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT Func_MovePointUpByA
.IMPORT Func_PlaySfxSample
.IMPORT Func_SignedAtan2
.IMPORT Func_TryPushAvatarHorz
.IMPORT Func_TryPushAvatarVert
.IMPORTZP Zp_AvatarCollided_ePlatform
.IMPORTZP Zp_AvatarExit_ePassage
.IMPORTZP Zp_AvatarPushDelta_i8
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_P1ButtonsHeld_bJoypad
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

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
kAvatarHorzDecelSlow = 8

;;; The (signed, 16-bit) initial Y-velocity of the player avatar when jumping,
;;; in subpixels per frame.
kAvatarJumpVelocity = $ffff & -850

;;; How many frames to blink the screen when the avatar is almost healed.
kAvatarHealBlinkFrames = 14

;;;=========================================================================;;;

.ZEROPAGE

;;; The current X/Y positions of the player avatar, in room-space pixels.
.EXPORTZP Zp_AvatarPosX_i16
Zp_AvatarPosX_i16: .res 2
.EXPORTZP Zp_AvatarPosY_i16
Zp_AvatarPosY_i16: .res 2

;;; The current X/Y subpixel positions of the player avatar.
.EXPORTZP Zp_AvatarSubX_u8
Zp_AvatarSubX_u8: .res 1
.EXPORTZP Zp_AvatarSubY_u8
Zp_AvatarSubY_u8: .res 1

;;; The current velocity of the player avatar, in subpixels per frame.
.EXPORTZP Zp_AvatarVelX_i16
Zp_AvatarVelX_i16: .res 2
.EXPORTZP Zp_AvatarVelY_i16
Zp_AvatarVelY_i16: .res 2

;;; The object flags to apply for the player avatar.  In particular, if
;;; bObj::FlipH is set, then the avatar will face left instead of right.
.EXPORTZP Zp_AvatarFlags_bObj
Zp_AvatarFlags_bObj: .res 1

;;; State bits indicating whether the player avatar is grounded, swimming or
;;; airborne:
;;;   * If the avatar is grounded, then the Airborne/Swimming/Jumping bits are
;;;     cleared, and the LandMask bits indicate how many more frames until the
;;;     avatar is done landing from a jump (normally zero).
;;;   * If the avatar is swimming, then the Swimming bit is set, the
;;;     Airborne/Jumping bits are cleared, and the DepthMask bits indicate how
;;;     many pixels underwater the avatar is (0 if at the surface; clamped if
;;;     the depth is too great to fit in DepthMask).
;;;   * If the avatar is airborne, then the Airborne bit is set, and the
;;;     Swimming/DepthMask/LandMask bits are cleared.  If the avatar is in
;;;     midair because it just jumped, then the Jumping bit will be set,
;;;     indicating that releasing the A button early should slow the avatar's
;;;     Y-velocity.
.EXPORTZP Zp_AvatarState_bAvatar
Zp_AvatarState_bAvatar: .res 1

;;; What pose the avatar is currently in (e.g. standing, jumping, etc.).
.EXPORTZP Zp_AvatarPose_eAvatar
Zp_AvatarPose_eAvatar: .res 1

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
;;; @param A The facing direction (either 0 or bObj::FlipH).
;;; @param X The initial bAvatar value to set.
.EXPORT FuncA_Avatar_InitMotionless
.PROC FuncA_Avatar_InitMotionless
    stx Zp_AvatarState_bAvatar
    ora #kPaletteObjAvatarNormal
    sta Zp_AvatarFlags_bObj
    lda #0
    sta Zp_AvatarHarmTimer_u8
    sta Zp_AvatarSubX_u8
    sta Zp_AvatarSubY_u8
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    sta Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 1
    jsr FuncA_Avatar_UpdateWaterDepth
_SetAvatarPose:
    ;; Determine whether the avatar is standing, hovering, or swimming.
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvs @swimming
    .assert bAvatar::Airborne = bProc::Negative, error
    bmi @hovering
    @standing:
    lda #eAvatar::Standing
    bne @setPose  ; unconditional
    @hovering:
    lda #eAvatar::Hovering
    bne @setPose  ; unconditional
    @swimming:
    lda #eAvatar::Swimming1
    @setPose:
    sta Zp_AvatarPose_eAvatar
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
    fall FuncA_Avatar_RagdollMove
.ENDPROC

;;; Updates the player avatar state without healing or applying the joypad.
;;; Sets Zp_AvatarExit_ePassage if the avatar hits a passage.
.EXPORT FuncA_Avatar_RagdollMove
.PROC FuncA_Avatar_RagdollMove
_RecoverFromLanding:
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Airborne = bProc::Negative, error
    bmi @done
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvs @done
    lda Zp_AvatarState_bAvatar
    and #bAvatar::LandMask
    beq @done  ; landing timer is already zero
    .assert bAvatar::LandMask & $01, error
    dec Zp_AvatarState_bAvatar
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
_SetAvatarPose:
    ;; Check if the player avatar is airborne, swimming, or grounded.
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvs _SetPoseInWater
    .assert bAvatar::Airborne = bProc::Negative, error
    bpl _SetPoseOnGround
_SetPoseInAir:
    ;; The player avatar is airborne; set its pose based on its Y-velocity.
    lda Zp_AvatarVelY_i16 + 1
    bmi @jumping
    cmp #2
    blt @hovering
    lda #eAvatar::Falling
    bne @setAvatarPose  ; unconditional
    @jumping:
    lda #eAvatar::Jumping
    bne @setAvatarPose  ; unconditional
    @hovering:
    lda #eAvatar::Hovering
    @setAvatarPose:
    sta Zp_AvatarPose_eAvatar
    rts
_SetPoseInWater:
    ;; The player avatar is in water, so set its pose to Swimming.
    lda Zp_FrameCounter_u8
    and #$10
    bne @swimming2
    @swimming1:
    lda #eAvatar::Swimming1
    bne @setAvatarPose  ; unconditional
    @swimming2:
    lda #eAvatar::Swimming2
    @setAvatarPose:
    sta Zp_AvatarPose_eAvatar
    rts
_SetPoseOnGround:
    lda Zp_AvatarState_bAvatar
    and #bAvatar::LandMask
    beq @standOrRun  ; landing timer is zero
    @landing:
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Down
    bne @kneeling
    lda #eAvatar::Landing
    bne @setAvatarPose  ; unconditional
    @standOrRun:
    lda Zp_AvatarVelX_i16 + 1
    beq @standing
    lda Zp_FrameCounter_u8
    and #$08
    bne @running2
    @running1:
    lda #eAvatar::Running1
    bne @setAvatarPose  ; unconditional
    @running2:
    lda #eAvatar::Running2
    bne @setAvatarPose  ; unconditional
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
    bne @setAvatarPose  ; unconditional
    @kneeling:
    lda #eAvatar::Kneeling
    bne @setAvatarPose  ; unconditional
    @looking:
    lda #eAvatar::Looking
    @setAvatarPose:
    sta Zp_AvatarPose_eAvatar
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
    pha  ; old Y-velocity (hi)
    adc #0
    sta Zp_AvatarPushDelta_i8
    jsr Func_TryPushAvatarVert
    pla  ; old Y-velocity (hi)
    bmi _NowAirborne  ; avatar is moving up
    sta T0  ; old Y-velocity (hi)
    lda Zp_AvatarCollided_ePlatform
    .assert ePlatform::None = 0, error
    beq _NowAirborne  ; no downward collision
_NowGrounded:
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Airborne = bProc::Negative, error
    bpl @done  ; avatar was already grounded
    @wasAirborne:
    lda #0
    ldy T0  ; old Y-velocity (hi)
    bmi @setState
    lda DataA_Avatar_LandingFrames_u8_arr, y
    @setState:
    sta Zp_AvatarState_bAvatar
    @done:
    rts
_NowAirborne:
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Airborne = bProc::Negative, error
    bmi @done
    lda #bAvatar::Airborne
    sta Zp_AvatarState_bAvatar
    @done:
    rts
.ENDPROC

;;; Maps from non-negative (Zp_AvatarVelY_i16 + 1) values to the value to set
;;; for Zp_AvatarLanding_u8.  The higher the downward speed, the longer the
;;; recovery time.
.PROC DataA_Avatar_LandingFrames_u8_arr
:   .byte 0, 0, 8, 8, 12, 18
    .assert 18 <= bAvatar::LandMask, error
    .assert * - :- = 1 + >kAvatarMaxAirSpeedVert, error
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
    fall FuncA_Avatar_DecelerateHorz
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
    ;; T0.
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvc @inAir
    @inWater:
    .assert <kAvatarMaxWaterSpeedHorz = 0, error
    lda #>-kAvatarMaxWaterSpeedHorz
    bne @setLimit  ; unconditional
    @inAir:
    .assert <kAvatarMaxAirSpeedHorz = 0, error
    lda #>-kAvatarMaxAirSpeedHorz
    @setLimit:
    sta T0  ; negative X-vel limit (pixels/frame)
_AccelOrDecel:
    ;; If the avatar is moving to the right, or moving to the left slower than
    ;; the limit, then accelerate.  Otherwise, decelerate.
    lda Zp_AvatarVelX_i16 + 1
    bpl _AccelerateTowardsLimit
    cmp T0  ; negative X-vel limit (pixels/frame)
    bge _AccelerateTowardsLimit
_DecelerateTowardsLimit:
    ;; Slowly decelerate, up to the (negative) velocity limit at maximum.
    lda Zp_AvatarVelX_i16 + 0
    add #kAvatarHorzDecelSlow
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    adc #0
    cmp T0  ; negitive X-vel limit (pixels/frame)
    blt @noClamp
    @clamp:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda T0  ; negitive X-vel limit (pixels/frame)
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
    cmp T0  ; negative X-vel limit (pixels/frame)
    bge @noClamp
    @clamp:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda T0  ; negative X-vel limit (pixels/frame)
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
    ;; T0.
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvc @inAir
    @inWater:
    .assert <kAvatarMaxWaterSpeedHorz = 0, error
    lda #>kAvatarMaxWaterSpeedHorz
    bne @setLimit  ; unconditional
    @inAir:
    .assert <kAvatarMaxAirSpeedHorz = 0, error
    lda #>kAvatarMaxAirSpeedHorz
    @setLimit:
    sta T0  ; positive X-vel limit (pixels/frame)
_AccelOrDecel:
    ;; If the avatar is moving to the left, or moving to the right slower than
    ;; the limit, then accelerate.  Otherwise, decelerate.
    lda Zp_AvatarVelX_i16 + 1
    bmi _AccelerateTowardsLimit
    cmp T0  ; positive X-vel limit (pixels/frame)
    blt _AccelerateTowardsLimit
_DecelerateTowardsLimit:
    ;; Slowly decelerate, down to the (positive) velocity limit at minimum.
    lda Zp_AvatarVelX_i16 + 0
    sub #kAvatarHorzDecelSlow
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    sbc #0
    cmp T0  ; positive X-vel limit (pixels/frame)
    bge @noClamp
    @clamp:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda T0  ; positive X-vel limit (pixels/frame)
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
    cmp T0  ; positive X-vel limit (pixels/frame)
    blt @noClamp
    @clamp:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda T0  ; positive X-vel limit (pixels/frame)
    @noClamp:
    sta Zp_AvatarVelX_i16 + 1
    rts
.ENDPROC

;;; Updates the player avatar's Y-velocity based on the jump button.
.PROC FuncA_Avatar_ApplyJump
    ;; Check whether the avatar can jump right now.
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Airborne = bProc::Negative, error
    bmi _Airborne
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvc _Grounded
    ;; At this point, we know the avatar is swimming, so check if the avatar is
    ;; underwater, or at the surface.  If at the surface, allow jumping as if
    ;; grounded.
    lda Zp_AvatarState_bAvatar
    and #bAvatar::DepthMask
    bne _Return  ; avatar is underwater and cannot jump
_Grounded:
    ;; If the player presses the jump button while grounded, start a jump.
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::AButton = bProc::Negative, error
    bpl @noJump
    lda #eSample::JumpAnna  ; param: eSample to play
    jsr Func_PlaySfxSample
    ldax #kAvatarJumpVelocity
    stax Zp_AvatarVelY_i16
    lda #bAvatar::Airborne | bAvatar::Jumping
    sta Zp_AvatarState_bAvatar
    @noJump:
    rts
_Airborne:
    ;; If the player stops holding the jump button while jumping, cap the
    ;; upward speed to kAvatarStopJumpSpeed (that is, the Y velocity will be
    ;; greater than or equal to -kAvatarStopJumpSpeed).
    lda Zp_AvatarState_bAvatar
    and #bAvatar::Jumping
    beq _Return  ; avatar is airborne, but is not jumping
    bit Zp_P1ButtonsHeld_bJoypad
    .assert bJoypad::AButton = bProc::Negative, error
    bmi _Return  ; A button is still held, so don't slow the jump
    lda Zp_AvatarVelY_i16 + 1
    bpl _Return  ; avatar is moving downward, not upward
    cmp #$ff & -kAvatarStopJumpSpeed
    bge _Return  ; avatar is already at or below the upward speed cap
    lda #$ff & -kAvatarStopJumpSpeed
    sta Zp_AvatarVelY_i16 + 1
    lda #$00
    sta Zp_AvatarVelY_i16 + 0
_Return:
    rts
.ENDPROC

;;; Updates the player avatar's Y-velocity to apply gravity.
.PROC FuncA_Avatar_ApplyGravity
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Airborne = bProc::Negative, error
    bmi _InAir
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvc _Done
_InWater:
    lda Zp_AvatarState_bAvatar
    and #bAvatar::DepthMask
    ;; Calculate the max upward speed in pixels/frame: either (depth) or
    ;; >kAvatarMaxWaterSpeedUp, whichever is less.
    .assert <kAvatarMaxWaterSpeedUp = 0, error
    cmp #>kAvatarMaxWaterSpeedUp
    blt @setMaxUpwardSpeed
    lda #>kAvatarMaxWaterSpeedUp
    @setMaxUpwardSpeed:
    sta T0  ; max upward speed
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
    add T0  ; max upward speed
    bcs @done
    lda #0
    sta Zp_AvatarVelY_i16 + 0
    sub T0  ; max upward speed
    sta Zp_AvatarVelY_i16 + 1
    rts
    ;; If moving downward, check for terminal velocity:
    @movingDown:
    sta Zp_AvatarVelY_i16 + 1
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
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Stores the room pixel position of the top center of the player avatar in
;;; Zp_Point*_i16.
;;; @preserve X, Y, T0+
.EXPORT Func_SetPointToAvatarTop
.PROC Func_SetPointToAvatarTop
    jsr Func_SetPointToAvatarCenter  ; preserves X, Y, and T0+
    lda #kAvatarBoundingBoxUp  ; param: offset
    jmp Func_MovePointUpByA  ; preserves X, Y, and T0+
.ENDPROC

;;; Stores the player avatar's room pixel position in Zp_Point*_i16.
;;; @preserve X, Y, T0+
.EXPORT Func_SetPointToAvatarCenter
.PROC Func_SetPointToAvatarCenter
    lda Zp_AvatarPosX_i16 + 0
    sta Zp_PointX_i16 + 0
    lda Zp_AvatarPosX_i16 + 1
    sta Zp_PointX_i16 + 1
    lda Zp_AvatarPosY_i16 + 0
    sta Zp_PointY_i16 + 0
    lda Zp_AvatarPosY_i16 + 1
    sta Zp_PointY_i16 + 1
    rts
.ENDPROC

;;; Calculates the angle from the position stored in Zp_Point*_i16 to the
;;; center of the player avatar.
;;; @return A The angle, measured in increments of tau/256.
;;; @preserve X, T4+
.EXPORT Func_GetAngleFromPointToAvatar
.PROC Func_GetAngleFromPointToAvatar
    lda Zp_AvatarPosX_i16 + 0
    sub Zp_PointX_i16 + 0
    sta T0  ; horz delta from point to avatar (lo)
    lda Zp_AvatarPosX_i16 + 1
    sbc Zp_PointX_i16 + 1
    .repeat 3
    lsr a
    ror T0  ; horz delta from point to avatar (lo)
    .endrepeat
    lda Zp_AvatarPosY_i16 + 0
    sub Zp_PointY_i16 + 0
    sta T1  ; vert delta from point to avatar (lo)
    lda Zp_AvatarPosY_i16 + 1
    sbc Zp_PointY_i16 + 1
    .repeat 3
    lsr a
    ror T1  ; vert delta from point to avatar (lo)
    .endrepeat
    lda T0  ; param: horz delta (signed)
    ldy T1  ; param: vert delta (signed)
    jmp Func_SignedAtan2  ; preserves X and T4+, returns A
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
    ;; If the avatar is temporarily invincible, blink the objects.
    lda Zp_AvatarHarmTimer_u8
    cmp #kAvatarHarmDeath
    beq @notInvincible
    cmp #kAvatarHarmHealFrames - kAvatarHarmInvincibleFrames
    blt @notInvincible
    lda Zp_FrameCounter_u8
    and #$02
    bne _Done
    @notInvincible:
_DrawObjects:
    jsr FuncA_Objects_SetShapePosToAvatarCenter
    lda Zp_AvatarPose_eAvatar  ; param: first tile ID
    .assert eAvatar::Hidden = 0, error
    beq _Done
    ldy Zp_AvatarFlags_bObj  ; param: object flags
    jmp FuncA_Objects_Draw2x2Shape
_Done:
    rts
.ENDPROC

;;; Sets Zp_ShapePosX_i16 and Zp_ShapePosY_i16 to the screen-space position of
;;; the player avatar.
;;; @preserve X, Y, T0+
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
