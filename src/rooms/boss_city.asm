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
.INCLUDE "../avatar.inc"
.INCLUDE "../boss.inc"
.INCLUDE "../charmap.inc"
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

.IMPORT DataA_Room_Building_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericMoveTowardGoalVert
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_LauncherTryAct
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_DrawAmmoRackMachine
.IMPORT FuncA_Objects_DrawBoss
.IMPORT FuncA_Objects_DrawLauncherMachineHorz
.IMPORT FuncA_Objects_DrawReloaderMachine
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_InitBoss
.IMPORT FuncA_Room_TickBoss
.IMPORT Func_AckIrqAndLatchWindowFromParam4
.IMPORT Func_AckIrqAndSetLatch
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointUpByA
.IMPORT Func_Noop
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Ppu_ChrBgBossCity
.IMPORT Ppu_ChrObjCity
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_IrqTmp_byte
.IMPORTZP Zp_NextIrq_int_ptr
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

;;; How many slots are in the ammo rack.
kNumAmmoRackSlots = 3

;;; The device indices for the levers in this room.
kLeverLeftDeviceIndex = 3
kLeverRightDeviceIndex = 4

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
kBossInitCenterX = $60
kBossInitCenterY = $67

;;; Modes that the boss in this room can be in.
.ENUM eBossMode
    Dead
    Open   ; TODO: replace this with a real mode
    Close  ; TODO: replace this with a real mode
    ;; TODO: other modes
    NUM_VALUES
.ENDENUM

;;; How many rocket hits are needed to defeat the boss.
kBossInitHealth = 8

;;; How many frames the boss waits, after you first enter the room, before
;;; taking action.
kBossInitCooldown = 120

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
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCity)
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
    d_addr FadeIn_func_ptr, FuncC_Boss_City_FadeInRoom
    d_addr Tick_func_ptr, FuncC_Boss_City_TickRoom
    d_addr Draw_func_ptr, FuncA_Objects_DrawBoss
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
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $0000
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", "R", "X", 0
    d_byte MainPlatform_u8, kReloaderPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_BossCityReloader_InitReset
    d_addr ReadReg_func_ptr, FuncC_Boss_CityReloader_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BossCity_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_BossCityReloader_TryMove
    d_addr TryAct_func_ptr, FuncC_Boss_CityReloader_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BossCityReloader_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawReloaderMachine
    d_addr Reset_func_ptr, FuncA_Room_BossCityReloader_InitReset
    D_END
    .assert * - :- = kAmmoRackMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossCityAmmoRack
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::Lift  ; TODO
    d_word ScrollGoalX_u16, $0000
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", "R", 0, 0
    d_byte MainPlatform_u8, kAmmoRackPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Boss_City_ReadRegLR
    d_addr WriteReg_func_ptr, FuncA_Machine_BossCity_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_BossCityAmmoRack_TryAct
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
    d_byte Type_ePlatform, ePlatform::Zone
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
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, kAmmoRackMachineHeightPx
    d_word Left_i16,  $0030
    d_word Top_i16,   $0018
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   .assert * - :- = kBossDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eRoom::CityPit
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
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 6
    d_byte Target_byte, sState::LeverLeft_u8
    D_END
    .assert * - :- = kLeverRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 8
    d_byte Target_byte, sState::LeverRight_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 1
    d_byte Target_byte, kAmmoRackMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kReloaderMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
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

.PROC DataC_Boss_CityTransfer_arr
    .assert kBossBgWidthTiles = 8, error
    .assert kBossBgHeightTiles = 6, error
    ;; Row 0:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow0Start + 1  ; transfer destination
    .byte 6
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

.PROC FuncC_Boss_City_FadeInRoom
    ldax #DataC_Boss_CityTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataC_Boss_CityTransfer_arr)  ; param: data length
    jmp Func_BufferPpuTransfer
.ENDPROC

;;; Room tick function for the BossCity room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_City_TickRoom
    .assert eBossMode::Dead = 0, error
    lda Zp_RoomState + sState::Current_eBossMode  ; param: zero if boss dead
    jmp FuncA_Room_TickBoss
.ENDPROC

;;; Performs per-frame upates for the boss in this room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_City_TickBoss
    ;; TODO check for rocket impact
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
    d_entry table, Dead,  Func_Noop
    d_entry table, Open,  _BossOpen
    d_entry table, Close, _BossClose
    D_END
