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

.IMPORT DataA_Pause_GardenAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_GardenAreaName_u8_arr
.IMPORT DataA_Room_Garden_sTileset
.IMPORT FuncA_Objects_DrawCannonMachine
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetRandomByte
.IMPORT Func_InitFireballActor
.IMPORT Func_InitGrenadeActor
.IMPORT Func_InitSmokeActor
.IMPORT Func_InitSpikeActor
.IMPORT Func_LockDoorDevice
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MarkRoomSafe
.IMPORT Func_Noop
.IMPORT Func_UnlockDoorDevice
.IMPORT Ppu_ChrUpgrade
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_RoomState
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_RoomIsSafe_bool
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The actor index for grenades launched by the GardenBossCannon machine.
kGrenadeActorIndex = 0
;;; The actor index for the puff of smoke created when the upgrade appears.
kSmokeActorIndex = 1

;;; The device index for the upgrade that appears when the boss is defeated.
kUpgradeDeviceIndex = 0
;;; The room block row/col where the upgrade will appear.
kUpgradeBlockRow = 6
kUpgradeBlockCol = 10

;;; The device index for the door.
kDoorDeviceIndex = 1

;;; The machine index for the GardenBossCannon machine.
kCannonMachineIndex = 0
;;; The platform index for the GardenBossCannon machine.
kCannonPlatformIndex = 0
;;; Initial position for grenades shot from the cannon.
kCannonGrenadeInitPosX = $28
kCannonGrenadeInitPosY = $78

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
kBossEyeOpenFrames = 24

;;; The first tile ID for the eye animation.
kBossEyeFirstTileId = $a9

;;; The OBJ palette number used for the eyes of the boss.
kBossEyePalette = 0

;;; The X/Y positions of the centers of the boss's two eyes.
kBossLeftEyeCenterX  = $68
kBossLeftEyeCenterY  = $58
kBossRightEyeCenterX = $98
kBossRightEyeCenterY = $78

;;;=========================================================================;;;

;;; Modes that the boss in this room can be in.
.ENUM eBoss
    Dead
    Waiting  ; eyes closed
    Angry    ; eyes closed, dropping spikes
    Shoot    ; active eye open, shooting fireballs one at a time
    Spray    ; active eye open, shooting a wave of fireballs
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

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
    ;; Counts down when nonzero; upon reaching zero, spawns the upgrade.
    SpawnUpgradeTimer_u8 .byte
    ;; The current aim angle of the GardenBossCannon machine (0-255).
    CannonAngle_u8       .byte
    ;; The goal value of the GardenBossCannon machine's Y register; it will
    ;; keep moving until this is reached.
    CannonGoalY_u8       .byte
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
    BossEyesOpen_u8_arr2 .res 2
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
    d_byte MinimapStartCol_u8, 6
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrUpgrade)
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
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/garden_boss.room"
    .assert * - :- = 16 * 16, error
_Machines_sMachine_arr:
    .assert kCannonMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenBossCannon
    d_byte Conduit_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0e
    d_byte RegNames_u8_arr4, "L", "R", 0, "Y"
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, _Cannon_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, _Cannon_TryMove
    d_addr TryAct_func_ptr, _Cannon_TryAct
    d_addr Tick_func_ptr, _Cannon_Tick
    d_addr Draw_func_ptr, FuncA_Objects_GardenBossCannon_Draw
    d_addr Reset_func_ptr, _Cannon_Reset
    D_END
_Platforms_sPlatform_arr:
    .assert kCannonPlatformIndex = 0, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0020
    d_word Top_i16,   $0070
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
    .assert kUpgradeDeviceIndex = 0, error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, kUpgradeBlockRow
    d_byte BlockCol_u8, kUpgradeBlockCol
    d_byte Target_u8, eFlag::UpgradeMaxInstructions0
    D_END
    .assert kDoorDeviceIndex = 1, error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::UnlockedDoor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 6
    d_byte Target_u8, eRoom::GardenTower
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 3
    d_byte Target_u8, sState::LeverLeft_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
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
    .byte eDevice::None
_Cannon_ReadReg:
    cmp #$c
    beq @readL
    cmp #$d
    beq @readR
    @readY:
    lda Ram_RoomState + sState::CannonAngle_u8
    and #$80
    beq @return
    lda #1
    @return:
    rts
    @readL:
    lda Ram_RoomState + sState::LeverLeft_u1
    rts
    @readR:
    lda Ram_RoomState + sState::LeverRight_u1
    rts
