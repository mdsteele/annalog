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
.INCLUDE "avatar.inc"
.INCLUDE "boss.inc"
.INCLUDE "breaker.inc"
.INCLUDE "charmap.inc"
.INCLUDE "cpu.inc"
.INCLUDE "cutscene.inc"
.INCLUDE "device.inc"
.INCLUDE "devices/breaker.inc"
.INCLUDE "fade.inc"
.INCLUDE "flag.inc"
.INCLUDE "hud.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "music.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "sample.inc"
.INCLUDE "scroll.inc"
.INCLUDE "spawn.inc"
.INCLUDE "tileset.inc"

.IMPORT FuncA_Avatar_SpawnAtDevice
.IMPORT FuncA_Cutscene_PlaySfxCircuitPowerUp
.IMPORT FuncA_Cutscene_PlaySfxCircuitTrace
.IMPORT FuncA_Cutscene_PlaySfxFlipBreaker
.IMPORT FuncM_SwitchPrgcAndLoadRoom
.IMPORT FuncM_SwitchPrgcAndLoadRoomWithMusic
.IMPORT Func_AllocObjects
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_FadeOutToBlack
.IMPORT Func_FillUpperAttributeTable
.IMPORT Func_MovePointUpByA
.IMPORT Func_PlaySfxExplodeBig
.IMPORT Func_SaveProgressAtActiveDevice
.IMPORT Func_SetAndTransferFade
.IMPORT Func_SetFlag
.IMPORT Main_Explore_Continue
.IMPORT Main_Explore_EnterRoom
.IMPORT Ppu_ChrBgAnimStatic
.IMPORT Ppu_ChrBgFontLower
.IMPORT Ppu_ChrObjPause
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarHarmTimer_u8
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_AvatarSubX_u8
.IMPORTZP Zp_AvatarSubY_u8
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_AvatarVelY_i16
.IMPORTZP Zp_Camera_bScroll
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_Current_eRoom
.IMPORTZP Zp_FloatingHud_bHud
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_Nearby_bDevice
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8

;;;=========================================================================;;;

;;; How many frames to wait between fade steps for circuit-tracing mode.
.DEFINE kCircuitTraceFadeSlowdown 8

;;; The screen scroll speed during circuit-tracing mode, in pixels per frame.
kCircuitTraceScrollSpeed = 6

;;; The BG tile ID to use for the rock tiles during circuit-tracing mode.
kTileIdBgCircuitTraceRocks = $10

;;; The OBJ palette number to use for drawing energy waves during
;;; circuit-tracing mode.
kPaletteObjCircuitWave = 0

;;;=========================================================================;;;

.ZEROPAGE

;;; The boss room that the breaker is in.
Zp_Breaker_eRoom: .res 1

;;; The flag for the breaker that's being activated.
.EXPORTZP Zp_BreakerBeingActivated_eFlag
Zp_BreakerBeingActivated_eFlag: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for activating a circuit breaker device.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Nearby_bDevice holds an active breaker device.
.EXPORT Main_Breaker_UseDevice
.PROC Main_Breaker_UseDevice
    jmp_prga MainA_Cutscene_FlipBreakerDevice
.ENDPROC

;;; Mode to load the room for the power core cutscene that plays when
;;; activating a breaker.
;;; @prereq Rendering is disabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Breaker_LoadCoreRoom
    ldx #eRoom::CoreBoss  ; param: room to load
    ldy #eMusic::Silence  ; param: music to play
    jsr FuncM_SwitchPrgcAndLoadRoomWithMusic
    jmp_prga MainA_Cutscene_EnterCoreBreakerRoom
.ENDPROC

;;; Mode to fade out from the "power up circuit" cutscene and transition to the
;;; breaker-specific story cutscene.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Breaker_TransitionToBreakerCutscene
    jsr Func_FadeOutToBlack
    main_chr00_bank Ppu_ChrBgFontLower
    jsr_prga FuncA_Cutscene_GetBreakerCutsceneRoomAndMusic  ; returns X and Y
    jsr FuncM_SwitchPrgcAndLoadRoomWithMusic
    jmp_prga MainA_Cutscene_EnterBreakerCutsceneRoom
