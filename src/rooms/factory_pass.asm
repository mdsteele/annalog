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
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Factory_sTileset
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeHorz
.IMPORT FuncA_Objects_MoveShapeVert
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeBig
.IMPORT Func_SetFlag
.IMPORT Func_ShakeRoom
.IMPORT Ppu_ChrBgAnimB0
.IMPORT Ppu_ChrObjSewer
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

kTileIdObjSolidBlack = $07

;;; The platform index for the rocks that can be lowered.
kRocksPlatformIndex = 1

;;; The device index for the lever that lowers the rocks.
kLeverDeviceIndex = 0

;;; The room pixel Y-position for the top of the rocks platform in its initial
;;; position, as well as when it's halfway and fully lowered.
kRocksInitTop = $a0
kRocksMidTop  = $a8
kRocksMaxTop  = $b0

;;; The tile row/col in the upper nametable for the top-left corner of the
;;; rocks's BG tiles.
kRocksStartRow = 20
kRocksStartCol = 22

;;; The PPU addresses for the start (left) of the first couple rows of rocks.
.LINECONT +
Ppu_FactoryPassRocksRow0 = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kRocksStartRow + 0) + kRocksStartCol
Ppu_FactoryPassRocksRow1 = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kRocksStartRow + 1) + kRocksStartCol
.LINECONT -

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the lever next to the rocks.
    Lever_u8      .byte
    ;; A timer that counts down each frame when nonzero.
    DelayTimer_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Factory"

.EXPORT DataC_Factory_Pass_sRoom
.PROC DataC_Factory_Pass_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, eArea::Factory
    d_byte MinimapStartRow_u8, 7
    d_byte MinimapStartCol_u8, 15
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjSewer)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Factory_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Factory_Pass_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Factory_Pass_TickRoom
    d_addr Draw_func_ptr, FuncC_Factory_Pass_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/factory_pass.room"
    .assert * - :- = 18 * 15, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0060
    d_word Top_i16,   $00ce
    D_END
    .assert * - :- = kRocksPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $50
    d_word Left_i16,  $00b0
    d_word Top_i16, kRocksInitTop
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   .assert * - :- = kLeverDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverCeiling
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 14
    d_byte Target_byte, sState::Lever_u8
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadToad
    d_word PosX_i16, $0048
    d_word PosY_i16, $00a0
    d_byte Param_byte, bObj::FlipH
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadToad
    d_word PosX_i16, $0098
    d_word PosY_i16, $00b0
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::FactoryElevator
    d_byte SpawnBlock_u8, 9
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::FactoryEast
    d_byte SpawnBlock_u8, 10
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; The PPU transfer entry for changing the rocks terrain when the rocks are
;;; halfway lowered.
.PROC DataC_Factory_PassTransfer1_arr
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_FactoryPassRocksRow0  ; transfer destination
    .byte 8
    .byte $00, $00, $00, $00, $00, $00, $00, $00
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_FactoryPassRocksRow1  ; transfer destination
    .byte 8
    .byte $69, $68, $69, $68, $69, $68, $69, $68
.ENDPROC

;;; The PPU transfer entry for changing the rocks terrain when the rocks are
;;; fully lowered.
.PROC DataC_Factory_PassTransfer2_arr
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_FactoryPassRocksRow0  ; transfer destination
    .byte 8
    .byte $00, $00, $00, $00, $00, $00, $00, $00
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_FactoryPassRocksRow1  ; transfer destination
    .byte 8
    .byte $00, $00, $00, $00, $00, $00, $00, $00
.ENDPROC

.PROC FuncC_Factory_Pass_EnterRoom
    flag_bit Sram_ProgressFlags_arr, eFlag::FactoryPassLoweredRocks
    beq @done
    ldx #kRocksPlatformIndex  ; param: platform index
    .assert kRocksPlatformIndex = 1, error
    stx Zp_RoomState + sState::Lever_u8
    lda #kRocksMaxTop - kRocksInitTop  ; param: move delta
    jmp Func_MovePlatformVert
    @done:
    rts
.ENDPROC

.PROC FuncC_Factory_Pass_TickRoom
_SetFlagWhenLeverFlipped:
    lda Zp_RoomState + sState::Lever_u8
    beq @done
    ldx #eFlag::FactoryPassLoweredRocks
    jsr Func_SetFlag  ; sets C if flag was already set
    bcs @done
    lda #20  ; param: num frames
    jsr Func_ShakeRoom
    jsr Func_PlaySfxExplodeBig
    lda #6
    sta Zp_RoomState + sState::DelayTimer_u8
    @done:
_LowerRocksIfFlagSetAndTimerZero:
    flag_bit Sram_ProgressFlags_arr, eFlag::FactoryPassLoweredRocks
    beq @done
    lda Zp_RoomState + sState::DelayTimer_u8
    bne @decrementTimer
    ldya #$00b0
    stya Zp_PointY_i16
    ldx #kRocksPlatformIndex  ; param: platform index
    lda #2  ; param: max move by
    jmp Func_MovePlatformTopTowardPointY
    @decrementTimer:
    dec Zp_RoomState + sState::DelayTimer_u8
    @done:
    rts
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Factory_Pass_DrawRoom
_DrawRockGaps:
    ldx #kRocksPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx #0
    @loop:
    lda _ShiftHorz_i8_arr6, x  ; param: signed offset
    jsr FuncA_Objects_MoveShapeHorz  ; preserves X
    lda _ShiftVert_i8_arr6, x  ; param: signed offset
    jsr FuncA_Objects_MoveShapeVert  ; preserves X
    ldy #0  ; param: object flags
    lda #$06  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    inx
    cpx #6
    blt @loop
_AnimateRocksBgTiles:
    lda Ram_PlatformTop_i16_0_arr + kRocksPlatformIndex
    sub #kRocksInitTop
    div #2
    and #$07
    .assert .bank(Ppu_ChrBgAnimB0) .mod 8 = 0, error
    ora #<.bank(Ppu_ChrBgAnimB0)
    sta Zp_Chr04Bank_u8
_MaybeDoTransfer:
    lda Ram_PlatformTop_i16_0_arr + kRocksPlatformIndex
    cmp #kRocksMaxTop
    beq _DoTransfer2
    cmp #kRocksMidTop
    beq _DoTransfer1
    rts
_DoTransfer1:
    ldax #DataC_Factory_PassTransfer1_arr  ; param: data pointer
    ldy #.sizeof(DataC_Factory_PassTransfer1_arr)  ; param: data length
    bne _DoTransfer  ; unconditional
_DoTransfer2:
    ldax #DataC_Factory_PassTransfer2_arr  ; param: data pointer
    ldy #.sizeof(DataC_Factory_PassTransfer2_arr)  ; param: data length
_DoTransfer:
    jmp Func_BufferPpuTransfer
_ShiftHorz_i8_arr6:
    .byte $38, <-$28, <-$10, $28, $08, $08
_ShiftVert_i8_arr6:
    .byte $08, $08, $18, <-$08, $00, $18
.ENDPROC

;;;=========================================================================;;;
