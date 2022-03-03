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

;;; See https://wiki.nesdev.org/w/index.php/MMC3

;;;=========================================================================;;;

;;; Writing here specifies the banking layout, as well as which bank to change
;;; when writing to Hw_Mmc3BankData_wo; the value written should be a bMmc3Bank
;;; bitfield or-ed together with an eMmc3Bank value.
Hw_Mmc3BankSelect_wo = $8000

.SCOPE bMmc3Bank
    ;; If set, CHR data is split into four swappable 1 KB banks at $0000-$0fff,
    ;; and two 2 KB banks at $1000-$1fff.  If cleared, instead there are two
    ;; swappable 2 KB banks at $0000-$0fff, and four 1 KB banks at $1000-$1fff.
    FourBankChr0000  = %10000000
    ;; If set, PRG $8000-$9fff is fixed to the second-to-last bank, and
    ;; $c000-$dfff is swappable.  If cleared, instead $8000-$9fff is swappable,
    ;; and $c000-$dfff is fixed to the second-to-last bank.
    SwappablePrgC000 = %01000000
    ;; These bits specify which bank register will be updated by the next
    ;; write to Hw_Mmc3BankData_wo.  These bits should be set to one of the
    ;; eMmc3Bank values.
    BankRegisterMask = %00000111
.ENDSCOPE

.ENUM eMmc3Bank
    ChrBank0Of2 = 0  ; CHR ROM bank at $0000-$07ff or $1000-$17ff
    ChrBank1Of2 = 1  ; CHR ROM bank at $0800-$0fff or $1800-$1fff
    ChrBank0Of4 = 2  ; CHR ROM bank at $1000-$13ff or $0000-$03ff
    ChrBank1Of4 = 3  ; CHR ROM bank at $1400-$17ff or $0400-$07ff
    ChrBank2Of4 = 4  ; CHR ROM bank at $1800-$1bff or $0800-$0bff
    ChrBank3Of4 = 5  ; CHR ROM bank at $1c00-$1fff or $0c00-$0fff
    PrgBank8OrC = 6  ; PRG ROM bank at $8000-$9fff or $c000-$dfff
    PrgBankA000 = 7  ; PRG ROM bank at $a000-$bfff
.ENDENUM

;;; Writing here sets the new bank value, based on last value written to
;;; Hw_Mmc3BankSelect_wo.  2KB CHR banks may only select even numbered banks
;;; (the lowest bit is ignored).
Hw_Mmc3BankData_wo = $8001

;;;=========================================================================;;;

;;; Writing here sets the nametable mirroring.
Hw_Mmc3Mirroring_wo = $a000

.ENUM eMmc3Mirror
    Vertical   = 0
    Horizontal = 1
.ENDENUM

;;;=========================================================================;;;

;;; Writing here sets whether reads/writes to PRG RAM are permitted; the main
;;; purpose is to write-protect save RAM during power-off.  Note that some
;;; emulators choose not to implement these settings as part of iNES Mapper 4,
;;; in order to avoid an incompatibility with the MMC6.
Hw_Mmc3PrgRamProtect_wo = $a001

.SCOPE bMmc3PrgRam
    Enable     = %10000000  ; if cleared, reads from PRG RAM return open bus
    DenyWrites = %01000000
.ENDSCOPE

;;;=========================================================================;;;

;;; This register specifies the IRQ counter reload value.  When the IRQ counter
;;; is zero (or if a reload is requested via Hw_Mmc3IrqReload_wo), this value
;;; will be copied to the IRQ counter at the next rising edge of the PPU
;;; address (presumably at PPU cycle 260 of the current scanline).
Hw_Mmc3IrqLatch_wo = $c000

;;; Writing any value to this register reloads the MMC3 IRQ counter at the next
;;; rising edge of the PPU address (presumably at PPU cycle 260 of the current
;;; scanline).
Hw_Mmc3IrqReload_wo = $c001

;;; Writing any value to this register will disable MMC3 interrupts and
;;; acknowledge any pending interrupts.  To acknowledge interrupts without
;;; disabling them, just disable then immediately reenable.
Hw_Mmc3IrqDisable_wo = $e000

;;; Writing any value to this register will enable MMC3 interrupts.
Hw_Mmc3IrqEnable_wo = $e001

;;;=========================================================================;;;