.ENDPROC

;;; Mode for fading to black from a breaker cutscene and switching back to
;;; explore mode in the room the breaker was in.
;;; @prereq Rendering is enabled.
.EXPORT Main_Breaker_FadeBackToBreakerRoom
.PROC Main_Breaker_FadeBackToBreakerRoom
    jsr Func_FadeOutToBlack
    ldx Zp_Breaker_eRoom  ; param: room to load
    jsr FuncM_SwitchPrgcAndLoadRoom
    jmp_prga MainA_Avatar_EnterBossRoomAfterBreaker
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_SharedFlipBreaker_sCutscene
.PROC DataA_Cutscene_SharedFlipBreaker_sCutscene
    ;; Adjust the player avatar to be in front of the breaker.
    act_SetAvatarPose eAvatar::Looking
    act_WaitUntilZ _AdjustAvatarOffset
    act_SetAvatarFlags kPaletteObjAvatarNormal
    ;; Make the player avatar reach up a couple times to try to reach the
    ;; breaker.
    act_WaitFrames 25
    act_SetAvatarPose eAvatar::Reaching
    act_WaitFrames 30
    act_SetAvatarPose eAvatar::Looking
    act_WaitFrames 35
    act_SetAvatarPose eAvatar::Straining
    act_WaitFrames 30
    act_SetAvatarPose eAvatar::Looking
    act_WaitFrames 40
    ;; Make the player avatar wobble on one foot while straining to reach the
    ;; breaker.
    act_SetAvatarPose eAvatar::Straining
    act_RepeatFunc 80, _WobbleAvatarOffset
    act_CallFunc _FixAvatarOffset
    ;; Make the player avatar jump up, grab the breaker handle, and pull it
    ;; down.
    act_ForkStart 1, _PlayBreakerSound_sCutscene
    act_CallFunc _FlipBreakerDevice
    act_PlaySfxSample eSample::JumpAnna
    act_WaitUntilZ _AnimateAvatarFlippingBreaker
    act_WaitFrames 60
    act_JumpToMain MainA_Cutscene_CircuitTrace
_PlayBreakerSound_sCutscene:
    act_WaitFrames 4
    act_CallFunc FuncA_Cutscene_PlaySfxFlipBreaker
    act_WaitFrames 12
    act_ShakeRoom 16
    act_ForkStop $ff
_AdjustAvatarOffset:
    lda #0
    sta Zp_AvatarSubX_u8
    lda Zp_AvatarPosX_i16 + 0
    and #$0f
    cmp #kBreakerAvatarOffset
    blt @adjustRight
    beq @return  ; Z is set to indicate that we're done
    @adjustLeft:
    dec Zp_AvatarPosX_i16 + 0
    lda #kPaletteObjAvatarNormal | bObj::FlipH  ; Z is clear
    bne @setFlags  ; unconditional
    @adjustRight:
    inc Zp_AvatarPosX_i16 + 0
    lda #kPaletteObjAvatarNormal
    .assert kPaletteObjAvatarNormal <> 0, error  ; Z is clear
    @setFlags:
    sta Zp_AvatarFlags_bObj
    @return:
    rts
_WobbleAvatarOffset:
    txa  ; timer
    and #$04
    bne _FixAvatarOffset
    lda #kBreakerAvatarOffset - 1
    .assert kBreakerAvatarOffset - 1 <> 0, error
    bne _SetAvatarOffset  ; unconditional
_FixAvatarOffset:
    lda #kBreakerAvatarOffset
_SetAvatarOffset:
    sta T0  ; wobble offset (0-15)
    lda Zp_AvatarPosX_i16 + 0
    and #$f0
    ora T0  ; wobble offset (0-15)
    sta Zp_AvatarPosX_i16 + 0
    rts
_FlipBreakerDevice:
    lda Zp_Nearby_bDevice
    and #bDevice::IndexMask
    tax  ; breaker device index
    lda #eDevice::BreakerDone
    sta Ram_DeviceType_eDevice_arr, x
    lda #kBreakerDoneDeviceAnimStart
    sta Ram_DeviceAnim_u8_arr, x
    rts
