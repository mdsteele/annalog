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
.INCLUDE "../actors/dirt.inc"
.INCLUDE "../boss.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../irq.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/blaster.inc"
.INCLUDE "../machines/boiler.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/lava.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../sample.inc"
.INCLUDE "boss_lava.inc"

.IMPORT DataA_Room_Lava_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_BlasterTick
.IMPORT FuncA_Machine_BlasterTryAct
.IMPORT FuncA_Machine_BoilerFinishEmittingSteam
.IMPORT FuncA_Machine_BoilerStartEmittingSteam
.IMPORT FuncA_Machine_BoilerTick
.IMPORT FuncA_Machine_BoilerWriteReg
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_Alloc2x1Shape
.IMPORT FuncA_Objects_AnimateLavaTerrain
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawBlasterMachine
.IMPORT FuncA_Objects_DrawBoilerMachine
.IMPORT FuncA_Objects_DrawBoilerValve
.IMPORT FuncA_Objects_DrawBoss
.IMPORT FuncA_Objects_DrawPlatformVolcanicVert
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_InitActorProjEgg
.IMPORT FuncA_Room_InitActorProjFlamestrike
.IMPORT FuncA_Room_InitBoss
.IMPORT FuncA_Room_MachineBoilerReset
.IMPORT FuncA_Room_PlaySfxSlowWindup
.IMPORT FuncA_Room_ResetLever
.IMPORT FuncA_Room_SetPointToBossBodyCenter
.IMPORT FuncA_Room_TickBoss
.IMPORT FuncA_Room_TurnProjectilesToSmokeIfConsoleOpen
.IMPORT FuncA_Room_TurnSteamToSmokeIfConsoleOpen
.IMPORT FuncA_Terrain_FadeInShortRoomWithLava
.IMPORT Func_AckIrqAndLatchWindowFromParam4
.IMPORT Func_AckIrqAndSetLatch
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_DirectPpuTransfer
.IMPORT Func_DistanceSensorRightDetectPoint
.IMPORT Func_DivAByBlockSizeAndClampTo9
.IMPORT Func_DivMod
.IMPORT Func_EmitSteamUpFromPipe
.IMPORT Func_FindActorWithType
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsActorWithinDistanceOfPoint
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MachineBoilerReadReg
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePlatformVert
.IMPORT Func_MovePointDownByA
.IMPORT Func_Noop
.IMPORT Func_PlaySfxBaddieDeath
.IMPORT Func_PlaySfxSample
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Func_ShootFireballFromPoint
.IMPORT Ppu_ChrBgAnimB0
.IMPORT Ppu_ChrObjBoss2
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_IrqTmp_byte
.IMPORTZP Zp_NextIrq_int_ptr
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_RoomState
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; The device indices for the levers in this room.
kLeverLeftDeviceIndex = 3
kLeverRightDeviceIndex = 4

;;; The machine indices for the machines in this room.
kBlasterMachineIndex = 0
kBoilerMachineIndex  = 1

;;; Platform indices for the machines in this room.
kBlasterPlatformIndex = 0
kSensorPlatformIndex  = 1
kBoilerPlatformIndex  = 2
kValvePlatformIndex   = 3
kPipe1PlatformIndex   = 4
kPipe2PlatformIndex   = 5

;;; The platform indices for the side walls.
kLeftWallPlatformIndex  = 6
kRightWallPlatformIndex = 7

;;; The initial and maximum permitted values for the blaster's X register.
kBlasterInitGoalX = 0
kBlasterMaxGoalX  = 9

;;; The minimum and initial X-positions for the left of the blaster platform.
.LINECONT +
kBlasterMinPlatformLeft = $0030
kBlasterInitPlatformLeft = \
    kBlasterMinPlatformLeft + kBlasterInitGoalX * kBlockWidthPx
.LINECONT -

;;;=========================================================================;;;

;;; The width and height of the boss's BG tile grid.
kBossFullWidthTiles = 8
kBossHeightTiles = 4
kBossFullWidthPx = kBossFullWidthTiles * kTileWidthPx
kBossHeightPx = kBossHeightTiles * kTileHeightPx
;;; The width of the boss's body's hitbox.
kBossBodyWidthPx  = $30
;;; The width and height of the boss's tail's hitbox.
kBossTailWidthPx  = $08
kBossTailHeightPx = $04

;;; The minimum permitted room pixel X-positions for the center and left of the
;;; boss's body.
kBossBodyMinCenterX = $38
kBossBodyMinLeftX   = kBossBodyMinCenterX - kBossBodyWidthPx / 2

;;; The room pixel Y-positions for the top and bottom of the zone that the boss
;;; can move within.
kBossZoneTopY    = $30
kBossZoneBottomY = $80

;;; The boss's initial and maximum goal positions within its zone, measured in
;;; blocks.
kBossInitGoalX = 5
kBossMaxGoalX  = 9
kBossInitGoalY = 0
kBossMaxGoalY  = 3

;;; The initial room pixel position for the top center of the boss's body.
kBossBodyInitCenterX = kBossBodyMinCenterX + kBlockWidthPx * kBossInitGoalX
kBossBodyInitTopY = kBossZoneTopY + kBlockHeightPx * kBossInitGoalY

;;; The tile row/col in the lower nametable for the top-left corner of the
;;; boss's BG tiles.
kBossBgStartRow = 8
kBossBgStartCol = 2

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
.ASSERT kBossBgStartRow .mod 4 = 0, error
.ASSERT (kBossBgStartCol + 2) .mod 4 = 0, error
Ppu_BossBodyAttrs = Ppu_Nametable3_sName + sName::Attrs_u8_arr64 + \
    (kBossBgStartRow / 4) * 8 + ((kBossBgStartCol + 2) / 4)
.LINECONT -

