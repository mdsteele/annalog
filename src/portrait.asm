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

.INCLUDE "dialog.inc"
.INCLUDE "macros.inc"
.INCLUDE "portrait.inc"

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Maps from an ePortrait value to the CHR04 bank to set when that dialog
;;; portrait is at rest.
.EXPORT DataA_Dialog_PortraitRestBank_u8_arr
.PROC DataA_Dialog_PortraitRestBank_u8_arr
    D_ARRAY .enum, ePortrait
    d_byte AdultAlexHand,      kChrBankPortraitAlexHand
    d_byte AdultAlexHappy,     kChrBankPortraitAlex3Rest
    d_byte AdultAlexSad,       kChrBankPortraitAlex2Rest
    d_byte AdultAlexShout,     kChrBankPortraitAlex3Talk
    d_byte AdultBoris,         kChrBankPortraitBorisRest
    d_byte AdultElder,         kChrBankPortraitElderRest
    d_byte AdultJerome,        kChrBankPortraitJeromeRest
    d_byte AdultMan,           kChrBankPortraitManRest
    d_byte AdultSmith,         kChrBankPortraitManRest
    d_byte AdultWoman,         kChrBankPortraitWomanRest
    d_byte AdultWomanShout,    kChrBankPortraitWomanTalk
    d_byte ChildAlex,          kChrBankPortraitAlexRest
    d_byte ChildAlexHand,      kChrBankPortraitAlexHand
    d_byte ChildAlexShout,     kChrBankPortraitAlexTalk
    d_byte ChildBruno,         kChrBankPortraitBrunoRest
    d_byte ChildBrunoShout,    kChrBankPortraitBrunoTalk
    d_byte ChildMarie,         kChrBankPortraitMarieRest
    d_byte ChildNora,          kChrBankPortraitNoraRest
    d_byte MermaidCorra,       kChrBankPortraitCorraRest
    d_byte MermaidDaphne,      kChrBankPortraitMermaidRest
    d_byte MermaidEirene,      kChrBankPortraitEireneRest
    d_byte MermaidEireneShout, kChrBankPortraitEireneTalk
    d_byte MermaidEireneSigh,  kChrBankPortraitEirene2Rest
    d_byte MermaidFarmer,      kChrBankPortraitFarmerRest
    d_byte MermaidFlorist,     kChrBankPortraitFloristRest
    d_byte MermaidGuardF,      kChrBankPortraitMermaidRest
    d_byte MermaidGuardM,      kChrBankPortraitFarmerRest
    d_byte MermaidGuardMShout, kChrBankPortraitFarmerTalk
    d_byte MermaidPhoebe,      kChrBankPortraitNoraRest
    d_byte OrcGronta,          kChrBankPortraitGrontaRest
    d_byte OrcGrontaShout,     kChrBankPortraitGrontaTalk
    d_byte OrcMale,            kChrBankPortraitOrcRest
    d_byte OrcMaleShout,       kChrBankPortraitOrcTalk
    d_byte PaperJerome,        kChrBankPortraitPaperJerome
    d_byte PaperManual,        kChrBankPortraitPaperManual
    d_byte Plaque,             kChrBankPortraitPlaque
    d_byte Screen,             kChrBankPortraitScreen
    d_byte Sign,               kChrBankPortraitSign
    D_END
.ENDPROC

;;; Maps from an ePortrait value to the CHR04 bank to alternate with the rest
;;; bank above to animate the portrait while text is being written.
.EXPORT DataA_Dialog_PortraitAnimBank_u8_arr
.PROC DataA_Dialog_PortraitAnimBank_u8_arr
    D_ARRAY .enum, ePortrait
    d_byte AdultAlexHand,      kChrBankPortraitAlexHand
    d_byte AdultAlexHappy,     kChrBankPortraitAlex3Talk
    d_byte AdultAlexSad,       kChrBankPortraitAlex2Talk
    d_byte AdultAlexShout,     kChrBankPortraitAlex3Rest
    d_byte AdultBoris,         kChrBankPortraitBorisTalk
    d_byte AdultElder,         kChrBankPortraitElderTalk
    d_byte AdultJerome,        kChrBankPortraitJeromeTalk
    d_byte AdultMan,           kChrBankPortraitManTalk
    d_byte AdultSmith,         kChrBankPortraitManTalk
    d_byte AdultWoman,         kChrBankPortraitWomanTalk
    d_byte AdultWomanShout,    kChrBankPortraitWomanRest
    d_byte ChildAlex,          kChrBankPortraitAlexTalk
    d_byte ChildAlexHand,      kChrBankPortraitAlexHand
    d_byte ChildAlexShout,     kChrBankPortraitAlexRest
    d_byte ChildBruno,         kChrBankPortraitBrunoTalk
    d_byte ChildBrunoShout,    kChrBankPortraitBrunoRest
    d_byte ChildMarie,         kChrBankPortraitMarieTalk
    d_byte ChildNora,          kChrBankPortraitNoraTalk
    d_byte MermaidCorra,       kChrBankPortraitCorraTalk
    d_byte MermaidDaphne,      kChrBankPortraitMermaidTalk
    d_byte MermaidEirene,      kChrBankPortraitEireneTalk
    d_byte MermaidEireneShout, kChrBankPortraitEireneRest
    d_byte MermaidEireneSigh,  kChrBankPortraitEirene2Talk
    d_byte MermaidFarmer,      kChrBankPortraitFarmerTalk
    d_byte MermaidFlorist,     kChrBankPortraitFloristTalk
    d_byte MermaidGuardF,      kChrBankPortraitMermaidTalk
    d_byte MermaidGuardM,      kChrBankPortraitFarmerTalk
    d_byte MermaidGuardMShout, kChrBankPortraitFarmerRest
    d_byte MermaidPhoebe,      kChrBankPortraitNoraTalk
    d_byte OrcGronta,          kChrBankPortraitGrontaTalk
    d_byte OrcGrontaShout,     kChrBankPortraitGrontaRest
    d_byte OrcMale,            kChrBankPortraitOrcTalk
    d_byte OrcMaleShout,       kChrBankPortraitOrcRest
    d_byte PaperJerome,        kChrBankPortraitPaperJerome
    d_byte PaperManual,        kChrBankPortraitPaperManual
    d_byte Plaque,             kChrBankPortraitPlaque
    d_byte Screen,             kChrBankPortraitScreen
    d_byte Sign,               kChrBankPortraitSign
    D_END
