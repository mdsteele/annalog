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
.INCLUDE "../boss.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../irq.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/cannon.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../scroll.inc"
.INCLUDE "boss_garden.inc"

.IMPORT DataA_Room_Garden_sTileset
.IMPORT FuncA_Machine_CannonTick
.IMPORT FuncA_Machine_CannonTryAct
.IMPORT FuncA_Machine_CannonTryMove
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_DrawBoss
.IMPORT FuncA_Objects_DrawCannonMachine
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_FindGrenadeActor
.IMPORT FuncA_Room_InitBoss
.IMPORT FuncA_Room_MachineCannonReset
.IMPORT FuncA_Room_ResetLever
.IMPORT FuncA_Room_TickBoss
.IMPORT Func_AckIrqAndLatchWindowFromParam3
.IMPORT Func_AckIrqAndSetLatch
.IMPORT Func_DivMod
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorProjFireball
.IMPORT Func_InitActorProjSpike
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MachineCannonReadRegY
.IMPORT Func_Noop
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_ShakeRoom
.IMPORT Ppu_ChrBgAnimA0
.IMPORT Ppu_ChrObjBoss1
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Camera_bScroll
.IMPORTZP Zp_Chr0cBank_u8
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_NextIrq_int_ptr
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The device indices for the levers in this room.
kLeverLeftDeviceIndex = 3
kLeverRightDeviceIndex = 4

;;; The machine index for the BossGardenCannon machine.
kCannonMachineIndex = 0
;;; The platform index for the BossGardenCannon machine.
kCannonPlatformIndex = 2
;;; Initial position for grenades shot from the cannon.
kCannonGrenadeInitPosX = $28
kCannonGrenadeInitPosY = $78

;;;=========================================================================;;;

;;; How many grenade hits are needed on each eye to defeat the boss.
kBossInitHealthPerEye = 4

;;; How many frames the boss waits, after you first enter the room, before
;;; taking action.
kBossInitCooldown = 120
;;; How many frames to wait between spikes when the boss is in Angry mode.
kBossAngrySpikeCooldown = 15
;;; How many frames to wait between fireballs when the boss is in Shoot mode.
kBossShootFireballCooldown = 60
;;; How many frames to wait between fireballs when the boss is in Spray mode.
kBossSprayFireballCooldown = 15

;;; How many spikes to drop when the boss is in Angry mode.
kBossAngryNumSpikes = 3

;;; How many frames it takes for an eye to fully open or close.
kBossEyeOpenFrames = 20

;;; The platform indices for the boss's two eyes.
kLeftEyePlatformIndex = 0
kRightEyePlatformIndex = 1
;;; The platform index for the boss's thorny vines.
kThornsPlatformIndex = 3
;;; The platform index for the boss's body.
kBossBodyPlatformIndex = 4

;;; The X/Y positions of the centers of the boss's two eyes.
kBossLeftEyeCenterX  = $68
kBossLeftEyeCenterY  = $58
kBossRightEyeCenterX = $98
kBossRightEyeCenterY = $78

;;; The OBJ palette number used for the eyes of the boss.
kPaletteObjBossEye = 1

;;; The room pixel Y-positions for the top and bottom of the zone that the boss
;;; appears within.
kBossZoneTopY    = $18
kBossZoneBottomY = $88

;;;=========================================================================;;;

