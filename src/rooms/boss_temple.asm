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
.INCLUDE "../actors/blood.inc"
.INCLUDE "../audio.inc"
.INCLUDE "../boss.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../irq.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/minigun.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../music.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../sample.inc"
.INCLUDE "../window.inc"
.INCLUDE "boss_temple.inc"

.IMPORT DataA_Room_Temple_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_MinigunRotateBarrel
.IMPORT FuncA_Machine_MinigunTryAct
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawBoss
.IMPORT FuncA_Objects_DrawMinigunUpMachine
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeLeftOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_InitActorProjBreakball
.IMPORT FuncA_Room_InitActorSmokeBlood
.IMPORT FuncA_Room_InitBoss
.IMPORT FuncA_Room_RemoveAllBulletsIfConsoleOpen
.IMPORT FuncA_Room_ResetLever
.IMPORT FuncA_Room_TickBoss
.IMPORT Func_AckIrqAndLatchWindowFromParam4
.IMPORT Func_AckIrqAndSetLatch
.IMPORT Func_DivMod
.IMPORT Func_FindActorWithType
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Func_PlaySfxSample
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Ppu_ChrBgAnimB4
.IMPORT Ppu_ChrObjBoss1
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_NextIrq_int_ptr
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_RoomState
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; The fixed scroll-X position for this room.
kRoomScrollX = $08

;;; The device indices for the levers in this room.
kLeverLeftDeviceIndex = 4
kLeverRightDeviceIndex = 5

;;; The machine index for the BossTempleMinigun machine.
kMinigunMachineIndex = 0
;;; The platform index for the BossTempleMinigun machine.
kMinigunPlatformIndex = 4

;;; The initial and maximum permitted horizontal goal values for the minigun.
kMinigunInitGoalX = 8
kMinigunMaxGoalX = 8

;;; The maximum and initial X-positions for the left of the minigun platform.
.LINECONT +
kMinigunMinPlatformLeft = $0038
kMinigunInitPlatformLeft = \
    kMinigunMinPlatformLeft + kMinigunInitGoalX * kBlockWidthPx
.LINECONT -

;;;=========================================================================;;;

;;; The room pixel Y-positions for the top and bottom of the zone that the boss
;;; can move within.
kBossZoneTopY    = $26
kBossZoneBottomY = $63

;;; The height of the boss zone, in pixels.
kBossZoneHeightPx = kBossZoneBottomY - kBossZoneTopY
;;; How many BG tile rows are visible in the boss zone (rounded up).
kBossZoneHeightTiles = (kBossZoneHeightPx + kTileHeightPx - 1) / kTileHeightPx

;;; The height of the boss's body in the BG tile grid.
.DEFINE kBossBodyHeightTiles 4
kBossBodyHeightPx = kBossBodyHeightTiles * kTileHeightPx
.ASSERT kBossBodyHeightPx < kBossZoneHeightPx, error

;;; The width of the boss's body in the BG tile grid.
kBossBodyWidthTiles = 10
kBossBodyWidthPx = kBossBodyWidthTiles * kTileWidthPx

;;; The tile row in the lower nametable for the top edge of the boss's BG
;;; tiles.
kBossBodyStartRow = 8

;;; How many BG tile rows above/below the boss must be reserved because they'll
;;; be visible in the boss zone.
kBossMarginHeightTiles = kBossZoneHeightTiles - kBossBodyHeightTiles

;;; How many BG tile rows are needed for the boss and the margins above/below.
kBossTotalHeightTiles = kBossBodyHeightTiles + kBossMarginHeightTiles * 2

;;; The tile row in the lower nametable for the top of the margin space above
;;; the boss's BG tiles.
kBossMarginStartRow = kBossBodyStartRow - kBossMarginHeightTiles
;;; Assert that the upper BG margin doesn't go above the top of the lower
;;; nametable.
.ASSERT kBossMarginStartRow >= 0, error
;;; Assert that the lower BG margin doesn't run into the top of the window.
.ASSERT kBossMarginStartRow + kBossTotalHeightTiles <= kWindowStartRow, error

.LINECONT +
;;; The PPU address in the lower nametable for the leftmost tile column of the
;;; first row of the margin above the boss's body.
Ppu_BossMarginStart = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kBossMarginStartRow * kScreenWidthTiles
;;; The PPU address in the lower nametable for the tile at the top-left corner
;;; of the boss's body.
Ppu_BossBodyStart = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kBossBodyStartRow * kScreenWidthTiles + 11
.LINECONT -

;;;=========================================================================;;;

;;; The room pixel X-position for the center of the boss.
kBossCenterX = $88

