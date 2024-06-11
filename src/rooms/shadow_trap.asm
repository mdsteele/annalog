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
.INCLUDE "../machines/laser.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/barrier.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_LaserTryAct
.IMPORT FuncA_Machine_LaserWriteReg
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawLaserMachine
.IMPORT FuncA_Room_HarmAvatarIfWithinLaserBeam
.IMPORT FuncA_Room_InitActorBadFlydrop
.IMPORT FuncA_Room_IsPointInLaserBeam
.IMPORT FuncA_Room_MachineLaserReset
.IMPORT FuncC_Shadow_DrawBarrierPlatform
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MachineLaserReadRegC
.IMPORT Func_MarkRoomSafe
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetFlag
.IMPORT Func_SetMachineIndex
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_WriteToUpperAttributeTable
.IMPORT Ppu_ChrObjShadow
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The index of the passage that leads to the ShadowDrill room.
kDrillPassageIndex = 0

;;; The room pixel Y-position of the center of the passage that leads to the
;;; ShadowDrill room.
kDrillPassageCenterY = $00a0

;;;=========================================================================;;;

;;; The platform index for the zone that, when the player avatar enters it,
;;; triggers the trap in this room.
kTrapZonePlatformIndex = 1

;;; The platform indices for the barriers that lock the player avatar in this
;;; room when the trap springs.
kWestBarrierPlatformIndex = 2
kEastBarrierPlatformIndex = 3

;;; The platform indices for the zones where baddies will be spawned when the
;;; trap springs.
kTrapSpawnEastPlatformIndex = 4
kTrapSpawnWestPlatformIndex = 5

;;; The room pixel Y-positions for the tops of the barrier platforms when they
;;; are fully open or fully shut.
kBarrierShutTop = $0090
kBarrierOpenTop = kBarrierShutTop - kBarrierPlatformHeightPx

;;; The type of baddie actor that gets spawned when the trap is sprung.
kTrapBaddieType = eActor::BadFlydrop

;;;=========================================================================;;;

;;; The machine index for the ShadowTrapLaser machine in this room.
kLaserMachineIndex = 0

;;; The primary platform index for the ShadowTrapLaser machine.
kLaserPlatformIndex = 0

;;; The initial and maximum permitted horizontal goal values for the laser.
kLaserInitGoalX = 9
kLaserMaxGoalX = 9

;;; The maximum and initial X-positions for the left of the laser platform.
.LINECONT +
kLaserMinPlatformLeft = $0040
kLaserInitPlatformLeft = \
    kLaserMinPlatformLeft + kLaserInitGoalX * kBlockWidthPx
.LINECONT -

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; True ($ff) if the baddies have been spawned, false ($00) otherwise.
    SpawnedBaddies_bool .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Shadow"

