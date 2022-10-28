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
.INCLUDE "../machines/shared.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_TempleAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_TempleAreaName_u8_arr
.IMPORT DataA_Room_Temple_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_MovePlatformLeftToward
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjTemple
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_RoomState
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The device index for the upgrade in this room.
kUpgradeDeviceIndex = 0

;;; The eFlag value for the upgrade in this room.
kUpgradeFlag = eFlag::UpgradeOpcodeTil

;;; The machine index for the TempleLobbyLift machine in this room.
kLiftMachineIndex = 0

;;; The platform index for the TempleLobbyLift machine in this room.
kLiftPlatformIndex = 0

;;; The initial and maximum permitted horizontal and vertical goal values for
;;; the TempleLobbyLift machine.
kLiftInitGoalX = 9
kLiftMaxGoalX = 9
kLiftInitGoalY = 0
kLiftMaxGoalY = 9

;;; The minimum, initial, and maximum X-positions for the left side of the lift
;;; platform.
kLiftMinPlatformLeft = $00d0
kLiftInitPlatformLeft = kLiftMinPlatformLeft + kLiftInitGoalX * kBlockWidthPx
kLiftMaxPlatformLeft = kLiftMinPlatformLeft + kLiftMaxGoalX * kBlockWidthPx

;;; The maximum, initial, and minumum Y-positions for the top of the lift
;;; platform.
kLiftMaxPlatformTop = $0120
kLiftInitPlatformTop = kLiftMaxPlatformTop - kLiftInitGoalY * kBlockHeightPx
kLiftMinPlatformTop = kLiftMaxPlatformTop - kLiftMaxGoalY * kBlockHeightPx

;;; Tile IDs for drawing the TempleLobbyLift machine.
kTileIdLiftCorner  = kTileIdMachineCorner
kTileIdLiftSurface = $7a

;;;=========================================================================;;;

;;; Enum for the steps of the CryptTombWinch machine's reset sequence (listed
;;; in reverse order).
.ENUM eResetSeq
    BottomRight = 0  ; last step: move to bottom-right position
    Middle           ; move up/down (if necessary), then move right to X=5
.ENDENUM

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; Which step of its reset sequence the TempleLobbyLift machine is on.
    LiftReset_eResetSeq .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Temple"

.EXPORT DataC_Temple_Lobby_sRoom
.PROC DataC_Temple_Lobby_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $0108
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 6
    d_byte MinimapStartCol_u8, 3
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTemple)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_TempleAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_TempleAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Temple_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, FuncC_Temple_Lobby_InitRoom
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/temple_lobby.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kLiftMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::TempleLobbyLift
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift  ; TODO
    d_word ScrollGoalX_u16, $0108
    d_byte ScrollGoalY_u8, $a0
    d_byte RegNames_u8_arr4, 0, 0, "X", "Y"
    d_byte MainPlatform_u8, kLiftPlatformIndex
    d_addr Init_func_ptr, FuncC_Temple_LobbyLift_Init
    d_addr ReadReg_func_ptr, FuncC_Temple_LobbyLift_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Temple_LobbyLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Temple_LobbyLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawTempleLobbyLift
    d_addr Reset_func_ptr, FuncC_Temple_LobbyLift_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLiftPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16, kLiftInitPlatformLeft
    d_word Top_i16, kLiftInitPlatformTop
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_byte TileRow_u8, 13
    d_byte TileCol_u8, 31
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_byte TileRow_u8, 13
    d_byte TileCol_u8, 44
    d_byte Param_byte, bObj::FlipV
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 28
    d_byte Target_u8, kUpgradeFlag
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 16
    d_byte BlockCol_u8, 26
    d_byte Target_u8, kLiftMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::TempleLobby  ; TODO
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::TempleLobby  ; TODO
    d_byte SpawnBlock_u8, 21
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::TempleEntry
    d_byte SpawnBlock_u8, 20
    D_END
.ENDPROC

.PROC FuncC_Temple_Lobby_InitRoom
    lda Sram_ProgressFlags_arr + (kUpgradeFlag >> 3)
    and #1 << (kUpgradeFlag & $07)
    beq @done
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr + kUpgradeDeviceIndex
    @done:
    rts
.ENDPROC

;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.PROC FuncC_Temple_LobbyLift_ReadReg
    cmp #$f
    beq _ReadY
_ReadX:
    .assert kLiftMinPlatformLeft - kTileWidthPx < $100, error
    lda Ram_PlatformLeft_i16_0_arr + kLiftPlatformIndex
    sub #kLiftMinPlatformLeft - kTileWidthPx
    .assert kLiftMaxPlatformLeft - kLiftMinPlatformLeft < $100, error
    div #kBlockWidthPx
    rts