_AnimateAvatarFlippingBreaker:
    ;; Animate the avatar to match the flipping breaker.
    lda Zp_Nearby_bDevice
    and #bDevice::IndexMask
    tax  ; breaker device index
    lda Ram_DeviceAnim_u8_arr, x
    pha  ; breaker device anim
    div #8
    tay
    lda _AvatarFlipPose_eAvatar_arr, y
    sta Zp_AvatarPose_eAvatar
    ;; Adjust the avatar's Y-position.
    lda Zp_AvatarPosY_i16 + 0
    and #$f0
    ora _AvatarFlipOffsetY_u8_arr, y
    sta Zp_AvatarPosY_i16 + 0
    lda #0
    sta Zp_AvatarSubY_u8
    pla  ; breaker device anim (sets Z when done)
    rts
_AvatarFlipPose_eAvatar_arr:
    .byte eAvatar::Kneeling
    .byte eAvatar::Standing
    .byte eAvatar::Reaching
    .byte eAvatar::Straining
_AvatarFlipOffsetY_u8_arr:
    .byte $08, $08, $08, $06
.ENDPROC

.EXPORT DataA_Cutscene_CoreBossPowerUpCircuit_sCutscene
.PROC DataA_Cutscene_CoreBossPowerUpCircuit_sCutscene
    act_WaitFrames 65
    act_CallFunc FuncA_Cutscene_PlaySfxCircuitPowerUp
    act_RepeatFunc 120, _PowerUpCircuit
    act_CallFunc Func_PlaySfxExplodeBig
    act_ShakeRoom 30
    act_RepeatFunc 150, _AnimatePoweredCircuit
    act_JumpToMain Main_Breaker_TransitionToBreakerCutscene
_PowerUpCircuit:
    cpx #64
    bge @on
    txa  ; timer (0-63 ascending)
    and #$03
    sta T0  ; timer mod 4
    txa  ; timer (0-63 ascending)
    div #16
    cmp T0  ; timer mod 4
    bge @on
    @off:
    ldx #<.bank(Ppu_ChrBgAnimStatic)
    .assert <.bank(Ppu_ChrBgAnimStatic) <> 0, error
    bne _SetBankToX  ; unconditional
    @on:
_AnimatePoweredCircuit:
    ldx Zp_Chr04Bank_u8
_SetBankToX:
    main_chr0c x
    rts
.ENDPROC

;;; Mode for activating a circuit breaker device.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Nearby_bDevice holds an active breaker device.
.PROC MainA_Cutscene_FlipBreakerDevice
    lda Zp_Current_eRoom
    sta Zp_Breaker_eRoom
    ;; Set the spawn point and mark the breaker as being activated.
    jsr Func_SaveProgressAtActiveDevice  ; preserves X
    lda Ram_DeviceTarget_byte_arr, x
    sta Zp_BreakerBeingActivated_eFlag
    ;; Hide the floating HUD.
    lda Zp_FloatingHud_bHud
    ora #bHud::Hidden
    sta Zp_FloatingHud_bHud
    ;; Zero the player avatar's velocity, and fully heal them.
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    sta Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 1
    sta Zp_AvatarHarmTimer_u8
    sta Zp_AvatarState_bAvatar
    ;; Start the breaker cutscene.
    lda #eCutscene::SharedFlipBreaker
    sta Zp_Next_eCutscene
    jmp Main_Explore_Continue
.ENDPROC

;;; Mode for the circuit-tracing cutscene that plays when activating a breaker.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.PROC MainA_Cutscene_CircuitTrace
    jsr Func_FadeOutToBlack
_SetUpAudio:
    lda #eMusic::Silence
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    jsr FuncA_Cutscene_PlaySfxCircuitTrace
_ClearBackground:
    lda #eMmc3Mirror::Vertical
    sta Hw_Mmc3Mirroring_wo
    ldxy #Ppu_Nametable0_sName  ; param: nametable addr
    jsr FuncA_Cutscene_ClearNametableTiles
    ldy #$00  ; param: attribute byte
    jsr Func_FillUpperAttributeTable
