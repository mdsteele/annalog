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

;;; A sDialog struct is a variable-length sequence of one or more entries, with
;;; each entry consisting of one of the following:
;;;   * The 2-byte ePortrait::Done constant, indicating the end of the dialog.
;;;   * Any other 2-byte ePortrait value followed by one window's worth of
;;;     text, with the text terminated by a kDialogTextEnd byte.
;;;   * A pointer to a function (which must be within PRG ROM) that will return
;;;     YA with a pointer to another sDialog struct.

;;;=========================================================================;;;

;;; A pair of CHR04 bank numbers; the lo byte is the bank number to use when
;;; dialog is paused, and the hi byte is the bank number to alternate with the
;;; first to animate the portrait while text is being written.
.ENUM ePortrait
    Done         = $0000  ; indicates end of dialog
    Woman        = $0201
    Sign         = $0303
    Paper        = $0404
    Mermaid      = $0605
    Man          = $0807
    ChildNora    = $0a09  ; same portrait as MermaidGirl
    MermaidGirl  = $0a09  ; same portrait as ChildNora
    Alex         = $0c0b
    MermaidYouth = $0e0d
    Florist      = $100f
    ChildMarie   = $1211
    ChildBruno   = $1413
.ENDENUM

;;;=========================================================================;;;

;;; Special characters in dialog text indicating linebreaks, end-of-text, and
;;; end-of-text-with-a-yes-or-no-question.
kDialogTextNewline = $fd
kDialogTextEnd     = $fe
kDialogTextYesNo   = $ff
.CHARMAP $24, kDialogTextNewline  ; '$'
.CHARMAP $23, kDialogTextEnd      ; '#'
.CHARMAP $25, kDialogTextYesNo    ; '%'

;;;=========================================================================;;;