;;; Modes that the boss in this room can be in.
.ENUM eBossMode
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
    LeverLeft_u8  .byte
    LeverRight_u8 .byte
    ;; Timer that ticks down each frame when nonzero.  Used to time transitions
    ;; between boss modes.
    BossCooldown_u8 .byte
    ;; What mode the boss is in.
    Current_eBossMode .byte
    ;; How many more projectiles (fireballs or spikes) to shoot before changing
    ;; modes.
    BossProjCount_u8 .byte
    ;; How many more Shoot cycles the boss must go through before the next
    ;; Spray can happen.
    BossShootsUntilNextSpray_u8 .byte
    ;; Which eye is "active".
    BossActive_eEye .byte
    ;; How many more grenade hits are needed on each eye before the boss dies,
    ;; indexed by eEye.
    BossEyeHealth_u8_arr2 .res 2
    ;; How open each of the eyes are, from 0 (closed) to kBossEyeOpenFrames
    ;; (open), indexed by eEye.
    BossEyeOpen_u8_arr2 .res 2
    ;; If nonzero, this is how many more frames to flash each eye.  This gets
    ;; set when the boss gets hurt in that eye.
    BossEyeFlash_u8_arr2 .res 2
    ;; Counter used for setting BG animation bank (instead of
    ;; Zp_FrameCounter_u8).  This gets incremented/decremented in the TickRoom
    ;; function.
    BossThornCounter_u8 .byte
    ;; Timer that counts down in the TickRoom function to make the thorns
    ;; periodically move.
    BossThornTimer_u8 .byte
    ;; When nonzero, this is how many more frames the thorns should spend
    ;; moving quickly.  This gets set when the boss gets hurt.
    BossThornHurt_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Boss"

.EXPORT DataC_Boss_Garden_sRoom
.PROC DataC_Boss_Garden_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, bRoom::Unsafe | bRoom::Tall | eArea::Garden
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 7
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss1)
    d_addr Tick_func_ptr, FuncC_Boss_Garden_TickRoom
    d_addr Draw_func_ptr, FuncA_Objects_DrawBoss
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncC_Boss_Garden_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/boss_garden.room"
    .assert * - :- = 16 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kCannonMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossGardenCannon
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::CannonRight
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0e
    d_byte RegNames_u8_arr4, "L", "R", 0, "Y"
    d_byte MainPlatform_u8, kCannonPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Boss_GardenCannon_ReadReg
    d_addr WriteReg_func_ptr, FuncC_Boss_GardenCannon_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_CannonTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CannonTryAct
    d_addr Tick_func_ptr, FuncA_Machine_CannonTick
    d_addr Draw_func_ptr, FuncA_Objects_DrawCannonMachine
    d_addr Reset_func_ptr, FuncC_Boss_GardenCannon_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLeftEyePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kBlockWidthPx
    d_byte HeightPx_u8, kBlockHeightPx
    d_word Left_i16, kBossLeftEyeCenterX - kTileWidthPx
    d_word Top_i16,  kBossLeftEyeCenterY - kTileHeightPx
    D_END
    .assert * - :- = kRightEyePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kBlockWidthPx
    d_byte HeightPx_u8, kBlockHeightPx
    d_word Left_i16, kBossRightEyeCenterX - kTileWidthPx
    d_word Top_i16,  kBossRightEyeCenterY - kTileHeightPx
    D_END
    .assert * - :- = kCannonPlatformIndex * .sizeof(sPlatform), error
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
    .assert * - :- = kBossBodyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $70
    d_byte HeightPx_u8, $38
    d_word Left_i16,  $0068
    d_word Top_i16,   $0030
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kBossDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 7
    d_byte Target_u8, eRoom::GardenTower
    D_END
    .assert * - :- = kBossUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be an upgrade
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 8
    d_byte Target_u8, eFlag::UpgradeRam1
    D_END
    .assert * - :- = kBossBreakerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be a breaker
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 5
    d_byte Target_u8, eFlag::BreakerGarden
    D_END
    .assert * - :- = kLeverLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 3
    d_byte Target_u8, sState::LeverLeft_u8
    D_END
    .assert * - :- = kLeverRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 10
    d_byte Target_u8, sState::LeverRight_u8
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

.PROC FuncC_Boss_Garden_sBoss
    D_STRUCT sBoss
    d_byte Boss_eFlag, eFlag::BossGarden
    d_byte BodyPlatform_u8, kBossBodyPlatformIndex
    d_addr Tick_func_ptr, FuncC_Boss_Garden_TickBoss
    d_addr Draw_func_ptr, FuncA_Objects_BossGarden_DrawBoss
    D_END
