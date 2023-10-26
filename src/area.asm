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

.INCLUDE "charmap.inc"
.INCLUDE "macros.inc"
.INCLUDE "room.inc"

;;;=========================================================================;;;

.SEGMENT "PRGA_Pause"

.EXPORT DataA_Pause_AreaNames_u8_arr12_ptr_0_arr
.EXPORT DataA_Pause_AreaNames_u8_arr12_ptr_1_arr
.REPEAT 2, table
    D_TABLE_LO table, DataA_Pause_AreaNames_u8_arr12_ptr_0_arr
    D_TABLE_HI table, DataA_Pause_AreaNames_u8_arr12_ptr_1_arr
    D_TABLE .enum, eArea
    d_entry table, City,    DataA_Pause_CityAreaName_u8_arr12
    d_entry table, Core,    DataA_Pause_CoreAreaName_u8_arr12
    d_entry table, Crypt,   DataA_Pause_CryptAreaName_u8_arr12
    d_entry table, Factory, DataA_Pause_FactoryAreaName_u8_arr12
    d_entry table, Garden,  DataA_Pause_GardenAreaName_u8_arr12
    d_entry table, Lava,    DataA_Pause_LavaAreaName_u8_arr12
    d_entry table, Mermaid, DataA_Pause_MermaidAreaName_u8_arr12
    d_entry table, Mine,    DataA_Pause_MineAreaName_u8_arr12
    d_entry table, Prison,  DataA_Pause_PrisonAreaName_u8_arr12
    d_entry table, Sewer,   DataA_Pause_SewerAreaName_u8_arr12
    d_entry table, Shadow,  DataA_Pause_ShadowAreaName_u8_arr12
    d_entry table, Temple,  DataA_Pause_TempleAreaName_u8_arr12
    d_entry table, Town,    DataA_Pause_TownAreaName_u8_arr12
    D_END
.ENDREPEAT

.PROC DataA_Pause_CityAreaName_u8_arr12
:   .byte "Ancient City"
    .assert * - :- = 12, error
.ENDPROC

.PROC DataA_Pause_CoreAreaName_u8_arr12
:   .byte " Power Core "
    .assert * - :- = 12, error
.ENDPROC

.PROC DataA_Pause_CryptAreaName_u8_arr12
:   .byte "Hidden Crypt"
    .assert * - :- = 12, error
.ENDPROC

.PROC DataA_Pause_FactoryAreaName_u8_arr12
:   .byte "Rust Factory"
    .assert * - :- = 12, error
.ENDPROC

.PROC DataA_Pause_GardenAreaName_u8_arr12
:   .byte " Vine Garden"
    .assert * - :- = 12, error
.ENDPROC

.PROC DataA_Pause_LavaAreaName_u8_arr12
:   .byte "Volcanic Pit"
    .assert * - :- = 12, error
.ENDPROC

.PROC DataA_Pause_MermaidAreaName_u8_arr12
:   .byte "Mermaid Vale"
    .assert * - :- = 12, error
.ENDPROC

.PROC DataA_Pause_MineAreaName_u8_arr12
:   .byte " Salt Mines "
    .assert * - :- = 12, error
.ENDPROC

.PROC DataA_Pause_PrisonAreaName_u8_arr12
:   .byte "Prison Caves"
    .assert * - :- = 12, error
.ENDPROC

.PROC DataA_Pause_SewerAreaName_u8_arr12
:   .byte "Old Waterway"
    .assert * - :- = 12, error
.ENDPROC

.PROC DataA_Pause_ShadowAreaName_u8_arr12
:   .byte " Shadow Labs"
    .assert * - :- = 12, error
.ENDPROC

.PROC DataA_Pause_TempleAreaName_u8_arr12
:   .byte " Lost Temple"
    .assert * - :- = 12, error
.ENDPROC

.PROC DataA_Pause_TownAreaName_u8_arr12
:   .byte " Bartik Town"
    .assert * - :- = 12, error
.ENDPROC

