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
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Prison_sTileset
.IMPORT DataC_Garden_AreaCells_u8_arr2_arr
.IMPORT DataC_Garden_AreaName_u8_arr
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_InitGrenadeActor
.IMPORT Func_InitSmokeActor
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Ppu_ChrUpgrade
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_RoomState
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; The actor index for grenades launched by the GardenBossCannon machine.
kGrenadeActorIndex = 0
;;; The actor index for the puff of smoke created when the upgrade appears.
kSmokeActorIndex = 1

;;; The device index for the upgrade that appears when the boss is defeated.
kUpgradeDeviceIndex = 0
;;; The room block row/col where the upgrade will appear.
kUpgradeBlockRow = 6
kUpgradeBlockCol = 10

;;; The machine index for the GardenBossCannon machine.
kCannonMachineIndex = 0
;;; The platform index for the GardenBossCannon machine.
kCannonPlatformIndex = 0
;;; The initial and max values for sState::CannonRegY_u8.
kCannonInitRegY = 0
kCannonMaxRegY = 1
;;; How many frames the GardenBossCannon machine spends per move/act operation.
kCannonMoveCountdown = $20
kCannonActCountdown = $40
;;; Various OBJ tile IDs used for drawing the GardenBossCannon machine.
kCannonTileIdLightOff   = $70
kCannonTileIdLightOn    = $71
kCannonTileIdCornerTop  = $7a
kCannonTileIdCornerBase = $7b
kCannonTileIdBarrelHigh = $7c
kCannonTileIdBarrelMid  = $7d
kCannonTileIdBarrelLow  = $7e
;;; Initial position for grenades shot from the cannon.
kCannonGrenadeInitPosX = $28
kCannonGrenadeInitPosY = $78

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u1         .byte
    LeverRight_u1        .byte
    ;; Counts down when nonzero; upon reaching zero, spawns the upgrade.
    SpawnUpgradeTimer_u8 .byte
    ;; The current value of the GardenBossCannon machine's Y register.
    CannonRegY_u8        .byte
    ;; The goal value of the GardenBossCannon machine's Y register; it will
    ;; keep moving until this is reached.
    CannonGoalY_u8       .byte
    ;; Nonzero if the GardenBossCannon machine is moving/firing; this is how
    ;; many more frames until it finishes the current move/act operation.
    CannonCountdown_u8   .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_Boss_sRoom
.PROC DataC_Garden_Boss_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 6
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrUpgrade)
    d_addr Tick_func_ptr, FuncC_Garden_BossRoomTick
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataC_Garden_AreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataC_Garden_AreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Prison_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Init_func_ptr, FuncC_Garden_BossRoomInit
    D_END
_TerrainData:
:   .incbin "out/data/garden_boss.room"
    .assert * - :- = 16 * 16, error
_Machines_sMachine_arr:
    .assert kCannonMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenBossCannon
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0e
    d_byte RegNames_u8_arr4, "L", "R", 0, "Y"
    d_addr Init_func_ptr, _Cannon_Init
    d_addr ReadReg_func_ptr, _Cannon_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, _Cannon_TryMove
    d_addr TryAct_func_ptr, _Cannon_TryAct
    d_addr Tick_func_ptr, _Cannon_Tick
    d_addr Draw_func_ptr, FuncA_Objects_GardenBossCannon_Draw
    d_addr Reset_func_ptr, _Cannon_Reset
    d_byte Padding
    .res kMachinePadding
    D_END
_Platforms_sPlatform_arr:
    .assert kCannonPlatformIndex = 0, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_byte WidthPx_u8,  $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0020
    d_word Top_i16,   $0070
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
    .assert kUpgradeDeviceIndex = 0, error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, kUpgradeBlockRow
    d_byte BlockCol_u8, kUpgradeBlockCol
    d_byte Target_u8, eFlag::UpgradeMaxInstructions0
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 3
    d_byte Target_u8, sState::LeverLeft_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 10
    d_byte Target_u8, sState::LeverRight_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 12
    d_byte Target_u8, kCannonMachineIndex
    D_END
    ;; TODO: Remove this.
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_u8, eFlag::UpgradeOpcodeIfGoto
    D_END
    .byte eDevice::None
