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

;;; The number of entries in the sIrq table.  This should be set to the maximum
;;; number of times we ever want to fire an HBlank IRQ during a single frame.
.DEFINE kMaxIrqEntries 2

;;; An HBlank IRQ table.  This describes when and how many HBlank IRQs should
;;; happen during a frame, and what rendering changes to make during each one.
.STRUCT sIrq
    ;; How many scanlines to wait (from VBlank or the last IRQ) before each IRQ
    ;; should fire.  This array must be terminated with a value of $ff.
    Latch_u8_arr        .res kMaxIrqEntries + 1
    ;; The values to write to Hw_PpuMask_wo during each IRQ.  This can be used
    ;; to e.g. enable/disable OBJ rendering in the middle of a frame.
    Render_bPpuMask_arr .res kMaxIrqEntries
    ;; The PPU vertical scroll value to set during each IRQ.  The special value
    ;; $ff means "no scrolling changes"; otherwise, the (X, Y) scroll is set to
    ;; (0, this) relative to the lower nametable.
    ScrollY_u8_arr      .res kMaxIrqEntries
.ENDSTRUCT

;;;=========================================================================;;;
