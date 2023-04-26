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
.INCLUDE "device.inc"
.INCLUDE "devices/breaker.inc"
.INCLUDE "flag.inc"
.INCLUDE "hud.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "music.inc"
.INCLUDE "oam.inc"
.INCLUDE "room.inc"
.INCLUDE "scroll.inc"
.INCLUDE "spawn.inc"
.INCLUDE "tileset.inc"

.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncM_SwitchPrgcAndLoadRoom
.IMPORT FuncM_SwitchPrgcAndLoadRoomWithMusic
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_FadeOutToBlack
.IMPORT Func_ProcessFrame
.IMPORT Func_SetFlag
.IMPORT Func_SetLastSpawnPointToNearbyDevice
.IMPORT Func_TickAllDevices
.IMPORT Main_BreakerCutscene_Garden
.IMPORT Main_Explore_EnterRoom
.IMPORT Main_Explore_FadeIn
.IMPORT Ppu_ChrBgAnimA0
.IMPORT Ppu_ChrBgAnimStatic
.IMPORT Ppu_ChrBgFontLower01
.IMPORT Ppu_ChrBgFontUpper
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarHarmTimer_u8
.IMPORTZP Zp_AvatarLanding_u8
.IMPORTZP Zp_AvatarMode_eAvatar
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarSubX_u8
.IMPORTZP Zp_AvatarSubY_u8
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_AvatarVelY_i16
.IMPORTZP Zp_Camera_bScroll
.IMPORTZP Zp_Chr0cBank_u8
.IMPORTZP Zp_Current_eRoom
.IMPORTZP Zp_FloatingHud_bHud
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_Nearby_bDevice
.IMPORTZP Zp_NextCutscene_main_ptr
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8

;;;=========================================================================;;;

;;; The durations of various breaker activation phases, in frames.
kBreakerReachFrames  = $90
kBreakerStrainFrames = 80
kBreakerFlipFrames   = kBreakerDoneDeviceAnimStart + 60

;;;=========================================================================;;;

;;; Phases of the breaker activation process.
.ENUM ePhase
    Adjust
    Reach
    Strain
    Flip
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

.ZEROPAGE

;;; The room that the breaker is in.
Zp_Breaker_eRoom: .res 1

;;; The flag for the breaker that's being activated.
.EXPORTZP Zp_BreakerBeingActivated_eFlag
Zp_BreakerBeingActivated_eFlag: .res 1

;;; Which phase of the breaker activation process we're currently in.
Zp_Breaker_ePhase: .res 1

;;; The number of remaining frames in the current breaker activation phase.
Zp_BreakerTimer_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for activating a circuit breaker.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Nearby_bDevice holds the index of a breaker device.
.EXPORT Main_Breaker_Activate
.PROC Main_Breaker_Activate
    jsr_prga FuncA_Breaker_InitActivate
_GameLoop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr Func_TickAllDevices
    jsr_prga FuncA_Breaker_TickActivate
    ;; Once we've finished the last phase, breaker activate mode is done.
    lda Zp_Breaker_ePhase
    cmp #ePhase::NUM_VALUES
    blt _GameLoop
    jsr Func_FadeOutToBlack
    .assert * = Main_Breaker_TraceCircuit, error, "fallthrough"
.ENDPROC

;;; Mode for the circuit-tracing cutscene that plays when activating a breaker.
;;; @prereq Rendering is disabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Breaker_TraceCircuit
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
    sta Zp_AvatarMode_eAvatar
    ;; Set room scroll and lock scrolling.
    lda #$48
    sta Zp_RoomScrollY_u8
    ldax #$0090
    stax Zp_RoomScrollX_u16
    lda #bScroll::LockHorz | bScroll::LockVert
    sta Zp_Camera_bScroll
    ;; Set CHR banks for breaker circuits.
    chr00_bank #<.bank(Ppu_ChrBgAnimStatic)
    chr04_bank #<.bank(Ppu_ChrBgAnimStatic)
    ;; Start the cutscene.
    ldax #Main_Breaker_PowerCoreCutscene
    stax Zp_NextCutscene_main_ptr
    jmp Main_Explore_EnterRoom
.ENDPROC

;;; Explore mode cutscene for showing the power core after a breaker is
;;; activated.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Breaker_PowerCoreCutscene
    lda #255
    sta Zp_BreakerTimer_u8
_GameLoop:
    ;; Update CHR0C bank (for animated terrain tiles).
    lda Zp_FrameCounter_u8
    div #4
    and #$07
    add #<.bank(Ppu_ChrBgAnimA0)
    sta Zp_Chr0cBank_u8
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
    ldx Zp_Chr0cBank_u8
    @setBank:
    chr04_bank x
    dec Zp_BreakerTimer_u8
    bne _GameLoop
_FadeOut:
    jsr Func_FadeOutToBlack
    ;; Restore CHR banks for window text.
    chr00_bank #<.bank(Ppu_ChrBgFontUpper)
    chr04_bank #<.bank(Ppu_ChrBgFontLower01)
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
    sta Zp_AvatarMode_eAvatar
    ;; TODO: set room scroll and lock scrolling
    jmp Main_Explore_FadeIn
