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

;; The height of a "tall" room, in blocks.  A "short" room is
;; kScreenHeightBlocks = 15 blocks tall, fitting vertically in the first
;; nametable.  A "tall" room extends into the top portion of the second
;; nametable by (kTallRoomHeightBlocks - kScreenHeightBlocks) = 9 blocks.
kTallRoomHeightBlocks = 24

;;;=========================================================================;;;

;; Stores basic information about a single room.
.STRUCT sRoom
    ;; The width of the room, in blocks.  This should never be less than
    ;; kScreenWidthBlocks = 16.
    WidthBlocks_u8  .byte
    ;; True ($ff) if the room is "tall" (kTallRoomHeightBlocks blocks tall), or
    ;; false ($00) if it is short (kScreenHeightBlocks blocks tall).
    IsTall_bool     .byte
    ;; A pointer to the terrain block data for this room, which stores 1 byte
    ;; per block in column-major order.  For "short" rooms, new columns start
    ;; every 16 bytes; for "tall" rooms, new columns start every 24 bytes.
    TerrainData_ptr .addr
.ENDSTRUCT

;;;=========================================================================;;;
