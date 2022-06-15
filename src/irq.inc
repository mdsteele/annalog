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

;;; Describes the HBlank interrupt structure for a video frame.  During each
;;; VBlank, the NMI handler will use the Latch_u8 value to set the MMC3's IRQ
;;; counter and copy FirstIrq_int_ptr to Zp_NextIrq_int_ptr.
.STRUCT sIrq
    ;; How many scanlines to wait from VBlank before the the first HBlank
    ;; interrupt should fire.
    Latch_u8         .byte
    ;; The handler interrupt function to call for the first HBlank interrupt of
    ;; the frame.  Note that this function must return with an RTI instruction.
    ;; This function must ack the IRQ and update the HBlank latch, and may
    ;; optionally update Zp_NextIrq_int_ptr.  This function should *NOT* read
    ;; any main-thread variables, to avoid data races with the main thread;
    ;; instead, it can use the parameter fields below.
    FirstIrq_int_ptr .addr
    ;; Arbitrary parameter bytes for the IRQ handler function(s) in a given
    ;; frame.  The main thread can set these up in Zp_Buffered_sIrq, and then
    ;; the handler function (running on the IRQ thread) can safely read them
    ;; from Zp_Active_sIrq without worrying about them changing mid-frame.
    Param1_byte      .byte
    Param2_byte      .byte
    Param3_byte      .byte
.ENDSTRUCT

;;;=========================================================================;;;