;;; Modes that the boss in this room can be in.
.ENUM eBossMode
    Dead
    EggPrepare          ; move into position to drop an egg
    EggDrop             ; drop an egg
    EggWait             ; wait for the egg to hatch and the solifuge killed
    FiresprayPrepare    ; move into position to shoot a spray of fireballs
    FiresprayWindup     ; open jaws before shooting a spray of fireballs
    FiresprayShoot      ; shoot a spray of fireballs
    FiresprayRecover    ; waiting for a bit after a fireball spray
    FlamestrikePrepare  ; move into position to shoot a flamestrike projectile
    FlamestrikeShoot    ; open jaws and shoot the flamestrike
    FlamestrikeDescend  ; stay in place while the flamestrike descends
    FlamestrikeRetreat  ; move upwards while the flamestrike is paused
    Hurt                ; closing jaws, vibrating in place
    Scuttling           ; moving around randomly
    NUM_VALUES
.ENDENUM

;;; How many blaster hits are needed to defeat the boss.
kBossInitHealth = 6

;;; How many frames the boss waits, after you first enter the room, before
;;; taking action.
kBossInitCooldown = 120
;;; How many frames to vibrate in place when hurt.
kBossHurtCooldown = 60
;;; How many frames to wait between consecutive scuttle actions.
kBossScuttleCooldown = 60
;;; How long to vibrate before shooting a flamestrike or dropping an egg.
kAttackVibrateFrames = 81

;;; The platform indices for the boss's body and tail.
kBossBodyPlatformIndex = 8
kBossTailPlatformIndex = 9

;;; How long it takes the boss's jaws to open or close, in frames.
kBossJawsOpenFrames = 16

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u8       .byte
    LeverRight_u8      .byte
    ;; What mode the boss is in.
    Current_eBossMode  .byte
    ;; For Scuttling mode, this is how many times to scuttle before attacking.
    ;; A new random value is chosen at the end of each scuttling sequence, and
    ;; is persisted during other modes (this allows the value to be persisted
    ;; if scuttling is temporarily interrupted by Hurt mode).
    ScuttleCount_u8    .byte
    ;; For FiresprayShoot mode, any negative value means sweep right to left,
    ;; and any non-negative value means sweep left to right.  Ignored for other
    ;; modes.
    FiresprayDir_i8    .byte
    ;; How many more blaster hits are needed before the boss dies.
    BossHealth_u8      .byte
    ;; Timer that ticks down each frame when nonzero.  Used to time transitions
    ;; between boss modes.
    BossCooldown_u8    .byte
    ;; The goal position for the boss within its zone, in blocks.
    BossGoalX_u8       .byte  ; 0-9
    BossGoalY_u8       .byte  ; 0-3
    ;; How open the boss's jaws are (0 = fully closed, kBossJawsOpenFrames =
    ;; fully open).
    BossJawsOpen_u8    .byte
    ;; The number of solifuge eggs that the boss has dropped so far.
    BossEggsDropped_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Boss"

.EXPORT DataC_Boss_Lava_sRoom
.PROC DataC_Boss_Lava_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte Flags_bRoom, bRoom::Unsafe | eArea::Lava
    d_byte MinimapStartRow_u8, 14
    d_byte MinimapStartCol_u8, 21
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss2)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Lava_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncA_Room_BossLava_EnterRoom
    d_addr FadeIn_func_ptr, FuncC_Boss_Lava_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_BossLava_TickRoom
    d_addr Draw_func_ptr, FuncC_Boss_Lava_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/boss_lava.room"
    .assert * - :- = 16 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kBlasterMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossLavaBlaster
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::Blaster
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", "R", "X", "D"
    d_byte MainPlatform_u8, kBlasterPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_BossLavaBlaster_InitReset
    d_addr ReadReg_func_ptr, FuncC_Boss_LavaBlaster_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BossLava_WriteRegLR
    d_addr TryMove_func_ptr, FuncA_Machine_BossLavaBlaster_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_BlasterTryAct
    d_addr Tick_func_ptr, FuncA_Machine_BossLavaBlaster_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawBlasterMachine
    d_addr Reset_func_ptr, FuncA_Room_BossLavaBlaster_InitReset
    D_END
    .assert * - :- = kBoilerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossLavaBoiler
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteCDE
    d_byte Status_eDiagram, eDiagram::BoilerValve
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $24
    d_byte RegNames_u8_arr4, "L", "R", "V", "D"
    d_byte MainPlatform_u8, kBoilerPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Boss_LavaBoiler_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BossLavaBoiler_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_BossLavaBoiler_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BoilerTick
    d_addr Draw_func_ptr, FuncC_Boss_LavaBoiler_Draw
    d_addr Reset_func_ptr, FuncA_Room_BossLavaBoiler_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kBlasterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBlasterMachineWidthPx
    d_byte HeightPx_u8, kBlasterMachineHeightPx
    d_word Left_i16, kBlasterInitPlatformLeft
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kSensorPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0008
    d_word Top_i16,   $0090
    D_END
    .assert * - :- = kBoilerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $18
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $00d8
    d_word Top_i16,   $00b0
    D_END
    .assert * - :- = kValvePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0084
    d_word Top_i16,   $00b4
    D_END
    .assert * - :- = kPipe1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16,   $00a0
    D_END
    .assert * - :- = kPipe2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00a8
    d_word Top_i16,   $00a0
    D_END
    .assert * - :- = kLeftWallPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $50
    d_word Left_i16,  $0008
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kRightWallPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $50
    d_word Left_i16,  $00f0
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kBossBodyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kBossBodyWidthPx
    d_byte HeightPx_u8, kBossHeightPx
    d_word Left_i16, kBossBodyInitCenterX - kBossBodyWidthPx / 2
    d_word Top_i16, kBossBodyInitTopY
    D_END
    .assert * - :- = kBossTailPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kBossTailWidthPx
    d_byte HeightPx_u8, kBossTailHeightPx
    d_word Left_i16, kBossBodyInitCenterX - kBossTailWidthPx / 2
    d_word Top_i16, kBossBodyInitTopY - kBossTailHeightPx
    D_END
    ;; Girders:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $90
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0038
    d_word Top_i16,   $00b0
    D_END
    ;; Lava:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $100
    d_byte HeightPx_u8, kLavaPlatformHeightPx
    d_word Left_i16,   $0000
    d_word Top_i16, kLavaPlatformTopShortRoom
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   .assert * - :- = kBossDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eRoom::LavaCavern
    D_END
    .assert * - :- = kBossUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be an upgrade
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eFlag::UpgradeRam3
    D_END
    .assert * - :- = kBossBreakerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be a breaker
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eFlag::BreakerLava
    D_END
    .assert * - :- = kLeverLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 4
    d_byte Target_byte, sState::LeverLeft_u8
    D_END
    .assert * - :- = kLeverRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 11
    d_byte Target_byte, sState::LeverRight_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 1
    d_byte Target_byte, kBlasterMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 14
    d_byte Target_byte, kBoilerMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC DataC_Boss_Lava_sBoss
    D_STRUCT sBoss
    d_byte Boss_eFlag, eFlag::BossLava
    d_byte BodyPlatform_u8, kBossBodyPlatformIndex
    d_addr Tick_func_ptr, FuncC_Boss_Lava_TickBoss
    d_addr Draw_func_ptr, FuncC_Boss_Lava_DrawBoss
    D_END
