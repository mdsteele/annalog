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
.INCLUDE "../machines/cannon.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"
.INCLUDE "garden_tower.inc"

.IMPORT DataA_Room_Garden_sTileset
.IMPORT FuncA_Machine_CannonTick
.IMPORT FuncA_Machine_CannonTryAct
.IMPORT FuncA_Machine_CannonTryMove
.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_DrawCannonMachine
.IMPORT FuncA_Objects_DrawCratePlatform
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_FindGrenadeActor
.IMPORT FuncA_Room_MachineCannonReset
.IMPORT Func_InitActorProjSmoke
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MachineCannonReadRegY
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_ShakeRoom
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_RoomState
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The device index for the door that leads to the boss room.
kDoorDeviceIndex = 3

;;; The index of the passage that is sometimes blocked by crates.
kCratePassageIndex = 1

;;; The machine index for the GardenTowerCannon machine.
kCannonMachineIndex = 0
;;; The platform index for the GardenTowerCannon machine.
kCannonPlatformIndex = 0

;;; The platform index for the breakable tower wall.
kBreakableWallPlatformIndex = 3

;;; The room pixel position/size of the breakable tower wall.
kBreakableWallPlatformLeft = $0090
kBreakableWallPlatformTop  = $0080
kBreakableWallPlatformWidth  = $08
kBreakableWallPlatformHeight = $20
.LINECONT +
kBreakableWallPlatformYCenter = \
    kBreakableWallPlatformTop + kBreakableWallPlatformHeight / 2
.LINECONT -

;;; How many grenades need to hit the upper/lower breakable wall to destroy it.
kBreakableWallHitsToDestroy = 2

;;; The platform indices for the positions the crates can be in.
kWallCratePlatformIndex = 1
kFloorCratePlatformIndex = 2

;;; OBJ palette numbers used for drawing certain platforms in this room.
kPaletteObjCrate       = 0
kPaletteObjGardenBrick = 0

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u1  .byte
    LeverRight_u1 .byte
    ;; How many times each section of the breakable wall has been hit.
    BreakableWallUpperHits_u8 .byte
    BreakableWallLowerHits_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_Tower_sRoom
.PROC DataC_Garden_Tower_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $110
    d_byte Flags_bRoom, bRoom::Tall | eArea::Garden
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 7
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjGarden)
    d_addr Tick_func_ptr, FuncC_Garden_Tower_TickRoom
    d_addr Draw_func_ptr, FuncA_Objects_GardenTower_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Garden_Tower_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/garden_tower.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kCannonMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenTowerCannon
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::CannonRight
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $50
    d_byte RegNames_u8_arr4, "L", "R", 0, "Y"
    d_byte MainPlatform_u8, kCannonPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Garden_TowerCannon_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CannonTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CannonTryAct
    d_addr Tick_func_ptr, FuncA_Machine_CannonTick
    d_addr Draw_func_ptr, FuncA_Objects_DrawCannonMachine
    d_addr Reset_func_ptr, FuncC_Garden_TowerCannon_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kCannonPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBlockWidthPx
    d_byte HeightPx_u8, kBlockHeightPx
    d_word Left_i16,  $0050
    d_word Top_i16,   $00a4
    D_END
    .assert * - :- = kWallCratePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0010
    d_word Top_i16,   $0110
    D_END
    .assert * - :- = kFloorCratePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $0f
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0021
    d_word Top_i16,   $0140
    D_END
    .assert * - :- = kBreakableWallPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBreakableWallPlatformWidth
    d_byte HeightPx_u8, kBreakableWallPlatformHeight
    d_word Left_i16,    kBreakableWallPlatformLeft
    d_word Top_i16,     kBreakableWallPlatformTop
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $00b0
    d_word PosY_i16, $0118
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0110
    d_word PosY_i16, $00f8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $00b8
    d_word PosY_i16, $0158
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadVinebug
    d_word PosX_i16, $0058
    d_word PosY_i16, $0108
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 14
    d_byte BlockCol_u8, 3
    d_byte Target_u8, sState::LeverLeft_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
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
    .assert * - :- = kDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::UnlockedDoor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 14
    d_byte Target_u8, eRoom::BossGarden
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | bPassage::SameScreen | 0
    d_byte Destination_eRoom, eRoom::GardenShaft
    d_byte SpawnBlock_u8, 5
    D_END
    .assert * - :- = kCratePassageIndex * .sizeof(sPassage), error
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
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; Room init function for the GardenTower room.
;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncC_Garden_Tower_EnterRoom
    sta Zp_Tmp1_byte  ; bSpawn value