_Cannon_TryMove:
    cpx #eDir::Down
    beq @moveDown
    @moveUp:
    ldy Ram_RoomState + sState::CannonGoalY_u8
    bne @error
    iny
    bne @success  ; unconditional
    @moveDown:
    ldy Ram_RoomState + sState::CannonGoalY_u8
    beq @error
    dey
    @success:
    sty Ram_RoomState + sState::CannonGoalY_u8
    lda #kCannonMoveCountdown
    clc  ; clear C to indicate success
    rts
    @error:
    sec  ; set C to indicate failure
    rts
_Cannon_TryAct:
    lda #kCannonGrenadeInitPosX
    sta Ram_ActorPosX_i16_0_arr + kGrenadeActorIndex
    lda #kCannonGrenadeInitPosY
    sta Ram_ActorPosY_i16_0_arr + kGrenadeActorIndex
    lda #0
    sta Ram_ActorPosX_i16_1_arr + kGrenadeActorIndex
    sta Ram_ActorPosY_i16_1_arr + kGrenadeActorIndex
    ldx #kGrenadeActorIndex  ; param: actor index
    lda Ram_RoomState + sState::CannonGoalY_u8  ; param: aim angle (0-1)
    jsr Func_InitGrenadeActor
    lda #kCannonActCountdown
    clc  ; clear C to indicate success
    rts
_Cannon_Tick:
    lda Ram_RoomState + sState::CannonGoalY_u8
    beq @moveDown
    @moveUp:
    lda Ram_RoomState + sState::CannonAngle_u8
    add #$100 / kCannonMoveCountdown
    bcc @setAngle
    jsr Func_MachineFinishResetting
    lda #$ff
    bne @setAngle  ; unconditional
    @moveDown:
    lda Ram_RoomState + sState::CannonAngle_u8
    sub #$100 / kCannonMoveCountdown
    bge @setAngle
    jsr Func_MachineFinishResetting
    lda #0
    @setAngle:
    sta Ram_RoomState + sState::CannonAngle_u8
    rts
_Cannon_Reset:
    lda #0
    sta Ram_RoomState + sState::CannonGoalY_u8
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

;;; Room init function for the GardenBoss room.
.PROC FuncC_Garden_Boss_InitRoom
    ;; Lock the door for now.
    ldx #kDoorDeviceIndex  ; param: device index
    jsr Func_LockDoorDevice
    ;; Hide the upgrade device for now.
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr + kUpgradeDeviceIndex
    ;; If the boss hasn't been defeated yet, then spawn the boss.
    lda Sram_ProgressFlags_arr + (eFlag::BossGarden >> 3)
    and #1 << (eFlag::BossGarden & $07)
    bne _NoBoss
_SpawnBoss:
    sta Zp_RoomIsSafe_bool
    lda #kBossInitHealth
    sta Ram_RoomState + sState::BossHealth_u8
    lda #kBossInitCooldown
    sta Ram_RoomState + sState::BossCooldown_u8
    lda #eBoss::Waiting
    sta Ram_RoomState + sState::BossMode_eBoss
    rts
_NoBoss:
    ;; If the boss has been defeated, but the upgrade hasn't been collected
    ;; yet, then set a timer to spawn the upgrade.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeMaxInstructions0 >> 3)
    and #1 << (eFlag::UpgradeMaxInstructions0 & $07)
    bne @playerHasUpgrade
    lda #30  ; 0.5 seconds
    sta Ram_RoomState + sState::SpawnUpgradeTimer_u8
    rts
    @playerHasUpgrade:
    ;; If the boss has been defeated and the upgrade has been collected, but
    ;; the conduit hasn't been activated yet, then spawn the conduit lever.
    lda Sram_ProgressFlags_arr + (eFlag::ConduitGarden >> 3)
    and #1 << (eFlag::ConduitGarden & $07)
    bne @conduitIsActivated
    ;; TODO: spawn conduit lever
    @conduitIsActivated:
    ;; If the conduit has already been activated, unlock the door.
    ldx #kDoorDeviceIndex  ; param: device index
    jmp Func_UnlockDoorDevice
