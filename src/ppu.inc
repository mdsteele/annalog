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

;;; See https://wiki.nesdev.org/w/index.php/PPU_registers

;;;=========================================================================;;;

kTileWidthPx = 8
kTileHeightPx = 8
kScreenWidthTiles = 32
kScreenHeightTiles = 30
kScreenWidthPx = kScreenWidthTiles * kTileWidthPx
kScreenHeightPx = kScreenHeightTiles * kTileHeightPx

;;;=========================================================================;;;

;;; PPU control register.
;;;
;;; When using the MMC3 mapper's IRQ feature, it is best to use 8x8 objects,
;;; and use pattern table $0000 for BG and $1000 for objects.  For details, see
;;; https://wiki.nesdev.org/w/index.php/MMC3#IRQ_Specifics and
;;; https://wiki.nesdev.org/w/index.php/Sprite_size.
Hw_PpuCtrl_wo = $2000

.SCOPE bPpuCtrl
    EnableNmi = %10000000  ; enable NMI interrupts for VBlank
    Obj8x16   = %00100000  ; use 8x16 objects (instead of 8x8)
    BgPat1    = %00010000  ; use pattern table 1 ($1000) for background
    ObjPat1   = %00001000  ; use pattern table 1 ($1000) for objects
    Inc32     = %00000100  ; increment VRAM addr by 32 per PpuData read/write
    NameMask  = %00000011  ; bits used to specify base nametable for scrolling
.ENDSCOPE

;;;=========================================================================;;;

;;; PPU rendering mask.  Set this to zero to disable rendering, which will
;;; allow access to the PPU outside of VBlank.
Hw_PpuMask_wo = $2001

.SCOPE bPpuMask
    EmphBlue  = %10000000  ; emphasize blue
    EmphGreen = %01000000  ; emphasize green
    EmphRed   = %00100000  ; emphasize red
    ObjMain   = %00010000  ; draw objects in main part of screen
    BgMain    = %00001000  ; draw background in main part of screen
    ObjLeft   = %00000100  ; draw objects in leftmost part of screen
    BgLeft    = %00000010  ; draw background in leftmost part of screen
    Grayscale = %00000001  ; grayscale mode
.ENDSCOPE

;;;=========================================================================;;;

;;; PPU status register.  Reading this will clear bit 7 (bPpuStatus::VBlank),
;;; and will also reset the write-twice latch for Hw_PpuScroll_w2 and
;;; Hw_PpuAddr_w2.
Hw_PpuStatus_ro = $2002

.SCOPE bPpuStatus
    VBlank     = %10000000  ; VBlank has started
    Sprite0Hit = %01000000  ; an opaque OBJ 0 pixel hit an opaque BG pixel
.ENDSCOPE

;;;=========================================================================;;;

;;; PPU scroll position.  Write twice (first X, then Y).
Hw_PpuScroll_w2 = $2005

;;;=========================================================================;;;

;;; PPU address register.  16 bits, write twice (high then low).
Hw_PpuAddr_w2 = $2006

;;; PPU data register.  Auto-increments Hw_PpuAddr_w2 by 1 or 32 on each
;;; access, depending on the value of Hw_PpuCtrl_wo.
Hw_PpuData_rw = $2007

;;;=========================================================================;;;

.STRUCT sName
    Tiles_u8_arr .byte 960
    Attrs_u8_arr .byte 64
.ENDSTRUCT

;;; See https://wiki.nesdev.org/w/index.php/PPU_nametables
Ppu_Nametables_sName_arr4 = $2000

;;;=========================================================================;;;

.STRUCT sPal
    C0 .byte
    C1 .byte
    C2 .byte
    C3 .byte
.ENDSTRUCT

;;; See https://wiki.nesdev.org/w/index.php/PPU_palettes
Ppu_Palettes_sPal_arr8 = $3f00

;;;=========================================================================;;;