.ENDPROC

;;; Performs per-frame upates for the boss in this room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Lava_TickBoss
_CheckForFireblastHit:
    ;; Check for a fireblast (in this room, it's not possible for there to be
    ;; more than one on screen at once).
    lda #eActor::ProjFireblast  ; param: actor type to find
    jsr Func_FindActorWithType  ; returns C and X
    bcs @done  ; no fireblast found
    ;; Fireblasts can only hit the boss's tail if its jaws/tail are fully open.
    lda Zp_RoomState + sState::BossJawsOpen_u8
    cmp #kBossJawsOpenFrames
    blt @notHitTail  ; tail covering is not fully open
    ;; Check if the fireblast has hit the tail.
    jsr Func_SetPointToActorCenter  ; preserves X
    ldy #kBossTailPlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; preserves X, returns C
    bcs @hitTail
    @notHitTail:
    ;; Check for a hatched solifuge (in this room, it's not possible for there
    ;; to be more than one).
    jsr Func_SetPointToActorCenter
    stx T1  ; fireblast actor index
    lda #eActor::BadSolifuge  ; param: actor type to find
    jsr Func_FindActorWithType  ; preserves T0+, returns C and X
    bcs @done  ; no solifuge found
    ;; Check if the fireblast is hitting the solifuge.
    lda #6  ; param: distance
    jsr Func_IsActorWithinDistanceOfPoint  ; preserves X and T1+, returns C
    bcc @done  ; fireblast is not hitting solifuge
    ;; The fireblast has hit the solifuge, so kill the solifuge and remove the
    ;; fireblast.
    jsr Func_InitActorSmokeExplosion  ; preserves T0+
    jsr Func_PlaySfxBaddieDeath  ; preserves T0+
    ldx T1  ; fireblast actor index
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, y
    .assert eActor::None = 0, error
    beq @done  ; unconditional
    ;; The fireblast has hit the tail, so remove the fireblast.
    @hitTail:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    ;; Make the boss react to getting hit.
    lda #eBossMode::Hurt
    sta Zp_RoomState + sState::Current_eBossMode
    lda #kBossHurtCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #eSample::BossHurtE  ; param: eSample to play
    jsr Func_PlaySfxSample
    ;; Decrement boss health (if nonzero).
    lda Zp_RoomState + sState::BossHealth_u8
    beq @done
    dec Zp_RoomState + sState::BossHealth_u8
    jsr FuncC_Boss_Lava_TransferBossBodyTiles
    @done:
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
    d_entry table, Dead,               Func_Noop
    d_entry table, EggPrepare,         _BossEggPrepare
    d_entry table, EggDrop,            _BossEggDrop
    d_entry table, EggWait,            _BossEggWait
    d_entry table, FiresprayPrepare,   _BossFiresprayPrepare
    d_entry table, FiresprayWindup,    _BossFiresprayWindup
    d_entry table, FiresprayShoot,     _BossFiresprayShoot
    d_entry table, FiresprayRecover,   _BossFiresprayRecover
    d_entry table, FlamestrikePrepare, _BossFlamestrikePrepare
    d_entry table, FlamestrikeShoot,   _BossFlamestrikeShoot
    d_entry table, FlamestrikeDescend, _BossFlamestrikeDescend
    d_entry table, FlamestrikeRetreat, _BossFlamestrikeRetreat
    d_entry table, Hurt,               _BossHurt
    d_entry table, Scuttling,          _BossScuttling
    D_END
.ENDREPEAT
_BossEggPrepare:
    jsr FuncC_Boss_Lava_BossCloseJaws
    ;; Wait until the boss is in position.
    jsr FuncC_Boss_Lava_BossMoveTowardGoal  ; sets C when goal is reached
    bcc _FirstReturn
    ;; Change modes to drop an egg.
    lda #eBossMode::EggDrop
    sta Zp_RoomState + sState::Current_eBossMode
    lda #kAttackVibrateFrames
    sta Zp_RoomState + sState::BossCooldown_u8
    fall _FirstReturn
_FirstReturn:
    rts
_BossFiresprayPrepare:
    jsr FuncC_Boss_Lava_BossCloseJaws
    ;; Wait until the boss is in position.
    jsr FuncC_Boss_Lava_BossMoveTowardGoal  ; sets C when goal is reached
    bcc _FirstReturn
    ;; Change modes to wind up for the spray of fireballs.
    lda #eBossMode::FiresprayWindup
    sta Zp_RoomState + sState::Current_eBossMode
    lda #70
    sta Zp_RoomState + sState::BossCooldown_u8
    jmp FuncA_Room_PlaySfxSlowWindup
    rts
_BossFiresprayWindup:
    jsr FuncC_Boss_Lava_BossOpenJaws
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Change modes to shoot the spray of fireballs.
    lda #eBossMode::FiresprayShoot
    sta Zp_RoomState + sState::Current_eBossMode
    lda #$31
    sta Zp_RoomState + sState::BossCooldown_u8
    jsr Func_GetRandomByte  ; returns A
    sta Zp_RoomState + sState::FiresprayDir_i8
    @done:
    rts
