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

.INCLUDE "apu.inc"
.INCLUDE "macros.inc"
.INCLUDE "ppu.inc"

;;;=========================================================================;;;

.SEGMENT "PRGA_Pcm0"

.EXPORT DataA_Pcm0_Well_arr
.PROC DataA_Pcm0_Well_arr
:   .assert * = $a000, error
    .incbin "out/pcm/maybe_this_time.pcm"  ; TODO
    .assert * - :- = $2000, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Pcm1"

.EXPORT DataA_Pcm1_MaybeThisTime_arr
.PROC DataA_Pcm1_MaybeThisTime_arr
:   .assert * = $a000, error
    .incbin "out/pcm/maybe_this_time.pcm"
    .assert * - :- = $2000, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Pcm2"

.EXPORT DataA_Pcm2_WillBeDifferent_arr
.PROC DataA_Pcm2_WillBeDifferent_arr
:   .assert * = $a000, error
    .incbin "out/pcm/maybe_this_time.pcm"  ; TODO
    .assert * - :- = $2000, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Pcm"

;;; Plays all PCM data stored in the currently-loaded PRGA bank.
;;; @prereq Audio is disabled.
;;; @prereq The PRGA bank for the PCM data is loaded.
.EXPORT Func_PlayPrgaPcm
.PROC Func_PlayPrgaPcm
    ;; Disable all NMI and IRQ interrupts.
    sei                 ; disable maskable (IRQ) interrupts
    ldx #0
    stx Hw_PpuCtrl_wo   ; disable VBlank NMI
_PlayPcmData:
    ldy #0    ; byte offset from base address
    sty T0    ; base address (lo)
    lda #$a0
    sta T1    ; base address (hi)
    ldx #$20  ; num pages to play
    ;; Loop over all of PRGA, sending one sample at a time to Hw_DmcLevel_wo,
    ;; once every 218 cycles.
    @sampleLoop:
    pha  ; 3 cycles   (Just wasting time so that the
    pla  ; 4 cycles    sample and page loops take the
    nop  ; 2 cycles    same number of cycles.)
    @pageLoop:
    lda (T1T0), y       ; 5 cycles (no page is crossed because T0 = 0)
    sta Hw_DmcLevel_wo  ; 4 cycles
    ;; Waste 195 cycles so that the sample loop totals 218 cycles.
    nop                 ; 2 cycles
    lda #38             ; 2 cycles
    sec                 ; 2 cycles
    @busyLoop:
    sbc #1              ; 2 cycles
    bne @busyLoop       ; 3 cycles if taken, 2 if not (no page is crossed)
    ;; Advance to the next sample.
    iny                 ; 2 cycles
    bne @sampleLoop     ; 3 cycles if taken, 2 if not (no page is crossed)
    inc T1              ; 5 cycles
    dex                 ; 2 cycles
    bne @pageLoop       ; 3 cycles if taken, 2 if not (no page is crossed)
    ;; Assert that all of the timing-sensitive code is in the same ROM page (so
    ;; none of the branches will cross a page boundary, and thus all have
    ;; predictable timing).
    .assert (* / $100) = (_PlayPcmData / $100), error
_Finish:
    ;; Re-enable interrupts.
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo   ; enable VBlank NMI
    cli                 ; enable maskable (IRQ) interrupts
    rts
.ENDPROC

;;;=========================================================================;;;
