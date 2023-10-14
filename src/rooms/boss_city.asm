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
.IMPORT FuncA_Room_InitBoss
.IMPORT FuncA_Room_TickBoss
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjCity
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The machine index for the BossCityLauncher machine.
kLauncherMachineIndex = 0
;;; The machine index for the BossCityReloader machine.
kReloaderMachineIndex = 1
;;; The machine index for the BossCityAmmoRack machine.
kAmmoRackMachineIndex = 2

;;; The platform index for the BossCityLauncher machine.
kLauncherPlatformIndex = 1
;;; The platform index for the BossCityReloader machine.
kReloaderPlatformIndex = 2
;;; The platform index for the BossCityAmmoRack machine.
kAmmoRackPlatformIndex = 3

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

;;; Modes that the boss in this room can be in.
.ENUM eBossMode
    Dead
    ;; TODO: other modes
    NUM_VALUES
.ENDENUM

;;; How many rocket hits are needed to defeat the boss.
kBossInitHealth = 8

;;; How many frames the boss waits, after you first enter the room, before
;;; taking action.
kBossInitCooldown = 120

;;; The platform index for the boss's body.
kBossBodyPlatformIndex = 0

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
    d_addr Enter_func_ptr, FuncC_Boss_City_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Boss_City_TickRoom
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
    d_addr Init_func_ptr, FuncC_Boss_CityLauncher_InitReset
    d_addr ReadReg_func_ptr, FuncC_Boss_CityLauncher_ReadReg
    d_addr WriteReg_func_ptr, FuncC_Boss_City_WriteReg
    d_addr TryMove_func_ptr, FuncC_Boss_CityLauncher_TryMove
    d_addr TryAct_func_ptr, FuncC_Boss_CityLauncher_TryAct
    d_addr Tick_func_ptr, FuncC_Boss_CityLauncher_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLauncherMachineHorz
    d_addr Reset_func_ptr, FuncC_Boss_CityLauncher_InitReset
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
    d_addr Init_func_ptr, FuncC_Boss_CityReloader_InitReset
    d_addr ReadReg_func_ptr, FuncC_Boss_CityReloader_ReadReg
    d_addr WriteReg_func_ptr, FuncC_Boss_City_WriteReg
    d_addr TryMove_func_ptr, FuncC_Boss_CityReloader_TryMove
    d_addr TryAct_func_ptr, FuncC_Boss_CityReloader_TryAct
    d_addr Tick_func_ptr, FuncC_Boss_CityReloader_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawReloaderMachine
    d_addr Reset_func_ptr, FuncC_Boss_CityReloader_InitReset
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
    d_addr WriteReg_func_ptr, FuncC_Boss_City_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncC_Boss_CityAmmoRack_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_ReachedGoal
    d_addr Draw_func_ptr, FuncA_Objects_DrawAmmoRackMachine
    d_addr Reset_func_ptr, Func_Noop
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kBossBodyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $0040
    d_word Top_i16,   $0050
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

.PROC FuncC_Boss_City_sBoss
    D_STRUCT sBoss
    d_byte Boss_eFlag, eFlag::BossCity
    d_byte BodyPlatform_u8, kBossBodyPlatformIndex
    d_addr Tick_func_ptr, FuncC_Boss_City_TickBoss
    d_addr Draw_func_ptr, FuncC_Boss_City_DrawBoss
    D_END
.ENDPROC

;;; Room init function for the BossCity room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_City_EnterRoom
    ldax #FuncC_Boss_City_sBoss  ; param: sBoss ptr
    jsr FuncA_Room_InitBoss  ; sets Z if boss is alive
    bne _BossIsDead
_BossIsAlive:
    lda #kBossInitHealth
    sta Zp_RoomState + sState::BossHealth_u8
    lda #kBossInitCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #eBossMode::Dead  ; TODO
    sta Zp_RoomState + sState::Current_eBossMode
_BossIsDead:
    rts
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
    D_TABLE .enum, eBossMode
    d_entry table, Dead,   Func_Noop
    D_END
.ENDREPEAT
.ENDPROC

;;; Draw function for the BossCity room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_City_DrawRoom
    ;; TODO: draw side walls
_DrawBoss:
    jmp FuncA_Objects_DrawBoss
.ENDPROC

;;; Draw function for the city boss.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_City_DrawBoss
    ;; TODO: draw the boss
    rts
.ENDPROC

.PROC FuncC_Boss_CityLauncher_InitReset
    lda #kLauncherInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLauncherMachineIndex
    rts
.ENDPROC

.PROC FuncC_Boss_CityReloader_InitReset
    lda #kReloaderInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kReloaderMachineIndex
    rts
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

;;; Shared WriteReg implementation for the BossCityLauncher and
;;; BossCityReloader machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq PRGA_Machine is loaded.
;;; @param A The value to write (0-9).
;;; @param X The register to write to ($c-$f).
.PROC FuncC_Boss_City_WriteReg
    cpx #$d
    beq _WriteR
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncC_Boss_CityLauncher_TryMove
    lda #kLauncherMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncC_Boss_CityReloader_TryMove
    lda #kReloaderMaxGoalX  ; param: max goal horz
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncC_Boss_CityLauncher_TryAct
    lda #eDir::Left  ; param: rocket direction
    jmp FuncA_Machine_LauncherTryAct
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

.PROC FuncC_Boss_CityAmmoRack_TryAct
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

.PROC FuncC_Boss_CityLauncher_Tick
    ldax #kLauncherMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_GenericMoveTowardGoalVert  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

.PROC FuncC_Boss_CityReloader_Tick
    ldax #kReloaderMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;
