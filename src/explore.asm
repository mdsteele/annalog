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
.INCLUDE "hud.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "spawn.inc"
.INCLUDE "terrain.inc"
.INCLUDE "tileset.inc"

.IMPORT FuncA_Actor_TickAllActors
.IMPORT FuncA_Avatar_EnterRoomViaDoor
.IMPORT FuncA_Avatar_EnterRoomViaPassage
.IMPORT FuncA_Avatar_ExitRoomViaPassage
.IMPORT FuncA_Avatar_ExploreMove
.IMPORT FuncA_Avatar_SpawnAtLastSafePoint
.IMPORT FuncA_Machine_ExecuteAll
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawAllActors
.IMPORT FuncA_Objects_DrawAllDevices
.IMPORT FuncA_Objects_DrawAllMachines
.IMPORT FuncA_Objects_DrawFloatingHud
.IMPORT FuncA_Objects_DrawPlayerAvatar
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_SetShapePosToAvatarCenter
.IMPORT FuncA_Room_CallRoomTick
.IMPORT FuncA_Room_InitAllMachinesAndCallRoomEnter
.IMPORT FuncA_Room_PickUpFlowerDevice
.IMPORT FuncA_Terrain_InitRoomScrollAndNametables
.IMPORT FuncA_Terrain_ScrollTowardsAvatar
.IMPORT FuncM_SwitchPrgcAndLoadRoom
.IMPORT Func_ClearRestOfOam
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_FadeInFromBlack
.IMPORT Func_FadeOutToBlack
.IMPORT Func_SetLastSpawnPoint
.IMPORT Func_TickAllDevices
.IMPORT Func_ToggleLeverDevice
.IMPORT Func_Window_DirectDrawTopBorder
.IMPORT Func_Window_Disable
.IMPORT Func_Window_SetUpIrq
.IMPORT Main_Breaker_Activate
.IMPORT Main_Console_UseDevice
.IMPORT Main_Death
.IMPORT Main_Dialog_OpenWindow
.IMPORT Main_Pause
.IMPORT Main_Upgrade_OpenWindow
.IMPORT Ppu_ChrBgAnimA0
.IMPORT Ram_DeviceBlockCol_u8_arr
.IMPORT Ram_DeviceBlockRow_u8_arr
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_LastSafe_eRoom
.IMPORTZP Zp_AvatarAirborne_bool
.IMPORTZP Zp_AvatarExit_ePassage
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarHarmTimer_u8
.IMPORTZP Zp_AvatarMode_eAvatar
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarWaterDepth_u8
.IMPORTZP Zp_Chr0cBank_u8
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_FloatingHud_bHud
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8

;;;=========================================================================;;;

;;; The OBJ palette number and tile ID used for the visual prompt that appears
;;; when the player avatar is near a device.
kPaletteObjDevicePrompt = 1
kTileIdObjDevicePrompt = $09

;;;=========================================================================;;;

.ZEROPAGE

;;; The index of the (interactive) device that the player avatar is near, or
;;; $ff if none.
Zp_NearbyDevice_u8: .res 1

;;; If set to a PRG ROM address ($8000+), e.g. by a dialog function or a room
;;; or machine tick function, then explore mode will jump to this mode (and
;;; zero this variable) just before it would draw the next frame.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
.EXPORTZP Zp_NextCutscene_main_ptr
Zp_NextCutscene_main_ptr: .res 2

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for exploring and platforming within a room, when spawning into the
;;; room from the last safe spawn point (either a passage or a device).
;;; @prereq Rendering is disabled.
.EXPORT Main_Explore_SpawnInLastSafeRoom
.PROC Main_Explore_SpawnInLastSafeRoom
    ldx Sram_LastSafe_eRoom  ; param: room number
    jsr FuncM_SwitchPrgcAndLoadRoom
    jsr_prga FuncA_Avatar_SpawnAtLastSafePoint
    .assert * = Main_Explore_EnterRoom, error, "fallthrough"
.ENDPROC

;;; Mode for exploring and platforming within a room, for when the room has
;;; been loaded and the player avatar positioned within the room, but the
;;; room's Enter_func_ptr has not yet been called.
;;; @prereq Rendering is disabled.
.EXPORT Main_Explore_EnterRoom
.PROC Main_Explore_EnterRoom
    jsr_prga FuncA_Room_InitAllMachinesAndCallRoomEnter
    .assert * = Main_Explore_FadeIn, error, "fallthrough"
.ENDPROC

;;; Mode for exploring and platforming within a room, when continuing after
;;; the pause screen (or when the room is otherwise loaded, but with the screen
;;; faded out).
;;; @prereq Rendering is disabled.
;;; @prereq Room is loaded and avatar is positioned.
.EXPORT Main_Explore_FadeIn
.PROC Main_Explore_FadeIn
    jsr Func_Window_Disable
    jsr Func_Window_DirectDrawTopBorder
    chr08_bank <(Zp_Current_sTileset + sTileset::Chr08Bank_u8)
    chr18_bank <(Zp_Current_sRoom + sRoom::Chr18Bank_u8)
    jsr_prga FuncA_Terrain_InitRoomScrollAndNametables
    jsr_prga FuncA_Avatar_FindNearbyDevice
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    ;; Zp_Render_bPpuMask will be set by FuncA_Objects_DrawObjectsForRoom.
    jsr Func_FadeInFromBlack
    .assert * = Main_Explore_Continue, error, "fallthrough"
