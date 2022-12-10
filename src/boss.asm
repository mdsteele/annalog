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

.INCLUDE "boss.inc"
.INCLUDE "device.inc"
.INCLUDE "macros.inc"

.IMPORT FuncA_Room_SpawnBreakerDevice
.IMPORT FuncA_Room_SpawnUpgradeDevice
.IMPORT Func_IsFlagSet
.IMPORT Func_LockDoorDevice
.IMPORT Func_MarkRoomSafe
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Func_UnlockDoorDevice
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORTZP Zp_RoomIsSafe_bool
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

.ZEROPAGE

;;; Which phase of the boss fight we're in (if we're in a boss room).
Zp_Boss_eBossPhase: .res 1

;;; Counts down during boss spawn phases.
Zp_BossSpawnTimer_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Sets the initial boss phase upon entering a boss room, and sets up the
;;; room as necessary.  This should be called from boss room init functions.
;;; @param X The eFlag::Boss* flag for this boss.
;;; @return A The initial eBossPhase value.
;;; @return Z Set if the boss is initially alive.
.EXPORT FuncA_Room_InitBossPhase
.PROC FuncA_Room_InitBossPhase
    stx Zp_Tmp1_byte  ; boss flag
    ;; Clear the spawn timer.
    lda #0
    sta Zp_BossSpawnTimer_u8
    ;; Lock the door for now.
    ldx #kBossDoorDeviceIndex  ; param: device index
    jsr Func_LockDoorDevice  ; preserves Zp_Tmp*
    ;; Check if the boss has been defeated yet.
    ldx Zp_Tmp1_byte  ; param: boss flag
    jsr Func_IsFlagSet  ; returns Z
    bne _BossAlreadyDefeated
    ;; The boss is still alive, so mark the room as unsafe.
    lda #0
    sta Zp_RoomIsSafe_bool
    ;; Set and return the initial phase.
    .assert eBossPhase::BossBattle = 0, error, "should set Z if boss is alive"
    sta Zp_Boss_eBossPhase
    rts
_BossAlreadyDefeated:
    ;; Check if the upgrade has been collected yet.
    ldx Ram_DeviceTarget_u8_arr + kBossUpgradeDeviceIndex  ; param: flag
    jsr Func_IsFlagSet  ; returns Z
    bne _UpgradeAlreadyCollected
    ;; If not, the player must have saved after defeating the boss, but before
    ;; collecting the upgrade.  So we'll set the phase to spawn the upgrade.
    lda #30  ; 0.5 seconds
    sta Zp_BossSpawnTimer_u8
    ;; Set and return the initial phase.
    lda #eBossPhase::SpawnUpgrade
    sta Zp_Boss_eBossPhase
    rts
_UpgradeAlreadyCollected:
    ;; Check if the breaker has been activated yet.
    ldx Ram_DeviceTarget_u8_arr + kBossBreakerDeviceIndex  ; param: flag
    jsr Func_IsFlagSet  ; returns Z
    bne _BreakerAlreadyDone
    ;; If not, the player must have saved after defeating the boss and
    ;; collecting the upgrade, but before activating the breaker.  So we'll set
    ;; the phase to spawn the breaker.
    lda #30  ; 0.5 seconds
    sta Zp_BossSpawnTimer_u8
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
;;; @param A Zero if the boss is dead, nonzero otherwise.
;;; @param X The eFlag::Boss* flag for this boss.
.EXPORT FuncA_Room_TickBossPhase
.PROC FuncA_Room_TickBossPhase
    sta Zp_Tmp1_byte  ; zero if boss is dead
    ldy Zp_Boss_eBossPhase
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eBossPhase
    d_entry table, BossBattle,   _BossBattle
    d_entry table, SpawnUpgrade, _SpawnUpgrade
    d_entry table, GetUpgrade,   _GetUpgrade
    d_entry table, SpawnBreaker, _SpawnBreaker
    d_entry table, FlipBreaker,  _FlipBreaker
    d_entry table, Done,         Func_Noop
    D_END
.ENDREPEAT
_BossBattle:
    ;; Check if the boss is dead yet.
    lda Zp_Tmp1_byte  ; zero if boss is dead
    bne @done
    ;; If the boss is dead, then set its flag and mark the room as safe.
    jsr Func_SetFlag
    jsr Func_MarkRoomSafe
    ;; Start the spawn timer and proceed to the next phase.
    lda #90  ; 1.5 seconds
    sta Zp_BossSpawnTimer_u8
    lda #eBossPhase::SpawnUpgrade
    sta Zp_Boss_eBossPhase
    @done:
    rts
_SpawnUpgrade:
    ;; Wait for the spawn timer to reach zero.
    dec Zp_BossSpawnTimer_u8
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
    ;; Start the spawn timer and proceed to the next phase.
    lda #45  ; 0.75 seconds
    sta Zp_BossSpawnTimer_u8
    lda #eBossPhase::SpawnBreaker
    sta Zp_Boss_eBossPhase
    @done:
    rts
_SpawnBreaker:
    ;; Wait for the spawn timer to reach zero.
    dec Zp_BossSpawnTimer_u8
    bne @done
    ;; Show the breaker.
    ldx #kBossBreakerDeviceIndex
    jsr FuncA_Room_SpawnBreakerDevice
    ;; Proceed to the next phase.
    lda #eBossPhase::FlipBreaker
    sta Zp_Boss_eBossPhase
    @done:
    rts
_FlipBreaker:
    ;; Wait until the player has activated the breaker.
    lda Ram_DeviceType_eDevice_arr + kBossBreakerDeviceIndex
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

;;;=========================================================================;;;
