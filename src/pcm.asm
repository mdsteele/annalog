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
    ;; Disable all interrupts.
    sei                 ; disable maskable (IRQ) interrupts
    ldx #0
    stx Hw_PpuCtrl_wo   ; disable VBlank NMI
_Initialize:
    lda #$a0
    sta T1  ; page addr (hi)
    ldy #0  ; byte offset in page
    sty T0  ; page addr (lo)
    ldx #7  ; buffer bits needed
    lda #$40
    ;; We wish to play PCM data at 8192 samples per second.  An NTSC NES CPU
    ;; runs at 1789773 cycles per second, so we must write one sample every 218
    ;; cycles.
_SampleLoop:
    ;; [4 cycles] At this point, A holds the next sample; write it to the APU.
    sta Hw_DmcLevel_wo                    ; 4 cycles
    ;; [166 cycles] Waste some time to make the sample rate correct.
    lda #15                               ; 2 cycles
    @loop:
    nop                                   ; 30 cycles (2 per iter)
    nop                                   ; 30 cycles (2 per iter)
    sec                                   ; 30 cycles (2 per iter)
    sbc #1                                ; 30 cycles (2 per iter)
    bne @loop                             ; 44 cycles (2 or 3 per iter)
    ;; [48 cycles] Fetch the next sample.  If the eighth-sample buffer is full,
    ;; use it; otherwise, read the next data byte.  Both of these branches end
    ;; by jumping back up to _SampleLoop, and either one always takes exactly
    ;; 48 cycles (including these next two instructions).
    txa  ; buffer bits needed             ; 2 cycles
    bne _ReadNextByte                     ; 2 or 3 cycles
_UseBufferedSample:
    ;; [36 cycles] Burn some cycles so that the _UseBufferedSample branch takes
    ;; the same number of cycles as the _ReadNextByte branch.  Along the way,
    ;; set buffer bits needed to 7, to indicate that the buffer is empty.
    ldx #2  ; buffer bits needed          ; 2 cycles
    @loop:
    inx     ; buffer bits needed          ; 10 cycles (2 per iter)
    cpx #7                                ; 10 cycles (2 per iter)
    bne @loop                             ; 14 cycles (2 or 3 per iter)
    ;; [8 cycles] Send the contents of eighth-sample buffer to the APU (after
    ;; chopping off the top bit, which holds garbage data).
    lda T2  ; eighth-sample buffer        ; 3 cycles
    and #$7f                              ; 2 cycles
    bpl _SampleLoop  ; unconditional      ; 3 cycles
_ReadNextByte:
    ;; [7 cycles] If there are no more data bytes to read (i.e. the page
    ;; address is no longer in PRGA), then we're done.
    lda T1  ; page addr (hi)              ; 3 cycles
    cmp #$c0                              ; 2 cycles
    bge _Finish                           ; 2 cycles (ignoring taken case)
    ;; [19 cycles] Read the next data byte, shift its top bit into the bottom
    ;; of the eighth-sample buffer, and send the bottom seven bits to the APU.
    lda (T1T0), y                         ; 5 cycles
    asl a                                 ; 2 cycles
    rol T2  ; eighth-sample buffer        ; 5 cycles
    dex     ; buffer bits needed          ; 2 cycles
    lsr a                                 ; 2 cycles
    sta T3  ; next sample                 ; 3 cycles
    ;; [12 cycles] Increment the data pointer.  To do this, we increment Y (the
    ;; byte offset within the ROM page), and when Y rolls over, we increment
    ;; the high byte of the page address.  If Y doesn't roll over, we burn some
    ;; cycles instead.
    iny     ; byte offset in page         ; 2 cycles
    bne @noPageFlip                       ; 2 or 3 cycles
    inc T1  ; page addr (hi)              ; 5 cycles
    bne @donePageFlip  ; unconditional    ; 3 cycles
    @noPageFlip:
    pha     ; (just burning cycles)       ; 3 cycles
    pla     ; (just burning cycles)       ; 4 cycles
    @donePageFlip:
    ;; [5 cycles] Send the next sample to the APU.
    lda T3  ; next sample                 ; 2 cycles
    bpl _SampleLoop  ; unconditional      ; 3 cycles
_Finish:
    ;; The code between _SampleLoop and here is timing-sensitive, and assumes
    ;; that none of its branch instructions will cross a page boundary (doing
    ;; so would change their timing), so assert that that assumption is true.
    .assert (* / $100) = (_SampleLoop / $100), error
    ;; Re-enable interrupts.
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo   ; enable VBlank NMI
    cli                 ; enable maskable (IRQ) interrupts
    rts
.ENDPROC

;;;=========================================================================;;;