;;; The minimum, maximum, and initial values for the top of the boss's body.
kBossMinTopY = kBossZoneTopY + 1
kBossMaxTopY = kBossZoneBottomY - kBossBodyHeightPx
kBossInitTopY = kBossMaxTopY
kBossInitBottomY = kBossInitTopY + kBossBodyHeightPx

;;; How many frames the boss waits, after you first enter the room, before
;;; taking action.
kBossInitCooldown = 120
;;; How many frames it takes for an eye to fully open or close.
.DEFINE kBossEyeOpenFrames 15
;;; How many frames the boss pauses for between all boss projectiles expiring
;;; and firing again.
kBossPauseFrames = 60
;;; How many frames the boss spends dying after hitting the spikes before it
;;; finally dies.
kBossDyingFrames = 45

;;; How many stun cycles the boss stays stunned for when hit with a breakball.
kBossStunCyclesPerHit = 10
;;; How many frames the boss stays stunned for per stun cycle.
kBossStunCycleFrames = 50
;;; How many frames the boss wobbles for at first when stunned.
kBossStunAnimFrames = 24

;;;=========================================================================;;;

;;; OBJ tile IDs used for drawing the boss.
kTileIdObjOutbreakBrainFirst = kTileIdObjOutbreakFirst + 0
kTileIdObjOutbreakEyeFirst   = kTileIdObjOutbreakFirst + 4
kTileIdObjOutbreakClaw       = kTileIdObjOutbreakFirst + 8

;;; OBJ palette numbers used for drawing the boss.
kPaletteObjOutbreakBrain = 1
kPaletteObjOutbreakClaw  = 0
kPaletteObjOutbreakEye   = 1

;;;=========================================================================;;;

;;; Modes that the boss in this room can be in.
.ENUM eBossMode
    Dead
    Dying       ; impaled on spikes; will die when cooldown expires
    Paused      ; eyes closed; will shoot a breakball when cooldown expires
    Waiting     ; eyes closed; waiting for projectiles to finish
    Stunned     ; active eye open; can shoot it to make boss crawl up
    ShootBreak  ; shooting a breakball from active eye
    NUM_VALUES
.ENDENUM

;;; For boss modes less than this, the boss is dead or dying.
kFirstHealthyBossMode = eBossMode::Paused
;;; For boss modes greater than or equal to this, the boss's active eye should
;;; open up.
kFirstBossModeWithOpenEye = eBossMode::Stunned

;;; Eyes of the boss.
.ENUM eBossEye
    Left
    Center
    Right
    NUM_VALUES
.ENDENUM

;;; The platform indices for the boss's eyes.
kBossEyeLeftPlatformIndex = 0
kBossEyeCenterPlatformIndex = 1
kBossEyeRightPlatformIndex = 2

;;; The platform index for the boss's body.
kBossBodyPlatformIndex = 3

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u8         .byte
    LeverRight_u8        .byte
    ;; What mode the boss is in.
    Current_eBossMode    .byte
    ;; Which eye is "active".
    Active_eBossEye      .byte
    ;; Timer that ticks down each frame when nonzero.  Used to time transitions
    ;; between boss modes.
    BossCooldown_u8      .byte
    ;; How many boss stun cycles are still to be completed before the boss
    ;; stops being stunned.  Each cycle lasts for kBossStunCycleFrames. The
    ;; stun cycle count is also decremented each time the boss gets hurt by a
    ;; bullet (to limit how many hits the boss can take before the boss stops
    ;; being stunned).
    BossStunCycles_u8    .byte
    ;; A counter that counts up each frame (wrapping around), faster during the
    ;; initial stun animation, and otherwise slower while stunned.  This
    ;; counter is used to drive the boss's pulsating animation.
    BossAnimCounter_u8   .byte
    ;; A timer for the boss's initial stun animation, during which the boss
    ;; pulsates rapidly.
    BossStunAnimTimer_u8 .byte
    ;; How open each of the eyes are, from 0 (closed) to kBossEyeOpenFrames
    ;; (open), indexed by eBossEye.
    BossEyeOpen_u8_arr3  .byte eBossEye::NUM_VALUES
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Boss"