.ENDPROC

;;; Room tick function for the GardenBoss room.
.PROC FuncC_Garden_Boss_TickRoom
_SpawnUpgrade:
    ;; If the timer is nonzero, count it down, and spawn the upgrade at zero.
    lda Ram_RoomState + sState::SpawnUpgradeTimer_u8
    beq @doneUpgrade
    dec Ram_RoomState + sState::SpawnUpgradeTimer_u8
    bne @doneUpgrade
    ;; Show the upgrade device and animate it.
    lda #eDevice::Upgrade
    sta Ram_DeviceType_eDevice_arr + kUpgradeDeviceIndex
    lda #kUpgradeDeviceAnimStart
    sta Ram_DeviceAnim_u8_arr + kUpgradeDeviceIndex
    ;; TODO: play a sound
    ;; Create a puff of smoke over the upgrade device.
    lda #kUpgradeBlockCol * kBlockWidthPx + kBlockWidthPx / 2
    sta Ram_ActorPosX_i16_0_arr + kSmokeActorIndex
    lda #kUpgradeBlockRow * kBlockHeightPx + kBlockHeightPx / 2
    sta Ram_ActorPosY_i16_0_arr + kSmokeActorIndex
    lda #0
    sta Ram_ActorPosX_i16_1_arr + kSmokeActorIndex
    sta Ram_ActorPosY_i16_1_arr + kSmokeActorIndex
    ldx #kSmokeActorIndex  ; param: actor index
    jsr Func_InitSmokeActor
    @doneUpgrade:
_CheckIfBossDead:
    lda Ram_RoomState + sState::BossMode_eBoss
    .assert eBoss::Dead = 0, error
    bne @bossAlive
    rts
    @bossAlive:
_CheckForGrenadeHit:
    ;; Check if there's a grenade in flight.  If not, we're done.
    lda Ram_ActorType_eActor_arr + kGrenadeActorIndex
    cmp #eActor::Grenade
    bne @done
    ;; Check which eye the grenade is near vertically.
    lda Ram_ActorPosY_i16_0_arr + kGrenadeActorIndex
    cmp #kBossLeftEyeCenterY + 6
    bge @grenadeIsLow
    @grenadeIsHigh:
    lda #kBossLeftEyeCenterX
    ldx #eEye::Left
    .assert eEye::Left = 0, error
    beq @checkPosX  ; unconditional
    @grenadeIsLow:
    lda #kBossRightEyeCenterX
    ldx #eEye::Right
    @checkPosX:
    ;; Check if the grenade has hit an eye yet.  If not, we're done.
    cmp Ram_ActorPosX_i16_0_arr + kGrenadeActorIndex
    bge @done
    ;; Check if the hit eye is open or closed.
    lda Ram_RoomState + sState::BossEyesOpen_u8_arr2, x
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
    ;; If the boss's health is now zero, kill the boss.
    ;; TODO: make a death animation, then spawn upgrade
    jsr Func_MarkRoomSafe
    lda #eBoss::Dead
    sta Ram_RoomState + sState::BossMode_eBoss
    .assert eBoss::Dead = 0, error
    beq @explode  ; unconditional
    ;; Otherwise, put the boss into waiting mode.
    @bossIsStillAlive:
    ;; TODO: make a hurt animation
    jsr FuncC_Garden_Boss_StartWaiting
    ;; Explode the grenade.
    @explode:
    ;; TODO: play a sound
    ldx #kGrenadeActorIndex
    jsr Func_InitSmokeActor
    @done:
_BossEyes:
    ldx #eEye::Left
    jsr FuncC_Garden_Boss_TickEye
    ldx #eEye::Right
    jsr FuncC_Garden_Boss_TickEye
_BossCooldown:
    dec Ram_RoomState + sState::BossCooldown_u8
    beq _BossCheckMode
    rts
_BossCheckMode:
    lda Ram_RoomState + sState::BossMode_eBoss
    cmp #eBoss::Angry
    beq _BossAngry
    cmp #eBoss::Shoot
    beq _BossShoot
    cmp #eBoss::Waiting
    beq _BossWaiting
_BossSpray:
    ;; TODO: Shoot a spray of fireballs, then return to Waiting mode.
