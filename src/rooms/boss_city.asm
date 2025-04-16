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
.INCLUDE "../actors/rocket.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../boss.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../irq.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/ammorack.inc"
.INCLUDE "../machines/launcher.inc"
.INCLUDE "../machines/reloader.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../sample.inc"
.INCLUDE "boss_city.inc"

.IMPORT DataA_Room_Building_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT FuncA_Machine_AmmoRack_TryAct
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericMoveTowardGoalVert
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_LauncherTryAct
.IMPORT FuncA_Machine_PlaySfxRocketTransfer
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawAmmoRackMachine
.IMPORT FuncA_Objects_DrawBoss
.IMPORT FuncA_Objects_DrawLauncherMachineHorz
.IMPORT FuncA_Objects_DrawReloaderMachine
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_InitActorProjBreakbomb
.IMPORT FuncA_Room_InitActorProjSpine
.IMPORT FuncA_Room_InitBoss
.IMPORT FuncA_Room_TickBoss
.IMPORT Func_AckIrqAndLatchWindowFromParam4
.IMPORT Func_AckIrqAndSetLatch
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_DivAByBlockSizeAndClampTo9
.IMPORT Func_FindActorWithType
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsPointInAnySolidPlatform
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePlatformVert
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointHorz
.IMPORT Func_MovePointUpByA
.IMPORT Func_Noop
.IMPORT Func_PlaySfxDrip
.IMPORT Func_PlaySfxExplodeBig
.IMPORT Func_PlaySfxSample
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_ShakeRoom
.IMPORT Func_SignedMult
.IMPORT Func_Sine
.IMPORT Ppu_ChrBgBossCity
.IMPORT Ppu_ChrObjBoss2
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_IrqTmp_byte
.IMPORTZP Zp_NextIrq_int_ptr
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_RoomState
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; The machine index for the BossCityLauncher machine.
kLauncherMachineIndex = 0
;;; The machine index for the BossCityReloader machine.
kReloaderMachineIndex = 1
;;; The machine index for the BossCityAmmoRack machine.
kAmmoRackMachineIndex = 2

;;; The platform index for the BossCityLauncher machine.
kLauncherPlatformIndex = 4
;;; The platform index for the BossCityReloader machine.
kReloaderPlatformIndex = 5
;;; The platform index for the BossCityAmmoRack machine.
kAmmoRackPlatformIndex = 6

;;; The initial and maximum permitted vertical goal values for the launcher.
kLauncherInitGoalY = 1
kLauncherMaxGoalY = 5

;;; The maximum and initial Y-positions for the top of the launcher platform.
.LINECONT +
kLauncherMaxPlatformTop = $0070
kLauncherInitPlatformTop = \
    kLauncherMaxPlatformTop - kLauncherInitGoalY * kBlockHeightPx
kLauncherMinPlatformTop = \
    kLauncherMaxPlatformTop - kLauncherMaxGoalY * kBlockHeightPx
.LINECONT -

;;; The initial and maximum permitted horizontal goal values for the reloader.
kReloaderInitGoalX = 5
kReloaderMaxGoalX = 9

;;; The maximum and initial X-positions for the left of the reloader platform.
.LINECONT +
kReloaderMinPlatformLeft = $0030
kReloaderInitPlatformLeft = \
    kReloaderMinPlatformLeft + kReloaderInitGoalX * kBlockWidthPx
.LINECONT -

;;; The device indices for the levers in this room.
kLeverLeftDeviceIndex = 3
kLeverRightDeviceIndex = 4

;;;=========================================================================;;;

;;; The platform indices for the side walls.
kLeftWallPlatformIndex  = 7
kRightWallPlatformIndex = 8

;;; The platform indices for the background bricks.
kBricks1PlatformIndex = 9
kBricks2PlatformIndex = 10
kBricks3PlatformIndex = 11

;;;=========================================================================;;;

;;; The width and height of the boss's BG tile grid.
kBossBgWidthTiles  = 8
kBossBgHeightTiles = 6
kBossBgWidthPx  = kBossBgWidthTiles * kTileWidthPx
kBossBgHeightPx = kBossBgHeightTiles * kTileHeightPx

;;; The tile row/col in the lower nametable for the top-left corner of the
;;; boss's BG tiles.
kBossBgStartRow = 7
kBossBgStartCol = 1

;;; The PPU addresses for the start (left) of each row of the boss's BG tiles.
.LINECONT +
Ppu_BossRow0Start = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBossBgStartRow + 0) + kBossBgStartCol
Ppu_BossRow1Start = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBossBgStartRow + 1) + kBossBgStartCol
Ppu_BossRow2Start = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBossBgStartRow + 2) + kBossBgStartCol
Ppu_BossRow3Start = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBossBgStartRow + 3) + kBossBgStartCol
Ppu_BossRow4Start = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBossBgStartRow + 4) + kBossBgStartCol
Ppu_BossRow5Start = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBossBgStartRow + 5) + kBossBgStartCol
.ASSERT (kBossBgStartRow + 1) .mod 4 = 0, error
.ASSERT (kBossBgStartCol + 3) .mod 4 = 0, error
Ppu_BossCoreAttrs = Ppu_Nametable3_sName + sName::Attrs_u8_arr64 + \
    ((kBossBgStartRow + 1) / 4) * 8 + ((kBossBgStartCol + 3) / 4)