.EXPORT DataC_Boss_Temple_sRoom
.PROC DataC_Boss_Temple_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8,  kRoomScrollX
    d_word MaxScrollX_u16, kRoomScrollX + $0
    d_byte Flags_bRoom, bRoom::Unsafe | eArea::Temple
    d_byte MinimapStartRow_u8, 1
    d_byte MinimapStartCol_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss1)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Temple_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncA_Room_BossTemple_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_BossTemple_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_BossTemple_TickRoom
    d_addr Draw_func_ptr, FuncC_Boss_Temple_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/boss_temple.room"
    .assert * - :- = 17 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kMinigunMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossTempleMinigun
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::MinigunUp
    d_word ScrollGoalX_u16, $0008
    d_byte ScrollGoalY_u8, $16
    d_byte RegNames_u8_arr4, "L", "R", "X", 0
    d_byte MainPlatform_u8, kMinigunPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_BossTempleMinigun_InitReset
    d_addr ReadReg_func_ptr, FuncC_Boss_TempleMinigun_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BossTempleMinigun_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_BossTempleMinigun_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_BossTempleMinigun_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BossTempleMinigun_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawMinigunUpMachine
    d_addr Reset_func_ptr, FuncA_Room_BossTempleMinigun_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kBossEyeLeftPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16, kBossCenterX - $14
    d_word Top_i16,  kBossInitBottomY - kTileHeightPx
    D_END
    .assert * - :- = kBossEyeCenterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16, kBossCenterX - $04
    d_word Top_i16,  kBossInitBottomY - 2
    D_END
    .assert * - :- = kBossEyeRightPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16, kBossCenterX + $0c
    d_word Top_i16,  kBossInitBottomY - kTileHeightPx
    D_END
    .assert * - :- = kBossBodyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kBossBodyWidthPx
    d_byte HeightPx_u8, kBossBodyHeightPx
    d_word Left_i16, kBossCenterX - kBossBodyWidthPx / 2
    d_word Top_i16,  kBossInitTopY
    D_END
    .assert * - :- = kMinigunPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kMinigunMachineWidthPx
    d_byte HeightPx_u8, kMinigunMachineHeightPx
    d_word Left_i16, kMinigunInitPlatformLeft
    d_word Top_i16,   $00a0
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   .assert * - :- = kBossDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eRoom::TempleSpire
    D_END
    .assert * - :- = kBossUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be an upgrade
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eFlag::UpgradeRam2
    D_END
    .assert * - :- = kBossBreakerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be a breaker
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 12
    d_byte Target_byte, eFlag::BreakerTemple
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 3
    d_byte Target_byte, kMinigunMachineIndex
    D_END
    .assert * - :- = kLeverLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 6
    d_byte Target_byte, sState::LeverLeft_u8
    D_END
    .assert * - :- = kLeverRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 10
    d_byte Target_byte, sState::LeverRight_u8
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC DataC_Boss_Temple_sBoss
    D_STRUCT sBoss
    d_byte Boss_eFlag, eFlag::BossTemple
    d_byte BodyPlatform_u8, kBossBodyPlatformIndex
    d_addr Tick_func_ptr, FuncC_Boss_Temple_TickBoss
    d_addr Draw_func_ptr, FuncC_Boss_Temple_DrawBoss
    D_END
.ENDPROC

;;; Performs per-frame upates for the boss in this room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Temple_TickBoss
    lda Zp_RoomState + sState::Current_eBossMode
    cmp #kFirstHealthyBossMode
    blt _TickEyes
_CheckForHits:
    jsr FuncA_Room_BossTemple_CheckForBulletHit
    jsr FuncC_Boss_Temple_CheckForBreakballHit
_TickAnimation:
    cmp #eBossMode::Stunned
    bne @normalAnim
    lda Zp_RoomState + sState::BossStunAnimTimer_u8
    beq @slowAnim
    @stunAnim:
    dec Zp_RoomState + sState::BossStunAnimTimer_u8
    inc Zp_RoomState + sState::BossAnimCounter_u8
    inc Zp_RoomState + sState::BossAnimCounter_u8
    inc Zp_RoomState + sState::BossAnimCounter_u8
    inc Zp_RoomState + sState::BossAnimCounter_u8
    @normalAnim:
    inc Zp_RoomState + sState::BossAnimCounter_u8
    @slowAnim:
    inc Zp_RoomState + sState::BossAnimCounter_u8
_TickEyes:
    ldx #eBossEye::NUM_VALUES - 1
    @loop:
    jsr FuncC_Boss_Temple_TickBossEye  ; preserves X
    dex
    bpl @loop
_CoolDown:
    lda Zp_RoomState + sState::BossCooldown_u8
    beq @done
    dec Zp_RoomState + sState::BossCooldown_u8
    @done:
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
    D_TABLE .enum, eBossMode
    d_entry table, Dead,       Func_Noop
    d_entry table, Dying,      _BossDying
    d_entry table, Paused,     _BossPaused
    d_entry table, Waiting,    _BossWaiting
    d_entry table, Stunned,    _BossStunned
    d_entry table, ShootBreak, _BossShootBreak
    D_END
