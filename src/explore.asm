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
.INCLUDE "charmap.inc"
.INCLUDE "cpu.inc"
.INCLUDE "cutscene.inc"
.INCLUDE "device.inc"
.INCLUDE "fade.inc"
.INCLUDE "hud.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "spawn.inc"
.INCLUDE "tileset.inc"

.IMPORT FuncA_Actor_TickAllDevicesAndActors
.IMPORT FuncA_Avatar_EnterRoomViaDoor
.IMPORT FuncA_Avatar_EnterRoomViaPassage
.IMPORT FuncA_Avatar_ExitRoomViaPassage
.IMPORT FuncA_Avatar_ExploreMove
.IMPORT FuncA_Avatar_PickUpFlowerDevice
.IMPORT FuncA_Avatar_SpawnAtLastSafePoint
.IMPORT FuncA_Avatar_ToggleFloatingHud
.IMPORT FuncA_Avatar_ToggleLeverDevice
.IMPORT FuncA_Machine_ExecuteAll
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawAllActors
.IMPORT FuncA_Objects_DrawAllDevices
.IMPORT FuncA_Objects_DrawAllMachines
.IMPORT FuncA_Objects_DrawFloatingHud
.IMPORT FuncA_Objects_DrawPlayerAvatar
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeVert
.IMPORT FuncA_Objects_SetShapePosToAvatarCenter
.IMPORT FuncA_Room_CallRoomTick
.IMPORT FuncA_Room_InitAllMachinesAndCallRoomEnter
.IMPORT FuncA_Terrain_DirectDrawWindowTopBorder
.IMPORT FuncA_Terrain_InitRoomScrollAndNametables
.IMPORT FuncM_DrawObjectsForRoomAndProcessFrame
.IMPORT FuncM_ScrollTowardsAvatar
.IMPORT FuncM_SwitchPrgcAndLoadRoom
.IMPORT Func_ClearRestOfOam
.IMPORT Func_FadeInFromBlackToGoal
.IMPORT Func_FadeOutToBlack
.IMPORT Func_FindDeviceNearPoint
.IMPORT Func_SaveProgressAtActiveDevice
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Func_Window_Disable
.IMPORT Func_Window_SetUpIrq
.IMPORT Main_Breaker_UseDevice
.IMPORT Main_Console_UseDevice
.IMPORT Main_Cutscene_Start
.IMPORT Main_Death
.IMPORT Main_Dialog_UseDevice
.IMPORT Main_FakeConsole_UseDevice
.IMPORT Main_Paper_UseDevice
.IMPORT Main_Pause_FadeIn
.IMPORT Main_Upgrade_UseDevice
.IMPORT Ppu_ChrBgAnimA0
.IMPORT Ppu_ChrObjAnnaFlower
.IMPORT Ppu_ChrObjAnnaNormal
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_LastSafe_eRoom
.IMPORTZP Zp_AvatarExit_ePassage
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarHarmTimer_u8
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_CarryingFlower_eFlag
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_Current_eRoom
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_GoalBg_eFade
.IMPORTZP Zp_GoalObj_eFade
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8

;;;=========================================================================;;;

;;; If the player avatar is swimming this many pixels or more below the surface
;;; of the water, then interactive devices can't be used.  The particular value
;;; chosen here is the smallest such that the ceiling lever in the
;;; MermaidSpring room can still be used while the pump water height is at Y=1.
kDeviceWaterDepthLimit = 4

;;; The OBJ palette number and tile ID used for the visual prompt that appears
;;; when the player avatar is near a device.
kPaletteObjDevicePrompt = 1
kTileIdObjDevicePrompt = 'H'

;;;=========================================================================;;;

.ZEROPAGE

;;; Information about the (interactive) device that the player avatar is near,
;;; if any.
.EXPORTZP Zp_Nearby_bDevice
Zp_Nearby_bDevice: .res 1

;;; If not eCutscene::None, then explore mode will start this cutscene (and set
;;; this variable back to eCutscene::None) just before it would draw the next
;;; frame.
.EXPORTZP Zp_Next_eCutscene
Zp_Next_eCutscene: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for exploring and platforming within a room, when spawning into the
;;; room from the last safe spawn point (either a passage or a device).
;;; @prereq Rendering is disabled.
.EXPORT Main_Explore_SpawnInLastSafeRoom
.PROC Main_Explore_SpawnInLastSafeRoom
    lda #$ff
    sta Zp_Current_eRoom
    ldx Sram_LastSafe_eRoom  ; param: room to load
    jsr FuncM_SwitchPrgcAndLoadRoom
    jsr_prga FuncA_Avatar_SpawnAtLastSafePoint
    fall Main_Explore_EnterRoom