.LINECONT -

;;; The room pixel Y-positions for the top and bottom of the zone that the boss
;;; can move within.
kBossZoneTopY    = $30
kBossZoneBottomY = $80

;;; The sizes of various parts of the boss, in pixels.
kBossShellWidthPx  = $2c
kBossShellHeightPx = $10
kBossCoreWidthPx   = $0c
kBossCoreHeightPx  = $10
kBossBodyWidthPx   = kBossShellWidthPx
kBossBodyHeightPx  = kBossShellHeightPx * 2 + kBossCoreHeightPx

;;; The initial room pixel position for the center of the boss.
kBossInitCenterX = $74
kBossInitCenterY = (kBossZoneTopY + kBossZoneBottomY) / 2

;;; The room pixel X-positions past which the boss must turn around.
kBossMinCenterX = $28
kBossMaxCenterX = $90

;;; The room pixel Y-positions past which the boss cannot open its shell.
kBossMinCenterOpenY = kBossZoneTopY    + kBossBodyHeightPx / 2 + 2
kBossMaxCenterOpenY = kBossZoneBottomY - kBossBodyHeightPx / 2 - 2

;;; The amplitude of the boss's horizontal and vertical sinusoidal movement, in
;;; half-pixels.
.LINECONT +
kBossHorzAmplitude = $6a
kBossVertAmplitude = \
    kBossZoneBottomY - kBossZoneTopY - kBossShellHeightPx * 2 - 10
.LINECONT -

;;; Modes that the boss in this room can be in.
.ENUM eBossMode
    Dead
    Hurt
    Open
    Close
    ShootSpines
    Weaving
    NUM_VALUES
.ENDENUM

;;; How many rocket hits are needed to defeat the boss.
kBossInitHealth = 8

;;; How many frames the boss waits, after you first enter the room, before
;;; taking action.
kBossInitCooldown = 120
;;; How many frames to wait in place when hurt.
kBossHurtCooldown = 45

;;; The delay duration between individual spines when shooting spines, in
;;; frames.
.DEFINE kBossSpineSlowdown 2

;;; Platform indices for various parts of the boss.
kBossBodyPlatformIndex       = 0
kBossCorePlatformIndex       = 1
kBossShellUpperPlatformIndex = 2
kBossShellLowerPlatformIndex = 3

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u8  .byte
    LeverRight_u8 .byte
    ;; The bit pattern for the damage that the left wall has taken from rockets
    ;; so far.  If bit N is set, that means that the Nth block down (starting
    ;; from zero) has been damaged.
    LeftWallDamage_u8 .byte
    ;; What mode the boss is in.
    Current_eBossMode .byte
    ;; How many more rocket hits are needed before the boss dies.
    BossHealth_u8 .byte
    ;; Timer that ticks down each frame when nonzero.  Used to time transitions
    ;; between boss modes.
    BossCooldown_u8 .byte
    ;; How open the boss's shell is.  This is used as in index into
    ;; DataC_Boss_City_ShellOffset_u8_arr.
    BossShellOpen_u8 .byte
    ;; The current theta angles for the boss's horizontal and vertical
    ;; sinusoidal movement.
    BossHorzTheta_u8 .byte
    BossVertTheta_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Boss"