_DrawInitialRocks:
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldx #15 - 1
    @loop:
    .assert >Ppu_Nametable0_sName .mod 4 = 0, error
    lda #>Ppu_Nametable0_sName >> 2
    sta T0
    txa  ; block row (0-15)
    .assert kScreenWidthTiles * 2 = $10 << 2, error
    mul #$10
    .repeat 2
    asl a
    rol T0
    .endrepeat
    ldy T0
    sty Hw_PpuAddr_w2
    ora _RockTileCol_u8_arr15, x
    sta Hw_PpuAddr_w2
    ldy #kTileIdBgCircuitTraceRocks
    sty Hw_PpuData_rw
    dex
    bpl @loop
_DrawInitialCircuitConduit:
    ldy #kTileIdBgAnimCircuitFirst + 4  ; param: tile ID
    lda #>Ppu_Nametable0_sName  ; param: nametable addr hi byte
    ldx #15  ; param: BG tile column index
    jsr FuncA_Cutscene_DirectDrawBgTileColumn
    ldy #kTileIdBgAnimCircuitFirst + 5  ; param: tile ID
    lda #>Ppu_Nametable0_sName  ; param: nametable addr hi byte
    ldx #16  ; param: BG tile column index
    jsr FuncA_Cutscene_DirectDrawBgTileColumn
_InitEnergyWaves:
    ;; This mode uses the avatar Y-position for storing the top of the main
    ;; energy wave.
    lda #200
    sta Zp_AvatarPosY_i16 + 0
    lda #0
    sta Zp_AvatarPosY_i16 + 1
    sta Zp_AvatarSubY_u8
_EnableRendering:
    lda #<.bank(Ppu_ChrBgAnimStatic)
    sta Zp_Chr04Bank_u8
    main_chr18_bank Ppu_ChrObjPause
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    ldx #0
    stx Zp_PpuScrollX_u8
    stx Zp_PpuScrollY_u8
    ;; This mode uses Zp_FrameCounter_u8 as its timer.  We start the timer on
    ;; $ff so that it will tick to zero on the first ProcessFrame.  Thereafter,
    ;; it will take on values from 0 inclusive to kCircuitTraceFrames exclusive
    ;; during each _GameLoop tick.
    dex  ; now X is $ff
    stx Zp_FrameCounter_u8
    ldy #eFade::Dark  ; param: eFade value
    jsr Func_SetAndTransferFade
_GameLoop:
    jsr FuncA_Cutscene_DrawCircuitTraceWaves
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr FuncA_Cutscene_TickCircuitTrace
    lda Zp_FrameCounter_u8
    cmp #kCircuitTraceFrames - 1
    blt _GameLoop
_Finish:
    jsr Func_FadeOutToBlack
    lda #eMmc3Mirror::Horizontal
    sta Hw_Mmc3Mirroring_wo
    jmp Main_Breaker_LoadCoreRoom
_RockTileCol_u8_arr15:
    .byte 10, 24,  4, 18,  2
    .byte 28,  7, 13, 22,  5
    .byte 25,  9, 19,  8, 20
.ENDPROC

;;; Performs per-frame updates for circuit-tracing mode.
.PROC FuncA_Cutscene_TickCircuitTrace
_ScrollVertically:
    lda Zp_PpuScrollY_u8
    sub #kCircuitTraceScrollSpeed
    bcs @setScroll
    adc #kScreenHeightPx  ; carry is already clear
    @setScroll:
    sta Zp_PpuScrollY_u8
_MoveEnergyWave:
    lda Zp_FrameCounter_u8
    cmp #kCircuitTraceSlowFrames
    bge @fastVel
    @slowVel:
    ldya #$ffff & -$0060
    bmi @applyVel  ; unconditional
    @fastVel:
    ldya #$ffff & -$02a0
    @applyVel:
    ;; This mode uses the avatar Y-position for storing the top of the main
    ;; energy wave.
    add Zp_AvatarSubY_u8
    sta Zp_AvatarSubY_u8
    tya  ; velocity (hi)
    adc Zp_AvatarPosY_i16 + 0
    sta Zp_AvatarPosY_i16 + 0
    lda #$ff
    adc Zp_AvatarPosY_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
