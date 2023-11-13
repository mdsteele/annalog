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

;;; State bytes for winch machines:
;;;   * State1: A boolean value indicating whether the winch is currently
;;;     falling ($ff) or not falling ($00).
;;;   * State2: The lo byte of the current falling speed, measured in subpixels
;;;     per frame.
;;;   * State3: The hi byte of the current falling speed.
;;;   * State4: Unused.

;;; The size of a winch spikeball platform, in pixels.
kSpikeballWidthPx  = $0d
kSpikeballHeightPx = $0e

;;; How many times a winch load has to drop onto a breakable floor in order to
;;; destroy it.
kNumWinchHitsToBreakFloor = 3

;;; How many frames to blink the breakable floor for when resetting it.
kWinchBreakableFloorBlinkFrames = 28

;;; The CHR bank number containing the diagram for winch machines.
kChrBankDiagramWinch = $03

;;; BG tile IDs for winch machine diagrams.
kTileIdBgDiagramWinchFirst = $60

;;; Tile IDs for drawing winch machines.
kTileIdObjCrusherFirst   = $e0
kTileIdObjWeakFloorFirst = $c0
kTileIdObjWinchFirst     = $e8

;;;=========================================================================;;;
