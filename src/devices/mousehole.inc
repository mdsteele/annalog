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

;;; Flag bits for a mousehole device.
.SCOPE bMousehole
    OnRight   = %10000000  ; if set, hole is on the right tile
    OnLeft    = %01000000  ; if set, hole is on the left tile
    RunLeft   = %00000010  ; if set, rodent can run left when exiting the hole
    RunRight  = %00000001  ; if set, rodent can run right when exiting the hole
    RunEither = %00000011  ; if set, rodent can run either direction
.ENDSCOPE
.LINECONT +
.ASSERT bMousehole::RunEither = bMousehole::RunLeft | bMousehole::RunRight, \
        error
.LINECONT -

;;;=========================================================================;;;