.ENDPROC

;;; Mode for exploring and platforming within a room, for when the room has
;;; been loaded and the player avatar positioned within the room, but the
;;; room's Enter_func_ptr has not yet been called.
;;; @prereq Rendering is disabled.
;;; @prereq Static room data is loaded and avatar is positioned.
.EXPORT Main_Explore_EnterRoom
.PROC Main_Explore_EnterRoom
    jsr_prga FuncA_Room_InitAllMachinesAndCallRoomEnter
    fall Main_Explore_FadeIn
.ENDPROC

;;; Mode for exploring and platforming within a room, when continuing after
;;; the pause screen (or when the room is otherwise loaded, but with the screen
;;; faded out).
;;; @prereq Rendering is disabled.
;;; @prereq Room is loaded and avatar is positioned.
.EXPORT Main_Explore_FadeIn
.PROC Main_Explore_FadeIn
    jsr Func_Window_Disable
    jsr_prga FuncA_Terrain_SetUpExploreBackground  ; sets Zp_Goal*_eFade
    jsr_prga FuncA_Avatar_FadeIn
    jsr FuncM_DrawObjectsForRoom  ; sets Zp_Render_bPpuMask and scrolling
    jsr Func_ClearRestOfOam
    jsr Func_FadeInFromBlackToGoal
    fall Main_Explore_Continue
.ENDPROC

;;; Mode for exploring and platforming within a room, when continuing after
;;; e.g. closing a window.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
.EXPORT Main_Explore_Continue
.PROC Main_Explore_Continue
_GameLoop:
    ;; Check if we need to start a cutscene:
    ldx Zp_Next_eCutscene  ; param: eCutscene value
    .assert eCutscene::None = 0, error
    jne Main_Cutscene_Start
    ;; Draw this frame:
    jsr FuncM_DrawObjectsForRoomAndProcessFrame
_CheckButtons:
    jsr_prga FuncA_Avatar_ExploreCheckButtons  ; returns C, X, and T1T0
    bcs @continueExploring
    jmp (T1T0)
    @continueExploring:
_Tick:
    jsr FuncM_ScrollTowardsAvatar
    jsr_prga FuncA_Actor_TickAllDevicesAndActors
    jsr_prga FuncA_Machine_ExecuteAll
    jsr_prga FuncA_Room_CallRoomTick
    ;; Check if the player avatar is dead:
    lda Zp_AvatarHarmTimer_u8
    cmp #kAvatarHarmDeath
    jeq Main_Death
    ;; Move the avatar and check if we've gone through a passage:
    jsr_prga FuncA_Avatar_ExploreMove
    lda Zp_AvatarExit_ePassage
    .assert ePassage::None = 0, error
    beq _GameLoop
    fall Main_Explore_GoThroughPassage
.ENDPROC

;;; Mode for leaving the current room through a passage and entering the next
;;; room.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @param A The ePassage value for the side of the room the player hit.
.PROC Main_Explore_GoThroughPassage
_FadeOut:
    pha  ; ePassage value
    jsr FuncM_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_FadeOutToBlack
    pla  ; ePassage value
_LoadNextRoom:
    tay  ; param: ePassage value
    jsr_prga FuncA_Avatar_CalculatePassage  ; returns A
    pha  ; origin bPassage value (calculated)
    tax  ; param: origin bPassage value (calculated)
    jsr FuncA_Avatar_ExitRoomViaPassage  ; returns X (eRoom) and A (block)
    pha  ; origin SpawnBlock_u8
    jsr FuncM_SwitchPrgcAndLoadRoom
    pla  ; origin SpawnBlock_u8
    tay  ; param: origin SpawnBlock_u8
    pla  ; origin bPassage value (calculated)
    tax  ; param: origin bPassage value (calculated)
    jsr_prga FuncA_Avatar_EnterRoomViaPassage
_FadeIn:
    jmp Main_Explore_EnterRoom
.ENDPROC