_Cannon_Init:
    lda #0
    sta Ram_RoomState + sState::CannonCountdown_u8
    .assert kCannonInitRegY = 0, error
    sta Ram_RoomState + sState::CannonRegY_u8
    sta Ram_RoomState + sState::CannonGoalY_u8
    rts
_Cannon_ReadReg:
    cmp #$c
    beq @readL
    cmp #$d
    beq @readR
    @readY:
    lda Ram_RoomState + sState::CannonRegY_u8
    rts
    @readL:
    lda Ram_RoomState + sState::LeverLeft_u1
    rts
    @readR:
    lda Ram_RoomState + sState::LeverRight_u1
    rts
_Cannon_TryMove:
    lda Ram_RoomState + sState::CannonCountdown_u8
    beq @ready
    sec  ; set C to indicate not ready yet
    rts
    @ready:
    lda Ram_RoomState + sState::CannonRegY_u8
    cpx #eDir::Down
    beq @moveDown
    @moveUp:
    cmp #kCannonMaxRegY
    bge @error
    tay
    iny
    bne @success  ; unconditional
    @moveDown:
    tay
    beq @error
    dey
    @success:
    sty Ram_RoomState + sState::CannonGoalY_u8
    clc  ; clear C to indicate success
    rts
    @error:
    jmp Func_MachineError
_Cannon_TryAct:
    lda Ram_RoomState + sState::CannonCountdown_u8
    beq @ready
    sec  ; set C to indicate not ready yet
    rts
    @ready:
    lda #kCannonActCountdown
    sta Ram_RoomState + sState::CannonCountdown_u8
    ;; Fire a grenade:
    lda #eActor::Grenade
    sta Ram_ActorType_eActor_arr + kGrenadeActorIndex
    lda #kCannonGrenadeInitPosX
    sta Ram_ActorPosX_i16_0_arr + kGrenadeActorIndex
    lda #kCannonGrenadeInitPosY
    sta Ram_ActorPosY_i16_0_arr + kGrenadeActorIndex
    lda #0
    sta Ram_ActorPosX_i16_1_arr + kGrenadeActorIndex
    sta Ram_ActorPosY_i16_1_arr + kGrenadeActorIndex
    ldx #kGrenadeActorIndex  ; param: actor index
    lda Ram_RoomState + sState::CannonRegY_u8  ; param: aim angle
    jsr Func_InitGrenadeActor
    clc  ; clear C to indicate success
    rts
_Cannon_Tick:
    lda Ram_RoomState + sState::CannonCountdown_u8
    bne @continueMove
    ldy Ram_RoomState + sState::CannonRegY_u8
    cpy Ram_RoomState + sState::CannonGoalY_u8
    jeq Func_MachineFinishResetting
    bge @beginMoveUp
    @beginMoveDown:
    iny
    bne @beginMove  ; unconditional
    @beginMoveUp:
    dey
    @beginMove:
    sty Ram_RoomState + sState::CannonRegY_u8
    lda #kCannonMoveCountdown
    sta Ram_RoomState + sState::CannonCountdown_u8
    @continueMove:
    dec Ram_RoomState + sState::CannonCountdown_u8
    rts
_Cannon_Reset:
    lda #0
    sta Ram_RoomState + sState::CannonGoalY_u8
    rts
.ENDPROC

