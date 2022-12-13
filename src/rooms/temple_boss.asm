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
.INCLUDE "../irq.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../window.inc"

.IMPORT DataA_Room_Temple_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_Alloc2x1Shape
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawCarriageMachine
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Room_InitActorProjBreakball
.IMPORT FuncA_Room_InitBossPhase
.IMPORT FuncA_Room_TickBossPhase
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_Noop
.IMPORT Int_WindowTopIrq
.IMPORT Ppu_ChrBgOutbreak
.IMPORT Ppu_ChrObjTemple
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Chr0cBank_u8
.IMPORTZP Zp_NextIrq_int_ptr
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; The fixed scroll-X position for this room.
kRoomScrollX = $08

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
kBlasterCooldownFrames = 30

;;;=========================================================================;;;

;;; The room pixel Y-positions for the top and bottom of the zone that the boss
;;; can move within.
kBossZoneTopY    = $26
kBossZoneBottomY = $63

;;; The height of the boss zone, in pixels.
kBossZoneHeightPx = kBossZoneBottomY - kBossZoneTopY
;;; How many BG tile rows are visible in the boss zone (rounded up).
kBossZoneHeightTiles = (kBossZoneHeightPx + kTileHeightPx - 1) / kTileHeightPx

;;; The height of the boss's body in the BG tile grid.
.DEFINE kBossBodyHeightTiles 4
kBossBodyHeightPx = kBossBodyHeightTiles * kTileHeightPx
.ASSERT kBossBodyHeightPx < kBossZoneHeightPx, error

;;; The width of the boss's body in the BG tile grid.
kBossBodyWidthTiles = 10

;;; The tile row in the lower nametable for the top edge of the boss's BG
;;; tiles.
kBossBodyStartRow = 8

;;; How many BG tile rows above/below the boss must be reserved because they'll
;;; be visible in the boss zone.
kBossMarginHeightTiles = kBossZoneHeightTiles - kBossBodyHeightTiles

;;; How many BG tile rows are needed for the boss and the margins above/below.
kBossTotalHeightTiles = kBossBodyHeightTiles + kBossMarginHeightTiles * 2

;;; The tile row in the lower nametable for the top of the margin space above
;;; the boss's BG tiles.
kBossMarginStartRow = kBossBodyStartRow - kBossMarginHeightTiles
;;; Assert that the upper BG margin doesn't go above the top of the lower
;;; nametable.
.ASSERT kBossMarginStartRow >= 0, error
;;; Assert that the lower BG margin doesn't run into the top of the window.
.ASSERT kBossMarginStartRow + kBossTotalHeightTiles <= kWindowStartRow, error

;;; The initial value for sState::BossTopY_u8.
kBossInitTopY = kBossZoneBottomY - kBossBodyHeightPx

.LINECONT +
;;; The PPU address in the lower nametable for the leftmost tile column of the
;;; first row of the margin above the boss's body.
Ppu_BossMarginStart = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kBossMarginStartRow * kScreenWidthTiles
;;; The PPU address in the lower nametable for the tile at the top-left corner
;;; of the boss's body.
Ppu_BossBodyStart = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kBossBodyStartRow * kScreenWidthTiles + 11
.LINECONT -

;;;=========================================================================;;;

;;; OBJ tile IDs used for drawing the boss.
kTileIdObjOutbreakFirst = $9c
kTileIdObjOutbreakBrain = kTileIdObjOutbreakFirst + 0
kTileIdObjOutbreakClaw  = kTileIdObjOutbreakFirst + 1
kTileIdObjOutbreakEye   = kTileIdObjOutbreakFirst + 2

;;; OBJ palette numbers used for drawing the boss.
kPaletteObjOutbreakBrain = 1
kPaletteObjOutbreakClaw  = 0
kPaletteObjOutbreakEye   = 1

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u1  .byte
    LeverRight_u1 .byte
    ;; The room pixel position of the top of the boss's body.
    BossTopY_u8   .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Temple"

.EXPORT DataC_Temple_Boss_sRoom
.PROC DataC_Temple_Boss_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8,  kRoomScrollX
    d_word MaxScrollX_u16, kRoomScrollX + $0
    d_byte Flags_bRoom, eArea::Temple
    d_byte MinimapStartRow_u8, 3
    d_byte MinimapStartCol_u8, 0
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTemple)
    d_addr Tick_func_ptr, FuncC_Temple_Boss_TickRoom
    d_addr Draw_func_ptr, FuncC_Temple_Boss_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Temple_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Init_func_ptr, FuncC_Temple_Boss_InitRoom
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, FuncC_Temple_Boss_FadeInRoom
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
    d_byte ScrollGoalY_u8, $16
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
    ;; Initialize boss:
    lda #kBossInitTopY
    sta Ram_RoomState + sState::BossTopY_u8
    ;; TODO: remove this next part
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @done
    lda #$88
    sta Ram_ActorPosX_i16_0_arr, x
    lda #kBossZoneBottomY + 4
    sta Ram_ActorPosY_i16_0_arr, x
    lda #0
    sta Ram_ActorPosX_i16_1_arr, x
    sta Ram_ActorPosY_i16_1_arr, x
    jsr FuncA_Room_InitActorProjBreakball
    @done:
    rts