.EXPORT DataC_Shadow_Trap_sRoom
.PROC DataC_Shadow_Trap_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Unsafe | eArea::Shadow
    d_byte MinimapStartRow_u8, 13
    d_byte MinimapStartCol_u8, 6
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjShadow)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Shadow_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_ShadowTrap_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_ShadowTrap_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_ShadowTrap_TickRoom
    d_addr Draw_func_ptr, FuncC_Shadow_Trap_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/shadow_trap.room"
    .assert * - :- = 18 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kLaserMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::ShadowTrapLaser
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::Laser
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, "C", 0, "X", 0
    d_byte MainPlatform_u8, kLaserPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_ShadowTrapLaser_InitReset
    d_addr ReadReg_func_ptr, FuncC_Shadow_TrapLaser_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_LaserWriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_ShadowTrapLaser_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_ShadowTrapLaser_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_ShadowTrapLaser_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLaserMachine
    d_addr Reset_func_ptr, FuncA_Room_ShadowTrapLaser_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLaserPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLaserMachineWidthPx
    d_byte HeightPx_u8, kLaserMachineHeightPx
    d_word Left_i16, kLaserInitPlatformLeft
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kTrapZonePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0080
    d_word Top_i16,   $00a0
    D_END
    .assert * - :- = kWestBarrierPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBarrierPlatformWidthPx
    d_byte HeightPx_u8, kBarrierPlatformHeightPx
    d_word Left_i16,  $002e - kBarrierPlatformWidthPx
    d_word Top_i16, kBarrierOpenTop
    D_END
    .assert * - :- = kEastBarrierPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBarrierPlatformWidthPx
    d_byte HeightPx_u8, kBarrierPlatformHeightPx
    d_word Left_i16,  $00f2
    d_word Top_i16, kBarrierOpenTop
    D_END
    .assert * - :- = kTrapSpawnEastPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $00
    d_byte HeightPx_u8, $00
    d_word Left_i16,  $00f0
    d_word Top_i16,   $0048
    D_END
    .assert * - :- = kTrapSpawnWestPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $00
    d_byte HeightPx_u8, $00
    d_word Left_i16,  $0030
    d_word Top_i16,   $0068
    D_END
    ;; Acid:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $a0
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0040
    d_word Top_i16,   $00ca
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 9
    d_byte Target_byte, kLaserMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   .assert * - :- = kDrillPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::ShadowDrill
    d_byte SpawnBlock_u8, 10
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::ShadowHeart
    d_byte SpawnBlock_u8, 10
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Shadow_Trap_DrawRoom
    ldx #kWestBarrierPlatformIndex
    jsr FuncC_Shadow_DrawBarrierPlatform
    ldx #kEastBarrierPlatformIndex
    jmp FuncC_Shadow_DrawBarrierPlatform
.ENDPROC

.PROC FuncC_Shadow_TrapLaser_ReadReg
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

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncA_Room_ShadowTrap_EnterRoom
_FixGravity:
    ;; If entering from the ShadowDrill room, and gravity is still reversed,
    ;; un-reverse it.
    cmp #bSpawn::Passage | kDrillPassageIndex
    bne @done  ; not entering from ShadowDrill room
    lda Zp_AvatarFlags_bObj
    .assert bObj::FlipV = $80, error
    bpl @done  ; gravity is already normal
    ;; Restore normal gravity.
    and #<~bObj::FlipV
    sta Zp_AvatarFlags_bObj
    ;; Invert the avatar's Y-position within the passage.
    lda #<(kDrillPassageCenterY * 2)
    sub Zp_AvatarPosY_i16 + 0
    sta Zp_AvatarPosY_i16 + 0
    lda #>(kDrillPassageCenterY * 2)
    sbc Zp_AvatarPosY_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
    @done:
_MaybeMarkSafe:
    flag_bit Sram_ProgressFlags_arr, eFlag::ShadowTrapDisarmed
    jne Func_MarkRoomSafe
    rts
.ENDPROC

.PROC FuncA_Room_ShadowTrap_TickRoom
    ldx #kLaserMachineIndex
    jsr Func_SetMachineIndex
    jsr FuncA_Room_HarmAvatarIfWithinLaserBeam
_CheckTrap:
    flag_bit Sram_ProgressFlags_arr, eFlag::ShadowTrapDisarmed
    bne _OpenBarriers
    bit Zp_RoomState + sState::SpawnedBaddies_bool
    bpl _MaybeSpawnBaddies
_CheckIfBaddiesZapped:
    ;; Kill any spawned baddies that get hit by the laser beam.
    lda #0
    sta T3  ; num baddies found
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #kTrapBaddieType
    bne @continue
    inc T3  ; num baddies found
    jsr Func_SetPointToActorCenter  ; preserves X and T0+
    stx T2  ; actor index
    jsr FuncA_Room_IsPointInLaserBeam  ; preserves T2+, returns C
    ldx T2  ; actor index
    bcc @continue
    jsr Func_InitActorSmokeExplosion  ; preserves X and T0+
    @continue:
    dex
    .assert kMaxActors <= $80, error
    bpl @loop
_CheckIfBaddiesDefeated:
    ;; If no baddies are left, disarm the trap.
    lda T3  ; num baddies found
    bne _ShutBarriers
    ldx #eFlag::ShadowTrapDisarmed  ; param: flag
    jsr Func_SetFlag
    jsr Func_MarkRoomSafe
    jmp _OpenBarriers