;;; Room init function for the GardenBoss room.
.PROC FuncC_Garden_BossRoomInit
    ;; Init room state variables.
    lda #0
    sta Ram_RoomState + sState::LeverLeft_u1
    sta Ram_RoomState + sState::LeverRight_u1
    sta Ram_RoomState + sState::SpawnUpgradeTimer_u8
    ;; Hide the upgrade device for now.
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kUpgradeDeviceIndex
    ;; If the boss hasn't been defeated yet, then spawn the boss.
    lda Sram_ProgressFlags_arr + (eFlag::BossGarden >> 3)
    and #1 << (eFlag::BossGarden & $07)
    beq _SpawnBoss
    ;; If the boss has been defeated, but the upgrade hasn't been collected
    ;; yet, then set a timer to spawn the upgrade.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeMaxInstructions0 >> 3)
    and #1 << (eFlag::UpgradeMaxInstructions0 & $07)
    bne @playerHasUpgrade
    lda #30  ; 0.5 seconds
    sta Ram_RoomState + sState::SpawnUpgradeTimer_u8
    rts
    @playerHasUpgrade:
    ;; If the boss has been defeated and the upgrade has been collected, but
    ;; the conduit hasn't been activated yet, then spawn the conduit lever.
    lda Sram_ProgressFlags_arr + (eFlag::ConduitGarden >> 3)
    and #1 << (eFlag::ConduitGarden & $07)
    bne @conduitIsActivated
    ;; TODO: spawn conduit lever
    @conduitIsActivated:
    rts
_SpawnBoss:
    ;; TODO: implement boss behavior
    rts
.ENDPROC

;;; Room tick function for the GardenBoss room.
.PROC FuncC_Garden_BossRoomTick
_SpawnUpgrade:
    ;; If the timer is nonzero, count it down, and spawn the upgrade at zero.
    lda Ram_RoomState + sState::SpawnUpgradeTimer_u8
    beq @doneUpgrade
    dec Ram_RoomState + sState::SpawnUpgradeTimer_u8
    bne @doneUpgrade
    ;; Show the upgrade device and animate it.
    lda #eDevice::Upgrade
    sta Ram_DeviceType_eDevice_arr + kUpgradeDeviceIndex
    lda #kUpgradeDeviceAnimStart
    sta Ram_DeviceAnim_u8_arr + kUpgradeDeviceIndex
    ;; TODO: play a sound
    ;; Create a puff of smoke over the upgrade device.
    lda #eActor::Smoke
    sta Ram_ActorType_eActor_arr + kSmokeActorIndex
    lda #kUpgradeBlockCol * kBlockWidthPx + kBlockWidthPx / 2
    sta Ram_ActorPosX_i16_0_arr + kSmokeActorIndex
    lda #kUpgradeBlockRow * kBlockHeightPx + kBlockHeightPx / 2
    sta Ram_ActorPosY_i16_0_arr + kSmokeActorIndex
    lda #0
    sta Ram_ActorPosX_i16_1_arr + kSmokeActorIndex
    sta Ram_ActorPosY_i16_1_arr + kSmokeActorIndex
    ldx #kSmokeActorIndex  ; param: actor index
    jsr Func_InitSmokeActor
    @doneUpgrade:
_TickBoss:
    ;; TODO: implement boss behavior
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_GardenBossCannon_Draw
    ;; Allocate objects.
    ldx #kCannonPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    jsr FuncA_Objects_MoveShapeDownOneTile
    jsr FuncA_Objects_MoveShapeRightOneTile
    lda #0  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags.
    lda #kMachineLightPalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    ;; Set corner tile IDs.
    lda #kCannonTileIdCornerTop
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kCannonTileIdCornerBase
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    ;; Set light tile ID.
    lda Ram_MachineStatus_eMachine_arr + kCannonMachineIndex
    cmp #eMachine::Error
    bne @lightOff
    lda Zp_FrameCounter_u8
    and #$08
    beq @lightOff
    lda #kCannonTileIdLightOn
    bne @setLight  ; unconditional
    @lightOff:
    lda #kCannonTileIdLightOff
    @setLight:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    ;; Set barrel tile ID.
    ;; TODO: Animate motion.
    lda Ram_RoomState + sState::CannonRegY_u8
    bne @barrelHigh
    @barrelLow:
    lda #kCannonTileIdBarrelLow
    bne @setBarrel  ; unconditional
    @barrelHigh:
    lda #kCannonTileIdBarrelHigh
    @setBarrel:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