;;; Mode for leaving the current room through a door device and entering the
;;; next room.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @prereq Zp_Nearby_bDevice holds an active door device.
.PROC Main_Explore_GoThroughDoor
_FadeOut:
    jsr FuncM_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_FadeOutToBlack
_LoadNextRoom:
    lda Zp_Nearby_bDevice
    and #bDevice::IndexMask
    tay  ; door device index
    lda Ram_DeviceType_eDevice_arr, y
    pha  ; origin door device type
    ldx Ram_DeviceTarget_byte_arr, y  ; param: room to load
    jsr FuncM_SwitchPrgcAndLoadRoom
    pla  ; origin door device type
    tax  ; param: origin door device type
    jsr_prga FuncA_Avatar_EnterRoomViaDoor
_FadeIn:
    jmp Main_Explore_EnterRoom
.ENDPROC

;;; Draws objects in the current room that should always be visible, such as
;;; the player avatar, machines, enemies, and devices.
.EXPORT FuncM_DrawObjectsForRoom
.PROC FuncM_DrawObjectsForRoom
    jmp_prga FuncA_Objects_DrawObjectsForRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Handles non-movement button presses (B/Select/Start) for explore mode.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @return C If cleared, T1T0 holds a pointer to the next main to jump to.
;;; @return T1T0 The next main to jump to, if any.
;;; @return X An argument for the new mode, if any.
.PROC FuncA_Avatar_ExploreCheckButtons
    ;; Update Zp_Nearby_bDevice.  This must happen before calling
    ;; FuncA_Avatar_ToggleFloatingHud and also before checking for device
    ;; activations.
    jsr FuncA_Avatar_FindNearbyDevice
_CheckForToggleHud:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Select
    beq @done
    jsr FuncA_Avatar_ToggleFloatingHud
    @done:
_CheckForPause:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    beq @done
    jsr Func_FadeOutToBlack
    ldya #Main_Pause_FadeIn
    bmi _ReturnYA  ; unconditional
    @done:
_CheckForActivateDevice:
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::BButton = bProc::Overflow, error
    bvc _ContinueExploring  ; B button not pressed
    lda Zp_Nearby_bDevice
    .assert bDevice::NoneNearby = bProc::Negative, error
    bmi _ContinueExploring  ; no nearby device
    ora #bDevice::Active
    sta Zp_Nearby_bDevice
    and #bDevice::IndexMask
    tax  ; param: device index
    ldy Ram_DeviceType_eDevice_arr, x
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eDevice
    d_entry table, None,           _ContinueExploring
    d_entry table, Boiler,         _ContinueExploring
    d_entry table, BreakerDone,    _ContinueExploring
    d_entry table, BreakerRising,  _ContinueExploring
    d_entry table, Door1Locked,    _ContinueExploring
    d_entry table, FlowerInert,    _ContinueExploring
    d_entry table, Mousehole,      _ContinueExploring
    d_entry table, Placeholder,    _ContinueExploring
    d_entry table, Teleporter,     _ContinueExploring
    d_entry table, BreakerReady,   _DeviceBreaker
    d_entry table, ConsoleCeiling, _DeviceConsole
    d_entry table, ConsoleFloor,   _DeviceConsole
    d_entry table, Door1Open,      _DeviceDoor
    d_entry table, Door1Unlocked,  _DeviceDoor
    d_entry table, Door2Open,      _DeviceDoor
    d_entry table, Door3Open,      _DeviceDoor
    d_entry table, FakeConsole,    _DeviceFakeConsole
    d_entry table, Flower,         _DeviceFlower
    d_entry table, LeverCeiling,   _DeviceLever
    d_entry table, LeverFloor,     _DeviceLever
    d_entry table, Paper,          _DevicePaper
    d_entry table, ScreenCeiling,  _DeviceDialog
    d_entry table, ScreenGreen,    _DeviceDialog
    d_entry table, ScreenRed,      _DeviceDialog
    d_entry table, Sign,           _DeviceDialog
    d_entry table, TalkLeft,       _DeviceDialog
    d_entry table, TalkRight,      _DeviceDialog
    d_entry table, Upgrade,        _DeviceUpgrade
    D_END
.ENDREPEAT
_DeviceBreaker:
    ldya #Main_Breaker_UseDevice
_ReturnYA:
    stya T1T0
    clc  ; clear C to indicate that T1T0 points to the main to jump to
    rts
_DeviceFlower:
    jsr FuncA_Avatar_PickUpFlowerDevice
