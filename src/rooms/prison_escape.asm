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
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/shared.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Prison_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawGirderPlatform
.IMPORT FuncA_Objects_DrawTrolleyMachine
.IMPORT FuncA_Objects_DrawTrolleyRopeWithLength
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjPrison
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The dialog index for the paper in this room.
kPaperDialogIndex = 0

;;; The machine index for the PrisonEscapeTrolley machine in this room.
kTrolleyMachineIndex = 0

;;; The platform indices for the PrisonEscapeTrolley machine and its girder.
kTrolleyPlatformIndex = 0
kGirderPlatformIndex  = 1

;;; The maximum permitted value for sState::TrolleyGoalX_u8.
kTrolleyMaxGoalX = 7

;;; The minimum room pixel position for the left edge of the trolley.
kTrolleyMinPlatformLeft = $100

;;; Various OBJ tile IDs used for drawing the PrisonEscapeTrolley machine.
kTrolleyTileIdRopeVert = $7c
kTrolleyTileIdPulley   = $7d
kTrolleyTileIdRopeDiag = $7e

;;; The OBJ palette number used for various parts of the PrisonEscapeTrolley
;;; machine.
kTrolleyRopePalette = 0

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

.EXPORT DataC_Prison_Escape_sRoom
.PROC DataC_Prison_Escape_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0100
    d_byte Flags_bRoom, bRoom::Tall | eArea::Prison
    d_byte MinimapStartRow_u8, 2
    d_byte MinimapStartCol_u8, 3
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPrison)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
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
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/prison_escape.room"
    .assert * - :- = 33 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kTrolleyMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::PrisonEscapeTrolley
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH
    d_byte Status_eDiagram, eDiagram::Trolley
    d_word ScrollGoalX_u16, $c0
    d_byte ScrollGoalY_u8, $b0
    d_byte RegNames_u8_arr4, 0, 0, "X", 0
    d_byte MainPlatform_u8, kTrolleyPlatformIndex
    d_addr Init_func_ptr, _Trolley_Init
    d_addr ReadReg_func_ptr, _Trolley_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, _Trolley_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, _Trolley_Tick
    d_addr Draw_func_ptr, FuncA_Objects_PrisonEscapeTrolley_Draw
    d_addr Reset_func_ptr, _Trolley_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kTrolleyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $0e
    d_word Left_i16, kTrolleyMinPlatformLeft
    d_word Top_i16,   $00c0
    D_END
    .assert * - :- = kGirderPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16, kTrolleyMinPlatformLeft - $08
    d_word Top_i16,   $0120
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0040
    d_word Top_i16,   $014e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0130
    d_word Top_i16,   $015e
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_byte TileRow_u8, 11
    d_byte TileCol_u8, 10
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 11
    d_byte Target_u8, kPaperDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 16
    d_byte Target_u8, kTrolleyMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | bPassage::SameScreen | 0
    d_byte Destination_eRoom, eRoom::PrisonCell
    d_byte SpawnBlock_u8, 7
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | bPassage::SameScreen | 1
    d_byte Destination_eRoom, eRoom::PrisonCell
    d_byte SpawnBlock_u8, 18
    D_END
_Trolley_Init:
_Trolley_Reset:
    lda #0
    sta Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
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
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    cmp #kTrolleyMaxGoalX
    bge @error
    inc Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    bne @success  ; unconditional
    @moveLeft:
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    beq @error
    dec Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    @success:
    jmp FuncA_Machine_StartWorking
    @error:
    jmp FuncA_Machine_Error
_Trolley_Tick:
    ;; Calculate the desired X-position for the left edge of the trolley, in
    ;; room-space pixels, storing it in Zp_PointX_i16.
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    .assert kTrolleyMaxGoalX * kBlockWidthPx < $100, error
    mul #kBlockWidthPx  ; fits in one byte
    add #<kTrolleyMinPlatformLeft
    sta Zp_PointX_i16 + 0
    lda #0
    adc #>kTrolleyMinPlatformLeft
    sta Zp_PointX_i16 + 1
    ;; Determine the horizontal speed of the trolley (faster if resetting).
    lda #1
    ldy Ram_MachineStatus_eMachine_arr + kTrolleyMachineIndex
    cpy #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the trolley horizontally, as necessary.
    ldx #kTrolleyPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftTowardPointX  ; returns Z and A
    beq @done
    ;; If the trolley moved, move the girder platform too.
    ldx #kGirderPlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @done:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the PrisonEscape room.
.PROC DataA_Dialog_PrisonEscape_sDialog_ptr_arr
:   .assert * - :- = kPaperDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_PrisonEscape_Paper_sDialog
.ENDPROC

.PROC DataA_Dialog_PrisonEscape_Paper_sDialog
    .word ePortrait::Paper
    .byte "Day 12: So where do I$"
    .byte "even start? We were a$"
    .byte "great civilization$"
    .byte "once, before the orcs.#"
    .word ePortrait::Paper
    .byte "But we were already$"
    .byte "crumbling long$"
    .byte "before they invaded.#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the PrisonEscapeTrolley machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.PROC FuncA_Objects_PrisonEscapeTrolley_Draw
    jsr FuncA_Objects_DrawTrolleyMachine
    ldx #7  ; param: num rope tiles
    jsr FuncA_Objects_DrawTrolleyRopeWithLength
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
    ldy #bObj::FlipH | kTrolleyRopePalette  ; param: object flags
    lda #kTrolleyTileIdRopeDiag  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape
    ;; Tile 2:
    lda #kTileWidthPx * 3  ; param: offset
    jsr FuncA_Objects_MoveShapeLeftByA
    ldy #kTrolleyRopePalette  ; param: object flags
    lda #kTrolleyTileIdRopeDiag  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape
    ;; Tile 3:
    jsr FuncA_Objects_MoveShapeRightOneTile
    jsr FuncA_Objects_MoveShapeUpOneTile
    ldy #kTrolleyRopePalette  ; param: object flags
    lda #kTrolleyTileIdRopeDiag  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape
    ;; Tile 4:
    jsr FuncA_Objects_MoveShapeRightOneTile
    ldy #bObj::FlipH | kTrolleyRopePalette  ; param: object flags
    lda #kTrolleyTileIdRopeDiag  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape
_Pulley:
    ;; Pulley:
    jsr FuncA_Objects_MoveShapeLeftHalfTile
    jsr FuncA_Objects_MoveShapeUpOneTile
    ldy #kTrolleyRopePalette  ; param: object flags
    lda #kTrolleyTileIdPulley  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;;=========================================================================;;;