_BossFlamestrikePrepare:
    jsr FuncC_Boss_Lava_BossCloseJaws
    ;; Wait until the boss is in position.
    jsr FuncC_Boss_Lava_BossMoveTowardGoal  ; sets C when goal is reached
    bcc @done
    ;; Change modes to shoot the flamestrike.
    lda #eBossMode::FlamestrikeShoot
    sta Zp_RoomState + sState::Current_eBossMode
    lda #kAttackVibrateFrames
    sta Zp_RoomState + sState::BossCooldown_u8
    @done:
    rts
_BossFlamestrikeShoot:
    jsr FuncC_Boss_Lava_VibrateForCooldownAndOpenJaws  ; sets Z when finished
    bne _SecondReturn  ; still vibrating
    ;; Change modes to wait while the flamestrike descends.
    lda #eBossMode::FlamestrikeDescend
    sta Zp_RoomState + sState::Current_eBossMode
    lda #70
    sta Zp_RoomState + sState::BossCooldown_u8
    ;; Shoot a flamestrike projectile.
    lda #kBossHeightPx / 2 - 1  ; param: offset
    jsr FuncA_Room_BossLava_SetPointBelowBossCenter
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs _SecondReturn
    jsr Func_SetActorCenterToPoint  ; preserves X
    lda #0  ; param: FlipH flag
    jsr FuncA_Room_InitActorProjFlamestrike
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs _SecondReturn
    jsr Func_SetActorCenterToPoint  ; preserves X
    lda #bObj::FlipH  ; param: FlipH flag
    jmp FuncA_Room_InitActorProjFlamestrike
_BossFlamestrikeDescend:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne _SecondReturn
    ;; Change modes to retreat while the flamestrike is paused.
    fall _StartFlamestrikeRetreat
_StartFlamestrikeRetreat:
    lda #0
    sta Zp_RoomState + sState::BossGoalY_u8
    lda #eBossMode::FlamestrikeRetreat
    sta Zp_RoomState + sState::Current_eBossMode
    fall _SecondReturn
_SecondReturn:
    rts
_BossFlamestrikeRetreat:
    jsr FuncC_Boss_Lava_BossCloseJaws
    jsr FuncC_Boss_Lava_BossMoveTowardGoal
    ;; Wait for the flamestrike to disappear.
    lda #eActor::ProjFlamestrike  ; param: actor type to find
    jsr Func_FindActorWithType  ; returns C
    bcs _StartFirespray  ; flamestrike is gone
    rts
_BossEggWait:
    jsr FuncC_Boss_Lava_BossCloseJaws
    ;; Wait until no egg or solifuge exists.
    jsr FuncA_Room_BossLava_DoesEggOrSolifugeExist
    bcc _SecondReturn  ; an egg or solifuge still exists in the room
_StartFirespray:
    ;; Choose a random valid position for shooting a fireball spray.
    jsr Func_GetRandomByte  ; returns A
    and #$07
    add #1
    sta Zp_RoomState + sState::BossGoalX_u8
    lda #1
    sta Zp_RoomState + sState::BossGoalY_u8
    ;; Change modes to move to the firing position and shoot a fireball spray.
    lda #eBossMode::FiresprayPrepare
    sta Zp_RoomState + sState::Current_eBossMode
    rts
_BossEggDrop:
    jsr FuncC_Boss_Lava_VibrateForCooldownAndOpenJaws  ; sets Z when finished
    bne _SecondReturn  ; still vibrating
    ;; Drop an egg.
    lda #kBossHeightPx / 2 + kTileHeightPx / 2  ; param: offset
    jsr FuncA_Room_BossLava_SetPointBelowBossCenter
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs _SecondReturn
    jsr Func_SetActorCenterToPoint  ; preserves X
    jsr FuncA_Room_InitActorProjEgg
    inc Zp_RoomState + sState::BossEggsDropped_u8
    fall _StartEggWait
_StartEggWait:
    lda #eBossMode::EggWait
    sta Zp_RoomState + sState::Current_eBossMode
    rts
_BossHurt:
    ;; Close jaws quickly.
    lda #2  ; param: speedup
    jsr FuncC_Boss_Lava_BossCloseJawsWithSpeedup
    ;; Vibrate in place until the cooldown expires.
    lda Zp_RoomState + sState::BossCooldown_u8
    beq @doneVibrate
    div #2
    and #1    ; param: signed delta
    bne @vibrate
    lda #<-1  ; param: signed delta
    @vibrate:
    ldx #kBossBodyPlatformIndex  ; param: platform index
    pha  ; signed delta
    jsr Func_MovePlatformHorz  ; preserves X
    pla  ; param: signed delta
    ldx #kBossTailPlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @doneVibrate:
    ;; At the end of the hurt animation, if boss's health is now zero, kill the
    ;; boss.
    lda Zp_RoomState + sState::BossHealth_u8
    bne @notDead
    .assert eBossMode::Dead = 0, error
    sta Zp_RoomState + sState::Current_eBossMode
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kBossBodyPlatformIndex
    rts
    @notDead:
    ;; Otherwise, switch modes based on what's happening in the battle.
    lda #eActor::ProjFlamestrike  ; param: actor type to find
    jsr Func_FindActorWithType  ; returns C
    bcc _StartFlamestrikeRetreat  ; a flamestrike exists in the room
    jsr FuncA_Room_BossLava_DoesEggOrSolifugeExist  ; returns C
    bcc _StartEggWait  ; an egg or solifuge exists in the room
    fall _StartNextScuttle
_StartNextScuttle:
    lda #eBossMode::Scuttling
    sta Zp_RoomState + sState::Current_eBossMode
    ;; Pick a new goal position.
    jsr Func_GetRandomByte  ; returns A (param: dividend)
    ldy #kBossMaxGoalX + 1  ; param: divisor
    jsr Func_DivMod  ; returns remainder in A
    sta Zp_RoomState + sState::BossGoalX_u8
    jsr Func_GetRandomByte  ; returns A (param: dividend)
    .assert kBossMaxGoalY = 3, error
    mod #4
    sta Zp_RoomState + sState::BossGoalY_u8
    fall _ThirdReturn