_BossShoot:
    ;; Shoot a fireball.
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @doneFireball
    ;; Initialize fireball position based on which eye we're shooting from.
    lda #0
    sta Ram_ActorPosX_i16_1_arr, x
    sta Ram_ActorPosY_i16_1_arr, x
    ldy Ram_RoomState + sState::BossActive_eEye
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
    jsr Func_InitFireballActor
    @doneFireball:
    ;; Decrement the projectile counter; if it reaches zero, return to waiting
    ;; mode.
    dec Ram_RoomState + sState::BossProjCount_u8
    jeq FuncC_Garden_Boss_StartWaiting
    ;; Otherwise, set the cooldown for the next fireball.
    lda #kBossShootFireballCooldown
    sta Ram_RoomState + sState::BossCooldown_u8
    rts
_BossAngry:
    ;; Drop a spike from a random location.
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @doneSpike
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
    jsr Func_InitSpikeActor
    @doneSpike:
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
_SpikePosY_u8_arr:
    .byte $50, $50, $50, $50, $50, $50, $60, $70, $70, $80, $80, $80, $80, $80
.ENDPROC

;;; Opens or closes the specified boss eye, depending on the boss mode.
;;; @param X Which eEye to update.
;;; @preserve X
.PROC FuncC_Garden_Boss_TickEye
    lda Ram_RoomState + sState::BossMode_eBoss
    cmp #eBoss::Shoot
    .assert eBoss::Spray > eBoss::Shoot, error
    blt _Close
    cpx Ram_RoomState + sState::BossActive_eEye
    bne _Close
_Open:
    lda Ram_RoomState + sState::BossEyesOpen_u8_arr2, x
    cmp #kBossEyeOpenFrames
    bge @done
    inc Ram_RoomState + sState::BossEyesOpen_u8_arr2, x
    @done:
    rts
_Close:
    lda Ram_RoomState + sState::BossEyesOpen_u8_arr2, x
    beq @done
    dec Ram_RoomState + sState::BossEyesOpen_u8_arr2, x
    @done:
    rts
.ENDPROC

;;; Makes the boss enter waiting mode for a random amount of time (between
;;; about 1-2 seconds).
.PROC FuncC_Garden_Boss_StartWaiting
    lda #eBoss::Waiting
    sta Ram_RoomState + sState::BossMode_eBoss
    jsr Func_GetRandomByte  ; returns A
    and #$3f
    ora #$40
    sta Ram_RoomState + sState::BossCooldown_u8
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
    ldx #eEye::Left
    jsr FuncA_Objects_GardenBoss_DrawEye
    ldx #eEye::Right
    jsr FuncA_Objects_GardenBoss_DrawEye
    @done:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for one of the boss's eyes.
;;; @param X Which eEye to draw.
;;; @preserve X
.PROC FuncA_Objects_GardenBoss_DrawEye
    ldy Zp_OamOffset_u8
    tya
    add #.sizeof(sObj) * 2
    sta Zp_OamOffset_u8
    ;; Set X-positions:
    lda _PosX_u8_arr, x
    sub Zp_RoomScrollX_u16 + 0
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    sub #kTileWidthPx
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    ;; Set Y-positions:
    lda _PosY_u8_arr, x
    sub Zp_RoomScrollY_u8
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    ;; Set tile IDs:
    lda Ram_RoomState + sState::BossEyesOpen_u8_arr2, x
    div #4
    add #kBossEyeFirstTileId
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    ;; Set flags:
    lda #kBossEyePalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    ora #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    rts
_PosX_u8_arr:
    D_ENUM eEye
    d_byte Left,  kBossLeftEyeCenterX
    d_byte Right, kBossRightEyeCenterX
    D_END
_PosY_u8_arr:
    D_ENUM eEye
    d_byte Left,  kBossLeftEyeCenterY  - 5
    d_byte Right, kBossRightEyeCenterY - 5
    D_END
.ENDPROC

;;; Allocates and populates OAM slots for the GardenBossCannon machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.PROC FuncA_Objects_GardenBossCannon_Draw
    ldx #kCannonPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx Ram_RoomState + sState::CannonAngle_u8  ; param: aim angle
    ldy #0  ; param: horz flip
    jmp FuncA_Objects_DrawCannonMachine
.ENDPROC

;;;=========================================================================;;;
