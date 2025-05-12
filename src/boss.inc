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

;;; The device index for the door that leads out of the boss room.
kBossDoorDeviceIndex = 0

;;; The device index for the upgrade that appears when the boss is defeated.
kBossUpgradeDeviceIndex = 1

;;; The device index for the breaker that appears once the boss is defeated and
;;; the upgrade is collected.
kBossBreakerDeviceIndex = 2

;;; How many frames to wait between fade steps during the FlashWhite phase
;;; after a boss is defeated.
kBossFlashWhiteFramesPerStep = 7

;;;=========================================================================;;;

;;; Phases that a boss fight can be in.
.ENUM eBossPhase
    BossBattle     ; waiting for the player to defeat the boss
    BossBlinking   ; boss is dead, and is blinking
    BossExploding  ; boss is dead, and is blinking and exploding
    FlashWhite     ; flashing to white, then fading back to normal
    SpawnUpgrade   ; waiting for upgrade to spawn
    GetUpgrade     ; waiting for the player to collect the upgrade
    SpawnBreaker   ; waiting for breaker to spawn
    FlipBreaker    ; waiting for the player to activate the breaker
    Done           ; nothing else to do
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; Describes static information about a boss.
.STRUCT sBoss
    ;; The eFlag::Boss* flag for this boss.
    Boss_eFlag      .byte
    ;; The platform index for the body of this boss; this defines the region
    ;; that will have explosions during the boss death animation.
    BodyPlatform_u8 .byte
    ;; Function to call each frame when the boss is alive.
    ;; @prereq PRGA_Room is loaded.
    Tick_func_ptr   .addr
    ;; Function to call each frame (if the boss is alive) to draw the boss.
    ;; This can also set up IRQs for the boss.
    ;; @prereq PRGA_Objects is loaded.
    Draw_func_ptr   .addr
.ENDSTRUCT

;;;=========================================================================;;;
