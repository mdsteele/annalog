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

.INCLUDE "audio.inc"
.INCLUDE "boss.inc"
.INCLUDE "device.inc"
.INCLUDE "devices/breaker.inc"
.INCLUDE "fade.inc"
.INCLUDE "machine.inc"
.INCLUDE "macros.inc"
.INCLUDE "music.inc"
.INCLUDE "room.inc"
.INCLUDE "sample.inc"

.IMPORT FuncA_Room_MachineResetHalt
.IMPORT FuncA_Room_PlaySfxBreakerRising
.IMPORT FuncA_Room_SpawnUpgradeDevice
.IMPORT Func_DivMod
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsFlagSet
.IMPORT Func_LockDoorDevice
.IMPORT Func_MarkRoomSafe
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeBig
.IMPORT Func_PlaySfxSample
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetFlag
.IMPORT Func_SetMachineIndex
.IMPORT Func_ShakeRoom
.IMPORT Func_TransferPalettes
.IMPORT Func_UnlockDoorDevice
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

;;; How many frames to wait between explosions during the BossExploding phase.
kFramesPerExplosion = 12

;;; How many explosions to make during the BossExploding phase.
kBossNumExplosions = 16

;;; How many frames to wait between fade steps during the FlashWhite phase.
kFlashWhiteFramesPerStep = 7

;;; How many fade steps are needed during the FlashWhite phase.
.ASSERT eFade::White > eFade::Normal, error
kFlashWhiteNumFadeSteps = eFade::White - eFade::Normal

;;;=========================================================================;;;

.ZEROPAGE

;;; Static data for the boss in this room (if any).
Zp_Current_sBoss_ptr: .res 2

;;; Which phase of the boss fight we're in (if we're in a boss room).
Zp_Boss_eBossPhase: .res 1

;;; Counts down during certain boss phases.
Zp_BossPhaseTimer_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Sets the initial boss phase upon entering a boss room, and sets up the room
;;; as necessary.  This should be called from boss room Enter_func_ptr
;;; functions.
;;; @param AX A pointer to the sBoss struct for this boss.
;;; @return A The initial eBossPhase value.
;;; @return Z Set if the boss is initially alive.
.EXPORT FuncA_Room_InitBoss
.PROC FuncA_Room_InitBoss
    stax Zp_Current_sBoss_ptr
    ;; Clear the phase timer.
    lda #0
    sta Zp_BossPhaseTimer_u8
    ;; Lock the door for now.
    ldx #kBossDoorDeviceIndex  ; param: device index
    jsr Func_LockDoorDevice
    ;; Check if the boss has been defeated yet.
    ldy #sBoss::Boss_eFlag
    lda (Zp_Current_sBoss_ptr), y
    tax  ; param: boss flag
    jsr Func_IsFlagSet  ; returns Z
    bne _BossAlreadyDefeated
    ;; Set and return the initial phase.
    lda #eBossPhase::BossBattle
    sta Zp_Boss_eBossPhase
    rts
_BossAlreadyDefeated:
    jsr Func_MarkRoomSafe
    jsr FuncA_Room_DisableAllMachinesAndConsoles
    ;; Check if the upgrade has been collected yet.
    ldx Ram_DeviceTarget_byte_arr + kBossUpgradeDeviceIndex  ; param: flag
    jsr Func_IsFlagSet  ; returns Z
    bne _UpgradeAlreadyCollected
    ;; If not, the player must have saved after defeating the boss, but before
    ;; collecting the upgrade.  So we'll set the phase to spawn the upgrade.
    lda #30  ; 0.5 seconds
    sta Zp_BossPhaseTimer_u8
    ;; Set and return the initial phase.
    lda #eBossPhase::SpawnUpgrade
    sta Zp_Boss_eBossPhase
    rts
_UpgradeAlreadyCollected:
    ;; Check if the breaker has been activated yet.
    ldx Ram_DeviceTarget_byte_arr + kBossBreakerDeviceIndex  ; param: flag
    jsr Func_IsFlagSet  ; returns Z
    bne _BreakerAlreadyDone
    ;; If not, the player must have saved after defeating the boss and
    ;; collecting the upgrade, but before activating the breaker.  So we'll set
    ;; the phase to spawn the breaker.
    lda #30  ; 0.5 seconds
    sta Zp_BossPhaseTimer_u8
    ;; Set and return the initial phase.
    lda #eBossPhase::SpawnBreaker
    sta Zp_Boss_eBossPhase
    rts
