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

.INCLUDE "device.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT Data_RoomBanks_u8_arr
.IMPORT FuncA_Terrain_FillNametables
.IMPORT FuncA_Terrain_GetColumnPtrForTileIndex
.IMPORT FuncA_Terrain_TransferTileColumn
.IMPORT Func_AllocObjectsFor2x2Shape
.IMPORT Func_ClearRestOfOam
.IMPORT Func_DrawObjectsForAllDevices
.IMPORT Func_DrawObjectsForAllMachines
.IMPORT Func_ExecuteAllMachines
.IMPORT Func_ExitCurrentRoom
.IMPORT Func_FadeIn
.IMPORT Func_FadeOut
.IMPORT Func_LoadRoom
.IMPORT Func_ProcessFrame
.IMPORT Func_TickAllDevices
.IMPORT Func_ToggleLeverDevice
.IMPORT Func_UpdateButtons
.IMPORT Func_Window_DirectDrawTopBorder
.IMPORT Func_Window_Disable
.IMPORT Main_Console_OpenWindow
.IMPORT Main_Dialog_OpenWindow
.IMPORT Main_Pause
.IMPORT Main_Upgrade_OpenWindow
.IMPORT Ppu_ChrCave
.IMPORT Ram_DeviceBlockCol_u8_arr
.IMPORT Ram_DeviceBlockRow_u8_arr
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Sram_Minimap_u16_arr
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsHeld_bJoypad
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp4_byte
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; How far the player avatar's bounding box extends in each direction from the
;;; avatar's position.
kAvatarBoundingBoxUp = 7
kAvatarBoundingBoxDown = 8
kAvatarBoundingBoxLeft = 5
kAvatarBoundingBoxRight = 5

;;; How fast the player avatar is allowed to move, in pixels per frame.
kAvatarMaxSpeedX = 2
kAvatarMaxSpeedY = 5

;;; If the player stops holding the jump button while jumping, then the
;;; avatar's upward speed is immediately capped to this many pixels per frame.
kAvatarStopJumpSpeed = 1

;;; The horizontal acceleration applied to the player avatar when holding the
;;; left/right arrows, in subpixels per frame per frame.
kAvatarHorzAccel = 70

;;; The (signed, 16-bit) initial velocity of the player avatar when jumping, in
;;; subpixels per frame.
kAvatarJumpVelocity = $ffff & -810

;;; The vertical acceleration applied to the player avatar when in midair, in
;;; subpixels per frame per frame.
kAvatarGravity = 48

;;; The OBJ palette number to use for the player avatar.
kAvatarPalette = 1

;;; Terrain block IDs greater than or equal to this are considered solid.
kFirstSolidTerrainType = $40

;;; Modes that the player avatar can be in.  The number for each of these enum
;;; values is the starting tile ID to use for the avatar objects when the
;;; avatar is in that mode.
.ENUM eAvatar
    Standing = $20  ; (grounded) standing still on the ground
    Landing  = $24  ; (grounded) just landed from a jump
    Reading  = $28  ; (grounded) facing away from camera (e.g. to read a sign)
    Running1 = $2c  ; (grounded) running along the ground (1st frame)
    Running2 = $30  ; (grounded) running along the ground (2nd frame)
    Jumping  = $34  ; (airborne) jumping up
    Floating = $38  ; (airborne) mid-jump hang time
    Falling  = $3c  ; (airborne) falling down
.ENDENUM

;;; Any eAvatar modes greater than or equal to this are considered airborne.
kFirstAirborneAvatarMode = eAvatar::Jumping

;;; The OBJ palette number and tile ID used for the visual prompt that appears
;;; when the player avatar is near a device.
kDevicePromptObjPalette = 1
kDevicePromptObjTileId = $09

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

;;; The current X/Y positions of the player avatar, in room-space pixels.
.EXPORTZP Zp_AvatarPosX_i16, Zp_AvatarPosY_i16
Zp_AvatarPosX_i16: .res 2
Zp_AvatarPosY_i16: .res 2

;;; The current minimap cell that the avatar is in.
.EXPORTZP Zp_AvatarMinimapRow_u8, Zp_AvatarMinimapCol_u8
Zp_AvatarMinimapRow_u8: .res 1
Zp_AvatarMinimapCol_u8: .res 1

;;; The current velocity of the player avatar, in subpixels per frame.
Zp_AvatarVelX_i16: .res 2
Zp_AvatarVelY_i16: .res 2

