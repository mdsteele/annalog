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
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_PrisonAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_PrisonAreaName_u8_arr
.IMPORT DataA_Room_Prison_sTileset
.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_DrawGirderPlatform
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftToward
.IMPORT Func_Noop
.IMPORT Ppu_ChrUpgrade
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The machine index for the PrisonEscapeTrolley machine in this room.
kTrolleyMachineIndex = 0

;;; The platform indices for the PrisonEscapeTrolley machine and its girder.
kTrolleyPlatformIndex = 0
kGirderPlatformIndex  = 1

;;; The maximum permitted value for sState::TrolleyGoalX_u8.
kTrolleyMaxGoalX = 7

;;; How many frames the PrisonEscapeTrolley machine spends per move operation.
kTrolleyMoveCooldown = kBlockWidthPx

;;; The minimum room pixel position for the left edge of the trolley.
kTrolleyMinPlatformLeft = $100

;;; Various OBJ tile IDs used for drawing the PrisonEscapeTrolley machine.
kTrolleyTileIdCorner   = $73
kTrolleyTileIdWheel    = $75
kTrolleyTileIdRopeVert = $76
kTrolleyTileIdPulley   = $77
kTrolleyTileIdRopeDiag = $78
kTrolleyTileIdGirder   = $79

;;; The OBJ palette number used for various parts of the PrisonEscapeTrolley
;;; machine.
kTrolleyGirderPalette = 0
kTrolleyRopePalette   = 0

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The goal value for the PrisonEscapeTrolley machine's X register.
    TrolleyGoalX_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

.EXPORT DataC_Prison_Escape_sRoom
.PROC DataC_Prison_Escape_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0100
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 2
    d_byte MinimapStartCol_u8, 3
    d_byte MinimapWidth_u8, 2
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
    d_addr AreaName_u8_arr_ptr, DataA_Pause_PrisonAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_PrisonAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Prison_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    .linecont +
    d_addr Dialogs_sDialog_ptr_arr_ptr, \
           DataA_Dialog_PrisonEscape_sDialog_ptr_arr
    .linecont -
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/prison_escape.room"
    .assert * - :- = 33 * 24, error
_Machines_sMachine_arr:
    .assert kTrolleyMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::PrisonEscapeTrolley
    d_byte Conduit_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH
    d_byte Status_eDiagram, eDiagram::Trolley
    d_word ScrollGoalX_u16, $c0
    d_byte ScrollGoalY_u8, $b0
    d_byte RegNames_u8_arr4, 0, 0, "X", 0
    d_addr Init_func_ptr, _Trolley_Init
    d_addr ReadReg_func_ptr, _Trolley_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, _Trolley_TryMove
    d_addr TryAct_func_ptr, Func_MachineError
    d_addr Tick_func_ptr, _Trolley_Tick
    d_addr Draw_func_ptr, FuncA_Objects_PrisonEscapeTrolley_Draw
    d_addr Reset_func_ptr, _Trolley_Reset
    D_END
_Platforms_sPlatform_arr:
    .assert kTrolleyPlatformIndex = 0, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_byte WidthPx_u8,  $10
    d_byte HeightPx_u8, $0e
    d_word Left_i16, kTrolleyMinPlatformLeft
    d_word Top_i16,   $00c0
    D_END
    .assert kGirderPlatformIndex = 1, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_byte WidthPx_u8,  $20
    d_byte HeightPx_u8, $08
    d_word Left_i16, kTrolleyMinPlatformLeft - $08
    d_word Top_i16,   $0120
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_byte WidthPx_u8,  $40
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0040
    d_word Top_i16,   $014e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_byte WidthPx_u8,  $60
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0130
    d_word Top_i16,   $015e
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Crawler
    d_byte TileRow_u8, 11
    d_byte TileCol_u8, 10
    d_byte Param_byte, 0
    D_END
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 11
    d_byte Target_u8, 0
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 16
    d_byte Target_u8, kTrolleyMachineIndex
    D_END
    .byte eDevice::None
_Passages_sPassage_arr:
    ;; TODO: Currently, a room cannot have two passages lead to the same room.
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::PrisonCell
    d_byte SpawnBlock_u8, 7
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::PrisonCell
    d_byte SpawnBlock_u8, 18
    D_END
_Trolley_Init:
_Trolley_Reset:
    lda #0
    sta Ram_RoomState + sState::TrolleyGoalX_u8
    rts
_Trolley_ReadReg:
    lda Ram_PlatformLeft_i16_0_arr + kTrolleyPlatformIndex
    sub #<(kTrolleyMinPlatformLeft - kTileWidthPx)
    sta Zp_Tmp1_byte
    lda Ram_PlatformLeft_i16_1_arr + kTrolleyPlatformIndex
    sbc #>(kTrolleyMinPlatformLeft - kTileWidthPx)
    .repeat 4
    lsr a
    ror Zp_Tmp1_byte
    .endrepeat
    lda Zp_Tmp1_byte
    rts