_ContinueExploring:
    sec  ; set C to indicate that explore mode should continue
    rts
_DeviceConsole:
    ldya #Main_Console_UseDevice
    bmi _ReturnYA  ; unconditional
_DeviceFakeConsole:
    ldya #Main_FakeConsole_UseDevice
    bmi _ReturnYA  ; unconditional
_DeviceDoor:
    lda #eAvatar::Reading
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvc @setPose  ; not swimming
    lda #eAvatar::SwimDoor
    @setPose:
    sta Zp_AvatarPose_eAvatar
    ;; We'll soon be setting the entrance door in the destination room as the
    ;; spawn point, but first we set the exit door in the current room as the
    ;; spawn point, in case this room is safe and the destination room is not.
    jsr Func_SaveProgressAtActiveDevice
    ldya #Main_Explore_GoThroughDoor
    bmi _ReturnYA  ; unconditional
_DevicePaper:
    ldya #Main_Paper_UseDevice
    bmi _ReturnYA  ; unconditional
_DeviceDialog:
    ldya #Main_Dialog_UseDevice
    bmi _ReturnYA  ; unconditional
_DeviceUpgrade:
    ldya #Main_Upgrade_UseDevice
    bmi _ReturnYA  ; unconditional
_DeviceLever:
    stx Zp_Nearby_bDevice  ; clear bDevice::Active
    jsr FuncA_Avatar_ToggleLeverDevice
    sec  ; set C to indicate that explore mode should continue
    rts
.ENDPROC

;;; Calculates a bPassage value from an ePassage and the avatar's position.
;;; @param Y The ePassage value for the side of the room the player hit.
;;; @return A The calculated bPassage value.
.PROC FuncA_Avatar_CalculatePassage
    tya  ; ePassage value
    .assert bPassage::EastWest = bProc::Negative, error
    bpl _UpDownPassage
_EastWestPassage:
    bit Zp_Current_sRoom + sRoom::Flags_bRoom
    .assert bRoom::Tall = bProc::Overflow, error
    bvc @upperHalf
    @tall:
    lda Zp_AvatarPosY_i16 + 1
    bmi @upperHalf
    bne @lowerHalf
    lda Zp_AvatarPosY_i16 + 0
    cmp #(kTallRoomHeightBlocks / 2) * kBlockHeightPx
    bge @lowerHalf
    @upperHalf:
    tya  ; ePassage value
    bne @done  ; unconditional
    @lowerHalf:
    tya  ; ePassage value
    ora #1
    @done:
    rts
_UpDownPassage:
    ;; Calculate which horizontal screen of the room the player avatar is in
    ;; (in other words, the hi byte of (avatar position - min scroll X) in room
    ;; pixel coordinates), storing the result in A.
    lda Zp_AvatarPosX_i16 + 0
    cmp Zp_Current_sRoom + sRoom::MinScrollX_u8
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    ;; Construct the bPassage value from the screen number and ePassage value.
    and #bPassage::ScreenMask
    sty T0  ; ePassage value
    ora T0
    rts
.ENDPROC

;;; Sets up the player avatar for when fading in the screen for explore mode,
;;; e.g. when first entering a room or when unpausing.
.PROC FuncA_Avatar_FadeIn
    ldx #<.bank(Ppu_ChrObjAnnaNormal)
    lda Zp_CarryingFlower_eFlag
    beq @setBank
    ldx #<.bank(Ppu_ChrObjAnnaFlower)
    @setBank:
    main_chr10 x
    fall FuncA_Avatar_FindNearbyDevice
.ENDPROC

