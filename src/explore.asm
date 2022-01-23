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

.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT DataC_TallRoom_sRoom
.IMPORT FuncA_Terrain_FillNametables
.IMPORT FuncA_Terrain_GetColumnPtrForTileIndex
.IMPORT FuncA_Terrain_TransferTileColumn
.IMPORT Func_ClearRestOfOam
.IMPORT Func_FadeIn
.IMPORT Func_ProcessFrame
.IMPORT Func_UpdateButtons
.IMPORT Func_Window_DirectDrawTopBorder
.IMPORT Func_Window_SetUpIrq
.IMPORT Main_Console_OpenWindow
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsHeld_bJoypad
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; How far the player avatar's bounding box extends in each direction from the
;;; avatar's position.
kAvatarBoundingBoxUp = 6
kAvatarBoundingBoxDown = 10
kAvatarBoundingBoxLeft = 5
kAvatarBoundingBoxRight = 5

;;; How fast the player avatar is allowed to move, in pixels per frame.
kAvatarMaxSpeedX = 2
kAvatarMaxSpeedY = 5

;;; The horizontal acceleration applied to the player avatar when holding the
;;; left/right arrows, in subpixels per frame per frame.
kAvatarHorzAccel = 70

;;; The (signed, 16-bit) initial velocity of the player avatar when jumping, in
;;; subpixels per frame.
kAvatarJumpVelocity = $ffff & -810

;;; The vertical acceleration applied to the player avatar when in midair, in
;;; subpixels per frame per frame.
kAvatarGravity = 48

;;; Modes that the player avatar can be in.  The number for each of these enum
;;; values is the starting tile ID to use for the avatar objects when the
;;; avatar is in that mode.
.ENUM ePlayer
    Standing = $08
    Reading  = $0c
    Running  = $10
    Jumping  = $14
.ENDENUM

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
;;; of the current scroll position with Zp_ScrollGoalX_u16.
Zp_ScrollXHi_u8: .res 1

;;; The current X/Y positions of the player avatar, in room-space pixels.
Zp_AvatarPosX_i16: .res 2
Zp_AvatarPosY_i16: .res 2

;;; The current velocity of the player avatar, in subpixels per frame.
Zp_AvatarVelX_i16: .res 2
Zp_AvatarVelY_i16: .res 2

;;; The object flags to apply for the player avatar.  In particular, if
;;; bObj::FlipH is set, then the avatar will face left instead of right.
Zp_AvatarFlags_bObj: .res 1

;;; What mode the avatar is currently in (e.g. standing, jumping, etc.).
Zp_AvatarMode_ePlayer: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8_Explore"

;;; Mode for exploring and platforming within a room, when entering the room
;;; e.g. from a door or from the title screen.
;;; @prereq Rendering is disabled.
.EXPORT Main_Explore_Enter
.PROC Main_Explore_Enter
    lda #0
    sta Zp_ScrollGoalX_u16 + 0
    sta Zp_ScrollGoalX_u16 + 1
    sta Zp_ScrollGoalY_u8
    sta Zp_ScrollXHi_u8
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    sta Zp_AvatarVelY_i16 + 0
    sta Zp_AvatarVelY_i16 + 1
    sta Zp_AvatarPosX_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
    sta Zp_AvatarFlags_bObj
    lda #$88
    sta Zp_AvatarPosX_i16 + 0
    lda #$66
    sta Zp_AvatarPosY_i16 + 0
    lda #ePlayer::Standing
    sta Zp_AvatarMode_ePlayer
_InitializeWindow:
    lda #$ff
    sta Zp_WindowTop_u8
    jsr Func_Window_SetUpIrq
    jsr Func_Window_DirectDrawTopBorder
_LoadRoom:
    prgc_bank #<.bank(DataC_TallRoom_sRoom)
    ldx #.sizeof(sRoom) - 1
    @loop:
    lda DataC_TallRoom_sRoom, x
    sta Zp_Current_sRoom, x
    dex
    bpl @loop
_DrawTerrain:
    prga_bank #<.bank(FuncA_Terrain_FillNametables)
    lda #0  ; param: left block column index
    jsr FuncA_Terrain_FillNametables
_InitObjects:
    lda #0
    sta Zp_OamOffset_u8
    jsr Func_ExploreDrawAvatar
    jsr Func_ClearRestOfOam
