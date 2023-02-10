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

.IMPORT DataA_Terrain_CoreLowerLeft_u8_arr
.IMPORT DataA_Terrain_CoreLowerRight_u8_arr
.IMPORT DataA_Terrain_CoreUpperLeft_u8_arr
.IMPORT DataA_Terrain_CoreUpperRight_u8_arr
.IMPORT DataA_Terrain_CryptLowerLeft_u8_arr
.IMPORT DataA_Terrain_CryptLowerRight_u8_arr
.IMPORT DataA_Terrain_CryptUpperLeft_u8_arr
.IMPORT DataA_Terrain_CryptUpperRight_u8_arr
.IMPORT DataA_Terrain_FactoryLowerLeft_u8_arr
.IMPORT DataA_Terrain_FactoryLowerRight_u8_arr
.IMPORT DataA_Terrain_FactoryUpperLeft_u8_arr
.IMPORT DataA_Terrain_FactoryUpperRight_u8_arr
.IMPORT DataA_Terrain_GardenLowerLeft_u8_arr
.IMPORT DataA_Terrain_GardenLowerRight_u8_arr
.IMPORT DataA_Terrain_GardenUpperLeft_u8_arr
.IMPORT DataA_Terrain_GardenUpperRight_u8_arr
.IMPORT DataA_Terrain_HouseLowerLeft_u8_arr
.IMPORT DataA_Terrain_HouseLowerRight_u8_arr
.IMPORT DataA_Terrain_HouseUpperLeft_u8_arr
.IMPORT DataA_Terrain_HouseUpperRight_u8_arr
.IMPORT DataA_Terrain_HutLowerLeft_u8_arr
.IMPORT DataA_Terrain_HutLowerRight_u8_arr
.IMPORT DataA_Terrain_HutUpperLeft_u8_arr
.IMPORT DataA_Terrain_HutUpperRight_u8_arr
.IMPORT DataA_Terrain_LavaLowerLeft_u8_arr
.IMPORT DataA_Terrain_LavaLowerRight_u8_arr
.IMPORT DataA_Terrain_LavaUpperLeft_u8_arr
.IMPORT DataA_Terrain_LavaUpperRight_u8_arr
.IMPORT DataA_Terrain_MermaidLowerLeft_u8_arr
.IMPORT DataA_Terrain_MermaidLowerRight_u8_arr
.IMPORT DataA_Terrain_MermaidUpperLeft_u8_arr
.IMPORT DataA_Terrain_MermaidUpperRight_u8_arr
.IMPORT DataA_Terrain_MineLowerLeft_u8_arr
.IMPORT DataA_Terrain_MineLowerRight_u8_arr
.IMPORT DataA_Terrain_MineUpperLeft_u8_arr
.IMPORT DataA_Terrain_MineUpperRight_u8_arr
.IMPORT DataA_Terrain_OutdoorsLowerLeft_u8_arr
.IMPORT DataA_Terrain_OutdoorsLowerRight_u8_arr
.IMPORT DataA_Terrain_OutdoorsUpperLeft_u8_arr
.IMPORT DataA_Terrain_OutdoorsUpperRight_u8_arr
.IMPORT DataA_Terrain_PrisonLowerLeft_u8_arr
.IMPORT DataA_Terrain_PrisonLowerRight_u8_arr
.IMPORT DataA_Terrain_PrisonUpperLeft_u8_arr
.IMPORT DataA_Terrain_PrisonUpperRight_u8_arr
.IMPORT DataA_Terrain_SewerLowerLeft_u8_arr
.IMPORT DataA_Terrain_SewerLowerRight_u8_arr
.IMPORT DataA_Terrain_SewerUpperLeft_u8_arr
.IMPORT DataA_Terrain_SewerUpperRight_u8_arr
.IMPORT DataA_Terrain_TempleLowerLeft_u8_arr
.IMPORT DataA_Terrain_TempleLowerRight_u8_arr
.IMPORT DataA_Terrain_TempleUpperLeft_u8_arr
.IMPORT DataA_Terrain_TempleUpperRight_u8_arr
.IMPORT Ppu_ChrBgCore
.IMPORT Ppu_ChrBgCrypt
.IMPORT Ppu_ChrBgFactory
.IMPORT Ppu_ChrBgGarden
.IMPORT Ppu_ChrBgHouse
.IMPORT Ppu_ChrBgHut
.IMPORT Ppu_ChrBgLava
.IMPORT Ppu_ChrBgMermaid
.IMPORT Ppu_ChrBgMine
.IMPORT Ppu_ChrBgOutdoors
.IMPORT Ppu_ChrBgPrison
.IMPORT Ppu_ChrBgSewer
.IMPORT Ppu_ChrBgTemple

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.EXPORT DataA_Room_Core_sTileset
.PROC DataA_Room_Core_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_CoreUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_CoreLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_CoreUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_CoreLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrBgCore)
    D_END
