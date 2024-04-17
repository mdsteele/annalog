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

;;; The CHR bank number containing the diagram for the machine debugger.
kChrBankDiagramDebugger = $01

;;; OBJ tile IDs used for drawing many different kinds of machines.
kTileIdObjMachineCorner      = $70
kTileIdObjMachineSurfaceHorz = $6d
kTileIdObjMachineSurfaceVert = $6e
kTileIdObjMachineLightOff    = $7a
kTileIdObjMachineLightOn     = $7b

;;; The OBJ palette number used for the blinking error light on machines.
kPaletteObjMachineLight = 1

;;;=========================================================================;;;
