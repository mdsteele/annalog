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

;;; State bytes for jet machines:
;;;   * State1: The jet flame power, from 0 to kJetMaxFlamePower.  This gets
;;;     set to kJetMaxFlamePower when the jet is moving; decrements when the
;;;     jet is not moving (down to kJetMaxFlamePower/2 if hovering, or down to
;;;     zero if at min/max height).
;;;   * State2: Unused.
;;;   * State3: Unused.

;;; The size of a jet machine's main platform, in pixels.
kJetPlatformWidthPx  = $20
kJetPlatformHeightPx = $0b

;;; How many pixels a jet machine moves per tick of its Y register.
.DEFINE kJetMoveInterval $30

;;; How many pixels a jet machine normally moves per frame.
kJetMoveSpeed = 3

;;; The maximum value for a jet machine's flame power stored in State1.
kJetMaxFlamePower = 24

;;; The CHR bank number containing the diagram for jet machines.
kChrBankDiagramJet = $09

;;; BG tile IDs for jet machine diagrams.
kTileIdBgDiagramJetFirst = $f0

;;; The start of OBJ tile IDs used for drawing jet machines.
kTileIdObjJetFirst = $80

;;;=========================================================================;;;
