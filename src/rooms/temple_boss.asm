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
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_TempleAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_TempleAreaName_u8_arr
.IMPORT DataA_Room_Temple_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_DrawCarriageMachine
.IMPORT FuncA_Room_InitActorProjBreakball
.IMPORT FuncA_Room_InitBossPhase
.IMPORT FuncA_Room_TickBossPhase
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjTemple
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_PointX_i16

;;;=========================================================================;;;

;;; The room block row/col where the upgrade will appear.
kUpgradeBlockRow = 12
kUpgradeBlockCol = 4
;;; The eFlag value for the upgrade in this room.
kUpgradeFlag = eFlag::UpgradeMaxInstructions1

;;; The machine index for the TempleBossBlaster machine.
kBlasterMachineIndex = 0
;;; The platform index for the TempleBossBlaster machine.
kBlasterPlatformIndex = 0

;;; The initial and maximum permitted horizontal goal values for the blaster.
kBlasterInitGoalX = 4
kBlasterMaxGoalX = 8

;;; The maximum and initial X-positions for the left of the blaster platform.
.LINECONT +
kBlasterMinPlatformLeft = $0038
kBlasterInitPlatformLeft = \
    kBlasterMinPlatformLeft + kBlasterInitGoalX * kBlockWidthPx
.LINECONT -

;;; The cooldown time between blaster shots, in frames.
kBlasterCooldownFrames = 10

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u1         .byte
    LeverRight_u1        .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Temple"

.EXPORT DataC_Temple_Boss_sRoom
.PROC DataC_Temple_Boss_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $0008
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 3
    d_byte MinimapStartCol_u8, 0
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTemple)
    d_addr Tick_func_ptr, FuncC_Temple_Boss_TickRoom
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_TempleAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_TempleAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Temple_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Init_func_ptr, FuncC_Temple_Boss_InitRoom
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/temple_boss.room"
    .assert * - :- = 17 * 16, error
_Machines_sMachine_arr:
:   .assert * - :- = kBlasterMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::TempleBossBlaster
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Carriage  ; TODO
    d_word ScrollGoalX_u16, $0008
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", "R", "X", 0
    d_byte MainPlatform_u8, kBlasterPlatformIndex
    d_addr Init_func_ptr, FuncC_Temple_BossBlaster_Init
    d_addr ReadReg_func_ptr, FuncC_Temple_BossBlaster_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Temple_BossBlaster_TryMove
    d_addr TryAct_func_ptr, FuncC_Temple_BossBlaster_TryAct
    d_addr Tick_func_ptr, FuncC_Temple_BossBlaster_Tick
    d_addr Draw_func_ptr, FuncA_Objects_TempleBossBlaster_Draw
    d_addr Reset_func_ptr, FuncC_Temple_BossBlaster_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kBlasterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16, kBlasterInitPlatformLeft
    d_word Top_i16,   $00a0
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kBossDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::UnlockedDoor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 8
    d_byte Target_u8, eRoom::TempleBoss  ; TODO
    D_END
    .assert * - :- = kBossUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be an upgrade
    d_byte BlockRow_u8, kUpgradeBlockRow
    d_byte BlockCol_u8, kUpgradeBlockCol
    d_byte Target_u8, kUpgradeFlag
    D_END
    .assert * - :- = kBossBreakerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be a breaker
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 12
    d_byte Target_u8, eFlag::BreakerTemple
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 3
    d_byte Target_u8, kBlasterMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 6
    d_byte Target_u8, sState::LeverLeft_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 10
    d_byte Target_u8, sState::LeverRight_u1
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

;;; Room init function for the GardenBoss room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Temple_Boss_InitRoom
    ldx #eFlag::BossTemple  ; param: boss flag
    jsr FuncA_Room_InitBossPhase  ; sets Z if boss is alive
    beq _InitializeBoss
_BossIsAlreadyDead:
    rts
_InitializeBoss:
    ;; TODO: remove this; initialize the boss instead
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @done
    lda #$c0
    sta Ram_ActorPosX_i16_0_arr, x
    lda #$30
    sta Ram_ActorPosY_i16_0_arr, x
    lda #0
    sta Ram_ActorPosX_i16_1_arr, x
    sta Ram_ActorPosY_i16_1_arr, x
    jsr FuncA_Room_InitActorProjBreakball
    @done:
    rts
.ENDPROC

;;; Room tick function for the TempleBoss room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Temple_Boss_TickRoom
    lda #0  ; param: zero if boss is dead (TODO)
    ldx #eFlag::BossTemple  ; param: boss flag
    jsr FuncA_Room_TickBossPhase
    ;; TODO: tick boss behavior if still alive
    rts
.ENDPROC

.PROC FuncC_Temple_BossBlaster_Init
    .assert * = FuncC_Temple_BossBlaster_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Temple_BossBlaster_Reset
    lda #kBlasterInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kBlasterMachineIndex
    rts
.ENDPROC

.PROC FuncC_Temple_BossBlaster_ReadReg
    cmp #$c
    beq @readL
    cmp #$d
    beq @readR
    @readX:
    lda Ram_PlatformLeft_i16_0_arr + kBlasterPlatformIndex
    sub #kBlasterMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
    @readL:
    lda Ram_RoomState + sState::LeverLeft_u1
    rts
    @readR:
    lda Ram_RoomState + sState::LeverRight_u1
    rts
.ENDPROC

.PROC FuncC_Temple_BossBlaster_TryMove
    ldy Ram_MachineGoalHorz_u8_arr + kBlasterMachineIndex
    cpx #eDir::Right
    bne @moveLeft
    @moveRight:
    cpy #kBlasterMaxGoalX
    bge @error
    iny
    bne @success  ; unconditional
    @moveLeft:
    tya
    beq @error
    dey
    @success:
    sty Ram_MachineGoalHorz_u8_arr + kBlasterMachineIndex
    jmp FuncA_Machine_StartWorking
    @error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncC_Temple_BossBlaster_TryAct
    ;; TODO: shoot a projectile upward
    lda #kBlasterCooldownFrames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

.PROC FuncC_Temple_BossBlaster_Tick
    ;; Calculate the desired X-position for the left edge of the blaster, in
    ;; room-space pixels, storing it in Zp_PointX_i16.
    lda Ram_MachineGoalHorz_u8_arr + kBlasterMachineIndex
    mul #kBlockWidthPx
    add #<kBlasterMinPlatformLeft
    sta Zp_PointX_i16 + 0
    lda #0
    adc #>kBlasterMinPlatformLeft
    sta Zp_PointX_i16 + 1
    ;; Determine the horizontal speed of the blaster (faster if resetting).
    ldx Ram_MachineStatus_eMachine_arr + kBlasterMachineIndex
    lda #1
    cpx #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the blaster horizontally, as necessary.
    ldx #kBlasterPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftTowardPointX  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_TempleBossBlaster_Draw
    jmp FuncA_Objects_DrawCarriageMachine  ; TODO
.ENDPROC

;;;=========================================================================;;;