.ENDPROC

;;; Mode for fading to black from a breaker cutscene and switching back to
;;; explore mode in the room the breaker was in.
;;; @prereq Rendering is enabled.
.EXPORT Main_Breaker_FadeBackToBreakerRoom
.PROC Main_Breaker_FadeBackToBreakerRoom
    jsr Func_FadeOutToBlack
    ;; Un-hide the player avatar.
    lda #eAvatar::Kneeling
    sta Zp_AvatarMode_eAvatar
    ;; Reload the room that the breaker was in.
    ldx Zp_Breaker_eRoom  ; param: room to load
    jsr FuncM_SwitchPrgcAndLoadRoom
    jmp Main_Explore_EnterRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Breaker"

;;; Initializes breaker mode.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Nearby_bDevice holds the index of a breaker device.
.PROC FuncA_Breaker_InitActivate
    lda Zp_Current_eRoom
    sta Zp_Breaker_eRoom
    ;; Set the spawn point and mark the breaker as activated.
    jsr Func_SetLastSpawnPointToNearbyDevice  ; preserves X
    lda Ram_DeviceTarget_u8_arr, x
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
    sta Zp_AvatarLanding_u8
    ;; Initialize the breaker mode's state machine.
    .assert ePhase::Adjust = 0, error
    sta Zp_Breaker_ePhase
    sta Zp_BreakerTimer_u8
    rts
.ENDPROC

;;; Performs per-frame updates for breaker activation mode.
;;; @prereq Zp_Nearby_bDevice holds the index of a breaker device.
.PROC FuncA_Breaker_TickActivate
    ldy Zp_Breaker_ePhase
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE ePhase
    d_entry table, Adjust, FuncA_Breaker_TickActivateAdjust
    d_entry table, Reach,  FuncA_Breaker_TickActivateReach
    d_entry table, Strain, FuncA_Breaker_TickActivateStrain
    d_entry table, Flip,   FuncA_Breaker_TickActivateFlip
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs per-frame updates for the "adjust" phase of breaker activation.
;;; In this phase, the player avatar's position is adjusted over several frames
;;; until it reaches a specific offset from the breaker device's position.
.PROC FuncA_Breaker_TickActivateAdjust
    lda #eAvatar::Looking
    sta Zp_AvatarMode_eAvatar
    lda Zp_AvatarPosX_i16 + 0
    and #$0f
    cmp #kBreakerAvatarOffset
    blt @adjustRight
    beq _FinishedAdjusting
    @adjustLeft:
    dec Zp_AvatarPosX_i16 + 0
    lda Zp_AvatarFlags_bObj
    ora #bObj::FlipH
    bne @setAdjustment  ; unconditional
    @adjustRight:
    inc Zp_AvatarPosX_i16 + 0
    lda Zp_AvatarFlags_bObj
    and #<~bObj::FlipH
    @setAdjustment:
    sta Zp_AvatarFlags_bObj
    lda #0
    sta Zp_AvatarSubX_u8
    rts
_FinishedAdjusting:
    ;; Make the player avatar face to the right.
    lda Zp_AvatarFlags_bObj
    and #<~bObj::FlipH
    sta Zp_AvatarFlags_bObj
    ;; Proceed to the next phase.
    lda #kBreakerReachFrames
    sta Zp_BreakerTimer_u8
    .assert ePhase::Reach = 1 + ePhase::Adjust, error
    inc Zp_Breaker_ePhase
    rts
.ENDPROC

