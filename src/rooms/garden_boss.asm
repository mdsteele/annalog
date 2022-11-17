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

.INCLUDE "../actor.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/cannon.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "garden_boss.inc"

.IMPORT DataA_Pause_GardenAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_GardenAreaName_u8_arr
.IMPORT DataA_Room_Garden_sTileset
.IMPORT FuncA_Machine_CannonTick
.IMPORT FuncA_Machine_CannonTryAct
.IMPORT FuncA_Machine_CannonTryMove
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_DrawCannonMachine
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_SpawnBreakerDevice
.IMPORT FuncA_Room_SpawnUpgradeDevice
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorProjFireball
.IMPORT Func_InitActorProjSmoke
.IMPORT Func_InitActorProjSpike
.IMPORT Func_LockDoorDevice
.IMPORT Func_MachineCannonReadRegY
.IMPORT Func_MarkRoomSafe
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Func_UnlockDoorDevice
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Ram_RoomState
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_RoomIsSafe_bool
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

;;; The device index for the upgrade that appears when the boss is defeated.
kUpgradeDeviceIndex = 0
;;; The room block row/col where the upgrade will appear.
kUpgradeBlockRow = 12
kUpgradeBlockCol = 8
;;; The eFlag value for the upgrade in this room.
kUpgradeFlag = eFlag::UpgradeMaxInstructions0

;;; The device index for the breaker that appears once the boss is defeated and
;;; the upgrade is collected.
kBreakerDeviceIndex = 1

;;; The device index for the door.
kDoorDeviceIndex = 2

;;; The machine index for the GardenBossCannon machine.
kCannonMachineIndex = 0
;;; The platform index for the GardenBossCannon machine.
kCannonPlatformIndex = 0
;;; Initial position for grenades shot from the cannon.
kCannonGrenadeInitPosX = $28
kCannonGrenadeInitPosY = $78

;;; The platform index for the boss's thorny vines.
kThornsPlatformIndex = 1

;;;=========================================================================;;;

;;; How many grenade hits are needed to defeat the boss.
kBossInitHealth = 8

;;; How many frames the boss waits, after you first enter the room, before
;;; taking action.
kBossInitCooldown = 120
;;; How many frames to wait between spikes when the boss is in Angry mode.
kBossAngrySpikeCooldown = 15
;;; How many frames to wait between fireballs when the boss is in Shoot mode.
kBossShootFireballCooldown = 60

;;; How many frames it takes for an eye to fully open or close.
kBossEyeOpenFrames = 20

;;; The platform indices for the boss's two eyes.
kLeftEyePlatformIndex = 2
kRightEyePlatformIndex = 3

;;; The X/Y positions of the centers of the boss's two eyes.
kBossLeftEyeCenterX  = $68
kBossLeftEyeCenterY  = $58
kBossRightEyeCenterX = $98
kBossRightEyeCenterY = $78

;;; The OBJ palette number used for the eyes of the boss.
kPaletteObjBossEye = 1

;;;=========================================================================;;;

;;; Phases that the boss fight can be in.
.ENUM ePhase
    BossBattle    ; waiting for the player to defeat the boss
    SpawnUpgrade  ; waiting for upgrade to spawn
    GetUpgrade    ; waiting for the player to collect the upgrade
    SpawnBreaker  ; waiting for breaker to spawn
    FlipBreaker   ; waiting for the player to activate the breaker
    Done          ; nothing else to do
    NUM_VALUES
.ENDENUM

;;; Modes that the boss in this room can be in.
.ENUM eBoss
    Dead
    Waiting  ; eyes closed
    Angry    ; eyes closed, dropping spikes
    Shoot    ; active eye open, shooting fireballs one at a time
    Spray    ; active eye open, shooting a wave of fireballs
    NUM_VALUES
.ENDENUM