_MaybeSpawnBaddies:
    ;; If the player avatar isn't in the trap zone, don't spawn baddies yet.
    jsr Func_SetPointToAvatarCenter
    ldy #kTrapZonePlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcc @done
    ;; Spawn the baddies.
    ldy #kTrapSpawnEastPlatformIndex  ; param: platform index
    lda #bObj::FlipH  ; param: flags
    jsr FuncA_Room_ShadowTrap_SpawnBaddie
    ldy #kTrapSpawnWestPlatformIndex  ; param: platform index
    lda #0  ; param: flags
    jsr FuncA_Room_ShadowTrap_SpawnBaddie
    ;; TODO: play an alarm sound
    lda #$ff
    sta Zp_RoomState + sState::SpawnedBaddies_bool
    @done:
_CheckBarriers:
    bit Zp_RoomState + sState::SpawnedBaddies_bool
    bpl _OpenBarriers
_ShutBarriers:
    ldax #kBarrierShutTop
    stax Zp_PointY_i16
    ldx #kWestBarrierPlatformIndex  ; param: platform index
    lda #kBarrierPlatformMoveSpeed
    jsr Func_MovePlatformTopTowardPointY
    ldx #kEastBarrierPlatformIndex  ; param: platform index
    lda #kBarrierPlatformMoveSpeed
    jmp Func_MovePlatformTopTowardPointY
_OpenBarriers:
    ldax #kBarrierOpenTop
    stax Zp_PointY_i16
    ldx #kWestBarrierPlatformIndex  ; param: platform index
    lda #kBarrierPlatformMoveSpeed
    jsr Func_MovePlatformTopTowardPointY
    ldx #kEastBarrierPlatformIndex  ; param: platform index
    lda #kBarrierPlatformMoveSpeed
    jmp Func_MovePlatformTopTowardPointY
.ENDPROC

;;; Spawns a baddie for when the trap springs.
;;; @param A Zero if the baddie should face right, or bObj::FlipH for left.
;;; @param Y The platform index for the zone to spawn the baddie in.
.PROC FuncA_Room_ShadowTrap_SpawnBaddie
    sta T0  ; flags
    jsr Func_FindEmptyActorSlot  ; preserves Y and T0+, returns C and X
    bcs @done
    jsr Func_SetPointToPlatformCenter  ; preserves X and T0+
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    .assert kTrapBaddieType = eActor::BadFlydrop, error
    lda T0  ; param: flags
    jmp FuncA_Room_InitActorBadFlydrop
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_ShadowTrapLaser_InitReset
    lda #kLaserInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kLaserMachineIndex
    jmp FuncA_Room_MachineLaserReset
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_ShadowTrapLaser_TryMove
    lda #kLaserMaxGoalX  ; param: max goal horz
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncA_Machine_ShadowTrapLaser_TryAct
    ldx Ram_MachineGoalHorz_u8_arr + kLaserMachineIndex
    lda _LaserBottom_i16_0_arr, x  ; param: laser bottom (lo)
    ldy #0                         ; param: laser bottom (hi)
    jmp FuncA_Machine_LaserTryAct
_LaserBottom_i16_0_arr:
:   .byte $30, $c5, $c5, $c5, $b0, $b0, $c5, $c5, $c5, $30
    .assert * - :- = kLaserMaxGoalX + 1, error
.ENDPROC

.PROC FuncA_Machine_ShadowTrapLaser_Tick
    ldax #kLaserMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; Sets two block rows of the upper nametable to use BG palette 2.
;;; @prereq Rendering is disabled.
.PROC FuncA_Terrain_ShadowTrap_FadeInRoom
    ldx #5    ; param: num bytes to write
    ldy #$aa  ; param: attribute value
    lda #$32  ; param: initial byte offset
    jmp Func_WriteToUpperAttributeTable
.ENDPROC

;;;=========================================================================;;;