_Trolley_TryMove:
    cpx #eDir::Left
    beq @moveLeft
    @moveRight:
    lda Ram_RoomState + sState::TrolleyGoalX_u8
    cmp #kTrolleyMaxGoalX
    bge @error
    inc Ram_RoomState + sState::TrolleyGoalX_u8
    bne @success  ; unconditional
    @moveLeft:
    lda Ram_RoomState + sState::TrolleyGoalX_u8
    beq @error
    dec Ram_RoomState + sState::TrolleyGoalX_u8
    @success:
    lda #kTrolleyMoveCooldown
    clc  ; success
    rts
    @error:
    sec  ; failure
    rts
_Trolley_Tick:
    ;; Calculate the desired X-position for the left edge of the trolley, in
    ;; room-space pixels, storing it in Zp_PlatformGoal_i16.
    lda Ram_RoomState + sState::TrolleyGoalX_u8
    .assert kTrolleyMaxGoalX * kBlockWidthPx < $100, error
    mul #kBlockWidthPx  ; fits in one byte
    add #<kTrolleyMinPlatformLeft
    sta Zp_PlatformGoal_i16 + 0
    lda #0
    adc #>kTrolleyMinPlatformLeft
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine the horizontal speed of the trolley (faster if resetting).
    lda #1
    ldy Ram_MachineStatus_eMachine_arr + kTrolleyMachineIndex
    cpy #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the trolley horizontally, as necessary.
    ldx #kTrolleyPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftToward  ; returns Z and A
    beq @done
    ;; If the winch moved, move the girder platform too.
    ldx #kGirderPlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @done:
    jmp Func_MachineFinishResetting
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the PrisonEscape room.
.PROC DataA_Dialog_PrisonEscape_sDialog_ptr_arr
    .addr _Dialog0_sDialog
_Dialog0_sDialog:
    .word ePortrait::Sign
    .byte "Of course, it wasn't$"
    .byte "the orcs that caused$"
    .byte "our downfall.#"
    .word ePortrait::Sign
    .byte "Their arrival was$"
    .byte "simply the inevitable$"
    .byte "result of our own$"
    .byte "failures.#"
    .byte 0
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the PrisonEscapeTrolley machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.PROC FuncA_Objects_PrisonEscapeTrolley_Draw
_Trolley:
    ;; Allocate objects.
    ldx #kTrolleyPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    jsr FuncA_Objects_MoveShapeDownOneTile
    jsr FuncA_Objects_MoveShapeRightOneTile
    lda #kMachineLightPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kMachineLightPalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kTrolleyRopePalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kTrolleyRopePalette | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTrolleyTileIdCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTrolleyTileIdWheel
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    @done:
_Girder:
    ldx #kGirderPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawGirderPlatform
_RopeTriangle:
    ;; The rope triangle tiles are shaped like this:
    ;;
    ;;     3/\4
    ;;    2/  \1
    ;;
    ;; Tile 1:
    jsr FuncA_Objects_MoveShapeUpOneTile
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    bcs @skip1
    lda #kTrolleyTileIdRopeDiag
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #bObj::FlipH | kTrolleyRopePalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @skip1:
    ;; Tile 2:
    lda Zp_ShapePosX_i16 + 0
    sub #kTileWidthPx * 3
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    sbc #0
    sta Zp_ShapePosX_i16 + 1
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    bcs @skip2
    lda #kTrolleyTileIdRopeDiag
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kTrolleyRopePalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @skip2:
    ;; Tile 3:
    jsr FuncA_Objects_MoveShapeRightOneTile
    jsr FuncA_Objects_MoveShapeUpOneTile
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    bcs @skip3
    lda #kTrolleyTileIdRopeDiag
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kTrolleyRopePalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @skip3:
    ;; Tile 4:
    jsr FuncA_Objects_MoveShapeRightOneTile
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    bcs @skip4
    lda #kTrolleyTileIdRopeDiag
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #bObj::FlipH | kTrolleyRopePalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @skip4:
_RopeVertical:
    ;; Pulley:
    lda Zp_ShapePosX_i16 + 0
    sub #kTileWidthPx / 2
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    sbc #0
    sta Zp_ShapePosX_i16 + 1
    jsr FuncA_Objects_MoveShapeUpOneTile
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    bcs @skipPulley
    lda #kTrolleyTileIdPulley
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kTrolleyRopePalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @skipPulley:
    ;; Other rope segments:
    ldx #7
    @loop:
    jsr FuncA_Objects_MoveShapeUpOneTile
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @continue
    lda #kTrolleyTileIdRopeVert
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kTrolleyRopePalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    dex
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;
