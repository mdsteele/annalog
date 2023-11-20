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

;;; Defines shared room state data for the CoreElevator, FactoryElevator, and
;;; MermaidElevator rooms.
.STRUCT sElevatorState
    ;; The current state of the levers across all the elevator rooms:
    UpperJetUpperLever_u8  .byte
    UpperJetLowerLever_u8  .byte
    LowerJetUpperLever_u8  .byte
    LowerJetLowerLever_u8  .byte
    ;; State data for the jet machine from the previous elevaor room:
    PrevJetPlatformTop_i16 .word
    PrevJetStatus_eMachine .byte
    PrevJetPc_u8           .byte
    PrevJetRegA_u8         .byte
    PrevJetWait_u8         .byte
    PrevJetGoalVert_u8     .byte
.ENDSTRUCT

;;;=========================================================================;;;