.ENDREPEAT
_BossDying:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Kill the boss.
    lda #eBossMode::Dead
    sta Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_BossPaused:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne _Return
    ;; Switch modes to fire a breakball.
    lda #eBossMode::ShootBreak
    sta Zp_RoomState + sState::Current_eBossMode
    jmp FuncC_Boss_Temple_ChooseActiveEye
_BossWaiting:
    ;; Wait for all boss projetiles to expire.
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::ProjBreakball
    beq _Return
    cmp #eActor::ProjBreakfire
    beq _Return
    dex
    bpl @loop
    ;; Pause briefly before shooting the next breakball.
    lda #eBossMode::Paused
    sta Zp_RoomState + sState::Current_eBossMode
    lda #kBossPauseFrames
    sta Zp_RoomState + sState::BossCooldown_u8
_Return:
    rts
_BossStunned:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; If there are any stun cycles left, wait for another cycle.
    lda Zp_RoomState + sState::BossStunCycles_u8
    beq @unstun
    dec Zp_RoomState + sState::BossStunCycles_u8
    lda #kBossStunCycleFrames
    sta Zp_RoomState + sState::BossCooldown_u8
    rts
    ;; Otherwise, the boss is done being stunned.
    @unstun:
    lda #eBossMode::Waiting
    sta Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_BossShootBreak:
    ;; Wait for the active eye to be fully open.
    ldy Zp_RoomState + sState::Active_eBossEye  ; param: platform index
    lda Zp_RoomState + sState::BossEyeOpen_u8_arr3, y
    cmp #kBossEyeOpenFrames
    blt @done
    ;; Spawn a breakball projetile.
    jsr Func_SetPointToPlatformCenter
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @done
    jsr Func_SetActorCenterToPoint  ; preserves X
    jsr Func_GetRandomByte  ; preserves X, returns A
    and #bObj::FlipH  ; param: horz direction
    jsr FuncA_Room_InitActorProjBreakball
    ;; Switch to waiting mode.
    lda #eBossMode::Waiting
    sta Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
.ENDPROC

;;; Sets Active_eBossEye to a random eBossEye value.
.PROC FuncC_Boss_Temple_ChooseActiveEye
    jsr Func_GetRandomByte  ; returns A (param: dividend)
    ldy #eBossEye::NUM_VALUES  ; param: divisor
    jsr Func_DivMod  ; returns remainder in A
    sta Zp_RoomState + sState::Active_eBossEye
    rts
.ENDPROC

;;; Performs per-frame upates for one of the boss's eyes.
;;; @param X The eBossEye value for the eye.
.PROC FuncC_Boss_Temple_TickBossEye
_CheckIfOpenOrClosed:
    lda Zp_RoomState + sState::Current_eBossMode
    cmp #kFirstHealthyBossMode
    blt _Open
    cmp #kFirstBossModeWithOpenEye
    blt _Close
    cpx Zp_RoomState + sState::Active_eBossEye
    bne _Close
_Open:
    lda Zp_RoomState + sState::BossEyeOpen_u8_arr3, x
    cmp #kBossEyeOpenFrames
    bge @done
    inc Zp_RoomState + sState::BossEyeOpen_u8_arr3, x
    @done:
    rts
_Close:
    lda Zp_RoomState + sState::BossEyeOpen_u8_arr3, x
    beq @done
    dec Zp_RoomState + sState::BossEyeOpen_u8_arr3, x
    @done:
    rts
.ENDPROC

;;; Checks if a breakball has hit the boss's body; if so, expires the breakball
;;; and stuns the boss.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Temple_CheckForBreakballHit
    ;; Find the breakball actor (if any).
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::ProjBreakball
    beq _FoundBreakball
    dex
    bpl @loop
_Done:
    rts
_FoundBreakball:
    ;; Ignore the breakball if it's moving downward.
    lda Ram_ActorVelY_i16_1_arr, x
    bpl _Done
    ;; Check if the breakball has hit the boss's body.
    jsr Func_SetPointToActorCenter  ; preserves X
    ldy #kBossBodyPlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; preserves X, returns C
    bcc _Done
_StunBoss:
    ;; Expire the breakball.
    jsr Func_InitActorSmokeExplosion
    ;; Stun the boss.
    lda #eBossMode::Stunned
    sta Zp_RoomState + sState::Current_eBossMode
    lda #kBossStunCyclesPerHit
    sta Zp_RoomState + sState::BossStunCycles_u8
    lda #0
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #kBossStunAnimFrames
    sta Zp_RoomState + sState::BossStunAnimTimer_u8
    ldx Zp_RoomState + sState::Active_eBossEye
    lda #kBossEyeOpenFrames / 2
    sta Zp_RoomState + sState::BossEyeOpen_u8_arr3, x
    lda #eSample::BossHurtE  ; param: eSample to play
    jmp Func_PlaySfxSample
