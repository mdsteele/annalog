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
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_CryptAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_CryptAreaName_u8_arr
.IMPORT DataA_Room_Crypt_sTileset
.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_DrawGirderPlatform
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeLeftOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Ppu_ChrUpgrade
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The machine index for the CryptFlowerHoist machine in this room.
kHoistMachineIndex = 0

;;; The platform indices for the CryptFlowerHoist machine and its girders.
kHoistPlatformIndex       = 0
kUpperGirderPlatformIndex = 1
kLowerGirderPlatformIndex = 2

;;; The maximum permitted room pixel Y-position for the top of the lower girder
;;; platform (i.e. when the platform is at its lowest point).
kLowerGirderMaxPlatformTop = $c0

;;; The initial and maximum permitted values for sState::HoistGoalY_u8.
kHoistInitRegY = 4
kHoistMaxRegY  = 9

;;; How many frames the CryptFlowerHoist machine spends per move operation.
kHoistCountdown = 16

;;; Various OBJ tile IDs used for drawing the CryptFlowerHoist machine.
kHoistChainTileId    = $7f
kHoistTileIdLightOff = $70
kHoistTileIdLightOn  = $71
kHoistTileIdCorner   = $73
kHoistTileIdWheel    = $75

;;; The OBJ palette number used for various parts of the CryptFlowerHoist
;;; machine.
kHoistGirderPalette = 0
kHoistChainPalette  = 0

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The goal value for the CryptFlowerHoist machine's Y register.
    HoistGoalY_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_Flower_sRoom
.PROC DataC_Crypt_Flower_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 3
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrUpgrade)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_CryptAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_CryptAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Crypt_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/crypt_flower.room"
    .assert * - :- = 17 * 16, error
_Machines_sMachine_arr:
    .assert kHoistMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CryptFlowerHoist
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Trolley
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_addr Init_func_ptr, _Hoist_Init
    d_addr ReadReg_func_ptr, _Hoist_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, _Hoist_TryMove
    d_addr TryAct_func_ptr, Func_MachineError
    d_addr Tick_func_ptr, _Hoist_Tick
    d_addr Draw_func_ptr, FuncA_Objects_CryptFlowerHoist_Draw
    d_addr Reset_func_ptr, _Hoist_Reset
    d_byte Padding
    .res kMachinePadding
    D_END
_Platforms_sPlatform_arr:
    .assert kHoistPlatformIndex = 0, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_byte WidthPx_u8,  $10
    d_byte HeightPx_u8, $0e
    d_word Left_i16,  $0088
    d_word Top_i16,   $0010
    D_END
    .assert kUpperGirderPlatformIndex = 1, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_byte WidthPx_u8,  $18
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0084
    d_word Top_i16,   $0078
    D_END
    .assert kLowerGirderPlatformIndex = 2, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_byte WidthPx_u8,  $18
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0084
    d_word Top_i16,   $00a0
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_byte WidthPx_u8,  $2f
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16,   $005e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_byte WidthPx_u8,  $1f
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00a1
    d_word Top_i16,   $005e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_byte WidthPx_u8,  $d0
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0030
    d_word Top_i16,   $00ce
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Spider
    d_byte TileRow_u8, 15
    d_byte TileCol_u8, 24
    d_byte Param_byte, 0
    D_END
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 4
    d_byte Target_u8, kHoistMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Flower
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 4
    d_byte Target_u8, eFlag::FlowerCrypt
    D_END
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::CryptFlower  ; TODO
    d_byte SpawnBlock_u8, 3
    D_END
_Hoist_Init:
_Hoist_Reset:
    lda #kHoistInitRegY
    sta Ram_RoomState + sState::HoistGoalY_u8
    rts
_Hoist_ReadReg:
    lda #kLowerGirderMaxPlatformTop + kTileHeightPx / 2
    sub Ram_PlatformTop_i16_0_arr + kLowerGirderPlatformIndex
    div #kTileHeightPx
    rts
_Hoist_TryMove:
    ldy Ram_RoomState + sState::HoistGoalY_u8
    txa
    .assert eDir::Up = 0, error
    bne @moveDown
    @moveUp:
    cpy #kHoistMaxRegY
    bge @error
    iny
    bne @success  ; unconditional
    @moveDown:
    tya
    beq @error
    dey
    @success:
    sty Ram_RoomState + sState::HoistGoalY_u8
    lda #kHoistCountdown
    clc  ; clear C to indicate success
    rts
    @error:
    sec  ; set C to indicate failure
    rts
_Hoist_Tick:
    ;; Calculate the desired Y-position for the top of the lower girder
    ;; platform, in room-space pixels.
    lda Ram_RoomState + sState::HoistGoalY_u8
    mul #kTileHeightPx
    sta Zp_Tmp1_byte  ; goal height above the lowest position, in pixels
    lda #kLowerGirderMaxPlatformTop
    sub Zp_Tmp1_byte
    ;; If we're at the desired height, we're done.
    cmp Ram_PlatformTop_i16_0_arr + kLowerGirderPlatformIndex
    jeq Func_MachineFinishResetting
    ;; Otherwise, move up or down as needed.
    blt @moveDown
    @moveUp:
    lda #1                          ; param: move delta
    ldx #kUpperGirderPlatformIndex  ; param: platform index
    jsr Func_MovePlatformVert
    lda #1                          ; param: move delta
    ldx #kLowerGirderPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
    @moveDown:
    lda #$ff                        ; param: move delta
    ldx #kUpperGirderPlatformIndex  ; param: platform index
    jsr Func_MovePlatformVert
    lda #$ff                        ; param: move delta
    ldx #kLowerGirderPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the CryptFlowerHoist machine.
.PROC FuncA_Objects_CryptFlowerHoist_Draw
    ldx #kHoistPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    jsr FuncA_Objects_MoveShapeDownOneTile
    jsr FuncA_Objects_MoveShapeRightOneTile
    ;; Allocate objects.
    lda #kHoistChainPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kMachineLightPalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kHoistChainPalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kHoistChainPalette | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kHoistTileIdCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kHoistTileIdWheel
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda Ram_MachineStatus_eMachine_arr + kHoistMachineIndex
    cmp #eMachine::Error
    bne @lightOff
    lda Zp_FrameCounter_u8
    and #$08
    beq @lightOff
    lda #kHoistTileIdLightOn
    bne @setLight  ; unconditional
    @lightOff:
    lda #kHoistTileIdLightOff
    @setLight:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    @done:
_Girders:
    ldx #kUpperGirderPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawGirderPlatform
    ldx #kLowerGirderPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawGirderPlatform
_Chain:
    jsr FuncA_Objects_MoveShapeLeftOneTile
    ldx #0
    @loop:
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X
    cpx #4
    beq @continue
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @continue
    lda #kHoistChainTileId
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kHoistChainPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    inx
    lda #$20
    cmp Zp_ShapePosY_i16 + 0
    blt @loop
    rts
.ENDPROC

;;;=========================================================================;;;
