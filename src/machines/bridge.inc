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

;;; State bytes for bridge machines:
;;;   * State1: The current bridge angle, from 0 for all the way down, to
;;;     kBridgeMaxAngle for all the way up.
;;;   * State2: Unused.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; The maximum permitted value for the bridge angle (which is stored in
;;; State1).
kBridgeMaxAngle = $10

;;; How many frames the bridge machine spends per move operation.
kBridgeMoveUpCountdown = kBridgeMaxAngle + $20
kBridgeMoveDownCountdown = kBridgeMaxAngle / 2

;;; The CHR bank numbers containing the diagrams for bridge machines.
kChrBankDiagramBridgeRight = $0a
kChrBankDiagramBridgeLeft  = $0b

;;; BG tile IDs for bridge machine diagrams.
kTileIdBgDiagramBridgeRightFirst = $60
kTileIdBgDiagramBridgeLeftFirst  = $60

;;;=========================================================================;;;
