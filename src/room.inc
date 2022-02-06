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

;;; The height of a "tall" room, in blocks.  A "short" room is
;;; kScreenHeightBlocks = 15 blocks tall, fitting vertically in the first
;;; nametable.  A "tall" room extends into the top portion of the second
;;; nametable by (kTallRoomHeightBlocks - kScreenHeightBlocks) = 9 blocks.
kTallRoomHeightBlocks = 24

kTallRoomHeightTiles = kTallRoomHeightBlocks * 2

;;; Some parts of the code assume that a room tile column fits in one byte.
;;; This puts the maximum width of a room at 8 screens, which is plenty wide.
kMaxRoomWidthTiles = $100
kMaxRoomWidthBlocks = kMaxRoomWidthTiles / 2

;;;=========================================================================;;;

;;; Stores basic information about a single room.
.STRUCT sRoom
    ;; The maximum permitted scroll X-coordinate, in pixels.  This should be
    ;; equal to (N - kScreenWidthBlocks) * kBlockWidthPx, where N is the width
    ;; of the room in blocks.
    MaxScrollX_u16            .word
    ;; True ($ff) if the room is "tall" (kTallRoomHeightBlocks blocks tall), or
    ;; false ($00) if it is short (kScreenHeightBlocks blocks tall).
    IsTall_bool               .byte
    ;; A pointer to the terrain block data for this room, which stores 1 byte
    ;; per block in column-major order.  For "short" rooms, new columns start
    ;; every 16 bytes; for "tall" rooms, new columns start every 24 bytes.
    TerrainData_ptr           .addr
    ;; The number of entries in the Machines_sMachine_arr_ptr array.  This must
    ;; be no greater than kMaxMachines.
    NumMachines_u8            .byte
    ;; A pointer to the machine data array for this room.
    Machines_sMachine_arr_ptr .addr
.ENDSTRUCT

;;;=========================================================================;;;
