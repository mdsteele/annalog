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
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "spawn.inc"
.INCLUDE "terrain.inc"
.INCLUDE "tileset.inc"

.IMPORT DataA_Room_Banks_u8_arr
.IMPORT FuncA_Actor_TickAllActors
.IMPORT FuncA_Avatar_EnterRoomViaDoor
.IMPORT FuncA_Avatar_ExploreMove
.IMPORT FuncA_Avatar_SpawnAtLastSafePoint
.IMPORT FuncA_Fade_In
.IMPORT FuncA_Fade_Out
.IMPORT FuncA_Machine_ExecuteAll
.IMPORT FuncA_Objects_DrawAllActors
.IMPORT FuncA_Objects_DrawAllDevices
.IMPORT FuncA_Objects_DrawAllMachines
.IMPORT FuncA_Objects_DrawMachineHud
.IMPORT FuncA_Objects_DrawPlayerAvatar
.IMPORT FuncA_Room_EnterViaPassage
.IMPORT FuncA_Room_ExitViaPassage
.IMPORT FuncA_Room_Load
.IMPORT FuncA_Terrain_CallRoomFadeIn
.IMPORT FuncA_Terrain_FillNametables
.IMPORT FuncA_Terrain_TransferTileColumn
.IMPORT FuncA_Terrain_UpdateAndMarkMinimap
.IMPORT Func_ClearRestOfOam
.IMPORT Func_FillLowerAttributeTable
.IMPORT Func_FillUpperAttributeTable
.IMPORT Func_PickUpFlowerDevice
.IMPORT Func_ProcessFrame
.IMPORT Func_SetLastSpawnPoint
.IMPORT Func_TickAllDevices
.IMPORT Func_ToggleLeverDevice
.IMPORT Func_Window_DirectDrawTopBorder
.IMPORT Func_Window_Disable
.IMPORT Func_Window_SetUpIrq
.IMPORT Main_Breaker_Activate
.IMPORT Main_Console_OpenWindow
.IMPORT Main_Dialog_OpenWindow
.IMPORT Main_Pause
.IMPORT Main_Upgrade_OpenWindow
.IMPORT Ppu_ChrBgAnim0
.IMPORT Ram_DeviceBlockCol_u8_arr
.IMPORT Ram_DeviceBlockRow_u8_arr
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Sram_LastSafe_eRoom
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarHarmTimer_u8
.IMPORTZP Zp_AvatarMode_eAvatar
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Chr0cBank_u8
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp4_byte
.IMPORTZP Zp_Tmp_ptr
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; The OBJ palette number and tile ID used for the visual prompt that appears
;;; when the player avatar is near a device.
kDevicePromptObjPalette = 1
kDevicePromptObjTileId = $09

;;; The higher the number, the more slowly the camera tracks towards the scroll
;;; goal.
.DEFINE kScrollXSlowdown 2
.DEFINE kScrollYSlowdown 2

;;; The maximum speed that the screen is allowed to scroll horizontally and
;;; vertically, in pixels per frame.
kMaxScrollXSpeed = 7
kMaxScrollYSpeed = 4

;;;=========================================================================;;;

.ZEROPAGE

;;; The desired horizontal scroll position; i.e. the position, in room-space
;;; pixels, of the left edge of the screen.  Note that this is unsigned, to
;;; simplify the comparison logic (we never want to scroll past the left edge
;;; of the room anyway).  Rooms can be several screens wide, so this needs to
;;; be two bytes.
.EXPORTZP Zp_ScrollGoalX_u16
Zp_ScrollGoalX_u16: .res 2

;;; The desired vertical scroll position; i.e. the position, in room-space
;;; pixels, of the top edge of the screen.  Note that this is unsigned, to
;;; simplify the comparison logic (we never want to scroll past the top edge of
;;; the room anyway).
.EXPORTZP Zp_ScrollGoalY_u8
Zp_ScrollGoalY_u8: .res 1

;;; The current horizontal and vertical scroll position within the room.
.EXPORTZP Zp_RoomScrollX_u16
Zp_RoomScrollX_u16: .res 2
.EXPORTZP Zp_RoomScrollY_u8
Zp_RoomScrollY_u8: .res 1

