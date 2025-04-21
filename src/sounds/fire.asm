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

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for the "shoot fire" sound effect.
;;; @thread AUDIO
.PROC Data_ShootFire_sSfx
    sfx_SetEnvTimer   bEnvelope::NoLength | bEnvelope::ConstVol |  4, $000a
    sfx_Wait 3
    sfx_SetEnvTimerLo bEnvelope::NoLength | bEnvelope::ConstVol |  8,   $0b
    sfx_Wait 3
    sfx_SetEnvTimerLo bEnvelope::NoLength | bEnvelope::ConstVol | 12,   $0c
    sfx_Wait 3
    sfx_SetEnvTimerLo bEnvelope::NoLength | bEnvelope::ConstVol |  8,   $0d
    sfx_Wait 3
    sfx_SetEnvTimerLo bEnvelope::NoLength | bEnvelope::ConstVol |  4,   $0e
    sfx_Wait 3
    sfx_End
.ENDPROC

;;; SFX data for the "fire burning" sound effect.
;;; @thread AUDIO
.PROC Data_FireBurning_sSfx
    sfx_SetEnvTimer   bEnvelope::NoLength | bEnvelope::ConstVol | 8, $000d
    sfx_Wait 3
    sfx_SetTimerLo $8d
    sfx_Wait 3
    sfx_SetEnvTimerLo bEnvelope::NoLength | bEnvelope::ConstVol | 6,   $0d
    sfx_Wait 3
    sfx_SetEnvTimerLo bEnvelope::NoLength | bEnvelope::ConstVol | 3,   $8d
    sfx_Wait 3
    sfx_End
.ENDPROC

;;; Starts playing the sound for when something shoots a firey projectile.
;;; @preserve X, T0+
.EXPORT Func_PlaySfxShootFire
.PROC Func_PlaySfxShootFire
    ldya #Data_ShootFire_sSfx  ; param: sSfx pointer
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Starts playing the sound for a firey projectile continuing to burn.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_PlaySfxFireBurning
.PROC FuncA_Actor_PlaySfxFireBurning
    ldya #Data_FireBurning_sSfx  ; param: sSfx pointer
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;
