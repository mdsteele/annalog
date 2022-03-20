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
.INCLUDE "device.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "terrain.inc"

.IMPORT Data_RoomBanks_u8_arr
.IMPORT FuncA_Avatar_ExploreMove
.IMPORT FuncA_Objects_DrawAllActors
.IMPORT FuncA_Objects_DrawAllDevices
.IMPORT FuncA_Objects_DrawAllMachines
.IMPORT FuncA_Objects_DrawPlayerAvatar
.IMPORT FuncA_Terrain_FillNametables
.IMPORT FuncA_Terrain_TransferTileColumn
.IMPORT Func_Avatar_PositionAtNearbyDevice
.IMPORT Func_ClearRestOfOam
.IMPORT Func_ExecuteAllMachines
.IMPORT Func_ExitCurrentRoom
.IMPORT Func_FadeIn
.IMPORT Func_FadeOut
.IMPORT Func_LoadRoom
.IMPORT Func_ProcessFrame
.IMPORT Func_TickAllActors
.IMPORT Func_TickAllDevices
.IMPORT Func_ToggleLeverDevice
.IMPORT Func_UpdateAndMarkMinimap
.IMPORT Func_UpdateButtons
.IMPORT Func_Window_DirectDrawTopBorder
.IMPORT Func_Window_Disable
.IMPORT Main_Console_OpenWindow
.IMPORT Main_Dialog_OpenWindow
.IMPORT Main_Pause
.IMPORT Main_Title
.IMPORT Main_Upgrade_OpenWindow
.IMPORT Ppu_ChrCave
.IMPORT Ram_DeviceBlockCol_u8_arr
.IMPORT Ram_DeviceBlockRow_u8_arr
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_AvatarHarmTimer_u8
.IMPORTZP Zp_AvatarMode_eAvatar
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Current_sRoom
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
Zp_ScrollGoalX_u16: .res 2

;;; The desired vertical scroll position; i.e. the position, in room-space
;;; pixels, of the top edge of the screen.  Note that this is unsigned, to
;;; simplify the comparison logic (we never want to scroll past the top edge of
;;; the room anyway).
Zp_ScrollGoalY_u8: .res 1

;;; The high byte of the current horizontal scroll position (the low byte is
;;; stored in Zp_PpuScrollX_u8, and together they form a single u16).  This
;;; high byte doesn't matter for PPU scrolling, but does matter for comparisons
;;; of the current scroll position with Zp_ScrollGoalX_u16 or 16-bit object
;;; positions.
.EXPORTZP Zp_ScrollXHi_u8
Zp_ScrollXHi_u8: .res 1

;;; The index of the device that the player avatar is near, or $ff if none.
.EXPORTZP Zp_NearbyDevice_u8
Zp_NearbyDevice_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for exploring and platforming within a room, when entering the room
;;; from a device (e.g. the console the game was last saved from).
;;; @prereq Rendering is disabled.
;;; @param X The eRoom value for the room to enter.
;;; @param Y The device index to enter from.
.EXPORT Main_Explore_EnterFromDevice
.PROC Main_Explore_EnterFromDevice
    sty Zp_NearbyDevice_u8
    prgc_bank Data_RoomBanks_u8_arr, x
    jsr Func_LoadRoom
    jsr Func_Avatar_PositionAtNearbyDevice
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
    ;; TODO: Set the appropriate chr08_bank for the current room.
    chr08_bank #<.bank(Ppu_ChrCave)
    jsr Func_UpdateAndMarkMinimap
_InitializeScrolling:
    jsr Func_SetScrollGoalFromAvatar
    lda Zp_ScrollGoalY_u8
    sta Zp_PpuScrollY_u8
    ldax Zp_ScrollGoalX_u16
    stx Zp_PpuScrollX_u8
    sta Zp_ScrollXHi_u8
_DrawTerrain:
    prga_bank #<.bank(FuncA_Terrain_FillNametables)
    ;; Calculate the index of the leftmost room tile column that should be in
    ;; the nametable.
    lda Zp_PpuScrollX_u8
    add #kTileWidthPx - 1
    sta Zp_Tmp1_byte
    lda Zp_ScrollXHi_u8
    adc #0
    .repeat 3
    lsr a
    ror Zp_Tmp1_byte
    .endrepeat
    lda Zp_Tmp1_byte  ; param: left block column index
    jsr FuncA_Terrain_FillNametables