.EXPORT DataC_Boss_City_sRoom
.PROC DataC_Boss_City_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte Flags_bRoom, bRoom::Unsafe | eArea::City
    d_byte MinimapStartRow_u8, 3
    d_byte MinimapStartCol_u8, 21
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 3
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss2)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Building_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncA_Room_BossCity_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_BossCity_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_BossCity_TickRoom
    d_addr Draw_func_ptr, FuncC_Boss_City_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/boss_city.room"
    .assert * - :- = 16 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kLauncherMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossCityLauncher
    d_byte Breaker_eFlag, 0
    .linecont +
    d_byte Flags_bMachine, bMachine::FlipH | bMachine::MoveV | \
                           bMachine::Act | bMachine::WriteCD
    .linecont -
    d_byte Status_eDiagram, eDiagram::LauncherLeft
    d_word ScrollGoalX_u16, $0000
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", "R", 0, "Y"
    d_byte MainPlatform_u8, kLauncherPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_BossCityLauncher_InitReset
    d_addr ReadReg_func_ptr, FuncC_Boss_CityLauncher_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BossCity_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_BossCityLauncher_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_BossCityLauncher_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BossCityLauncher_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLauncherMachineHorz
    d_addr Reset_func_ptr, FuncA_Room_BossCityLauncher_InitReset
    D_END
    .assert * - :- = kReloaderMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossCityReloader
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::Reloader
    d_word ScrollGoalX_u16, $0000
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", "R", "X", 0
    d_byte MainPlatform_u8, kReloaderPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_BossCityReloader_InitReset
    d_addr ReadReg_func_ptr, FuncC_Boss_CityReloader_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BossCity_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_BossCityReloader_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_BossCityReloader_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BossCityReloader_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawReloaderMachine
    d_addr Reset_func_ptr, FuncA_Room_BossCityReloader_InitReset
    D_END
    .assert * - :- = kAmmoRackMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossCityAmmoRack
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::AmmoRack
    d_word ScrollGoalX_u16, $0000
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", "R", 0, 0
    d_byte MainPlatform_u8, kAmmoRackPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Boss_City_ReadRegLR
    d_addr WriteReg_func_ptr, FuncA_Machine_BossCity_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_AmmoRack_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_ReachedGoal
    d_addr Draw_func_ptr, FuncA_Objects_DrawAmmoRackMachine
    d_addr Reset_func_ptr, Func_Noop
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kBossBodyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kBossBodyWidthPx
    d_byte HeightPx_u8, kBossBodyHeightPx
    d_word Left_i16, kBossInitCenterX - kBossBodyWidthPx / 2
    d_word Top_i16, kBossInitCenterY - kBossBodyHeightPx / 2
    D_END
    .assert * - :- = kBossCorePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kBossCoreWidthPx
    d_byte HeightPx_u8, kBossCoreHeightPx
    d_word Left_i16, kBossInitCenterX - kBossCoreWidthPx / 2
    d_word Top_i16, kBossInitCenterY - kBossCoreHeightPx / 2
    D_END
    .assert * - :- = kBossShellUpperPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kBossShellWidthPx
    d_byte HeightPx_u8, kBossShellHeightPx
    d_word Left_i16, kBossInitCenterX - kBossShellWidthPx / 2
    d_word Top_i16, kBossInitCenterY - kBossShellHeightPx
    D_END
    .assert * - :- = kBossShellLowerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kBossShellWidthPx
    d_byte HeightPx_u8, kBossShellHeightPx
    d_word Left_i16, kBossInitCenterX - kBossShellWidthPx / 2
    d_word Top_i16, kBossInitCenterY
    D_END
    ;; Machines:
    .assert * - :- = kLauncherPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLauncherMachineWidthPx
    d_byte HeightPx_u8, kLauncherMachineHeightPx
    d_word Left_i16,  $00d0
    d_word Top_i16, kLauncherInitPlatformTop
    D_END
    .assert * - :- = kReloaderPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kReloaderMachineWidthPx
    d_byte HeightPx_u8, kReloaderMachineHeightPx
    d_word Left_i16, kReloaderInitPlatformLeft
    d_word Top_i16,   $0020
    D_END
    .assert * - :- = kAmmoRackPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kAmmoRackMachineWidthPx
    d_byte HeightPx_u8, kAmmoRackMachineHeightPx
    d_word Left_i16,  $0030
    d_word Top_i16,   $0018
    D_END
    ;; Side walls:
    .assert * - :- = kLeftWallPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, kBossZoneBottomY - kBossZoneTopY
    d_word Left_i16,  $0008
    d_word Top_i16, kBossZoneTopY
    D_END
    .assert * - :- = kRightWallPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, kBossZoneBottomY - kBossZoneTopY
    d_word Left_i16,  $00e0
    d_word Top_i16, kBossZoneTopY
    D_END
    ;; Background bricks:
    .assert * - :- = kBricks1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0040
    d_word Top_i16,   $0058
    D_END
    .assert * - :- = kBricks2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0088
    d_word Top_i16,   $0070
    D_END
    .assert * - :- = kBricks3PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00a8
    d_word Top_i16,   $0040
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   .assert * - :- = kBossDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eRoom::CitySinkhole
    D_END
    .assert * - :- = kBossUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be an upgrade
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 2
    d_byte Target_byte, eFlag::UpgradeBRemote
    D_END
    .assert * - :- = kBossBreakerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be a breaker
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eFlag::BreakerCity
    D_END
    .assert * - :- = kLeverLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 6
    d_byte Target_byte, sState::LeverLeft_u8
    D_END
    .assert * - :- = kLeverRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 8
    d_byte Target_byte, sState::LeverRight_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 1
    d_byte Target_byte, kAmmoRackMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kReloaderMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kLauncherMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC DataC_Boss_City_sBoss
    D_STRUCT sBoss
    d_byte Boss_eFlag, eFlag::BossCity
    d_byte BodyPlatform_u8, kBossBodyPlatformIndex
    d_addr Tick_func_ptr, FuncC_Boss_City_TickBoss
    d_addr Draw_func_ptr, FuncC_Boss_City_DrawBoss
    D_END
.ENDPROC

;;; Maps from sState::BossShellOpen_u8 values to the distance between the
;;; center of the boss and the edge of each shell, in pixels.
.PROC DataC_Boss_City_ShellOffset_u8_arr
    .byte 0, 1, 1, 1, 2, 2, 2, 3, 3, 4, 5, 6, 6, 7, 7, 8, 8, 8, 9, 9, 9, 9, 8
.ENDPROC

.PROC DataC_Boss_CityBlinkTransfer_arr
    ;; Row 2:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow2Start + 3  ; transfer destination
    .byte 2
    .byte $68, $69
    ;; Row 3:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow3Start + 3  ; transfer destination
    .byte 2
    .byte $6a, $6b
.ENDPROC

.PROC DataC_Boss_CityUnblinkTransfer_arr
    ;; Row 2:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow2Start + 3  ; transfer destination
    .byte 2
    .byte $42, $43
    ;; Row 3:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow3Start + 3  ; transfer destination
    .byte 2
    .byte $48, $49
.ENDPROC

;;; Performs per-frame upates for the boss in this room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_City_TickBoss
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
    d_entry table, Dead,        Func_Noop
    d_entry table, Hurt,        _BossHurt
    d_entry table, Open,        _BossOpen
    d_entry table, Close,       _BossClose
    d_entry table, ShootSpines, _BossShootSpines
    d_entry table, Weaving,     _BossWeaving
    D_END
