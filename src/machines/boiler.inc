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

;;; State bytes for boiler machines:
;;;   * Slowdown: Set whenever the boiler ACTs.  While nonzero, draws the
;;;     boiler's ignition flame, and blinks the input side of the valve.
;;;   * State1: The current angle of the valve, which tends toward
;;;     MachineGoalHorz * kBoilerValveAnimSlowdown.
;;;   * State2: Unused.
;;;   * State3: Unused.

;;; The number of frames between valve angles when animating a boiler valve.
.DEFINE kBoilerValveAnimSlowdown 4

;;; The CHR bank number containing the diagram for boiler machines.
kChrBankDiagramBoiler = $0e

;;; BG tile IDs for boiler machine diagrams.
kTileIdBgDiagramBoilerFirst = $e0

;;; Various OBJ tile IDs used for drawing boiler machines.
kTileIdObjBoilerFlameFirst = $8c
kTileIdObjValveFirst       = $b0

;;; Parameter values for FuncA_Objects_DrawBoilerValve and
;;; FuncA_Objects_DrawValveShape to indicate where on the valve the input is
;;; coming from.
.ENUM eValveInput
    RightHalfOfTopEdge    =   1
    TopHalfOfRightEdge    =   3
    BottomHalfOfRightEdge =   5
    RightHalfOfBottomEdge =   7
    LeftHalfOfBottomEdge  =   9
    BottomHalfOfLeftEdge  =  11
    TopHalfOfLeftEdge     =  13
    LeftHalfOfTopEdge     =  15
    BothSides             = $40
    None                  = $80
.ENDENUM

;;;=========================================================================;;;
