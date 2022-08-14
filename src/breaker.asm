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
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"

.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT Func_ClearRestOfOam
.IMPORT Func_ProcessFrame
.IMPORT Func_SetFlag
.IMPORT Func_SetLastSpawnPoint
.IMPORT Func_TickAllDevices
.IMPORT Main_Explore_Continue
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarHarmTimer_u8
.IMPORTZP Zp_AvatarMode_eAvatar
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarRecover_u8
.IMPORTZP Zp_AvatarSubX_u8
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_AvatarVelY_i16
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

;;; The durations of various breaker activation phases, in frames.
kBreakerReachFrames  = $90
kBreakerStrainFrames = 80
kBreakerFlipFrames   = kBreakerDoneDeviceAnimStart + 60

;;;=========================================================================;;;

;;; Phases of the breaker activation process.
.ENUM ePhase
    Adjust
    Reach
    Strain
    Flip
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

.ZEROPAGE

;;; The device index of the breaker that's being activated.
Zp_BreakerDeviceIndex_u8: .res 1

;;; Which phase of the breaker activation process we're currently in.
Zp_Breaker_ePhase: .res 1

;;; The number of remaining frames in the current breaker activation phase.
Zp_BreakerTimer_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for activating a circuit breaker.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @param X The device index for the breaker to activate.
.EXPORT Main_Breaker_Activate
.PROC Main_Breaker_Activate
    jsr_prga FuncA_Breaker_Init
_GameLoop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_TickAllDevices
    jsr_prga FuncA_Breaker_Tick
    ;; Once we've finished the last phase, breaker mode is done.
    lda Zp_Breaker_ePhase
    cmp #ePhase::NUM_VALUES
    blt _GameLoop
    jmp Main_Explore_Continue
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Breaker"

;;; Initializes breaker mode.
;;; @prereq Explore mode is initialized.
;;; @param X The device index for the breaker to activate.
.PROC FuncA_Breaker_Init
    stx Zp_BreakerDeviceIndex_u8
    ;; Set the spawn point and mark the breaker as activated.
    txa  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint  ; preserves X
    lda Ram_DeviceTarget_u8_arr, x
    tax  ; param: eFlag value
    jsr Func_SetFlag
    ;; Zero the player avatar's velocity, and fully heal them.
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    sta Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 1
    sta Zp_AvatarHarmTimer_u8
    sta Zp_AvatarRecover_u8
    ;; Initialize the breaker mode's state machine.
    .assert ePhase::Adjust = 0, error
    sta Zp_Breaker_ePhase
    sta Zp_BreakerTimer_u8
    rts
.ENDPROC

;;; Performs per-frame updates for breaker activation mode.
.PROC FuncA_Breaker_Tick
    lda Zp_Breaker_ePhase
    mul #2
    tay
    lda _JumpTable_ptr_arr + 0, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_arr + 1, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
_JumpTable_ptr_arr:
    D_ENUM ePhase, kSizeofAddr
    d_addr Adjust, FuncA_Breaker_TickAdjust
    d_addr Reach, FuncA_Breaker_TickReach
    d_addr Strain, FuncA_Breaker_TickStrain
    d_addr Flip, FuncA_Breaker_TickFlip
    D_END
.ENDPROC

;;; Performs per-frame updates for the "adjust" phase of breaker activation.
;;; In this phase, the player avatar's position is adjusted over several frames
;;; until it reaches a specific offset from the breaker device's position.
.PROC FuncA_Breaker_TickAdjust
    lda #eAvatar::Looking
    sta Zp_AvatarMode_eAvatar
    lda Zp_AvatarPosX_i16 + 0
    and #$0f
    cmp #kBreakerAvatarOffset
    blt @adjustRight
    beq _FinishedAdjusting
    @adjustLeft:
    dec Zp_AvatarPosX_i16 + 0
    lda Zp_AvatarFlags_bObj
    ora #bObj::FlipH
    bne @setAdjustment  ; unconditional
    @adjustRight:
    inc Zp_AvatarPosX_i16 + 0
    lda Zp_AvatarFlags_bObj
    and #<~bObj::FlipH
    @setAdjustment:
    sta Zp_AvatarFlags_bObj
    lda #0
    sta Zp_AvatarSubX_u8
    rts
_FinishedAdjusting:
    ;; Make the player avatar face to the right.
    lda Zp_AvatarFlags_bObj
    and #<~bObj::FlipH
    sta Zp_AvatarFlags_bObj
    ;; Proceed to the next phase.
    lda #kBreakerReachFrames
    sta Zp_BreakerTimer_u8
    .assert ePhase::Reach = 1 + ePhase::Adjust, error
    inc Zp_Breaker_ePhase
    rts