.ENDPROC

;;; Mode for exploring and platforming within a room, when continuing after
;;; e.g. closing a window.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
.EXPORT Main_Explore_Continue
.PROC Main_Explore_Continue
_GameLoop:
    ;; Check if we need to start a cutscene:
    lda Zp_NextCutscene_main_ptr + 1
    bpl @noCutscene
    sta T1
    lda Zp_NextCutscene_main_ptr + 0
    sta T0
    lda #0
    sta Zp_NextCutscene_main_ptr + 0
    sta Zp_NextCutscene_main_ptr + 1
    jmp (T1T0)
    @noCutscene:
    ;; Draw this frame:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
_CheckForToggleHud:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Select
    beq @done
    bit Zp_FloatingHud_bHud
    .assert bHud::NoMachine = bProc::Overflow, error
    bvs @done
    lda Zp_FloatingHud_bHud
    eor #bHud::Hidden
    sta Zp_FloatingHud_bHud
    @done:
_CheckForPause:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    beq @done
    jsr Func_FadeOutToBlack
    jmp Main_Pause
    @done:
.PROC _CheckForActivateDevice
    jsr_prga FuncA_Avatar_FindNearbyDevice
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::BButton = bProc::Overflow, error
    bvc _DoneWithDevice
    ldx Zp_NearbyDevice_u8  ; param: device index
    bmi _DoneWithDevice
    ldy Ram_DeviceType_eDevice_arr, x
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eDevice
    d_entry table, None,          _DoneWithDevice
    d_entry table, BreakerDone,   _DoneWithDevice
    d_entry table, BreakerRising, _DoneWithDevice
    d_entry table, FlowerInert,   _DoneWithDevice
    d_entry table, LockedDoor,    _DoneWithDevice
    d_entry table, Placeholder,   _DoneWithDevice
    d_entry table, Teleporter,    _DoneWithDevice
    d_entry table, BreakerReady,  Main_Explore_UseBreaker
    d_entry table, Console,       Main_Console_UseDevice
    d_entry table, Flower,        _DeviceFlower
    d_entry table, LeverCeiling,  _DeviceLever
    d_entry table, LeverFloor,    _DeviceLever
    d_entry table, OpenDoorway,   Main_Explore_GoThroughDoor
    d_entry table, Paper,         _DeviceSign
    d_entry table, Sign,          _DeviceSign
    d_entry table, TalkLeft,      _DeviceTalkLeft
    d_entry table, TalkRight,     _DeviceTalkRight
    d_entry table, UnlockedDoor,  Main_Explore_GoThroughDoor
    d_entry table, Upgrade,       Main_Explore_PickUpUpgrade
    D_END
.ENDREPEAT
_DeviceFlower:
    lda #$ff
    sta Zp_NearbyDevice_u8
    jsr_prga FuncA_Room_PickUpFlowerDevice
    jmp _DoneWithDevice
_DeviceSign:
    lda #eAvatar::Reading
    sta Zp_AvatarMode_eAvatar
    bne _Dialog  ; unconditional
_DeviceTalkLeft:
    lda Zp_AvatarFlags_bObj
    ora #bObj::FlipH
    bne _Talk  ; unconditional
_DeviceTalkRight:
    lda Zp_AvatarFlags_bObj
    and #<~bObj::FlipH
_Talk:
    sta Zp_AvatarFlags_bObj
    lda #$ff
    sta Zp_NearbyDevice_u8
_Dialog:
    ldy Ram_DeviceTarget_u8_arr, x  ; param: eDialog value
    jmp Main_Dialog_OpenWindow
_DeviceLever:
    jsr Func_ToggleLeverDevice
_DoneWithDevice:
.ENDPROC
_UpdateScrolling:
    jsr_prga FuncA_Terrain_ScrollTowardsAvatar
_Tick:
    jsr_prga FuncA_Actor_TickAllActors
    jsr Func_TickAllDevices
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
    jeq _GameLoop
    .assert * = Main_Explore_GoThroughPassage, error, "fallthrough"
.ENDPROC

;;; Mode for leaving the current room through a passage and entering the next
;;; room.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @param A The ePassage value for the side of the room the player hit.
.PROC Main_Explore_GoThroughPassage
_FadeOut:
    pha  ; ePassage value
    jsr_prga FuncA_Objects_DrawObjectsForRoom
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
;;; @prereq Zp_NearbyDevice_u8 holds the index of a door device.
.PROC Main_Explore_GoThroughDoor
    lda #eAvatar::Reading
    sta Zp_AvatarMode_eAvatar
_SetSpawnPoint:
    ;; We'll soon be setting the entrance door in the destination room as the
    ;; spawn point, but first we set the exit door in the current room as the
    ;; spawn point, in case this room is safe and the destination room is not.
    lda Zp_NearbyDevice_u8
    ora #bSpawn::Device  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint
