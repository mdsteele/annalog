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

.IMPORT Func_PlaySfxBytecodePulse2

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX sequence data for the "menu cancel" sound effect.
.PROC Data_MenuCancel_sSfx
    sfx_SetAll bEnvelope::Duty18 | bEnvelope::NoLength | 1, kNoSweep, $0180
    sfx_Wait 5
    sfx_SetEnvTimer bEnvelope::Duty14 | bEnvelope::NoLength | 1, $01e0
    sfx_Wait 5
    sfx_End
.ENDPROC

;;; SFX sequence data for the "menu confirm" sound effect.
.PROC Data_MenuConfirm_sSfx
    sfx_SetAll bEnvelope::Duty12 | bEnvelope::NoLength | 1, kNoSweep, $0180
    sfx_Wait 5
    sfx_SetEnvTimer bEnvelope::Duty14 | bEnvelope::NoLength | 1, $0120
    sfx_Wait 5
    sfx_End
.ENDPROC

;;; SFX data for the "menu move" sound effect.
.PROC Data_MenuMove_sSfx
    sfx_SetAll bEnvelope::Duty14 | bEnvelope::NoLength | 0, kNoSweep, $01a0
    sfx_Wait 3
    sfx_End
.ENDPROC

;;; Starts playing the sound for cancelling in a menu.
;;; @preserve T0+
.EXPORT Func_PlaySfxMenuCancel
.PROC Func_PlaySfxMenuCancel
    ldya #Data_MenuCancel_sSfx
    jmp Func_PlaySfxBytecodePulse2  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for confirming a menu item.
;;; @preserve T0+
.EXPORT Func_PlaySfxMenuConfirm
.PROC Func_PlaySfxMenuConfirm
    ldya #Data_MenuConfirm_sSfx
    jmp Func_PlaySfxBytecodePulse2  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for moving the cursor in a menu.
;;; @preserve T0+
.EXPORT Func_PlaySfxMenuMove
.PROC Func_PlaySfxMenuMove
    ldya #Data_MenuMove_sSfx
    jmp Func_PlaySfxBytecodePulse2  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