.ENDREPEAT
_BossHurt:
    jsr FuncA_Room_BossCity_OpenShell
    ;; Blink the boss core.
    lda Zp_RoomState + sState::BossCooldown_u8
    and #$02
    beq @unblink
    @blink:
    ldax #DataC_Boss_CityBlinkTransfer_arr  ; param: data pointer
    .assert DataC_Boss_CityBlinkTransfer_arr >= $8000, error
    bmi @doTransfer  ; unconditional
    @unblink:
    ldax #DataC_Boss_CityUnblinkTransfer_arr  ; param: data pointer
    @doTransfer:
    ldy #.sizeof(DataC_Boss_CityBlinkTransfer_arr)  ; param: data length
    .linecont +
    .assert .sizeof(DataC_Boss_CityUnblinkTransfer_arr) = \
            .sizeof(DataC_Boss_CityBlinkTransfer_arr), error
    .linecont -
    jsr Func_BufferPpuTransfer
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; At the end of the hurt animation, decrement the boss's health.  If its
    ;; health is now zero, kill the boss.
    dec Zp_RoomState + sState::BossHealth_u8
    bne @resume  ; boss is not dead yet
    lda #eBossMode::Dead
    sta Zp_RoomState + sState::Current_eBossMode
    jmp FuncA_Room_BossCity_DesolidifyBossPlatforms
    @resume:
    lda #eBossMode::Close
    sta Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_BossOpen:
    jsr FuncA_Room_BossCity_OpenShell
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    jsr Func_GetRandomByte  ; returns N
    bmi _ShootBreakbombs
    @startShootingSpines:
    lda #eBossMode::ShootSpines
    sta Zp_RoomState + sState::Current_eBossMode
    lda #30
    sta Zp_RoomState + sState::BossCooldown_u8
    @done:
    rts
_ShootBreakbombs:
    jsr Func_PlaySfxDrip
    ;; Shoot a pair of breakbombs.
    jsr FuncA_Room_BossCity_SetPointToBossCenter
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs @doneBreakbombs
    jsr Func_SetActorCenterToPoint  ; preserves X
    lda #0  ; param: flags
    jsr FuncA_Room_InitActorProjBreakbomb
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs @doneBreakbombs
    jsr Func_SetActorCenterToPoint  ; preserves X
    lda #bObj::FlipH  ; param: flags
    jsr FuncA_Room_InitActorProjBreakbomb
    @doneBreakbombs:
    ;; Change modes to close the shell.
    lda #eBossMode::Close
    sta Zp_RoomState + sState::Current_eBossMode
    lda #60
    sta Zp_RoomState + sState::BossCooldown_u8
    @done:
    rts
_BossClose:
    jsr FuncA_Room_BossCity_CloseShell
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Move around the room for a random amount of time (between about 1 and 3
    ;; seconds).
    lda #eBossMode::Weaving
    sta Zp_RoomState + sState::Current_eBossMode
    jsr Func_GetRandomByte  ; returns A
    and #$7f
    add #60
    sta Zp_RoomState + sState::BossCooldown_u8
    @done:
    rts
_BossWeaving:
    jsr FuncA_Room_BossCity_CloseShell
    jsr FuncA_Room_BossCity_MoveBossHorz
    jsr FuncA_Room_BossCity_MoveBossVert
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Wait for the boss's vertical position to be valid for opening its shell.
    jsr FuncA_Room_BossCity_SetPointToBossCenter
    lda Zp_PointY_i16 + 0
    cmp #kBossMinCenterOpenY
    blt @done
    cmp #kBossMaxCenterOpenY + 1
    bge @done
    ;; Change modes to open the shell.
    lda #eBossMode::Open
    sta Zp_RoomState + sState::Current_eBossMode
    lda #90
    sta Zp_RoomState + sState::BossCooldown_u8
    @done:
    rts
_BossShootSpines:
    jsr FuncA_Room_BossCity_CloseShell
    ;; Wait for the shell to be fully closed.
    lda Zp_RoomState + sState::BossCooldown_u8
    cmp #kBossSpineSlowdown * 5
    bge @done
    mod #kBossSpineSlowdown
    bne @done
    lda Zp_RoomState + sState::BossCooldown_u8
    div #kBossSpineSlowdown
    sta T3  ; spine index
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs @doneSpine
    jsr FuncA_Room_BossCity_SetPointToBossCenter  ; preserves X and T0+
    ldy T3  ; spine index
    lda _SpineOffsetX_i8_arr5, y
    jsr Func_MovePointHorz  ; preserves X, Y, and T0+
    lda #14
    jsr Func_MovePointDownByA  ; preserves X, Y, and T0+
    jsr Func_SetActorCenterToPoint  ; preserves X, Y, and T0+
    lda _SpineAngle_u8_arr5, y  ; param: spine angle
    jsr FuncA_Room_InitActorProjSpine  ; preserves X and T3+
    @doneSpine:
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Chamge modes to stay closed for a bit.
    lda #eBossMode::Close
    sta Zp_RoomState + sState::Current_eBossMode
    lda #90
    sta Zp_RoomState + sState::BossCooldown_u8
    @done:
    rts
_SpineOffsetX_i8_arr5:
    .byte 0, <-11, 11, <-21, 21