;;; The object flags to apply for the player avatar.  In particular, if
;;; bObj::FlipH is set, then the avatar will face left instead of right.
Zp_AvatarFlags_bObj: .res 1

;;; What mode the avatar is currently in (e.g. standing, jumping, etc.).
Zp_AvatarMode_eAvatar: .res 1

;;; How many more frames the player avatar should stay in eAvatar::Landing mode
;;; (after landing from a jump).
Zp_AvatarRecover_u8: .res 1

;;; The index of the device that the player avatar is near, or $ff if none.
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
    ;; Position the avatar in front of device number Zp_NearbyDevice_u8.
    ldx Zp_NearbyDevice_u8
    lda #0
    sta Zp_AvatarPosX_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
    lda Ram_DeviceBlockCol_u8_arr, x
    .assert kMaxRoomWidthBlocks <= $80, error
    asl a      ; Since kMaxRoomWidthBlocks <= $80, the device block col fits in
    .repeat 3  ; seven bits, so the first ASL won't set the carry bit, so we
    asl a      ; only need to ROL (Zp_AvatarPosX_i16 + 1) after the second ASL.
    rol Zp_AvatarPosX_i16 + 1
    .endrepeat
    ora #$06
    sta Zp_AvatarPosX_i16 + 0
    lda Ram_DeviceBlockRow_u8_arr, x
    .assert kTallRoomHeightBlocks <= $20, error
    asl a  ; Since kTallRoomHeightBlocks <= $20, the device block row fits in
    asl a  ; five bits, so the first three ASL's won't set the carry bit, so
    asl a  ; we only need to ROL (Zp_AvatarPosY_i16 + 1) after the fourth ASL.
    asl a
    rol Zp_AvatarPosY_i16 + 1
    ora #kBlockHeightPx - kAvatarBoundingBoxDown
    sta Zp_AvatarPosY_i16 + 0
    ;; Make the avatar stand still, facing to the right.
    lda #eAvatar::Standing
    sta Zp_AvatarMode_eAvatar
    lda #0
    sta Zp_AvatarRecover_u8
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    sta Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 1
    lda #kAvatarPalette
    sta Zp_AvatarFlags_bObj
    .assert * = Main_Explore_Unpause, error, "fallthrough"
.ENDPROC

;;; Mode for exploring and platforming within a room, when continuing after
;;; the pause screen (or when the room is otherwise loaded, but with the screen
;;; faded out).
;;; @prereq Rendering is disabled.
;;; @prereq Room is loaded and avatar is positioned.
.EXPORT Main_Explore_Unpause
.PROC Main_Explore_Unpause
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
_InitObjects:
    lda #0
    sta Zp_OamOffset_u8
    jsr Func_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
_FadeIn:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
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
    jsr Func_DrawObjectsForRoom
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
    lda Ram_DeviceTarget_u8_arr, x  ; param: dialog index
    jmp Main_Dialog_OpenWindow
    @lever:
    jsr Func_ToggleLeverDevice
    @done:
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    prga_bank #<.bank(FuncA_Terrain_ScrollTowardsGoal)
    jsr FuncA_Terrain_ScrollTowardsGoal
_Tick:
    jsr Func_TickAllDevices
    jsr Func_ExecuteAllMachines
    prga_bank #<.bank(FuncA_Terrain_ExploreMoveAvatar)
    jsr FuncA_Terrain_ExploreMoveAvatar  ; clears Z if door; returns eDoor in A
    beq _GameLoop
    .assert * = Main_Explore_GoThroughDoor, error, "fallthrough"
.ENDPROC

;;; Mode for leaving the current room through a door and entering the next
;;; room.
;;; @param A The eDoor value for the side of the room the player hit.
.PROC Main_Explore_GoThroughDoor
    ;; Fade out the current room.
    pha  ; eDoor value
    jsr Func_DrawObjectsForRoom
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
    jmp Main_Explore_Unpause
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
.PROC _SetScrollGoalY
    lda Zp_AvatarPosY_i16 + 0
    lsr Zp_Tmp1_byte
    sub Zp_Tmp1_byte
    tax
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    bmi _MinGoal
    bne _MaxGoal
    txa
    cmp Zp_Tmp2_byte
    blt _SetGoal
_MaxGoal:
    lda Zp_Tmp2_byte
    jmp _SetGoal