.ENDPROC

;;; Performs per-frame updates for the "reach" phase of breaker activation.  In
;;; this phase, the player avatar reaches upward towards the breaker lever (but
;;; can't quite reach it).
.PROC FuncA_Breaker_TickReach
    lda Zp_BreakerTimer_u8
    and #$30
    cmp #$20
    blt @looking
    bit Zp_BreakerTimer_u8
    .assert bProc::Overflow = $40, error
    bvc @straining
    @reaching:
    lda #eAvatar::Reaching
    bne @setAvatar  ; unconditional
    @straining:
    lda #eAvatar::Straining
    bne @setAvatar  ; unconditional
    @looking:
    lda #eAvatar::Looking
    @setAvatar:
    sta Zp_AvatarMode_eAvatar
_DecrementTimer:
    dec Zp_BreakerTimer_u8
    bne _Return
_FinishedReaching:
    lda #eAvatar::Straining
    sta Zp_AvatarMode_eAvatar
    ;; Proceed to the next phase.
    lda #kBreakerStrainFrames
    sta Zp_BreakerTimer_u8
    .assert ePhase::Strain = 1 + ePhase::Reach, error
    inc Zp_Breaker_ePhase
_Return:
    rts
.ENDPROC

;;; Performs per-frame updates for the "strain" phase of breaker activation.
;;; In this phase, the player avatar strains upward and wobbles as they try to
;;; reach the breaker lever.
.PROC FuncA_Breaker_TickStrain
    ;; Make the avatar wobble horizontally.
    lda Zp_FrameCounter_u8
    and #$04
    beq @left
    @right:
    lda #kBreakerAvatarOffset
    .assert kBreakerAvatarOffset > 0, error
    bne @setPos  ; unconditional
    @left:
    lda #kBreakerAvatarOffset - 1
    @setPos:
    sta Zp_Tmp1_byte
    lda Zp_AvatarPosX_i16 + 0
    and #$f0
    ora Zp_Tmp1_byte
    sta Zp_AvatarPosX_i16 + 0
_DecrementTimer:
    dec Zp_BreakerTimer_u8
    bne _Return
_FinishedStraining:
    ;; Fix player avatar's X-position.
    lda Zp_AvatarPosX_i16 + 0
    and #$f0
    ora #kBreakerAvatarOffset
    sta Zp_AvatarPosX_i16 + 0
    ;; Flip the breaker.
    ldx Zp_BreakerDeviceIndex_u8
    lda #eDevice::BreakerDone
    sta Ram_DeviceType_eDevice_arr, x
    lda #kBreakerDoneDeviceAnimStart
    sta Ram_DeviceAnim_u8_arr, x
    ;; Proceed to the next phase.
    lda #kBreakerFlipFrames
    sta Zp_BreakerTimer_u8
    .assert ePhase::Flip = 1 + ePhase::Strain, error
    inc Zp_Breaker_ePhase
_Return:
    rts
.ENDPROC

;;; Performs per-frame updates for the "flip" phase of breaker activation.  In
;;; this phase, the player avatar grabs and pulls the breaker lever down.
.PROC FuncA_Breaker_TickFlip
    ;; Animate the avatar to match the flipping breaker.
    ldx Zp_BreakerDeviceIndex_u8
    lda Ram_DeviceAnim_u8_arr, x
    div #8
    tay
    lda _AvatarMode_eAvatar_arr, y
    sta Zp_AvatarMode_eAvatar
    ;; Adjust the avatar's Y-position.
    lda Zp_AvatarPosY_i16 + 0
    and #$f0
    ora _AvatarOffsetY_u8_arr, y
    sta Zp_AvatarPosY_i16 + 0
_DecrementTimer:
    dec Zp_BreakerTimer_u8
    bne _Return
_FinishedFlipping:
    ;; Proceed to the next phase.
    .assert ePhase::NUM_VALUES = 1 + ePhase::Flip, error
    inc Zp_Breaker_ePhase
_Return:
    rts
_AvatarMode_eAvatar_arr:
    .byte eAvatar::Ducking
    .byte eAvatar::Standing
    .byte eAvatar::Reaching
    .byte eAvatar::Straining
_AvatarOffsetY_u8_arr:
    .byte $08
    .byte $08
    .byte $08
    .byte $06
.ENDPROC

;;;=========================================================================;;;