_SpineAngle_u8_arr5:
    .byte $40, $57, $29, $60, $20
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_City_DrawRoom
    jsr FuncA_Objects_DrawBoss
    ldx #kLeftWallPlatformIndex  ; param: platform index
    ldy Zp_RoomState + sState::LeftWallDamage_u8  ; param: damage pattern
    lda #kTileIdObjPlatformCityWalls + 2  ; param: first tile ID
    fall FuncC_Boss_City_DrawSideWall
.ENDPROC

;;; Draws one of the side walls in this room, using the given damage pattern.
;;; If bit N of Y is set, that means that the Nth block down (starting from
;;; zero) has been damaged.
;;; @prereq PRGA_Objects is loaded.
;;; @param A The first tile ID to use.
;;; @param X The platform index for the side wall.
;;; @param Y The bit pattern to use for wall damage.
.PROC FuncC_Boss_City_DrawSideWall
    sta T3  ; first tile ID
    sty T2  ; damage pattern
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves T0+
    ldx #(kBossZoneBottomY - kBossZoneTopY) / kBlockHeightPx
    @loop:
    ldy #0  ; param: object flags
    lda T3  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X and T0+
    ldy #0  ; param: object flags
    lda T3  ; param: tile ID
    lsr T2  ; damage pattern
    bcc @noDamage
    ora #$01
    @noDamage:
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X and T0+
    dex
    bne @loop
    rts
.ENDPROC

;;; Draw function for the city boss.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_City_DrawBoss
    lda #<.bank(Ppu_ChrBgBossCity)
    sta Zp_Chr04Bank_u8
_SetShapePosition:
    ;; Set the shape position to the center of the boss's body.
    ldx #kBossBodyPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    lda #kBossBodyWidthPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #kBossBodyHeightPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
_SetUpIrq:
    ;; Compute the IRQ latch value to set between the bottom of the boss's zone
    ;; and the top of the window (if any), and set that as Param4_byte.
    lda Zp_Buffered_sIrq + sIrq::Latch_u8
    sub #kBossZoneBottomY
    add Zp_RoomScrollY_u8
    sta Zp_Buffered_sIrq + sIrq::Param4_byte  ; window latch
    ;; Set up our own sIrq struct to handle boss movement.
    lda #kBossZoneTopY - 1
    sub Zp_RoomScrollY_u8
    sta Zp_Buffered_sIrq + sIrq::Latch_u8
    ldax #Int_BossCityZoneTopIrq
    stax Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr
    ;; Compute the PPU scroll-X value for the boss zone.
    lda #kBossBgStartCol * kTileWidthPx + kBossBgWidthPx / 2
    sub Zp_ShapePosX_i16 + 0
    sta Zp_Buffered_sIrq + sIrq::Param1_byte  ; boss scroll-X
    ;; Compute the PPU scroll-Y value for the bottom part of the boss's zone.
    lda #kBossBgStartRow * kTileHeightPx + kBossBgHeightPx - kBossShellHeightPx
    ldx Zp_RoomState + sState::BossShellOpen_u8
    sub DataC_Boss_City_ShellOffset_u8_arr, x
    sta Zp_Buffered_sIrq + sIrq::Param2_byte  ; boss lower scroll-Y
    ;; Compute the latch value to use between the top and middle boss zone
    ;; IRQs.
    lda Zp_ShapePosY_i16 + 0
    sub #kBossZoneTopY + 1
    add Zp_RoomScrollY_u8
    sta Zp_Buffered_sIrq + sIrq::Param3_byte  ; top-to-middle latch
_DrawRightWall:
    ldx #kRightWallPlatformIndex  ; param: platform index
    ldy #%01001  ; param: damage pattern
    lda #kTileIdObjPlatformCityWalls + 0  ; param: first tile ID
    jsr FuncC_Boss_City_DrawSideWall
_DrawBackgroundTerrainObjects:
    ldx #kBricks3PlatformIndex
    @loop:
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    ldy #bObj::Pri  ; param: object flags
    lda #kTileIdObjPlatformCityBricks  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    dex
    cpx #kBricks1PlatformIndex
    .assert kBricks1PlatformIndex > 0, error
    bge @loop
    rts
.ENDPROC

.PROC FuncC_Boss_CityLauncher_ReadReg
    cmp #$f
    bne FuncC_Boss_City_ReadRegLR
_RegY:
    lda #kLauncherMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kLauncherPlatformIndex  ; param: distance
    jmp Func_DivAByBlockSizeAndClampTo9  ; returns A
.ENDPROC

.PROC FuncC_Boss_CityReloader_ReadReg
    cmp #$e
    bne FuncC_Boss_City_ReadRegLR
_RegX:
    lda Ram_PlatformLeft_i16_0_arr + kReloaderPlatformIndex
    sub #kReloaderMinPlatformLeft - kTileWidthPx  ; param: distance
    jmp Func_DivAByBlockSizeAndClampTo9  ; returns A
.ENDPROC

;;; Reads the shared "L" or "R" lever register for the BossCityLauncher and
;;; BossCityReloader machines.
;;; @param A The register to read ($c or $d).
;;; @return A The value of the register (0-9).
.PROC FuncC_Boss_City_ReadRegLR
    cmp #$d
    beq _RegR
_RegL:
    lda Zp_RoomState + sState::LeverLeft_u8
    rts
