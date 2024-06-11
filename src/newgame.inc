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

;;; Places that a new game can start, if using the debug cheat code.
.ENUM eNewGame
    Town      ; start at the start, for a normal new game
    Prison    ; start locked in the prison cell
    Tower     ; start just outside the garden boss room
    Breaker1  ; start in the garden boss room, just after defeating it
    Spire     ; start just outside the temple boss room
    Breaker2  ; start in the temple boss room, just after defeating it
    Rescue    ; start just inside the prison caves, on the way to rescue Alex
    Nave      ; start in the temple nave, when Alex is waiting there
    Tomb      ; start just outside the crypt boss room
    Breaker3  ; start in the crypt boss room, just after defeating it
    Spring    ; start at the hot spring, with Alex waiting there to help
    Cavern    ; start just outside the lava boss room
    Breaker4  ; start in the lava boss room, just after defeating it
    Collapse  ; start just outside the mine boss room
    Breaker5  ; start in the mine boss room, just after defeating it
    Pass      ; start at the pass between the sewer and factory
    City      ; start at the eastern edge of the city center
    Sinkhole  ; start just outside the city boss room
    Breaker6  ; start in the city boss room, just after defeating it
    Shadow    ; start at the entrance to the Shadow Labs
    Office    ; start in ShadowOffice, before tagging either ghost
    Depths    ; start just outside the shadow boss room
    Breaker7  ; start in the shadow boss room, just after defeating it
    Core      ; start just outside the final boss room
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;