;;; If true ($ff), the camera position (that is, Zp_RoomScroll*) will track
;;; towards the scroll goal (Zp_ScrollGoal*) each frame; if false ($00), then
;;; the camera position will stay locked (though the scroll goal can continue
;;; to update).
.EXPORTZP Zp_CameraCanScroll_bool
Zp_CameraCanScroll_bool: .res 1

;;; The index of the (interactive) device that the player avatar is near, or
;;; $ff if none.
Zp_NearbyDevice_u8: .res 1

;;; If true ($ff), the register value HUD will be displayed (assuming that
;;; Zp_HudMachineIndex_u8 is also valid); if false ($00), the register value
;;; HUD will not be drawn.
Zp_HudEnabled_bool: .res 1

;;; If set to a PRG ROM address ($8000+) e.g. by a room or machine tick
;;; function, then explore mode will jump to this mode (and zero this variable)
;;; just before it would draw the next frame.
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
    prga_bank #<.bank(DataA_Room_Banks_u8_arr)
    prgc_bank DataA_Room_Banks_u8_arr, x
    jsr FuncA_Room_Load
    jsr_prga FuncA_Avatar_SpawnAtLastSafePoint
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
    jsr Func_FindNearbyDevice
    lda #0
    sta Zp_OamOffset_u8
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    ;; Zp_Render_bPpuMask will be set by FuncA_Objects_DrawObjectsForRoom.
    jsr_prga FuncA_Fade_In
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
    sta Zp_Tmp_ptr + 1
    lda Zp_NextCutscene_main_ptr + 0
    sta Zp_Tmp_ptr + 0
    lda #0
    sta Zp_NextCutscene_main_ptr + 0
    sta Zp_NextCutscene_main_ptr + 1
    jmp (Zp_Tmp_ptr)
    @noCutscene:
    ;; Draw this frame:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
_CheckForToggleHud:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Select
    beq @done
    lda Zp_HudEnabled_bool
    eor #$ff
    sta Zp_HudEnabled_bool
    @done:
_CheckForPause:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    beq @done
    jsr_prga FuncA_Fade_Out
    jmp Main_Pause
    @done:
.PROC _CheckForActivateDevice
    jsr Func_FindNearbyDevice
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::BButton = bProc::Overflow, error
    bvc _DoneWithDevice
    ldx Zp_NearbyDevice_u8  ; param: device index
    bmi _DoneWithDevice
    ldy Ram_DeviceType_eDevice_arr, x
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eDevice
    d_entry table, None,          _DoneWithDevice
    d_entry table, BreakerDone,   _DoneWithDevice
    d_entry table, BreakerRising, _DoneWithDevice
    d_entry table, LockedDoor,    _DoneWithDevice
    d_entry table, Placeholder,   _DoneWithDevice
    d_entry table, Teleporter,    _DoneWithDevice
    d_entry table, BreakerReady,  Main_Explore_UseBreaker
    d_entry table, Console,       Main_Explore_UseConsole
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
    jsr Func_PickUpFlowerDevice
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
    lda Ram_DeviceTarget_u8_arr, x
    tax  ; param: dialog index
    jmp Main_Dialog_OpenWindow
_DeviceLever:
    jsr Func_ToggleLeverDevice
_DoneWithDevice:
.ENDPROC
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
_Tick:
    jsr_prga FuncA_Actor_TickAllActors
    jsr Func_TickAllDevices
    jsr_prga FuncA_Machine_ExecuteAll
    jsr Func_CallRoomTick
    ;; Check if the player avatar is dead:
    lda Zp_AvatarHarmTimer_u8
    cmp #kAvatarHarmDeath
    jeq Main_Explore_Death
    ;; Move the avatar and check if we've gone through a passage:
    jsr_prga FuncA_Avatar_ExploreMove  ; if passage, clears Z and returns A
    jeq _GameLoop
    .assert * = Main_Explore_GoThroughPassage, error, "fallthrough"
.ENDPROC