_RegR:
    lda Zp_RoomState + sState::LeverRight_u8
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_BossCity_EnterRoom
    ldax #DataC_Boss_City_sBoss  ; param: sBoss ptr
    jsr FuncA_Room_InitBoss  ; sets Z if boss is alive
    bne FuncA_Room_BossCity_DesolidifyBossPlatforms  ; boss is dead
_BossIsAlive:
    lda #kBossInitHealth
    sta Zp_RoomState + sState::BossHealth_u8
    lda #kBossInitCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #eBossMode::Close
    sta Zp_RoomState + sState::Current_eBossMode
    rts
.ENDPROC

.PROC FuncA_Room_BossCity_TickRoom
    ;; Check for a rocket (in this room, it's not possible for there to be more
    ;; than one on screen at once).
    lda #eActor::ProjRocket  ; param: actor type
    jsr Func_FindActorWithType  ; returns C and X
    bcs @done  ; no rocket found
    ;; Check if the rocket has hit a platform (other than its launcher).
    jsr Func_SetPointToActorCenter  ; preserves X
    jsr Func_IsPointInAnySolidPlatform  ; preserves X, returns C and Y
    bcc @done  ; no collision
    cpy #kLauncherPlatformIndex
    beq @done  ; still exiting launcher
    ;; If the rocket hits the reloader, explode the rocket and shake the room.
    cpy #kReloaderPlatformIndex
    beq @shakeRoom
    ;; If the rocket hits the boss's core, make the boss react to getting hit.
    cpy #kBossCorePlatformIndex
    bne @notBossCore
    lda #eSample::BossHurtE  ; param: eSample to play
    jsr Func_PlaySfxSample  ; preserves X and Y
    lda #eBossMode::Hurt
    sta Zp_RoomState + sState::Current_eBossMode
    lda #kBossHurtCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    .assert kBossHurtCooldown > 0, error
    bne @explodeRocket  ; unconditional
    @notBossCore:
    ;; If the rocket hits the left wall, damage the wall.
    cpy #kLeftWallPlatformIndex
    bne @explodeRocket
    lda Ram_ActorPosY_i16_0_arr, x
    sbc #kBossZoneTopY  ; carry bit is already set from the CPY
    div #kBlockHeightPx
    tay  ; damage bit index
    lda Data_PowersOfTwo_u8_arr8, y
    ora Zp_RoomState + sState::LeftWallDamage_u8
    sta Zp_RoomState + sState::LeftWallDamage_u8
    @shakeRoom:
    lda #kRocketShakeFrames  ; param: num frames
    jsr Func_ShakeRoom  ; preserves X
    @explodeRocket:
    jsr Func_InitActorSmokeExplosion
    jsr Func_PlaySfxExplodeBig
    @done:
_TickBoss:
    .assert eBossMode::Dead = 0, error
    lda Zp_RoomState + sState::Current_eBossMode  ; param: zero if boss dead
    jmp FuncA_Room_TickBoss
.ENDPROC

;;; Changes the boss's shell/core platforms' types from Harm to Zone.  Call
;;; this when the boss is dead.
.PROC FuncA_Room_BossCity_DesolidifyBossPlatforms
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kBossCorePlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kBossShellUpperPlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kBossShellLowerPlatformIndex
    rts
.ENDPROC

;;; Opens the boss's shell by one step.
;;; @prereq PRGC_Boss is loaded.
.PROC FuncA_Room_BossCity_OpenShell
    lda Zp_RoomState + sState::BossShellOpen_u8
    cmp #.sizeof(DataC_Boss_City_ShellOffset_u8_arr) - 1
    bge @done
    inc Zp_RoomState + sState::BossShellOpen_u8
    bne FuncA_Room_BossCity_AdjustShellPlatformsVert  ; unconditional
    @done:
    rts
.ENDPROC

;;; Closes the boss's shell by one step.
;;; @prereq PRGC_Boss is loaded.
.PROC FuncA_Room_BossCity_CloseShell
    lda Zp_RoomState + sState::BossShellOpen_u8
    bne @open
    rts
    @open:
    dec Zp_RoomState + sState::BossShellOpen_u8
    fall FuncA_Room_BossCity_AdjustShellPlatformsVert
.ENDPROC

;;; Adjusts the boss's two shell platforms to their correct vertical position,
;;; based on the boss's vertical position and on BossShellOpen_u8.
;;; @prereq PRGC_Boss is loaded.
.PROC FuncA_Room_BossCity_AdjustShellPlatformsVert
    jsr FuncA_Room_BossCity_SetPointToBossCenter
    ldx Zp_RoomState + sState::BossShellOpen_u8
    lda DataC_Boss_City_ShellOffset_u8_arr, x  ; param: offset
    pha  ; shell offset
    jsr Func_MovePointDownByA
    ldx #kBossShellLowerPlatformIndex  ; param: platform index
    lda #127  ; param: max move by
    jsr Func_MovePlatformTopTowardPointY
    pla  ; shell offset
    mul #2  ; clears carry bit
    adc #kBossShellHeightPx
    jsr Func_MovePointUpByA
    ldx #kBossShellUpperPlatformIndex  ; param: platform index
    lda #127  ; param: max move by
    jmp Func_MovePlatformTopTowardPointY
.ENDPROC