.ENDREPEAT
_BossOpen:
    jsr FuncC_Boss_City_OpenShell
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    lda #eBossMode::Close
    sta Zp_RoomState + sState::Current_eBossMode
    lda #120
    sta Zp_RoomState + sState::BossCooldown_u8
    @done:
    rts
_BossClose:
    jsr FuncC_Boss_City_CloseShell
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    lda #eBossMode::Open
    sta Zp_RoomState + sState::Current_eBossMode
    lda #90
    sta Zp_RoomState + sState::BossCooldown_u8
    @done:
    rts
.ENDPROC

;;; Draw function for the city boss.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_City_DrawBoss
    lda #<.bank(Ppu_ChrBgBossCity)
    sta Zp_Chr04Bank_u8
_DrawSideWalls:
    ;; TODO: draw side walls
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
_DrawBackgroundTerrainObjects:
    ;; TODO: draw background objects
    rts
.ENDPROC

;;; Opens the boss's shell by one step.
.PROC FuncC_Boss_City_OpenShell
    lda Zp_RoomState + sState::BossShellOpen_u8
    cmp #.sizeof(DataC_Boss_City_ShellOffset_u8_arr) - 1
    bge @done
    inc Zp_RoomState + sState::BossShellOpen_u8
    bne FuncC_Boss_City_AdjustShellPlatformsVert  ; unconditional
    @done:
    rts
.ENDPROC

;;; Closes the boss's shell by one step.
.PROC FuncC_Boss_City_CloseShell
    lda Zp_RoomState + sState::BossShellOpen_u8
    bne @open
    rts
    @open:
    dec Zp_RoomState + sState::BossShellOpen_u8
    .assert * = FuncC_Boss_City_AdjustShellPlatformsVert, error, "fallthrough"
.ENDPROC

;;; Adjusts the boss's two shell platforms to their correct vertical position,
;;; based on the boss's vertical position and on BossShellOpen_u8.
.PROC FuncC_Boss_City_AdjustShellPlatformsVert
    jsr FuncC_Boss_City_SetPointToBossCenter
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
.PROC FuncC_Boss_City_SetPointToBossCenter
    ldy #kBossBodyPlatformIndex  ; param: platform index
    jmp Func_SetPointToPlatformCenter  ; preserves X and T0+
.ENDPROC

.PROC FuncC_Boss_CityLauncher_ReadReg
    cmp #$f
    bne FuncC_Boss_City_ReadRegLR
_RegY:
    lda #kLauncherMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kLauncherPlatformIndex
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Boss_CityReloader_ReadReg
    cmp #$e
    bne FuncC_Boss_City_ReadRegLR
_RegX:
    lda Ram_PlatformLeft_i16_0_arr + kReloaderPlatformIndex
    sub #kReloaderMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
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

.PROC FuncC_Boss_CityReloader_TryAct
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
    ;; TODO: play a sound
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
    ;; TODO: play a sound
_StartWaiting:
    lda #kReloaderActCountdown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
_Error:
    jmp FuncA_Machine_Error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Room init function for the BossCity room.
.PROC FuncA_Room_BossCity_EnterRoom
    ldax #DataC_Boss_City_sBoss  ; param: sBoss ptr
    jsr FuncA_Room_InitBoss  ; sets Z if boss is alive
    bne _BossIsDead
_BossIsAlive:
    lda #kBossInitHealth
    sta Zp_RoomState + sState::BossHealth_u8
    lda #kBossInitCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #eBossMode::Close
    sta Zp_RoomState + sState::Current_eBossMode
_BossIsDead:
    rts
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

.PROC FuncA_Machine_BossCityAmmoRack_TryAct
    ;; Can't refill the ammo rack if it's not empty.
    lda Ram_MachineState1_byte_arr + kAmmoRackMachineIndex  ; ammo slot bits
    jne FuncA_Machine_Error
    ;; Refill all ammo slots.
    lda #(1 << kNumAmmoRackSlots) - 1
    sta Ram_MachineState1_byte_arr + kAmmoRackMachineIndex  ; ammo slot bits
    ;; TODO: play a sound
    lda #kAmmoRackActCountdown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
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