;;; Eyes of the boss.
.ENUM eEye
    Left
    Right
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u1         .byte
    LeverRight_u1        .byte
    ;; Which phase of the boss fight we're in.
    Current_ePhase       .byte
    ;; Counts down during spawn phases.
    SpawnTimer_u8        .byte
    ;; How many more grenade hits are needed before the boss dies.
    BossHealth_u8        .byte
    ;; Timer that ticks down each frame when nonzero.  Used to time transitions
    ;; between boss modes.
    BossCooldown_u8      .byte
    ;; What mode the boss is in.
    BossMode_eBoss       .byte
    ;; How many more projectiles (fireballs or spikes) to shoot before changing
    ;; modes.
    BossProjCount_u8     .byte
    ;; Which eye is "active".
    BossActive_eEye      .byte
    ;; How open each of the eyes are, from 0 (closed) to kBossEyeOpenFrames
    ;; (open), indexed by eEye.
    BossEyeOpen_u8_arr2  .res 2
    ;; If nonzero, this is how many more frames to flash each eye.
    BossEyeFlash_u8_arr2 .res 2
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_Boss_sRoom
.PROC DataC_Garden_Boss_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 7
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjGarden)
    d_addr Tick_func_ptr, FuncC_Garden_Boss_TickRoom
    d_addr Draw_func_ptr, FuncA_Objects_GardenBoss_Draw
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_GardenAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_GardenAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Init_func_ptr, FuncC_Garden_Boss_InitRoom
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/garden_boss.room"
    .assert * - :- = 16 * 16, error
_Machines_sMachine_arr:
:   .assert * - :- = kCannonMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenBossCannon
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0e
    d_byte RegNames_u8_arr4, "L", "R", 0, "Y"
    d_byte MainPlatform_u8, kCannonPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Garden_BossCannon_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CannonTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CannonTryAct
    d_addr Tick_func_ptr, FuncA_Machine_CannonTick
    d_addr Draw_func_ptr, FuncA_Objects_DrawCannonMachine
    d_addr Reset_func_ptr, FuncC_Garden_BossCannon_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kCannonPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0020
    d_word Top_i16,   $0070
    D_END
    .assert * - :- = kThornsPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $50
    d_byte HeightPx_u8, $4e
    d_word Left_i16,  $0090
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kLeftEyePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, 0
    d_byte HeightPx_u8, 0
    d_word Left_i16, kBossLeftEyeCenterX
    d_word Top_i16,  kBossLeftEyeCenterY
    D_END
    .assert * - :- = kRightEyePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, 0
    d_byte HeightPx_u8, 0
    d_word Left_i16, kBossRightEyeCenterX
    d_word Top_i16,  kBossRightEyeCenterY
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be an upgrade
    d_byte BlockRow_u8, kUpgradeBlockRow
    d_byte BlockCol_u8, kUpgradeBlockCol
    d_byte Target_u8, kUpgradeFlag
    D_END
    .assert * - :- = kBreakerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be a breaker
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 5
    d_byte Target_u8, eFlag::BreakerGarden
    D_END
    .assert * - :- = kDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::UnlockedDoor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 7
    d_byte Target_u8, eRoom::GardenTower
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 3
    d_byte Target_u8, sState::LeverLeft_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 10
    d_byte Target_u8, sState::LeverRight_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 12
    d_byte Target_u8, kCannonMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

;;; Room init function for the GardenBoss room.
.PROC FuncC_Garden_Boss_InitRoom
    ;; Lock the door for now.
    ldx #kDoorDeviceIndex  ; param: device index
    jsr Func_LockDoorDevice
    ;; Check if the boss has been defeated yet.
    lda Sram_ProgressFlags_arr + (eFlag::BossGarden >> 3)
    and #1 << (eFlag::BossGarden & $07)
    bne _BossAlreadyDefeated
    ;; The boss is still alive, so mark the room as unsafe.
    sta Zp_RoomIsSafe_bool  ; A is already zero
    ;; Set the current phase.
    .assert ePhase::BossBattle = 0, error
    sta Ram_RoomState + sState::Current_ePhase
    ;; Initialize the boss.
    lda #kBossInitHealth
    sta Ram_RoomState + sState::BossHealth_u8
    lda #kBossInitCooldown
    sta Ram_RoomState + sState::BossCooldown_u8
    lda #eBoss::Waiting
    sta Ram_RoomState + sState::BossMode_eBoss
    rts