_InitObjectsAndFadeIn:
    lda #0
    sta Zp_OamOffset_u8
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    ;; Zp_Render_bPpuMask will be set by FuncA_Objects_DrawObjectsForRoom.
    jsr Func_FadeIn
    .assert * = Main_Explore_Continue, error, "fallthrough"
.ENDPROC

;;; Mode for exploring and platforming within a room, when continuing after
;;; e.g. closing a window.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
.EXPORT Main_Explore_Continue
.PROC Main_Explore_Continue
_GameLoop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_CheckForPause:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    beq @done
    jsr Func_FadeOut
    jmp Main_Pause
    @done:
_CheckForActivateDevice:
    jsr Func_FindNearbyDevice
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::BButton
    beq @done
    ldx Zp_NearbyDevice_u8
    bmi @done
    lda Ram_DeviceType_eDevice_arr, x
    cmp #eDevice::Console
    beq @console
    cmp #eDevice::Lever
    beq @lever
    cmp #eDevice::Sign
    beq @sign
    cmp #eDevice::Upgrade
    bne @done
    @upgrade:
    lda #$ff
    sta Zp_NearbyDevice_u8
    jmp Main_Upgrade_OpenWindow
    @console:
    lda #eAvatar::Reading
    sta Zp_AvatarMode_eAvatar
    lda Ram_DeviceTarget_u8_arr, x
    tax  ; param: machine index
    jmp Main_Console_OpenWindow
    @sign:
    lda #eAvatar::Reading
    sta Zp_AvatarMode_eAvatar
    lda Ram_DeviceTarget_u8_arr, x
    tax  ; param: dialog index
    jmp Main_Dialog_OpenWindow
    @lever:
    jsr Func_ToggleLeverDevice
    @done:
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
_Tick:
    jsr Func_TickAllActors
    jsr Func_TickAllDevices
    jsr Func_ExecuteAllMachines
    lda Zp_AvatarHarmTimer_u8
    cmp #kAvatarHarmDeath
    jeq Main_Explore_Death
    jsr_prga FuncA_Avatar_ExploreMove  ; clears Z if door; returns eDoor in A
    jeq _GameLoop
    .assert * = Main_Explore_GoThroughDoor, error, "fallthrough"
.ENDPROC

;;; Mode for leaving the current room through a door and entering the next
;;; room.
;;; @param A The eDoor value for the side of the room the player hit.
.PROC Main_Explore_GoThroughDoor
    ;; Fade out the current room.
    pha  ; eDoor value
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_FadeOut
    pla  ; eDoor value
_CalculateDoor:
    ;; Calculate the bDoor value from the eDoor and the avatar's position.
    tay  ; eDoor value
    and #bDoor::EastWest
    beq @upDown
    @eastWest:
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
    tya  ; eDoor value
    bne _LoadNextRoom  ; unconditional
    @lowerHalf:
    tya  ; eDoor value
    ora #1
    bne _LoadNextRoom  ; unconditional
    @upDown:
    ;; TODO: determine screen number for up/down doors
_LoadNextRoom:
    pha  ; bDoor value
    tax  ; param: bDoor value
    jsr Func_ExitCurrentRoom  ; returns A
    tax  ; param: eRoom value
    prgc_bank Data_RoomBanks_u8_arr, x
    jsr Func_LoadRoom
    pla  ; bDoor value
_RepositionAvatar:
    ;; Extract eDoor value from bDoor value.
    and #bDoor::SideMask
    ;; Reposition avatar based on eDoor value and new room size.
    cmp #eDoor::Eastern
    bne @eastern
    ;; TODO: handle up/down doors
    @western:
    lda <(Zp_Current_sRoom + sRoom::MinScrollX_u8)
    add #8
    sta Zp_AvatarPosX_i16 + 0
    lda #0
    sta Zp_AvatarPosX_i16 + 1
    beq @doorDone  ; unconditional
    @eastern:
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 0)
    add #kScreenWidthPx - 8
    sta Zp_AvatarPosX_i16 + 0
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 1)
    adc #0
    sta Zp_AvatarPosX_i16 + 1
    @doorDone:
_EnterNextRoom:
    jmp Main_Explore_FadeIn
.ENDPROC

;;; Mode for when the avatar has just been killed while exploring.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
.PROC Main_Explore_Death
    ;; TODO: Animate the avatar blinking red or collapasing or something.
    jsr Func_FadeOut
    jmp Main_Title
.ENDPROC

;;; Sets Zp_NearbyDevice_u8 to the index of the device that the player avatar
;;; is near (if any), or to $ff if the avatar is not near a device.
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
    ;; Find a device with the same block row/col.
    ldx #kMaxDevices - 1
    @loop:
    lda Ram_DeviceType_eDevice_arr, x
    .assert eDevice::None = 0, error
    beq @continue
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
    ;; Halve the visible screen height, then subtract that from the player
    ;; avatar's Y-position.
    lsr Zp_Tmp1_byte
    lda Zp_AvatarPosY_i16 + 0
    sub Zp_Tmp1_byte  ; half visible screen height
    tax
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    ;; Clamp the result to within the permitted scroll-Y range.
    bmi @minGoal
    bne @maxGoal
    txa
    cmp Zp_Tmp2_byte  ; max scroll-Y
    blt @setGoalToA
    @maxGoal:
    lda Zp_Tmp2_byte  ; max scroll-Y
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

;;; Updates the scroll position for next frame to move closer to
;;; Zp_ScrollGoalX_u16 and Zp_ScrollGoalY_u8, transferring nametable updates
;;; for the current room as necessary.
.EXPORT FuncA_Terrain_ScrollTowardsGoal
.PROC FuncA_Terrain_ScrollTowardsGoal
_TrackScrollYTowardsGoal:
    ;; Compute the delta from the current scroll-Y position to the goal
    ;; position, storing it in A.
    lda Zp_ScrollGoalY_u8
    sub Zp_PpuScrollY_u8
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
    add Zp_PpuScrollY_u8
    sta Zp_PpuScrollY_u8
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
    ;; Clamp Zp_PpuScrollY_u8 to no more than the permitted value.
    lda Zp_PpuScrollY_u8
    cmp Zp_Tmp2_byte  ; max scroll-Y
    blt @done
    lda Zp_Tmp2_byte  ; max scroll-Y
    sta Zp_PpuScrollY_u8
    @done:
_PrepareToScrollHorz:
    ;; Calculate the index of the leftmost room tile column that is currently
    ;; in the nametable, and put that index in Zp_Tmp1_byte.
    lda Zp_PpuScrollX_u8
    add #kTileWidthPx - 1
    sta Zp_Tmp1_byte
    lda Zp_ScrollXHi_u8
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
    sub Zp_PpuScrollX_u8
    sta Zp_Tmp2_byte  ; delta (lo)
    lda Zp_ScrollGoalX_u16 + 1
    sbc Zp_ScrollXHi_u8
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
    add Zp_PpuScrollX_u8
    sta Zp_PpuScrollX_u8
    tya
    adc Zp_ScrollXHi_u8
    sta Zp_ScrollXHi_u8
_UpdateNametable:
    ;; Calculate the index of the leftmost room tile column that should now be
    ;; in the nametable, and put that index in Zp_Tmp2_byte.
    lda Zp_PpuScrollX_u8
    add #kTileWidthPx - 1
    sta Zp_Tmp2_byte
    lda Zp_ScrollXHi_u8
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
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for everything in the room that should
;;; always be visible: the player avatar, machines, enemies, and devices.
.EXPORT FuncA_Objects_DrawObjectsForRoom
.PROC FuncA_Objects_DrawObjectsForRoom
    jsr FuncA_Objects_DrawAllActors
    jsr FuncA_Objects_DrawPlayerAvatar
    jsr FuncA_Objects_DrawDevicePrompt
    jsr FuncA_Objects_DrawAllMachines
    jmp FuncA_Objects_DrawAllDevices
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
    sub Zp_PpuScrollX_u8
    sta Zp_Tmp1_byte
    lda Zp_AvatarPosX_i16 + 1
    sbc Zp_ScrollXHi_u8
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
    sub Zp_PpuScrollY_u8
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
