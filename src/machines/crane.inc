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

;;; State bytes for crane machines:
;;;   * State1: Unused.
;;;   * State2: Unused.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; How many frames the crane machine spends per act operation.
kCraneActCooldown = 8

;;; The CHR bank numbers containing the diagrams for crane/trolley machines.
kChrBankDiagramCrane   = $0c
kChrBankDiagramTrolley = $02

;;; BG tile IDs for crane/trolley machine diagrams.
kTileIdBgDiagramCraneFirst   = $60
kTileIdBgDiagramTrolleyFirst = $60

;;; Various OBJ tile IDs used for drawing crane/trolley machines.
kTileIdObjCraneFirst = $b0

;;;=========================================================================;;;
