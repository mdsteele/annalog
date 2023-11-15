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
.INCLUDE "../actors/grenade.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/cannon.inc"
.INCLUDE "../macros.inc"
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
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawCannonMachine
.IMPORT FuncA_Objects_DrawCratePlatform
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_FindGrenadeActor
.IMPORT FuncA_Room_MachineCannonReset
.IMPORT FuncA_Room_ResetLever
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MachineCannonReadRegY
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeFracture
.IMPORT Func_PlaySfxExplodeSmall
.IMPORT Func_SetFlag
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_ShakeRoom
.IMPORT Ppu_ChrBgAnimStatic
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The device indices for the levers in this room.
kLeverLeftDeviceIndex = 0
kLeverRightDeviceIndex = 1
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

;;; How much to shake the room when a grenade hits the breakable tower wall
;;; (instead of the floor).
kBreakableWallShakeFrames = 8
.ASSERT kBreakableWallShakeFrames > kGrenadeShakeFrames, error

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

;;; How many frames to blink the breakable wall for when resetting it.
kBreakableWallBlinkFrames = 28

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
    LeverLeft_u8  .byte
    LeverRight_u8 .byte
    ;; How many times each section of the breakable wall has been hit.
    BreakableWallUpperHits_u8 .byte
    BreakableWallLowerHits_u8 .byte
    ;; How many more frames to blink the breakable wall for.
    BreakableWallBlink_u8 .byte
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
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Garden_Tower_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Garden_Tower_TickRoom
    d_addr Draw_func_ptr, FuncA_Objects_GardenTower_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/garden_tower.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kCannonMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenTowerCannon
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::CannonRight
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $50
    d_byte RegNames_u8_arr4, "L", "R", 0, "Y"
    d_byte MainPlatform_u8, kCannonPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Garden_TowerCannon_ReadReg
    d_addr WriteReg_func_ptr, FuncC_Garden_TowerCannon_WriteReg
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
    ;; TODO: add Harm platforms for thorns (removed when boss is defeated)
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
:   .assert * - :- = kLeverLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 14
    d_byte BlockCol_u8, 3
    d_byte Target_byte, sState::LeverLeft_u8
    D_END
    .assert * - :- = kLeverRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 14
    d_byte BlockCol_u8, 7
    d_byte Target_byte, sState::LeverRight_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 2
    d_byte Target_byte, kCannonMachineIndex
    D_END
    .assert * - :- = kDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 14
    d_byte Target_byte, eRoom::BossGarden
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
    sta T0  ; bSpawn value
_BreakableWall:
    ;; If entering from the boss room door, remove the breakable wall, so the
    ;; player won't be trapped.  (In normal gameplay, it should be impossible
    ;; to enter from that door if the wall is still there; this is just a
    ;; safety measure.)
    cmp #bSpawn::Device | kDoorDeviceIndex
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
    lda T0  ; bSpawn value
    cmp #bSpawn::Passage | kCratePassageIndex
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
    lda Zp_RoomState + sState::BreakableWallBlink_u8
    beq @done
    dec Zp_RoomState + sState::BreakableWallBlink_u8
    bne @done
    lda #0
    sta Zp_RoomState + sState::BreakableWallUpperHits_u8
    sta Zp_RoomState + sState::BreakableWallLowerHits_u8
    @done:
_CheckGrenade:
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
    ldy Zp_RoomState + sState::BreakableWallLowerHits_u8
    cpy #kBreakableWallHitsToDestroy
    bge _Done
    ;; Hit the wall.
    iny
    sty Zp_RoomState + sState::BreakableWallLowerHits_u8
    cpy #kBreakableWallHitsToDestroy
    blt _WallDamaged
    bge _PartOfWallDestroyed  ; unconditional
_GrenadeIsHigh:
    ;; If the upper portion of the wall is already destroyed, we're done.
    ldy Zp_RoomState + sState::BreakableWallUpperHits_u8
    cpy #kBreakableWallHitsToDestroy
    bge _Done
    ;; Hit the wall.
    iny
    sty Zp_RoomState + sState::BreakableWallUpperHits_u8
    cpy #kBreakableWallHitsToDestroy
    blt _WallDamaged
