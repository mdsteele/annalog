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

.SCOPE bEnvelope
    DutyMask = %11000000  ; bits used to specify pulse duty cycle
    Duty18   = %00000000  ; 1/8 pulse duty cycle
    Duty14   = %01000000  ; 1/4 pulse duty cycle
    Duty12   = %10000000  ; 1/2 pulse duty cycle
    Duty34   = %11000000  ; 3/4 pulse duty cycle
    NoLength = %00100000  ; if set, length counter is halted
    ConstVol = %00010000  ; if set, volume is constant
    VolMask  = %00001111  ; bits used for volume
.ENDSCOPE

;;;=========================================================================;;;

;;; Constructs a frequency sweep byte for a pulse channel from a shift value
;;; (which must range from -7 to 7) and a period value (which must range from 0
;;; to 7).
.LINECONT +
.DEFINE pulse_sweep(SHIFT, PERIOD) (((SHIFT) <> 0) * \
    ($80 | ((PERIOD) << 4) | \
     (((SHIFT) < 0) * ($0f & (SHIFT)) + \
      ((SHIFT) > 0) * (8 - (SHIFT)))))
.LINECONT -

;;;=========================================================================;;;

;;; Volume envelope control for the noise channel.
Hw_NoiseEnvelope_wo = $400c

;;; Controls the noise channel period (in the bottom four bits).  In addition,
;;; setting the highest bit makes the noise sound more metallic.
Hw_NoisePeriod_wo = $400e

;;; Controls length counter for the noise channel (in the upper five bits).
Hw_NoiseLength_wo = $400f

;;;=========================================================================;;;

;;; Delta modulated sample data for the DMC must be aligned to this many bytes.
kDmcSampleAlign = $40

;;; DMC channel flags and rate (https://www.nesdev.org/wiki/APU_DMC)
Hw_DmcFlags_wo = $4010

.SCOPE bDmcFlags
    EnableIrq = %10000000  ; if set, generate IRQ when sample finishes
    Loop      = %01000000  ; if set, loop the sample
    RateMask  = %00001111  ; bits used to specify sample rate
.ENDSCOPE

;;; Write here to directly set the output level of the DMC (0-127).
Hw_DmcLevel_wo = $4011

;;; Encoded address of the delta modulated sample to play.  The actual address
;;; used will be ($c000 + kDmcSampleAlign * this).
Hw_DmcSampleStart_wo = $4012

;;; Encoded byte length of the delta modulated sample to play.  The actual
;;; length used will be (1 + 16 * this).
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
