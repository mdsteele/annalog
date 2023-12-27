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

.INCLUDE "avatar.inc"
.INCLUDE "cpu.inc"
.INCLUDE "cutscene.inc"
.INCLUDE "device.inc"
.INCLUDE "devices/breaker.inc"
.INCLUDE "flag.inc"
.INCLUDE "hud.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "music.inc"
.INCLUDE "oam.inc"
.INCLUDE "room.inc"
.INCLUDE "sample.inc"
.INCLUDE "scroll.inc"
.INCLUDE "spawn.inc"
.INCLUDE "tileset.inc"

.IMPORT FuncA_Cutscene_PlaySfxFlipBreaker
.IMPORT FuncM_SwitchPrgcAndLoadRoom
.IMPORT FuncM_SwitchPrgcAndLoadRoomWithMusic
.IMPORT Func_FadeOutToBlack
.IMPORT Func_PlaySfxSample
.IMPORT Func_ProcessFrame
.IMPORT Func_SetFlag
.IMPORT Func_SetLastSpawnPointToActiveDevice
.IMPORT Main_Explore_Continue
.IMPORT Main_Explore_EnterRoom
.IMPORT Ppu_ChrBgAnimA0
.IMPORT Ppu_ChrBgAnimStatic
.IMPORT Ppu_ChrBgFontLower
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr
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
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8

;;;=========================================================================;;;

;;; The durations of various breaker activation phases, in frames.
kBreakerReachFrames  = $90
kBreakerStrainFrames = 80
kBreakerFlipFrames   = kBreakerDoneDeviceAnimStart + 60

;;;=========================================================================;;;

.ZEROPAGE

;;; The room that the breaker is in.
Zp_Breaker_eRoom: .res 1

;;; The flag for the breaker that's being activated.
.EXPORTZP Zp_BreakerBeingActivated_eFlag
Zp_BreakerBeingActivated_eFlag: .res 1

;;; The number of remaining frames in the current breaker activation phase.
Zp_BreakerTimer_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for activating a circuit breaker device.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Nearby_bDevice holds an active breaker device.
.EXPORT Main_Breaker_UseDevice
.PROC Main_Breaker_UseDevice
    jmp_prga MainA_Breaker_FlipBreakerDevice
.ENDPROC

;;; Mode for the circuit-tracing cutscene that plays when activating a breaker.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Breaker_TraceCircuit
    jsr Func_FadeOutToBlack
    ;; TODO: implement this
    .assert * = Main_Breaker_LoadCoreRoom, error, "fallthrough"
.ENDPROC

;;; Mode to load the room for the power core cutscene that plays when
;;; activating a breaker.
;;; @prereq Rendering is disabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Breaker_LoadCoreRoom
    ;; Load the core room.
    ldx #eRoom::CoreBoss  ; param: room to load
    ldy #eMusic::Silence  ; param: music to play
    jsr FuncM_SwitchPrgcAndLoadRoomWithMusic
    ;; Hide the player avatar.
    lda #eAvatar::Hidden
    sta Zp_AvatarPose_eAvatar
    ;; Set room scroll and lock scrolling.
    lda #$48
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

;;; Explore mode cutscene for showing the power core after a breaker is
;;; activated.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Breaker_PowerCoreCutscene
    ;; TODO: move some/all of this into the cutscene
    lda #255
    sta Zp_BreakerTimer_u8
_GameLoop:
    ;; Update CHR04 bank (for animated terrain tiles).
    lda Zp_FrameCounter_u8
    div #4
    and #$07
    add #<.bank(Ppu_ChrBgAnimA0)
    sta Zp_Chr04Bank_u8
    jsr Func_ProcessFrame
_PowerUpCircuit:
    ;; TODO: split this up into phases
    lda Zp_BreakerTimer_u8
    sub #130
    blt @on
    cmp #64
    bge @off
    sta T1  ; 0-63
    and #$03
    sta T0  ; 0-3
    lda #63
    sub T1  ; 0-63
    div #16
    cmp T0  ; 0-3
    bge @on
    @off:
    ldx #<.bank(Ppu_ChrBgAnimStatic)
    .assert <.bank(Ppu_ChrBgAnimStatic) <> 0, error
    bne @setBank  ; unconditional
    @on:
    ldx Zp_Chr04Bank_u8
    @setBank:
    main_chr0c x
    dec Zp_BreakerTimer_u8
    bne _GameLoop
_FadeOut:
    jsr Func_FadeOutToBlack
    main_chr00_bank Ppu_ChrBgFontLower
    .assert * = Main_Breaker_LoadCutsceneRoom, error, "fallthrough"
.ENDPROC

;;; Mode to load the room for the breaker-specific cutscene that plays after
;;; activating a breaker.
;;; @prereq Rendering is disabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Breaker_LoadCutsceneRoom
    ;; Load the room where the cutscene takes place.
    jsr_prga FuncA_Breaker_GetCutsceneRoom  ; returns X
    ldy #eMusic::Silence  ; param: music to play
    jsr FuncM_SwitchPrgcAndLoadRoomWithMusic
    ;; Hide the player avatar.
    lda #eAvatar::Hidden
    sta Zp_AvatarPose_eAvatar
    ;; Set up the room scroll and fade in.
    jsr_prga FuncA_Breaker_InitCutsceneScroll
    jmp Main_Explore_EnterRoom