_ThirdReturn:
    rts
_BossFiresprayShoot:
    ;; Only shoot every eight frames.
    lda Zp_RoomState + sState::BossCooldown_u8
    and #$07
    bne @done
    ;; Shoot a fireball.
    lda #kBossHeightPx / 2 + kTileHeightPx / 2  ; param: offset
    jsr FuncA_Room_BossLava_SetPointBelowBossCenter
    lda Zp_RoomState + sState::BossCooldown_u8
    mul #2  ; clears the carry bit
    bit Zp_RoomState + sState::FiresprayDir_i8
    bmi @sweepRightToLeft
    @sweepLeftToRight:
    adc #$10  ; param: aim angle
    bne @shootFireball  ; unconditional
    @sweepRightToLeft:
    rsub #$70  ; param: aim angle
    @shootFireball:
    jsr Func_ShootFireballFromPoint
    ;; Once the last fireball is shot, recover for a bit before switching back
    ;; to scuttling.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done  ; still more fireballs to shoot
    lda #eBossMode::FiresprayRecover
    sta Zp_RoomState + sState::Current_eBossMode
    lda #90
    sta Zp_RoomState + sState::BossCooldown_u8
    @done:
    rts
_BossFiresprayRecover:
    ;; Wait for cooldown, then start scuttling.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne FuncC_Boss_Lava_BossOpenJaws
    beq _StartNextScuttle  ; unconditional
_BossScuttling:
    ;; Wait for cooldown.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne FuncC_Boss_Lava_BossOpenJaws
    ;; Close jaws while scuttling.
    jsr FuncC_Boss_Lava_BossCloseJaws
    ;; Move towards the goal.
    jsr FuncC_Boss_Lava_BossMoveTowardGoal  ; sets C when goal is reached
    bcc _ThirdReturn  ; hasn't reached goal yet
    ;; Set a cooldown before proceeding to the next goal position.
    lda #kBossScuttleCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    dec Zp_RoomState + sState::ScuttleCount_u8
    beq _StartNewAttackSequence
    lda #60
    sta Zp_RoomState + sState::BossCooldown_u8
    bne _StartNextScuttle  ; unconditional
_StartNewAttackSequence:
    ;; Choose a random number of times to scuttle next time, from 2-3.
    jsr Func_GetRandomByte  ; returns A
    mod #2
    ora #2
    sta Zp_RoomState + sState::ScuttleCount_u8
    ;; If the boss hasn't dropped enough eggs for this health level, prepare to
    ;; drop one.
    ldx Zp_RoomState + sState::BossHealth_u8
    lda Zp_RoomState + sState::BossEggsDropped_u8
    cmp _EggsToDrop_u8_arr, x
    blt _StartEggPrepare
    ;; Otherwise, prepare a flamestrike attack.
    fall _StartFlamestrikePrepare
_StartFlamestrikePrepare:
    ;; Choose a random valid position for firing a flamestrike (Y is 2, and X
    ;; is in in the range 3-6).
    lda #2
    sta Zp_RoomState + sState::BossGoalY_u8
    jsr Func_GetRandomByte  ; returns A
    mod #4
    add #3
    sta Zp_RoomState + sState::BossGoalX_u8
    ;; Change modes to move to the firing position and shoot a flamestrike.
    lda #eBossMode::FlamestrikePrepare
    sta Zp_RoomState + sState::Current_eBossMode
    rts
_StartEggPrepare:
    ;; Choose a random valid position for dropping an egg (Y is 0, and X is in
    ;; in the range 4-5).
    lda #0
    sta Zp_RoomState + sState::BossGoalY_u8
    jsr Func_GetRandomByte  ; returns A
    mod #2
    add #4
    sta Zp_RoomState + sState::BossGoalX_u8
    ;; Change modes to move to the dropping position and drop an egg.
    lda #eBossMode::EggPrepare
    sta Zp_RoomState + sState::Current_eBossMode
    rts
_EggsToDrop_u8_arr:
    ;; The boss should drop its first egg at 4 health remaining, and another
    ;; one when at 2 health.  (At zero health, don't drop any more, since the
    ;; boss is about to die.)
:   .byte 0, 2, 2, 1, 1, 0, 0
    .assert * - :- = kBossInitHealth + 1, error
.ENDPROC

;;; Opens the boss's jaws and tail by one step, up until they're fully open.
;;; @return Z Set if the jaws are already fully open.
.PROC FuncC_Boss_Lava_BossOpenJaws
    lda Zp_RoomState + sState::BossJawsOpen_u8
    cmp #kBossJawsOpenFrames
    beq @done
    inc Zp_RoomState + sState::BossJawsOpen_u8
    @done:
    rts
.ENDPROC

;;; Closes the boss's jaws and tail by one step, down until they're fully
;;; closed.
.PROC FuncC_Boss_Lava_BossCloseJaws
    lda #1  ; param: speedup
    fall FuncC_Boss_Lava_BossCloseJawsWithSpeedup
.ENDPROC

;;; Closes the boss's jaws and tail by the given number of steps, down until
;;; they're fully closed.
;;; @param A The speedup factor.
.PROC FuncC_Boss_Lava_BossCloseJawsWithSpeedup
    rsub Zp_RoomState + sState::BossJawsOpen_u8
    .assert kBossJawsOpenFrames < $80, error
    bpl @setJaws
    lda #0
    @setJaws:
    sta Zp_RoomState + sState::BossJawsOpen_u8
    rts
.ENDPROC