_MinGoal:
    lda #0
_SetGoal:
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

;;; Recomputes Zp_AvatarMinimapRow_u8 and Zp_AvatarMinimapCol_u8 from the
;;; avatar's current position and room, then (if necessary) updates SRAM to
;;; mark that minimap cell as explored.
.PROC Func_UpdateAndMarkMinimap
_UpdateMinimapRow:
    ldy <(Zp_Current_sRoom + sRoom::MinimapStartRow_u8)
    bit <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bpl @upperHalf
    @tall:
    lda Zp_AvatarPosY_i16 + 1
    bmi @upperHalf
    bne @lowerHalf
    lda Zp_AvatarPosY_i16 + 0
    cmp #(kTallRoomHeightBlocks / 2) * kBlockHeightPx
    blt @upperHalf
    @lowerHalf:
    iny
    @upperHalf:
    sty Zp_AvatarMinimapRow_u8
_UpdateMinimapCol:
    lda Zp_AvatarPosX_i16 + 1
    bmi @leftSide
    cmp <(Zp_Current_sRoom + sRoom::MinimapWidth_u8)
    blt @middle
    @rightSide:
    ldx <(Zp_Current_sRoom + sRoom::MinimapWidth_u8)
    dex
    txa
    @middle:
    add <(Zp_Current_sRoom + sRoom::MinimapStartCol_u8)
    bcc @setCol  ; unconditional
    @leftSide:
    lda <(Zp_Current_sRoom + sRoom::MinimapStartCol_u8)
    @setCol:
    sta Zp_AvatarMinimapCol_u8
_MarkMinimap:
    ;; Determine the bitmask to use for Sram_Minimap_u16_arr, and store it in
    ;; Zp_Tmp1_byte.
    lda Zp_AvatarMinimapRow_u8
    tay
    and #$07
    tax
    lda Data_PowersOfTwo_u8_arr8, x
    sta Zp_Tmp1_byte  ; mask
    ;; Calculate the byte offset into Sram_Minimap_u16_arr and store it in X.
    lda Zp_AvatarMinimapCol_u8
    mul #2
    tax  ; byte index into Sram_Minimap_u16_arr
    cpy #$08
    blt @loByte
    inx
    @loByte:
    ;; Check if minimap needs to be updated.
    lda Sram_Minimap_u16_arr, x
    ora Zp_Tmp1_byte  ; mask
    cmp Sram_Minimap_u16_arr, x
    beq @done
    ;; Enable writes to SRAM.
    ldy #bMmc3PrgRam::Enable
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Update minimap.
    sta Sram_Minimap_u16_arr, x
    ;; Disable writes to SRAM.
    ldy #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sty Hw_Mmc3PrgRamProtect_wo
    @done:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for everything in the room that should
;;; always be visible: the player avatar, machines, enemies, and devices.
.EXPORT Func_DrawObjectsForRoom
.PROC Func_DrawObjectsForRoom
    jsr Func_DrawObjectsForPlayerAvatar
    jsr Func_DrawObjectsForDevicePrompt
    jsr Func_DrawObjectsForAllMachines
    ;; TODO: Draw objects for e.g. enemies
    jmp Func_DrawObjectsForAllDevices
.ENDPROC

;;; Allocates and populates OAM slots for the player avatar.
.PROC Func_DrawObjectsForPlayerAvatar
    ;; Calculate screen-space Y-position.
    lda Zp_AvatarPosY_i16 + 0
    sub Zp_PpuScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Calculate screen-space X-position.
    lda Zp_AvatarPosX_i16 + 0
    sub Zp_PpuScrollX_u8
    sta Zp_ShapePosX_i16 + 0
    lda Zp_AvatarPosX_i16 + 1
    sbc Zp_ScrollXHi_u8
    sta Zp_ShapePosX_i16 + 1
    ;; Allocate objects.
    jsr Func_AllocObjectsFor2x2Shape  ; sets C if offscreen; returns Y
    bcs _Done
_ObjectFlags:
    lda Zp_AvatarFlags_bObj
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    and #bObj::FlipH
    bne _ObjectTilesFacingLeft
_ObjectTilesFacingRight:
    lda Zp_AvatarMode_eAvatar
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    bne _Done  ; unconditional
_ObjectTilesFacingLeft:
    lda Zp_AvatarMode_eAvatar
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
_Done:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the visual prompt that appears when
;;; the player avatar is near a device.
.PROC Func_DrawObjectsForDevicePrompt
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

