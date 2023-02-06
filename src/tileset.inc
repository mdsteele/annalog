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

;;; A terrain tileset, which specifies how to interpret terrain block data for
;;; a room.
.STRUCT sTileset
    ;; Pointers to arrays mapping from terrain block types to the BG tile IDs
    ;; for each quadrant of the block.  The arrays themselves should reside in
    ;; the PRGA_Terrain segment.
    UpperLeft_u8_arr_ptr  .addr
    LowerLeft_u8_arr_ptr  .addr
    UpperRight_u8_arr_ptr .addr
    LowerRight_u8_arr_ptr .addr
    ;; The default CHR08 bank number to set when using this tileset.  A room's
    ;; Enter_func_ptr can modify this in Zp_Current_sTileset to override the
    ;; default.
    Chr08Bank_u8          .byte
.ENDSTRUCT

;;;=========================================================================;;;
