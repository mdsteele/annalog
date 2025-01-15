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
.INCLUDE "../actors/ghost.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../boss.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../irq.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/emitter.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/force.inc"
.INCLUDE "../platforms/lava.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "boss_shadow.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT FuncA_Machine_EmitterTryAct
.IMPORT FuncA_Machine_EmitterXWriteReg
.IMPORT FuncA_Machine_EmitterYWriteReg
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_InjureBadGhost
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_AnimateLavaTerrain
.IMPORT FuncA_Objects_BobActorShapePosUpAndDown
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_DrawBoss
.IMPORT FuncA_Objects_DrawEmitterXMachine
.IMPORT FuncA_Objects_DrawEmitterYMachine
.IMPORT FuncA_Objects_DrawForcefieldPlatform
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_InitBoss
.IMPORT FuncA_Room_MachineEmitterXInitReset
.IMPORT FuncA_Room_MachineEmitterYInitReset
.IMPORT FuncA_Room_MakeBadGhostAppear
.IMPORT FuncA_Room_MakeBadGhostAppearForAttack
.IMPORT FuncA_Room_RemoveEmitterForcefield
.IMPORT FuncA_Room_TickBoss
.IMPORT FuncA_Terrain_FadeInShortRoomWithLava
.IMPORT Func_AckIrqAndLatchWindowFromParam4
.IMPORT Func_GetRandomByte
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MachineEmitterReadReg
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformVert
.IMPORT Func_MovePointUpByA
.IMPORT Func_Noop
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_ShakeRoom
.IMPORT Func_WriteToLowerAttributeTable
.IMPORT Ppu_ChrObjShadow1
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The platform index for the BossShadowEmitterX machine.
kEmitterXPlatformIndex = 3
;;; The platform index for the BossShadowEmitterY machine.
kEmitterYPlatformIndex = 4

;;; The initial positions of the emitter beams.
kEmitterXInitRegX = 3
kEmitterYInitRegY = 5

;;; The minimum/maximum room pixel X/Y-positions for the top-left of the
;;; forcefield platform.
kForcefieldMinPlatformLeft = $0030
kForcefieldMinPlatformTop  = $0030

;;;=========================================================================;;;

;;; The platform index for the lava in this room.
kLavaPlatformIndex = 5

;;; The maximum value for sState::LavaOffset_u8, for when the lava is fully
;;; raised.
kMaxLavaOffset = $27

;;; How many frames it takes for the lava to rise/fall by one pixel.
kLavaRiseSlowdown = 7
kLavaFallSlowdown = 4

;;; How many frames to wait between when the lava is fully raised and when it
;;; starts falling.
kLavaWaitFrames = 90

;;;=========================================================================;;;

;;; The actor indices for the ghost baddies.
kGhostMermaidActorIndex = 0
kGhostOrcActorIndex     = 1

;;; Modes that the boss in this room can be in.
.ENUM eBossMode
    Dead
    FinalGhostDying      ; final ghost has been hit and is about to die
    FinalGhostWaiting    ; final ghost has appeared and is waiting to be hit
    Intro                ; start of the fight
    GravityPending       ; waiting to begin a special gravity attack
    GravityActive        ; mermaid ghost is starting a special gravity attack
    LavaPending          ; waiting to begin a special lava attack
    LavaActive           ; orc ghost is starting a special lava attack
    LavaRising           ; lava is currently rising
    LavaFalling          ; lava is currently falling
    SingleAttackPending  ; waiting to begin next attack (one ghost at a time)
    DoubleAttackPending  ; waiting to begin next attack (both ghosts at once)
    DoubleAttackHalf     ; one half of the double-ghost attack is in progress
    AttackActive         ; ghost attack wave is in progress
    MergePending         ; waiting to begin merging into the final ghost
    MergeActive          ; waiting to finish merging into the final ghost
    NUM_VALUES
.ENDENUM

;;; The first eBossMode for which the final ghost is not visible.  Note that
;;; the final ghost must be visible for eBossNode::Dead so that it will be
;;; visible when exploding at the end of the fight.
kFirstNonFinalGhostMode = eBossMode::Intro

;;; How many forcefield hits are needed to defeat the boss.
kBossInitHealth = 8

