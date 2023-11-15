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

;;; State bytes for cannon machines:
;;;   * State1: The current aim angle (0 for all the way down, 255 for all the
;;;     way up).
;;;   * State2: Unused.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; The CHR bank numbers containing the diagrams for cannon machines.
kChrBankDiagramCannonLeft  = $04
kChrBankDiagramCannonRight = $04

;;; BG tile IDs for cannon machine diagrams.
kTileIdBgDiagramCannonLeftFirst  = $e0
kTileIdBgDiagramCannonRightFirst = $f0

;;; The first tile ID use for drawing cannon machines.
kTileIdObjCannonFirst = $88

;;;=========================================================================;;;