_BreakerAlreadyDone:
    ;; Place the already-activated breaker.
    lda #eDevice::BreakerDone
    sta Ram_DeviceType_eDevice_arr + kBossBreakerDeviceIndex
    ;; Unlock the door.
    ldx #kBossDoorDeviceIndex  ; param: device index
    jsr Func_UnlockDoorDevice
    ;; Set and return the initial phase.
    lda #eBossPhase::Done
    sta Zp_Boss_eBossPhase
    rts
.ENDPROC

;;; Performs per-frame updates for the current boss phase, advancing to the
;;; next phase if necessary.  This should be called from boss room tick
;;; functions.
;;; @prereq FuncA_Room_InitBoss has already been called for this room.
;;; @param A Zero if the boss is dead, nonzero otherwise.
.EXPORT FuncA_Room_TickBoss
.PROC FuncA_Room_TickBoss
    ldy Zp_Boss_eBossPhase
    ;; Don't tick the boss if a machine console is open, unless the eBossPhase
    ;; is FlashWhite (since we don't want the screen to stay stuck on solid
    ;; white while the console is open, to avoid confusing the player).
    cpy #eBossPhase::FlashWhite
    beq @done
    bit Zp_ConsoleMachineIndex_u8
    bpl _Return
    @done:
_HandleCurrentBossPhase:
    sta T2  ; zero if boss is dead
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBossPhase
    d_entry table, BossBattle,    _BossBattle
    d_entry table, BossBlinking,  _BossBlinking
    d_entry table, BossExploding, _BossExploding
    d_entry table, FlashWhite,    _FlashWhite
    d_entry table, SpawnUpgrade,  _SpawnUpgrade
    d_entry table, GetUpgrade,    _GetUpgrade
    d_entry table, SpawnBreaker,  _SpawnBreaker
    d_entry table, FlipBreaker,   _FlipBreaker
    d_entry table, Done,          Func_Noop
    D_END
.ENDREPEAT
_BossBattle:
    ;; Check if the boss is dead yet.
    lda T2  ; zero if boss is dead
    beq @dead
    ;; If the boss is alive, call its tick function.
    @alive:
    ldy #sBoss::Tick_func_ptr
    lda (Zp_Current_sBoss_ptr), y
    sta T0
    iny
    lda (Zp_Current_sBoss_ptr), y
    sta T1
    jmp (T1T0)
    ;; If the boss is dead, then set its flag and mark the room as safe.
    @dead:
    ldy #sBoss::Boss_eFlag
    lda (Zp_Current_sBoss_ptr), y
    tax  ; param: boss flag
    jsr Func_SetFlag
    jsr Func_MarkRoomSafe
    jsr FuncA_Room_DisableAllMachinesAndConsoles
    ;; Turn off the boss music.
    lda #eMusic::Silence
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    lda #eSample::BossRoar7  ; param: eSample to play
    jsr Func_PlaySfxSample
    ;; Reinitialize the timer and proceed to the next phase.
    lda #45  ; 0.75 seconds
    sta Zp_BossPhaseTimer_u8
    lda #eBossPhase::BossBlinking
    sta Zp_Boss_eBossPhase
_Return:
    rts
_BossBlinking:
    ;; Wait for the phase timer to reach zero.
    dec Zp_BossPhaseTimer_u8
    bne @done
    ;; Reinitialize the timer and proceed to the next phase.
    lda #kFramesPerExplosion * kBossNumExplosions
    sta Zp_BossPhaseTimer_u8
    lda #eBossPhase::BossExploding
    sta Zp_Boss_eBossPhase
    @done:
    rts