.EXPORT DataA_Pause_AreaCells_u8_arr2_arr_ptr_0_arr
.EXPORT DataA_Pause_AreaCells_u8_arr2_arr_ptr_1_arr
.REPEAT 2, table
    D_TABLE_LO table, DataA_Pause_AreaCells_u8_arr2_arr_ptr_0_arr
    D_TABLE_HI table, DataA_Pause_AreaCells_u8_arr2_arr_ptr_1_arr
    D_TABLE .enum, eArea
    d_entry table, City,    DataA_Pause_CityAreaCells_u8_arr2_arr
    d_entry table, Core,    DataA_Pause_CoreAreaCells_u8_arr2_arr
    d_entry table, Crypt,   DataA_Pause_CryptAreaCells_u8_arr2_arr
    d_entry table, Factory, DataA_Pause_FactoryAreaCells_u8_arr2_arr
    d_entry table, Garden,  DataA_Pause_GardenAreaCells_u8_arr2_arr
    d_entry table, Lava,    DataA_Pause_LavaAreaCells_u8_arr2_arr
    d_entry table, Mermaid, DataA_Pause_MermaidAreaCells_u8_arr2_arr
    d_entry table, Mine,    DataA_Pause_MineAreaCells_u8_arr2_arr
    d_entry table, Prison,  DataA_Pause_PrisonAreaCells_u8_arr2_arr
    d_entry table, Sewer,   DataA_Pause_SewerAreaCells_u8_arr2_arr
    d_entry table, Shadow,  DataA_Pause_ShadowAreaCells_u8_arr2_arr
    d_entry table, Temple,  DataA_Pause_TempleAreaCells_u8_arr2_arr
    d_entry table, Town,    DataA_Pause_TownAreaCells_u8_arr2_arr
    D_END
.ENDREPEAT

.PROC DataA_Pause_CityAreaCells_u8_arr2_arr
    .byte  1, 19
    .byte  1, 20
    .byte  1, 21
    .byte  1, 22
    .byte  2, 16
    .byte  2, 17
    .byte  2, 18
    .byte  2, 19
    .byte  2, 20
    .byte  2, 21
    .byte  2, 22
    .byte  2, 23
    .byte  3, 18
    .byte  3, 19
    .byte  3, 20
    .byte  3, 21
    .byte  3, 23
    .byte  4, 19
    .byte $ff
.ENDPROC

.PROC DataA_Pause_CoreAreaCells_u8_arr2_arr
    .byte  1, 13
    .byte  1, 14
    .byte  2, 10
    .byte  2, 11
    .byte  2, 12
    .byte  2, 13
    .byte  2, 14
    .byte  2, 15
    .byte  3, 11
    .byte  3, 12
    .byte  3, 13
    .byte  3, 14
    .byte  3, 15
    .byte  4, 12
    .byte  4, 13
    .byte  4, 14
    .byte  5, 12
    .byte $ff
.ENDPROC

.PROC DataA_Pause_CryptAreaCells_u8_arr2_arr
    .byte  7,  0
    .byte  7,  2
    .byte  8,  0
    .byte  8,  1
    .byte  8,  2
    .byte  9,  0
    .byte  9,  1
    .byte  9,  2
    .byte  9,  3
    .byte 10,  0
    .byte 10,  1
    .byte 10,  2
    .byte 10,  3
    .byte 10,  4
    .byte 11,  0
    .byte 11,  1
    .byte 11,  2
    .byte 11,  3
    .byte 12,  0
    .byte 12,  1
    .byte 13,  0
    .byte $ff
.ENDPROC

.PROC DataA_Pause_FactoryAreaCells_u8_arr2_arr
    .byte  5,  8
    .byte  5,  9
    .byte  5, 10
    .byte  5, 11
    .byte  5, 14
    .byte  5, 15
    .byte  6, 10
    .byte  6, 11
    .byte  6, 12
    .byte  6, 13
    .byte  6, 14
    .byte  6, 15
    .byte  6, 16
    .byte  7, 10
    .byte  7, 12
    .byte  7, 13
    .byte  7, 14
    .byte  7, 15
    .byte  7, 16
    .byte $ff
.ENDPROC

.PROC DataA_Pause_GardenAreaCells_u8_arr2_arr
    .byte  4,  6
    .byte  5,  6
    .byte  6,  6
    .byte  7,  6
    .byte  7,  7
    .byte  7,  8
    .byte  7,  9
    .byte  7,  11
    .byte  8,  6
    .byte  8,  7
    .byte  8,  8
    .byte  8,  9
    .byte  8, 10
    .byte  8, 11
    .byte  9,  6
    .byte  9,  7
    .byte  9,  8
    .byte  9,  9
    .byte  9, 10
    .byte  9, 11
    .byte 10,  6
    .byte 10,  7
    .byte 10,  8
    .byte $ff
.ENDPROC