.SEGMENT "PRGA_Terrain"

;;; Updates the scroll position for next frame to move closer to
;;; Zp_ScrollGoalX_u16 and Zp_ScrollGoalY_u8, transferring nametable updates
;;; for the current room as necessary.
.EXPORT FuncA_Terrain_ScrollTowardsGoal
.PROC FuncA_Terrain_ScrollTowardsGoal
    ;; TODO: track towards the goal instead of locking directly onto it
    lda Zp_ScrollGoalY_u8
    sta Zp_PpuScrollY_u8
_ScrollHorz:
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
    ;; Update the current scroll.
    ;; TODO: track towards the goal instead of locking directly onto it
    ldya Zp_ScrollGoalX_u16
    sty Zp_ScrollXHi_u8
    sta Zp_PpuScrollX_u8
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
    lda Zp_Tmp2_byte
    cmp Zp_Tmp1_byte
    beq _DoneTransfer
    bmi _DoTransfer
    add #kScreenWidthTiles - 1
_DoTransfer:
    jsr FuncA_Terrain_TransferTileColumn
_DoneTransfer:
    rts
.ENDPROC

;;; Updates the player avatar state based on the current joypad state.
;;; @return Z Cleared if the player avatar hit a door, set otherwise.
;;; @return A The eDoor that the player avatar hit, or eDoor::None for none.
.PROC FuncA_Terrain_ExploreMoveAvatar
.PROC _PlayerApplyJoypad
_JoypadLeft:
    ;; Check D-pad left.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Left
    beq @noLeft
    ;; If left and right are both held, ignore both.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Right
    bne _NeitherLeftNorRight
    ;; Accelerate to the left.
    lda Zp_AvatarVelX_i16 + 0
    sub #kAvatarHorzAccel
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    sbc #0
    bpl @noMax
    cmp #$ff & (1 - kAvatarMaxSpeedX)
    bge @noMax
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda #$ff & -kAvatarMaxSpeedX
    @noMax:
    sta Zp_AvatarVelX_i16 + 1
    lda #kAvatarPalette | bObj::FlipH
    sta Zp_AvatarFlags_bObj
    bne _DoneLeftRight  ; unconditional
    @noLeft:
_JoypadRight:
    ;; Check D-pad right.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Right
    beq @noRight
    ;; Accelerate to the right.
    lda Zp_AvatarVelX_i16 + 0
    add #kAvatarHorzAccel
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    adc #0
    bmi @noMax
    cmp #kAvatarMaxSpeedX
    blt @noMax
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    lda #kAvatarMaxSpeedX
    @noMax:
    sta Zp_AvatarVelX_i16 + 1
    lda #kAvatarPalette
    sta Zp_AvatarFlags_bObj
    .assert kAvatarPalette > 0, error
    bne _DoneLeftRight  ; unconditional
    @noRight:
_NeitherLeftNorRight:
    ;; Decelerate.
    lda Zp_AvatarVelX_i16 + 1
    bmi @negative
    bne @positive
    lda Zp_AvatarVelX_i16 + 0
    cmp #kAvatarHorzAccel
    blt @stop
    @positive:
    ldy #$ff & -kAvatarHorzAccel
    ldx #$ff
    bne @decel  ; unconditional
    @negative:
    ldy #kAvatarHorzAccel
    ldx #0
    beq @decel  ; unconditional
    @stop:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    beq _DoneLeftRight  ; unconditional
    @decel:
    tya
    add Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 0
    txa
    adc Zp_AvatarVelX_i16 + 1
    sta Zp_AvatarVelX_i16 + 1
_DoneLeftRight:
    lda Zp_AvatarMode_eAvatar
    cmp #kFirstAirborneAvatarMode
    bge _Airborne
_Grounded:
    ;; If the player presses the jump button while grounded, start a jump.
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::AButton
    beq _DoneJump
    ;; TODO: play a jumping sound
    ldax #kAvatarJumpVelocity
    stax Zp_AvatarVelY_i16
    lda #eAvatar::Jumping
    sta Zp_AvatarMode_eAvatar
    bne _DoneJump  ; unconditional