.ENDPROC

;;; Room fade in function for the TempleBoss room.
;;; @prereq Rendering is disabled.
.PROC FuncC_Temple_Boss_FadeInRoom
_DrawBoss:
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldy #kBossBodyHeightTiles - 1
    @rowLoop:
    ldx _BossRowStart_ptr_0_arr, y
    lda _BossRowStart_ptr_1_arr, y
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda _BossRowFirstTileId_u8_arr, y
    ldx #kBossBodyWidthTiles
    clc
    @colLoop:
    sta Hw_PpuData_rw
    adc #1  ; carry is already clear
    dex
    bne @colLoop
    dey
    bpl @rowLoop
_DrawColumns:
    lda #kPpuCtrlFlagsVert
    sta Hw_PpuCtrl_wo
    ldy #8 - 1
    @loop:
    lda _ColumnTileId_u8_arr, y  ; param: BG tile ID
    ldx _ColumnTileCol_u8_arr, y  ; param: nametable tile column index
    jsr _DrawStripe  ; preserves Y
    dey
    bpl @loop
    rts
_DrawStripe:
    pha  ; BG tile ID
    txa  ; nametable tile column index
    add #<Ppu_BossMarginStart
    tax  ; PPU address (lo)
    lda #0
    adc #>Ppu_BossMarginStart
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2  ; PPU address (hi)
    stx Hw_PpuAddr_w2  ; PPU address (lo)
    pla  ; BG tile ID
    ldx #kBossTotalHeightTiles
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
    rts
_BossRowStart_ptr_0_arr:
    .repeat kBossBodyHeightTiles, i
    .byte <(Ppu_BossBodyStart + kScreenWidthTiles * i)
    .endrepeat
_BossRowStart_ptr_1_arr:
    .repeat kBossBodyHeightTiles, i
    .byte >(Ppu_BossBodyStart + kScreenWidthTiles * i)
    .endrepeat
_BossRowFirstTileId_u8_arr:
    .repeat kBossBodyHeightTiles, i
    .byte $c0 + kBossBodyWidthTiles * i
    .endrepeat
_ColumnTileId_u8_arr:
    .byte $9a, $9b, $94, $95, $94, $95, $9a, $9b
_ColumnTileCol_u8_arr:
    .byte   3,   4,   9,  10,  21,  22,  27,  28
.ENDPROC

;;; Room tick function for the TempleBoss room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Temple_Boss_TickRoom
    lda #1  ; param: zero if boss is dead (TODO)
    ldx #eFlag::BossTemple  ; param: boss flag
    jsr FuncA_Room_TickBossPhase
    ;; TODO: tick boss behavior if still alive
    rts
.ENDPROC

;;; Draw function for the TempleBoss room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Temple_Boss_DrawRoom
    lda #<.bank(Ppu_ChrBgOutbreak)
    sta Zp_Chr0cBank_u8
_DrawBossClaws:
    jsr FuncC_Temple_SetShapePosToBossMidTop
    lda #$24  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #0  ; param: horz flip
    jsr FuncC_Temple_DrawBossClawPair
    jsr FuncC_Temple_SetShapePosToBossMidTop
    lda #$2c  ; param: offset
    jsr FuncA_Objects_MoveShapeLeftByA
    lda #bObj::FlipH  ; param: horz flip
    jsr FuncC_Temple_DrawBossClawPair
_DrawBossEyes:
    jsr FuncC_Temple_SetShapePosToBossMidTop
    jsr FuncA_Objects_MoveShapeLeftHalfTile
    lda #kBossBodyHeightPx  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    jsr FuncC_Temple_DrawBossEyeShape
    jsr FuncA_Objects_MoveShapeUpOneTile
    lda #kTileWidthPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeLeftByA
    jsr FuncC_Temple_DrawBossEyeShape
    lda #kTileWidthPx * 4  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    jsr FuncC_Temple_DrawBossEyeShape
_DrawBossBrain:
    jsr FuncC_Temple_SetShapePosToBossMidTop
    jsr FuncA_Objects_MoveShapeUpOneTile
    lda #kPaletteObjOutbreakBrain  ; param: object flags
    jsr FuncA_Objects_Alloc2x1Shape  ; returns C and Y
    bcs @done
    lda #kPaletteObjOutbreakBrain | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kTileIdObjOutbreakBrain
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    @done:
_SetUpIrq:
    ;; Compute the IRQ latch value to set between the bottom of the boss's zone
    ;; and the top of the window (if any), and set that as Param3_byte.
    lda <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    sub #kBossZoneBottomY
    add Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Param3_byte)  ; window latch
    ;; Set up our own sIrq struct to handle boss movement.
    lda #kBossZoneTopY - 1
    sub Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    ldax #Int_TempleBossZoneTopIrq
    stax <(Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr)
    ;; Compute PPU scroll values for the boss zone.
    lda #kBossBodyStartRow * kTileHeightPx + kBossZoneTopY
    sub Ram_RoomState + sState::BossTopY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Param2_byte)  ; boss scroll-Y
    rts
