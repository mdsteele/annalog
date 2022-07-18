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
.INCLUDE "../machine.inc"
.INCLUDE "../machines/cannon.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_GardenAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_GardenAreaName_u8_arr
.IMPORT DataA_Room_Garden_sTileset
.IMPORT FuncA_Objects_DrawCannonMachine
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_InitGrenadeActor
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_RoomState

;;;=========================================================================;;;

;;; The actor index for grenades launched by the GardenBossCannon machine.
kGrenadeActorIndex = 4

;;; The machine index for the GardenBossCannon machine.
kCannonMachineIndex = 0
;;; The platform index for the GardenBossCannon machine.
kCannonPlatformIndex = 0
;;; Initial position for grenades shot from the cannon.
kCannonGrenadeInitPosX = $58
kCannonGrenadeInitPosY = $a8

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u1         .byte
    LeverRight_u1        .byte
    ;; The current aim angle of the GardenBossCannon machine (0-255).
    CannonAngle_u8       .byte
    ;; The goal value of the GardenBossCannon machine's Y register; it will
    ;; keep moving until this is reached.
    CannonGoalY_u8       .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_Tower_sRoom
.PROC DataC_Garden_Tower_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $110
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 7
    d_byte MinimapWidth_u8, 2
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjGarden)
    d_addr Tick_func_ptr, FuncC_Garden_Tower_TickRoom
    d_addr Draw_func_ptr, FuncA_Objects_GardenTower_Draw
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_GardenAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_GardenAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, FuncC_Garden_Tower_InitRoom
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/garden_tower.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
    .assert kCannonMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenBossCannon
    d_byte Conduit_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $50
    d_byte RegNames_u8_arr4, "L", "R", 0, "Y"
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, _Cannon_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, _Cannon_TryMove
    d_addr TryAct_func_ptr, _Cannon_TryAct
    d_addr Tick_func_ptr, _Cannon_Tick
    d_addr Draw_func_ptr, FuncA_Objects_GardenTowerCannon_Draw
    d_addr Reset_func_ptr, _Cannon_Reset
    D_END
_Platforms_sPlatform_arr:
    .assert kCannonPlatformIndex = 0, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBlockWidthPx
    d_byte HeightPx_u8, kBlockHeightPx
    d_word Left_i16, kCannonGrenadeInitPosX - kTileWidthPx
    d_word Top_i16,  kCannonGrenadeInitPosY - kTileHeightPx
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Crawler
    d_byte TileRow_u8, 35
    d_byte TileCol_u8, 22
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Crawler
    d_byte TileRow_u8, 31
    d_byte TileCol_u8, 34
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Crawler
    d_byte TileRow_u8, 43
    d_byte TileCol_u8, 23
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Vinebug
    d_byte TileRow_u8, 33
    d_byte TileCol_u8, 11
    d_byte Param_byte, 0
    D_END
    .assert kGrenadeActorIndex = 4, error
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 14
    d_byte BlockCol_u8, 3
    d_byte Target_u8, sState::LeverLeft_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 14
    d_byte BlockCol_u8, 7
    d_byte Target_u8, sState::LeverRight_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 2
    d_byte Target_u8, kCannonMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::UnlockedDoor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 14
    d_byte Target_u8, eRoom::GardenBoss
    D_END
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | bPassage::SameScreen | 0
    d_byte Destination_eRoom, eRoom::GardenShaft
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | bPassage::SameScreen | 1
    d_byte Destination_eRoom, eRoom::GardenShaft
    d_byte SpawnBlock_u8, 17
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::GardenTunnel
    d_byte SpawnBlock_u8, 3
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::MermaidEntry
    d_byte SpawnBlock_u8, 19
    D_END
_Cannon_ReadReg:
    cmp #$c
    beq @readL
    cmp #$d
    beq @readR
    @readY:
    lda Ram_RoomState + sState::CannonAngle_u8
    and #$80
    asl a
    rol a
    rts
    @readL:
    lda Ram_RoomState + sState::LeverLeft_u1
    rts
    @readR:
    lda Ram_RoomState + sState::LeverRight_u1
    rts
_Cannon_TryMove:
    cpx #eDir::Down
    beq @moveDown
    @moveUp:
    ldy Ram_RoomState + sState::CannonGoalY_u8
    bne @error
    iny
    bne @success  ; unconditional
    @moveDown:
    ldy Ram_RoomState + sState::CannonGoalY_u8
    beq @error
    dey
    @success:
    sty Ram_RoomState + sState::CannonGoalY_u8
    lda #kCannonMoveCountdown
    clc  ; clear C to indicate success
    rts
    @error:
    sec  ; set C to indicate failure
    rts
_Cannon_TryAct:
    lda #kCannonGrenadeInitPosX
    sta Ram_ActorPosX_i16_0_arr + kGrenadeActorIndex
    lda #kCannonGrenadeInitPosY
    sta Ram_ActorPosY_i16_0_arr + kGrenadeActorIndex
    lda #0
    sta Ram_ActorPosX_i16_1_arr + kGrenadeActorIndex
    sta Ram_ActorPosY_i16_1_arr + kGrenadeActorIndex
    ldx #kGrenadeActorIndex  ; param: actor index
    lda Ram_RoomState + sState::CannonGoalY_u8  ; param: aim angle (0-1)
    jsr Func_InitGrenadeActor
    lda #kCannonActCountdown
    clc  ; clear C to indicate success
    rts
_Cannon_Tick:
    lda Ram_RoomState + sState::CannonGoalY_u8
    beq @moveDown
    @moveUp:
    lda Ram_RoomState + sState::CannonAngle_u8
    add #$100 / kCannonMoveCountdown
    bcc @setAngle
    jsr Func_MachineFinishResetting
    lda #$ff
    bne @setAngle  ; unconditional
    @moveDown:
    lda Ram_RoomState + sState::CannonAngle_u8
    sub #$100 / kCannonMoveCountdown
    bge @setAngle
    jsr Func_MachineFinishResetting
    lda #0
    @setAngle:
    sta Ram_RoomState + sState::CannonAngle_u8
    rts
_Cannon_Reset:
    lda #0
    sta Ram_RoomState + sState::CannonGoalY_u8
    ;; TODO: reset target practice
    rts
.ENDPROC

;;; Room init function for the GardenTower room.
.PROC FuncC_Garden_Tower_InitRoom
    ;; TODO: Init target practice.
    rts
.ENDPROC

;;; Room tick function for the GardenTower room.
.PROC FuncC_Garden_Tower_TickRoom
    ;; TODO: Tick target practice.
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for this room.
.PROC FuncA_Objects_GardenTower_Draw
    ;; TODO: Draw target practice.
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the GardenBossCannon machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.PROC FuncA_Objects_GardenTowerCannon_Draw
    ldx #kCannonPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx Ram_RoomState + sState::CannonAngle_u8  ; param: aim angle
    ldy #0  ; param: horz flip
    jmp FuncA_Objects_DrawCannonMachine
.ENDPROC

;;;=========================================================================;;;