_Airborne:
    ;; If the player stops holding the jump button while airborne, cap the
    ;; upward speed to kAvatarStopJumpSpeed (that is, the Y velocity will be
    ;; greater than or equal to -kAvatarStopJumpSpeed).
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::AButton
    bne _DoneJump
    lda Zp_AvatarVelY_i16 + 1
    bpl _DoneJump
    cmp #$ff & -kAvatarStopJumpSpeed
    bge _DoneJump
    lda #$ff & -kAvatarStopJumpSpeed
    sta Zp_AvatarVelY_i16 + 1
    lda #$00
    sta Zp_AvatarVelY_i16 + 0
_DoneJump:
.ENDPROC
.PROC _ApplyVelX
    ldy #0
    lda Zp_AvatarVelX_i16 + 1
    bpl @nonnegative
    dey  ; now y is $ff
    @nonnegative:
    lda Zp_AvatarVelX_i16 + 1
    add Zp_AvatarPosX_i16 + 0
    sta Zp_AvatarPosX_i16 + 0
    tya
    adc Zp_AvatarPosX_i16 + 1
    sta Zp_AvatarPosX_i16 + 1
.ENDPROC
.PROC _DetectHorzDoor
    lda Zp_AvatarVelX_i16 + 1
    bmi _Western
_Eastern:
    ;; Calculate the room pixel X-position where the avatar will be offscreen
    ;; to the right, storing the result in Zp_Tmp1_byte (lo) and A (hi).
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 0)
    add #<(kScreenWidthPx + kAvatarBoundingBoxLeft)
    sta Zp_Tmp1_byte
    lda <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 1)
    adc #>(kScreenWidthPx + kAvatarBoundingBoxLeft)
    ;; Compare the avatar's position to the offscreen position.
    cmp Zp_AvatarPosX_i16 + 1
    beq @checkLoByte
    bge _NoHitDoor
    @hitDoor:
    lda #eDoor::Eastern
    rts
    @checkLoByte:
    lda Zp_AvatarPosX_i16 + 0
    cmp Zp_Tmp1_byte  ; door X-position (lo)
    bge @hitDoor
    blt _NoHitDoor  ; unconditional
_Western:
    ;; If the avatar's X-position is negative, then we definitely hit the
    ;; western door (although this should not happen in practice).  On the
    ;; other hand, if the hi byte of the avatar's X-position is greater than
    ;; zero, then we definitely didn't hit the western door.
    lda Zp_AvatarPosX_i16 + 1
    bmi @hitDoor
    bne _NoHitDoor
    ;; Calculate the room pixel X-position where the avatar will be fully
    ;; hidden by the one-tile-wide mask on the left side of the screen, storing
    ;; the result in A.
    lda <(Zp_Current_sRoom + sRoom::MinScrollX_u8 + 0)
    add #kTileWidthPx - kAvatarBoundingBoxRight
    ;; Compare the avatar's position to the offscreen position.  By this point,
    ;; we already know that the hi byte of the avatar's position is zero.
    cmp Zp_AvatarPosX_i16 + 0
    blt _NoHitDoor
    @hitDoor:
    lda #eDoor::Western
    rts
_NoHitDoor:
.ENDPROC
.PROC _DetectHorzCollision
    ;; Calculate the room block row index that the avatar's feet are in, and
    ;; store it in Zp_Tmp1_byte.
    lda Zp_AvatarPosY_i16 + 0
    add #kAvatarBoundingBoxDown - 1
    sta Zp_Tmp1_byte
    lda Zp_AvatarPosY_i16 + 1
    adc #0
    .repeat 4
    lsr a
    ror Zp_Tmp1_byte
    .endrepeat
    ;; Calculate the room block row index that the avatar's head is in, and
    ;; store it in Zp_Tmp2_byte.
    lda Zp_AvatarPosY_i16 + 0
    sub #kAvatarBoundingBoxUp
    sta Zp_Tmp2_byte
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    .repeat 4
    lsr a
    ror Zp_Tmp2_byte
    .endrepeat
    ;; Check if the player is moving to the left or to the right.
    lda Zp_AvatarVelX_i16 + 1
    bmi _Left