;;; How many frames the boss waits, after you first enter the room, before
;;; taking action.
kBossInitCooldown = 120

;;; The platform index for the boss's body.
kBossBodyPlatformIndex = 2

;;; The maximum speed that the final ghost can move, in pixels per frame.
kFinalGhostMaxSpeed = 3
;;; The higher the number, the more slowly the final ghost tracks towards its
;;; goal position.
.DEFINE kFinalGhostSlowdown 16

;;; OBJ palette numbers for drawing the final ghost.
kPaletteObjFinalGhostNormal = 0
kPaletteObjFinalGhostHurt   = 1

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; How far the lava is above its base position, in pixels.
    LavaOffset_u8 .byte
    ;; What mode the boss is in.
    Current_eBossMode .byte
    ;; How many more forcefield hits are needed before the boss dies.
    BossHealth_u8 .byte
    ;; Timer that ticks down each frame when nonzero.  Used to time transitions
    ;; between boss modes.
    BossCooldown_u8 .byte
    ;; How many more normal attack waves before a lava-rise or gravity-reverse
    ;; attack.
    AttackWavesRemaining_u8 .byte
    ;; True ($ff) if the mermaid ghost is the next to attack; false ($00) if
    ;; the orc ghost is the next to attack.
    IsMermaidNext_bool .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Boss"

.EXPORT DataC_Boss_Shadow_sRoom
.PROC DataC_Boss_Shadow_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte Flags_bRoom, bRoom::Unsafe | eArea::Shadow
    d_byte MinimapStartRow_u8, 14
    d_byte MinimapStartCol_u8, 9
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjShadow1)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Shadow_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncA_Room_BossShadow_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_BossShadow_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_BossShadow_TickRoom
    d_addr Draw_func_ptr, FuncC_Boss_Shadow_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/boss_shadow.room"
    .assert * - :- = 16 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kEmitterXMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossShadowEmitterX
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteE
    d_byte Status_eDiagram, eDiagram::EmitterX
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, 0, 0, "X", 0
    d_byte MainPlatform_u8, kEmitterXPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_BossShadowEmitterX_InitReset
    d_addr ReadReg_func_ptr, Func_MachineEmitterReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_EmitterXWriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_BossShadowEmitter_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_ReachedGoal
    d_addr Draw_func_ptr, FuncA_Objects_BossShadowEmitterX_Draw
    d_addr Reset_func_ptr, FuncA_Room_BossShadowEmitterX_InitReset
    D_END
    .assert * - :- = kEmitterYMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossShadowEmitterY
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteF
    d_byte Status_eDiagram, eDiagram::EmitterY
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kEmitterYPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_BossShadowEmitterY_InitReset
    d_addr ReadReg_func_ptr, Func_MachineEmitterReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_EmitterYWriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_BossShadowEmitter_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_ReachedGoal
    d_addr Draw_func_ptr, FuncA_Objects_BossShadowEmitterY_Draw
    d_addr Reset_func_ptr, FuncA_Room_BossShadowEmitterY_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .linecont +
    .assert * - :- = kEmitterForcefieldPlatformIndex * .sizeof(sPlatform), \
            error
    .linecont -
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kForcefieldPlatformWidth
    d_byte HeightPx_u8, kForcefieldPlatformHeight
    d_word Left_i16, kForcefieldMinPlatformLeft
    d_word Top_i16, kForcefieldMinPlatformTop
    D_END
    .assert * - :- = kEmitterRegionPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $a0
    d_byte HeightPx_u8, $70
    d_word Left_i16, kForcefieldMinPlatformLeft
    d_word Top_i16, kForcefieldMinPlatformTop
    D_END
    .assert * - :- = kBossBodyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0058
    d_word Top_i16,   $0038
    D_END
    .assert * - :- = kEmitterXPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00c8
    d_word Top_i16,   $0018
    D_END
    .assert * - :- = kEmitterYPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0018
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kLavaPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $100
    d_byte HeightPx_u8, kLavaPlatformHeightPx
    d_word Left_i16,   $0000
    d_word Top_i16, kLavaPlatformTopShortRoom
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kGhostMermaidActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGhostMermaid
    d_word PosX_i16, $00c8
    d_word PosY_i16, $0060
    d_byte Param_byte, eBadGhost::Absent
    D_END
    .assert * - :- = kGhostOrcActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGhostOrc
    d_word PosX_i16, $0038
    d_word PosY_i16, $0064
    d_byte Param_byte, eBadGhost::Absent
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kBossDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eRoom::ShadowDepths
    D_END
    .assert * - :- = kBossUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be an upgrade
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eFlag::UpgradeOpMul
    D_END
    .assert * - :- = kBossBreakerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be a breaker
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eFlag::BreakerShadow
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 3
    d_byte Target_byte, kEmitterYMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 12
    d_byte Target_byte, kEmitterXMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC DataC_Boss_Shadow_sBoss
    D_STRUCT sBoss
    d_byte Boss_eFlag, eFlag::BossShadow
    d_byte BodyPlatform_u8, kBossBodyPlatformIndex
    d_addr Tick_func_ptr, FuncC_Boss_Shadow_TickBoss
    d_addr Draw_func_ptr, FuncC_Boss_Shadow_DrawBoss
    D_END
