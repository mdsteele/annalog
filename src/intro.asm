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

.INCLUDE "audio.inc"
.INCLUDE "fade.inc"
.INCLUDE "intro.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncC_Title_ClearNametableTiles
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_FillUpperAttributeTable
.IMPORT Func_GetRotorPolarOffset
.IMPORT Func_SetAndTransferBgFade
.IMPORT Func_SetAndTransferFade
.IMPORT Func_SetAndTransferObjFade
.IMPORT Func_Window_Disable
.IMPORT MainC_Title_Menu
.IMPORT Ppu_ChrBgIntro
.IMPORT Ppu_ChrObjPause
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_RoomState
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; The size of the "mdsteele" logo, in tiles.
kMdsteeleLogoRows = 8
kMdsteeleLogoCols = 8

;;; The PPU address in the upper nametable for the top-left corner of the
;;; "mdsteele" logo's background tiles.
.LINECONT +
Ppu_MdsteeleLogoTopLeft = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kScreenHeightTiles - kMdsteeleLogoRows) / 2 + \
    (kScreenWidthTiles - kMdsteeleLogoCols) / 2
.LINECONT -

;;; How many frames to wait between fade steps during the intro sequence.
kIntroFadeFrames = 10

;;; How many frames to spin the "mdsteele" logo border at full speed before
;;; slowing it down.
kMdsteeleLogoSpin = 70

;;; How many frames to display the complete "mdsteele" logo for before fading
;;; out.
kMdsteeleLogoPause = 150

;;; The initial angle of the "mdsteele" logo border, in tau/256 units.  This
;;; offset is hand-tuned to make the logo look correct once it comes to a
;;; complete stop.
kMdsteeleLogoInitAngle = <(59 - kMdsteeleLogoSpin)

;;;=========================================================================;;;

;;; Phases of the intro.
.ENUM ePhase
    MdsteeleFadeIn
    MdsteeleSlowDown
    MdsteeleFadeOut
    NUM_VALUES
.ENDENUM

;;; State data for the intro.
.STRUCT sState
    ;; The current phase of the intro sequence.
    Current_ePhase .byte
    ;; How many frames have elapsed on the current intro phase.
    PhaseTimer_u8  .byte
    ;; The rotation speed of the "mdsteele" hexagon border, in tau/(256*256)
    ;; units per frame.
    TurnSpeed_u8   .byte
    ;; The rotation angle of the "mdsteele" hexagon border, in tau/(256*256)
    ;; units.
    Angle_u16      .word
.ENDSTRUCT

;;;=========================================================================;;;

.ZEROPAGE

;;; Use the same storage space as Zp_RoomState for the intro (since we don't
;;; need room data during the intro).
.ASSERT .sizeof(sState) <= kRoomStateSize, error
Zp_Intro_sState := Zp_RoomState

;;;=========================================================================;;;

.SEGMENT "PRGC_Title"

;;; Mode for the intro sequence that plays on startup before the title menu
;;; appears.
;;; @prereq Rendering is disabled.
.EXPORT MainC_Title_Intro
.PROC MainC_Title_Intro
    jsr FuncC_Title_InitIntro
_GameLoop:
    main_prga_bank FuncA_Objects_Draw1x1Shape
    jsr FuncC_Title_DrawIntro
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr FuncC_Title_TickIntro  ; returns C
    bcc _GameLoop
_Finish:
    ;; Disable rendering.
    lda #0
    sta Zp_Render_bPpuMask
    jsr Func_ClearRestOfOamAndProcessFrame
    ;; Start the title menu.
    jmp MainC_Title_Menu
.ENDPROC

;;; Initializes the intro sequence.
;;; @prereq Rendering is disabled.
.PROC FuncC_Title_InitIntro
    main_chr08_bank Ppu_ChrBgIntro
    main_chr18_bank Ppu_ChrObjPause
_ClearUpperNametable:
    ldxy #Ppu_Nametable0_sName  ; param: nametable addr
    jsr FuncC_Title_ClearNametableTiles
    ldy #$00  ; param: attribute byte
    jsr Func_FillUpperAttributeTable  ; preserves Y
