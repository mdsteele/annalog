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
;;;
;;; This file has two main sections: the first half defines constants and
;;; hardware registers that are intrinsic to the MMC3 hardware, while the
;;; second half defines constants and macros related to how this specific game
;;; uses the MMC3.

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

;;; From here to the end of this file are constants and macros that are
;;; specific to how this game uses the MMC3, rather than intrinsic to the MMC3
;;; hardware itself.
;;;
;;; For PRG ROM banks, this game always leaves PRG8 fixed and PRGC swappable
;;; (so as to make it possible to store DMC sample data in swappable PRG banks,
;;; since the APU can only read sample data from PRGC or PRGE).  For CHR ROM
;;; banks, this game always divides the CHR0 pattern table (which it uses for
;;; BG tiles) into four swappable segments, and the CHR1 pattern table (which
;;; it uses for OBJ tiles) into two swappable segments.
;;;
;;; This game only ever switches PRG banks from the main thread (that is, never
;;; from NMI or IRQ handlers), and so main thread code never has to worry about
;;; PRG banks switching out from under it.
;;;
;;; CHR banks, on the other hand, can be switched by any thread in this game,
;;; which creates a potential race condition.  For example: (1) the main thread
;;; sets MMC3 bank select for PRGA, (2) an interrupt occurs and changes some
;;; CHR bank, thus setting the MMC3 bank select for that CHR bank, (3) the main
;;; thread resumes and sets MMC3 bank data, but now this is setting a CHR bank
;;; instead of PRGA, and finally (4) the main thread jumps to PRGA code without
;;; the bank being properly set, and crashes.  This kind of conflict could
;;; potentially happen between any pair of threads (main, IRQ, and NMI), so we
;;; must take steps to avoid it.
;;;
;;; To avoid bank switch conflicts like this between the main thread and the
;;; IRQ thread, the main thread always writes the bank select value to
;;; Zp_MainSelect_bMmc3Bank just before writing to Hw_Mmc3BankSelect_wo, and
;;; the IRQ thread always copies Zp_MainSelect_bMmc3Bank back to
;;; Hw_Mmc3BankSelect_wo after completing a bank switch.  Thus, regardless of
;;; where the main thread gets interrupted, the intended bank select value will
;;; always be set when the main thread's bank data write occurs.
;;;
;;; To avoid bank switch conflicts between the main thread and the NMI thread,
;;; the NMI thread only ever changes a CHR bank when instructed to by the main
;;; thread via Func_ProcessFrame.  Thus, the main thread cannot be in the
;;; middle of a bank switch when the NMI thread switches banks, as it will be
;;; blocked within Func_ProcessFrame.
;;;
;;; There is no formal mechanism to prevent bank switch conflicts between the
;;; IRQ thread and the NMI thread (which can interrupt the IRQ thread, though
;;; not the other way around); instead, this game simply tries to manage its
;;; IRQs carefully so as to avoid ever being in the middle of one when an NMI
;;; occurs.  In addition, since the IRQ thread only ever switches CHR banks
;;; (not PRG), if a conflict does occur, it will most likely cause a one-frame
;;; graphical glitch, rather than a crash.

;;; MMC3 bank settings for this particular game:
kMmc3BankFlags = bMmc3Bank::FourBankChr0000 | bMmc3Bank::SwappablePrgC000
kSelectChr00 = kMmc3BankFlags | eMmc3Bank::ChrBank0Of4
kSelectChr04 = kMmc3BankFlags | eMmc3Bank::ChrBank1Of4
kSelectChr08 = kMmc3BankFlags | eMmc3Bank::ChrBank2Of4
kSelectChr0c = kMmc3BankFlags | eMmc3Bank::ChrBank3Of4
kSelectChr10 = kMmc3BankFlags | eMmc3Bank::ChrBank0Of2
kSelectChr18 = kMmc3BankFlags | eMmc3Bank::ChrBank1Of2
kSelectPrga  = kMmc3BankFlags | eMmc3Bank::PrgBankA000
kSelectPrgc  = kMmc3BankFlags | eMmc3Bank::PrgBank8OrC