.ENDPROC

;;; Performs per-frame upates for the boss in this room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Shadow_TickBoss
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
    d_entry table, Dead,                Func_Noop
    d_entry table, FinalGhostDying,     _BossMode_FinalGhostDying
    d_entry table, FinalGhostWaiting,   Func_Noop
    d_entry table, Intro,               _BossMode_Intro
    d_entry table, GravityPending,      _BossMode_GravityPending
    d_entry table, GravityActive,       _BossMode_GravityActive
    d_entry table, LavaPending,         _BossMode_LavaPending
    d_entry table, LavaActive,          _BossMode_LavaActive
    d_entry table, LavaRising,          _BossMode_LavaRising
    d_entry table, LavaFalling,         _BossMode_LavaFalling
    d_entry table, SingleAttackPending, _BossMode_SingleAttackPending
    d_entry table, DoubleAttackPending, _BossMode_DoubleAttackPending
    d_entry table, DoubleAttackHalf,    _BossMode_DoubleAttackHalf
    d_entry table, AttackActive,        _BossMode_AttackActive
    d_entry table, MergePending,        _BossMode_MergePending
    d_entry table, MergeActive,         _BossMode_MergeActive
    D_END
.ENDREPEAT
_BossMode_MergePending:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Make both ghosts appear.
    .assert kGhostOrcActorIndex = 1, error
    .assert kGhostMermaidActorIndex = 0, error
    ldx #1
    @loop:
    lda #eBadGhost::AppearForMerge  ; param: eBadGhost::AppearFor* value
    jsr FuncA_Room_MakeBadGhostAppear  ; preserves X
    lda _MergeDelay_u8_arr, x
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    dex
    bpl @loop
    ;; Switch main boss mode to wait for the merge to complete.
    lda #eBossMode::MergeActive
    sta Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_MergeDelay_u8_arr:
    .byte 75, 86
_BossMode_MergeActive:
    ;; Wait for ghosts to disappear.
    .assert eBadGhost::Absent = 0, error
    lda Ram_ActorState1_byte_arr + kGhostMermaidActorIndex  ; eBadGhost mode
    ora Ram_ActorState1_byte_arr + kGhostOrcActorIndex      ; eBadGhost mode
    bne @done
    ;; Make the final ghost appear.
    lda #eBossMode::FinalGhostWaiting
    sta Zp_RoomState + sState::Current_eBossMode
    jsr FuncA_Room_RemoveEmitterForcefield
    ;; TODO: Flash the screen white
    ;; Switch gravity back to normal if it was reversed.
    lda Zp_AvatarFlags_bObj
    and #<~bObj::FlipV
    sta Zp_AvatarFlags_bObj
    @done:
    rts