.ENDPROC

;;; Draw function for the BossTemple room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Temple_DrawRoom
    jsr FuncC_Boss_Temple_GetPulsationIndex  ; returns A (0-2)
    .assert .bank(Ppu_ChrBgAnimB4) .mod 4 = 0, error
    ora #<.bank(Ppu_ChrBgAnimB4)
    sta Zp_Chr04Bank_u8
    jmp FuncA_Objects_DrawBoss
.ENDPROC

;;; Draw function for the temple boss.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Temple_DrawBoss
_DrawBossClaws:
    jsr FuncC_Boss_Temple_SetShapePosToBossMidTop
    lda #$24  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #0  ; param: horz flip
    jsr FuncC_Boss_Temple_DrawClawPair
    jsr FuncC_Boss_Temple_SetShapePosToBossMidTop
    lda #$2c  ; param: offset
    jsr FuncA_Objects_MoveShapeLeftByA
    lda #bObj::FlipH  ; param: horz flip
    jsr FuncC_Boss_Temple_DrawClawPair
_DrawBossEyes:
    ldx #eBossEye::NUM_VALUES - 1
    @loop:
    jsr FuncC_Boss_Temple_DrawEye
    dex
    bpl @loop
_DrawBossBrain:
    jsr FuncC_Boss_Temple_SetShapePosToBossMidTop
    jsr FuncA_Objects_MoveShapeUpOneTile
    lda Zp_RoomState + sState::Current_eBossMode
    cmp #kFirstHealthyBossMode
    bge @pulsate
    lda #kTileIdObjOutbreakBrainFirst + 3  ; param: tile ID
    bne @drawTiles  ; unconditional
    @pulsate:
    jsr FuncC_Boss_Temple_GetPulsationIndex  ; returns A (0-2)
    .assert kTileIdObjOutbreakBrainFirst .mod 4 = 0, error
    ora #kTileIdObjOutbreakBrainFirst  ; param: tile ID
    @drawTiles:
    pha  ; tile ID
    ldy #kPaletteObjOutbreakBrain | bObj::FlipH  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    jsr FuncA_Objects_MoveShapeLeftOneTile
    ldy #kPaletteObjOutbreakBrain  ; param: object flags
    pla  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape
_SetUpIrq:
    ;; Compute the IRQ latch value to set between the bottom of the boss's zone
    ;; and the top of the window (if any), and set that as Param4_byte.
    lda <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    sub #kBossZoneBottomY
    add Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Param4_byte)  ; window latch
    ;; Set up our own sIrq struct to handle boss movement.
    lda #kBossZoneTopY - 1
    sub Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    ldax #Int_BossTempleZoneTopIrq
    stax <(Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr)
    ;; Compute PPU scroll values for the boss zone.
    lda #kBossBodyStartRow * kTileHeightPx + kBossZoneTopY
    sub Ram_PlatformTop_i16_0_arr + kBossBodyPlatformIndex
    sta <(Zp_Buffered_sIrq + sIrq::Param2_byte)  ; boss scroll-Y
    rts
.ENDPROC

;;; Returns the index to use for the boss's pulsating animation, following the
;;; pattern 0, 1, 2, 1.
;;; @return A The pulsatation index (0-2).
.PROC FuncC_Boss_Temple_GetPulsationIndex
    lda Zp_RoomState + sState::BossAnimCounter_u8
    div #16
    and #$03
    cmp #$03
    bne @noWrap
    lda #$01
    @noWrap:
    rts
.ENDPROC

;;; Draws two claws on one side of the temple boss.
;;; @prereq The shape position is set to the top left of the claw pair.
;;; @param A Either 0 for eastern claws, or bObj::FlipH for western claws.
.PROC FuncC_Boss_Temple_DrawClawPair
    pha  ; horz flip
    .assert kPaletteObjOutbreakClaw = 0, error
    tay  ; param: object flags
    lda Ram_PlatformTop_i16_0_arr + kBossBodyPlatformIndex
    and #$01
    cpy #0
    beq @noEor
    eor #$01
    @noEor:
    tax  ; 1 if claws are close together, 0 otherwise
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X and Y
    lda #kTileIdObjOutbreakClaw  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    lda _Offset_u8_arr2, x  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    pla  ; horz flip
    eor #bObj::FlipV
    tay  ; param: object flags
    lda #kTileIdObjOutbreakClaw  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