_BreakableWall:
    ;; If entering from the boss room door, remove the breakable wall, so the
    ;; player won't be trapped.  (In normal gameplay, it should be impossible
    ;; to enter from that door if the wall is still there; this is just a
    ;; safety measure.)
    .assert bSpawn::IsPassage <> 0, error
    cmp #kDoorDeviceIndex
    beq @removeWall
    ;; Check if the breakable wall has been broken already; if so, remove it.
    flag_bit Sram_ProgressFlags_arr, eFlag::GardenTowerWallBroken
    beq @done
    @removeWall:
    ldx #ePlatform::Zone
    stx Ram_PlatformType_ePlatform_arr + kBreakableWallPlatformIndex
    @done:
_Crates:
    ldx #ePlatform::Zone
    ;; If entering from the passage that the wall crate blocks, always remove
    ;; the wall crate, even if the flag isn't set.  (In normal gameplay, it
    ;; should be impossible to enter from that passage before the flag is set;
    ;; this is just a safety measure.)
    lda Zp_Tmp1_byte  ; bSpawn value
    cmp #bSpawn::IsPassage | kCratePassageIndex
    beq @removeWallCrates
    ;; Check whether the crates should be in the wall or on the floor, and
    ;; remove them from whichever of those two places they shouldn't be.
    ;; (Note that at this point, X is still set to ePlatform::Zone.)
    flag_bit Sram_ProgressFlags_arr, eFlag::GardenTowerCratesPlaced
    bne @removeWallCrates
    @removeFloorCrates:
    stx Ram_PlatformType_ePlatform_arr + kFloorCratePlatformIndex
    rts
    @removeWallCrates:
    stx Ram_PlatformType_ePlatform_arr + kWallCratePlatformIndex
    rts
.ENDPROC

;;; Room tick function for the GardenTower room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Garden_Tower_TickRoom
    ;; If the breakable wall is already destroyed, then we're done.
    lda Ram_PlatformType_ePlatform_arr + kBreakableWallPlatformIndex
    cmp #ePlatform::Solid
    bne _Done
    ;; Find the grenade (if any).  If there isn't one, we're done.
    jsr FuncA_Room_FindGrenadeActor  ; returns C and X
    bcs _Done
    ;; Check if the grenade is within the breakable wall.  If not, we're done.
    jsr Func_SetPointToActorCenter  ; preserves X
    ldy #kBreakableWallPlatformIndex  ; param: platform inde
    jsr Func_IsPointInPlatform  ; preserves X, returns C
    bcc _Done
    ;; Check whether this is a high grenade or a low grenade.
    lda #<kBreakableWallPlatformYCenter
    cmp Ram_ActorPosY_i16_0_arr, x
    lda #>kBreakableWallPlatformYCenter
    sbc Ram_ActorPosY_i16_1_arr, x
    bge _GrenadeIsHigh
_GrenadeIsLow:
    ;; If the lower portion of the wall is already destroyed, we're done.
    lda Zp_RoomState + sState::BreakableWallLowerHits_u8
    cmp #kBreakableWallHitsToDestroy
    bge _Done
    ;; Hit the wall.
    inc Zp_RoomState + sState::BreakableWallLowerHits_u8
    bne _CheckIfWallDestroyed  ; unconditional
_GrenadeIsHigh:
    ;; If the lower portion of the wall is already destroyed, we're done.
    lda Zp_RoomState + sState::BreakableWallUpperHits_u8
    cmp #kBreakableWallHitsToDestroy
    bge _Done
    ;; Hit the wall.
    inc Zp_RoomState + sState::BreakableWallUpperHits_u8