;;; Mode for leaving the current room through a passage and entering the next
;;; room.
;;; @param A The ePassage value for the side of the room the player hit.
.PROC Main_Explore_GoThroughPassage
    ;; Fade out the current room.
    pha  ; ePassage value
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr_prga FuncA_Fade_Out
    pla  ; ePassage value
_CalculatePassage:
    ;; Calculate the bPassage value from the ePassage and the avatar's
    ;; position, storing it in A.
    tay  ; ePassage value
    and #bPassage::EastWest
    beq _CalculateUpDownPassage
_CalculateEastWestPassage:
    bit <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bpl @upperHalf
    @tall:
    lda Zp_AvatarPosY_i16 + 1
    bmi @upperHalf
    bne @lowerHalf
    lda Zp_AvatarPosY_i16 + 0
    cmp #(kTallRoomHeightBlocks / 2) * kBlockHeightPx
    bge @lowerHalf
    @upperHalf:
    tya  ; ePassage value
    bne _LoadNextRoom  ; unconditional
    @lowerHalf:
    tya  ; ePassage value
    ora #1
    bne _LoadNextRoom  ; unconditional
_CalculateUpDownPassage:
    ;; Calculate which horizontal screen of the room the player avatar is in
    ;; (in other words, the hi byte of (avatar position - min scroll X) in room
    ;; pixel coordinates), storing the result in A.
    lda Zp_AvatarPosX_i16 + 0
    sub <(Zp_Current_sRoom + sRoom::MinScrollX_u8)
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    ;; Construct the bPassage value from the screen number and ePassage value.
    and #bPassage::ScreenMask
    sty Zp_Tmp1_byte  ; ePassage value
    ora Zp_Tmp1_byte
_LoadNextRoom:
    pha  ; origin bPassage value (calculated)
    tax  ; param: origin bPassage value (calculated)
    jsr_prga FuncA_Room_ExitViaPassage  ; returns X (eRoom) and A (spawn block)
    pha  ; origin SpawnBlock_u8
    prgc_bank DataA_Room_Banks_u8_arr, x
    jsr FuncA_Room_Load
    pla  ; origin SpawnBlock_u8
    tay  ; param: origin SpawnBlock_u8
    pla  ; param: origin bPassage value (calculated)
    jsr FuncA_Room_EnterViaPassage
    jmp Main_Explore_FadeIn
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
    .assert bSpawn::IsPassage <> 0, error
    lda Zp_NearbyDevice_u8  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint
_FadeOut:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr_prga FuncA_Fade_Out
_LoadNextRoom:
    prga_bank #<.bank(DataA_Room_Banks_u8_arr)
    ldy Zp_NearbyDevice_u8
    ldx Ram_DeviceTarget_u8_arr, y  ; param: eRoom value
    prgc_bank DataA_Room_Banks_u8_arr, x
    jsr FuncA_Room_Load
    jsr_prga FuncA_Avatar_EnterRoomViaDoor
_FadeIn:
    jmp Main_Explore_FadeIn
.ENDPROC

;;; Mode for pickup up an upgrade device.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @param X The upgrade device index.
.PROC Main_Explore_PickUpUpgrade
    ldy #0
    sty Zp_HudEnabled_bool
    dey  ; now Y is $ff
    sty Zp_NearbyDevice_u8
    jmp Main_Upgrade_OpenWindow
.ENDPROC

;;; Mode for activating a breaker device.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @param X The breaker device index.
.PROC Main_Explore_UseBreaker
    ldy #0
    sty Zp_HudEnabled_bool
    dey  ; now Y is $ff
    sty Zp_NearbyDevice_u8
    jmp Main_Breaker_Activate
.ENDPROC

;;; Mode for using a console device.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @prereq Zp_NearbyDevice_u8 holds the index of a console device.
.PROC Main_Explore_UseConsole
    lda #eAvatar::Reading
    sta Zp_AvatarMode_eAvatar
_SetSpawnPoint:
    .assert bSpawn::IsPassage <> 0, error
    lda Zp_NearbyDevice_u8  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint
