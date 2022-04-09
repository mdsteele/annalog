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

;;; The NES 2.0 header.  See https://wiki.nesdev.org/w/index.php/NES_2.0.  This
;;; is used for constructing the iNES-format ROM container file, and is used by
;;; emulators, but does not appear on a real NES cartridge.

;;;=========================================================================;;;

.SCOPE bFlags
    FourScreen        = %1000
    HasTrainer        = %0100
    HasSram           = %0010
    VerticalMirroring = %0001
.ENDSCOPE

;;;=========================================================================;;;

kVersion     = 2  ; header version; 0 = iNES, 2 = NES 2.0
kConsole     = 0  ; 0 = NES, 1 = Vs. System, 2 = Playchoice 10, 3 = other
kExtConsole  = 0  ; unused when kConsole = NES
kRegion      = 0  ; 0 = NTSC, 1 = PAL, 2 = multiple, 3 = Dendy
kMapper      = 4  ; iNES mapper #4 is MMC3
kSubmapper   = 0  ; for MMC3, submapper #0 is MMC3C ("new style" IRQ)
kPrgRomSize  = 4  ; number of 16k PRG ROM chunks (should be a power of 2)
kChrRomSize  = 4  ; number of 8k CHR ROM chunks (should be a power of 2)
kPrgRamShift = 0  ; if nonzero, there are (64 << this) bytes of PRG RAM
kSramShift   = 7  ; if nonzero, there are (64 << this) bytes of SRAM
kChrRamShift = 0  ; if nonzero, there are (64 << this) bytes of CHR RAM
kChrNvShift  = 0  ; if nonzero, there are (64 << this) bytes of CHR NVRAM
kNumMiscRoms = 0  ; unused for most consoles/mappers
kController  = 1  ; default controller to enumlate; 1 = standard joypad
kFlags       = bFlags::HasSram

;;;=========================================================================;;;

.SEGMENT "HEADER"
    .byte "NES", $1a  ; magic number
    .byte (kPrgRomSize & $0ff)
    .byte (kChrRomSize & $0ff)
    .byte ((kMapper & $00f) << 4) | kFlags
    .byte (kMapper & $0f0) | (kVersion << 2) | kConsole
    .byte (kSubmapper << 4) | ((kMapper & $f00) >> 8)
    .byte ((kChrRomSize & $f00) >> 4) | ((kPrgRomSize & $f00) >> 8)
    .byte (kSramShift << 4) | kPrgRamShift
    .byte (kChrNvShift << 4) | kChrRamShift
    .byte kRegion
    .byte kExtConsole
    .byte kNumMiscRoms
    .byte kController

;;;=========================================================================;;;