;;; Makes the boss vibrate in place for the duration of the cooldown, opening
;;; its jaws towards the end of the cooldown period (assuming that the total
;;; cooldown period is kAttackVibrateFrames).
;;; @return Z Set when finished vibrating.
.PROC FuncC_Boss_Lava_VibrateForCooldownAndOpenJaws
_Vibrate:
    lda Zp_RoomState + sState::BossCooldown_u8
    lsr a
    bcs @done
    and #1    ; param: signed delta
    bne @vibrate
    lda #<-1  ; param: signed delta
    @vibrate:
    ldx #kBossBodyPlatformIndex  ; param: platform index
    pha  ; signed delta
    jsr Func_MovePlatformHorz  ; preserves X
    pla  ; param: signed delta
    ldx #kBossTailPlatformIndex  ; param: platform index
    jsr Func_MovePlatformHorz
    @done:
_OpenJaws:
    ;; Towards the end of the cooldown, open the boss's jaws.
    lda Zp_RoomState + sState::BossCooldown_u8
    cmp #30
    bge @done
    jsr FuncC_Boss_Lava_BossOpenJaws  ; sets Z when fully open
    @done:
_SetZWhenCooldownComplete:
    lda Zp_RoomState + sState::BossCooldown_u8
    rts
.ENDPROC

;;; Moves the boss towards its goal position (as specified by BossGoalX_u8 and
;;; BossGoalY_u8), if it's not already there.
;;; @return C Set if the boss is at its goal.
.PROC FuncC_Boss_Lava_BossMoveTowardGoal
    ;; Compute the goal top-left position for the boss's body platform, storing
    ;; it in Zp_Point*_i16.
    lda Zp_RoomState + sState::BossGoalX_u8
    mul #kBlockWidthPx  ; this will clear the carry
    adc #kBossBodyMinLeftX
    sta Zp_PointX_i16 + 0
    lda Zp_RoomState + sState::BossGoalY_u8
    mul #kBlockHeightPx  ; this will clear the carry
    adc #kBossZoneTopY
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointX_i16 + 1
    sta Zp_PointY_i16 + 1
    ;; Move the boss's body towards the goal position, and the tail with it.
    ldx #kBossBodyPlatformIndex  ; param: platform index
    lda #1  ; param: max move by
    jsr Func_MovePlatformLeftTowardPointX  ; preserves X, returns A and Z
    beq @reachedGoalHorz
    ldx #kBossTailPlatformIndex  ; param: platform index
    jsr Func_MovePlatformHorz
    clc  ; hasn't reached goal yet
    rts
    @reachedGoalHorz:
    lda #1  ; param: max move by
    jsr Func_MovePlatformTopTowardPointY  ; returns A and Z
    beq @reachedGoalVert
    ldx #kBossTailPlatformIndex  ; param: platform index
    jsr Func_MovePlatformVert
    clc  ; hasn't reached goal yet
    rts
    @reachedGoalVert:
    sec  ; has reached goal
    rts
.ENDPROC

;;; Draw function for the BossLava room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Lava_DrawRoom
    jsr FuncA_Objects_AnimateLavaTerrain
    jsr FuncA_Objects_DrawBoss
_DrawBgRocks:
    ldx #kLeftWallPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    lda #$50  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #$10  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    lda #kTileIdObjDirtFirst + 0
    ldy #bObj::Pri  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    lda #$48  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #$20  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    lda #kTileIdObjDirtFirst + 1
    ldy #bObj::Pri  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;; Draw function for the lava boss.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Lava_DrawBoss
_DrawSideWalls:
    ldx #kLeftWallPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawPlatformVolcanicVert
    ldx #kRightWallPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawPlatformVolcanicVert
_SetShapePosition:
    ;; Set the shape position to the center of the boss's body.
    ldx #kBossBodyPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    lda #kBossBodyWidthPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #kBossHeightPx / 2  ; param: offset
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
    ldax #Int_BossLavaZoneTopIrq
    stax Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr
    ;; Store next frame's CHR04 bank for the lava animation so that the IRQ for
    ;; the bottom of the boss's zone can restore it.
    lda Zp_Chr04Bank_u8
    sta Zp_Buffered_sIrq + sIrq::Param3_byte  ; terrain CHR04 bank
    ;; Compute PPU scroll values for the boss zone.
    lda #kBossBgStartCol * kTileWidthPx + kBossFullWidthPx / 2
    sub Zp_ShapePosX_i16 + 0
    sta Zp_Buffered_sIrq + sIrq::Param1_byte  ; boss scroll-X
    lda #kBossBgStartRow * kTileHeightPx + kBossHeightPx / 2 + kBossZoneTopY
    sub Zp_ShapePosY_i16 + 0
    sub Zp_RoomScrollY_u8
    sta Zp_Buffered_sIrq + sIrq::Param2_byte  ; boss scroll-Y
    ;; Set up the CHR04 bank to animate the boss's legs.
    eor Zp_Buffered_sIrq + sIrq::Param1_byte  ; boss scroll-X
    div #4
    and #$03
    .assert .bank(Ppu_ChrBgAnimB0) .mod 4 = 0, error
    ora #<.bank(Ppu_ChrBgAnimB0)
    sta Zp_Chr04Bank_u8
_DrawBossJawsAndTail:
    lda #kTileHeightPx * 3  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA
    ldy #0
    lda Zp_RoomState + sState::BossJawsOpen_u8
    beq @pickTileId
    iny
    cmp #kBossJawsOpenFrames
    blt @pickTileId
    iny
    @pickTileId:
    tya
    mul #2  ; clears carry bit
    adc #kTileIdObjBossLavaJawsFirst
    pha  ; tile ID for tail
    jsr _DrawBossJawsOrTail
    lda #kTileHeightPx * 5  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    pla  ; tile ID for tail
    .assert kTileIdObjBossLavaJawsFirst .mod 2 = 0, error
    ora #1  ; tile ID for head
_DrawBossJawsOrTail:
    pha  ; tile ID
    lda #kPaletteObjBossLava   ; param: object flags
    jsr FuncA_Objects_Alloc2x1Shape  ; returns C and Y
    pla  ; tile ID
    bcs @done
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kPaletteObjBossLava | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;; ReadReg implementation for the BossLavaBlaster machine.
;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.PROC FuncC_Boss_LavaBlaster_ReadReg
    cmp #$e
    blt FuncC_Boss_Lava_ReadRegLR
    bne FuncC_Boss_Lava_ReadRegD