_ReadY:
    .assert kLiftMaxPlatformTop + kTileHeightPx >= $100, error
    lda #<(kLiftMaxPlatformTop + kTileHeightPx)
    sub Ram_PlatformTop_i16_0_arr + kLiftPlatformIndex
    .assert kLiftMaxPlatformTop - kLiftMinPlatformTop < $100, error
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Temple_LobbyLift_TryMove
    ldy Ram_MachineGoalHorz_u8_arr + kLiftMachineIndex
    .assert eDir::Up = 0, error
    txa
    beq _MoveUp
    cmp #eDir::Down
    beq _MoveDown
_MoveHorz:
    ldx Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    cmp #eDir::Left
    beq _MoveLeft
_MoveRight:
    cpy #kLiftMaxGoalX
    bge _Error
    iny
    bne _ValidateHorz  ; unconditional
_MoveLeft:
    tya  ; current horz position
    beq _Error
    dey
_ValidateHorz:
    txa  ; current vert position
    cmp _MinY_u8_arr, y
    blt _Error
    cmp _MaxY_u8_arr, y
    bgt _Error
    sty Ram_MachineGoalHorz_u8_arr + kLiftMachineIndex
    jmp FuncA_Machine_StartWorking
_MoveUp:
    lda Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    cmp _MaxY_u8_arr, y
    bge _Error
    inc Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    jmp FuncA_Machine_StartWorking
_MoveDown:
    lda Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    cmp _MinY_u8_arr, y
    beq _Error
    dec Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    jmp FuncA_Machine_StartWorking
_Error:
    jmp FuncA_Machine_Error
_MaxY_u8_arr:
    .byte 9, 9, 9, 9, 9, 8, 2, 2, 8, 9
_MinY_u8_arr:
    .byte 0, 1, 8, 8, 1, 0, 0, 0, 0, 0
.ENDPROC

.PROC FuncC_Temple_LobbyLift_Tick
_MoveVert:
    ;; Calculate the desired room-space pixel Y-position for the top edge of
    ;; the platform, storing it in Zp_PlatformGoal_i16.
    lda Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    .assert kLiftMaxGoalY * kBlockHeightPx < $100, error
    mul #kBlockHeightPx
    sta Zp_Tmp1_byte  ; vert goal offset
    .assert kLiftMaxPlatformTop >= $100, error
    lda #<kLiftMaxPlatformTop
    sub Zp_Tmp1_byte  ; vert goal offset
    sta Zp_PlatformGoal_i16 + 0
    lda #>kLiftMaxPlatformTop
    sbc #0
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx Ram_MachineStatus_eMachine_arr + kLiftMachineIndex
    lda #1
    cpx #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the platform vertically, as necessary.
    ldx #kLiftPlatformIndex  ; param: platform index
    jsr Func_MovePlatformTopToward  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_MoveHorz:
    ;; Calculate the desired room-space pixel X-position for the left edge of
    ;; the platform, storing it in Zp_PlatformGoal_i16.
    lda Ram_MachineGoalHorz_u8_arr + kLiftMachineIndex
    .assert kLiftMaxGoalX * kBlockWidthPx < $100, error
    mul #kBlockWidthPx
    sta Zp_Tmp1_byte  ; horz goal offset
    .assert kLiftMaxPlatformLeft >= $100, error
    lda #<kLiftMinPlatformLeft
    add Zp_Tmp1_byte  ; horz goal offset
    sta Zp_PlatformGoal_i16 + 0
    lda #>kLiftMinPlatformLeft
    adc #0
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx Ram_MachineStatus_eMachine_arr + kLiftMachineIndex
    lda #1
    cpx #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the platform horizontally, as necessary.
    ldx #kLiftPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftToward  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_ReachedGoal:
    lda Ram_RoomState + sState::LiftReset_eResetSeq
    jeq FuncA_Machine_ReachedGoal
    .assert * = FuncC_Temple_LobbyLift_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Temple_LobbyLift_Reset
    lda Ram_MachineGoalHorz_u8_arr + kLiftMachineIndex
    cmp #5
    bge _MoveToBottomRight
    cmp #4
    blt _MoveVertBeforeMiddle
    lda Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    cmp #9
    blt _MoveStraightToMiddle
_MoveVertBeforeMiddle:
    lda #8
    sta Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
_MoveStraightToMiddle:
    lda #5
    sta Ram_MachineGoalHorz_u8_arr + kLiftMachineIndex
    lda #eResetSeq::Middle
    sta Ram_RoomState + sState::LiftReset_eResetSeq
    rts
_MoveToBottomRight:
    lda #eResetSeq::BottomRight
    sta Ram_RoomState + sState::LiftReset_eResetSeq
    .assert * = FuncC_Temple_LobbyLift_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Temple_LobbyLift_Init
    lda #kLiftInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kLiftMachineIndex
    lda #kLiftInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_DrawTempleLobbyLift
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_LeftHalf:
    ;; Allocate objects.
    jsr FuncA_Objects_MoveShapeDownOneTile
    jsr FuncA_Objects_MoveShapeRightOneTile
    lda #kMachineLightPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kMachineLightPalette | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdLiftCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdLiftSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_RightHalf:
    ;; Allocate objects.
    lda #kTileWidthPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #kMachineLightPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kMachineLightPalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdLiftSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdLiftCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