_EnableHud:
    lda #$ff
    sta Zp_HudEnabled_bool
_OpenConsoleWindow:
    ldy Zp_NearbyDevice_u8
    ldx Ram_DeviceTarget_u8_arr, y  ; param: machine index
    jmp Main_Console_OpenWindow
.ENDPROC

;;; Mode for when the avatar has just been killed while exploring.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
.PROC Main_Explore_Death
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    ;; TODO: Fade out palettes, but don't disable rendering.
    jsr_prga FuncA_Fade_Out
    ;; TODO: Animate the avatar collapasing.
_LoadLastSafeRoom:
    ldx Sram_LastSafe_eRoom  ; param: room number
    prga_bank #<.bank(DataA_Room_Banks_u8_arr)
    prgc_bank DataA_Room_Banks_u8_arr, x
    jsr FuncA_Room_Load
_Respawn:
    jsr_prga FuncA_Avatar_SpawnAtLastSafePoint
    ;; TODO: Animate the avatar moving to its new location.
    ;; TODO: Start explore mode *without* needing to disable rendering first.
    jmp Main_Explore_FadeIn
.ENDPROC

;;; Calls the current room's Tick_func_ptr function.
.PROC Func_CallRoomTick
    jmp (Zp_Current_sRoom + sRoom::Tick_func_ptr)
.ENDPROC

;;; Sets Zp_NearbyDevice_u8 to the index of the (interactive) device that the
;;; player avatar is near (if any), or to $ff if the avatar is not near an
;;; interactive device.
.PROC Func_FindNearbyDevice
    ;; Check if the player avatar is airborne; if so, treat them as not near
    ;; any device.
    lda Zp_AvatarMode_eAvatar
    cmp #kFirstAirborneAvatarMode
    blt @notAirborne
    ldx #$ff
    bne @done  ; unconditional
    @notAirborne:
    ;; Calculate the player avatar's room block row and store it in
    ;; Zp_Tmp1_byte.
    lda Zp_AvatarPosY_i16 + 0
    sta Zp_Tmp1_byte
    lda Zp_AvatarPosY_i16 + 1
    .repeat 4
    lsr a
    ror Zp_Tmp1_byte
    .endrepeat
    ;; Calculate the player avatar's room block column and store it in
    ;; Zp_Tmp2_byte.
    lda Zp_AvatarPosX_i16 + 0
    sta Zp_Tmp2_byte
    lda Zp_AvatarPosX_i16 + 1
    .repeat 4
    lsr a
    ror Zp_Tmp2_byte
    .endrepeat
    ;; Find an interactive device with the same block row/col.
    ldx #kMaxDevices - 1
    @loop:
    lda Ram_DeviceType_eDevice_arr, x
    cmp #kFirstInteractiveDeviceType
    blt @continue
    lda Ram_DeviceBlockCol_u8_arr, x
    cmp Zp_Tmp2_byte  ; player block col
    bne @continue
    lda Ram_DeviceBlockRow_u8_arr, x
    cmp Zp_Tmp1_byte  ; player block row
    beq @done
    @continue:
    dex
    bpl @loop
    @done:
    stx Zp_NearbyDevice_u8
    rts
.ENDPROC

;;; Sets Zp_ScrollGoalX_u16 and Zp_ScrollGoalY_u8 such that the player avatar
;;; would be as close to the center of the screen as possible, while still
;;; keeping the scroll goal within the valid range for the current room.
.EXPORT Func_SetScrollGoalFromAvatar
.PROC Func_SetScrollGoalFromAvatar
.PROC _SetScrollGoalY
    ;; Calculate the maximum permitted scroll-Y and store it in Zp_Tmp1_byte.
    lda #0
    bit <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bpl @shortRoom
    lda #kTallRoomHeightBlocks * kBlockHeightPx - kScreenHeightPx
    @shortRoom:
    sta Zp_Tmp1_byte  ; max scroll-Y
    ;; Subtract half the screen height from the player avatar's Y-position,
    ;; storing the result in AX.
    lda Zp_AvatarPosY_i16 + 0
    sub #kScreenHeightPx / 2
    tax
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    ;; Clamp the result to within the permitted scroll-Y range.
    bmi @minGoal
    bne @maxGoal
    txa
    cmp Zp_Tmp1_byte  ; max scroll-Y
    blt @setGoalToA
    @maxGoal:
    lda Zp_Tmp1_byte  ; max scroll-Y
    jmp @setGoalToA
    @minGoal:
    lda #0
    @setGoalToA:
    sta Zp_ScrollGoalY_u8
