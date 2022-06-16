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

.INCLUDE "joypad.inc"

;;;=========================================================================;;;

.ZEROPAGE

;;; A bitfield indicating which player 1 buttons are currently being held.
.EXPORTZP Zp_P1ButtonsHeld_bJoypad
Zp_P1ButtonsHeld_bJoypad: .res 1

;;; A bitfield indicating which player 1 buttons have been newly pressed since
;;; the previous call to Func_ReadJoypad.
.EXPORTZP Zp_P1ButtonsPressed_bJoypad
Zp_P1ButtonsPressed_bJoypad: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Helper function for Func_ReadJoypad.  Reads buttons from the joypad and
;;; populates Zp_P1ButtonsHeld_bJoypad.
;;; @preserve X, Y
.PROC Func_ReadJoypadOnce
    ;; This function's code comes almost directly from
    ;; https://wiki.nesdev.org/w/index.php/Controller_reading_code.
    lda #1
    ;; While the strobe bit is set, buttons will be continuously reloaded.
    ;; This means that reading from Hw_Joypad1_rw will only return the state of
    ;; the first button: button A.
    sta Hw_Joypad1_rw
    sta Zp_P1ButtonsHeld_bJoypad  ; Initialize with a 1 bit, to be used later.
    lsr a  ; now A is 0
    ;; By storing 0 into Hw_Joypad1_rw, the strobe bit is cleared and the
    ;; reloading stops.  This allows all 8 buttons (newly reloaded) to be read
    ;; from Hw_Joypad1_rw.
    sta Hw_Joypad1_rw
    @loop:
    lda Hw_Joypad1_rw
    lsr a                         ; bit 0 -> Carry
    rol Zp_P1ButtonsHeld_bJoypad  ; Carry -> bit 0; bit 7 -> Carry
    bcc @loop  ; Stop when the initial 1 bit is finally shifted into Carry.
    rts
.ENDPROC

;;; Reads buttons from joypad and populates Zp_P1ButtonsHeld_bJoypad and
;;; Zp_P1ButtonsPressed_bJoypad.
.EXPORT Func_ReadJoypad
.PROC Func_ReadJoypad
    ;; Store the buttons *not* held last frame in Y.
    lda Zp_P1ButtonsHeld_bJoypad
    eor #$ff
    tay
    ;; Apparently, when using APU DMC playback, controller reading will
    ;; sometimes glitch.  One standard workaround (used by e.g. Super Mario
    ;; Bros. 3) is to read the controller repeatedly until you get the same
    ;; result twice in a row.  This part of the code is adapted from
    ;; https://wiki.nesdev.org/w/index.php/Controller_reading_code.
    jsr Func_ReadJoypadOnce  ; preserves X and Y
    @rereadLoop:
    ldx Zp_P1ButtonsHeld_bJoypad
    jsr Func_ReadJoypadOnce  ; preserves X and Y
    cpx Zp_P1ButtonsHeld_bJoypad
    bne @rereadLoop
    ;; Now that we have a reliable value for Zp_P1ButtonsHeld_bJoypad, we can
    ;; set Zp_P1ButtonsPressed_bJoypad to the buttons that are newly held this
    ;; frame.
    tya
    and Zp_P1ButtonsHeld_bJoypad
    sta Zp_P1ButtonsPressed_bJoypad
    rts
.ENDPROC

;;;=========================================================================;;;
