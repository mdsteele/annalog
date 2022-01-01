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

;;; See https://wiki.nesdev.org/w/index.php/PPU_OAM and
;;; https://wiki.nesdev.org/w/index.php/PPU_registers

;;;=========================================================================;;;

;;; Writing here sets the start OAM address used by Hw_OamDma_wo.
Hw_OamAddr_wo = $2003

;;; Writing $xx here will upload CPU page $xx00-$xxff to the internal PPU OAM.
;;; The CPU is suspended during the transfer.
Hw_OamDma_wo  = $4014

;;;=========================================================================;;;

.STRUCT sObj
    YPos_u8    .byte
    Tile_u8    .byte
    Flags_bObj .byte
    XPos_u8    .byte
.ENDSTRUCT

;;;=========================================================================;;;

.SCOPE bObj
    FlipV = %10000000  ; flip object vertically
    FlipH = %01000000  ; flip object horizontally
    Pri   = %00100000  ; draw object behind background
.ENDSCOPE

;;;=========================================================================;;;