.ENDPROC

;;; Maps from an ePortrait to the first BG tile ID for that portrait.
.EXPORT DataA_Dialog_PortraitFirstTileId_u8_arr
.PROC DataA_Dialog_PortraitFirstTileId_u8_arr
    D_ARRAY .enum, ePortrait
    d_byte AdultAlexHand,      kTileIdBgPortraitAlexFirst
    d_byte AdultAlexHappy,     kTileIdBgPortraitAlexFirst
    d_byte AdultAlexSad,       kTileIdBgPortraitAlexFirst
    d_byte AdultAlexShout,     kTileIdBgPortraitAlexFirst
    d_byte AdultBoris,         kTileIdBgPortraitBorisFirst
    d_byte AdultElder,         kTileIdBgPortraitElderFirst
    d_byte AdultJerome,        kTileIdBgPortraitJeromeFirst
    d_byte AdultMan,           kTileIdBgPortraitManFirst
    d_byte AdultSmith,         kTileIdBgPortraitManFirst
    d_byte AdultWoman,         kTileIdBgPortraitWomanFirst
    d_byte AdultWomanShout,    kTileIdBgPortraitWomanFirst
    d_byte ChildAlex,          kTileIdBgPortraitAlexFirst
    d_byte ChildAlexHand,      kTileIdBgPortraitAlexFirst
    d_byte ChildAlexShout,     kTileIdBgPortraitAlexFirst
    d_byte ChildBruno,         kTileIdBgPortraitBrunoFirst
    d_byte ChildBrunoShout,    kTileIdBgPortraitBrunoFirst
    d_byte ChildMarie,         kTileIdBgPortraitMarieFirst
    d_byte ChildNora,          kTileIdBgPortraitNoraFirst
    d_byte MermaidCorra,       kTileIdBgPortraitCorraFirst
    d_byte MermaidDaphne,      kTileIdBgPortraitMermaidFirst
    d_byte MermaidEirene,      kTileIdBgPortraitEireneFirst
    d_byte MermaidEireneShout, kTileIdBgPortraitEireneFirst
    d_byte MermaidEireneSigh,  kTileIdBgPortraitEireneFirst
    d_byte MermaidFarmer,      kTileIdBgPortraitFarmerFirst
    d_byte MermaidFlorist,     kTileIdBgPortraitFloristFirst
    d_byte MermaidGuardF,      kTileIdBgPortraitMermaidFirst
    d_byte MermaidGuardM,      kTileIdBgPortraitFarmerFirst
    d_byte MermaidGuardMShout, kTileIdBgPortraitFarmerFirst
    d_byte MermaidPhoebe,      kTileIdBgPortraitNoraFirst
    d_byte OrcGronta,          kTileIdBgPortraitGrontaFirst
    d_byte OrcGrontaShout,     kTileIdBgPortraitGrontaFirst
    d_byte OrcMale,            kTileIdBgPortraitOrcFirst
    d_byte OrcMaleShout,       kTileIdBgPortraitOrcFirst
    d_byte PaperJerome,        kTileIdBgPortraitPaperFirst
    d_byte PaperManual,        kTileIdBgPortraitPaperFirst
    d_byte Plaque,             kTileIdBgPortraitPlaqueFirst
    d_byte Screen,             kTileIdBgPortraitScreenFirst
    d_byte Sign,               kTileIdBgPortraitSignFirst
    D_END
.ENDPROC

;;;=========================================================================;;;
