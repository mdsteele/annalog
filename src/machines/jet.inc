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
;;;   * State1: Unused.
;;;   * State2: Unused.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; The size of a jet machine's main platform, in pixels.
kJetPlatformWidthPx  = $20
kJetPlatformHeightPx = $0b

;;; How many pixels a jet machine moves per tick of its Y register.
.DEFINE kJetMoveInterval $30

;;; How many pixels a jet machine normally moves per frame.
kJetMoveSpeed = 3

;;; The CHR bank number containing the diagram for jet machines.
kChrBankDiagramJet = $06

;;; BG tile IDs for jet machine diagrams.
kTileIdBgDiagramJetFirst = $60

;;; The start of OBJ tile IDs used for drawing jet machines.
kTileIdObjJetFirst = $82

;;;=========================================================================;;;
