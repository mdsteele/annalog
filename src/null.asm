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

.INCLUDE "actor.inc"
.INCLUDE "device.inc"
.INCLUDE "dialog.inc"
.INCLUDE "platform.inc"

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; An empty sActor array (that is immediately terminated by eActor::None).
.EXPORT Data_Empty_sActor_arr
.PROC Data_Empty_sActor_arr
    .assert eActor::None = 0, error
    .assert * = Data_Zero_arr2, error, "fallthrough"
.ENDPROC

;;; A music chain that contains no phrases.
.EXPORT Data_Empty_bChain_arr
.PROC Data_Empty_bChain_arr
    .assert * = Data_Zero_arr2, error, "fallthrough"
.ENDPROC

;;; An empty sDevice array (that is immediately terminated by eDevice::None).
.EXPORT Data_Empty_sDevice_arr
.PROC Data_Empty_sDevice_arr
    .assert eDevice::None = 0, error
    .assert * = Data_Zero_arr2, error, "fallthrough"
.ENDPROC

;;; An empty sDialog struct (that just immediately ends the dialog).  This can
;;; be useful for dynamic dialog functions to set as the next sDialog pointer
;;; if they want to end the conversation.
.EXPORT Data_Empty_sDialog
.PROC Data_Empty_sDialog
    .assert ePortrait::Done = $0000, error
    .assert * = Data_Zero_arr2, error, "fallthrough"
.ENDPROC

;;; A music opcode array that contains nothing but a STOP opcode.
.EXPORT Data_Empty_bMusic_arr
.PROC Data_Empty_bMusic_arr
    .assert * = Data_Zero_arr2, error, "fallthrough"
.ENDPROC

;;; A sPhrase struct that contains no notes.
.EXPORT Data_Empty_sPhrase
.PROC Data_Empty_sPhrase
    .assert * = Data_Zero_arr2, error, "fallthrough"
.ENDPROC

;;; An empty sPlatform array (that is immediately terminated by
;;; ePlatform::None).
.EXPORT Data_Empty_sPlatform_arr
.PROC Data_Empty_sPlatform_arr
    .assert ePlatform::None = 0, error
    .assert * = Data_Zero_arr2, error, "fallthrough"
.ENDPROC

;;; An array of bytes that are all zero, long enough to serve as null values
;;; for all of the above exported symbols.
.PROC Data_Zero_arr2
    .byte 0, 0
.ENDPROC

;;; Does nothing and returns immediately.  Can be used as a null function
;;; pointer.
.EXPORT Func_Noop
.PROC Func_Noop
    rts
.ENDPROC

;;;=========================================================================;;;