_RegX:
    lda Ram_PlatformLeft_i16_0_arr + kBlasterPlatformIndex
    sub #kBlasterMinPlatformLeft - kTileWidthPx  ; param: distance
    jmp Func_DivAByBlockSizeAndClampTo9  ; returns A
.ENDPROC

;;; ReadReg implementation for the BossLavaBoiler machine.
;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.PROC FuncC_Boss_LavaBoiler_ReadReg
    cmp #$e
    blt FuncC_Boss_Lava_ReadRegLR
    bne FuncC_Boss_Lava_ReadRegD
    jmp Func_MachineBoilerReadReg
.ENDPROC

;;; Reads the shared "L" or "R" lever register for the BossLavaBlaster and
;;; BossLavaBoiler machines.
;;; @param A The register to read ($c or $d).
;;; @return A The value of the register (0-9).
.PROC FuncC_Boss_Lava_ReadRegLR
    cmp #$d
    beq _RegR
_RegL:
    lda Zp_RoomState + sState::LeverLeft_u8
    rts
_RegR:
    lda Zp_RoomState + sState::LeverRight_u8
    rts
.ENDPROC

;;; Reads the shared "D" distance sensor register for the BossLavaBlaster and
;;; BossLavaBoiler machines.
;;; @return A The value of the register (0-9).
.PROC FuncC_Boss_Lava_ReadRegD
    lda #kBlockWidthPx * 11
    sta T0  ; param: minimum distance so far, in pixels
    ;; Detect the player avatar.
    ldy #kSensorPlatformIndex  ; param: distance sensor platform index
    jsr Func_SetPointToAvatarCenter  ; preserves Y and T0+
    jsr Func_DistanceSensorRightDetectPoint  ; preserves Y, returns T0
    ;; Detect the hatched solifuge, if any.
    lda #eActor::BadSolifuge  ; param: actor type to find
    jsr Func_FindActorWithType  ; preserves Y and T0+, returns C and X
    bcs @doneSolifuge  ; no solifuge baddie was found
    jsr Func_SetPointToActorCenter  ; preserves Y and T0+
    jsr Func_DistanceSensorRightDetectPoint  ; returns T0
    @doneSolifuge:
    ;; Compute and return the register value.
    lda T0  ; minimum distance so far, in pixels
    sub #kBlockWidthPx * 2  ; param: distance
    bge @noClamp
    lda #0  ; param: distance
    @noClamp:
    jmp Func_DivAByBlockSizeAndClampTo9  ; returns A
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_LavaBoiler_Draw
    jsr FuncA_Objects_DrawBoilerMachine
    ldx #kValvePlatformIndex  ; param: platform index
    ldy #eValveInput::LeftHalfOfBottomEdge  ; param: input pipe position
    jmp FuncA_Objects_DrawBoilerValve
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Room init function for the BossLava room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncA_Room_BossLava_EnterRoom
    ldax #DataC_Boss_Lava_sBoss  ; param: sBoss ptr
    jsr FuncA_Room_InitBoss  ; sets Z if boss is alive
    beq _BossIsAlive
_BossIsDead:
    ;; Remove the boss's body.
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kBossBodyPlatformIndex
    rts
_BossIsAlive:
    lda #kBossInitHealth
    sta Zp_RoomState + sState::BossHealth_u8
    lda #kBossInitCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #eBossMode::FiresprayRecover
    sta Zp_RoomState + sState::Current_eBossMode
    lda #4
    sta Zp_RoomState + sState::ScuttleCount_u8
    rts
.ENDPROC

;;; Room tick function for the BossLava room.
.PROC FuncA_Room_BossLava_TickRoom
_MachineProjectiles:
    jsr FuncA_Room_TurnSteamToSmokeIfConsoleOpen
    lda #eActor::ProjFireblast  ; param: projectile type
    jsr FuncA_Room_TurnProjectilesToSmokeIfConsoleOpen
_Boss:
    .assert eBossMode::Dead = 0, error
    lda Zp_RoomState + sState::Current_eBossMode  ; param: zero if boss dead
    jmp FuncA_Room_TickBoss
.ENDPROC

;;; Sets Zp_PointX_i16 to the horizontal center of the boss, and sets
;;; Zp_PointY_i16 to a position A pixels below the vertical center of the boss.
;;; @param A How many pixels below the center of the boss to set the point.
.PROC FuncA_Room_BossLava_SetPointBelowBossCenter
    pha  ; offset
    jsr FuncA_Room_SetPointToBossBodyCenter
    pla  ; param: offset
    jmp Func_MovePointDownByA
.ENDPROC

;;; Determines if there is an egg projectile or solifuge baddie in the room.
;;; @return C Clear if an egg and/or solifuge exists in the room, set if not.
.PROC FuncA_Room_BossLava_DoesEggOrSolifugeExist
    lda #eActor::ProjEgg  ; param: actor type to find
    jsr Func_FindActorWithType  ; returns C
    bcs @checkForSolifuge
    rts
    @checkForSolifuge:
    lda #eActor::BadSolifuge  ; param: actor type to find
    jmp Func_FindActorWithType  ; returns C
.ENDPROC

.PROC FuncA_Room_BossLavaBlaster_InitReset
    lda #kBlasterInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kBlasterMachineIndex
    .assert kBlasterInitGoalX < $80, error
    bpl FuncA_Room_BossLava_ResetLevers  ; unconditional
.ENDPROC

.PROC FuncA_Room_BossLavaBoiler_Reset
    jsr FuncA_Room_MachineBoilerReset
    fall FuncA_Room_BossLava_ResetLevers
.ENDPROC

.PROC FuncA_Room_BossLava_ResetLevers
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Room_ResetLever
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_BossLavaBoiler_WriteReg
    cpx #$e
    blt FuncA_Machine_BossLava_WriteRegLR
    jmp FuncA_Machine_BoilerWriteReg
.ENDPROC