_DrawMdsteeleLogo:
    lda #kPpuCtrlFlagsVert
    sta Hw_PpuCtrl_wo
    lda #kTileIdBgMdsteeleLogoFirst
    sta T0  ; tile ID
    ldx #0
    @columnLoop:
    lda #>Ppu_MdsteeleLogoTopLeft
    sta Hw_PpuAddr_w2
    txa  ; logo column
    add #<Ppu_MdsteeleLogoTopLeft
    sta Hw_PpuAddr_w2
    ldy #0
    @rowLoop:
    lda T0  ; tile ID
    sta Hw_PpuData_rw
    inc T0  ; tile ID
    iny
    cpy #kMdsteeleLogoRows
    blt @rowLoop
    inx
    cpx #kMdsteeleLogoCols
    blt @columnLoop
_PrepareToFadeIn:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Next_bAudio  ; disable audio
    sta Zp_Intro_sState + sState::Current_ePhase
    sta Zp_Intro_sState + sState::PhaseTimer_u8
    sta Zp_Intro_sState + sState::Angle_u16 + 0
    lda #kMdsteeleLogoInitAngle
    sta Zp_Intro_sState + sState::Angle_u16 + 1
    lda #255
    sta Zp_Intro_sState + sState::TurnSpeed_u8
    jsr Func_Window_Disable
    ldy #eFade::Black  ; param: eFade value
    jmp Func_SetAndTransferFade
.ENDPROC

;;; Performs per-frame updates for the intro sequence.
;;; @return C Set if the intro is now finished.
.PROC FuncC_Title_TickIntro
    inc Zp_Intro_sState + sState::PhaseTimer_u8
    lda Zp_Intro_sState + sState::TurnSpeed_u8 + 0
    add Zp_Intro_sState + sState::Angle_u16 + 0
    sta Zp_Intro_sState + sState::Angle_u16 + 0
    lda #0
    adc Zp_Intro_sState + sState::Angle_u16 + 1
    sta Zp_Intro_sState + sState::Angle_u16 + 1
    ;; Stop the intro early if the player presses START, A, or B.
    lda #bJoypad::Start | bJoypad::AButton | bJoypad::BButton
    bit Zp_P1ButtonsPressed_bJoypad
    bne _IntroIsFinished
    ;; Handle the current intro phase.
    ldy Zp_Intro_sState + sState::Current_ePhase
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, ePhase
    d_entry table, MdsteeleFadeIn,   _MdsteeleFadeIn
    d_entry table, MdsteeleSlowDown, _MdsteeleSlowDown
    d_entry table, MdsteeleFadeOut,  _MdsteeleFadeOut
    D_END
.ENDREPEAT
_IntroIsFinished:
    sec  ; set C to indicate that the intro is finished
    rts
_MdsteeleFadeIn:
    lda Zp_Intro_sState + sState::PhaseTimer_u8
    cmp #kIntroFadeFrames * 1
    blt @fadeBlack
    beq @fadeDark
    cmp #kIntroFadeFrames * 2
    beq @fadeDim
    cmp #kIntroFadeFrames * 3
    beq @fadeNormal
    .assert kIntroFadeFrames * 3 < kMdsteeleLogoSpin, error
    cmp #kMdsteeleLogoSpin
    bge _StartNextPhase
    rts  ; C is clear, indicating that the intro should continue
    @fadeNormal:
    ldy #eFade::Normal
    .assert eFade::Normal < $80, error
    bpl @setFade  ; unconditional
    @fadeDim:
    ldy #eFade::Dim
    .assert eFade::Dim < $80, error
    bpl @setFade  ; unconditional
    @fadeDark:
    ldy #eFade::Dark
    .assert eFade::Dark < $80, error
    bpl @setFade  ; unconditional
    @fadeBlack:
    ldy #eFade::Black
    @setFade:
    jsr Func_SetAndTransferObjFade
    clc  ; clear C to indicate that the intro should continue
    rts
_MdsteeleSlowDown:
    dec Zp_Intro_sState + sState::TurnSpeed_u8
    beq _StartNextPhase
    lda Zp_Intro_sState + sState::TurnSpeed_u8
    cmp #kIntroFadeFrames * 2
    beq @fadeNormal
    cmp #kIntroFadeFrames * 3
    beq @fadeDim
    cmp #kIntroFadeFrames * 4
    bne @done
    @fadeDark:
    ldy #eFade::Dark
    .assert eFade::Dark < $80, error
    bpl @setFade  ; unconditional
    @fadeDim:
    ldy #eFade::Dim
    .assert eFade::Dim < $80, error
    bpl @setFade  ; unconditional
    @fadeNormal:
    ldy #eFade::Normal
    @setFade:
    jsr Func_SetAndTransferBgFade
    @done:
    clc  ; clear C to indicate that the intro should continue
    rts
