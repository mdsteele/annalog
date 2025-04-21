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

.INCLUDE "../apu.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../sound.inc"

.IMPORT Func_PlaySfxOnNoiseChannel
.IMPORTZP Zp_AudioTmp_byte

;;;=========================================================================;;;

;;; The duration of the rocket launch sound, in frames.
kSfxLaunchDurationFrames = $1c

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for the "rocket launch" sound effect.
;;; @thread AUDIO
.PROC Data_RocketLaunch_sSfx
    sfx_Func _Func
    sfx_End
_Func:
    sty Zp_AudioTmp_byte  ; frames so far
    lda #kSfxLaunchDurationFrames
    sub Zp_AudioTmp_byte  ; frames so far
    beq @stop
    div #2
    ora #bEnvelope::NoLength | bEnvelope::ConstVol
    sta Hw_NoiseEnvelope_wo
    lda #0
    sta Hw_NoiseLength_wo
    cpy #$0f
    blt @setPeriod
    ldy #$0f
    @setPeriod:
    sty Hw_NoisePeriod_wo
    clc  ; clear C to indicate that the sound is still going
    rts
    @stop:
    sec  ; set C to indicate that the sound is finished
    rts
.ENDPROC

;;; SFX data for a clicking sound effect.
.PROC Data_Click_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | 0, $008a
    sfx_Wait 3
    sfx_SetTimerLo $88
    sfx_Wait 3
    sfx_End
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

;;; Starts playing the sound for when a stepstone is pushed into position.
;;; @preserve T0+
.EXPORT FuncA_Cutscene_PlaySfxClick
.PROC FuncA_Cutscene_PlaySfxClick
    ldya #Data_Click_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Starts playing a rocket launch sound.
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxRocketLaunch
.PROC FuncA_Machine_PlaySfxRocketLaunch
    ldya #Data_RocketLaunch_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for when a rocket is transferred between machines
;;; (e.g. a reloader and a launcher).
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxRocketTransfer
.PROC FuncA_Machine_PlaySfxRocketTransfer
    ldya #Data_Click_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
