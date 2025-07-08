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
.INCLUDE "../audio.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../sound.inc"

.IMPORT Func_PlaySfxOnNoiseChannel
.IMPORT Func_PlaySfxOnPulse1Channel
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

.SEGMENT "PRGE_Sfx"

;;; SFX data for the "break flower" sound effect.
;;; @thread AUDIO
.PROC Data_BreakFlower_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | 2, $0083
    sfx_Wait 2
    sfx_SetTimer $0085
    sfx_Wait 2
    sfx_SetTimer $008a
    sfx_Wait 7
    sfx_End
.ENDPROC

;;; SFX data for the "pick up flower" sound effect.
;;; @thread AUDIO
.PROC Data_PickUpFlower_sSfx
    sfx_SetAll bEnvelope::Duty14 | bEnvelope::NoLength | 3, kNoSweep, $00d2
    sfx_Wait 3
    sfx_SetTimer $00a9
    sfx_Wait 3
    sfx_SetTimer $009f
    sfx_Wait 3
    sfx_SetTimer $008e
    sfx_Wait 9
    sfx_End
.ENDPROC

;;; SFX data for the "growing flower" sound effect.
;;; @thread AUDIO
.PROC Data_GrowingFlower_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | 0, $0001
    sfx_Wait 7
    sfx_SetTimer $0003
    sfx_Wait 7
    sfx_SetTimer $0085
    sfx_Wait 7
    sfx_SetTimer $0087
    sfx_Wait 7
    sfx_SetTimer $0089
    sfx_Wait 7
    sfx_SetTimer $008b
    sfx_Wait 7
    sfx_End
.ENDPROC

;;; SFX data for the "shrinking flower" sound effect.
;;; @thread AUDIO
.PROC Data_ShrinkingFlower_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | 0, $0089
    sfx_Wait 7
    sfx_SetTimer $0087
    sfx_Wait 7
    sfx_SetTimer $0085
    sfx_Wait 7
    sfx_SetTimer $0003
    sfx_Wait 7
    sfx_SetTimer $0001
    sfx_Wait 7
    sfx_End
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Starts playing the sound for when the player avatar breaks a flower.
;;; @preserve X, Y, T0+
.EXPORT Func_PlaySfxBreakFlower
.PROC Func_PlaySfxBreakFlower
    lda #<Data_BreakFlower_sSfx
    sta Zp_Next_sChanSfx_arr + eChan::Noise + sChanSfx::NextOp_sSfx_ptr + 0
    lda #>Data_BreakFlower_sSfx
    sta Zp_Next_sChanSfx_arr + eChan::Noise + sChanSfx::NextOp_sSfx_ptr + 1
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Starts playing the sound for when a flower baddie grows.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_PlaySfxGrowingFlower
.PROC FuncA_Actor_PlaySfxGrowingFlower
    ldya #Data_GrowingFlower_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;; Starts playing the sound for when a flower baddie shrinks.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_PlaySfxShrinkingFlower
.PROC FuncA_Actor_PlaySfxShrinkingFlower
    ldya #Data_ShrinkingFlower_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Starts playing the sound for when the player avatar picks up a flower.
;;; @preserve X, T0+
.EXPORT FuncA_Avatar_PlaySfxPickUpFlower
.PROC FuncA_Avatar_PlaySfxPickUpFlower
    ldya #Data_PickUpFlower_sSfx
    jmp Func_PlaySfxOnPulse1Channel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;