.ENDPROC

.PROC FuncC_Boss_Garden_EnterRoom
_LockScrolling:
    lda #0
    sta Zp_RoomScrollY_u8
    lda #bScroll::LockVert
    sta Zp_Camera_bScroll
_InitBoss:
    ldax #FuncC_Boss_Garden_sBoss  ; param: sBoss ptr
    jsr FuncA_Room_InitBoss  ; sets Z if boss is alive
    beq _BossIsAlive
_BossIsDead:
    ;; Remove the boss's thorns.
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kThornsPlatformIndex
    rts
_BossIsAlive:
    lda #kBossInitHealthPerEye
    sta Zp_RoomState + sState::BossEyeHealth_u8_arr2 + 0
    sta Zp_RoomState + sState::BossEyeHealth_u8_arr2 + 1
    lda #kBossInitCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #eBossMode::Waiting
    sta Zp_RoomState + sState::Current_eBossMode
    rts
.ENDPROC

;;; Room tick function for the BossGarden room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Garden_TickRoom
    .assert eBossMode::Dead = 0, error
    lda Zp_RoomState + sState::Current_eBossMode  ; param: zero if boss is dead
    jmp FuncA_Room_TickBoss
.ENDPROC

;;; Performs per-frame upates for the boss (if it's still alive).
.PROC FuncC_Boss_Garden_TickBoss
    jsr FuncC_Boss_Garden_CheckForGrenadeHit
    ;; Tick eyes.
    ldx #eEye::Left  ; param: eye to tick
    jsr FuncC_Boss_Garden_TickEye
    ldx #eEye::Right  ; param: eye to tick
    jsr FuncC_Boss_Garden_TickEye
_TickThorns:
    ;; Move thorns quickly when hurt.
    lda Zp_RoomState + sState::BossThornHurt_u8
    beq @noHurt
    dec Zp_RoomState + sState::BossThornHurt_u8
    dec Zp_RoomState + sState::BossThornCounter_u8
    dec Zp_RoomState + sState::BossThornCounter_u8
    jmp @done
    @noHurt:
    ;; Periodically move thorns:
    dec Zp_RoomState + sState::BossThornTimer_u8
    bpl @noWrap
    lda #$40
    sta Zp_RoomState + sState::BossThornTimer_u8
    @noWrap:
    lda Zp_RoomState + sState::BossThornTimer_u8
    cmp #$18
    bge @done
    inc Zp_RoomState + sState::BossThornCounter_u8
    @done:
_CoolDown:
    ;; Wait for cooldown to expire.
    dec Zp_RoomState + sState::BossCooldown_u8
    beq _CheckMode
    rts
_CheckMode:
    ;; Branch based on the current boss mode.
    ldy Zp_RoomState + sState::Current_eBossMode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eBossMode
    d_entry table, Dead,    Func_Noop
    d_entry table, Waiting, FuncC_Boss_Garden_TickBossWaiting
    d_entry table, Angry,   FuncC_Boss_Garden_TickBossAngry
    d_entry table, Shoot,   FuncC_Boss_Garden_TickBossShoot
    d_entry table, Spray,   FuncC_Boss_Garden_TickBossSpray
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs a state transition for the boss when it's in Spray mode and the
;;; cooldown has expired.
.PROC FuncC_Boss_Garden_TickBossSpray
    jsr Func_GetRandomByte  ; returns A
    ldy #11  ; param: divisor
    jsr Func_DivMod  ; returns remainder in A
    add #2  ; param: column to shoot at
    ldy Zp_RoomState + sState::BossActive_eEye  ; param: eye to shoot from
    jsr FuncC_Boss_Garden_ShootFireballAtColumn
    ;; Decrement the projectile counter; if it reaches zero, return to waiting
    ;; mode.
    dec Zp_RoomState + sState::BossProjCount_u8
    jeq FuncC_Boss_Garden_StartWaiting
    ;; Otherwise, set the cooldown for the next fireball.
    lda #kBossSprayFireballCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    rts
.ENDPROC

;;; Performs a state transition for the boss when it's in Shoot mode and the
;;; cooldown has expired.
.PROC FuncC_Boss_Garden_TickBossShoot
    ldy Zp_RoomState + sState::BossActive_eEye  ; param: eye to shoot from
    jsr FuncC_Boss_Garden_ShootFireballAtAvatar
    ;; Decrement the projectile counter; if it reaches zero, return to waiting
    ;; mode.
    dec Zp_RoomState + sState::BossProjCount_u8
    jeq FuncC_Boss_Garden_StartWaiting
    ;; Otherwise, set the cooldown for the next fireball.
    lda #kBossShootFireballCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    rts
.ENDPROC

;;; Performs a state transition for the boss when it's in Angry mode and the
;;; cooldown has expired.
.PROC FuncC_Boss_Garden_TickBossAngry
    jsr FuncC_Boss_Garden_DropSpike
    ;; Decrement the projectile counter; if it reaches zero, return to waiting
    ;; mode.
    dec Zp_RoomState + sState::BossProjCount_u8
    jeq FuncC_Boss_Garden_StartWaiting
    ;; Otherwise, set the cooldown for the next spike.
    lda #kBossAngrySpikeCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    rts
.ENDPROC

;;; Performs a state transition for the boss when it's in Waiting mode and the
;;; cooldown has expired.
.PROC FuncC_Boss_Garden_TickBossWaiting
_SetActiveEye:
    ;; If one of the eyes is at zero health, pick the other eye.
    lda Zp_RoomState + sState::BossEyeHealth_u8_arr2 + 1
    beq @setActiveEye
    lda Zp_RoomState + sState::BossEyeHealth_u8_arr2 + 0
    bne @randomEye
    lda #1
    bne @setActiveEye  ; unconditional
    ;; Otherwise, pick a random eye.
    @randomEye:
    jsr Func_GetRandomByte  ; returns A
    and #$01
    @setActiveEye:
    sta Zp_RoomState + sState::BossActive_eEye
_ChooseNewBossMode:
    ;; If the boss is at high health, switch to Shoot mode.
    lda Zp_RoomState + sState::BossEyeHealth_u8_arr2 + 0
    add Zp_RoomState + sState::BossEyeHealth_u8_arr2 + 1
    cmp #kBossInitHealthPerEye + 1
    bge _StartShootMode
    ;; The boss is at low health.  If BossShootsUntilNextSpray_u8 is zero,
    ;; switch to Spray mode.  Otherwise, decrement it and switch to Shoot mode.
    lda Zp_RoomState + sState::BossShootsUntilNextSpray_u8
    beq _StartSprayMode
    dec Zp_RoomState + sState::BossShootsUntilNextSpray_u8
    jmp _StartShootMode
_StartSprayMode:
    lda #7
    sta Zp_RoomState + sState::BossProjCount_u8
    ;; Set BossShootsUntilNextSpray_u8 to a random value from 2-3.
    jsr Func_GetRandomByte  ; returns A
    and #$01
    add #2
    sta Zp_RoomState + sState::BossShootsUntilNextSpray_u8
    lda #eBossMode::Spray
    .assert eBossMode::Spray <> 0, error
    bne _SetBossMode  ; unconditional
_StartShootMode:
    ;; Choose a random number of fireballs to shoot, from 4-7.
    jsr Func_GetRandomByte  ; returns A
    and #$03
    add #4
    sta Zp_RoomState + sState::BossProjCount_u8
    lda #eBossMode::Shoot
_SetBossMode:
    sta Zp_RoomState + sState::Current_eBossMode
    ;; Initialize the cooldown.
    lda #kBossEyeOpenFrames
    sta Zp_RoomState + sState::BossCooldown_u8
    rts
.ENDPROC

;;; Opens or closes the specified boss eye, depending on the boss mode.
;;; @param X Which eEye to update.
.PROC FuncC_Boss_Garden_TickEye
    lda Zp_RoomState + sState::BossEyeFlash_u8_arr2, x
    beq @noFlash
    dec Zp_RoomState + sState::BossEyeFlash_u8_arr2, x
    @noFlash:
_CheckIfOpenOrClosed:
    lda Zp_RoomState + sState::Current_eBossMode
    cmp #eBossMode::Shoot
    .assert eBossMode::Spray > eBossMode::Shoot, error
    blt _Close
    cpx Zp_RoomState + sState::BossActive_eEye
    bne _Close
_Open:
    lda Zp_RoomState + sState::BossEyeOpen_u8_arr2, x
    cmp #kBossEyeOpenFrames
    bge @done
    inc Zp_RoomState + sState::BossEyeOpen_u8_arr2, x
    @done:
    rts
_Close:
    lda Zp_RoomState + sState::BossEyeOpen_u8_arr2, x
    beq @done
    dec Zp_RoomState + sState::BossEyeOpen_u8_arr2, x
    @done:
    rts
.ENDPROC

;;; Shoots a fireball from the specified eye, towards the player avatar.
;;; @param Y Which eEye to shoot from.
.PROC FuncC_Boss_Garden_ShootFireballAtAvatar
    lda Zp_AvatarPosX_i16 + 0
    div #kBlockWidthPx
    .assert * = FuncC_Boss_Garden_ShootFireballAtColumn, error, "fallthrough"
.ENDPROC

;;; Shoots a fireball from the specified eye, towards the specified room block
;;; column.
;;; @param A Which room block column to shoot at.
;;; @param Y Which eEye to shoot from.
.PROC FuncC_Boss_Garden_ShootFireballAtColumn
    sta T0  ; room block column
    ;; Shoot a fireball.
    jsr Func_FindEmptyActorSlot  ; preserves Y and T0+, returns C and X
    bcs @done
    ;; Initialize fireball position based on which eye we're shooting from.
    lda #0
    sta Ram_ActorPosX_i16_1_arr, x
    sta Ram_ActorPosY_i16_1_arr, x
    lda _FireballPosY_u8_arr2, y
    sta Ram_ActorPosY_i16_0_arr, x
    lda _FireballPosX_u8_arr2, y
    sta Ram_ActorPosX_i16_0_arr, x
    ;; Choose fireball angle based on target column.
    lda T0  ; room block column
    mul #2
    ora Zp_RoomState + sState::BossActive_eEye
    tay
    lda _FireballAngle_u8_arr2_arr, y  ; param: aim angle
    jsr Func_InitActorProjFireball
    ;; TODO: play a sound
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
    .byte 64,  64
    .byte 64,  64
    .byte 91, 112  ; leftmost side of room
    .byte 84, 108  ; left lever
    .byte 76,  96  ; leftmost side of lowest floor
    .byte 69,  92
    .byte 64,  84  ; below left eye
    .byte 59,  80  ; door
    .byte 52,  72
    .byte 47,  64  ; below right eye
    .byte 40,  56  ; right lever
    .byte 36,  44
    .byte 28,  32  ; console
    .byte 16,  12
.ENDPROC

;;; Drops a spike from a random horizontal position.
.PROC FuncC_Boss_Garden_DropSpike
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
.PROC FuncC_Boss_Garden_StartWaiting
    lda #eBossMode::Waiting
    sta Zp_RoomState + sState::Current_eBossMode
    jsr Func_GetRandomByte  ; preserves X, returns A
    and #$3f
    ora #$40
    sta Zp_RoomState + sState::BossCooldown_u8
    rts
.ENDPROC

;;; Checks if a grenade has hit a boss eye; if so, explodes the grenade and
;;; makes the boss react accordingly.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Garden_CheckForGrenadeHit
    ;; Find the actor index for the grenade in flight (if any).  If we don't
    ;; find one, then we're done.
    jsr FuncA_Room_FindGrenadeActor  ; returns C and X
    bcs _Done
_CheckEyes:
    ;; Check if the grenade hit either eye.
    jsr Func_SetPointToActorCenter  ; preserves X
    ldy #kLeftEyePlatformIndex
    jsr Func_IsPointInPlatform  ; preserves X and Y, returns C
    bcs _HitEye
    ldy #kRightEyePlatformIndex
    jsr Func_IsPointInPlatform  ; preserves X and Y, returns C
    bcs _HitEye
    rts
_HitEye:
    ;; At this point, X is the grenade actor index, and Y is the platform index
    ;; of the eye that was hit.  Assert that we can use that platform index as
    ;; an eEye value.
    .assert kLeftEyePlatformIndex = eEye::Left, error
    .assert kRightEyePlatformIndex = eEye::Right, error
    ;; Check if the hit eye is open or closed.
    lda Zp_RoomState + sState::BossEyeOpen_u8_arr2, y
    cmp #kBossEyeOpenFrames / 2
    bge _HitOpenEye
_HitClosedEye:
    ;; If the hit eye is closed, shake the room and switch the boss to Angry
    ;; mode.
    lda #kBossAngrySpikeCooldown * kBossAngryNumSpikes  ; param: num frames
    jsr Func_ShakeRoom  ; preserves X
    lda #eBossMode::Angry
    sta Zp_RoomState + sState::Current_eBossMode
    .assert eBossMode::Angry = 2, error
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #kBossAngryNumSpikes
    sta Zp_RoomState + sState::BossProjCount_u8
    bne _ExplodeGrenade  ; unconditional
_HitOpenEye:
    ;; If the hit eye is open, deal damage to that eye (assuming that eye's
    ;; health isn't somehow already zero).
    lda Zp_RoomState + sState::BossEyeHealth_u8_arr2, y
    beq @doneDamage
    sub #1
    sta Zp_RoomState + sState::BossEyeHealth_u8_arr2, y
    @doneDamage:
    ;; If the boss's total health is now zero, mark the boss as dead.
    lda Zp_RoomState + sState::BossEyeHealth_u8_arr2 + 0
    ora Zp_RoomState + sState::BossEyeHealth_u8_arr2 + 1
    bne @bossIsStillAlive
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kThornsPlatformIndex
    lda #eBossMode::Dead
    sta Zp_RoomState + sState::Current_eBossMode
    .assert eBossMode::Dead = 0, error
    beq _ExplodeGrenade  ; unconditional
    ;; Otherwise, put the boss into waiting mode.
    @bossIsStillAlive:
    lda #kBossEyeOpenFrames
    sta Zp_RoomState + sState::BossEyeFlash_u8_arr2, y
    lda #$10
    sta Zp_RoomState + sState::BossThornHurt_u8
    jsr FuncC_Boss_Garden_StartWaiting  ; preserves X
_ExplodeGrenade:
    ;; At this point, X is still the grenade actor index.
    jsr Func_InitActorSmokeExplosion
    ;; TODO: play a sound for hitting the eye
_Done:
    rts
.ENDPROC

.PROC FuncC_Boss_GardenCannon_ReadReg
    cmp #$c
    beq @readL
    cmp #$d
    beq @readR
    @readY:
    jmp Func_MachineCannonReadRegY
    @readL:
    lda Zp_RoomState + sState::LeverLeft_u8
    rts
    @readR:
    lda Zp_RoomState + sState::LeverRight_u8
    rts
.ENDPROC

.PROC FuncC_Boss_GardenCannon_WriteReg
    cpx #$d
    beq _WriteR
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_GardenCannon_Reset
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    ldx #kLeverRightDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    jsr FuncA_Room_MachineCannonReset
    ;; If the boss is currently shooting/spraying, switch to waiting mode (to
    ;; avoid the player cheesing by reprogramming the machine every time the
    ;; boss opens an eye).
    lda Zp_RoomState + sState::Current_eBossMode
    cmp #eBossMode::Shoot
    .assert eBossMode::Spray > eBossMode::Shoot, error
    blt @done
    jmp FuncC_Boss_Garden_StartWaiting
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws the boss.
.PROC FuncA_Objects_BossGarden_DrawBoss
_DrawBossEyes:
    ldx #eEye::Left  ; param: eye
    jsr FuncA_Objects_BossGarden_DrawEye  ; preserves X
    .assert eEye::Right = 1 + eEye::Left, error
    inx  ; param: eye
    jsr FuncA_Objects_BossGarden_DrawEye
_AnimateThorns:
    lda Zp_RoomState + sState::BossThornCounter_u8
    div #4
    and #$07
    add #<.bank(Ppu_ChrBgAnimA0)
    sta Zp_Chr0cBank_u8
_SetUpIrq:
    ;; Compute the IRQ latch value to set between the bottom of the boss's zone
    ;; and the top of the window (if any), and set that as Param3_byte.
    lda <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    sub #kBossZoneBottomY
    add Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Param3_byte)  ; window latch
    ;; Set up our own sIrq struct to handle boss movement.
    lda #kBossZoneTopY - 1
    sub Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    ldax #Int_BossGardenZoneTopIrq
    stax <(Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr)
    rts
.ENDPROC

;;; Allocates and populates OAM slots for one of the boss's eyes.
;;; @param X Which eEye to draw.
;;; @preserve X
.PROC FuncA_Objects_BossGarden_DrawEye
    ;; Assert that we can use the eEye value as a platform index.
    .assert kLeftEyePlatformIndex = eEye::Left, error
    .assert kRightEyePlatformIndex = eEye::Right, error
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile  ; preserves X
    lda #kPaletteObjBossEye  ; param: flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @done
    ;; Determine if the eye should be flashing red this frame.
    lda Zp_RoomState + sState::BossEyeFlash_u8_arr2, x
    beq @noFlash
    lda Zp_FrameCounter_u8
    and #$02
    beq @noFlash
    lda #$10
    @noFlash:
    sta T0  ; flash bit
    ;; Compute the first tile ID based on the current eye openness.
    lda Zp_RoomState + sState::BossEyeOpen_u8_arr2, x
    div #2
    and #$fe
    ora T0  ; flash bit
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
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top of the boss's zone in the
;;; BossGarden room.  Sets the vertical scroll so as to make the thorn terrain
;;; visible.
.PROC Int_BossGardenZoneTopIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Set up the
    ;; next IRQ.
    lda #kBossZoneBottomY - kBossZoneTopY - 1  ; param: latch value
    jsr Func_AckIrqAndSetLatch  ; preserves Y
    ldax #Int_BossGardenZoneBottomIrq
    stax Zp_NextIrq_int_ptr
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #6  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the lower
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #3 << 2  ; nametable number << 2
    sta Hw_PpuAddr_w2
    lda #kBossZoneTopY
    sta Hw_PpuScroll_w2
    and #$38
    mul #4
    ;; We should now be in the second HBlank.
    stx Hw_PpuScroll_w2  ; new scroll-X value (zero)
    sta Hw_PpuAddr_w2  ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;; HBlank IRQ handler function for the bottom of the boss's zone in the
;;; BossGarden room.  Sets the scroll so as to make the bottom of the room look
;;; normal.
.PROC Int_BossGardenZoneBottomIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ and prepare for the next one.
    jsr Func_AckIrqAndLatchWindowFromParam3  ; preserves Y
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #7  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the upper
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #0 << 2  ; nametable number << 2
    sta Hw_PpuAddr_w2
    lda #kBossZoneBottomY  ; new scroll-Y value
    sta Hw_PpuScroll_w2
    lda #(kBossZoneBottomY & $38) << 2
    ;; We should now be in the second HBlank (and X is zero).
    stx Hw_PpuScroll_w2  ; new scroll-X value (zero)
    sta Hw_PpuAddr_w2    ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;;=========================================================================;;;
