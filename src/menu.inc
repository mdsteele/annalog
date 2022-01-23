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

;;; The maximum number of selectable items in a menu.
.DEFINE kMaxMenuItems 16

;;;=========================================================================;;;

;;; Represents static data about a console instruction field editing menu.
.STRUCT sMenu
    ;; The (width - 1) of each menu item, in tiles.
    WidthsMinusOne_u8_arr   .res kMaxMenuItems
    ;; Pointers to the label string for each menu item.  Each string is assumed
    ;; to have length equal to the corresponding value in Widths_u8_arr.
    Labels_u8_arr_ptr_arr   .res kMaxMenuItems * 2
    ;; Pointers to the functions to be called when the player presses various
    ;; directions on the D-pad; each function should update Zp_MenuItem_u8
    ;; appropriately based on the menu layout.
    OnUp_func_ptr           .res 2
    OnDown_func_ptr         .res 2
    OnLeft_func_ptr         .res 2
    OnRight_func_ptr        .res 2
.ENDSTRUCT

;;;=========================================================================;;;