_FadeOut:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_FadeOutToBlack
_LoadNextRoom:
    ldy Zp_NearbyDevice_u8
    ldx Ram_DeviceTarget_u8_arr, y  ; param: eRoom value
    jsr FuncM_SwitchPrgcAndLoadRoom
    jsr_prga FuncA_Avatar_EnterRoomViaDoor
_FadeIn:
    jmp Main_Explore_EnterRoom
.ENDPROC

;;; Mode for pickup up an upgrade device.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @param X The upgrade device index.
.PROC Main_Explore_PickUpUpgrade
_SetSpawnPoint:
    txa  ; upgrade device index
    ora #bSpawn::Device  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint  ; preserves X
_CollectUpgrade:
    ldy #$ff
    sty Zp_NearbyDevice_u8
    jmp Main_Upgrade_OpenWindow
.ENDPROC

;;; Mode for activating a breaker device.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @param X The breaker device index.
.PROC Main_Explore_UseBreaker
    ldy #$ff
    sty Zp_NearbyDevice_u8
    jmp Main_Breaker_Activate
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Calculates a bPassage value from an ePassage and the avatar's position.
;;; @param Y The ePassage value for the side of the room the player hit.
;;; @return A The calculated bPassage value.
.PROC FuncA_Avatar_CalculatePassage
    tya  ; ePassage value
    .assert bPassage::EastWest = bProc::Negative, error
    bpl _UpDownPassage
_EastWestPassage:
    bit <(Zp_Current_sRoom + sRoom::Flags_bRoom)
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
    cmp <(Zp_Current_sRoom + sRoom::MinScrollX_u8)
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    ;; Construct the bPassage value from the screen number and ePassage value.
    and #bPassage::ScreenMask
    sty T0  ; ePassage value
    ora T0
    rts
.ENDPROC

;;; Sets Zp_NearbyDevice_u8 to the index of the (interactive) device that the
;;; player avatar is near (if any), or to $ff if the avatar is not near an
;;; interactive device.
.PROC FuncA_Avatar_FindNearbyDevice
    ;; Check if the player avatar is airborne (and not in water); if so, treat
    ;; them as not near any device.
    lda Zp_AvatarWaterDepth_u8
    bne @notAirborne
    bit Zp_AvatarAirborne_bool
    bpl @notAirborne
    ldx #$ff
    bne @done  ; unconditional
    @notAirborne:
    ;; Calculate the player avatar's room block row and store it in T0.
    lda Zp_AvatarPosY_i16 + 0
    sta T0
    lda Zp_AvatarPosY_i16 + 1
    .repeat 4
    lsr a
    ror T0
    .endrepeat
    ;; Calculate the player avatar's room block column and store it in T1.
    lda Zp_AvatarPosX_i16 + 0
    sta T1
    lda Zp_AvatarPosX_i16 + 1
    .repeat 4
    lsr a
    ror T1
    .endrepeat
    ;; Find an interactive device with the same block row/col.
    ldx #kMaxDevices - 1
    @loop:
    lda Ram_DeviceType_eDevice_arr, x
    cmp #kFirstInteractiveDeviceType
    blt @continue
    lda Ram_DeviceBlockCol_u8_arr, x
    cmp T1  ; player block col
    bne @continue
    lda Ram_DeviceBlockRow_u8_arr, x
    cmp T0  ; player block row
    beq @done
    @continue:
    dex
    bpl @loop
    @done:
    stx Zp_NearbyDevice_u8
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for everything in the room that should
;;; always be visible: the player avatar, machines, enemies, and devices.
.EXPORT FuncA_Objects_DrawObjectsForRoom
.PROC FuncA_Objects_DrawObjectsForRoom
    ;; Set up PPU scrolling and IRQ.  A room's draw function can optionally
    ;; override this if it needs its own IRQ behavior.
    lda Zp_RoomScrollX_u16 + 0
    sta Zp_PpuScrollX_u8
    lda Zp_RoomScrollY_u8
    sta Zp_PpuScrollY_u8
    jsr Func_Window_SetUpIrq
    ;; Update CHR0C bank (for animated terrain).  A room's draw function can
    ;; optionally override this if it needs its own animation behavior.
    lda Zp_FrameCounter_u8
    div #4
    and #$07
    add #<.bank(Ppu_ChrBgAnimA0)
    sta Zp_Chr0cBank_u8
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
    jmp (Zp_Current_sRoom + sRoom::Draw_func_ptr)
.ENDPROC

;;; Allocates and populates OAM slots for the visual prompt that appears when
;;; the player avatar is near a device.
.PROC FuncA_Objects_DrawDevicePrompt
    lda Zp_NearbyDevice_u8
    bmi _NotVisible
    lda Zp_AvatarMode_eAvatar
    cmp #eAvatar::Reading
    beq _NotVisible
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
    add #3 + kTileWidthPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA
    ;; Draw the object:
    ldy #kPaletteObjDevicePrompt  ; param: object flags
    lda #kTileIdObjDevicePrompt  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
_NotVisible:
    rts
.ENDPROC

;;;=========================================================================;;;