_BossMode_FinalGhostDying:
    ;; Adjust the ghost towards the center of the room.
    lda #$70 + (kFinalGhostSlowdown - 1)
    sub Ram_PlatformLeft_i16_0_arr + kBossBodyPlatformIndex
    div #kFinalGhostSlowdown
    cmp #kFinalGhostMaxSpeed
    blt @moveByA
    lda #kFinalGhostMaxSpeed
    @moveByA:
    ldx #kBossBodyPlatformIndex  ; param: platform index
    jsr Func_MovePlatformHorz
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Kill the final ghost.
    lda #eBossMode::Dead
    sta Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_BossMode_GravityPending:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Make the mermaid ghost appear.
    ldx #kGhostMermaidActorIndex  ; param: actor index
    lda #eBadGhost::AppearForSpecial  ; param: eBadGhost::AppearFor* value
    jsr FuncA_Room_MakeBadGhostAppear
    ;; Switch main boss mode to wait for the attack to complete.
    .assert eBossMode::GravityPending + 1 = eBossMode::GravityActive, error
    inc Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_BossMode_GravityActive:
    ;; TODO: If the ghost gets injured, cancel the special and begin a new set
    ;;   of attack waves.
    ;; Wait for the mermaid ghost to disappear.
    .assert eBadGhost::Absent = 0, error
    lda Ram_ActorState1_byte_arr + kGhostMermaidActorIndex  ; eBadGhost mode
    bne @done
    ;; Reverse gravity.
    lda Zp_AvatarFlags_bObj
    eor #bObj::FlipV
    sta Zp_AvatarFlags_bObj
    ;; Begin a new set of attack waves.
    jmp _BeginNewAttackWaves
    @done:
    rts
_BossMode_LavaPending:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Make the orc ghost appear.
    ldx #kGhostOrcActorIndex  ; param: actor index
    lda #eBadGhost::AppearForSpecial  ; param: eBadGhost::AppearFor* value
    jsr FuncA_Room_MakeBadGhostAppear
    ;; Switch main boss mode to wait for the attack to complete.
    .assert eBossMode::LavaPending + 1 = eBossMode::LavaActive, error
    inc Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_BossMode_LavaActive:
    ;; TODO: If the ghost gets injured, cancel the special and begin a new set
    ;;   of attack waves.
    ;; Wait for the orc ghost to disappear, then make the lava start rising.
    .assert eBadGhost::Absent = 0, error
    lda Ram_ActorState1_byte_arr + kGhostOrcActorIndex  ; eBadGhost mode
    bne @done
    ;; Switch main boss mode to make the lava start rising.
    .assert eBossMode::LavaActive + 1 = eBossMode::LavaRising, error
    inc Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_BossMode_LavaRising:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Raise the lava.
    inc Zp_RoomState + sState::LavaOffset_u8
    ldx #kLavaPlatformIndex  ; param: platform index
    lda #<-1  ; param: move delta
    jsr Func_MovePlatformVert
    lda Zp_RoomState + sState::LavaOffset_u8
    cmp #kMaxLavaOffset
    bge @lavaFullyRaised
    ;; If the lava isn't fully raised yet, shake the room and keep going.
    lda #kLavaRiseSlowdown  ; param: num frames
    sta Zp_RoomState + sState::BossCooldown_u8
    jmp Func_ShakeRoom
    ;; Once the lava is fully raised, set the cooldown and prepare to make the
    ;; lava fall.
    @lavaFullyRaised:
    lda #kLavaWaitFrames
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #eBossMode::LavaFalling
    sta Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_BossMode_LavaFalling:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Lower the lava.
    dec Zp_RoomState + sState::LavaOffset_u8
    ldx #kLavaPlatformIndex  ; param: platform index
    lda #1  ; param: move delta
    jsr Func_MovePlatformVert
    lda Zp_RoomState + sState::LavaOffset_u8
    beq @lavaFullyLowered
    ;; If the lava isn't fully lowered yet, shake the room and keep going.
    lda #kLavaFallSlowdown  ; param: num frames
    sta Zp_RoomState + sState::BossCooldown_u8
    jmp Func_ShakeRoom
    ;; Once the lava is fully lowered, begin a new set of attack waves.
    @lavaFullyLowered:
    jmp _BeginNewAttackWaves
    @done:
    rts
_BossMode_DoubleAttackPending:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Make the first ghost appear.
    jsr FuncA_Room_BossShadow_GetNextGhostIndex  ; returns X
    jsr FuncA_Room_MakeBadGhostAppearForAttack
    ;; Switch main boss mode to wait until the other ghost should appear.
    lda #eBossMode::DoubleAttackHalf
    sta Zp_RoomState + sState::Current_eBossMode
    lda #60
    sta Zp_RoomState + sState::BossCooldown_u8
    @done:
    rts