_MdsteeleFadeOut:
    lda Zp_Intro_sState + sState::PhaseTimer_u8
    cmp #kMdsteeleLogoPause + kIntroFadeFrames * 1
    beq @fadeDim
    cmp #kMdsteeleLogoPause + kIntroFadeFrames * 2
    beq @fadeDark
    cmp #kMdsteeleLogoPause + kIntroFadeFrames * 3
    beq @fadeBlack
    cmp #kMdsteeleLogoPause + kIntroFadeFrames * 4
    bge _StartNextPhase
    rts  ; C is clear, indicating that the intro should continue
    @fadeDim:
    ldy #eFade::Dim
    .assert eFade::Dim < $80, error
    bpl @setFade  ; unconditional
    @fadeDark:
    ldy #eFade::Dark
    .assert eFade::Dark < $80, error
    bpl @setFade  ; unconditional
    @fadeBlack:
    ldy #eFade::Black
    @setFade:
    jsr Func_SetAndTransferFade
    clc  ; clear C to indicate that the intro should continue
    rts
_StartNextPhase:
    lda #0
    sta Zp_Intro_sState + sState::PhaseTimer_u8
    inc Zp_Intro_sState + sState::Current_ePhase
    lda Zp_Intro_sState + sState::Current_ePhase
    cmp #ePhase::NUM_VALUES  ; sets C if intro is finished
    rts
.ENDPROC

;;; Draws objects for "mdsteele" logo border in the intro sequence.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Title_DrawIntro
    lda #0
    sta Zp_ShapePosY_i16 + 1
    sta Zp_ShapePosY_i16 + 1
    ldy #3 - 1
    sty T4  ; side index
_SideLoop:
    ldx #5 - 1
    @segmentLoop:
    ldy T4  ; side index
    lda _BaseAngle_u8_arr3, y
    add Zp_Intro_sState + sState::Angle_u16 + 1
    pha  ; side angle
    add _AngleOffset_u8_arr5, x  ; param: angle
    ldy _RadiusMult_u8_arr5, x  ; param: radius multiplier
    jsr Func_GetRotorPolarOffset  ; preserves X and T4+, returns T2 and T3
    ;; Draw one object:
    lda #(kScreenWidthPx - kTileWidthPx) / 2
    add T2  ; X-offset (signed)
    sta Zp_ShapePosX_i16 + 0
    lda #(kScreenHeightPx - kTileHeightPx) / 2
    add T3  ; Y-offset (signed)
    sta Zp_ShapePosY_i16 + 0
    pla  ; side angle
    add #$1c
    div #16
    mod #8
    .assert kTileIdObjMdsteeleBorderFirst .mod 8 = 0, error
    ora #kTileIdObjMdsteeleBorderFirst  ; param: tile ID
    pha  ; tile ID
    ldy #0  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    ;; Draw opposite object:
    lda #(kScreenWidthPx - kTileWidthPx) / 2
    sub T2  ; X-offset (signed)
    sta Zp_ShapePosX_i16 + 0
    lda #(kScreenHeightPx - kTileHeightPx) / 2
    sub T3  ; Y-offset (signed)
    sta Zp_ShapePosY_i16 + 0
    pla  ; param: tile ID
    ldy #0  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    ;; Loop:
    dex
    bpl @segmentLoop
    dec T4  ; side index
    bpl _SideLoop
    rts
_RadiusMult_u8_arr5:
    ;; [round(hypot((2 + 4 * t) * sqrt(3), 8 * 5 - (2 + 4 * t)) * 1.75)
    ;;  for t in range(5)]
    .byte 67, 62, 61, 62, 67
_AngleOffset_u8_arr5:
    ;; [round(atan2((2 + 4 * t) * sqrt(3), 8 * 5 - (2 + 4 * t)) * 128/pi)
    ;;  for t in range(5)]
    .byte 4, 12, 21, 31, 39
_BaseAngle_u8_arr3:
    ;; [round(t * 256 / 6.) for t in range(3)]
    .byte 0, 43, 85
.ENDPROC

;;;=========================================================================;;;