_PartOfWallDestroyed:
    jsr Func_PlaySfxExplodeFracture  ; preserves X
    ;; Check if both parts of the wall are now destroyed.
    lda Zp_RoomState + sState::BreakableWallUpperHits_u8
    add Zp_RoomState + sState::BreakableWallLowerHits_u8
    cmp #kBreakableWallHitsToDestroy * 2
    blt _ExplodeGrenade
    ;; Remove the wall.
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kBreakableWallPlatformIndex
    stx T0  ; grenade actor index
    ldx #eFlag::GardenTowerWallBroken  ; param: flag
    jsr Func_SetFlag  ; preserves T0+
    ldx T0  ; grenade actor index
    bpl _ExplodeGrenade  ; unconditional
_WallDamaged:
    jsr Func_PlaySfxExplodeSmall
_ExplodeGrenade:
    jsr Func_InitActorSmokeExplosion  ; preserves X
    lda #kBreakableWallShakeFrames  ; param: num frames
    jsr Func_ShakeRoom
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
    lda Zp_RoomState + sState::LeverLeft_u8
    rts
    @readR:
    lda Zp_RoomState + sState::LeverRight_u8
    rts
.ENDPROC

.PROC FuncC_Garden_TowerCannon_WriteReg
    cpx #$d
    beq _WriteR
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Garden_TowerCannon_Reset
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    ldx #kLeverRightDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
_ResetBreakbleWall:
    lda Zp_RoomState + sState::BreakableWallUpperHits_u8
    ora Zp_RoomState + sState::BreakableWallLowerHits_u8
    beq @done
    lda #kBreakableWallBlinkFrames
    sta Zp_RoomState + sState::BreakableWallBlink_u8
    @done:
_ResetMachine:
    jmp FuncA_Room_MachineCannonReset
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for this room.
.PROC FuncA_Objects_GardenTower_DrawRoom
_Thorns:
    ;; If the garden boss has been defeated, disable the BG thorns animation.
    flag_bit Sram_ProgressFlags_arr, eFlag::BossGarden
    beq @done
    lda #<.bank(Ppu_ChrBgAnimStatic)
    sta Zp_Chr04Bank_u8
    @done:
    ;; TODO: If thorns present, animate them like in the boss room.
_BreakableWall:
    ;; If the breakble wall platform is completely destroyed, we're done.
    lda Ram_PlatformType_ePlatform_arr + kBreakableWallPlatformIndex
    cmp #ePlatform::Solid
    bne @done
    ;; If the breakable wall blink timer is active, blink between drawing the
    ;; wall as it actually is, and drawing it solid.
    lda Zp_RoomState + sState::BreakableWallBlink_u8
    and #$04
    beq @drawNormal
    @drawSolid:
    lda #0
    sta T2  ; virtual num upper hits
    beq @draw  ; unconditional
    @drawNormal:
    lda Zp_RoomState + sState::BreakableWallUpperHits_u8
    sta T2  ; virtual num upper hits
    lda Zp_RoomState + sState::BreakableWallLowerHits_u8
    @draw:
    sta T3  ; virtual num lower hits
    ;; Draw each brick of the breakable wall.
    ldx #kBreakableWallPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx T2  ; virtual num upper hits
    lda _Brick0TileId_u8, x  ; param: tile ID
    jsr FuncA_Objects_DrawGardenBrick  ; preserves X and T2+
    lda _Brick1TileId_u8, x  ; param: tile ID
    jsr FuncA_Objects_DrawGardenBrick  ; preserves X and T2+
    ldx T3  ; virtual num lower hits
    lda _Brick2TileId_u8, x  ; param: tile ID
    jsr FuncA_Objects_DrawGardenBrick  ; preserves X
    lda _Brick3TileId_u8, x  ; param: tile ID
    jsr FuncA_Objects_DrawGardenBrick
    @done:
_Crates:
    ldx #kWallCratePlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawCratePlatform
    ldx #kFloorCratePlatformIndex  ; param: platform index
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
;;; @preserve X, T2+
.PROC FuncA_Objects_DrawGardenBrick
    ldy #kPaletteObjGardenBrick  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    jmp FuncA_Objects_MoveShapeDownOneTile  ; preserves X and T2+
.ENDPROC

;;;=========================================================================;;;