_BossMode_DoubleAttackHalf:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Make the second ghost appear.
    jsr FuncA_Room_BossShadow_GetNextGhostIndex  ; returns X
    jsr FuncA_Room_MakeBadGhostAppearForAttack
    ;; Toggle the next-ghost flag once more, so that for the next double-attack
    ;; wave, the ghosts will appear in the opposite order.
    jsr FuncA_Room_BossShadow_GetNextGhostIndex
    ;; Switch main boss mode to wait for the attack to complete.
    lda #eBossMode::AttackActive
    sta Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_BossMode_SingleAttackPending:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Make the next ghost appear.
    jsr FuncA_Room_BossShadow_GetNextGhostIndex  ; returns X
    jsr FuncA_Room_MakeBadGhostAppearForAttack
    ;; Switch main boss mode to wait for the attack to complete.
    lda #eBossMode::AttackActive
    sta Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_BossMode_AttackActive:
    ;; TODO: If boss health is zero, make ghosts teleport out earlier.
    ;; Wait for ghosts to disappear, then begin the next attack wave.
    .assert eBadGhost::Absent = 0, error
    lda Ram_ActorState1_byte_arr + kGhostMermaidActorIndex  ; eBadGhost mode
    ora Ram_ActorState1_byte_arr + kGhostOrcActorIndex      ; eBadGhost mode
    beq _BeginNextAttackWave
    rts
_BossMode_Intro:
    ;; Wait for the cooldown to expire, then begin a new set of attack waves.
    lda Zp_RoomState + sState::BossCooldown_u8
    beq _BeginNewAttackWaves
    rts
_BeginNewAttackWaves:
    ;; Begin a new set of 4-7 attack waves.
    jsr Func_GetRandomByte  ; returns A
    mod #4
    ora #4
    sta Zp_RoomState + sState::AttackWavesRemaining_u8
_BeginNextAttackWave:
    ;; If boss health is zero, make final ghost appear.
    lda Zp_RoomState + sState::BossHealth_u8
    beq _BeginMerge
    ;; If there are no more attack waves left in this group, perform a special
    ;; attack.
    lda Zp_RoomState + sState::AttackWavesRemaining_u8
    beq _BeginSpecialAttack
    dec Zp_RoomState + sState::AttackWavesRemaining_u8
    ;; If boss health is at half or below, perform double-attack waves.
    ;; Otherwise, perform single-attack waves.
    ldy #eBossMode::SingleAttackPending
    lda #kBossInitHealth / 2
    cmp Zp_RoomState + sState::BossHealth_u8
    blt @setMode
    ldy #eBossMode::DoubleAttackPending
    @setMode:
    sty Zp_RoomState + sState::Current_eBossMode
    lda #30
    sta Zp_RoomState + sState::BossCooldown_u8
    rts
_BeginMerge:
    lda #eBossMode::MergePending
    sta Zp_RoomState + sState::Current_eBossMode
    lda #60
    sta Zp_RoomState + sState::BossCooldown_u8
    rts
_BeginSpecialAttack:
    ;; If gravity is currently reversed, begin another gravity attack (to
    ;; change gravity back to normal).  After all, there's no point in a lava
    ;; attack if the avatar is on the ceiling.
    bit Zp_AvatarFlags_bObj
    .assert bObj::FlipV = bProc::Negative, error
    bmi _BeginSpecialGravityAttack
    ;; Otherwise, choose a special attack randomly.
    jsr Func_GetRandomByte  ; returns N
    bmi _BeginSpecialGravityAttack
_BeginSpecialLavaAttack:
    lda #eBossMode::LavaPending
    sta Zp_RoomState + sState::Current_eBossMode
    lda #30
    sta Zp_RoomState + sState::BossCooldown_u8
    rts
_BeginSpecialGravityAttack:
    lda #eBossMode::GravityPending
    sta Zp_RoomState + sState::Current_eBossMode
    lda #30
    sta Zp_RoomState + sState::BossCooldown_u8
    rts
.ENDPROC

;;; Draw function for the BossShadow room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Shadow_DrawRoom
    jsr FuncA_Objects_AnimateLavaTerrain
