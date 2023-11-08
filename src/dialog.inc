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

;;; A sDialog struct is a variable-length sequence of one or more entries, with
;;; each entry consisting of one of the following:
;;;   * The 2-byte ePortrait::Done constant, indicating the end of the dialog.
;;;   * Any other 2-byte ePortrait value followed by one window's worth of
;;;     text, with the text terminated by a kDialogTextEnd byte.
;;;   * A pointer to a function (which must be within PRG ROM) that will return
;;;     YA with a pointer to another sDialog struct.

;;;=========================================================================;;;

;;; A pair of CHR04 bank numbers; the lo byte is the bank number to use when
;;; dialog is paused, and the hi byte is the bank number to alternate with the
;;; first to animate the portrait while text is being written.
.ENUM ePortrait
    Done               = $0000  ; indicates end of dialog
    AdultMan           = $0807  ; same portrait as MermaidFarmer
    AdultWoman         = $0201
    ChildAlex          = $0c0b
    ChildAlexShout     = $0b0c
    ChildBruno         = $1413
    ChildBrunoShout    = $1314
    ChildMarie         = $1211
    ChildNora          = $0a09  ; same portrait as MermaidPhoebe
    MermaidDaphne      = $0605  ; same portrait as MermaidGuardF
    MermaidCorra       = $0e0d
    MermaidEirene      = $1c1b
    MermaidEireneShout = $1b1c
    MermaidFarmer      = $0807  ; same portrait as AdultMan
    MermaidFlorist     = $100f
    MermaidGuardF      = $0605  ; same portrait as MermaidDaphne
    MermaidPhoebe      = $0a09  ; same portrait as ChildNora
    OrcGronta          = $1716
    OrcGrontaShout     = $1617
    OrcMale            = $1918
    OrcMaleShout       = $1819
    Paper              = $0404
    Plaque             = $1515
    Screen             = $1a1a
    Sign               = $0303
.ENDENUM

;;;=========================================================================;;;

;;; The list of dialogs in the game.
.ENUM eDialog
    CityBuilding2Screen
    CityBuilding6Screen
    CityFlowerOrcAngry
    CityFlowerOrcCalm
    CityOutskirtsAlex1
    CityOutskirtsAlex2
    CoreBossGrontaGive
    CoreBossGrontaIntro
    CoreSouthCorra1
    CoreSouthCorra2
    CryptTombPlaque
    FactoryVaultAlex
    FactoryVaultScreen
    GardenEastCorra
    MermaidEntrySign
    MermaidHut1AlexPetition
    MermaidHut1BreakerCrypt1
    MermaidHut1BreakerCrypt2
    MermaidHut1BreakerGarden
    MermaidHut1Guard
    MermaidHut1Queen
    MermaidHut2Guard
    MermaidHut3Daphne
    MermaidHut3Phoebe
    MermaidHut4Florist
    MermaidHut5Marie
    MermaidHut5Nora
    MermaidSpringAlex1
    MermaidSpringAlex2
    MermaidSpringSign
    MermaidVillageAlex
    MermaidVillageBruno
    MermaidVillageCorra
    MermaidVillageFarmer
    MermaidVillageGuard
    PaperJerome01
    PaperJerome08
    PaperJerome10
    PaperJerome11
    PaperJerome12
    PaperJerome13
    PaperJerome21
    PaperJerome28
    PaperJerome34
    PaperJerome35
    PaperJerome36
    PaperManual2
    PaperManual3
    PaperManual4
    PrisonFlowerSign
    PrisonUpperAlexCell
    PrisonUpperAlexFree
    PrisonUpperAlexLast
    PrisonUpperBreakerTemple1
    PrisonUpperBreakerTemple2
    PrisonUpperBruno
    PrisonUpperMarie
    PrisonUpperNora
    ShadowGateScreen
    ShadowTeleportScreen
    TempleAltarPlaque
    TempleEntryCorraHi
    TempleEntryCorraWait
    TempleEntryGuard
    TempleNaveAlexBoost1
    TempleNaveAlexBoost2
    TempleNaveAlexStand
    TownHouse1Nora
    TownHouse2Stela
    TownHouse3Smith
    TownHouse4Laura
    TownHouse4Martin
    TownHouse5Bruno
    TownHouse5Marie
    TownHouse6Elder
    TownOutdoorsAlex1
    TownOutdoorsAlex2
    TownOutdoorsAlex3
    TownOutdoorsGronta
    TownOutdoorsIvan
    TownOutdoorsSandra
    TownOutdoorsSign
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; Special characters in dialog text indicating linebreaks, end-of-text, and
;;; end-of-text-with-a-yes-or-no-question.
kDialogTextNewline = $fd
kDialogTextEnd     = $fe
kDialogTextYesNo   = $ff
.CHARMAP $24, kDialogTextNewline  ; '$'
.CHARMAP $23, kDialogTextEnd      ; '#'
.CHARMAP $25, kDialogTextYesNo    ; '%'

;;;=========================================================================;;;

;;; Expands to a sDialog entry that displays a pane of text.
.MACRO dlg_Text PORTRAIT, LABEL
    .assert LABEL >= $a000 && LABEL < $c000, error
    .assert .bank(LABEL) < 8, error
    .word ePortrait::PORTRAIT
    .byte <LABEL
    .byte (<.bank(LABEL) << 5) | ($1f & >LABEL)
.ENDMACRO

;;; Expands to a sDialog entry that calls a dynamic dialog function.
.MACRO dlg_Func LABEL
    .assert LABEL >= $8000, error
    .addr LABEL
.ENDMACRO

;;; Expands to a sDialog entry indicating the end of the dialog.
.MACRO dlg_Done
    .word ePortrait::Done
.ENDMACRO

;;;=========================================================================;;;