_Right:
    ;; Calculate the room tile column index at the avatar's right side, and
    ;; store it in Zp_Tmp3_byte.
    lda Zp_AvatarPosX_i16 + 0
    add #kAvatarBoundingBoxRight + 1
    sta Zp_Tmp3_byte
    lda Zp_AvatarPosX_i16 + 1
    adc #0
    .repeat 3
    lsr a
    ror Zp_Tmp3_byte
    .endrepeat
    ;; Check for tile collisions.
    lda Zp_Tmp3_byte  ; param: room tile column index (right side of avatar)
    jsr FuncA_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp1_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    bge @solid
    ldy Zp_Tmp2_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    blt _Done
    ;; We've hit the right wall, so set horizontal velocity to zero, and set
    ;; horizontal position to just to the left of the wall we hit.
    @solid:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    .repeat 3
    asl Zp_Tmp3_byte
    rol a
    .endrepeat
    tax
    lda Zp_Tmp3_byte
    sub #kAvatarBoundingBoxRight
    sta Zp_AvatarPosX_i16 + 0
    txa
    sbc #0
    sta Zp_AvatarPosX_i16 + 1
    jmp _Done
_Left:
    ;; Calculate the room tile column index to the left of the avatar, and
    ;; store it in Zp_Tmp3_byte.
    lda Zp_AvatarPosX_i16 + 0
    sub #kAvatarBoundingBoxLeft + 1
    sta Zp_Tmp3_byte
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    .repeat 3
    lsr a
    ror Zp_Tmp3_byte
    .endrepeat
    ;; Check for tile collisions.
    lda Zp_Tmp3_byte  ; param: room tile column index (left side of avatar)
    jsr FuncA_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp1_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    bge @solid
    ldy Zp_Tmp2_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    blt _Done
    ;; We've hit the left wall, so set horizontal velocity to zero, and set
    ;; horizontal position to just to the right of the wall we hit.
    @solid:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    .repeat 3
    asl Zp_Tmp3_byte
    rol a
    .endrepeat
    tax
    lda Zp_Tmp3_byte
    add #kTileWidthPx + kAvatarBoundingBoxLeft
    sta Zp_AvatarPosX_i16 + 0
    txa
    adc #0
    sta Zp_AvatarPosX_i16 + 1
_Done:
.ENDPROC
.PROC _ApplyVelY
    ldy #0
    lda Zp_AvatarVelY_i16 + 1
    bpl @nonnegative
    dey  ; now y is $ff
    @nonnegative:
    lda Zp_AvatarVelY_i16 + 1
    add Zp_AvatarPosY_i16 + 0
    sta Zp_AvatarPosY_i16 + 0
    tya
    adc Zp_AvatarPosY_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
.ENDPROC
.PROC _DetectVertDoor
    ;; TODO: Implement top/bottom doors.
.ENDPROC
.PROC _DetectVertCollision
    ;; Calculate the room tile column index that the avatar's left side is in,
    ;; and store it in Zp_Tmp1_byte.
    lda Zp_AvatarPosX_i16 + 0
    sub #kAvatarBoundingBoxLeft
    sta Zp_Tmp1_byte
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    .repeat 3
    lsr a
    ror Zp_Tmp1_byte
    .endrepeat
    ;; Calculate the room tile column index at the avatar's right side is in,
    ;; and store it in Zp_Tmp2_byte.
    lda Zp_AvatarPosX_i16 + 0
    add #kAvatarBoundingBoxRight - 1
    sta Zp_Tmp2_byte
    lda Zp_AvatarPosX_i16 + 1
    adc #0
    .repeat 3
    lsr a
    ror Zp_Tmp2_byte
    .endrepeat
    ;; Check if the player is moving up or down.
    lda Zp_AvatarVelY_i16 + 1
    bpl _Down
_Up:
    ;; Calculate the room block row index just above the avatar's head, and
    ;; store it in Zp_Tmp3_byte.
    lda Zp_AvatarPosY_i16 + 0
    sub #kAvatarBoundingBoxUp + 1
    sta Zp_Tmp3_byte
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    .repeat 4
    lsr a
    ror Zp_Tmp3_byte
    .endrepeat
    ;; Check for tile collisions.
    lda Zp_Tmp1_byte  ; param: room tile column index (left side of avatar)
    jsr FuncA_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    bge @solid
    lda Zp_Tmp2_byte  ; param: room tile column index (right side of avatar)
    jsr FuncA_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    blt @done
    @solid:
    ;; We've hit the ceiling, so set vertical velocity to zero, and set
    ;; vertical position to just below the ceiling we hit.
    lda #0
    sta Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 1
    .repeat 4
    asl Zp_Tmp3_byte
    rol a
    .endrepeat
    tax
    lda Zp_Tmp3_byte
    add #kBlockHeightPx + kAvatarBoundingBoxUp
    sta Zp_AvatarPosY_i16 + 0
    txa
    adc #0
    sta Zp_AvatarPosY_i16 + 1
    @done:
    jmp _Done
