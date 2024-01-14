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
.INCLUDE "../actors/orc.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/blaster.inc"
.INCLUDE "../machines/laser.inc"
.INCLUDE "../machines/shared.inc"
.INCLUDE "../machines/winch.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../music.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../scroll.inc"

.IMPORT DataA_Room_Core_sTileset
.IMPORT Data_Empty_sDialog
.IMPORT FuncA_Machine_BlasterHorzTryAct
.IMPORT FuncA_Machine_BlasterTickMirrors
.IMPORT FuncA_Machine_BlasterWriteRegMirrors
.IMPORT FuncA_Machine_CannonTick
.IMPORT FuncA_Machine_CannonTryAct
.IMPORT FuncA_Machine_CannonTryMove
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericMoveTowardGoalVert
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_GetWinchHorzSpeed
.IMPORT FuncA_Machine_GetWinchVertSpeed
.IMPORT FuncA_Machine_LaserTryAct
.IMPORT FuncA_Machine_LaserWriteReg
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Machine_WinchReachedGoal
.IMPORT FuncA_Machine_WinchStartFalling
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawBlasterMachineHorz
.IMPORT FuncA_Objects_DrawBlasterMirror
.IMPORT FuncA_Objects_DrawCannonMachine
.IMPORT FuncA_Objects_DrawLaserMachine
.IMPORT FuncA_Objects_DrawWinchMachineWithSpikeball
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_HarmAvatarIfWithinLaserBeam
.IMPORT FuncA_Room_MachineBlasterReset
.IMPORT FuncA_Room_MachineCannonReset
.IMPORT FuncA_Room_ReflectFireblastsOffMirror
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorBadGronta
.IMPORT Func_InitActorSmokeFragment
.IMPORT Func_IsFlagSet
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MachineBlasterReadRegMirrors
.IMPORT Func_MachineCannonReadRegY
.IMPORT Func_MachineLaserReadRegC
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_Noop
.IMPORT Func_ResetWinchMachineState
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetMachineIndex
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Ppu_ChrObjBoss2
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState2_byte_arr
.IMPORT Ram_MachineState3_byte_arr
.IMPORT Ram_MachineState4_byte_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_BreakerBeingActivated_eFlag
.IMPORTZP Zp_Camera_bScroll
.IMPORTZP Zp_DialogAnsweredYes_bool
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState
.IMPORTZP Zp_ScrollGoalX_u16

;;;=========================================================================;;;

;;; The actor index for Gronta in this room.
kGrontaActorIndex = 0

;;; The machine indices for the machines in this room.
kWinchMachineIndex   = 0
kBlasterMachineIndex = 1
kLaserMachineIndex   = 2
kCannonMachineIndex  = 3

;;; The platform indices for the machines in this room.
kWinchPlatformIndex     = 0
kSpikeballPlatformIndex = 1
kBlasterPlatformIndex   = 2
kMirror1PlatformIndex   = 3
kMirror2PlatformIndex   = 4
kLaserPlatformIndex     = 5
kCannonPlatformIndex    = 6
;;; The platform index for the zone that triggers the boss fight cutscene when
;;; the player avatar stands in it.
kCutsceneZonePlatformIndex = 7
;;; The platform index for the wall that blocks the passage during the boss
;;; fight.
kPassageBarrierPlatformIndex = 8

;;; The initial values for the blaster's M/R mirror registers.
kBlasterInitGoalM = 4
kBlasterInitGoalR = 4
;;; The initial and maximum permitted values for the blaster's Y register.
kBlasterInitGoalY = 2
kBlasterMaxGoalY  = 2

;;; The maximum and initial Y-positions for the top of the blaster platform.
.LINECONT +
kBlasterMaxPlatformTop = $0060
kBlasterInitPlatformTop = \
    kBlasterMaxPlatformTop - kBlasterInitGoalY * kBlockHeightPx
.LINECONT -

;;; The mirrors' offsets from relative to absolute angles, in increments of
;;; tau/16.
kMirror1AngleOffset = 12
kMirror2AngleOffset = 8

;;; The initial and maximum permitted horizontal goal values for the laser.
kLaserInitGoalX = 0
kLaserMaxGoalX = 4

;;; The maximum and initial X-positions for the left of the laser platform.
.LINECONT +
kLaserMinPlatformLeft = $0020
kLaserInitPlatformLeft = \
    kLaserMinPlatformLeft + kLaserInitGoalX * kBlockWidthPx
.LINECONT -

;;; The initial and maximum permitted values for the winch's X and Z registers.
kWinchInitGoalX = 0
kWinchMaxGoalX  = 2
kWinchInitGoalZ = 0
kWinchMaxGoalZ  = 6

;;; The minimum and initial room pixel position for the left edge of the winch.
.LINECONT +
kWinchMinPlatformLeft = $50
kWinchInitPlatformLeft = \
    kWinchMinPlatformLeft + kBlockWidthPx * kWinchInitGoalX