_Offset_u8_arr2:
    .byte kTileHeightPx * 3
    .byte kTileHeightPx * 3 - 2
.ENDPROC

;;; Draws one eye for the temple boss.
;;; @param X The eBossEye value for the eye to draw.
;;; @preserve X
.PROC FuncC_Boss_Temple_DrawEye
    .assert eBossEye::Left = kBossEyeLeftPlatformIndex, error
    .assert eBossEye::Center = kBossEyeCenterPlatformIndex, error
    .assert eBossEye::Right = kBossEyeRightPlatformIndex, error
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    ;; Determine tile ID.
    lda Zp_RoomState + sState::BossEyeOpen_u8_arr3, x
    .assert (kBossEyeOpenFrames + 1) .mod 4 = 0, error
    div #(kBossEyeOpenFrames + 1) / 4
    .assert kTileIdObjOutbreakEyeFirst .mod 4 = 0, error
    ora #kTileIdObjOutbreakEyeFirst  ; param: tile ID
    ;; Draw the shape.
    ldy #kPaletteObjOutbreakEye  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
.ENDPROC

;;; Sets Zp_ShapePosX_i16 and Zp_ShapePosY_i16 to the screen-space position of
;;; the top-center of the boss's body.
;;; @preserve X, Y, T0+
.PROC FuncC_Boss_Temple_SetShapePosToBossMidTop
    lda #kScreenWidthPx / 2
    sta Zp_ShapePosX_i16 + 0
    lda Ram_PlatformTop_i16_0_arr + kBossBodyPlatformIndex
    sub Zp_RoomScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda #0
    sta Zp_ShapePosX_i16 + 1
    sta Zp_ShapePosY_i16 + 1
    rts
.ENDPROC

.PROC FuncC_Boss_TempleMinigun_ReadReg
    cmp #$c
    beq @readL
    cmp #$d
    beq @readR
    @readX:
    lda Ram_PlatformLeft_i16_0_arr + kMinigunPlatformIndex
    sub #kMinigunMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
    @readL:
    lda Zp_RoomState + sState::LeverLeft_u8
    rts
    @readR:
    lda Zp_RoomState + sState::LeverRight_u8
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Room init function for the BossTemple room.
.PROC FuncA_Room_BossTemple_EnterRoom
    ldax #DataC_Boss_Temple_sBoss  ; param: sBoss ptr
    jsr FuncA_Room_InitBoss  ; sets Z if boss is alive
    bne _BossIsDead
_BossIsAlive:
    lda #eBossMode::Paused
    sta Zp_RoomState + sState::Current_eBossMode
    lda #kBossInitCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
_BossIsDead:
    rts
.ENDPROC

;;; Room tick function for the BossTemple room.
.PROC FuncA_Room_BossTemple_TickRoom
    jsr FuncA_Room_RemoveAllBulletsIfConsoleOpen
    .assert eBossMode::Dead = 0, error
    lda Zp_RoomState + sState::Current_eBossMode  ; param: zero if boss dead
    jmp FuncA_Room_TickBoss
.ENDPROC

.PROC FuncA_Room_BossTempleMinigun_InitReset
    lda #kMinigunInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kMinigunMachineIndex
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Room_ResetLever
.ENDPROC

;;; Checks if a bullet has hit a boss eye; if so, expires the bullet and makes
;;; the boss react accordingly.
.PROC FuncA_Room_BossTemple_CheckForBulletHit
    ;; Loop over all actors, skipping over non-bullets.
    ldx #kMaxActors - 1
    @actorLoop:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::ProjBullet
    bne @actorContinue
    jsr Func_SetPointToActorCenter  ; preserves X
    ;; For each bullet, loop over the boss eyes, check if the bullet hits them.
    ldy #eBossEye::NUM_VALUES - 1
    @eyeLoop:
    .assert eBossEye::Left = kBossEyeLeftPlatformIndex, error
    .assert eBossEye::Center = kBossEyeCenterPlatformIndex, error
    .assert eBossEye::Right = kBossEyeRightPlatformIndex, error
    jsr Func_IsPointInPlatform  ; preserves X and Y; returns C
    ;; In practice, only one bullet/eye impact should be able to happen in a
    ;; given frame, so if an impact happens, we can just break out of both
    ;; loops (which saves us the trouble of preserving the loop variables).
    bcs FuncA_Room_BossTemple_BulletHitsEye
    dey
    bpl @eyeLoop
    @actorContinue:
    dex
    bpl @actorLoop
    rts