.ENDPROC
.PROC _SetScrollGoalX
    ;; Compute the signed 16-bit horizontal scroll goal, storing it in AX.
    lda Zp_AvatarPosX_i16 + 0
    sub #kScreenWidthPx / 2
    tax
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    ;; Check AX against the current room's MinScrollX_u8, and clamp if needed.
    bmi @minGoal  ; if AX is negative, clamp to min scroll value
    bne @notMin   ; min scroll is 8-bit, so if A > 0, then AX > min
    cpx <(Zp_Current_sRoom + sRoom::MinScrollX_u8)
    bge @notMin
    @minGoal:
    ldx <(Zp_Current_sRoom + sRoom::MinScrollX_u8)
    lda #0
    beq _SetGoalToAX  ; unconditional
    @notMin:
    ;; Check AX against the current room's MaxScrollX_u16, and clamp if needed.
    cmp <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 1)
    blt _SetGoalToAX
    bne @maxGoal
    cpx <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 0)
    blt _SetGoalToAX
    @maxGoal:
    ldax <(Zp_Current_sRoom + sRoom::MaxScrollX_u16)
_SetGoalToAX:
    stax Zp_ScrollGoalX_u16
.ENDPROC
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; Sets up room scrolling and populates nametables for explore mode.  Called
;;; just before fading in the screen (e.g. when entering the room or
;;; unpausing).
.PROC FuncA_Terrain_InitRoomScrollAndNametables
    ;; Fill the attribute tables.
    ldy #$00  ; param: fill byte
    jsr Func_FillUpperAttributeTable  ; preserves Y
    jsr Func_FillLowerAttributeTable
    ;; Initialize the scroll position.
    jsr Func_SetScrollGoalFromAvatar
    bit Zp_CameraCanScroll_bool
    bpl @done
    lda Zp_ScrollGoalY_u8
    sta Zp_RoomScrollY_u8
    ldax Zp_ScrollGoalX_u16
    stax Zp_RoomScrollX_u16
    @done:
    jsr FuncA_Terrain_UpdateAndMarkMinimap
    ;; Calculate the index of the leftmost room tile column that should be in
    ;; the nametable.
    lda Zp_RoomScrollX_u16 + 0
    add #kTileWidthPx - 1
    sta Zp_Tmp1_byte
    lda Zp_RoomScrollX_u16 + 1
    adc #0
    .repeat 3
    lsr a
    ror Zp_Tmp1_byte
    .endrepeat
    lda Zp_Tmp1_byte  ; param: left block column index
    ;; Populate the nametables.
    jsr FuncA_Terrain_FillNametables
    jmp FuncA_Terrain_CallRoomFadeIn
.ENDPROC

;;; Updates the scroll position for next frame to move closer to
;;; Zp_ScrollGoalX_u16 and Zp_ScrollGoalY_u8, transferring nametable updates
;;; for the current room as necessary.
.EXPORT FuncA_Terrain_ScrollTowardsGoal
.PROC FuncA_Terrain_ScrollTowardsGoal
    bit Zp_CameraCanScroll_bool
    bmi @canScroll
    rts
    @canScroll:
_TrackScrollYTowardsGoal:
    ;; Compute the delta from the current scroll-Y position to the goal
    ;; position, storing it in A.
    lda Zp_ScrollGoalY_u8
    sub Zp_RoomScrollY_u8
    blt @goalLessThanCurr
    ;; If the delta is positive, then we need to scroll down.  Divide the delta
    ;; by (1 << kScrollYSlowdown) to get the amount we'll scroll by this frame,
    ;; but cap it at a maximum of kMaxScrollYSpeed.
    @goalMoreThanCurr:
    .repeat kScrollYSlowdown
    lsr a
    .endrepeat
    cmp #kMaxScrollYSpeed
    blt @scrollByA
    lda #kMaxScrollYSpeed
    bne @scrollByA  ; unconditional
    ;; If the delta is negative, then we need to scroll up.  Divide the
    ;; (negative) delta by (1 << kScrollYSlowdown), roughly, to get the amount
    ;; we'll scroll by this frame, but cap it at a minimum of
    ;; -kMaxScrollYSpeed.
    @goalLessThanCurr:
    .repeat kScrollYSlowdown
    sec
    ror a
    .endrepeat
    cmp #$ff & -kMaxScrollYSpeed
    bge @scrollByA
    lda #$ff & -kMaxScrollYSpeed
    ;; Add YA to the current scroll-X position.
    @scrollByA:
    add Zp_RoomScrollY_u8
    sta Zp_RoomScrollY_u8
    @doneScrollVert:
_ClampScrollY:
    ;; Calculate the visible height of the screen (the part not covered by the
    ;; window), and store it in Zp_Tmp1_byte.
    lda Zp_WindowTop_u8
    cmp #kScreenHeightPx
    blt @windowVisible
    lda #kScreenHeightPx
    @windowVisible:
    sta Zp_Tmp1_byte  ; visible screen height
    ;; Calculate the maximum permitted scroll-Y and store it in Zp_Tmp2_byte.
    lda #kScreenHeightPx
    bit <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bpl @shortRoom
    lda #<(kTallRoomHeightBlocks * kBlockHeightPx)
    @shortRoom:
    sub Zp_Tmp1_byte  ; visible screen height
    sta Zp_Tmp2_byte  ; max scroll-Y
    ;; Clamp Zp_RoomScrollY_u8 to no more than the permitted value.
    lda Zp_RoomScrollY_u8
    cmp Zp_Tmp2_byte  ; max scroll-Y
    blt @done
    lda Zp_Tmp2_byte  ; max scroll-Y
    sta Zp_RoomScrollY_u8
    @done:
_PrepareToScrollHorz:
    ;; Calculate the index of the leftmost room tile column that is currently
    ;; in the nametable, and put that index in Zp_Tmp1_byte.
    lda Zp_RoomScrollX_u16 + 0
    add #kTileWidthPx - 1
    sta Zp_Tmp1_byte
    lda Zp_RoomScrollX_u16 + 1
    adc #0
    .repeat 3
    lsr a
    ror Zp_Tmp1_byte
    .endrepeat
_TrackScrollXTowardsGoal:
    ldy #0
    ;; Compute the delta from the current scroll-X position to the goal
    ;; position, storing it in Zp_Tmp2_byte (lo) and A (hi).
    lda Zp_ScrollGoalX_u16 + 0
    sub Zp_RoomScrollX_u16 + 0
    sta Zp_Tmp2_byte  ; delta (lo)
    lda Zp_ScrollGoalX_u16 + 1
    sbc Zp_RoomScrollX_u16 + 1
    bmi @goalLessThanCurr
    ;; If the delta is positive, then we need to scroll to the right.  Divide
    ;; the delta by (1 << kScrollXSlowdown) to get the amount we'll scroll by
    ;; this frame, but cap it at a maximum of kMaxScrollXSpeed.
    @goalMoreThanCurr:
    .assert kMaxScrollXSpeed << kScrollXSlowdown < $100, error
    bne @maxScroll
    lda Zp_Tmp2_byte  ; delta (lo)
    .repeat kScrollXSlowdown
    lsr a
    .endrepeat
    cmp #kMaxScrollXSpeed
    blt @scrollByYA
    @maxScroll:
    lda #kMaxScrollXSpeed
    bne @scrollByYA  ; unconditional
    ;; If the delta is negative, then we need to scroll to the left.  Divide
    ;; the (negative) delta by (1 << kScrollXSlowdown), roughly, to get the
    ;; amount we'll scroll by this frame, but cap it at a minimum of
    ;; -kMaxScrollXSpeed.
    @goalLessThanCurr:
    dey  ; now Y is $ff
    cmp #$ff
    bne @minScroll
    lda Zp_Tmp2_byte  ; delta (lo)
    .repeat kScrollXSlowdown
    sec
    ror a
    .endrepeat
    cmp #$ff & -kMaxScrollXSpeed
    bge @scrollByYA
    @minScroll:
    lda #$ff & -kMaxScrollXSpeed
    ;; Add YA to the current scroll-X position.
    @scrollByYA:
    add Zp_RoomScrollX_u16 + 0
    sta Zp_RoomScrollX_u16 + 0
    tya
    adc Zp_RoomScrollX_u16 + 1
    sta Zp_RoomScrollX_u16 + 1