_CheckIfWallDestroyed:
    lda Zp_RoomState + sState::BreakableWallUpperHits_u8
    cmp #kBreakableWallHitsToDestroy
    blt _ExplodeGrenade
    lda Zp_RoomState + sState::BreakableWallLowerHits_u8
    cmp #kBreakableWallHitsToDestroy
    blt _ExplodeGrenade
    ;; Remove the wall.
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kBreakableWallPlatformIndex
    stx Zp_Tmp1_byte  ; grenade actor index
    ldx #eFlag::GardenTowerWallBroken  ; param: flag
    jsr Func_SetFlag  ; preserves Zp_Tmp*
    ldx Zp_Tmp1_byte  ; grenade actor index
_ExplodeGrenade:
    ;; We've hit the wall, so explode the grenade.
    jsr Func_InitActorProjSmoke  ; preserves X
    ;; Shake the room.
    lda #8  ; param: num frames
    jsr Func_ShakeRoom
    ;; TODO: play a sound for hitting the wall
_Done:
    rts
.ENDPROC

.PROC FuncC_Garden_TowerCannon_ReadReg
    cmp #$c
    beq @readL
    cmp #$d
    beq @readR
    @readY:
    jmp Func_MachineCannonReadRegY
    @readL:
    lda Zp_RoomState + sState::LeverLeft_u1
    rts
    @readR:
    lda Zp_RoomState + sState::LeverRight_u1
    rts
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Garden_TowerCannon_Reset
    jsr FuncA_Room_MachineCannonReset
    lda #0
    sta Zp_RoomState + sState::BreakableWallUpperHits_u8
    sta Zp_RoomState + sState::BreakableWallLowerHits_u8
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for this room.
.PROC FuncA_Objects_GardenTower_DrawRoom
_BreakableWall:
    lda Ram_PlatformType_ePlatform_arr + kBreakableWallPlatformIndex
    cmp #ePlatform::Solid
    bne @done
    ldx #kBreakableWallPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx Zp_RoomState + sState::BreakableWallUpperHits_u8
    lda _Brick0TileId_u8, x  ; param: tile ID
    jsr FuncA_Objects_DrawGardenBrick  ; preserves X
    lda _Brick1TileId_u8, x  ; param: tile ID
    jsr FuncA_Objects_DrawGardenBrick  ; preserves X
    ldx Zp_RoomState + sState::BreakableWallLowerHits_u8
    lda _Brick2TileId_u8, x  ; param: tile ID
    jsr FuncA_Objects_DrawGardenBrick  ; preserves X
    lda _Brick3TileId_u8, x  ; param: tile ID
    jsr FuncA_Objects_DrawGardenBrick  ; preserves X
    @done:
_Crates:
    ldx #kWallCratePlatformIndex
    jsr FuncA_Objects_DrawCratePlatform
    ldx #kFloorCratePlatformIndex
    jmp FuncA_Objects_DrawCratePlatform
_Brick0TileId_u8:
    .byte kTileIdObjGardenBricksFirst + 0
    .byte kTileIdObjGardenBricksFirst + 2
    .byte kTileIdObjGardenBricksFirst + 1
_Brick1TileId_u8:
    .byte kTileIdObjGardenBricksFirst + 0
    .byte kTileIdObjGardenBricksFirst + 3
    .byte kTileIdObjGardenBricksFirst + 5
_Brick2TileId_u8:
    .byte kTileIdObjGardenBricksFirst + 0
    .byte kTileIdObjGardenBricksFirst + 2
    .byte kTileIdObjGardenBricksFirst + 4
_Brick3TileId_u8:
    .byte kTileIdObjGardenBricksFirst + 0
    .byte kTileIdObjGardenBricksFirst + 3
    .byte kTileIdObjGardenBricksFirst + 1
.ENDPROC

;;; Draws one brick in the breakable tower wall, at the current shape position,
;;; then moves the shape position down by one tile.
;;; @param A The tile ID.
;;; @preserve X
.PROC FuncA_Objects_DrawGardenBrick
    pha  ; tile ID
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    pla  ; tile ID
    bcs @done
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjGardenBrick
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @done:
    jmp FuncA_Objects_MoveShapeDownOneTile  ; preserves X
.ENDPROC

;;;=========================================================================;;;
