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

.INCLUDE "room.inc"

;;;=========================================================================;;;

.SEGMENT "PRGC_Room"

DataC_ShortRoomTerrain_arr:
:   .incbin "out/data/short.room"
    .assert * - :- = 16 * 16, error

DataC_TallRoomTerrain_arr:
:   .incbin "out/data/tall.room"
    .assert * - :- = 35 * 24, error

.EXPORT DataC_TallRoom_sRoom
DataC_TallRoom_sRoom:
:   .assert * - :- = sRoom::MaxScrollX_u16, error
    .word $130
    .assert * - :- = sRoom::IsTall_bool, error
    .byte $ff
    .assert * - :- = sRoom::TerrainData_ptr, error
    .addr DataC_TallRoomTerrain_arr
    .assert * - :- = .sizeof(sRoom), error

;;;=========================================================================;;;