;;; MMC3 bank settings for this particular game:
kMmc3BankFlags = bMmc3Bank::FourBankChr0000 | bMmc3Bank::SwappablePrgC000

.MACRO _set_bank REG, ARG1, ARG2
    lda #kMmc3BankFlags | (REG)
    sta Hw_Mmc3BankSelect_wo
    .if .not .blank(ARG2)
    lda ARG1, ARG2
    sta Hw_Mmc3BankData_wo
    .elseif .match({ARG1}, x)
    stx Hw_Mmc3BankData_wo
    .else
    lda ARG1
    sta Hw_Mmc3BankData_wo
    .endif
.ENDMACRO

;;; Sets the given argument as the PRGA bank number.  The A register and the N
;;; and Z flags are destroyed in the process.
;;;
;;; Examples:
;;;     prga_bank #<.bank(FuncA_Foo)    ; use immediate value bank number
;;;     prga_bank Zp_BankNumber_u8      ; get bank number from variable
;;;     prga_bank x                     ; use X as the bank number
.MACRO prga_bank ARG
    _set_bank eMmc3Bank::PrgBankA000, ARG
.ENDMACRO

;;; Switches the PRGA bank number to that of the given function, then calls
;;; that function.  Note that the A register and the N and Z flags are
;;; destroyed by the bank-switching process, so this cannot be used for
;;; functions that take any of those as arguments.
;;;
;;; Example:
;;;     jsr_prga FuncA_Baz_Foobar  ; switches to PRGA_Baz and calls function
.MACRO jsr_prga ARG
    .assert ARG >= $a000 && ARG < $c000, error
    prga_bank #<.bank(ARG)
    jsr ARG
.ENDMACRO

;;; Sets the given argument as the PRGC bank number.  The A register and the N
;;; and Z flags are destroyed in the process.
;;;
;;; Examples:
;;;     prgc_bank #<.bank(DataC_Foo)    ; use immediate value bank number
;;;     prgc_bank Zp_BankNumber_u8      ; get bank number from variable
;;;     prgc_bank Data_Banks_u8_arr, x  ; get bank number from array
;;;     prgc_bank x                     ; use X as the bank number
.MACRO prgc_bank ARG1, ARG2
    _set_bank eMmc3Bank::PrgBank8OrC, ARG1, ARG2
.ENDMACRO

;;; Sets the given argument as the bank number for CHR $0000-$03ff.  The A
;;; register and the N and Z flags are destroyed in the process.
;;;
;;; This operation accepts the same arguments as prga_bank.
.MACRO chr00_bank ARG
    _set_bank eMmc3Bank::ChrBank0Of4, ARG
.ENDMACRO

;;; Sets the given argument as the bank number for CHR $0400-$07ff.  The A
;;; register and the N and Z flags are destroyed in the process.
;;;
;;; This operation accepts the same arguments as prga_bank.
.MACRO chr04_bank ARG
    _set_bank eMmc3Bank::ChrBank1Of4, ARG
.ENDMACRO

;;; Sets the given argument as the bank number for CHR $0800-$0bff.  The A
;;; register and the N and Z flags are destroyed in the process.
;;;
;;; This operation accepts the same arguments as prga_bank.
.MACRO chr08_bank ARG
    _set_bank eMmc3Bank::ChrBank2Of4, ARG
.ENDMACRO

;;; Sets the given argument as the bank number for CHR $0c00-$0fff.  The A
;;; register and the N and Z flags are destroyed in the process.
;;;
;;; This operation accepts the same arguments as prga_bank.
.MACRO chr0c_bank ARG
    _set_bank eMmc3Bank::ChrBank3Of4, ARG
.ENDMACRO

;;; Sets the given argument as the bank number for CHR $1000-$17ff.  The A
;;; register and the N and Z flags are destroyed in the process.
;;;
;;; This operation accepts the same arguments as prga_bank.
.MACRO chr10_bank ARG
    _set_bank eMmc3Bank::ChrBank0Of2, ARG
.ENDMACRO

;;; Sets the given argument as the bank number for CHR $1800-$1fff.  The A
;;; register and the N and Z flags are destroyed in the process.
;;;
;;; This operation accepts the same arguments as prga_bank.
.MACRO chr18_bank ARG
    _set_bank eMmc3Bank::ChrBank1Of2, ARG
.ENDMACRO

;;;=========================================================================;;;
