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
.INCLUDE "flag.inc"
.INCLUDE "macros.inc"
.INCLUDE "minimap.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT Sram_Minimap_u16_arr
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

.ZEROPAGE

;;; The minimap cell that the room camera is currently looking at.
.EXPORTZP Zp_CameraMinimapRow_u8, Zp_CameraMinimapCol_u8
Zp_CameraMinimapRow_u8: .res 1
Zp_CameraMinimapCol_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; Recomputes Zp_CameraMinimapRow_u8 and Zp_CameraMinimapCol_u8 from the
;;; current room scroll position, then (if necessary) updates SRAM to mark that
;;; minimap cell as explored.
.EXPORT FuncA_Terrain_UpdateAndMarkMinimap
.PROC FuncA_Terrain_UpdateAndMarkMinimap
_UpdateMinimapRow:
    ldy <(Zp_Current_sRoom + sRoom::MinimapStartRow_u8)
    bit <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bpl @upperHalf
    @tall:
    lda Zp_RoomScrollY_u8
    cmp #(kTallRoomHeightBlocks * kBlockHeightPx - kScreenHeightPx) / 2
    blt @upperHalf
    @lowerHalf:
    iny
    @upperHalf:
    sty Zp_CameraMinimapRow_u8
_UpdateMinimapCol:
    ;; Calculate which horizontal screen of the room the camera is looking at
    ;; (in other words, the hi byte of (camera center position - min scroll X)
    ;; in room pixel coordinates), storing the result in A.
    lda #kScreenWidthPx / 2
    sub <(Zp_Current_sRoom + sRoom::MinScrollX_u8)
    add Zp_RoomScrollX_u16 + 0
    lda #0
    adc Zp_RoomScrollX_u16 + 1
    ;; Add that screen number to the room's starting minimap column to get the
    ;; current absolute minimap column.
    add <(Zp_Current_sRoom + sRoom::MinimapStartCol_u8)
    sta Zp_CameraMinimapCol_u8
_MarkMinimap:
    ;; Determine the bitmask to use for Sram_Minimap_u16_arr, and store it in
    ;; Zp_Tmp1_byte.
    lda Zp_CameraMinimapRow_u8
    tay
    and #$07
    tax
    lda Data_PowersOfTwo_u8_arr8, x
    sta Zp_Tmp1_byte  ; mask
    ;; Calculate the byte offset into Sram_Minimap_u16_arr and store it in X.
    lda Zp_CameraMinimapCol_u8
    mul #2
    tax  ; byte index into Sram_Minimap_u16_arr
    cpy #$08
    blt @loByte
    inx
    @loByte:
    ;; Check if minimap needs to be updated.
    lda Sram_Minimap_u16_arr, x
    ora Zp_Tmp1_byte  ; mask
    cmp Sram_Minimap_u16_arr, x
    beq @done
    ;; Enable writes to SRAM.
    ldy #bMmc3PrgRam::Enable
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Update minimap.
    sta Sram_Minimap_u16_arr, x
    ;; Disable writes to SRAM.
    ldy #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sty Hw_Mmc3PrgRamProtect_wo
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Pause"

.EXPORT DataA_Pause_CoreAreaName_u8_arr
.PROC DataA_Pause_CoreAreaName_u8_arr
    .byte "Power Core", $ff
.ENDPROC

.EXPORT DataA_Pause_CryptAreaName_u8_arr
.PROC DataA_Pause_CryptAreaName_u8_arr
    .byte "Deep Crypt", $ff
.ENDPROC

.EXPORT DataA_Pause_FactoryAreaName_u8_arr
.PROC DataA_Pause_FactoryAreaName_u8_arr
    .byte "Rust Factory", $ff
.ENDPROC

.EXPORT DataA_Pause_GardenAreaName_u8_arr
.PROC DataA_Pause_GardenAreaName_u8_arr
    .byte "Vine Garden", $ff
.ENDPROC

.EXPORT DataA_Pause_LavaAreaName_u8_arr
.PROC DataA_Pause_LavaAreaName_u8_arr
    .byte "Lava Pits", $ff
.ENDPROC

.EXPORT DataA_Pause_MermaidAreaName_u8_arr
.PROC DataA_Pause_MermaidAreaName_u8_arr
    .byte "Mermaid Vale", $ff
.ENDPROC

.EXPORT DataA_Pause_MineAreaName_u8_arr
.PROC DataA_Pause_MineAreaName_u8_arr
    .byte "Salt Mines", $ff
.ENDPROC

.EXPORT DataA_Pause_PrisonAreaName_u8_arr
.PROC DataA_Pause_PrisonAreaName_u8_arr
    .byte "Prison Caves", $ff
.ENDPROC

.EXPORT DataA_Pause_ShadowAreaName_u8_arr
.PROC DataA_Pause_ShadowAreaName_u8_arr
    .byte "Shadow Labs", $ff
.ENDPROC

.EXPORT DataA_Pause_TempleAreaName_u8_arr
.PROC DataA_Pause_TempleAreaName_u8_arr
    .byte "Lost Temple", $ff
.ENDPROC

.EXPORT DataA_Pause_TownAreaName_u8_arr
.PROC DataA_Pause_TownAreaName_u8_arr
    .byte "Bartik Town", $ff
.ENDPROC