.ENDPROC

.EXPORT DataA_Room_Crypt_sTileset
.PROC DataA_Room_Crypt_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_CryptUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_CryptLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_CryptUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_CryptLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrBgCrypt)
    D_END
.ENDPROC

.EXPORT DataA_Room_Factory_sTileset
.PROC DataA_Room_Factory_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_FactoryUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_FactoryLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_FactoryUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_FactoryLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrBgFactory)
    D_END
.ENDPROC

.EXPORT DataA_Room_Garden_sTileset
.PROC DataA_Room_Garden_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_GardenUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_GardenLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_GardenUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_GardenLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrBgGarden)
    D_END
.ENDPROC

.EXPORT DataA_Room_House_sTileset
.PROC DataA_Room_House_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_HouseUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_HouseLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_HouseUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_HouseLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrBgHouse)
    D_END
.ENDPROC

.EXPORT DataA_Room_Hut_sTileset
.PROC DataA_Room_Hut_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_HutUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_HutLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_HutUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_HutLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrBgHut)
    D_END
.ENDPROC

.EXPORT DataA_Room_Lava_sTileset
.PROC DataA_Room_Lava_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_LavaUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_LavaLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_LavaUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_LavaLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrBgLava)
    D_END
.ENDPROC

.EXPORT DataA_Room_Mermaid_sTileset
.PROC DataA_Room_Mermaid_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_MermaidUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_MermaidLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_MermaidUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_MermaidLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrBgMermaid)
    D_END
.ENDPROC

.EXPORT DataA_Room_Mine_sTileset
.PROC DataA_Room_Mine_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_MineUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_MineLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_MineUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_MineLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrBgMine)
    D_END
.ENDPROC

.EXPORT DataA_Room_Outdoors_sTileset
.PROC DataA_Room_Outdoors_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_OutdoorsUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_OutdoorsLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_OutdoorsUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_OutdoorsLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrBgOutdoors)
    D_END
.ENDPROC

.EXPORT DataA_Room_Prison_sTileset
.PROC DataA_Room_Prison_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_PrisonUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_PrisonLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_PrisonUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_PrisonLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrBgPrison)
    D_END
.ENDPROC

.EXPORT DataA_Room_Sewer_sTileset
.PROC DataA_Room_Sewer_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_SewerUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_SewerLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_SewerUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_SewerLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrBgSewer)
    D_END
.ENDPROC

.EXPORT DataA_Room_Temple_sTileset
.PROC DataA_Room_Temple_sTileset
    D_STRUCT sTileset
    d_addr UpperLeft_u8_arr_ptr,  DataA_Terrain_TempleUpperLeft_u8_arr
    d_addr LowerLeft_u8_arr_ptr,  DataA_Terrain_TempleLowerLeft_u8_arr
    d_addr UpperRight_u8_arr_ptr, DataA_Terrain_TempleUpperRight_u8_arr
    d_addr LowerRight_u8_arr_ptr, DataA_Terrain_TempleLowerRight_u8_arr
    d_byte Chr08Bank_u8, <.bank(Ppu_ChrBgTemple)
    D_END
.ENDPROC

;;;=========================================================================;;;