_BossExploding:
    ;; Check if it's time to start another explosion.
    lda Zp_BossPhaseTimer_u8  ; param: dividend
    ldy #kFramesPerExplosion  ; param: divisor
    jsr Func_DivMod  ; returns quotient in Y and remainder in A
    cmp #kFramesPerExplosion - 1
    bne @noExplosion
    ;; Choose a random position within the boss's body.
    ldy #sBoss::BodyPlatform_u8
    lda (Zp_Current_sBoss_ptr), y
    tax  ; param: platform index
    jsr FuncA_Room_SetPointRandomlyWithinPlatform
    ;; Allocate an actor for the explosion.
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @noExplosion
    jsr Func_SetActorCenterToPoint  ; preserves X
    jsr Func_InitActorSmokeExplosion
    jsr Func_PlaySfxExplodeBig
    @noExplosion:
    ;; Wait for the phase timer to reach zero.
    dec Zp_BossPhaseTimer_u8
    bne @done
    ;; Flash the screen to white.
    ldy #eFade::White  ; param: eFade value
    jsr Func_TransferPalettes
    jsr Func_PlaySfxExplodeBig
    jsr FuncA_Room_ResetHaltAllMachines
    ;; Reinitialize the timer and proceed to the next phase.
    lda #kFlashWhiteFramesPerStep * kFlashWhiteNumFadeSteps
    sta Zp_BossPhaseTimer_u8
    lda #eBossPhase::FlashWhite
    sta Zp_Boss_eBossPhase
    @done:
    rts
_FlashWhite:
    ;; Fade the screen from white.
    lda Zp_BossPhaseTimer_u8  ; param: dividend
    ldy #kFlashWhiteFramesPerStep  ; param: divisor
    jsr Func_DivMod  ; returns quotient in Y and remainder in A
    cmp #1
    bne @noTransfer
    tya  ; quotient
    add #eFade::Normal
    tay  ; param: eFade value
    jsr Func_TransferPalettes
    @noTransfer:
    ;; Wait for the phase timer to reach zero.
    dec Zp_BossPhaseTimer_u8
    bne @done
    ;; Start playing calm music.
    lda #eMusic::Calm
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    ;; Reinitialize the timer and proceed to the next phase.
    lda #105  ; 1.75 seconds
    sta Zp_BossPhaseTimer_u8
    lda #eBossPhase::SpawnUpgrade
    sta Zp_Boss_eBossPhase
    @done:
    rts
_SpawnUpgrade:
    ;; Wait for the phase timer to reach zero.
    dec Zp_BossPhaseTimer_u8
    bne @done
    ;; Spawn the upgrade.
    ldy #kBossUpgradeDeviceIndex  ; param: device index
    jsr FuncA_Room_SpawnUpgradeDevice
    ;; Proceed to the next phase.
    lda #eBossPhase::GetUpgrade
    sta Zp_Boss_eBossPhase
    @done:
    rts
_GetUpgrade:
    ;; Wait until the player has collected the upgrade.
    lda Ram_DeviceType_eDevice_arr + kBossUpgradeDeviceIndex
    .assert eDevice::None = 0, error
    bne @done
    ;; Reinitialize the timer and proceed to the next phase.
    lda #45  ; 0.75 seconds
    sta Zp_BossPhaseTimer_u8
    lda #eBossPhase::SpawnBreaker
    sta Zp_Boss_eBossPhase
    @done:
    rts
_SpawnBreaker:
    ;; Wait for the phase timer to reach zero.
    dec Zp_BossPhaseTimer_u8
    bne @done
    ;; Spawn the breaker.
    lda #eDevice::BreakerRising
    sta Ram_DeviceType_eDevice_arr + kBossBreakerDeviceIndex
    lda #kBreakerRisingDeviceAnimStart
    sta Ram_DeviceAnim_u8_arr + kBossBreakerDeviceIndex
    jsr FuncA_Room_PlaySfxBreakerRising
    ;; Proceed to the next phase.
    lda #eBossPhase::FlipBreaker
    sta Zp_Boss_eBossPhase
    @done:
    rts