_BossAlreadyDefeated:
    ;; Remove the boss's thorns.
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kThornsPlatformIndex
    ;; Check if the upgrade has been collected yet.
    lda Sram_ProgressFlags_arr + (kUpgradeFlag >> 3)
    and #1 << (kUpgradeFlag & $07)
    bne _UpgradeAlreadyCollected
    ;; If not, the player must have saved after defeating the boss, but before
    ;; collecting the upgrade.  So we'll set the phase to spawn the upgrade.
    lda #30  ; 0.5 seconds
    sta Ram_RoomState + sState::SpawnTimer_u8
    lda #ePhase::SpawnUpgrade
    sta Ram_RoomState + sState::Current_ePhase
    rts
_UpgradeAlreadyCollected:
    ;; Check if the breaker has been activated yet.
    lda Sram_ProgressFlags_arr + (eFlag::BreakerGarden >> 3)
    and #1 << (eFlag::BreakerGarden & $07)
    bne _BreakerAlreadyDone
    ;; If not, the player must have saved after defeating the boss and
    ;; collecting the upgrade, but before activating the breaker.  So we'll set
    ;; the phase to spawn the breaker.
    lda #30  ; 0.5 seconds
    sta Ram_RoomState + sState::SpawnTimer_u8
    lda #ePhase::SpawnBreaker
    sta Ram_RoomState + sState::Current_ePhase
    rts
_BreakerAlreadyDone:
    lda #ePhase::Done
    sta Ram_RoomState + sState::Current_ePhase
    ;; Place the already-activated breaker.
    lda #eDevice::BreakerDone
    sta Ram_DeviceType_eDevice_arr + kBreakerDeviceIndex
    ;; Unlock the door.
    ldx #kDoorDeviceIndex  ; param: device index
    jmp Func_UnlockDoorDevice
.ENDPROC

;;; Room tick function for the GardenBoss room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Garden_Boss_TickRoom
    ldy Ram_RoomState + sState::Current_ePhase
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE ePhase
    d_entry table, BossBattle,   _BossBattle
    d_entry table, SpawnUpgrade, _SpawnUpgrade
    d_entry table, GetUpgrade,   _GetUpgrade
    d_entry table, SpawnBreaker, _SpawnBreaker
    d_entry table, FlipBreaker,  _FlipBreaker
    d_entry table, Done,         Func_Noop
    D_END
.ENDREPEAT
_SpawnUpgrade:
    ;; Wait for the spawn timer to reach zero.
    dec Ram_RoomState + sState::SpawnTimer_u8
    bne @done
    ;; Spawn the upgrade.
    ldy #kUpgradeDeviceIndex  ; param: device index
    jsr FuncA_Room_SpawnUpgradeDevice
    ;; Proceed to the next phase.
    inc Ram_RoomState + sState::Current_ePhase
    @done:
    rts
_GetUpgrade:
    ;; Wait until the player has collected the upgrade.
    lda Ram_DeviceType_eDevice_arr + kUpgradeDeviceIndex
    .assert eDevice::None = 0, error
    bne @done
    ;; Start the spawn timer.
    lda #45  ; 0.75 seconds
    sta Ram_RoomState + sState::SpawnTimer_u8
    ;; Proceed to the next phase.
    inc Ram_RoomState + sState::Current_ePhase
    @done:
    rts