.PROC FuncA_Machine_BossLava_WriteRegLR
    cpx #$d
    beq _WriteR
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_BossLavaBlaster_TryMove
    lda #kBlasterMaxGoalX  ; param: max goal horz
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncA_Machine_BossLavaBlaster_Tick
    ldax #kBlasterMinPlatformLeft  ; param: min platform left
    jmp FuncA_Machine_BlasterTick
.ENDPROC

.PROC FuncA_Machine_BossLavaBoiler_TryAct
    jsr FuncA_Machine_BoilerStartEmittingSteam
    ;; Determine which pipe(s) the steam should exit out of.
    lda Ram_MachineGoalHorz_u8_arr + kBoilerMachineIndex  ; valve angle
    and #$03
    tax  ; valve angle (in tau/8 units, mod 4)
    ldy _ValvePipePlatformIndex_u8_arr4, x  ; param: pipe platform index
    ;; Emit upward steam from the chosen pipe(s).
    jsr Func_EmitSteamUpFromPipe
    jmp FuncA_Machine_BoilerFinishEmittingSteam
_ValvePipePlatformIndex_u8_arr4:
    .byte kPipe1PlatformIndex
    .byte kPipe2PlatformIndex
    .byte kPipe2PlatformIndex
    .byte kPipe1PlatformIndex
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

.PROC DataA_Terrain_BossLavaLegs_sXfer_arr
    .assert kBossFullWidthTiles = 8, error
    .assert kBossHeightTiles = 4, error
    .assert kTileIdBgAnimBossLavaFirst = $68, error
    ;; Row 0:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_BossRow0Start
    d_xfer_data $68, $6c, $70, $00, $00, $74, $78, $7c
    ;; Row 1:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_BossRow1Start
    d_xfer_data $69, $6d, $71, $00, $00, $75, $79, $7d
    ;; Row 2:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_BossRow2Start
    d_xfer_data $6a, $6e, $72, $00, $00, $76, $7a, $7e
    ;; Row 3:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_BossRow3Start
    d_xfer_data $6b, $6f, $73, $00, $00, $77, $7b, $7f
    ;; Nametable attributes to color body injuries red:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_BossBodyAttrs
    d_xfer_data $55
    d_xfer_terminator
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGC_Boss"

.PROC DataC_Boss_BossLavaBody_sXfer_arr
    .assert kBossFullWidthTiles = 8, error
    .assert kBossHeightTiles = 4, error
    .assert kTileIdBgTerrainBossLavaFirst = $a8, error
    ;; Col 3:
    d_xfer_header kPpuCtrlFlagsVert, Ppu_BossRow0Start + 3
    d_xfer_data $a8, $aa, $ac, $ae
    ;; Col 4:
    d_xfer_header kPpuCtrlFlagsVert, Ppu_BossRow0Start + 4
    d_xfer_data $a9, $ab, $ad, $af
    d_xfer_terminator
.ENDPROC

;;; @prereq PRGA_Terrain is loaded.
;;; @prereq Rendering is disabled.
.PROC FuncC_Boss_Lava_FadeInRoom
    jsr FuncA_Terrain_FadeInShortRoomWithLava
    ;; Transfer BG tiles for the boss's legs.
    ldax #DataA_Terrain_BossLavaLegs_sXfer_arr  ; param: data pointer
    jsr Func_DirectPpuTransfer
    ;; Transfer BG tiles for the boss's body.
    fall FuncC_Boss_Lava_TransferBossBodyTiles
.ENDPROC

;;; Buffers a PPU transfer to draw the BG tiles for the lava boss's body,
;;; taking its current health into account. Note that this is called from both
;;; room fade-in and boss tick functions, so no particular PRGA bank is
;;; guaranteed to be loaded (and rendering may or may not be enabled).
.PROC FuncC_Boss_Lava_TransferBossBodyTiles
    ;; Buffer a transfer for the boss's body at full health.
    ldax #DataC_Boss_BossLavaBody_sXfer_arr  ; param: data pointer
    jsr Func_BufferPpuTransfer
    ;; For each point of damage on the boss, alter one of the body tiles in the
    ;; transfer buffer to be injured.
    lda #kBossInitHealth
    sub Zp_RoomState + sState::BossHealth_u8
    tax
    bpl @continue  ; unconditional
    @loop:
    lda Zp_PpuTransferLen_u8
    sub _OffsetFromEnd_u8_arr, x
    tay
    lda Ram_PpuTransfer_arr, y
    .linecont +
    .assert kTileIdBgTerrainBossLavaHurtFirst = \
            kTileIdBgTerrainBossLavaFirst | $10, error
    ora #$10
    .linecont -
    sta Ram_PpuTransfer_arr, y
    @continue:
    dex
    bpl @loop
    rts
_OffsetFromEnd_u8_arr:
:   .byte 4, 10, 11, 2, 12, 3
    .assert * - :- = kBossInitHealth, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top of the boss's zone in the BossLava
;;; room.  Sets the horizontal and vertical scroll so as to make the boss's BG
;;; tiles appear to move.
;;; @thread IRQ
.PROC Int_BossLavaZoneTopIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Set up the
    ;; next IRQ.
    lda #kBossZoneBottomY - kBossZoneTopY - 1  ; param: latch value
    jsr Func_AckIrqAndSetLatch  ; preserves Y
    ldax #Int_BossLavaZoneBottomIrq
    stax Zp_NextIrq_int_ptr
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #2  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the lower
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #3 << 2  ; nametable number << 2
    sta Hw_PpuAddr_w2
    lda Zp_Active_sIrq + sIrq::Param2_byte  ; boss scroll-Y
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
;;; BossLava room.  Sets the horizontal and vertical scroll so as to make the
;;; bottom of the room look normal.
;;; @thread IRQ
.PROC Int_BossLavaZoneBottomIrq
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
    ;; Restore the CHR04 bank needed for the animated lava terrain.
    irq_chr04 Zp_Active_sIrq + sIrq::Param3_byte  ; terrain CHR04 bank
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;;=========================================================================;;;