.GLOBAL FuncM_SwitchPrgaBank
.GLOBALZP Zp_MainSelect_bMmc3Bank

;;; Sets Hw_Mmc3BankSelect_wo to the given kSelect* constant from within the
;;; main thread.
.MACRO _main_bank_select SELECT
    lda #SELECT
    sta Zp_MainSelect_bMmc3Bank
    sta Hw_Mmc3BankSelect_wo
.ENDMACRO

;;; Sets Hw_Mmc3BankData_wo from the given arguments.  Use this only if the
;;; current value of Hw_Mmc3BankSelect_wo is known.
.MACRO _bank_data ARG1, ARG2
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

;;; Switches PRGA banks on the main thread, setting it from the given value.
;;; The A register and the N and Z flags are destroyed in the process.
;;;
;;; Examples:
;;;     main_prga Zp_BankNumber_u8          ; gets bank number from variable
;;;     main_prga Data_Banks_u8_arr, x      ; gets bank number from array
;;;     main_prga (Zp_Banks_u8_arr_ptr), y  ; gets bank number from indirection
;;;     main_prga x                         ; uses X as the bank number
.MACRO main_prga ARG1, ARG2
    .if .not .blank(ARG2)
    lda ARG1, ARG2
    .else
    lda ARG1
    .endif
    jsr FuncM_SwitchPrgaBank
.ENDMACRO

;;; Switches PRGA banks on the main thread, setting it to the bank number of
;;; the given PRGA symbol.  The A register and the N and Z flags are destroyed
;;; in the process.
;;;
;;; Examples:
;;;     main_prga_bank DataA_Foo_Bar_u8_arr
.MACRO main_prga_bank ARG
    .assert ARG >= $a000 && ARG < $c000, error
    main_prga #<.bank(ARG)
.ENDMACRO

;;; Switches the PRGA bank number to that of the given function, then calls
;;; that function.  Use this only on the main thread.  Note that the A register
;;; and the N and Z flags are destroyed by the bank-switching process, so this
;;; cannot be used for functions that take any of those as arguments.
;;;
;;; Example:
;;;     jsr_prga FuncA_Baz_Foobar  ; switches to PRGA_Baz and calls function
.MACRO jsr_prga ARG
    main_prga_bank ARG
    jsr ARG
.ENDMACRO

;;; Switches the PRGA bank number to that of the given function, then jumps to
;;; that function; this is useful for jumping from a Main to a MainA, or from a
;;; FuncM to a FuncA.  Use this only on the main thread.  Note that the A
;;; register and the N and Z flags are destroyed by the bank-switching process,
;;; so this cannot be used for functions that take any of those as arguments.
;;;
;;; Example:
;;;     jmp_prga FuncA_Baz_Foobar  ; switches to PRGA_Baz and jumps to function
.MACRO jmp_prga ARG
    main_prga_bank ARG
    jmp ARG
.ENDMACRO

;;; Switches PRGC banks on the main thread, setting it from the given value.
;;; The A register and the N and Z flags are destroyed in the process.
;;;
;;; This operation accepts the same arguments as main_prga.
.MACRO main_prgc ARG1, ARG2
    _main_bank_select kSelectPrgc
    _bank_data ARG1, ARG2
.ENDMACRO

;;; Switches CHR00 banks on the main thread, setting it from the given value.
;;; The A register and the N and Z flags are destroyed in the process.
;;;
;;; This operation accepts the same arguments as main_prga.
.MACRO main_chr00 ARG1, ARG2
    _main_bank_select kSelectChr00
    _bank_data ARG1, ARG2
.ENDMACRO

;;; Switches CHR00 banks on the main thread, setting it to the bank number of
;;; the given Ppu_ChrBgj* symbol.  The A register and the N and Z flags are
;;; destroyed in the process.
.MACRO main_chr00_bank ARG
    main_chr00 #<.bank(ARG)
.ENDMACRO