_FlipBreaker:
    ;; Shake the room continuously until the breaker finishes rising.
    lda Ram_DeviceType_eDevice_arr + kBossBreakerDeviceIndex
    cmp #eDevice::BreakerRising
    bne @finishedRising
    lda Ram_DeviceAnim_u8_arr + kBossBreakerDeviceIndex
    and #$03
    bne @done
    lda #6  ; param: num frames
    jmp Func_ShakeRoom
    @finishedRising:
    ;; Wait until the player has activated the breaker.
    cmp #eDevice::BreakerDone
    bne @done
    ;; Unlock the door.
    ldx #kBossDoorDeviceIndex  ; param: device index
    jsr Func_UnlockDoorDevice
    ;; Proceed to the next phase.
    lda #eBossPhase::Done
    sta Zp_Boss_eBossPhase
    @done:
    rts
.ENDPROC

;;; Sets Zp_Point*_i16 to a random room pixel position within the platform
;;; rectangle.  The platform's width and height must each fit in one byte.
;;; @param X The platform index.
.PROC FuncA_Room_SetPointRandomlyWithinPlatform
_PointX:
    lda Ram_PlatformRight_i16_0_arr, x
    sub Ram_PlatformLeft_i16_0_arr, x
    tay  ; param: divisor
    jsr Func_GetRandomByte  ; preserves X and Y; returns A (param: dividend)
    jsr Func_DivMod  ; preserves X, returns remainder in A
    add Ram_PlatformLeft_i16_0_arr, x
    sta Zp_PointX_i16 + 0
    lda #0
    adc Ram_PlatformLeft_i16_1_arr, x
    sta Zp_PointX_i16 + 1
_PointY:
    lda Ram_PlatformBottom_i16_0_arr, x
    sub Ram_PlatformTop_i16_0_arr, x
    tay  ; param: divisor
    jsr Func_GetRandomByte  ; preserves X and Y; returns A (param: dividend)
    jsr Func_DivMod  ; preserves X, returns remainder in A
    add Ram_PlatformTop_i16_0_arr, x
    sta Zp_PointY_i16 + 0
    lda #0
    adc Ram_PlatformTop_i16_1_arr, x
    sta Zp_PointY_i16 + 1
    rts
.ENDPROC

;;; Halts all machines in the room, and disables all console devices.
.PROC FuncA_Room_DisableAllMachinesAndConsoles
_DisableMachines:
    lda #eMachine::Halted
    ldx #0
    beq @while  ; unconditional
    @loop:
    sta Ram_MachineStatus_eMachine_arr, x
    inx
    @while:
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    blt @loop
_DisableConsoles:
    ldx #kMaxDevices - 1
    @loop:
    lda Ram_DeviceType_eDevice_arr, x
    cmp #eDevice::Console
    bne @continue
    lda #eDevice::Placeholder
    sta Ram_DeviceType_eDevice_arr, x
    @continue:
    dex
    .assert kMaxDevices <= $80, error
    bpl @loop
    rts
.ENDPROC

;;; Calls FuncA_Room_MachineResetHalt for each machine in the room.
.PROC FuncA_Room_ResetHaltAllMachines
    ldx #0
    beq @while  ; unconditional
    @loop:
    jsr Func_SetMachineIndex
    jsr FuncA_Room_MachineResetHalt
    ldx Zp_MachineIndex_u8
    inx
    @while:
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    blt @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; If the boss is alive, draws it.  This should be called from the room draw
;;; function for boss rooms.
;;; @prereq FuncA_Room_InitBoss has already been called for this room.
.EXPORT FuncA_Objects_DrawBoss
.PROC FuncA_Objects_DrawBoss
    ;; If the boss battle is ongoing, draw the boss.
    lda Zp_Boss_eBossPhase
    .assert eBossPhase::BossBattle = 0, error
    beq _Draw
    ;; If the boss is dead and the screen has flashed white (the point at which
    ;; the boss disappears), don't draw the boss.
    cmp #eBossPhase::FlashWhite
    bge @doNotDraw
    ;; Otherwise, the boss has just died and is blinking, so draw the boss only
    ;; on some frames.
    lda Zp_BossPhaseTimer_u8
    and #$04
    beq _Draw
    @doNotDraw:
    rts
_Draw:
    ldy #sBoss::Draw_func_ptr
    lda (Zp_Current_sBoss_ptr), y
    sta T0
    iny
    lda (Zp_Current_sBoss_ptr), y
    sta T1
    jmp (T1T0)
.ENDPROC

;;;=========================================================================;;;