_FadeIn:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
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
    jsr Func_ExploreDrawAvatar
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
    jsr Func_SetScrollGoalFromAvatar
    jsr Func_ScrollTowardsGoal
.PROC _CheckForPause
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    jne Main_Console_OpenWindow
.ENDPROC
    jsr Func_ExploreMoveAvatar
    jmp _GameLoop
.ENDPROC

;;; Sets Zp_ScrollGoalX_u16 and Zp_ScrollGoalY_u8 such that the player avatar
;;; would be as close to the center of the screen as possible, while still
;;; keeping the scroll goal within the valid range for the current room.
.EXPORT Func_SetScrollGoalFromAvatar
.PROC Func_SetScrollGoalFromAvatar
    ;; Calculate half visible height of the screen (the part not covered by the
    ;; window), and store it in Zp_Tmp1_byte.
    lda Zp_WindowTop_u8
    cmp #kScreenHeightPx
    blt @windowVisible
    lda #kScreenHeightPx
    @windowVisible:
    sta Zp_Tmp1_byte
    ;; Calculate the maximum permitted scroll-Y and store it in Zp_Tmp2_byte.
    lda #kScreenHeightPx
    bit <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bpl @shortRoom
    lda #<(kTallRoomHeightBlocks * kBlockHeightPx)
    @shortRoom:
    sub Zp_Tmp1_byte
    sta Zp_Tmp2_byte
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
    lda Zp_AvatarPosX_i16 + 0
    sub #kScreenWidthPx / 2
    tax
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    bmi _MinGoal
    cmp <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 1)
    blt _Done
    bne _MaxGoal
    cpx <(Zp_Current_sRoom + sRoom::MaxScrollX_u16 + 0)
    blt _Done
_MaxGoal:
    ldax <(Zp_Current_sRoom + sRoom::MaxScrollX_u16)
    jmp _Done
_MinGoal:
    lda #0
    tax
_Done:
    stax Zp_ScrollGoalX_u16
.ENDPROC
    rts
.ENDPROC

;;; Updates the scroll position for next frame to move closer to
;;; Zp_ScrollGoalX_u16 and Zp_ScrollGoalY_u8, transferring nametable updates
;;; for the current room as necessary.
.EXPORT Func_ScrollTowardsGoal
.PROC Func_ScrollTowardsGoal
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
    tax
    prga_bank #<.bank(FuncA_Terrain_TransferTileColumn)
    txa
    jsr FuncA_Terrain_TransferTileColumn
_DoneTransfer:
    rts
.ENDPROC

;;; Updates the player avatar state based on the current joypad state.
;;; TODO: This should probably be in the same PRGA bank as terrain functions.
.PROC Func_ExploreMoveAvatar
    jsr Func_PlayerApplyJoypad