_SpawnBreaker:
    ;; Wait for the spawn timer to reach zero.
    dec Ram_RoomState + sState::SpawnTimer_u8
    bne @done
    ;; Show the breaker.
    ldx #kBreakerDeviceIndex
    jsr FuncA_Room_SpawnBreakerDevice
    ;; Proceed to the next phase.
    inc Ram_RoomState + sState::Current_ePhase
    @done:
    rts
_FlipBreaker:
    ;; Wait until the player has activated the breaker.
    lda Ram_DeviceType_eDevice_arr + kBreakerDeviceIndex
    cmp #eDevice::BreakerDone
    bne @done
    ;; Unlock the door.
    ldx #kDoorDeviceIndex  ; param: device index
    jsr Func_UnlockDoorDevice
    ;; Proceed to the next phase.
    inc Ram_RoomState + sState::Current_ePhase
    @done:
    rts
_BossBattle:
    ;; Check if the boss is dead yet.
    lda Ram_RoomState + sState::BossMode_eBoss
    .assert eBoss::Dead = 0, error
    bne @bossIsStillAlive
    ;; If the boss is dead, then set its flag and mark the room as safe.
    ldx #eFlag::BossGarden  ; param: eFlag value
    jsr Func_SetFlag
    jsr Func_MarkRoomSafe
    ;; Start the spawn timer and proceed to the next phase.
    lda #90  ; 1.5 seconds
    sta Ram_RoomState + sState::SpawnTimer_u8
    inc Ram_RoomState + sState::Current_ePhase
    rts
    @bossIsStillAlive:
    jsr FuncC_Garden_Boss_CheckForGrenadeHit
    .assert * = FuncC_Garden_Boss_TickBoss, error, "fallthrough"
.ENDPROC

