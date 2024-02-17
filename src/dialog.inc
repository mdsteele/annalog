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
;;;   * The 1-byte kDialogEntryDone constant, indicating the end of the dialog.
;;;   * The 1-byte kDialogEntryFunc constant, followed by a pointer to a
;;;     function that will return YA with a pointer to another sDialog struct.
;;;   * A 1-byte ePortrait value, followed by a 16-bit word encoding a banked
;;;     pointer to a pane of dialog text within one of the PRGA_Text? segments.
;;;     The top 3 bits of the word hold the PRGA bank number (which must be
;;;     0-7), and the bottom 13 bits of the word hold the bottom 13 bits of the
;;;     pointer (the top 3 bits of the pointer can be omitted, since they
;;;     will always be %101 given that the address is within PRGA).

;;;=========================================================================;;;

;;; Animated dialog portraits for various NPCs and devices.
.ENUM ePortrait
    AdultMan
    AdultSmith
    AdultWoman
    ChildAlex
    ChildAlexShout
    ChildBruno
    ChildBrunoShout
    ChildMarie
    ChildNora
    MermaidDaphne
    MermaidCorra
    MermaidEirene
    MermaidEireneShout
    MermaidFarmer
    MermaidFlorist
    MermaidGuardF
    MermaidPhoebe
    OrcGronta
    OrcGrontaShout
    OrcMale
    OrcMaleShout
    Paper
    Plaque
    Screen
    Sign
    NUM_VALUES
.ENDENUM

;;; Special constants used in place of an ePortrait value for doing dialog
;;; control flow.
.ASSERT $fa >= ePortrait::NUM_VALUES, error
kDialogEntryCall     = $fa  ; calls a function, then continues the sDialog
kDialogEntryFunc     = $fb  ; calls a function that returns next sDialog in YA
kDialogEntryGoto     = $fc  ; jumps to the specified sDialog
kDialogEntryQuest    = $fd  ; adds a quest marker, then continues the sDialog
kDialogEntryDone     = $fe  ; ends the dialog
kDialogEntryCutscene = $ff  ; ends the dialog and starts a new cutscene

;;;=========================================================================;;;

;;; The list of dialogs in the game.
.ENUM eDialog
    CityBuilding2Screen
    CityBuilding6Screen
    CityCenterBreakerCity1
    CityFlowerOrcAngry
    CityFlowerOrcCalm
    CityOutskirtsAlex1
    CityOutskirtsAlex2
    CoreBossGrontaDying
    CoreBossGrontaGive
    CoreBossGrontaIntro
    CoreBossScreen
    CoreLockBreakerShadow
    CoreSouthCorra1
    CoreSouthCorra2
    CryptTombPlaque
    FactoryVaultAlex
    FactoryVaultScreen
    GardenEastCorra
    GardenShrineBreakerMine1
    GardenShrineBreakerMine2
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
    PaperJerome09
    PaperJerome10
    PaperJerome11
    PaperJerome12
    PaperJerome13
    PaperJerome14
    PaperJerome15
    PaperJerome21
    PaperJerome23
    PaperJerome28
    PaperJerome34
    PaperJerome35
    PaperJerome36
    PaperManual1
    PaperManual2
    PaperManual3
    PaperManual4
    PaperManual5
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
    TownHouse4BreakerLava1
    TownHouse4BreakerLava2
    TownHouse4BreakerLava3
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
    .byte ePortrait::PORTRAIT
    .byte <LABEL
    .byte (<.bank(LABEL) << 5) | ($1f & >LABEL)
.ENDMACRO

;;; Expands to a sDialog entry that calls a function before continuing.
.MACRO dlg_Call LABEL
    .assert LABEL >= $8000, error
    .byte kDialogEntryCall
    .addr LABEL
.ENDMACRO

;;; Expands to a sDialog entry that calls a dynamic dialog function.
.MACRO dlg_Func LABEL
    .assert LABEL >= $8000, error
    .byte kDialogEntryFunc
    .addr LABEL
.ENDMACRO

;;; Expands to a sDialog entry that jumps to another sDialog entry.
.MACRO dlg_Goto LABEL
    .assert LABEL >= $8000, error
    .byte kDialogEntryGoto
    .addr LABEL
.ENDMACRO

;;; Expands to a sDialog entry that adds a quest marker before continuing.
.MACRO dlg_Quest FLAG
    .byte kDialogEntryQuest
    .byte FLAG
.ENDMACRO

;;; Expands to a sDialog entry indicating the end of the dialog.
.MACRO dlg_Done
    .byte kDialogEntryDone
.ENDMACRO

;;; Expands to a sDialog entry that ends dialog and starts a new cutscene.
.MACRO dlg_Cutscene CUTSCENE
    .byte kDialogEntryCutscene
    .byte CUTSCENE
.ENDMACRO

;;;=========================================================================;;;