.EXPORT DataA_Pause_CoreAreaCells_u8_arr2_arr
.PROC DataA_Pause_CoreAreaCells_u8_arr2_arr
    .byte  1, 13
    .byte  1, 14
    .byte  2, 10
    .byte  2, 11
    .byte  2, 12
    .byte  2, 13
    .byte  2, 14
    .byte  2, 15
    .byte  2, 16
    .byte  2, 17
    .byte  3, 11
    .byte  3, 12
    .byte  3, 13
    .byte  3, 14
    .byte  3, 15
    .byte  4, 13
    .byte  4, 14
    .byte $ff
.ENDPROC

.EXPORT DataA_Pause_CryptAreaCells_u8_arr2_arr
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
    .byte $ff
.ENDPROC

.EXPORT DataA_Pause_FactoryAreaCells_u8_arr2_arr
.PROC DataA_Pause_FactoryAreaCells_u8_arr2_arr
    .byte  4, 12
    .byte  5, 11
    .byte  5, 12
    .byte  5, 14
    .byte  5, 15
    .byte  6, 10
    .byte  6, 11
    .byte  6, 12
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

.EXPORT DataA_Pause_GardenAreaCells_u8_arr2_arr
.PROC DataA_Pause_GardenAreaCells_u8_arr2_arr
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

.EXPORT DataA_Pause_LavaAreaCells_u8_arr2_arr
.PROC DataA_Pause_LavaAreaCells_u8_arr2_arr
    .byte 12, 14
    .byte 12, 16
    .byte 12, 17
    .byte 12, 19
    .byte 13, 13
    .byte 13, 14
    .byte 13, 15
    .byte 13, 16
    .byte 13, 17
    .byte 13, 18
    .byte 13, 19
    .byte 14, 14
    .byte 14, 15
    .byte 14, 16
    .byte 14, 17
    .byte 14, 18
    .byte 14, 19
    .byte 14, 20
    .byte $ff
.ENDPROC

.EXPORT DataA_Pause_MermaidAreaCells_u8_arr2_arr
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

.EXPORT DataA_Pause_MineAreaCells_u8_arr2_arr
.PROC DataA_Pause_MineAreaCells_u8_arr2_arr
    .byte  9, 19
    .byte  9, 20
    .byte  9, 21
    .byte  9, 22
    .byte  9, 23
    .byte 10, 19
    .byte 10, 20
    .byte 10, 21
    .byte 10, 22
    .byte 10, 23
    .byte 11, 20
    .byte 11, 21
    .byte 11, 22
    .byte 12, 20
    .byte 12, 21
    .byte 12, 22
    .byte 13, 22
    .byte $ff
.ENDPROC

.EXPORT DataA_Pause_PrisonAreaCells_u8_arr2_arr
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
    .byte 4, 6
    .byte $ff
.ENDPROC

.EXPORT DataA_Pause_ShadowAreaCells_u8_arr2_arr
.PROC DataA_Pause_ShadowAreaCells_u8_arr2_arr
    .byte 12, 4
    .byte 12, 5
    .byte 12, 6
    .byte 12, 7
    .byte 13, 2
    .byte 13, 3
    .byte 13, 4
    .byte 13, 5
    .byte 13, 6
    .byte 13, 7
    .byte 13, 8
    .byte 13, 9
    .byte 14, 3
    .byte 14, 4
    .byte 14, 5
    .byte 14, 6
    .byte 14, 7
    .byte 14, 8
    .byte $ff
.ENDPROC

.EXPORT DataA_Pause_TempleAreaCells_u8_arr2_arr
.PROC DataA_Pause_TempleAreaCells_u8_arr2_arr
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

.EXPORT DataA_Pause_TownAreaCells_u8_arr2_arr
.PROC DataA_Pause_TownAreaCells_u8_arr2_arr
    .byte  0, 11
    .byte  0, 12
    .byte  0, 13
    .byte  0, 14
    .byte  0, 15
    .byte  0, 16
    .byte $ff
.ENDPROC

;;; An array of all the markers that can appear on the minimap during the game.
;;; This array is sorted, first by Row_u8 (ascending), then by Col_u8
;;; (ascending), then by priority (descending).  It is terminated by an entry
;;; with Row_u8 = $ff.
.EXPORT DataA_Pause_Minimap_sMarker_arr
.PROC DataA_Pause_Minimap_sMarker_arr
    D_STRUCT sMarker
    d_byte Row_u8, 1
    d_byte Col_u8, 8
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerPrison
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 7
    d_byte Col_u8, 8
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::UpgradeOpcodeIf
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 7
    d_byte Col_u8, 11
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerGarden
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 7
    d_byte Col_u8, 13
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::UpgradeOpcodeSkip
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 9
    d_byte Col_u8, 3
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerCrypt
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 9
    d_byte Col_u8, 13
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerMermaid
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 10
    d_byte Col_u8, 4
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::UpgradeOpcodeGoto
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 10
    d_byte Col_u8, 12
    d_byte If_eFlag, eFlag::GardenEastTalkedToMermaid
    d_byte Not_eFlag, eFlag::MermaidHut1MetQueen
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 11
    d_byte Col_u8, 0
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::BreakerCrypt
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 12
    d_byte Col_u8, 17
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::UpgradeOpcodeCopy
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 13
    d_byte Col_u8, 22
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::UpgradeOpcodeSync
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 14
    d_byte Col_u8, 16
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerLava
    D_END
    .assert sMarker::Row_u8 = 0, error
    .byte $ff
.ENDPROC
;;; Ensure that we can access all bytes of the array with one index register.
.ASSERT .sizeof(DataA_Pause_Minimap_sMarker_arr) <= $100, error

;;;=========================================================================;;;