;;; Stores the room pixel position of the center of the boss in Zp_Point*_i16.
;;; @preserve X, T0+
.PROC FuncA_Room_BossCity_SetPointToBossCenter
    ldy #kBossBodyPlatformIndex  ; param: platform index
    jmp Func_SetPointToPlatformCenter  ; preserves X and T0+
.ENDPROC

;;; Moves the boss horizontally, with sinusoidal motion.
.PROC FuncA_Room_BossCity_MoveBossHorz
    inc Zp_RoomState + sState::BossHorzTheta_u8
    ;; Store the horizontal goal position for the left of the boss's body
    ;; platform in Zp_PointX_i16.
    lda Zp_RoomState + sState::BossHorzTheta_u8
    jsr Func_Sine  ; returns A (param: signed multiplicand)
    ldy #kBossHorzAmplitude  ; param: unsigned multiplier
    jsr Func_SignedMult  ; returns YA
    tya
    add #kBossInitCenterX - kBossBodyWidthPx / 2
    sta Zp_PointX_i16 + 0
    lda #0
    sta Zp_PointX_i16 + 1
_MovePlatforms:
    ldx #kBossBodyPlatformIndex  ; param: platform index
    lda #127  ; param: max move by
    jsr Func_MovePlatformLeftTowardPointX  ; returns A
    pha  ; move delta
    ldx #kBossCorePlatformIndex  ; param: platform index
    jsr Func_MovePlatformHorz
    pla  ; param: move delta
    pha  ; move delta
    ldx #kBossShellUpperPlatformIndex  ; param: platform index
    jsr Func_MovePlatformHorz
    pla  ; param: move delta
    ldx #kBossShellLowerPlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
.ENDPROC

;;; Moves the boss vertically, with sinusoidal motion.
.PROC FuncA_Room_BossCity_MoveBossVert
    ;; Increase vertical speed as the boss takes damage.
    lda #kBossInitHealth + 4
    sub Zp_RoomState + sState::BossHealth_u8
    div #2
    add Zp_RoomState + sState::BossVertTheta_u8
    sta Zp_RoomState + sState::BossVertTheta_u8
    ;; Store the vertical goal position for the top of the boss's body platform
    ;; in Zp_PointY_i16.
    jsr Func_Sine  ; returns A (param: signed multiplicand)
    ldy #kBossVertAmplitude  ; param: unsigned multiplier
    jsr Func_SignedMult  ; returns YA
    tya
    add #kBossInitCenterY - kBossBodyHeightPx / 2
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
_MovePlatforms:
    ldx #kBossBodyPlatformIndex  ; param: platform index
    lda #127  ; param: max move by
    jsr Func_MovePlatformTopTowardPointY  ; returns A
    pha  ; move delta
    ldx #kBossCorePlatformIndex  ; param: platform index
    jsr Func_MovePlatformVert
    pla  ; param: move delta
    pha  ; move delta
    ldx #kBossShellUpperPlatformIndex  ; param: platform index
    jsr Func_MovePlatformVert
    pla  ; param: move delta
    ldx #kBossShellLowerPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
.ENDPROC

.PROC FuncA_Room_BossCityLauncher_InitReset
    lda #kLauncherInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLauncherMachineIndex
    rts
.ENDPROC

.PROC FuncA_Room_BossCityReloader_InitReset
    lda #kReloaderInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kReloaderMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Shared WriteReg implementation for the BossCityLauncher, BossCityReloader,
;;; and BossCityAmmoRack machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
;;; @param X The register to write to ($c-$f).
.PROC FuncA_Machine_BossCity_WriteReg
    cpx #$d
    beq _WriteR
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_BossCityLauncher_TryMove
    lda #kLauncherMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncA_Machine_BossCityReloader_TryMove
    lda #kReloaderMaxGoalX  ; param: max goal horz
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncA_Machine_BossCityLauncher_TryAct
    lda #eDir::Left  ; param: rocket direction
    jmp FuncA_Machine_LauncherTryAct
.ENDPROC

.PROC FuncA_Machine_BossCityReloader_TryAct
    ldx Ram_MachineGoalHorz_u8_arr + kReloaderMachineIndex
    lda Ram_MachineState1_byte_arr + kReloaderMachineIndex  ; ammo count
    beq _TryPickUpAmmo
_TryDropOffAmmo:
    ;; Error unless the reloader and launcher machines are lined up.
    cpx #kReloaderMaxGoalX
    blt _Error
    lda Ram_PlatformTop_i16_0_arr + kLauncherPlatformIndex
    cmp #<kLauncherMinPlatformTop
    bne _Error
    ;; Error if the launcher machine already has a rocket loaded.
    lda Ram_MachineState1_byte_arr + kLauncherMachineIndex  ; ammo count
    bne _Error
    jsr FuncA_Machine_PlaySfxRocketTransfer
    dec Ram_MachineState1_byte_arr + kReloaderMachineIndex  ; ammo count
    inc Ram_MachineState1_byte_arr + kLauncherMachineIndex  ; ammo count
    bne _StartWaiting  ; unconditional
_TryPickUpAmmo:
    cpx #kNumAmmoRackSlots
    bge _Error
    lda Data_PowersOfTwo_u8_arr8, x
    bit Ram_MachineState1_byte_arr + kAmmoRackMachineIndex  ; ammo slot bits
    beq _Error
    eor #$ff
    and Ram_MachineState1_byte_arr + kAmmoRackMachineIndex  ; ammo slot bits
    sta Ram_MachineState1_byte_arr + kAmmoRackMachineIndex  ; ammo slot bits
    inc Ram_MachineState1_byte_arr + kReloaderMachineIndex  ; ammo count
    jsr FuncA_Machine_PlaySfxRocketTransfer