;;; Sets Zp_Nearby_bDevice with the index of the (interactive) device that the
;;; player avatar is near (if any), or sets bDevice::NoneNearby if the avatar
;;; is not near an interactive device.
.PROC FuncA_Avatar_FindNearbyDevice
    ;; If the player avatar is hidden, treat them as not near any device.
    lda Zp_AvatarPose_eAvatar
    .assert eAvatar::Hidden = 0, error
    beq @noneNearby
    ;; If the player avatar is airborne, treat them as not near any device.
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Airborne = bProc::Negative, error
    bmi @noneNearby
    ;; If the player is swimming below the surface of the water, treat them as
    ;; not near any device.
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvc @notSwimming
    lda Zp_AvatarState_bAvatar
    and #bAvatar::DepthMask
    cmp #kDeviceWaterDepthLimit
    bge @noneNearby
    @notSwimming:
    ;; Check if there's a device nearby.
    jsr Func_SetPointToAvatarCenter
    jsr Func_FindDeviceNearPoint  ; returns N and Y
    bmi @noneNearby
    ;; Check if the nearby device is interactive.
    lda Ram_DeviceType_eDevice_arr, y
    cmp #kFirstInteractiveDeviceType
    bge @done
    @noneNearby:
    ldy #bDevice::NoneNearby
    @done:
    sty Zp_Nearby_bDevice
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; Sets CHR banks and draws all background tiles necessary for fading in
;;; explore mode, including drawing room terrain at the initial scroll
;;; position, drawing the top border of the window, and calling the room's
;;; FadeIn function.
;;; @prereq Rendering is disabled.
;;; @prereq Room is loaded and avatar is positioned.
.PROC FuncA_Terrain_SetUpExploreBackground
    main_chr08 Zp_Current_sTileset + sTileset::Chr08Bank_u8
    main_chr18 Zp_Current_sRoom + sRoom::Chr18Bank_u8
    ;; Fade in to normal brightness by default, but a room's FadeIn function
    ;; can override this.
    lda #eFade::Normal
    sta Zp_GoalBg_eFade
    sta Zp_GoalObj_eFade
    jsr FuncA_Terrain_InitRoomScrollAndNametables
    jmp FuncA_Terrain_DirectDrawWindowTopBorder
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws objects in the current room that should always be visible, such as
;;; the player avatar, machines, enemies, and devices.
.EXPORT FuncA_Objects_DrawObjectsForRoom
.PROC FuncA_Objects_DrawObjectsForRoom
    ;; Set up PPU scrolling and IRQ.  A room's draw function can optionally
    ;; override this if it needs its own IRQ behavior.
    lda Zp_RoomScrollX_u16 + 0
    sta Zp_PpuScrollX_u8
    lda Zp_RoomScrollY_u8
    sta Zp_PpuScrollY_u8
    jsr Func_Window_SetUpIrq
    ;; Update CHR04 bank (for animated terrain).  A room's draw function can
    ;; optionally override this if it needs its own animation behavior.
    lda Zp_FrameCounter_u8
    div #4
    and #$07
    add #<.bank(Ppu_ChrBgAnimA0)
    sta Zp_Chr04Bank_u8
    ;; Draw objects.
    jsr FuncA_Objects_DrawFloatingHud
    jsr FuncA_Objects_DrawPlayerAvatar
    jsr FuncA_Objects_DrawDevicePrompt
    jsr FuncA_Objects_DrawAllActors
    jsr FuncA_Objects_DrawAllMachines
    jsr FuncA_Objects_CallRoomDraw
    jmp FuncA_Objects_DrawAllDevices
.ENDPROC

;;; Calls the current room's Draw_func_ptr function.
.PROC FuncA_Objects_CallRoomDraw
    ldy #sRoomExt::Draw_func_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    jmp (T1T0)
.ENDPROC

;;; Allocates and populates OAM slots for the visual prompt that appears when
;;; the player avatar is near a device.
.PROC FuncA_Objects_DrawDevicePrompt
    lda Zp_Nearby_bDevice
    and #bDevice::NoneNearby | bDevice::Active
    bne _NotVisible
_DrawObject:
    jsr FuncA_Objects_SetShapePosToAvatarCenter
    jsr FuncA_Objects_MoveShapeLeftHalfTile
    ;; Calculate the Y-offset and adjust Y-position:
    lda Zp_FrameCounter_u8
    div #8
    and #$03
    cmp #$03
    bne @noZigZag
    lda #$01
    @noZigZag:
    bit Zp_AvatarFlags_bObj
    .assert bObj::FlipV = bProc::Negative, error
    bpl @normalGravity
    @reverseGravity:
    add #3 + kTileHeightPx
    bne @moveShape  ; unconditional
    @normalGravity:
    sub #5 + kTileHeightPx * 2  ; param: signed offset
    @moveShape:
    jsr FuncA_Objects_MoveShapeVert
    ;; Draw the object:
    ldy #kPaletteObjDevicePrompt  ; param: object flags
    lda #kTileIdObjDevicePrompt  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
_NotVisible:
    rts
.ENDPROC

;;;=========================================================================;;;