.ENDPROC

;;; Called when a bullet hits one of the boss's eyes.
;;; @param X The actor index for the bullet.
;;; @param Y The eBossEye value for the eye that was hit.
.PROC FuncA_Room_BossTemple_BulletHitsEye
    ;; Expire the bullet.
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    ;; Check if the eye is open.
    lda Zp_RoomState + sState::BossEyeOpen_u8_arr3, y
    .assert (kBossEyeOpenFrames + 1) .mod 4 = 0, error
    cmp #(kBossEyeOpenFrames + 1) * 3 / 4
    bge _EyeIsOpen
_EyeIsClosed:
    ;; TODO: play a sound
    rts
_EyeIsOpen:
    lda #eSample::BossHurtF  ; param: eSample to play
    jsr Func_PlaySfxSample
    ;; Decrement the number of stun cycles if nonzero.
    lda Zp_RoomState + sState::BossStunCycles_u8
    beq @done
    dec Zp_RoomState + sState::BossStunCycles_u8
    @done:
    fall FuncA_Room_BossTemple_CrawlUp
.ENDPROC

;;; Moves the boss upwards by one pixel, and checks if it has hit the spikes at
;;; the top of the room.
.PROC FuncA_Room_BossTemple_CrawlUp
    ;; Move the boss's body.
    ldx #kBossBodyPlatformIndex  ; param: platform index
    lda #<-1  ; param: move delta
    jsr Func_MovePlatformVert
    ;; Move the boss's eye zones.
    ldx #eBossEye::NUM_VALUES - 1
    @loop:
    .assert eBossEye::Left = kBossEyeLeftPlatformIndex, error
    .assert eBossEye::Center = kBossEyeCenterPlatformIndex, error
    .assert eBossEye::Right = kBossEyeRightPlatformIndex, error
    lda #<-1  ; param: move delta
    jsr Func_MovePlatformVert  ; preserves X
    dex
    bpl @loop
_CheckForSpikes:
    ;; If the top of the boss's body <= kBossMinTopY, the boss dies.
    lda #kBossMinTopY
    cmp Ram_PlatformTop_i16_0_arr + kBossBodyPlatformIndex
    bge _KillBoss
    rts
_KillBoss:
    ;; The boss has hits the spikes, so make it start dying.
    lda #eBossMode::Dying
    sta Zp_RoomState + sState::Current_eBossMode
    lda #kBossDyingFrames
    sta Zp_RoomState + sState::BossCooldown_u8
    ;; Silence the music.
    lda #eMusic::Silence
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    ;; Expire the breakball projectile, if any; it's possible for there to be
    ;; one if the last bullet hit comes just as the boss is firing a breakball.
    lda #eActor::ProjBreakball  ; param: actor type
    jsr Func_FindActorWithType  ; returns C and X
    bcs @noBreakball  ; no breakball found
    jsr Func_InitActorSmokeExplosion
    @noBreakball:
    fall FuncA_Room_BossTemple_SpurtBlood
.ENDPROC

;;; Spawns blood smoke actors out of the boss's brain.
.PROC FuncA_Room_BossTemple_SpurtBlood
    ;; Make blood spurt out of the boss where it hit the spikes.
    lda #kBossMinTopY
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointX_i16 + 1
    sta Zp_PointY_i16 + 1
    ldy #4 - 1
    @loop:
    jsr Func_FindEmptyActorSlot  ; preserves Y and T0+, returns C and X
    bcs @break  ; no more empty actor slots
    lda _BloodPosX_u8_arr4, y
    sta Zp_PointX_i16 + 0
    jsr Func_SetActorCenterToPoint  ; preserves X and Y
    lda _BloodTile_u8_arr4, y  ; param: tile ID
    sty T0  ; loop counter
    jsr FuncA_Room_InitActorSmokeBlood  ; preserves X and T0+
    ldy T0  ; loop counter
    lda _BloodVelX_i16_0_arr4, y
    sta Ram_ActorVelX_i16_0_arr, x
    lda _BloodVelX_i16_1_arr4, y
    sta Ram_ActorVelX_i16_1_arr, x
    lda _BloodVelY_i16_0_arr4, y
    sta Ram_ActorVelY_i16_0_arr, x
    lda _BloodVelY_i16_1_arr4, y
    sta Ram_ActorVelY_i16_1_arr, x
    dey
    bpl @loop
    @break:
    ;; TODO: play a sound
    rts
_BloodTile_u8_arr4:
    .byte kTileIdObjBloodFirst + 1
    .byte kTileIdObjBloodFirst + 0
    .byte kTileIdObjBloodFirst + 1
    .byte kTileIdObjBloodFirst + 0