_UpdateFade:
    ;; Set fade based on timer.
    lda Zp_FrameCounter_u8
    div #kCircuitTraceFadeSlowdown
    .assert kCircuitTraceFrames .mod kCircuitTraceFadeSlowdown = 0, error
    .linecont +
    cmp #(kCircuitTraceFrames / kCircuitTraceFadeSlowdown) - \
         (eFade::Normal - eFade::Black)
    .linecont -
    bge @fadeOut
    cmp #(eFade::Normal - eFade::Dark) + 1
    blt @fadeIn
    @fadeNormal:
    lda #eFade::Normal
    .assert eFade::Normal > 0, error
    bne @setFade  ; unconditional
    @fadeIn:
    add #eFade::Dark
    bne @setFade  ; unconditional
    @fadeOut:
    .assert kCircuitTraceFrames .mod kCircuitTraceFadeSlowdown = 0, error
    rsub #(kCircuitTraceFrames / kCircuitTraceFadeSlowdown) - 1
    @setFade:
    tay  ; param: eFade value
    jmp Func_SetAndTransferFade
.ENDPROC

;;; Sets up the CoreBossPowerUpCircuit cutscene, then jumps to
;;; Main_Explore_EnterRoom.
;;; @prereq Rendering is disabled.
.PROC MainA_Cutscene_EnterCoreBreakerRoom
    ;; Hide the player avatar.
    lda #eAvatar::Hidden
    sta Zp_AvatarPose_eAvatar
    ;; Set room scroll and lock scrolling.
    lda #$47
    sta Zp_RoomScrollY_u8
    ldax #$0090
    stax Zp_RoomScrollX_u16
    lda #bScroll::LockHorz | bScroll::LockVert
    sta Zp_Camera_bScroll
    ;; Set CHR banks for breaker circuits.
    main_chr00_bank Ppu_ChrBgAnimStatic
    main_chr0c_bank Ppu_ChrBgAnimStatic
    ;; Start the cutscene.
    lda #eCutscene::CoreBossPowerUpCircuit
    sta Zp_Next_eCutscene
    jmp Main_Explore_EnterRoom
.ENDPROC

;;; Sets Zp_Next_eCutscene for the breaker being activated, and returns the
;;; room that the cutscene takes place in and the music to play in that room.
;;; @return X The eRoom value for the cutscene room.
;;; @return Y The eMusic value for the music to play in the cutscene room.
.PROC FuncA_Cutscene_GetBreakerCutsceneRoomAndMusic
    ;; Set Y to the eBreaker value for the breaker that just got activated.
    lda Zp_BreakerBeingActivated_eFlag
    .assert kFirstBreakerFlag > 0, error
    sub #kFirstBreakerFlag
    tay  ; eBreaker value
    ;; Set up the cutscene.
    lda _Cutscene_eCutscene_arr, y
    sta Zp_Next_eCutscene
    ;; Return the eRoom value for the room the cutscene takes place in.
    ldx _Cutscene_eRoom_arr, y
    ldy #eMusic::Silence
    rts
_Cutscene_eRoom_arr:
    D_ARRAY .enum, eBreaker
    d_byte Garden, eRoom::MermaidHut1
    d_byte Temple, eRoom::PrisonUpper
    d_byte Crypt,  eRoom::MermaidHut1
    d_byte Lava,   eRoom::TownHouse4
    d_byte Mine,   eRoom::GardenShrine
    d_byte City,   eRoom::CityCenter
    d_byte Shadow, eRoom::CoreLock
    D_END
_Cutscene_eCutscene_arr:
    D_ARRAY .enum, eBreaker
    d_byte Garden, eCutscene::MermaidHut1BreakerGarden
    d_byte Temple, eCutscene::PrisonUpperBreakerTemple
    d_byte Crypt,  eCutscene::MermaidHut1BreakerCrypt
    d_byte Lava,   eCutscene::TownHouse4BreakerLava
    d_byte Mine,   eCutscene::GardenShrineBreakerMine
    d_byte City,   eCutscene::CityCenterBreakerCity
    d_byte Shadow, eCutscene::CoreLockBreakerShadow
    D_END
