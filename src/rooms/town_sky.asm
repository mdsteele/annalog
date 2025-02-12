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
.INCLUDE "../actors/adult.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Outdoors_sTileset
.IMPORT DataA_Text2_TownSkyFinaleJeromeRecorded_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleReactivate4_Part2_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleReactivate6_Part1_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleReactivate6_Part2_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleReactivate6_Part3_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleReactivate6_Part4_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleReactivate6_Part5_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleReactivate6_Part6_u8_arr
.IMPORT Data_Empty_sDevice_arr
.IMPORT Data_Empty_sPlatform_arr
.IMPORT Func_Noop
.IMPORT Main_Finale_StartNextStep
.IMPORT Ppu_ChrObjFinale

;;;=========================================================================;;;

.SEGMENT "PRGC_Town"

.EXPORT DataC_Town_Sky_sRoom
.PROC DataC_Town_Sky_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte Flags_bRoom, bRoom::Unsafe | eArea::Town
    d_byte MinimapStartRow_u8, 0
    d_byte MinimapStartCol_u8, 14
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjFinale)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Outdoors_sTileset
    d_addr Platforms_sPlatform_arr_ptr, Data_Empty_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, Data_Empty_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/town_sky.room"
    .assert * - :- = 16 * 15, error
_Actors_sActor_arr:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0070
    d_word PosY_i16, $0080
    d_byte Param_byte, eNpcAdult::GhostJerome
    D_END
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_TownSkyFinaleReactivate2_sCutscene
.PROC DataA_Cutscene_TownSkyFinaleReactivate2_sCutscene
    act_WaitFrames 60
    ;; TODO: animate the core tower rising into the sky, with Anna riding it
    act_JumpToMain Main_Finale_StartNextStep
.ENDPROC

.EXPORT DataA_Cutscene_TownSkyFinaleReactivate4_sCutscene
.PROC DataA_Cutscene_TownSkyFinaleReactivate4_sCutscene
    act_WaitFrames 60
    ;; TODO: animate Jerome appearing
    act_RunDialog eDialog::TownSkyFinaleReactivate4
    act_WaitFrames 60
    act_JumpToMain Main_Finale_StartNextStep
.ENDPROC

.EXPORT DataA_Cutscene_TownSkyFinaleReactivate6_sCutscene
.PROC DataA_Cutscene_TownSkyFinaleReactivate6_sCutscene
    act_WaitFrames 30
    act_RunDialog eDialog::TownSkyFinaleReactivate6
    act_WaitFrames 60
_Finish_sCutscene:
    ;; TODO: jump to credits
    act_WaitFrames 60
    act_ForkStart 0, _Finish_sCutscene
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_TownSkyFinaleReactivate4_sDialog
.PROC DataA_Dialog_TownSkyFinaleReactivate4_sDialog
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJeromeRecorded_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleReactivate4_Part2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownSkyFinaleReactivate6_sDialog
.PROC DataA_Dialog_TownSkyFinaleReactivate6_sDialog
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleReactivate6_Part1_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleReactivate6_Part2_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleReactivate6_Part3_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleReactivate6_Part4_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleReactivate6_Part5_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleReactivate6_Part6_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