_StartWaiting:
    lda #kReloaderActCountdown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
_Error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncA_Machine_BossCityLauncher_Tick
    ldax #kLauncherMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_GenericMoveTowardGoalVert  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

.PROC FuncA_Machine_BossCityReloader_Tick
    ldax #kReloaderMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

.PROC DataA_Terrain_BossCityInitTransfer_arr
    .assert kBossBgWidthTiles = 8, error
    .assert kBossBgHeightTiles = 6, error
    ;; Row 0:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow0Start + 1  ; transfer destination
    .byte 6
    .assert kTileIdBgBossCityFirst = $40, error
    .byte $4c, $4d, $4e, $4f, $50, $51
    ;; Row 1:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow1Start  ; transfer destination
    .byte 8
    .byte $52, $53, $54, $55, $56, $57, $58, $59
    ;; Row 2:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow2Start + 1  ; transfer destination
    .byte 6
    .byte $40, $41, $42, $43, $44, $45
    ;; Row 3:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow3Start + 1  ; transfer destination
    .byte 6
    .byte $46, $47, $48, $49, $4a, $4b
    ;; Row 4:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow4Start  ; transfer destination
    .byte 8
    .byte $5a, $5b, $5c, $5d, $5e, $5f, $60, $61
    ;; Row 5:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow5Start + 1  ; transfer destination
    .byte 6
    .byte $62, $63, $64, $65, $66, $67
    ;; Attributes:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossCoreAttrs  ; transfer destination
    .byte 1
    .byte $11
.ENDPROC

.PROC FuncA_Terrain_BossCity_FadeInRoom
    ldax #DataA_Terrain_BossCityInitTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataA_Terrain_BossCityInitTransfer_arr)  ; param: data length
    jmp Func_BufferPpuTransfer
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top of the boss's zone in the BossCity
;;; room.  Sets the horizontal and vertical scroll so as to make the boss's
;;; upper shell BG tiles appear to move.
.PROC Int_BossCityZoneTopIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Set up the
    ;; next IRQ.
    lda Zp_Active_sIrq + sIrq::Param3_byte  ; top-to-middle latch
    jsr Func_AckIrqAndSetLatch  ; preserves Y
    ldax #Int_BossCityZoneMiddleIrq
    stax Zp_NextIrq_int_ptr
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the lower
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #3 << 2  ; nametable number << 2
    sta Hw_PpuAddr_w2
    lda #kBossBgStartRow * kTileHeightPx * 2 + kBossBgHeightPx - 1
    sub Zp_Active_sIrq + sIrq::Param2_byte  ; boss lower scroll-Y
    sub Zp_Active_sIrq + sIrq::Param3_byte  ; top-to-middle latch
    sta Hw_PpuScroll_w2
    and #$38
    mul #4
    sta Zp_IrqTmp_byte  ; ((Y & $38) << 2)
    lda Zp_Active_sIrq + sIrq::Param1_byte  ; boss scroll-X
    tax  ; new scroll-X value
    div #8
    ora Zp_IrqTmp_byte
    ;; We should now be in the second HBlank.
    stx Hw_PpuScroll_w2
    sta Hw_PpuAddr_w2  ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;; HBlank IRQ handler function for the middle of the boss's zone in the
;;; BossCity room.  Sets the horizontal and vertical scroll so as to make the
;;; boss's lower shell BG tiles appear to move.
.PROC Int_BossCityZoneMiddleIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Set up the
    ;; next IRQ.  Note that we have to compute the middle-to-bottom latch value
    ;; from the top-to-middle latch value (since we don't have enough params to
    ;; store both directly).
    lda #kBossZoneBottomY - kBossZoneTopY - 2
    sub Zp_Active_sIrq + sIrq::Param3_byte  ; top-to-middle latch
    jsr Func_AckIrqAndSetLatch  ; preserves Y
    ldax #Int_BossCityZoneBottomIrq
    stax Zp_NextIrq_int_ptr
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    .repeat 3  ; This value is hand-tuned to help wait for second HBlank.
    nop
    .endrepeat
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the lower
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #3 << 2  ; nametable number << 2
    sta Hw_PpuAddr_w2
    lda Zp_Active_sIrq + sIrq::Param2_byte  ; boss lower scroll-Y
    sta Hw_PpuScroll_w2
    and #$38
    mul #4
    sta Zp_IrqTmp_byte  ; ((Y & $38) << 2)
    lda Zp_Active_sIrq + sIrq::Param1_byte  ; boss scroll-X
    tax  ; new scroll-X value
    div #8
    ora Zp_IrqTmp_byte
    ;; We should now be in the second HBlank.
    stx Hw_PpuScroll_w2
    sta Hw_PpuAddr_w2  ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;; HBlank IRQ handler function for the bottom of the boss's zone in the
;;; BossCity room.  Sets the horizontal and vertical scroll so as to make the
;;; bottom of the room look normal.
.PROC Int_BossCityZoneBottomIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ and prepare for the next one.
    jsr Func_AckIrqAndLatchWindowFromParam4  ; preserves Y
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
