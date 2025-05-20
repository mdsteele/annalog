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
.IMPORT Func_PlaySfxOnPulse2Channel

;;;=========================================================================;;;

.SEGMENT "PRGE_Sfx"

;;; SFX data for the "small thud" sound effect.
;;; @thread AUDIO
.PROC Data_ThudSmall_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | 1, $000c
    sfx_Wait 6
    sfx_End
.ENDPROC

;;; SFX data for the "big thud" sound effect.
;;; @thread AUDIO
.PROC Data_ThudBig_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | 5, $000d
    sfx_Wait 24
    sfx_End
.ENDPROC

;;; SFX data for the "thump" sound effect.
;;; @thread AUDIO
.PROC Data_Thump_sSfx
    .linecont +
    sfx_SetAll (bEnvelope::Duty14 | bEnvelope::NoLength | \
                bEnvelope::ConstVol | 12), \
               (pulse_sweep +6, 0), $0120
    sfx_Wait 6
    sfx_End
    .linecont -
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Starts playing the sound for when a softer object gets hit (e.g. the player
;;; avatar flops face down on the ground, or an orc punches someone, or a boss
;;; gets hit for no damage).
;;; @preserve X, T0+
.EXPORT Func_PlaySfxThump
.PROC Func_PlaySfxThump
    ldya #Data_Thump_sSfx
    jmp Func_PlaySfxOnPulse2Channel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Starts playing the sound for when smaller heavy object (like a crate) falls
;;; on the floor.
;;; @preserve X, T0+
.EXPORT FuncA_Room_PlaySfxThudSmall
.PROC FuncA_Room_PlaySfxThudSmall
    ldya #Data_ThudSmall_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Starts playing the sound for when bigger heavy object falls on the floor.
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxThudBig
.PROC FuncA_Machine_PlaySfxThudBig
    ldya #Data_ThudBig_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
