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

;;; See https://wiki.nesdev.org/w/index.php/APU

;;;=========================================================================;;;

;;; DMC channel flags and rate (https://wiki.nesdev.org/w/index.php/APU_DMC)
Hw_DmcFlags_wo = $4010

.SCOPE bDmcFlags
    EnableIrq = %10000000  ; if set, generate IRQ when sample finishes
    Loop      = %01000000  ; if set, loop the sample
    RateMask  = %00001111  ; bits used to specify sample rate
.ENDSCOPE

;;; Encoded address of the delta modulated sample to play.  The actual address
;;; used will be ($c000 + 64 * this).
Hw_DmcSampleStart_wo = $4012

;;; Length of the delta modulated sample to play.  The actual length used will
;;; be (1 + 16 * this).
Hw_DmcSampleLength_wo = $4013

;;;=========================================================================;;;

Hw_ApuStatus_rw = $4015

.SCOPE bApuStatus
    DmcInterrupt   = %10000000
    FrameInterrupt = %01000000
    Dmc            = %00010000
    Noise          = %00001000
    Triangle       = %00000100
    Pulse2         = %00000010
    Pulse1         = %00000001
.ENDSCOPE

;;; APU Frame Counter (https://wiki.nesdev.org/w/index.php/APU_Frame_Counter)
Hw_ApuCount_wo = $4017

.SCOPE bApuCount
    Seq5Step   = %10000000
    DisableIrq = %01000000  ; if set, frame counter IRQs will not be generated
.ENDSCOPE

;;;=========================================================================;;;