;;; Performs per-frame upates for the boss in this room (if it's still alive).
.PROC FuncC_Garden_Boss_TickBoss
    ;; Tick eyes.
    ldx #eEye::Left  ; param: eye to tick
    jsr FuncC_Garden_Boss_TickEye
    ldx #eEye::Right  ; param: eye to tick
    jsr FuncC_Garden_Boss_TickEye
    ;; Wait for cooldown to expire.
    dec Ram_RoomState + sState::BossCooldown_u8
    beq _CheckMode
    rts
_CheckMode:
    ;; Branch based on the current boss mode.
    ldy Ram_RoomState + sState::BossMode_eBoss
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eBoss
    d_entry table, Dead,    Func_Noop
    d_entry table, Waiting, _BossWaiting
    d_entry table, Angry,   _BossAngry
    d_entry table, Shoot,   _BossShoot
    d_entry table, Spray,   _BossSpray
    D_END
.ENDREPEAT
_BossSpray:
    ;; TODO: Shoot a spray of fireballs, then return to Waiting mode.
_BossShoot:
    ldy Ram_RoomState + sState::BossActive_eEye  ; param: eye to shoot from
    jsr FuncC_Garden_Boss_ShootFireball
    ;; Decrement the projectile counter; if it reaches zero, return to waiting
    ;; mode.
    dec Ram_RoomState + sState::BossProjCount_u8
    jeq FuncC_Garden_Boss_StartWaiting
    ;; Otherwise, set the cooldown for the next fireball.
    lda #kBossShootFireballCooldown
    sta Ram_RoomState + sState::BossCooldown_u8
    rts
_BossAngry:
    jsr FuncC_Garden_Boss_DropSpike
    ;; Decrement the projectile counter; if it reaches zero, return to waiting
    ;; mode.
    dec Ram_RoomState + sState::BossProjCount_u8
    jeq FuncC_Garden_Boss_StartWaiting
    ;; Otherwise, set the cooldown for the next spike.
    lda #kBossAngrySpikeCooldown
    sta Ram_RoomState + sState::BossCooldown_u8
    rts
_BossWaiting:
    jsr Func_GetRandomByte  ; returns A
    sta Zp_Tmp1_byte  ; 8 random bits
    ;; Choose a random eye to open.
    and #$01
    sta Ram_RoomState + sState::BossActive_eEye
    lsr Zp_Tmp1_byte  ; now 7 random bits
    ;; If the boss is at high health, switch to Shoot mode; if at low health,
    ;; randomly choose between Shoot and Spray mode.
    lda Ram_RoomState + sState::BossHealth_u8
    cmp #kBossInitHealth / 2
    blt @lowHealth
    @highHealth:
    lda #eBoss::Shoot
    .assert eBoss::Shoot > 0, error
    bne @setMode  ; unconditional
    @lowHealth:
    lda Zp_Tmp1_byte  ; 7 random bits
    and #$01
    .assert eBoss::Shoot + 1 = eBoss::Spray, error
    add #eBoss::Shoot
    lsr Zp_Tmp1_byte  ; now 6 random bits
    @setMode:
    sta Ram_RoomState + sState::BossMode_eBoss
    ;; Choose a random number of fireballs to shoot, from 4-7.
    lda Zp_Tmp1_byte  ; at least 6 random bits
    and #$03
    add #4
    sta Ram_RoomState + sState::BossProjCount_u8
    ;; Initialize the cooldown.
    lda #kBossEyeOpenFrames
    sta Ram_RoomState + sState::BossCooldown_u8
    rts
.ENDPROC

;;; Opens or closes the specified boss eye, depending on the boss mode.
;;; @param X Which eEye to update.
.PROC FuncC_Garden_Boss_TickEye
    lda Ram_RoomState + sState::BossEyeFlash_u8_arr2, x
    beq @noFlash
    dec Ram_RoomState + sState::BossEyeFlash_u8_arr2, x
    @noFlash:
_CheckIfOpenOrClosed:
    lda Ram_RoomState + sState::BossMode_eBoss
    cmp #eBoss::Shoot
    .assert eBoss::Spray > eBoss::Shoot, error
    blt _Close
    cpx Ram_RoomState + sState::BossActive_eEye
    bne _Close
_Open:
    lda Ram_RoomState + sState::BossEyeOpen_u8_arr2, x
    cmp #kBossEyeOpenFrames
    bge @done
    inc Ram_RoomState + sState::BossEyeOpen_u8_arr2, x
    @done:
    rts
_Close:
    lda Ram_RoomState + sState::BossEyeOpen_u8_arr2, x
    beq @done
    dec Ram_RoomState + sState::BossEyeOpen_u8_arr2, x
    @done:
    rts
.ENDPROC

;;; Shoots a fireball from the specified eye.
;;; @param Y Which eEye to shoot from.
.PROC FuncC_Garden_Boss_ShootFireball
    ;; Shoot a fireball.
    jsr Func_FindEmptyActorSlot  ; preserves Y, sets C on failure, returns X
    bcs @done
    ;; Initialize fireball position based on which eye we're shooting from.
    lda #0
    sta Ram_ActorPosX_i16_1_arr, x
    sta Ram_ActorPosY_i16_1_arr, x
    lda _FireballPosY_u8_arr2, y
    sta Ram_ActorPosY_i16_0_arr, x
    lda _FireballPosX_u8_arr2, y
    sta Ram_ActorPosX_i16_0_arr, x
    ;; Choose fireball angle based on the player avatar's X-position.
    lda Zp_AvatarPosX_i16 + 0
    div #kTileWidthPx
    and #$fe  ; now A is 2 * avatar's room block column
    ora Ram_RoomState + sState::BossActive_eEye
    tay
    lda _FireballAngle_u8_arr2_arr, y  ; param: aim angle
    jsr Func_InitActorProjFireball
    @done:
    rts
_FireballPosX_u8_arr2:
    D_ENUM eEye
    d_byte Left,  kBossLeftEyeCenterX
    d_byte Right, kBossRightEyeCenterX
    D_END
_FireballPosY_u8_arr2:
    D_ENUM eEye
    d_byte Left,  kBossLeftEyeCenterY
    d_byte Right, kBossRightEyeCenterY
    D_END
_FireballAngle_u8_arr2_arr:
    ;; Each pair has angles for left eye and right eye.
    ;; There is one pair for each room block column.
    .byte 16, 16
    .byte 16, 16
    .byte 23, 28  ; leftmost side of room
    .byte 21, 27  ; left lever
    .byte 19, 24  ; leftmost side of lowest floor
    .byte 17, 23
    .byte 16, 21  ; below left eye
    .byte 15, 20
    .byte 13, 18
    .byte 11, 16  ; below right eye
    .byte 10, 14  ; right lever
    .byte  9, 11
    .byte  7,  8  ; console
    .byte  4,  3
.ENDPROC

;;; Drops a spike from a random horizontal position.
.PROC FuncC_Garden_Boss_DropSpike
    ;; Drop a spike from a random location.
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @done
    ;; Set random X-position within room:
    jsr Func_GetRandomByte  ; returns A, preserves X
    cmp #$a0
    blt @noWrap
    sbc #$80
    @noWrap:
    adc #$30
    sta Ram_ActorPosX_i16_0_arr, x
    ;; Set Y-position based on the room block column of the X-position:
    div #kTileWidthPx * 2
    tay
    lda _SpikePosY_u8_arr, y
    sta Ram_ActorPosY_i16_0_arr, x
    ;; Initialize the spike:
    lda #0
    sta Ram_ActorPosX_i16_1_arr, x
    sta Ram_ActorPosY_i16_1_arr, x
    jsr Func_InitActorProjSpike
    @done:
    rts
_SpikePosY_u8_arr:
    .byte $00, $00, $41, $39, $41, $49, $61, $61, $71, $81, $81, $81, $81, $81
.ENDPROC

;;; Makes the boss enter waiting mode for a random amount of time (between
;;; about 1-2 seconds).
;;; @preserve X
.PROC FuncC_Garden_Boss_StartWaiting
    lda #eBoss::Waiting
    sta Ram_RoomState + sState::BossMode_eBoss
    jsr Func_GetRandomByte  ; preserves X, returns A
    and #$3f
    ora #$40
    sta Ram_RoomState + sState::BossCooldown_u8
    rts
.ENDPROC

;;; Checks if a grenade has hit a boss eye; if so, explodes the grenade and
;;; makes the boss react accordingly.
.PROC FuncC_Garden_Boss_CheckForGrenadeHit
    ;; Find the actor index for the grenade in flight (if any).  If we don't
    ;; find one, then we're done.
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::ProjGrenade
    beq @foundGrenade
    dex
    .assert kMaxActors <= $80, error
    bpl @loop
    rts
    @foundGrenade:
_CheckEyes:
    ;; Check which eye the grenade is near vertically.
    lda Ram_ActorPosY_i16_0_arr, x
    cmp #kBossLeftEyeCenterY + 6
    bge @grenadeIsLow
    @grenadeIsHigh:
    lda #kBossLeftEyeCenterX
    ldy #eEye::Left
    .assert eEye::Left = 0, error
    beq @checkPosX  ; unconditional
    @grenadeIsLow:
    lda #kBossRightEyeCenterX
    ldy #eEye::Right
    @checkPosX:
    ;; Check if the grenade has hit an eye yet.  If not, we're done.
    cmp Ram_ActorPosX_i16_0_arr, x
    bge _Done
    ;; Check if the hit eye is open or closed.
    lda Ram_RoomState + sState::BossEyeOpen_u8_arr2, y
    cmp #kBossEyeOpenFrames / 2
    bge @eyeIsOpen
    ;; If the hit eye is closed, switch the boss to Angry mode.
    @eyeIsClosed:
    lda #eBoss::Angry
    sta Ram_RoomState + sState::BossMode_eBoss
    .assert eBoss::Angry = 2, error
    sta Ram_RoomState + sState::BossCooldown_u8
    lda #3
    sta Ram_RoomState + sState::BossProjCount_u8
    bne @explode  ; unconditional
    ;; If the hit eye is open, deal damage to the boss.
    @eyeIsOpen:
    dec Ram_RoomState + sState::BossHealth_u8
    bne @bossIsStillAlive
    ;; If the boss's health is now zero, mark the boss as dead.
    ;; TODO: make a death animation
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kThornsPlatformIndex
    lda #eBoss::Dead
    sta Ram_RoomState + sState::BossMode_eBoss
    .assert eBoss::Dead = 0, error
    beq @explode  ; unconditional
    ;; Otherwise, put the boss into waiting mode.
    @bossIsStillAlive:
    lda #kBossEyeOpenFrames
    sta Ram_RoomState + sState::BossEyeFlash_u8_arr2, y
    jsr FuncC_Garden_Boss_StartWaiting  ; preserves X
    ;; Explode the grenade.
    @explode:
    jsr Func_InitActorProjSmoke
    ;; TODO: play a sound for hitting the eye
_Done:
    rts
.ENDPROC

.PROC FuncC_Garden_BossCannon_ReadReg
    cmp #$c
    beq @readL
    cmp #$d
    beq @readR
    @readY:
    jmp Func_MachineCannonReadRegY
    @readL:
    lda Ram_RoomState + sState::LeverLeft_u1
    rts
    @readR:
    lda Ram_RoomState + sState::LeverRight_u1
    rts
.ENDPROC

.PROC FuncC_Garden_BossCannon_Reset
    lda #0
    sta Ram_MachineGoalVert_u8_arr + kCannonMachineIndex
    ;; If the boss is currently shooting/spraying, switch to waiting mode (to
    ;; avoid the player cheesing by reprogramming the machine every time the
    ;; boss opens an eye).
    lda Ram_RoomState + sState::BossMode_eBoss
    cmp #eBoss::Shoot
    .assert eBoss::Spray > eBoss::Shoot, error
    blt @done
    jmp FuncC_Garden_Boss_StartWaiting
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the boss.
.PROC FuncA_Objects_GardenBoss_Draw
    lda Ram_RoomState + sState::BossMode_eBoss
    .assert eBoss::Dead = 0, error
    beq @done
    ;; Draw boss eyes.
    ldy #eEye::Left  ; param: eye
    jsr FuncA_Objects_GardenBoss_DrawEye
    ldy #eEye::Right  ; param: eye
    jsr FuncA_Objects_GardenBoss_DrawEye
    @done:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for one of the boss's eyes.
;;; @param Y Which eEye to draw.
.PROC FuncA_Objects_GardenBoss_DrawEye
    ldx _PlatformIndex_u8_arr, y  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves Y
    tya  ; eEye value
    tax  ; eEye value
    lda #kPaletteObjBossEye  ; param: flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @done
    ;; Determine if the eye should be flashing red this frame.
    lda Ram_RoomState + sState::BossEyeFlash_u8_arr2, x
    beq @noFlash
    lda Zp_FrameCounter_u8
    and #$02
    beq @noFlash
    lda #$10
    @noFlash:
    sta Zp_Tmp1_byte  ; flash bit
    ;; Compute the first tile ID based on the current eye openness.
    lda Ram_RoomState + sState::BossEyeOpen_u8_arr2, x
    div #2
    and #$fe
    ora Zp_Tmp1_byte  ; flash bit
    add #kTileIdObjPlantEyeFirst
    ;; Set tile IDs:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1  ; carry bit will already be clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    ;; Set flags:
    lda #kPaletteObjBossEye | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @done:
    rts
_PlatformIndex_u8_arr:
    D_ENUM eEye
    d_byte Left,  kLeftEyePlatformIndex
    d_byte Right, kRightEyePlatformIndex
    D_END
.ENDPROC

;;;=========================================================================;;;