.PROC DataA_Pause_LavaAreaCells_u8_arr2_arr
    .byte 12, 14
    .byte 12, 16
    .byte 12, 17
    .byte 12, 18
    .byte 12, 19
    .byte 12, 20
    .byte 13, 13
    .byte 13, 14
    .byte 13, 15
    .byte 13, 16
    .byte 13, 17
    .byte 13, 18
    .byte 13, 19
    .byte 13, 20
    .byte 14, 14
    .byte 14, 15
    .byte 14, 16
    .byte 14, 17
    .byte 14, 18
    .byte 14, 19
    .byte 14, 20
    .byte 14, 21
    .byte $ff
.ENDPROC

.PROC DataA_Pause_MermaidAreaCells_u8_arr2_arr
    .byte  8, 14
    .byte  9, 13
    .byte  9, 14
    .byte  9, 15
    .byte  9, 16
    .byte 10,  9
    .byte 10, 10
    .byte 10, 11
    .byte 10, 12
    .byte 10, 13
    .byte 10, 14
    .byte 10, 15
    .byte 10, 16
    .byte 11, 11
    .byte 11, 12
    .byte 11, 13
    .byte 11, 14
    .byte $ff
.ENDPROC

.PROC DataA_Pause_MineAreaCells_u8_arr2_arr
    .byte  9, 18
    .byte  9, 19
    .byte  9, 20
    .byte  9, 21
    .byte  9, 22
    .byte  9, 23
    .byte 10, 18
    .byte 10, 19
    .byte 10, 20
    .byte 10, 21
    .byte 10, 22
    .byte 10, 23
    .byte 11, 19
    .byte 11, 20
    .byte 11, 21
    .byte 11, 22
    .byte 11, 23
    .byte 12, 21
    .byte 12, 22
    .byte 12, 23
    .byte 13, 23
    .byte $ff
.ENDPROC

.PROC DataA_Pause_PrisonAreaCells_u8_arr2_arr
    .byte 1, 5
    .byte 1, 6
    .byte 1, 7
    .byte 1, 8
    .byte 2, 3
    .byte 2, 4
    .byte 2, 5
    .byte 2, 6
    .byte 2, 7
    .byte 2, 8
    .byte 2, 9
    .byte 3, 3
    .byte 3, 4
    .byte 3, 5
    .byte 3, 6
    .byte 3, 8
    .byte 3, 9
    .byte $ff
.ENDPROC

.PROC DataA_Pause_SewerAreaCells_u8_arr2_arr
    .byte  3, 22
    .byte  4, 22
    .byte  5, 16
    .byte  5, 17
    .byte  5, 18
    .byte  5, 19
    .byte  5, 20
    .byte  5, 21
    .byte  5, 22
    .byte  5, 23
    .byte  6, 19
    .byte  6, 22
    .byte  7, 17
    .byte  7, 18
    .byte  7, 19
    .byte  7, 20
    .byte  7, 21
    .byte  7, 22
    .byte  7, 23
    .byte  8, 21
    .byte $ff
.ENDPROC

.PROC DataA_Pause_ShadowAreaCells_u8_arr2_arr
    .byte 12, 5
    .byte 12, 6
    .byte 12, 7
    .byte 12, 8
    .byte 12, 9
    .byte 13, 3
    .byte 13, 4
    .byte 13, 5
    .byte 13, 6
    .byte 13, 7
    .byte 13, 8
    .byte 13, 9
    .byte 13, 10
    .byte 14, 4
    .byte 14, 5
    .byte 14, 6
    .byte 14, 7
    .byte 14, 8
    .byte 14, 9
    .byte $ff
.ENDPROC

.PROC DataA_Pause_TempleAreaCells_u8_arr2_arr
    .byte  1,  1
    .byte  2,  1
    .byte  3,  0
    .byte  3,  1
    .byte  4,  0
    .byte  4,  1
    .byte  5,  0
    .byte  5,  1
    .byte  5,  2
    .byte  5,  3
    .byte  5,  4
    .byte  6,  0
    .byte  6,  1
    .byte  6,  2
    .byte  6,  3
    .byte  6,  4
    .byte  7,  3
    .byte  7,  4
    .byte  7,  5
    .byte  8,  5
    .byte $ff
.ENDPROC

.PROC DataA_Pause_TownAreaCells_u8_arr2_arr
    .byte  0, 11
    .byte  0, 12
    .byte  0, 13
    .byte  0, 14
    .byte  0, 15
    .byte  0, 16
    .byte $ff
.ENDPROC

;;;=========================================================================;;;