_SetUpIrq:
    lda Zp_RoomState + sState::LavaOffset_u8
    beq @done
    ;; Compute the IRQ latch value to set between the top of the lava and the
    ;; top of the window (if any), and set that as Param4_byte.
    rsub #kLavaTerrainTopShortRoom
    sta T0  ; lava terrain top (in room pixels)
    add Zp_RoomScrollY_u8
    rsub Zp_Buffered_sIrq + sIrq::Latch_u8
    blt @done  ; window top is above lava top
    sta Zp_Buffered_sIrq + sIrq::Param4_byte  ; window latch
    ;; Set up our own sIrq struct to handle lava movement.
    lda T0  ; lava terrain top (in room pixels)
    sub Zp_RoomScrollY_u8
    sta Zp_Buffered_sIrq + sIrq::Latch_u8
    ldax #Int_BossShadowLavaIrq
    stax Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr
    @done:
_Forcefield:
    ldx #kEmitterForcefieldPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawForcefieldPlatform
_DrawBoss:
    jmp FuncA_Objects_DrawBoss
.ENDPROC

;;; Draw function for the shadow boss.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Shadow_DrawBoss
    ;; Check if the final ghost is visible.
    lda Zp_RoomState + sState::Current_eBossMode
    cmp #kFirstNonFinalGhostMode
    bge @done  ; final ghost has not yet appeared
    ;; Set the shape position to the center of the final ghost.
    ldx #kBossBodyPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile
    ldx #0  ; param: (fake) actor index
    jsr FuncA_Objects_BobActorShapePosUpAndDown
    ;; Pick the OBJ palette for the final ghost.
    ldy #kPaletteObjFinalGhostNormal  ; param: object flags
    lda Zp_RoomState + sState::Current_eBossMode
    cmp #eBossMode::FinalGhostDying
    bne @draw
    lda Zp_FrameCounter_u8
    and #$02
    beq @draw
    .assert kPaletteObjFinalGhostHurt = kPaletteObjFinalGhostNormal + 1, error
    iny  ; param: object flags
    ;; Draw the final ghost.
    @draw:
    lda #kTileIdObjAnnaGhostFirst  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Shape
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_BossShadow_EnterRoom
    ldax #DataC_Boss_Shadow_sBoss  ; param: sBoss ptr
    jsr FuncA_Room_InitBoss  ; sets Z if boss is alive
    bne _BossIsDead
_BossIsAlive:
    lda #kBossInitHealth
    sta Zp_RoomState + sState::BossHealth_u8
    lda #kBossInitCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #eBossMode::Intro
    sta Zp_RoomState + sState::Current_eBossMode
_BossIsDead:
    rts
.ENDPROC

.PROC FuncA_Room_BossShadow_TickRoom
    .assert eBossMode::Dead = 0, error
    lda Zp_RoomState + sState::Current_eBossMode  ; param: zero if boss dead
    jmp FuncA_Room_TickBoss
.ENDPROC

;;; Returns the actor index for the ghost (mermaid or orc) that should attack
;;; next, and toggles it for the next time.
;;; @return X The actor index for the ghost that should attack next.
;;; @preserve T0+
.PROC FuncA_Room_BossShadow_GetNextGhostIndex
    ldx #kGhostMermaidActorIndex
    lda Zp_RoomState + sState::IsMermaidNext_bool
    eor #$ff
    sta Zp_RoomState + sState::IsMermaidNext_bool
    bpl @mermaidWasNext
    @orcWasNext:
    .assert kGhostMermaidActorIndex + 1 = kGhostOrcActorIndex, error
    inx
    @mermaidWasNext:
    rts
.ENDPROC

.PROC FuncA_Room_BossShadowEmitterX_InitReset
    lda #kEmitterXInitRegX  ; param: X register value
    jmp FuncA_Room_MachineEmitterXInitReset
.ENDPROC

.PROC FuncA_Room_BossShadowEmitterY_InitReset
    lda #kEmitterYInitRegY  ; param: X register value
    jmp FuncA_Room_MachineEmitterYInitReset
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_BossShadowEmitter_TryAct
    jsr FuncA_Machine_EmitterTryAct  ; returns C
    bcc _Return  ; no forcefield was created
