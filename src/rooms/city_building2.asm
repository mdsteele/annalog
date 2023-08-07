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

.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Building_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT Data_Empty_sDialog
.IMPORT Data_Empty_sPlatform_arr
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjCity
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_DialogAnsweredYes_bool

;;;=========================================================================;;;

.SEGMENT "PRGC_City"

.EXPORT DataC_City_Building2_sRoom
.PROC DataC_City_Building2_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, eArea::City
    d_byte MinimapStartRow_u8, 1
    d_byte MinimapStartCol_u8, 19
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCity)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_City_Building2_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Building_sTileset
    d_addr Platforms_sPlatform_arr_ptr, Data_Empty_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncC_City_Building2_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/city_building2.room"
    .assert * - :- = 16 * 15, error
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eRoom::CityCenter
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Screen
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eDialog::CityBuilding2Screen
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC FuncC_City_Building2_EnterRoom
    ;; TODO: Play a sound for random key generation.
    ;; TODO: Generate a random key combination.
    rts
.ENDPROC

.PROC FuncC_City_Building2_DrawRoom
    ;; TODO: Draw the key combination on the wall.
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_CityBuilding2Screen_sDialog
.PROC DataA_Dialog_CityBuilding2Screen_sDialog
    dlg_Func _InitialFunc
_InitialFunc:
    ;; If the eastern door in CityCenter has already been unlocked, display a
    ;; message to that effect.
    flag_bit Sram_ProgressFlags_arr, eFlag::CityCenterDoorUnlocked
    beq @doorStillLocked
    ;; For safety, connect the key generator (even though you shouldn't
    ;; normally be able to unlock the door without connecting the key generator
    ;; first).
    ldx #eFlag::CityCenterKeygenConnected  ; param: flag
    jsr Func_SetFlag
    ldya #_Unlocked_sDialog
    rts
    @doorStillLocked:
    ;; Otherwise, if the key generator has already been connected to the
    ;; western semaphore, display a message to that effect.
    flag_bit Sram_ProgressFlags_arr, eFlag::CityCenterKeygenConnected
    beq @notYetConnected
    ldya #_AlreadyConnected_sDialog
    rts
    ;; Otherwise, prompt the player to connect the key generator.
    @notYetConnected:
    ldya #_Unconnected_sDialog
    rts
_Unconnected_sDialog:
    dlg_Text Screen, DataA_Text0_CityBuilding2Screen_Locked_u8_arr
    dlg_Text Screen, DataA_Text0_CityBuilding2Screen_Question_u8_arr
    dlg_Func _QuestionFunc
_QuestionFunc:
    bit Zp_DialogAnsweredYes_bool
    bmi @yes
    @no:
    ldya #Data_Empty_sDialog
    rts
    @yes:
    ldx #eFlag::CityCenterKeygenConnected  ; param: flag
    jsr Func_SetFlag
    ldya #_NowConnected_sDialog
    rts
_AlreadyConnected_sDialog:
    dlg_Text Screen, DataA_Text0_CityBuilding2Screen_Locked_u8_arr
_NowConnected_sDialog:
    dlg_Text Screen, DataA_Text0_CityBuilding2Screen_Connected_u8_arr
    dlg_Done
_Unlocked_sDialog:
    dlg_Text Screen, DataA_Text0_CityBuilding2Screen_Unlocked_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_CityBuilding2Screen_Unlocked_u8_arr
    .byte "   SECURITY STATUS$"
    .byte "Eastern door: UNLOCKED$"
    .byte "Continuous key$"
    .byte "randomization:     N/A#"
.ENDPROC

.PROC DataA_Text0_CityBuilding2Screen_Locked_u8_arr
    .byte "   SECURITY STATUS$"
    .byte "Eastern door:   LOCKED$"
    .byte "Continuous key$"
    .byte "randomization: ENABLED#"
.ENDPROC

.PROC DataA_Text0_CityBuilding2Screen_Question_u8_arr
    .byte "Connect key generator$"
    .byte "to western semaphore?%"
.ENDPROC

.PROC DataA_Text0_CityBuilding2Screen_Connected_u8_arr
    .byte "Western semaphore is$"
    .byte "now connected to key$"
    .byte "generator output.#"
.ENDPROC

;;;=========================================================================;;;
