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

;;; State bytes for waterfall smoke:
;;;   * Flags: Unused.
;;;   * Param: The platform index for the water below.
;;;   * State1: The platform index for the water below.
;;;   * State2: The current height of the waterfall, in pixels.
;;;   * State3: Boolean; true ($ff) if this waterfall has been shut off and the
;;;     top end is now falling, false ($00) if the water is still pouring from
;;;     the pipe.
;;;   * State4: Boolean; true ($ff) if the bottom end of this waterfall has
;;;     reached the water below yet, false ($00) if not.

;;;=========================================================================;;;