;;; Performs per-frame updates for the "reach" phase of breaker activation.  In
;;; this phase, the player avatar reaches upward towards the breaker lever (but
;;; can't quite reach it).
.PROC FuncA_Breaker_TickActivateReach
    lda Zp_BreakerTimer_u8
    and #$30
    cmp #$20
    blt @looking
    bit Zp_BreakerTimer_u8
    .assert bProc::Overflow = $40, error
    bvc @straining
    @reaching:
    lda #eAvatar::Reaching
    bne @setAvatar  ; unconditional
    @straining:
    lda #eAvatar::Straining
    bne @setAvatar  ; unconditional
    @looking:
    lda #eAvatar::Looking
    @setAvatar:
    sta Zp_AvatarMode_eAvatar
_DecrementTimer:
    dec Zp_BreakerTimer_u8
    bne _Return
_FinishedReaching:
    lda #eAvatar::Straining
    sta Zp_AvatarMode_eAvatar
    ;; Proceed to the next phase.
    lda #kBreakerStrainFrames
    sta Zp_BreakerTimer_u8
    .assert ePhase::Strain = 1 + ePhase::Reach, error
    inc Zp_Breaker_ePhase
_Return:
    rts
.ENDPROC

;;; Performs per-frame updates for the "strain" phase of breaker activation.
;;; In this phase, the player avatar strains upward and wobbles as they try to
;;; reach the breaker lever.
;;; @prereq Zp_Nearby_bDevice holds the index of a breaker device.
.PROC FuncA_Breaker_TickActivateStrain
    ;; Make the avatar wobble horizontally.
    lda Zp_FrameCounter_u8
    and #$04
    beq @left
    @right:
    lda #kBreakerAvatarOffset
    .assert kBreakerAvatarOffset > 0, error
    bne @setPos  ; unconditional
    @left:
    lda #kBreakerAvatarOffset - 1
    @setPos:
    sta T0  ; wobble offset (0-15)
    lda Zp_AvatarPosX_i16 + 0
    and #$f0
    ora T0  ; wobble offset (0-15)
    sta Zp_AvatarPosX_i16 + 0
_DecrementTimer:
    dec Zp_BreakerTimer_u8
    bne _Return
_FinishedStraining:
    ;; Fix player avatar's X-position.
    lda Zp_AvatarPosX_i16 + 0
    and #$f0
    ora #kBreakerAvatarOffset
    sta Zp_AvatarPosX_i16 + 0
    ;; Flip the breaker.
    lda Zp_Nearby_bDevice
    and #bDevice::IndexMask
    tax  ; breaker device index
    lda #eDevice::BreakerDone
    sta Ram_DeviceType_eDevice_arr, x
    lda #kBreakerDoneDeviceAnimStart
    sta Ram_DeviceAnim_u8_arr, x
    ;; Proceed to the next phase.
    lda #kBreakerFlipFrames
    sta Zp_BreakerTimer_u8
    .assert ePhase::Flip = 1 + ePhase::Strain, error
    inc Zp_Breaker_ePhase
_Return:
    rts
.ENDPROC

;;; Performs per-frame updates for the "flip" phase of breaker activation.  In
;;; this phase, the player avatar grabs and pulls the breaker lever down.
;;; @prereq Zp_Nearby_bDevice holds the index of a breaker device.
.PROC FuncA_Breaker_TickActivateFlip
    ;; Animate the avatar to match the flipping breaker.
    lda Zp_Nearby_bDevice
    and #bDevice::IndexMask
    tax  ; breaker device index
    lda Ram_DeviceAnim_u8_arr, x
    div #8
    tay
    lda _AvatarMode_eAvatar_arr, y
    sta Zp_AvatarMode_eAvatar
    ;; Adjust the avatar's Y-position.
    lda Zp_AvatarPosY_i16 + 0
    and #$f0
    ora _AvatarOffsetY_u8_arr, y
    sta Zp_AvatarPosY_i16 + 0
    lda #0
    sta Zp_AvatarSubY_u8
_DecrementTimer:
    dec Zp_BreakerTimer_u8
    bne _Return
_FinishedFlipping:
    ;; Proceed to the next phase.
    .assert ePhase::NUM_VALUES = 1 + ePhase::Flip, error
    inc Zp_Breaker_ePhase
_Return:
    rts
_AvatarMode_eAvatar_arr:
    .byte eAvatar::Kneeling
    .byte eAvatar::Standing
    .byte eAvatar::Reaching
    .byte eAvatar::Straining
_AvatarOffsetY_u8_arr:
    .byte $08
    .byte $08
    .byte $08
    .byte $06
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
    ;; Set the cutscene pointer.
    lda _Cutscene_main_ptr_0_arr, y
    sta Zp_NextCutscene_main_ptr + 0
    lda _Cutscene_main_ptr_1_arr, y
    sta Zp_NextCutscene_main_ptr + 1
    ;; Return the eRoom value for the room the cutscene takes place in.
    ldx _Cutscene_eRoom_arr, y
    rts
_Cutscene_eRoom_arr:
    D_ENUM eBreaker
    d_byte Garden, eRoom::MermaidHut1
    d_byte Temple, eRoom::PrisonUpper
    d_byte Crypt,  eRoom::MermaidHut1  ; TODO
    d_byte Lava,   eRoom::MermaidHut1  ; TODO
    d_byte Mine,   eRoom::MermaidHut1  ; TODO
    d_byte City,   eRoom::MermaidHut1  ; TODO
    d_byte Shadow, eRoom::MermaidHut1  ; TODO
    D_END
.REPEAT 2, table
    D_TABLE_LO table, _Cutscene_main_ptr_0_arr
    D_TABLE_HI table, _Cutscene_main_ptr_1_arr
    D_TABLE eBreaker
    d_entry table, Garden, Main_BreakerCutscene_Garden
    d_entry table, Temple, Main_Breaker_FadeBackToBreakerRoom  ; TODO
    d_entry table, Crypt,  Main_Breaker_FadeBackToBreakerRoom  ; TODO
    d_entry table, Lava,   Main_Breaker_FadeBackToBreakerRoom  ; TODO
    d_entry table, Mine,   Main_Breaker_FadeBackToBreakerRoom  ; TODO
    d_entry table, City,   Main_Breaker_FadeBackToBreakerRoom  ; TODO
    d_entry table, Shadow, Main_Breaker_FadeBackToBreakerRoom  ; TODO
    D_END
.ENDREPEAT
.ENDPROC

;;;=========================================================================;;;