.LINECONT -

;;; The minimum and initial room pixel position for the top edge of the
;;; spikeball.
.LINECONT +
kSpikeballMinPlatformTop = $22
kSpikeballInitPlatformTop = \
    kSpikeballMinPlatformTop + kBlockHeightPx * kWinchInitGoalZ
.LINECONT -

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; True ($ff) if the Gronta cutscene has already been started; false ($00)
    ;; otherwise.
    TalkedToGronta_bool .byte
    ;; True ($ff) if the player chose to give the B-Remote to Gronta; false
    ;; ($00) otherwise.
    GaveUpRemote_bool .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Core"

.EXPORT DataC_Core_Boss_sRoom
.PROC DataC_Core_Boss_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0110
    d_byte Flags_bRoom, bRoom::Unsafe | bRoom::Tall | eArea::Core
    d_byte MinimapStartRow_u8, 1
    d_byte MinimapStartCol_u8, 13
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 4
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss2)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_CoreBoss_EnterRoom
    d_addr FadeIn_func_ptr, FuncC_Core_Boss_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_CoreBoss_TickRoom
    d_addr Draw_func_ptr, FuncA_Objects_CoreBoss_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/core_boss.room"
    .assert * - :- = 33 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kWinchMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CoreBossWinch
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveHV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Winch
    d_word ScrollGoalX_u16, $010
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, 0, "X", "Z"
    d_byte MainPlatform_u8, kWinchPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_CoreBossWinch_InitReset
    d_addr ReadReg_func_ptr, FuncC_Core_BossWinch_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CoreBossWinch_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CoreBossWinch_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_CoreBossWinch_Tick
    d_addr Draw_func_ptr, FuncA_Objects_CoreBossWinch_Draw
    d_addr Reset_func_ptr, FuncA_Room_CoreBossWinch_InitReset
    D_END
    .assert * - :- = kBlasterMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CoreBossBlaster
    d_byte Breaker_eFlag, 0
    .linecont +
    d_byte Flags_bMachine, bMachine::FlipH | bMachine::MoveV | \
                           bMachine::Act | bMachine::WriteCD
    .linecont -
    d_byte Status_eDiagram, eDiagram::LauncherLeft  ; TODO
    d_word ScrollGoalX_u16, $0110
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "M", "R", 0, "Y"
    d_byte MainPlatform_u8, kBlasterPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_CoreBossBlaster_Init
    d_addr ReadReg_func_ptr, FuncC_Core_BossBlaster_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BlasterWriteRegMirrors
    d_addr TryMove_func_ptr, FuncA_Machine_CoreBossBlaster_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_BlasterHorzTryAct
    d_addr Tick_func_ptr, FuncA_Machine_CoreBossBlaster_Tick
    d_addr Draw_func_ptr, FuncA_Objects_CoreBossBlaster_Draw
    d_addr Reset_func_ptr, FuncA_Room_CoreBossBlaster_Reset
    D_END
    .assert * - :- = kLaserMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CoreBossLaser
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::Laser
    d_word ScrollGoalX_u16, $010
    d_byte ScrollGoalY_u8, $a0
    d_byte RegNames_u8_arr4, "C", 0, "X", 0
    d_byte MainPlatform_u8, kLaserPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_CoreBossLaser_InitReset
    d_addr ReadReg_func_ptr, FuncC_Core_BossLaser_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_LaserWriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_CoreBossLaser_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CoreBossLaser_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_CoreBossLaser_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLaserMachine
    d_addr Reset_func_ptr, FuncA_Room_CoreBossLaser_InitReset
    D_END
    .assert * - :- = kCannonMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CoreBossCannon
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::FlipH | bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::CannonLeft
    d_word ScrollGoalX_u16, $110
    d_byte ScrollGoalY_u8, $a0
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kCannonPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, Func_MachineCannonReadRegY
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CannonTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CannonTryAct
    d_addr Tick_func_ptr, FuncA_Machine_CannonTick
    d_addr Draw_func_ptr, FuncA_Objects_DrawCannonMachine
    d_addr Reset_func_ptr, FuncA_Room_MachineCannonReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kWinchPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16, kWinchInitPlatformLeft
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kSpikeballPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kSpikeballWidthPx
    d_byte HeightPx_u8, kSpikeballHeightPx
    d_word Left_i16, kWinchInitPlatformLeft + 2
    d_word Top_i16, kSpikeballInitPlatformTop
    D_END
    .assert * - :- = kBlasterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBlasterMachineWidthPx
    d_byte HeightPx_u8, kBlasterMachineHeightPx
    d_word Left_i16, $01f0
    d_word Top_i16, kBlasterInitPlatformTop
    D_END
    .assert * - :- = kMirror1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01c4
    d_word Top_i16,   $0064
    D_END
    .assert * - :- = kMirror2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01c4
    d_word Top_i16,   $00c4
    D_END
    .assert * - :- = kLaserPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLaserMachineWidthPx
    d_byte HeightPx_u8, kLaserMachineHeightPx
    d_word Left_i16, kLaserInitPlatformLeft
    d_word Top_i16,   $00e0
    D_END
    .assert * - :- = kCannonPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBlockWidthPx
    d_byte HeightPx_u8, kBlockHeightPx
    d_word Left_i16, $01f0
    d_word Top_i16,  $012c
    D_END
    .assert * - :- = kCutsceneZonePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $e0
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00a0
    d_word Top_i16,   $0060
    D_END
    .assert * - :- = kPassageBarrierPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0018
    d_word Top_i16,   $0140
    D_END
    ;; Top corners of reactor:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00f0
    d_word Top_i16,   $0078
    D_END
    ;; Wide radius of reactor:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $50
    d_byte HeightPx_u8, $40
    d_word Left_i16,  $00e8
    d_word Top_i16,   $00a8
    D_END
    ;; Narrow radius of reactor:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $a8
    d_word Left_i16,  $00f8
    d_word Top_i16,   $0070
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kGrontaActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, $0110
    d_word PosY_i16, $0068
    d_byte Param_byte, eNpcOrc::GrontaStanding
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 2
    d_byte Target_byte, kWinchMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 31
    d_byte Target_byte, kBlasterMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 6
    d_byte Target_byte, kLaserMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 28
    d_byte Target_byte, kCannonMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::CoreLock
    d_byte SpawnBlock_u8, 21
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Core_Boss_FadeInRoom
    ;; Only redraw circuits if the circuit activation cutscene is playing (in
    ;; this room, the player avatar will be hidden iff that's the case).
    lda Zp_AvatarPose_eAvatar
    .assert eAvatar::Hidden = 0, error
    bne _Return
_RedrawCircuits:
    ldx #kLastBreakerFlag
    @loop:
    cpx Zp_BreakerBeingActivated_eFlag
    beq @currentBreaker
    jsr Func_IsFlagSet  ; preserves X, returns Z
    bne @continue
    lda #$00  ; param: tile ID base
    beq @redraw  ; unconditional
    @currentBreaker:
    lda #$c0  ; param: tile ID base
    @redraw:
    jsr FuncC_Core_Boss_RedrawCircuit  ; preserves X
    @continue:
    dex
    cpx #kFirstBreakerFlag
    bge @loop
_Return:
    rts
.ENDPROC

;;; Redraws tiles for a breaker circuit for the circuit activation cutscene.
;;; @prereq Rendering is disabled.
;;; @param A The tile ID base to use.
;;; @param X The eFlag::Breaker* value for the circuit to redraw.
;;; @preserve X
.PROC FuncC_Core_Boss_RedrawCircuit
    sta T2  ; tile ID base
    stx T3  ; eFlag::Breaker* value
_GetTransferEntries:
    txa  ; eFlag::Breaker* value
    sub #kFirstBreakerFlag
    tay  ; eBreaker value
    lda DataC_Core_Boss_BreakerTransfers_arr_ptr_0_arr, y
    sta T0  ; transfer ptr (lo)
    lda DataC_Core_Boss_BreakerTransfers_arr_ptr_1_arr, y
    sta T1  ; transfer ptr (hi)
_ReadHeader:
    ldy #0
    lda (T1T0), y  ; PPU control byte
    sta Hw_PpuCtrl_wo
    iny
    lda (T1T0), y  ; PPU destination address (lo)
    sta T4         ; PPU destination address (lo)
    iny
    lda (T1T0), y  ; PPU destination address (hi)
    iny
_WriteToPpu:
    bne @entryBegin  ; unconditional
    @entryLoop:
    iny
    ;; At this point, A holds the PPU address offset.
    add T4  ; PPU destination address (lo)
    sta T4  ; PPU destination address (lo)
    lda #0
    adc T5  ; PPU destination address (hi)
    @entryBegin:
    sta T5  ; PPU destination address (hi)
    sta Hw_PpuAddr_w2
    lda T4  ; PPU destination address (lo)
    sta Hw_PpuAddr_w2
    lda (T1T0), y  ; tile ID index
    iny
    tax  ; tile ID index
    lda (T1T0), y  ; transfer length
    iny
    sta T6  ; transfer length
    @dataLoop:
    lda DataC_Core_Boss_CircuitTiles_u8_arr, x
    ora T2  ; tile ID base
    sta Hw_PpuData_rw
    inx
    dec T6  ; transfer length
    bne @dataLoop
    lda (T1T0), y  ; PPU address offset
    bne @entryLoop
    ldx T3  ; eFlag::Breaker* value (to preserve X)
    rts
.ENDPROC

;;; Maps from eBreaker enum values to PPU transfer arrays.
.REPEAT 2, table
    D_TABLE_LO table, DataC_Core_Boss_BreakerTransfers_arr_ptr_0_arr
    D_TABLE_HI table, DataC_Core_Boss_BreakerTransfers_arr_ptr_1_arr
    D_TABLE .enum, eBreaker
    d_entry table, Garden, DataC_Core_Boss_CircuitGardenTransfer_arr
    d_entry table, Temple, DataC_Core_Boss_CircuitTempleTransfer_arr
    d_entry table, Crypt,  DataC_Core_Boss_CircuitCryptTransfer_arr
    d_entry table, Lava,   DataC_Core_Boss_CircuitLavaTransfer_arr
    d_entry table, Mine,   DataC_Core_Boss_CircuitMineTransfer_arr
    d_entry table, City,   DataC_Core_Boss_CircuitCityTransfer_arr
    d_entry table, Shadow, DataC_Core_Boss_CircuitShadowTransfer_arr
    D_END
.ENDREPEAT

.PROC DataC_Core_Boss_CircuitGardenTransfer_arr
    .byte kPpuCtrlFlagsHorz  ; control flags
    .addr $21d3              ; destination address
_Row0:
    .byte $03  ; tile ID offset
    .byte 1    ; transfer length
    .byte $20  ; address offset
_Row1:
    .byte $02  ; tile ID offset
    .byte 2    ; transfer length
    .byte $20  ; address offset
_Row2:
    .byte $01  ; tile ID offset
    .byte 3    ; transfer length
    .byte $20  ; address offset
_Row3:
    .byte $00  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row4:
    .byte $40  ; tile ID offset
    .byte 10   ; transfer length
    .byte $21  ; address offset
_Row5:
    .byte $27  ; tile ID offset
    .byte 9    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitTempleTransfer_arr
    .byte kPpuCtrlFlagsHorz  ; control flags
    .addr $2716              ; destination address
_Row0:
    .byte $20  ; tile ID offset
    .byte 7    ; transfer length
    .byte $1f  ; address offset
_Row1:
    .byte $10  ; tile ID offset
    .byte 8    ; transfer length
    .byte $1f  ; address offset
_Row2:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row3:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $20  ; address offset
_Row4:
    .byte $05  ; tile ID offset
    .byte 3    ; transfer length
    .byte $20  ; address offset
_Row5:
    .byte $06  ; tile ID offset
    .byte 2    ; transfer length
    .byte $60  ; address offset
_Row6:
    .byte $07  ; tile ID offset
    .byte 1    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitCryptTransfer_arr
    .byte kPpuCtrlFlagsHorz  ; control flags
    .addr $2c1a              ; destination address
_Row0:
    .byte $20  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row1:
    .byte $10  ; tile ID offset
    .byte 5    ; transfer length
    .byte $1f  ; address offset
_Row2:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row3:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row4:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row5:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row6:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row7:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $20  ; address offset
_Row8:
    .byte $05  ; tile ID offset
    .byte 3    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitLavaTransfer_arr
    .byte kPpuCtrlFlagsHorz  ; control flags
    .addr $2c06              ; destination address
_Row0:
    .byte $33  ; tile ID offset
    .byte 4    ; transfer length
    .byte $20  ; address offset
_Row1:
    .byte $1b  ; tile ID offset
    .byte 5    ; transfer length
    .byte $22  ; address offset
_Row2:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row3:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row4:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row5:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row6:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row7:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row8:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitMineTransfer_arr
    .byte kPpuCtrlFlagsHorz  ; control flags
    .addr $2707              ; destination address
_Row0:
    .byte $30  ; tile ID offset
    .byte 7    ; transfer length
    .byte $20  ; address offset
_Row1:
    .byte $18  ; tile ID offset
    .byte 8    ; transfer length
    .byte $25  ; address offset
_Row2:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row3:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row4:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row5:
    .byte $08  ; tile ID offset
    .byte 3    ; transfer length
    .byte $61  ; address offset
_Row6:
    .byte $08  ; tile ID offset
    .byte 2    ; transfer length
    .byte $21  ; address offset
_Row7:
    .byte $08  ; tile ID offset
    .byte 1    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitCityTransfer_arr
    .byte kPpuCtrlFlagsHorz ; control flags
    .addr $21b1             ; destination address
_Row0:
    .byte $0c  ; tile ID offset
    .byte 1    ; transfer length
    .byte $1f  ; address offset
_Row1:
    .byte $0c  ; tile ID offset
    .byte 2    ; transfer length
    .byte $1f  ; address offset
_Row2:
    .byte $0c  ; tile ID offset
    .byte 3    ; transfer length
    .byte $1f  ; address offset
_Row3:
    .byte $0c  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row4:
    .byte $0c  ; tile ID offset
    .byte 4    ; transfer length
    .byte $19  ; address offset
_Row5:
    .byte $4a  ; tile ID offset
    .byte 10   ; transfer length
    .byte $20  ; address offset
_Row6:
    .byte $37  ; tile ID offset
    .byte 9    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitShadowTransfer_arr
    .byte kPpuCtrlFlagsVert  ; control flags
    .addr $2ca1              ; destination address
_Col0:
    .byte $54  ; tile ID offset
    .byte 4    ; transfer length
    .byte $01  ; address offset
_Col1:
    .byte $58  ; tile ID offset
    .byte 4    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitTiles_u8_arr
    ;; $00
    .byte $33, $32, $31, $30
    .byte $34, $35, $36, $37
    .byte $3b, $3a, $39, $38
    .byte $3c, $3d, $3e, $3f
    ;; $10
    .byte $34, $35, $36, $2b, $2b, $2b, $2b, $2b
    .byte $2d, $2d, $2d, $2d, $2d, $3a, $39, $38
    ;; $20
    .byte $34, $2a, $2a, $2a, $2a, $2a, $2a
    .byte $33, $2b, $2b, $2b, $2b, $2b, $2b, $2b, $2b
    ;; $30
    .byte $2c, $2c, $2c, $2c, $2c, $2c, $38
    .byte $2d, $2d, $2d, $2d, $2d, $2d, $2d, $2d, $3f
    ;; $40
    .byte $33, $32, $31, $2a, $2a, $2a, $2a, $2a, $2a, $2a
    .byte $2c, $2c, $2c, $2c, $2c, $2c, $2c, $3d, $3e, $3f
    ;; $54
    .byte $2e, $2e, $2e, $2e
    .byte $2f, $2f, $2f, $2f
.ENDPROC

.PROC FuncC_Core_BossBlaster_ReadReg
    cmp #$f
    beq _ReadY
    jmp Func_MachineBlasterReadRegMirrors
_ReadY:
    lda #kBlasterMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kBlasterPlatformIndex
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Core_BossLaser_ReadReg
    cmp #$e
    beq _ReadX
_ReadC:
    jmp Func_MachineLaserReadRegC
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kLaserPlatformIndex
    sub #kLaserMinPlatformLeft - kTileHeightPx
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Core_BossWinch_ReadReg
    cmp #$e
    beq _ReadX
_ReadZ:
    lda Ram_PlatformTop_i16_0_arr + kSpikeballPlatformIndex
    sub #kSpikeballMinPlatformTop - kTileHeightPx
    div #kBlockHeightPx
    rts
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kWinchPlatformIndex
    sub #kWinchMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_CoreBossLaser_TryMove
    lda #kLaserMaxGoalX  ; param: max goal horz
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncA_Machine_CoreBossLaser_TryAct
    ldx Ram_MachineGoalHorz_u8_arr + kLaserMachineIndex
    lda _LaserBottom_i16_0_arr, x  ; param: laser bottom (lo)
    ldy _LaserBottom_i16_1_arr, x  ; param: laser bottom (hi)
    jmp FuncA_Machine_LaserTryAct
_LaserBottom_i16_0_arr:
:   .byte $f0, $60, $60, $50, $10
    .assert * - :- = kLaserMaxGoalX + 1, error
_LaserBottom_i16_1_arr:
:   .byte $00, $01, $01, $01, $01
    .assert * - :- = kLaserMaxGoalX + 1, error
.ENDPROC

.PROC FuncA_Machine_CoreBossLaser_Tick
    ldax #kLaserMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

.PROC FuncA_Machine_CoreBossWinch_TryMove
    ldy Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    .assert eDir::Up = 0, error
    txa
    beq _MoveUp
    cpx #eDir::Down
    beq _MoveDown
_MoveHorz:
    cpx #eDir::Left
    beq @moveLeft
    @moveRight:
    cpy #kWinchMaxGoalX
    bge _Error
    iny
    bne @checkFloor  ; unconditional
    @moveLeft:
    tya
    beq _Error
    dey
    @checkFloor:
    lda DataA_Machine_CoreBossWinchFloor_u8_arr, y
    cmp Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    blt _Error
    sty Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_MoveUp:
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    beq _Error
    dec Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_MoveDown:
    lda DataA_Machine_CoreBossWinchFloor_u8_arr, y
    cmp Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    beq _Error
    inc Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_Error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncA_Machine_CoreBossWinch_TryAct
    ldy Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    lda DataA_Machine_CoreBossWinchFloor_u8_arr, y  ; param: new Z-goal
    jmp FuncA_Machine_WinchStartFalling
.ENDPROC

.PROC FuncA_Machine_CoreBossWinch_Tick
_MoveVert:
    ;; Calculate the desired room-space pixel Y-position for the top edge of
    ;; the spikeball, storing it in Zp_PointY_i16.
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    mul #kBlockHeightPx
    adc #kSpikeballMinPlatformTop  ; carry is already clear
    .linecont +
    .assert kWinchMaxGoalZ * kBlockHeightPx + \
            kSpikeballMinPlatformTop < $100, error
    .linecont -
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jsr FuncA_Machine_GetWinchVertSpeed  ; preserves X, returns Z and A
    bne @move
    rts
    @move:
    ;; Move the spikeball vertically, as necessary.
    jsr Func_MovePlatformTopTowardPointY  ; returns Z and A
    beq @reachedGoal
    rts
    @reachedGoal:
_MoveHorz:
    ;; Calculate the desired X-position for the left edge of the winch, in
    ;; room-space pixels, storing it in Zp_PointX_i16.
    lda Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    mul #kBlockWidthPx
    adc #<kWinchMinPlatformLeft  ; carry is already clear
    sta Zp_PointX_i16 + 0
    .linecont +
    .assert kWinchMaxGoalX * kBlockWidthPx + \
            kWinchMinPlatformLeft < $100, error
    .linecont -
    lda #0
    sta Zp_PointX_i16 + 1
    ;; Move the winch horizontally, if necessary.
    jsr FuncA_Machine_GetWinchHorzSpeed  ; returns A
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftTowardPointX  ; returns Z and A
    beq @reachedGoal
    ;; If the winch moved, move the spikeball platform too.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @reachedGoal:
_Finished:
    jmp FuncA_Machine_WinchReachedGoal
.ENDPROC

.PROC DataA_Machine_CoreBossWinchFloor_u8_arr
    .byte 2, 6, 6
.ENDPROC

.PROC FuncA_Machine_CoreBossBlaster_TryMove
    lda #kBlasterMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncA_Machine_CoreBossBlaster_Tick
    ldax #kBlasterMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_GenericMoveTowardGoalVert  ; returns A
    sta T1  ; nonzero if moved
    jsr FuncA_Machine_BlasterTickMirrors  ; preserves T1+, returns A
    ora T1  ; nonzero if moved
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_CoreBoss_EnterRoom
    lda Zp_Next_eCutscene
    .assert eCutscene::None = 0, error
    beq @done
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kGrontaActorIndex
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_CoreBoss_TickRoom
    ;; If the avatar is hidden for a circuit activation cutscene, we're done.
    lda Zp_AvatarPose_eAvatar
    .assert eAvatar::Hidden = 0, error
    beq _Return
_TalkToGronta:
    ;; If the Gronta cutscene has already played, no need to start it.
    bit Zp_RoomState + sState::TalkedToGronta_bool
    bmi @done
    ;; If the player avatar isn't standing in the cutscene-starting zone, don't
    ;; start it yet.
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Airborne = bProc::Negative, error
    bmi @done
    jsr Func_SetPointToAvatarCenter
    ldy #kCutsceneZonePlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcc @done
    ;; Start the cutscene.
    lda #$ff
    sta Zp_RoomState + sState::TalkedToGronta_bool
    lda #eCutscene::CoreBossStartBattle
    sta Zp_Next_eCutscene
    @done:
_Mirror1:
    lda Ram_MachineState3_byte_arr + kBlasterMachineIndex  ; mirror 1 anim
    div #kBlasterMirrorAnimSlowdown
    add #kMirror1AngleOffset  ; param: absolute mirror angle
    ldy #kMirror1PlatformIndex  ; param: mirror platform index
    jsr FuncA_Room_ReflectFireblastsOffMirror
_Mirror2:
    lda Ram_MachineState4_byte_arr + kBlasterMachineIndex  ; mirror 2 anim
    div #kBlasterMirrorAnimSlowdown
    add #kMirror2AngleOffset  ; param: absolute mirror angle
    ldy #kMirror2PlatformIndex  ; param: mirror platform index
    jsr FuncA_Room_ReflectFireblastsOffMirror
_Laser:
    ldx #kLaserMachineIndex
    jsr Func_SetMachineIndex
    jsr FuncA_Room_HarmAvatarIfWithinLaserBeam
    ;; TODO: hurt Gronta if the laser hits her
_Return:
    rts
.ENDPROC

.PROC FuncA_Room_CoreBossWinch_InitReset
    lda #kWinchInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    lda #kWinchInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp Func_ResetWinchMachineState
.ENDPROC

.PROC FuncA_Room_CoreBossBlaster_Init
    lda #kBlasterInitGoalM * kBlasterMirrorAnimSlowdown
    sta Ram_MachineState3_byte_arr + kBlasterMachineIndex  ; mirror 1 anim
    lda #kBlasterInitGoalR * kBlasterMirrorAnimSlowdown
    sta Ram_MachineState4_byte_arr + kBlasterMachineIndex  ; mirror 2 anim
    .assert * = FuncA_Room_CoreBossBlaster_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncA_Room_CoreBossBlaster_Reset
    jsr FuncA_Room_MachineBlasterReset
    lda #kBlasterInitGoalM
    sta Ram_MachineState1_byte_arr + kBlasterMachineIndex  ; mirror 1 goal
    lda #kBlasterInitGoalR
    sta Ram_MachineState2_byte_arr + kBlasterMachineIndex  ; mirror 2 goal
    lda #kBlasterInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kBlasterMachineIndex
    rts
.ENDPROC

.PROC FuncA_Room_CoreBossLaser_InitReset
    lda #kLaserInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kLaserMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_CoreBoss_DrawRoom
_PassageBarrier:
    lda Ram_PlatformType_ePlatform_arr + kPassageBarrierPlatformIndex
    cmp #kFirstSolidPlatformType
    blt @done
    ldx #kPassageBarrierPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx #3
    @loop:
    ldy _BarrierFlags_bObj_arr, x  ; param: object flags
    lda _BarrierTileId_u8_arr, x  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    dex
    bpl @loop
    @done:
    rts
_BarrierFlags_bObj_arr:
    .byte 0, 0, 0, bObj::FlipV
_BarrierTileId_u8_arr:
    .byte kTileIdObjMachineCorner
    .byte kTileIdObjMachineSurfaceVert
    .byte kTileIdObjMachineSurfaceVert
    .byte kTileIdObjMachineCorner
.ENDPROC

;;; Draws the CoreBossWinch machine.
.PROC FuncA_Objects_CoreBossWinch_Draw
    ldx #kSpikeballPlatformIndex  ; param: spikeball platform index
    jmp FuncA_Objects_DrawWinchMachineWithSpikeball
.ENDPROC

;;; Draws the CoreBossBlaster machine.
.PROC FuncA_Objects_CoreBossBlaster_Draw
    jsr FuncA_Objects_DrawBlasterMachineHorz
_Mirror1:
    ldx #kMirror1PlatformIndex  ; param: mirror platform index
    lda Ram_MachineState3_byte_arr + kBlasterMachineIndex  ; mirror 1 anim
    div #kBlasterMirrorAnimSlowdown
    add #kMirror1AngleOffset  ; param: absolute mirror angle
    jsr FuncA_Objects_DrawBlasterMirror
_Mirror2:
    ldx #kMirror2PlatformIndex  ; param: mirror platform index
    lda Ram_MachineState4_byte_arr + kBlasterMachineIndex  ; mirror 2 anim
    div #kBlasterMirrorAnimSlowdown
    add #kMirror2AngleOffset  ; param: absolute mirror angle
    jmp FuncA_Objects_DrawBlasterMirror
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_CoreBossStartBattle_sCutscene
.PROC DataA_Cutscene_CoreBossStartBattle_sCutscene
    act_CallFunc _SetupFunc
    act_SetAvatarState 0
    act_SetAvatarVelX 0
    act_SetActorState2 kGrontaActorIndex, $ff
    act_BranchIfZ _GetHorzScreen, _LeftSide_sCutscene
_RightSide_sCutscene:
    act_WalkAvatar $0168
    act_SetAvatarFlags kPaletteObjAvatarNormal | bObj::FlipH
    act_ForkStart 0, _IntroDialog_sCutscene
_LeftSide_sCutscene:
    act_SetActorFlags kGrontaActorIndex, bObj::FlipH
    act_WalkAvatar $00b8
    act_SetAvatarFlags kPaletteObjAvatarNormal
_IntroDialog_sCutscene:
    act_SetAvatarPose eAvatar::Standing
    act_RunDialog eDialog::CoreBossGrontaIntro
    act_BranchIfZ _ShouldGiveUpRemoteFunc, _BeginFight_sCutscene
_GiveUpRemote_sCutscene:
    act_PlayMusic eMusic::Silence
    act_WaitFrames 20
    act_SetAvatarPose eAvatar::Kneeling
    act_WaitFrames 20
    act_SetAvatarPose eAvatar::Reaching
    act_CallFunc _SpawnActorForRemote
    act_WaitFrames 20
    act_SetAvatarPose eAvatar::Standing
    ;; TODO: animate Gronta catching the remote
    act_WaitFrames 60
    act_RunDialog eDialog::CoreBossGrontaGive
    ;; TODO: animate core activating
    act_ContinueExploring
_BeginFight_sCutscene:
    act_PlayMusic eMusic::Boss2
    act_WaitFrames 210  ; TODO: animate Gronta getting ready to fight
    act_SetScrollFlags 0
    act_CallFunc _ChangeGrontaFromNpcToBad
    ;; TODO: Handle Gronta's mode-setting in TickRoom rather than here.
    act_SetActorState1 kGrontaActorIndex, eBadGronta::ThrowWindup
    act_SetActorState2 kGrontaActorIndex, 60
    act_ContinueExploring
_SetupFunc:
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kPassageBarrierPlatformIndex
    ldax #$0090
    stax Zp_ScrollGoalX_u16
    rts
_GetHorzScreen:
    lda Zp_AvatarPosX_i16 + 1
    rts
_ShouldGiveUpRemoteFunc:
    lda Zp_RoomState + sState::GaveUpRemote_bool
    rts
_SpawnActorForRemote:
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs @done
    jsr Func_SetPointToAvatarCenter  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    lda #40  ; param: frames until expire
    jsr Func_InitActorSmokeFragment  ; preserves X
    lda #<-3
    sta Ram_ActorVelY_i16_1_arr, x
    lda Zp_AvatarPosX_i16 + 1
    bne @rightSide
    @leftSide:
    lda #2
    bne @setVelX  ; unconditional
    @rightSide:
    lda #<-2
    @setVelX:
    sta Ram_ActorVelX_i16_1_arr, x
    @done:
    rts
_ChangeGrontaFromNpcToBad:
    ldx #kGrontaActorIndex  ; param: actor index
    lda Ram_ActorFlags_bObj_arr + kGrontaActorIndex  ; param: flags
    jmp Func_InitActorBadGronta
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_CoreBossGrontaIntro_sDialog
.PROC DataA_Dialog_CoreBossGrontaIntro_sDialog
    dlg_Text OrcGronta, DataA_Text1_CoreBossGrontaIntro_Part1_u8_arr
    dlg_Text OrcGronta, DataA_Text1_CoreBossGrontaIntro_Part2_u8_arr
    dlg_Text OrcGronta, DataA_Text1_CoreBossGrontaIntro_Demand_u8_arr
    dlg_Func _DemandFunc
_DemandFunc:
    bit Zp_DialogAnsweredYes_bool
    bmi @yes
    @no:
    ldya #_PreparedToFight_sDialog
    rts
    @yes:
    ldya #_HandItOver_sDialog
    rts
_HandItOver_sDialog:
    dlg_Text OrcGronta, DataA_Text1_CoreBossGrontaIntro_HandItOver_u8_arr
    dlg_Func _HandItOverFunc
_HandItOverFunc:
    bit Zp_DialogAnsweredYes_bool
    bmi @yes
    @no:
    ldya #_PreparedToFight_sDialog
    rts
    @yes:
    lda #$ff
    sta Zp_RoomState + sState::GaveUpRemote_bool
    bne _EndDialogFunc  ; unconditional
_PreparedToFight_sDialog:
    dlg_Text OrcGronta, DataA_Text1_CoreBossGrontaIntro_PreparedToFight_u8_arr
    dlg_Func _PreparedToFightFunc
_PreparedToFightFunc:
    bit Zp_DialogAnsweredYes_bool
    bmi @yes
    @no:
    ldya #_HandItOver_sDialog
    rts
    @yes:
_EndDialogFunc:
    lda #bScroll::LockHorz
    sta Zp_Camera_bScroll
    ldya #Data_Empty_sDialog
    rts
.ENDPROC

.EXPORT DataA_Dialog_CoreBossGrontaGive_sDialog
.PROC DataA_Dialog_CoreBossGrontaGive_sDialog
    dlg_Text OrcGrontaShout, DataA_Text1_CoreBossGrontaGive_Part1_u8_arr
    dlg_Text OrcGronta, DataA_Text1_CoreBossGrontaGive_Part2_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text1"

.PROC DataA_Text1_CoreBossGrontaIntro_Part1_u8_arr
    .byte "Ahhhh...here you are,$"
    .byte "little human. You have$"
    .byte "the remote, don't you?#"
.ENDPROC

.PROC DataA_Text1_CoreBossGrontaIntro_Part2_u8_arr
    .byte "The remote that will$"
    .byte "determine whether it$"
    .byte "will be orcs or humans$"
    .byte "that rule this place.#"
.ENDPROC

.PROC DataA_Text1_CoreBossGrontaIntro_Demand_u8_arr
    .byte "I demand that you give$"
    .byte "it to me!%"
.ENDPROC

.PROC DataA_Text1_CoreBossGrontaIntro_HandItOver_u8_arr
    .byte "You're just going to$"
    .byte "hand it over, then?%"
.ENDPROC

.PROC DataA_Text1_CoreBossGrontaIntro_PreparedToFight_u8_arr
    .byte "Oh ho! Then are you$"
    .byte "prepared to fight me?%"
.ENDPROC

.PROC DataA_Text1_CoreBossGrontaGive_Part1_u8_arr
    .byte "Bwahahaha! What a$"
    .byte "coward!#"
.ENDPROC

.PROC DataA_Text1_CoreBossGrontaGive_Part2_u8_arr
    .byte "Now we orcs shall take$"
    .byte "our rightful place as$"
    .byte "masters of this world!#"
.ENDPROC

;;;=========================================================================;;;
