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

;;; State bytes for multiplexer machines:
;;;   * Slowdown: Unused.
;;;   * State1: The value of the J register (0-9).
;;;   * State2: The platform index of the selected platform.
;;;   * State3: Unused.

;;; The CHR bank numbers containing the diagrams for multiplexer machines.
kChrBankDiagramMultiplexerPlatform = $14
kChrBankDiagramMultiplexerValve    = $14

;;; BG tile IDs for multiplexer machine diagrams.
kTileIdBgDiagramMultiplexerPlatformFirst = $e0
kTileIdBgDiagramMultiplexerValveFirst    = $f0

;;; Various OBJ tile IDs used for drawing multiplexer machines.
kTileIdObjMultiplexerFirst = $82

;;;=========================================================================;;;
