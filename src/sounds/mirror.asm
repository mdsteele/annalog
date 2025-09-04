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

.IMPORT Func_PlaySfxOnPulse2Channel

;;;=========================================================================;;;

.SEGMENT "PRGE_Sfx"

;;; SFX data for the "mirror absorb" sound effect.
;;; @thread AUDIO
.PROC Data_MirrorAbsorb_sSfx
    sfx_SetAll bEnvelope::Duty18 | bEnvelope::NoLength | 2, kNoSweep, $0080
    sfx_Wait 12
    sfx_End
.ENDPROC

;;; SFX data for the "mirror reflect" sound effect.
;;; @thread AUDIO
.PROC Data_MirrorReflect_sSfx
    sfx_SetAll bEnvelope::Duty12 | bEnvelope::NoLength | 2, kNoSweep, $0044
    sfx_Wait 12
    sfx_End
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Starts playing the sound for when a fireblast is absorbed by the back of a
;;; mirror.
;;; @preserve X, T0+
.EXPORT FuncA_Room_PlaySfxMirrorAbsorb
.PROC FuncA_Room_PlaySfxMirrorAbsorb
    ldya #Data_MirrorAbsorb_sSfx
    jmp Func_PlaySfxOnPulse2Channel  ; preserves X and T0+
.ENDPROC

;;; Starts playing the sound for when a fireblast reflects off of a mirror.
;;; @preserve X, T0+
.EXPORT FuncA_Room_PlaySfxMirrorReflect
.PROC FuncA_Room_PlaySfxMirrorReflect
    ldya #Data_MirrorReflect_sSfx
    jmp Func_PlaySfxOnPulse2Channel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;
