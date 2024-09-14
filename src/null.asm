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
.EXPORT Data_Empty_sActor_arr := Data_Zero_u8
.ASSERT eActor::None = 0, error

;;; A music chain that contains nothing but a HALT ($00) item.
.EXPORT Data_Empty_bChain_arr := Data_Zero_u8

;;; An empty sDevice array (that is immediately terminated by eDevice::None).
.EXPORT Data_Empty_sDevice_arr := Data_Zero_u8
.ASSERT eDevice::None = 0, error

;;; A music opcode array that contains nothing but a STOP ($00) opcode.
.EXPORT Data_Empty_bMusic_arr := Data_Zero_u8

;;; A sPhrase struct that contains nothing but a DONE ($00) note.
.EXPORT Data_Empty_sPhrase := Data_Zero_u8

;;; An empty sPlatform array (that is immediately terminated by
;;; ePlatform::None).
.EXPORT Data_Empty_sPlatform_arr := Data_Zero_u8
.ASSERT ePlatform::None = 0, error

;;; A byte that is zero, which can serve as a null value for all of the above
;;; exported symbols.
.PROC Data_Zero_u8
    .byte 0
.ENDPROC

;;; An empty sDialog struct (that just immediately ends the dialog).  This can
;;; be useful for dynamic dialog functions to set as the next sDialog pointer
;;; if they want to end the conversation.
.EXPORT Data_Empty_sDialog
.PROC Data_Empty_sDialog
    dlg_Done
.ENDPROC

;;; Does nothing and returns immediately.  Can be used as a null function
;;; pointer.
.EXPORT Func_Noop
.PROC Func_Noop
    rts
.ENDPROC

;;;=========================================================================;;;