.ENDPROC

;;; Draws two claws on one side of the temple boss.
;;; @prereq The shape position is set to the top left of the claw pair.
;;; @param A Either 0 for eastern claws, or bObj::FlipH for western claws.
.PROC FuncC_Temple_DrawBossClawPair
    pha  ; horz flip
    .assert kPaletteObjOutbreakClaw = 0, error
    tay  ; param: object flags
    lda Ram_RoomState + sState::BossTopY_u8
    and #$01
    cpy #0
    beq @noEor
    eor #$01
    @noEor:
    tax  ; 1 if claws are close together, 0 otherwise
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X and Y
    lda #kTileIdObjOutbreakClaw  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    lda _Offset_u8_arr2, x  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    pla  ; horz flip
    eor #bObj::FlipV
    tay  ; param: object flags
    lda #kTileIdObjOutbreakClaw  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
_Offset_u8_arr2:
    .byte kTileHeightPx * 3
    .byte kTileHeightPx * 3 - 2
.ENDPROC

;;; Draws one eye for the temple boss.
;;; @prereq The shape position is set to the top left of the eye.
;;; @preserve X
.PROC FuncC_Temple_DrawBossEyeShape
    ldy #kPaletteObjOutbreakEye  ; param: object flags
    lda #kTileIdObjOutbreakEye  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
.ENDPROC

;;; Sets Zp_ShapePosX_i16 and Zp_ShapePosY_i16 to the screen-space position of
;;; the top-center of the boss's body.
;;; @preserve X, Y, Zp_Tmp*
.PROC FuncC_Temple_SetShapePosToBossMidTop
    lda #kScreenWidthPx / 2
    sta Zp_ShapePosX_i16 + 0
    lda Ram_RoomState + sState::BossTopY_u8
    sub Zp_RoomScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda #0
    sta Zp_ShapePosX_i16 + 1
    sta Zp_ShapePosY_i16 + 1
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
    dec Ram_RoomState + sState::BossTopY_u8  ; TODO: only when proj hits
    lda #kBlasterCooldownFrames  ; param: number of frames
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

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top of the boss's zone in the
;;; TempleBoss room.  Sets the vertical scroll so as to make the boss's BG
;;; tiles appear to move.
.PROC Int_TempleBossZoneTopIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ.
    sta Hw_Mmc3IrqDisable_wo  ; ack
    sta Hw_Mmc3IrqEnable_wo  ; re-enable
    ;; Set up the latch value for next IRQ.
    lda #kBossZoneBottomY - kBossZoneTopY - 1
    sta Hw_Mmc3IrqLatch_wo
    sta Hw_Mmc3IrqReload_wo
    ;; Update Zp_NextIrq_int_ptr for the next IRQ.
    ldax #Int_TempleBossZoneBottomIrq
    stax Zp_NextIrq_int_ptr
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #8  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the lower
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #$0c  ; nametable number << 2 (so $0c for nametable 3)
    sta Hw_PpuAddr_w2
    lda <(Zp_Active_sIrq + sIrq::Param2_byte)  ; boss scroll-Y
    sta Hw_PpuScroll_w2
    and #$38
    mul #4
    ;; We should now be in the second HBlank.
    stx Hw_PpuScroll_w2  ; new scroll-X value (zero)
    sta Hw_PpuAddr_w2  ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;; HBlank IRQ handler function for the bottom of the boss's zone in the
;;; TempleBoss room.  Sets the scroll so as to make the bottom of the room look
;;; normal.
.PROC Int_TempleBossZoneBottomIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ.
    sta Hw_Mmc3IrqDisable_wo  ; ack
    sta Hw_Mmc3IrqEnable_wo  ; re-enable
    ;; Set up the latch value for next IRQ.
    lda <(Zp_Active_sIrq + sIrq::Param3_byte)  ; window latch
    sta Hw_Mmc3IrqLatch_wo
    sta Hw_Mmc3IrqReload_wo
    ;; Update Zp_NextIrq_int_ptr for the next IRQ.
    ldax #Int_WindowTopIrq
    stax Zp_NextIrq_int_ptr
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #8  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the upper
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #$00  ; nametable number << 2 (so $00 for nametable 0)
    sta Hw_PpuAddr_w2
    lda #kBossZoneBottomY  ; new scroll-Y value
    sta Hw_PpuScroll_w2
    lda #((kBossZoneBottomY & $38) << 2) | (kRoomScrollX >> 3)
    ldx #kRoomScrollX
    ;; We should now be in the second HBlank (and X is zero).
    stx Hw_PpuScroll_w2  ; new scroll-X value
    sta Hw_PpuAddr_w2    ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_TempleBossBlaster_Draw
    jmp FuncA_Objects_DrawCarriageMachine  ; TODO
.ENDPROC

;;;=========================================================================;;;
