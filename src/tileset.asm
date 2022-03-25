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

.INCLUDE "macros.inc"
.INCLUDE "tileset.inc"

.IMPORT DataA_Terrain_PrisonLowerLeft_u8_arr
.IMPORT DataA_Terrain_PrisonLowerRight_u8_arr
.IMPORT DataA_Terrain_PrisonUpperLeft_u8_arr
.IMPORT DataA_Terrain_PrisonUpperRight_u8_arr
.IMPORT Ppu_ChrCave

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.EXPORT DataA_Room_Prison_sTileset
.PROC DataA_Room_Prison_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_PrisonUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_PrisonLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_PrisonUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_PrisonLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrCave)
    D_END
.ENDPROC

;;;=========================================================================;;;