_MaybeHarmOrcAndMermaidGhosts:
    ;; Check the mermaid and orc ghosts to see if they should be injured by the
    ;; new forcefield.
    .assert kGhostMermaidActorIndex = 0, error
    .assert kGhostOrcActorIndex = 1, error
    ldx #1
    @loop:
    ;; Check if the ghost is vulnerable.
    lda Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    cmp #kBadGhostFirstVulnerable
    blt @continue  ; ghost is not currently vulnerable
    ;; Check if the forcefield is hitting the ghost.
    jsr Func_SetPointToActorCenter  ; preserves X
    ldy #kEmitterForcefieldPlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; preserves X, returns C
    bcs @injure  ; the forcefield is hitting the ghost's body
    lda #$10  ; param: offset
    jsr Func_MovePointUpByA  ; preserves X
    jsr Func_IsPointInPlatform  ; preserves X, returns C
    bcc @continue  ; forcefield isn't hitting the ghost's head
    ;; Injure the ghost and decrement boss health.
    @injure:
    jsr FuncA_Machine_InjureBadGhost  ; preserves X
    lda Zp_RoomState + sState::BossHealth_u8
    beq @continue
    dec Zp_RoomState + sState::BossHealth_u8
    @continue:
    dex
    bpl @loop
_MaybeHarmFinalGhost:
    ;; Check if the final ghost is vulnerable.
    lda Zp_RoomState + sState::Current_eBossMode
    cmp #eBossMode::FinalGhostWaiting
    bne @done
    ;; Check if the forcefield is hitting the final ghost.
    ldy #kBossBodyPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter
    ldy #kEmitterForcefieldPlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcc @done  ; forcefield isn't hitting the final ghost
    ;; Mortally wound the final ghost.
    lda #eBossMode::FinalGhostDying
    sta Zp_RoomState + sState::Current_eBossMode
    lda #120
    sta Zp_RoomState + sState::BossCooldown_u8
    @done:
_Return:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

.PROC FuncA_Terrain_BossShadow_FadeInRoom
_Tiles:
    ldax #Ppu_Nametable3_sName + sName::Tiles_u8_arr + 0
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    lda #4
    sta T0  ; num block rows
    @loop:
    ldy #$40  ; param: left tile ID
    lda #$41  ; param: right tile ID
    jsr _WriteLavaTileRow  ; preserves A, Y, and T0+
    tya  ; param: right tile ID (now $40)
    iny  ; param: left tile ID (now $41)
    jsr _WriteLavaTileRow  ; preserves A, Y, and T0+
    dec T0  ; num block rows
    bne @loop
_Attributes:
    jsr FuncA_Terrain_FadeInShortRoomWithLava
    ldx #16   ; param: num bytes to write
    ldy #$55  ; param: attribute value
    lda #$00  ; param: initial byte offset
    jmp Func_WriteToLowerAttributeTable
_WriteLavaTileRow:
    ldx #kScreenWidthBlocks
    @loop:
    sty Hw_PpuData_rw
    sta Hw_PpuData_rw
    dex
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_BossShadowEmitterX_Draw
    ;; The beam length is 18 for GoalHorz=0 or GoalHorz=9, and 20 otherwise.
    ldy #18  ; param: beam length in tiles
    lda Ram_MachineGoalHorz_u8_arr + kEmitterXMachineIndex
    beq @draw
    cmp #9
    beq @draw
    iny
    iny  ; param: beam length in tiles
    @draw:
    jmp FuncA_Objects_DrawEmitterXMachine
.ENDPROC

.PROC FuncA_Objects_BossShadowEmitterY_Draw
    ldy #24  ; param: beam length in tiles
    jmp FuncA_Objects_DrawEmitterYMachine
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top of the lava in the BossShadow room.
;;; Sets the scroll so as to make the lava appear to start here.
.PROC Int_BossShadowLavaIrq
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
    lda #kLavaTerrainTopShortRoom  ; new scroll-Y value
    sta Hw_PpuScroll_w2
    lda #((kLavaTerrainTopShortRoom & $38) << 2) | (0 >> 3)
    ;; We should now be in the second HBlank.
    stx Hw_PpuScroll_w2  ; new scroll-X value (zero)
    sta Hw_PpuAddr_w2    ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;;=========================================================================;;;
