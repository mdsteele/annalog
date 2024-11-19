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

.IMPORT Func_PlaySfxBytecodeNoise
.IMPORT Func_PlaySfxBytecodePulse2

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for the "metallic clang" sound effect.
.PROC Data_MetallicClang_sSfx
    sfx_SetAll bEnvelope::Duty18 | bEnvelope::NoLength | 7, kNoSweep, $00f7
    sfx_Wait 4
    sfx_SetEnvTimer bEnvelope::Duty14 | bEnvelope::NoLength | 9,      $00f5
    sfx_Wait 40
    sfx_End
.ENDPROC

;;; SFX data for the "metallic ding" sound effect.
.PROC Data_MetallicDing_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | 1, $0081
    sfx_Wait 4
    sfx_End
.ENDPROC

;;; Starts playing a metallic "ding" sound.
;;; @preserve X, T0+
.EXPORT Func_PlaySfxMetallicDing
.PROC Func_PlaySfxMetallicDing
    txa
    pha
    ldya #Data_MetallicDing_sSfx
    jsr Func_PlaySfxBytecodeNoise  ; preserves T0+
    pla
    tax
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Starts playing a metallic "clang" sound.
;;; @preserve T0+
.EXPORT FuncA_Room_PlaySfxMetallicClang
.PROC FuncA_Room_PlaySfxMetallicClang
    ldya #Data_MetallicClang_sSfx
    jmp Func_PlaySfxBytecodePulse2  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
