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
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

.ZEROPAGE

;;; The current minimap cell that the avatar is in.
.EXPORTZP Zp_AvatarMinimapRow_u8, Zp_AvatarMinimapCol_u8
Zp_AvatarMinimapRow_u8: .res 1
Zp_AvatarMinimapCol_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Recomputes Zp_AvatarMinimapRow_u8 and Zp_AvatarMinimapCol_u8 from the
;;; avatar's current position and room, then (if necessary) updates SRAM to
;;; mark that minimap cell as explored.
.EXPORT FuncA_Avatar_UpdateAndMarkMinimap
.PROC FuncA_Avatar_UpdateAndMarkMinimap
_UpdateMinimapRow:
    ldy <(Zp_Current_sRoom + sRoom::MinimapStartRow_u8)
    bit <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bpl @upperHalf
    @tall:
    lda Zp_AvatarPosY_i16 + 1
    bmi @upperHalf
    bne @lowerHalf
    lda Zp_AvatarPosY_i16 + 0
    cmp #(kTallRoomHeightBlocks / 2) * kBlockHeightPx
    blt @upperHalf
    @lowerHalf:
    iny
    @upperHalf:
    sty Zp_AvatarMinimapRow_u8
_UpdateMinimapCol:
    lda Zp_AvatarPosX_i16 + 1
    bmi @leftSide
    cmp <(Zp_Current_sRoom + sRoom::MinimapWidth_u8)
    blt @middle
    @rightSide:
    ldx <(Zp_Current_sRoom + sRoom::MinimapWidth_u8)
    dex
    txa
    @middle:
    add <(Zp_Current_sRoom + sRoom::MinimapStartCol_u8)
    bcc @setCol  ; unconditional
    @leftSide:
    lda <(Zp_Current_sRoom + sRoom::MinimapStartCol_u8)
    @setCol:
    sta Zp_AvatarMinimapCol_u8
_MarkMinimap:
    ;; Determine the bitmask to use for Sram_Minimap_u16_arr, and store it in
    ;; Zp_Tmp1_byte.
    lda Zp_AvatarMinimapRow_u8
    tay
    and #$07
    tax
    lda Data_PowersOfTwo_u8_arr8, x
    sta Zp_Tmp1_byte  ; mask
    ;; Calculate the byte offset into Sram_Minimap_u16_arr and store it in X.
    lda Zp_AvatarMinimapCol_u8
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

.EXPORT DataA_Pause_CryptAreaName_u8_arr
.PROC DataA_Pause_CryptAreaName_u8_arr
    .byte "Deep Crypt", $ff
.ENDPROC

.EXPORT DataA_Pause_GardenAreaName_u8_arr
.PROC DataA_Pause_GardenAreaName_u8_arr
    .byte "Vine Garden", $ff
.ENDPROC

.EXPORT DataA_Pause_MermaidAreaName_u8_arr
.PROC DataA_Pause_MermaidAreaName_u8_arr
    .byte "Mermaid Vale", $ff
.ENDPROC

.EXPORT DataA_Pause_PrisonAreaName_u8_arr
.PROC DataA_Pause_PrisonAreaName_u8_arr
    .byte "Prison Caves", $ff
.ENDPROC

.EXPORT DataA_Pause_TownAreaName_u8_arr
.PROC DataA_Pause_TownAreaName_u8_arr
    .byte "Bartik Town", $ff
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

.EXPORT DataA_Pause_GardenAreaCells_u8_arr2_arr
.PROC DataA_Pause_GardenAreaCells_u8_arr2_arr
    .byte  6,  6
    .byte  7,  6
    .byte  7,  7
    .byte  7,  8
    .byte  7,  9
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

.EXPORT DataA_Pause_PrisonAreaCells_u8_arr2_arr
.PROC DataA_Pause_PrisonAreaCells_u8_arr2_arr
    .byte 1, 5
    .byte 1, 6
    .byte 1, 7
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

.EXPORT DataA_Pause_TownAreaCells_u8_arr2_arr
.PROC DataA_Pause_TownAreaCells_u8_arr2_arr
    .byte 0, 11
    .byte 0, 12
    .byte 0, 13
    .byte 0, 14
    .byte 0, 15
    .byte 0, 16
    .byte $ff
.ENDPROC

;;; An array of all the markers that can appear on the minimap during the game.
;;; This array is sorted, first by Row_u8 (ascending), then by Col_u8
;;; (ascending), then by priority (descending).  It is terminated by an entry
;;; with Row_u8 = $ff.
.EXPORT DataA_Pause_Minimap_sMarker_arr
.PROC DataA_Pause_Minimap_sMarker_arr
    D_STRUCT sMarker
    d_byte Row_u8, 7
    d_byte Col_u8, 8
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::UpgradeOpcodeIf
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
    d_byte Col_u8, 12
    d_byte If_eFlag, eFlag::GardenEastTalkedToMermaid
    d_byte Not_eFlag, eFlag::MermaidHut1MetQueen
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 11
    d_byte Col_u8, 0
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::ConduitCrypt
    D_END
    .assert sMarker::Row_u8 = 0, error
    .byte $ff
.ENDPROC
;;; Ensure that we can access all bytes of the array with one index register.
.ASSERT .sizeof(DataA_Pause_Minimap_sMarker_arr) <= $100, error

;;;=========================================================================;;;
