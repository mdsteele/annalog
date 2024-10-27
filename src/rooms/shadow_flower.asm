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
.INCLUDE "../actors/flower.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../devices/flower.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/laser.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_LaserTryAct
.IMPORT FuncA_Machine_LaserWriteReg
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawLaserMachine
.IMPORT FuncA_Room_HarmAvatarIfWithinLaserBeam
.IMPORT FuncA_Room_IsPointInLaserBeam
.IMPORT FuncA_Room_KillGooWithLaserBeam
.IMPORT FuncA_Room_MachineLaserReset
.IMPORT FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
.IMPORT FuncA_Room_RespawnFlowerDeviceIfDropped
.IMPORT FuncA_Room_SpawnExplosionAtPoint
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_MachineLaserReadRegC
.IMPORT Func_Noop
.IMPORT Func_SetMachineIndex
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_WriteToUpperAttributeTable
.IMPORT Ppu_ChrObjShadow2
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr

;;;=========================================================================;;;

;;; The actor index for the flower baddie in this room.
kFlowerActorIndex = 0

;;; The platform index for the zone that the flower baddie's head is in when
;;; attacking.
kFlowerHeadPlatformIndex = 1

;;; The machine index for the ShadowFlowerLaser machine in this room.
kLaserMachineIndex = 0

;;; The primary platform index for the ShadowFlowerLaser machine.
kLaserPlatformIndex = 0

;;; The initial and maximum permitted horizontal goal values for the laser.
kLaserInitGoalX = 9
kLaserMaxGoalX = 9

;;; The maximum and initial X-positions for the left of the laser platform.
.LINECONT +
kLaserMinPlatformLeft = $0020
kLaserInitPlatformLeft = \
    kLaserMinPlatformLeft + kLaserInitGoalX * kBlockWidthPx
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "PRGC_Shadow"

.EXPORT DataC_Shadow_Flower_sRoom
.PROC DataC_Shadow_Flower_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte Flags_bRoom, eArea::Shadow
    d_byte MinimapStartRow_u8, 13
    d_byte MinimapStartCol_u8, 3
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjShadow2)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Shadow_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_ShadowFlower_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_ShadowFlower_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_ShadowFlower_TickRoom
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/shadow_flower.room"
    .assert * - :- = 17 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kLaserMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::ShadowFlowerLaser
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::Laser
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, "C", 0, "X", 0
    d_byte MainPlatform_u8, kLaserPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_ShadowFlowerLaser_InitReset
    d_addr ReadReg_func_ptr, FuncC_Shadow_FlowerLaser_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_LaserWriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_ShadowFlowerLaser_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_ShadowFlowerLaser_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_ShadowFlowerLaser_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLaserMachine
    d_addr Reset_func_ptr, FuncA_Room_ShadowFlowerLaser_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   ;; ShadowFlowerLaser machine:
    .assert * - :- = kLaserPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLaserMachineWidthPx
    d_byte HeightPx_u8, kLaserMachineHeightPx
    d_word Left_i16, kLaserInitPlatformLeft
    d_word Top_i16,   $0020
    D_END
    ;; Flower baddie head zone:
    .assert * - :- = kFlowerHeadPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0030
    d_word Top_i16,   $00a8
    D_END
    ;; Acid:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $80
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0050
    d_word Top_i16,   $00ca
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kFlowerActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadFlower
    d_word PosX_i16, $0028
    d_word PosY_i16, $00b8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGooGreen
    d_word PosX_i16, $005a
    d_word PosY_i16, $0088
    d_byte Param_byte, bObj::FlipHV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGooGreen
    d_word PosX_i16, $0098
    d_word PosY_i16, $0078
    d_byte Param_byte, bObj::FlipHV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGooGreen
    d_word PosX_i16, $00a8
    d_word PosY_i16, $00b8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGooRed
    d_word PosX_i16, $00b8
    d_word PosY_i16, $0098
    d_byte Param_byte, bObj::FlipHV
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kFlowerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Flower
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 2
    d_byte Target_byte, eFlag::FlowerShadow
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 2
    d_byte Target_byte, kLaserMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::ShadowDescent
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Shadow_FlowerLaser_ReadReg
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

.PROC FuncA_Room_ShadowFlower_EnterRoom
    ;; Determine if the flower should be present in the room.
    jsr FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
    ;; IF the flower should be present, then remove the device for now and
    ;; leave the baddie in its place.
    lda #eDevice::Placeholder
    cmp Ram_DeviceType_eDevice_arr + kFlowerDeviceIndex
    beq @removeFlowerActor
    @removeFlowerDevice:
    sta Ram_DeviceType_eDevice_arr + kFlowerDeviceIndex
    rts
    ;; Otherwise, the flower should be absent, so the device has already been
    ;; removed; remove the baddie as well.
    @removeFlowerActor:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kFlowerActorIndex
    rts
.ENDPROC

.PROC FuncA_Room_ShadowFlower_TickRoom
    ;; Apply laser beam damage to the avatar and goo baddies.
    ldx #kLaserMachineIndex
    jsr Func_SetMachineIndex
    jsr FuncA_Room_HarmAvatarIfWithinLaserBeam
    jsr FuncA_Room_KillGooWithLaserBeam
_MaybeRespawnFlower:
    ;; If the flower baddie is dead, respawn the flower if/when necessary.
    ;; Otherwise, check if the laser beam is hitting the flower baddie.
    lda Ram_ActorType_eActor_arr + kFlowerActorIndex
    cmp #eActor::BadFlower
    jne FuncA_Room_RespawnFlowerDeviceIfDropped
_MaybeKillFlowerBaddie:
    ;; Kill the flower baddie if the laser beam hits its head.
    lda Ram_ActorState1_byte_arr + kFlowerActorIndex  ; current eBadFlower mode
    cmp #eBadFlower::Attacking
    bne @done  ; the flower baddie's head is not in the zone
    ldy #kFlowerHeadPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter
    jsr FuncA_Room_IsPointInLaserBeam  ; returns C
    bcc @done  ; the laser is not hitting the zone
    jsr FuncA_Room_SpawnExplosionAtPoint
    ldx #kFlowerActorIndex  ; param: actor index
    jsr Func_InitActorSmokeExplosion
    ;; TODO: play a sound for the flower baddie dying
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_ShadowFlowerLaser_InitReset
    lda #kLaserInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kLaserMachineIndex
    jmp FuncA_Room_MachineLaserReset
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_ShadowFlowerLaser_TryMove
    lda #kLaserMaxGoalX  ; param: max goal horz
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncA_Machine_ShadowFlowerLaser_TryAct
    ldx Ram_MachineGoalHorz_u8_arr + kLaserMachineIndex
    lda _LaserBottom_i16_0_arr, x  ; param: laser bottom (lo)
    ldy #0                         ; param: laser bottom (hi)
    jmp FuncA_Machine_LaserTryAct
_LaserBottom_i16_0_arr:
:   .byte $50, $c0, $90, $70, $c5, $70, $c5, $80, $c0, $30
    .assert * - :- = kLaserMaxGoalX + 1, error
.ENDPROC

.PROC FuncA_Machine_ShadowFlowerLaser_Tick
    ldax #kLaserMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; @prereq Rendering is disabled.
.PROC FuncA_Terrain_ShadowFlower_FadeInRoom
    ldx #5    ; param: num bytes to write
    ldy #$aa  ; param: attribute value
    lda #$32  ; param: initial byte offset
    jmp Func_WriteToUpperAttributeTable
.ENDPROC

;;;=========================================================================;;;
