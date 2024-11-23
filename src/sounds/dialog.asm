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
.INCLUDE "../dialog.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../sound.inc"

.IMPORT Ram_Audio_sChanSfx_arr
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

.SCOPE bSfxDialog
    TypeMask    = %11000000
    SweepMask   = %00111000
    TimerHiMask = %00000111
    TypePulse12 = bEnvelope::Duty12
    TypePulse14 = bEnvelope::Duty14
    TypePulse18 = bEnvelope::Duty18
    TypeNoise   = bEnvelope::Duty34
.ENDSCOPE
.ASSERT bSfxDialog::TypeMask = bEnvelope::DutyMask, error

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for dialog text sounds.  Param1_byte should hold the TimerLo
;;; value, and Param2_byte should hold the bSfxDialog value.
.PROC Data_DialogText_sSfx
    sfx_Func _Initialize
    sfx_Wait 4
    sfx_End
_Initialize:
    ldy Ram_Audio_sChanSfx_arr + sChanSfx::Param2_byte, x
    tya  ; Param2_byte
    and #bSfxDialog::TypeMask
    ora #bEnvelope::NoLength | 0
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Envelope_wo, x
    tya  ; Param2_byte
    and #bSfxDialog::SweepMask
    .assert bSfxDialog::SweepMask = %00111000, error
    div #8
    ora #$88
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Sweep_wo, x
    lda Ram_Audio_sChanSfx_arr + sChanSfx::Param1_byte, x
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    tya  ; Param2_byte
    and #bSfxDialog::TimerHiMask
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
    sec  ; set C to indicate that the function is finished
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Starts playing a sound for dialog text.
;;; @param Y The ePortrait value for the current dialog text.
.EXPORT FuncA_Dialog_PlaySfxDialogText
.PROC FuncA_Dialog_PlaySfxDialogText
    ;; If Param2 has TypeNoise set, play on the Noise channel; otherwise, play
    ;; on the Pulse2 channel.
    ldx #eChan::Pulse2
    lda DataA_Dialog_SfxDialogTextParam2_bSfxDialog_arr, y
    pha  ; bSfxDialog value
    and #bSfxDialog::TypeMask
    cmp #bSfxDialog::TypeNoise
    bne @notNoise
    ldx #eChan::Noise
    @notNoise:
    pla  ; bSfxDialog value
    ;; Set up the sound effect on the chosen channel.
    sta Zp_Next_sChanSfx_arr + sChanSfx::Param2_byte, x
    lda DataA_Dialog_SfxDialogTextParam1_u8_arr, y
    sta Zp_Next_sChanSfx_arr + sChanSfx::Param1_byte, x
    lda #<Data_DialogText_sSfx
    sta Zp_Next_sChanSfx_arr + sChanSfx::NextOp_sSfx_ptr + 0, x
    lda #>Data_DialogText_sSfx
    sta Zp_Next_sChanSfx_arr + sChanSfx::NextOp_sSfx_ptr + 1, x
    rts
.ENDPROC

;;; Maps from ePortrait values to the bSfxDialog values to use as Param2 for a
;;; dialog text sound, which stores the waveform type, sweep bits, and TimerHi
;;; bits.
.PROC DataA_Dialog_SfxDialogTextParam2_bSfxDialog_arr
    D_ARRAY .enum, ePortrait
    d_byte AdultElder,         bSfxDialog::TypePulse14 | (6 << 3) | $2
    d_byte AdultMan,           bSfxDialog::TypePulse14 | (6 << 3) | $2
    d_byte AdultSmith,         bSfxDialog::TypePulse14 | (6 << 3) | $2
    d_byte AdultWoman,         bSfxDialog::TypePulse14 | (5 << 3) | $2
    d_byte ChildAlex,          bSfxDialog::TypePulse14 | (5 << 3) | $1
    d_byte ChildAlexShout,     bSfxDialog::TypePulse14 | (5 << 3) | $1
    d_byte ChildBruno,         bSfxDialog::TypePulse14 | (5 << 3) | $1
    d_byte ChildBrunoShout,    bSfxDialog::TypePulse14 | (5 << 3) | $1
    d_byte ChildMarie,         bSfxDialog::TypePulse14 | (4 << 3) | $1
    d_byte ChildNora,          bSfxDialog::TypePulse14 | (3 << 3) | $1
    d_byte MermaidDaphne,      bSfxDialog::TypePulse12 | (4 << 3) | $2
    d_byte MermaidCorra,       bSfxDialog::TypePulse12 | (4 << 3) | $2
    d_byte MermaidEirene,      bSfxDialog::TypePulse12 | (5 << 3) | $2
    d_byte MermaidEireneShout, bSfxDialog::TypePulse12 | (5 << 3) | $2
    d_byte MermaidFarmer,      bSfxDialog::TypePulse12 | (6 << 3) | $2
    d_byte MermaidFlorist,     bSfxDialog::TypePulse12 | (4 << 3) | $2
    d_byte MermaidGuardF,      bSfxDialog::TypePulse12 | (5 << 3) | $2
    d_byte MermaidPhoebe,      bSfxDialog::TypePulse12 | (3 << 3) | $1
    d_byte OrcGronta,          bSfxDialog::TypePulse18 | (3 << 3) | $3
    d_byte OrcGrontaShout,     bSfxDialog::TypePulse18 | (3 << 3) | $3
    d_byte OrcMale,            bSfxDialog::TypePulse18 | (4 << 3) | $3
    d_byte OrcMaleShout,       bSfxDialog::TypePulse18 | (4 << 3) | $3
    d_byte Paper,              bSfxDialog::TypeNoise
    d_byte Plaque,             bSfxDialog::TypeNoise
    d_byte Screen,             bSfxDialog::TypeNoise
    d_byte Sign,               bSfxDialog::TypeNoise
    D_END
.ENDPROC

;;; Maps from ePortrait values to the Param1 for a dialog text sound, which
;;; stores the pulse/noise TimerLo value.
.PROC DataA_Dialog_SfxDialogTextParam1_u8_arr
    D_ARRAY .enum, ePortrait
    d_byte AdultElder,         $c0
    d_byte AdultMan,           $a0
    d_byte AdultSmith,         $b0
    d_byte AdultWoman,         $00
    d_byte ChildAlex,          $60
    d_byte ChildAlexShout,     $60
    d_byte ChildBruno,         $50
    d_byte ChildBrunoShout,    $50
    d_byte ChildMarie,         $30
    d_byte ChildNora,          $00
    d_byte MermaidDaphne,      $60
    d_byte MermaidCorra,       $60
    d_byte MermaidEirene,      $a0
    d_byte MermaidEireneShout, $a0
    d_byte MermaidFarmer,      $a0
    d_byte MermaidFlorist,     $a0
    d_byte MermaidGuardF,      $a0
    d_byte MermaidPhoebe,      $20
    d_byte OrcGronta,          $00
    d_byte OrcGrontaShout,     $00
    d_byte OrcMale,            $40
    d_byte OrcMaleShout,       $40
    d_byte Paper,              $00  ; noise
    d_byte Plaque,             $02  ; noise
    d_byte Screen,             $8a  ; noise
    d_byte Sign,               $01  ; noise
    D_END
.ENDPROC

;;;=========================================================================;;;