_ApplyVelX:
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
    prga_bank #<.bank(FuncA_Terrain_GetColumnPtrForTileIndex)
    lda Zp_Tmp3_byte  ; param: room tile column index (right side of avatar)
    jsr FuncA_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp1_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    bne @solid
    ldy Zp_Tmp2_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    beq _Done
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
    prga_bank #<.bank(FuncA_Terrain_GetColumnPtrForTileIndex)
    lda Zp_Tmp3_byte  ; param: room tile column index (left side of avatar)
    jsr FuncA_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp1_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    bne @solid
    ldy Zp_Tmp2_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    beq _Done
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
_ApplyVelY:
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
    bmi _Up
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
    prga_bank #<.bank(FuncA_Terrain_GetColumnPtrForTileIndex)
    lda Zp_Tmp1_byte  ; param: room tile column index (left side of avatar)
    jsr FuncA_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    bne @solid
    lda Zp_Tmp2_byte  ; param: room tile column index (right side of avatar)
    jsr FuncA_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (bottom of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    bne @solid
    @empty:
    ;; There's no floor beneath us, so start falling.
    lda #ePlayer::Jumping
    sta Zp_AvatarMode_ePlayer
    jmp _Done
    @solid:
    ;; We've hit the floor, so end jumping mode, set vertical velocity to zero,
    ;; and set vertical position to just above the floor we hit.
    lda #ePlayer::Standing
    sta Zp_AvatarMode_ePlayer
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
    jmp _Done
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
    prga_bank #<.bank(FuncA_Terrain_GetColumnPtrForTileIndex)
    lda Zp_Tmp1_byte  ; param: room tile column index (left side of avatar)
    jsr FuncA_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    bne @solid
    lda Zp_Tmp2_byte  ; param: room tile column index (right side of avatar)
    jsr FuncA_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*_byte
    ldy Zp_Tmp3_byte  ; room block row index (top of avatar)
    lda (Zp_TerrainColumn_u8_arr_ptr), y  ; terrain block type
    beq _Done
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
_Done:
.ENDPROC
_ApplyGravity:
    jsr Func_PlayerApplyGravity
    rts
.ENDPROC

.PROC Func_PlayerApplyJoypad
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
    lda #bObj::FlipH
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
    lda #0
    sta Zp_AvatarFlags_bObj
    beq _DoneLeftRight  ; unconditional
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
    ;; Check A button (jump).
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::AButton
    beq @noJump
    lda #ePlayer::Jumping
    cmp Zp_AvatarMode_ePlayer
    beq @noJump
    sta Zp_AvatarMode_ePlayer
    ldax #kAvatarJumpVelocity
    stax Zp_AvatarVelY_i16
    ;; TODO: play a jumping sound
    @noJump:
    rts
.ENDPROC

.PROC Func_PlayerApplyGravity
    lda Zp_AvatarMode_ePlayer
    cmp #ePlayer::Jumping
    blt @noGravity
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
    rts
.ENDPROC

.EXPORT Func_ExploreDrawAvatar
.PROC Func_ExploreDrawAvatar
    ;; We need to allocate four objects.  If there's not room in OAM, give up.
    ldy Zp_OamOffset_u8
    cpy #.sizeof(sObj) * (kNumOamSlots - 4) + 1
    blt _ObjectYPositions
_NotVisible:
    rts
_ObjectYPositions:
    ;; Determine the avatar's center Y position on screen; if the avatar is
    ;; completely offscreen vertically, return without allocating any objects.
    ;; TODO: Avoid drawing objects on top of the window.
    lda Zp_AvatarPosY_i16 + 0
    sub Zp_PpuScrollY_u8
    tax  ; center Y position on screen
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    bne _NotVisible
    cpx #kScreenHeightPx + kTileHeightPx
    bge _NotVisible
    txa
    ;; Set the vertical positions of the four objects.
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
    sub #kTileHeightPx
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::YPos_u8, y
_ObjectXPositions:
    ;; Determine the avatar's center X position on screen; if the avatar is
    ;; completely offscreen to the left, return without allocating any objects.
    lda Zp_AvatarPosX_i16 + 0
    sub Zp_PpuScrollX_u8
    tax  ; center X position on screen (lo)
    lda Zp_AvatarPosX_i16 + 1
    sbc Zp_ScrollXHi_u8
    sta Zp_Tmp1_byte  ; center X position on screen (hi)
    bmi _NotVisible
    ;; If the center of the avatar is offscreen to the right, hide the two
    ;; right-hand objects.
    beq @rightSide
    lda #$ff
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
    @rightSide:
    txa  ; center X position on screen (lo)
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::XPos_u8, y
    ;; Determine the avatar's left edge X position on screen; if the avatar is
    ;; completely offscreen to the right, return without allocating any
    ;; objects.  If the left edge is offscreen to the left, hide the two
    ;; left-hand objects.
    sub #kTileWidthPx
    tax  ; left X position on screen (lo)
    lda Zp_Tmp1_byte  ; center X position on screen (hi)
    sbc #0
    beq @leftSide
    bpl _NotVisible
    lda #$ff
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    @leftSide:
    txa  ; left X position on screen (lo)
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
_ObjectFlags:
    lda Zp_AvatarFlags_bObj
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    and #bObj::FlipH
    bne _ObjectTilesFacingLeft
_ObjectTilesFacingRight:
    lda Zp_AvatarMode_ePlayer
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    bne _FinishAllocation  ; unconditional
_ObjectTilesFacingLeft:
    lda Zp_AvatarMode_ePlayer
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
_FinishAllocation:
    tya
    add #.sizeof(sObj) * 4
    sta Zp_OamOffset_u8
    rts
.ENDPROC

;;;=========================================================================;;;