_Down:
    ;; Calculate the room block row index just below the avatar's feet, and
    ;; store it in Zp_Tmp3_byte.
    lda Zp_AvatarPosY_i16 + 0
    add #kAvatarBoundingBoxDown
    sta Zp_Tmp3_byte
    lda Zp_AvatarPosY_i16 + 1
    adc #0
    .repeat 4
    lsr a
    ror Zp_Tmp3_byte
    .endrepeat
    ;; Check for tile collisions.
    lda Zp_Tmp1_byte  ; param: room tile column index (left side of avatar)
    jsr FuncA_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    bge @solid
    lda Zp_Tmp2_byte  ; param: room tile column index (right side of avatar)
    jsr FuncA_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    cmp #kFirstSolidTerrainType
    bge @solid
    @empty:
    ;; There's no floor beneath us, so start falling.
    lda Zp_AvatarVelY_i16 + 1
    cmp #2
    blt @floating
    lda #eAvatar::Falling
    bne @setMode  ; unconditional
    @floating:
    lda #eAvatar::Floating
    @setMode:
    sta Zp_AvatarMode_eAvatar
    jmp _Done
    @solid:
    ;; We've hit the floor, so update the avatar mode.
    lda Zp_AvatarMode_eAvatar
    cmp #kFirstAirborneAvatarMode
    bge @wasAirborne
    lda Zp_AvatarRecover_u8
    beq @standOrRun
    dec Zp_AvatarRecover_u8
    bne @doneRecover
    @standOrRun:
    lda Zp_AvatarVelX_i16 + 1
    beq @standing
    lda Zp_FrameCounter_u8
    and #$08
    bne @running2
    @running1:
    lda #eAvatar::Running1
    bne @setAvatarMode  ; unconditional
    @running2:
    lda #eAvatar::Running2
    bne @setAvatarMode  ; unconditional
    @standing:
    lda #eAvatar::Standing
    bne @setAvatarMode  ; unconditional
    @wasAirborne:
    ldx Zp_AvatarVelY_i16 + 1
    lda DataA_Terrain_AvatarRecoverFrames_u8_arr, x
    beq @standOrRun
    sta Zp_AvatarRecover_u8
    lda #eAvatar::Landing
    @setAvatarMode:
    sta Zp_AvatarMode_eAvatar
    @doneRecover:
    ;; Set vertical velocity to zero, and set vertical position to just above
    ;; the floor we hit.
    lda #0
    sta Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 1
    .repeat 4
    asl Zp_Tmp3_byte
    rol a
    .endrepeat
    tax
    lda Zp_Tmp3_byte
    sub #kAvatarBoundingBoxDown
    sta Zp_AvatarPosY_i16 + 0
    txa
    sbc #0
    sta Zp_AvatarPosY_i16 + 1
_Done:
.ENDPROC
    jsr Func_UpdateAndMarkMinimap
.PROC _ApplyGravity
    ;; Only apply gravity if the player avatar is airborne.
    lda Zp_AvatarMode_eAvatar
    cmp #kFirstAirborneAvatarMode
    blt @noGravity
    ;; Accelerate the player avatar downwards.
    lda #kAvatarGravity
    add Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 0
    lda #0
    adc Zp_AvatarVelY_i16 + 1
    ;; If moving downward, check for terminal velocity:
    bmi @setVelYHi
    cmp #kAvatarMaxSpeedY
    blt @setVelYHi
    lda #0
    sta Zp_AvatarVelY_i16 + 0
    lda #kAvatarMaxSpeedY
    @setVelYHi:
    sta Zp_AvatarVelY_i16 + 1
    @noGravity:
.ENDPROC
    lda #eDoor::None  ; indicate that no door was hit
    rts
.ENDPROC

;;; Maps from non-negative (Zp_AvatarVelY_i16 + 1) values to the value to set
;;; for Zp_AvatarRecover_u8.  The higher the downward speed, the longer the
;;; recovery time.
.PROC DataA_Terrain_AvatarRecoverFrames_u8_arr
:   .byte 0, 0, 8, 8, 12, 18
    .assert * - :- = kAvatarMaxSpeedY + 1, error
.ENDPROC

;;;=========================================================================;;;