.ENDPROC

;;; Sets up the avatar and room scrolling for the current breaker's cutscene,
;;; then jumps to Main_Explore_EnterRoom.
;;; @prereq Rendering is disabled.
;;; @prereq Static room data is loaded.
.PROC MainA_Cutscene_EnterBreakerCutsceneRoom
    ;; Hide the player avatar.
    lda #eAvatar::Hidden
    sta Zp_AvatarPose_eAvatar
    ;; Set Y to the eBreaker value for the breaker that just got activated.
    lda Zp_BreakerBeingActivated_eFlag
    .assert kFirstBreakerFlag > 0, error
    sub #kFirstBreakerFlag
    tay  ; eBreaker value
    ;; Position the (hidden) player avatar so as to make the room scroll
    ;; position be what we want.  (We don't want to do this by locking
    ;; scrolling, because we want e.g. the vertical scroll to be able to shift
    ;; while the dialog window is open.)
    lda _AvatarPosX_i16_0_arr, y
    sta Zp_AvatarPosX_i16 + 0
    lda _AvatarPosX_i16_1_arr, y
    sta Zp_AvatarPosX_i16 + 1
    lda _AvatarPosY_i16_0_arr, y
    sta Zp_AvatarPosY_i16 + 0
    lda _AvatarPosY_i16_1_arr, y
    sta Zp_AvatarPosY_i16 + 1
    jmp Main_Explore_EnterRoom
_AvatarPosX_i16_0_arr:
    D_ARRAY .enum, eBreaker
    d_byte Garden, $a8
    d_byte Temple, $50
    d_byte Crypt,  $a8
    d_byte Lava,   $80
    d_byte Mine,   $88
    d_byte City,   $f0
    d_byte Shadow, $90
    D_END
_AvatarPosX_i16_1_arr:
    D_ARRAY .enum, eBreaker
    d_byte Garden, $00
    d_byte Temple, $01
    d_byte Crypt,  $00
    d_byte Lava,   $00
    d_byte Mine,   $00
    d_byte City,   $03
    d_byte Shadow, $00
    D_END
_AvatarPosY_i16_0_arr:
    D_ARRAY .enum, eBreaker
    d_byte Garden, $b8
    d_byte Temple, $b8
    d_byte Crypt,  $b8
    d_byte Lava,   $c8
    d_byte Mine,   $88
    d_byte City,   $58
    d_byte Shadow, $c8
    D_END
_AvatarPosY_i16_1_arr:
    D_ARRAY .enum, eBreaker
    d_byte Garden, $00
    d_byte Temple, $00
    d_byte Crypt,  $00
    d_byte Lava,   $00
    d_byte Mine,   $00
    d_byte City,   $01
    d_byte Shadow, $00
    D_END
.ENDPROC

;;; Fills the specified nametable with blank BG tiles.
;;; @prereq Rendering is disabled.
;;; @param XY The PPU address for the nametable to clear.
.PROC FuncA_Cutscene_ClearNametableTiles
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    .assert sName::Tiles_u8_arr = 0, error
    stx Hw_PpuAddr_w2
    sty Hw_PpuAddr_w2
    lda #' '
    ldxy #kScreenWidthTiles * kScreenHeightTiles
    @loop:
    sta Hw_PpuData_rw
    dey
    bne @loop
    dex
    bpl @loop
    rts
.ENDPROC

;;; Draws a column of BG tiles to the upper nametable.
;;; @prereq Rendering is disabled.
;;; @param X The BG tile column index (0-31).
;;; @param Y The BG tile ID to draw.
;;; @preserve Y, T0+
.PROC FuncA_Cutscene_DirectDrawBgTileColumn
    .assert (Ppu_Nametable0_sName + sName::Tiles_u8_arr) .mod $100 = 0, error
    lda #>(Ppu_Nametable0_sName + sName::Tiles_u8_arr)
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda #kPpuCtrlFlagsVert
    sta Hw_PpuCtrl_wo
    ldx #kScreenHeightTiles
    @loop:
    sty Hw_PpuData_rw
    dex
    bne @loop
    rts
