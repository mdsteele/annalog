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

;;; A sDialog struct is a variable-length sequence of one or more entries,
;;; terminated by a zero byte.  Each entry consists of a 2-byte ePortrait value
;;; followed by one window's worth of text, with the text terminated by a
;;; kDialogTextEnd byte.

;;;=========================================================================;;;

;;; A pair of CHR04 bank numbers; the lo byte is the bank number to use when
;;; dialog is paused, and the hi byte is the bank number to alternate with the
;;; first to animate the portrait while text is being written.
.ENUM ePortrait
    Woman = $0201
    Sign =  $0303
.ENDENUM

;;;=========================================================================;;;

;;; Special characters in dialog text indicating linebreaks and end-of-text.
kDialogTextNewline = $fe
kDialogTextEnd     = $ff
.CHARMAP $24, kDialogTextNewline  ; '$'
.CHARMAP $23, kDialogTextEnd      ; '#'

;;;=========================================================================;;;