_UpdateNametable:
    ;; Calculate the index of the leftmost room tile column that should now be
    ;; in the nametable, and put that index in Zp_Tmp2_byte.
    lda Zp_RoomScrollX_u16 + 0
    add #kTileWidthPx - 1
    sta Zp_Tmp2_byte
    lda Zp_RoomScrollX_u16 + 1
    adc #0
    .repeat 3
    lsr a
    ror Zp_Tmp2_byte
    .endrepeat
    ;; Determine if we need to update the nametable; if so, set A to the index
    ;; of the room tile column that should be loaded.
    lda Zp_Tmp2_byte  ; new leftmost room tile column
    cmp Zp_Tmp1_byte  ; old leftmost room tile column
    beq @doneTransfer
    bmi @doTransfer
    add #kScreenWidthTiles - 1
    @doTransfer:
    jsr FuncA_Terrain_TransferTileColumn
    @doneTransfer:
    jmp FuncA_Terrain_UpdateAndMarkMinimap
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
    div #8
    and #$03
    add #<.bank(Ppu_ChrBgAnim0)
    sta Zp_Chr0cBank_u8
    ;; Draw HUD.
    bit Zp_HudEnabled_bool
    bpl @skipHud
    jsr FuncA_Objects_DrawMachineHud
    @skipHud:
    ;; Draw other objects.
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
    ;; Calculate the screen X-position and store it in Zp_Tmp1_byte:
    lda Zp_AvatarPosX_i16 + 0
    sub Zp_RoomScrollX_u16 + 0
    sta Zp_Tmp1_byte
    lda Zp_AvatarPosX_i16 + 1
    sbc Zp_RoomScrollX_u16 + 1
    sta Zp_Tmp2_byte
    lda Zp_Tmp1_byte
    sub #kTileWidthPx / 2
    sta Zp_Tmp1_byte  ; screen pixel X-pos
    lda Zp_Tmp2_byte
    sbc #0
    bne _NotVisible
    ;; Calculate the Y-offset and store it in Zp_Tmp4_byte:
    lda Zp_FrameCounter_u8
    lsr a
    lsr a
    lsr a
    and #$03
    cmp #$03
    bne @noZigZag
    lda #$01
    @noZigZag:
    add #3 + kTileWidthPx * 2
    sta Zp_Tmp4_byte  ; Y-offset
    ;; Calculate the screen Y-position and store it in Zp_Tmp2_byte:
    lda Zp_AvatarPosY_i16 + 0
    sub Zp_RoomScrollY_u8
    sta Zp_Tmp2_byte
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    sta Zp_Tmp3_byte
    lda Zp_Tmp2_byte
    sub Zp_Tmp4_byte  ; Y-offset
    sta Zp_Tmp2_byte  ; screen pixel Y-pos
    lda Zp_Tmp3_byte
    sbc #0
    bne _NotVisible
    ;; Set object attributes.
    ldy Zp_OamOffset_u8
    lda Zp_Tmp2_byte  ; screen pixel Y-pos
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    lda Zp_Tmp1_byte  ; screen pixel X-pos
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    lda #kDevicePromptObjPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kDevicePromptObjTileId
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ;; Update the OAM offset.
    .repeat .sizeof(sObj)
    iny
    .endrepeat
    sty Zp_OamOffset_u8
_NotVisible:
    rts
.ENDPROC

;;;=========================================================================;;;