.ENDPROC

;;; Draws all the energy waves for circuit-tracing mode.
.PROC FuncA_Cutscene_DrawCircuitTraceWaves
_MainEnergyWave:
    ;; If the main energy wave is not on-screen, don't drow it.
    lda Zp_AvatarPosY_i16 + 1
    bne @done
    ldx Zp_AvatarPosY_i16 + 0  ; param: Y-position
    lda Zp_FrameCounter_u8
    mod #4
    tay
    lda _MainWaveTileId_u8_arr4, y  ; param: tile ID
    jsr FuncA_Cutscene_DrawCircuitTraceWave
    @done:
_SecondaryEnergyWaves:
    lda Zp_FrameCounter_u8
    cmp #kCircuitTraceSlowFrames
    blt @slow
    mul #2
    @slow:
    mod #kTileHeightPx
    add #kScreenHeightPx - 8
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    @loop:
    ldx Zp_PointY_i16 + 0  ; param: Y-position
    lda #kTileIdObjCircuitWaveFirst + 0  ; param: tile ID
    jsr FuncA_Cutscene_DrawCircuitTraceWave
    lda #kTileHeightPx  ; param: offset
    jsr Func_MovePointUpByA
    lda Zp_PointY_i16 + 0
    cmp Zp_AvatarPosY_i16 + 0
    lda Zp_PointY_i16 + 1
    bne @done
    sbc Zp_AvatarPosY_i16 + 1
    bpl @loop
    @done:
    rts
_MainWaveTileId_u8_arr4:
    .byte kTileIdObjCircuitWaveFirst + 0
    .byte kTileIdObjCircuitWaveFirst + 1
    .byte kTileIdObjCircuitWaveFirst + 2
    .byte kTileIdObjCircuitWaveFirst + 1
.ENDPROC

;;; Draws a single energy wave for circuit-tracing mode.
;;; @param A The OBJ tile ID for the wave.
;;; @param X The screen Y-position of the top of the wave.
.PROC FuncA_Cutscene_DrawCircuitTraceWave
    cpx #kScreenHeightPx
    bge @done  ; object is off-screen
    pha  ; tile ID
    lda #2  ; param: num objects
    jsr Func_AllocObjects  ; preserves X and T0+, returns Y
    pla  ; tile ID
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    dex
    txa  ; Y-position
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    lda #kScreenWidthPx / 2 - kTileWidthPx
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    lda #kScreenWidthPx / 2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    lda #kPaletteObjCircuitWave | bObj::Pri
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Sets the avatar position and pose within the boss room for after a breaker
;;; cutscene, then jumps to Main_Explore_EnterRoom.
;;; @prereq Rendering is disabled.
;;; @prereq Static room data is loaded.
.PROC MainA_Avatar_EnterBossRoomAfterBreaker
    ldx Zp_BreakerBeingActivated_eFlag  ; param: eFlag value
    jsr Func_SetFlag
    lda #0
    sta Zp_BreakerBeingActivated_eFlag
    ;; Position the player avatar at the breaker device.
    ldy #kBossBreakerDeviceIndex  ; param: device index
    jsr FuncA_Avatar_SpawnAtDevice
    ;; Since the room's Enter function hasn't been called yet, the breaker
    ;; device is actually still a Placeholder device, which has a different
    ;; spawn offset than a breaker.  So correct the avatar's X-position within
    ;; the block.
    lda Zp_AvatarPosX_i16 + 0
    .assert kBlockWidthPx = $10, error
    and #$f0
    ora #kBreakerAvatarOffset
    sta Zp_AvatarPosX_i16 + 0
    ;; Make the player avatar start out kneeling as the room fades in (since
    ;; that was the pose the avatar was last in when the boss room faded out
    ;; for the breaker cutscene).
    lda #eAvatar::Kneeling
    sta Zp_AvatarPose_eAvatar
    jmp Main_Explore_EnterRoom
.ENDPROC

;;;=========================================================================;;;