_BloodPosX_u8_arr4:
    .byte $84, $87, $89, $8c
_BloodVelX_i16_0_arr4:
    .byte <-280, <-50, <200, <230
_BloodVelX_i16_1_arr4:
    .byte >-280, >-50, >200, >230
_BloodVelY_i16_0_arr4:
    .byte <-550, <-200, <-700, <-400
_BloodVelY_i16_1_arr4:
    .byte >-550, >-200, >-700, >-400
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_BossTempleMinigun_WriteReg
    cpx #$d
    beq _WriteR
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_BossTempleMinigun_TryMove
    lda #kMinigunMaxGoalX  ; param: max goal
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncA_Machine_BossTempleMinigun_TryAct
    ldy #eDir::Up  ; param: bullet direction
    jmp FuncA_Machine_MinigunTryAct
.ENDPROC

.PROC FuncA_Machine_BossTempleMinigun_Tick
    jsr FuncA_Machine_MinigunRotateBarrel
    ldax #kMinigunMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; Room fade-in function for the BossTemple room.
;;; @prereq Rendering is disabled.
.PROC FuncA_Terrain_BossTemple_FadeInRoom
_DrawBoss:
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldy #kBossBodyHeightTiles - 1
    @rowLoop:
    ldx _BossRowStart_ptr_0_arr, y
    lda _BossRowStart_ptr_1_arr, y
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda _BossRowFirstTileId_u8_arr, y
    ldx #kBossBodyWidthTiles
    clc
    @colLoop:
    sta Hw_PpuData_rw
    adc #1  ; carry is already clear
    dex
    bne @colLoop
    dey
    bpl @rowLoop
_DrawColumns:
    lda #kPpuCtrlFlagsVert
    sta Hw_PpuCtrl_wo
    ldy #8 - 1
    @loop:
    lda _ColumnTileId_u8_arr, y  ; param: BG tile ID
    ldx _ColumnTileCol_u8_arr, y  ; param: nametable tile column index
    jsr _DrawStripe  ; preserves Y
    dey
    bpl @loop
    rts
_DrawStripe:
    pha  ; BG tile ID
    txa  ; nametable tile column index
    add #<Ppu_BossMarginStart
    tax  ; PPU address (lo)
    lda #0
    adc #>Ppu_BossMarginStart
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2  ; PPU address (hi)
    stx Hw_PpuAddr_w2  ; PPU address (lo)
    pla  ; BG tile ID
    ldx #kBossTotalHeightTiles
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
    rts
_BossRowStart_ptr_0_arr:
    .repeat kBossBodyHeightTiles, i
    .byte <(Ppu_BossBodyStart + kScreenWidthTiles * i)
    .endrepeat
_BossRowStart_ptr_1_arr:
    .repeat kBossBodyHeightTiles, i
    .byte >(Ppu_BossBodyStart + kScreenWidthTiles * i)
    .endrepeat
_BossRowFirstTileId_u8_arr:
    .repeat kBossBodyHeightTiles, i
    .byte $40 + kBossBodyWidthTiles * i
    .endrepeat
_ColumnTileId_u8_arr:
    .byte $9a, $9b, $94, $95, $94, $95, $9a, $9b
_ColumnTileCol_u8_arr:
    .byte   3,   4,   9,  10,  21,  22,  27,  28
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top of the boss's zone in the
;;; BossTemple room.  Sets the vertical scroll so as to make the boss's BG
;;; tiles appear to move.
.PROC Int_BossTempleZoneTopIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Set up the
    ;; next IRQ.
    lda #kBossZoneBottomY - kBossZoneTopY - 1  ; param: latch value
    jsr Func_AckIrqAndSetLatch  ; preserves Y
    ldax #Int_BossTempleZoneBottomIrq
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
    lda <(Zp_Active_sIrq + sIrq::Param2_byte)  ; boss scroll-Y
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
;;; BossTemple room.  Sets the scroll so as to make the bottom of the room look
;;; normal.
.PROC Int_BossTempleZoneBottomIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ and prepare for the next one.
    jsr Func_AckIrqAndLatchWindowFromParam4  ; preserves Y
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #6  ; This value is hand-tuned to help wait for second HBlank.
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
    lda #((kBossZoneBottomY & $38) << 2) | (kRoomScrollX >> 3)
    ldx #kRoomScrollX
    ;; We should now be in the second HBlank.
    stx Hw_PpuScroll_w2  ; new scroll-X value
    sta Hw_PpuAddr_w2    ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;;=========================================================================;;;