.ENDPROC

;;; Mode for fading to black from a breaker cutscene and switching back to
;;; explore mode in the room the breaker was in.
;;; @prereq Rendering is enabled.
.EXPORT Main_Breaker_FadeBackToBreakerRoom
.PROC Main_Breaker_FadeBackToBreakerRoom
    jsr Func_FadeOutToBlack
    ;; Un-hide the player avatar.
    lda #eAvatar::Kneeling
    sta Zp_AvatarPose_eAvatar
    ;; Reload the room that the breaker was in.
    ldx Zp_Breaker_eRoom  ; param: room to load
    jsr FuncM_SwitchPrgcAndLoadRoom
    jmp Main_Explore_EnterRoom
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
    act_WaitUntilZ _AnimateAvatarFlippingBreaker
    act_WaitFrames 60
    act_JumpToMain Main_Breaker_TraceCircuit
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
    lda Zp_FrameCounter_u8
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
    lda #eSample::Jump  ; param: eSample to play
    jmp Func_PlaySfxSample
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
    act_JumpToMain Main_Breaker_PowerCoreCutscene
.ENDPROC

.EXPORT DataA_Cutscene_SharedFadeBackToBreakerRoom_sCutscene
.PROC DataA_Cutscene_SharedFadeBackToBreakerRoom_sCutscene
    act_JumpToMain Main_Breaker_FadeBackToBreakerRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Breaker"

;;; Mode for activating a circuit breaker device.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Nearby_bDevice holds an active breaker device.
.PROC MainA_Breaker_FlipBreakerDevice
    lda Zp_Current_eRoom
    sta Zp_Breaker_eRoom
    ;; Set the spawn point and mark the breaker as activated.
    jsr Func_SetLastSpawnPointToActiveDevice  ; preserves X
    lda Ram_DeviceTarget_byte_arr, x
    sta Zp_BreakerBeingActivated_eFlag
    tax  ; param: eFlag value
    jsr Func_SetFlag
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

;;; Sets up the cutscene pointer and returns the room that the cutscene takes
;;; place in.
;;; @return X The eRoom value for the cutscene room.
.PROC FuncA_Breaker_GetCutsceneRoom
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
    rts
_Cutscene_eRoom_arr:
    D_ARRAY .enum, eBreaker
    d_byte Garden, eRoom::MermaidHut1
    d_byte Temple, eRoom::PrisonUpper
    d_byte Crypt,  eRoom::MermaidHut1
    d_byte Lava,   eRoom::MermaidHut1  ; TODO
    d_byte Mine,   eRoom::MermaidHut1  ; TODO
    d_byte City,   eRoom::MermaidHut1  ; TODO
    d_byte Shadow, eRoom::MermaidHut1  ; TODO
    D_END
_Cutscene_eCutscene_arr:
    D_ARRAY .enum, eBreaker
    d_byte Garden, eCutscene::MermaidHut1BreakerGarden
    d_byte Temple, eCutscene::PrisonUpperBreakerTemple
    d_byte Crypt,  eCutscene::MermaidHut1BreakerCrypt
    d_byte Lava,   eCutscene::SharedFadeBackToBreakerRoom  ; TODO
    d_byte Mine,   eCutscene::SharedFadeBackToBreakerRoom  ; TODO
    d_byte City,   eCutscene::SharedFadeBackToBreakerRoom  ; TODO
    d_byte Shadow, eCutscene::SharedFadeBackToBreakerRoom  ; TODO
    D_END
.ENDPROC

.PROC FuncA_Breaker_InitCutsceneScroll
    ;; Set Y to the eBreaker value for the breaker that just got activated.
    lda Zp_BreakerBeingActivated_eFlag
    .assert kFirstBreakerFlag > 0, error
    sub #kFirstBreakerFlag
    tay  ; eBreaker value
    ;; Set room scroll and lock scrolling.
    lda _ScrollX_u16_0_arr, y
    sta Zp_RoomScrollX_u16 + 0
    lda _ScrollX_u16_1_arr, y
    sta Zp_RoomScrollX_u16 + 1
    lda #bScroll::LockHorz
    sta Zp_Camera_bScroll
    rts
_ScrollX_u16_0_arr:
    D_ARRAY .enum, eBreaker
    d_byte Garden, $00
    d_byte Temple, $d0
    d_byte Crypt,  $00
    d_byte Lava,   $00  ; TODO
    d_byte Mine,   $00  ; TODO
    d_byte City,   $00  ; TODO
    d_byte Shadow, $00  ; TODO
    D_END
_ScrollX_u16_1_arr:
    D_ARRAY .enum, eBreaker
    d_byte Garden, $00
    d_byte Temple, $00
    d_byte Crypt,  $00
    d_byte Lava,   $00  ; TODO
    d_byte Mine,   $00  ; TODO
    d_byte City,   $00  ; TODO
    d_byte Shadow, $00  ; TODO
    D_END
.ENDPROC

;;;=========================================================================;;;
