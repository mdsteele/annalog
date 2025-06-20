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

;;; State bytes for rocket ammo rack machines:
;;;   * Slowdown: Unused.
;;;   * State1: The ammo rack slot bits.  Bit N is set if there is a rocket in
;;;     slot number N.
;;;   * State2: An animation timer for restocking, which decrements each frame
;;;     when nonzero.
;;;   * State3: Unused.

;;; How many ammo slots are in an ammo rack machine.
kNumAmmoRackSlots = 3

;;; The size of an ammo rack machine's main platform, in pixels.
kAmmoRackMachineWidthPx  = $10 * kNumAmmoRackSlots
kAmmoRackMachineHeightPx = $08

;;; How many frames an ammo rack machine spends per ACT operation.
kAmmoRackActCountdown = 16

;;; The CHR bank number containing the diagram for ammorack machines.
kChrBankDiagramAmmoRack = $10

;;; BG tile IDs for ammorack machine diagrams.
kTileIdBgDiagramAmmoRackFirst = $e0

;;;=========================================================================;;;
