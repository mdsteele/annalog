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

;;; See https://www.nesdev.org/wiki/APU

;;;=========================================================================;;;

;;; The number of audio channels in the APU.
kNumApuChannels = 5

;;; Hardware registers for a given APU channel.  Each register means different
;;; things for each channel, but the purposes are similar enough between
;;; channels that some code can use this struct to treat channels generically.
.STRUCT sChanRegs
    ;; * For the pulse channels, this controls the volume envelope and also the
    ;;   duty cycle.
    ;; * For the triangle channel, this controls whether the channel is on.
    ;; * For the noise channel, this controls the volume envelope.
    ;; * For the DMC channel, this controls the sample rate.
    Envelope_wo .byte
    ;; * For the pulse channels, this controls frequency sweep.
    ;; * For the triangle and noise channels, this is unused.
    ;; * For the DMC channel, this is used to directly load PCM samples.
    Sweep_wo    .byte
    ;; * For the pulse and triangle channels, this controls the low bits of the
    ;;   tone frequency.
    ;; * For the noise channel, this controls the noise period.
    ;; * For the DMC channel, this controls the sample address.
    TimerLo_wo  .byte
    ;; * For the pulse and triangle channels, this controls the high bits of
    ;;   the tone frequency, as well as the length counter.
    ;; * For the noise channel, this controls the length counter.
    ;; * For the DMC channel, this controls the sample length.
    TimerHi_wo  .byte
.ENDSTRUCT

;;; Hardware registers for each APU channel.
Hw_Channels_sChanRegs_arr5 = $4000

;;;=========================================================================;;;

;;; DMC channel flags and rate (https://www.nesdev.org/wiki/APU_DMC)
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

;;; APU Frame Counter (https://www.nesdev.org/wiki/APU_Frame_Counter)
Hw_ApuCount_wo = $4017

.SCOPE bApuCount
    Seq5Step   = %10000000
    DisableIrq = %01000000  ; if set, frame counter IRQs will not be generated
.ENDSCOPE

;;;=========================================================================;;;
