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

.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"
.INCLUDE "city_center.inc"

.IMPORT DataA_Room_Building_sTileset
.IMPORT DataA_Text0_CityBuilding2Screen_Connected_u8_arr
.IMPORT DataA_Text0_CityBuilding2Screen_Locked_u8_arr
.IMPORT DataA_Text0_CityBuilding2Screen_Question_u8_arr
.IMPORT DataA_Text0_CityBuilding2Screen_Unlocked_u8_arr
.IMPORT DataC_City_Building2TerrainData
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_GetRandomByte
.IMPORT Func_Noop
.IMPORT Func_PlaySfxSecretUnlocked
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjCity
.IMPORT Ram_ProgressFlags_arr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The platform index for the zone where the last key combination digit is
;;; drawn.
kLastDigitPlatformIndex = 0

;;; How many frames after entering the room before the first digit stops
;;; spinning.
kInitialSpinFrames = 30
;;; How many frames after a digit stops spinning before the next digit stops
;;; spinning.
kPerDigitSpinFrames = 10

.ASSERT .sizeof(sCityCenterState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_City"

.EXPORT DataC_City_Building2_sRoom
.PROC DataC_City_Building2_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, bRoom::ReduceMusic | bRoom::ShareState | eArea::City
    d_byte MinimapStartRow_u8, 1
    d_byte MinimapStartCol_u8, 19
    d_addr TerrainData_ptr, DataC_City_Building2TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCity)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Building_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncA_Room_CityBuilding2_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_CityBuilding2_TickRoom
    d_addr Draw_func_ptr, FuncC_City_Building2_DrawRoom
    D_END
_Platforms_sPlatform_arr:
:   .assert * - :- = kLastDigitPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00a4
    d_word Top_i16,   $0068
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eRoom::CityCenter
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ScreenRed
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eDialog::CityBuilding2Screen
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_City_Building2_DrawRoom
    flag_bit Ram_ProgressFlags_arr, eFlag::CityCenterDoorUnlocked
    bne @done
    ldx #kLastDigitPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx #kNumSemaphoreKeyDigits - 1
    @loop:
    cpx Zp_RoomState + sCityCenterState::NumDigitsSet_u8
    bge @spinning
    lda Zp_RoomState + sCityCenterState::Key_u8_arr, x
    bpl @draw  ; unconditional
    @spinning:
    txa
    adc Zp_FrameCounter_u8  ; carry is set
    and #$03
    add #1
    @draw:
    add #kTileIdObjComboFirst  ; param: tile ID
    ldy #kPaletteObjComboDigit  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    lda #kBlockWidthPx  ; param: offset
    jsr FuncA_Objects_MoveShapeLeftByA  ; preserves X
    cpx #5
    bne @continue
    lda #kBlockHeightPx  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA  ; preserves X
    lda #kBlockWidthPx * 5  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    @continue:
    dex
    bpl @loop
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_CityBuilding2_EnterRoom
    flag_bit Ram_ProgressFlags_arr, eFlag::CityCenterDoorUnlocked
    bne @done
    lda #kInitialSpinFrames
    sta Zp_RoomState + sCityCenterState::SpinTimer_u8
    ;; Generate a random key combination, with each digit between 1 and 4.
    ldx #kNumSemaphoreKeyDigits - 1
    @loop:
    jsr Func_GetRandomByte  ; preserves X, returns A
    and #$03
    tay
    iny
    sty Zp_RoomState + sCityCenterState::Key_u8_arr, x
    dex
    bpl @loop
    inx  ; now X is zero
    stx Zp_RoomState + sCityCenterState::NumDigitsSet_u8
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_CityBuilding2_TickRoom
    dec Zp_RoomState + sCityCenterState::SpinTimer_u8
    bne @done
    lda Zp_RoomState + sCityCenterState::NumDigitsSet_u8
    cmp #kNumSemaphoreKeyDigits
    bge @done
    inc Zp_RoomState + sCityCenterState::NumDigitsSet_u8
    lda #kPerDigitSpinFrames
    sta Zp_RoomState + sCityCenterState::SpinTimer_u8
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_CityBuilding2Screen_sDialog
.PROC DataA_Dialog_CityBuilding2Screen_sDialog
    dlg_IfSet CityCenterDoorUnlocked, _Unlocked_sDialog
    dlg_Text Screen, DataA_Text0_CityBuilding2Screen_Locked_u8_arr
    dlg_IfSet CityCenterKeygenConnected, _Connected_sDialog
_Unconnected_sDialog:
    dlg_Text Screen, DataA_Text0_CityBuilding2Screen_Question_u8_arr
    dlg_IfYes _Connected_sDialog
    dlg_Done
_Connected_sDialog:
    dlg_Call _ConnectKeygen
    dlg_Text Screen, DataA_Text0_CityBuilding2Screen_Connected_u8_arr
    dlg_Done
_Unlocked_sDialog:
    ;; For safety, connect the key generator (even though you shouldn't
    ;; normally be able to unlock the door without connecting the key generator
    ;; first).
    dlg_Call _ConnectKeygen
    dlg_Text Screen, DataA_Text0_CityBuilding2Screen_Unlocked_u8_arr
    dlg_Done
_ConnectKeygen:
    ldx #eFlag::CityCenterKeygenConnected  ; param: flag
    jsr Func_SetFlag  ; sets C if flag was already set
    bcs @done
    jmp Func_PlaySfxSecretUnlocked
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