;;; Switches CHR04 banks on the main thread, setting it from the given value.
;;; The A register and the N and Z flags are destroyed in the process.
;;;
;;; This operation accepts the same arguments as main_prga.
.MACRO main_chr04 ARG1, ARG2
    _main_bank_select kSelectChr04
    _bank_data ARG1, ARG2
.ENDMACRO

;;; Switches CHR04 banks on the main thread, setting it to the bank number of
;;; the given Ppu_ChrBgj* symbol.  The A register and the N and Z flags are
;;; destroyed in the process.
.MACRO main_chr04_bank ARG
    main_chr04 #<.bank(ARG)
.ENDMACRO

;;; Switches CHR08 banks on the main thread, setting it from the given value.
;;; The A register and the N and Z flags are destroyed in the process.
;;;
;;; This operation accepts the same arguments as main_prga.
.MACRO main_chr08 ARG1, ARG2
    _main_bank_select kSelectChr08
    _bank_data ARG1, ARG2
.ENDMACRO

;;; Switches CHR08 banks on the main thread, setting it to the bank number of
;;; the given Ppu_ChrBgj* symbol.  The A register and the N and Z flags are
;;; destroyed in the process.
.MACRO main_chr08_bank ARG
    main_chr08 #<.bank(ARG)
.ENDMACRO

;;; Switches CHR0C banks on the main thread, setting it from the given value.
;;; The A register and the N and Z flags are destroyed in the process.
;;;
;;; This operation accepts the same arguments as main_prga.
.MACRO main_chr0c ARG1, ARG2
    _main_bank_select kSelectChr0c
    _bank_data ARG1, ARG2
.ENDMACRO

;;; Switches CHR0C banks on the main thread, setting it to the bank number of
;;; the given Ppu_ChrBgj* symbol.  The A register and the N and Z flags are
;;; destroyed in the process.
.MACRO main_chr0c_bank ARG
    main_chr0c #<.bank(ARG)
.ENDMACRO

;;; Switches CHR10 banks on the main thread, setting it from the given value.
;;; The A register and the N and Z flags are destroyed in the process.
;;;
;;; This operation accepts the same arguments as main_prga.
.MACRO main_chr10 ARG1, ARG2
    _main_bank_select kSelectChr10
    _bank_data ARG1, ARG2
.ENDMACRO

;;; Switches CHR10 banks on the main thread, setting it to the bank number of
;;; the given Ppu_ChrObj* symbol.  The A register and the N and Z flags are
;;; destroyed in the process.
.MACRO main_chr10_bank ARG
    .assert .bank(ARG) .mod 2 = 0, error
    main_chr10 #<.bank(ARG)
.ENDMACRO

;;; Switches CHR18 banks on the main thread, setting it from the given value.
;;; The A register and the N and Z flags are destroyed in the process.
;;;
;;; This operation accepts the same arguments as main_prga.
.MACRO main_chr18 ARG1, ARG2
    _main_bank_select kSelectChr18
    _bank_data ARG1, ARG2
.ENDMACRO

;;; Switches CHR18 banks on the main thread, setting it to the bank number of
;;; the given Ppu_ChrObj* symbol.  The A register and the N and Z flags are
;;; destroyed in the process.
.MACRO main_chr18_bank ARG
    .assert .bank(ARG) .mod 2 = 0, error
    main_chr18 #<.bank(ARG)
.ENDMACRO

;;; Switches CHR04 banks on the IRQ thread, setting it to the bank number of
;;; the given Ppu_ChrBg* symbol.  This will automatically restore the main
;;; thread's Hw_Mmc3BankSelect_wo value afterwards.  The A register and the N
;;; and Z flags are destroyed in the process.
.MACRO irq_chr04_bank ARG
    lda #kSelectChr04
    sta Hw_Mmc3BankSelect_wo
    _bank_data #<.bank(ARG)
    lda Zp_MainSelect_bMmc3Bank
    sta Hw_Mmc3BankSelect_wo
.ENDMACRO

;;;=========================================================================;;;
