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

;;; State bytes for field machines:
;;;   * State1: The number of frames the field machine has been charging for
;;;     since it was last reset or discharged.
;;;   * State2: Unused.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; The size, in pixels, of a teleport field machine's primary platform.
kFieldMachineWidth = $10
kFieldMachineHeight = $10

;;; The width, in pixels, of a teleport field machine's teleportation field.
kTeleportFieldWidth = $40

;;;=========================================================================;;;
