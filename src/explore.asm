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
.IMPORT Func_ClearRestOfOam
.IMPORT Func_FadeIn
.IMPORT Func_ProcessFrame
.IMPORT Func_UpdateButtons
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsHeld_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask

;;;=========================================================================;;;

;;; The largest value that may be stored in Zp_ScrollGoalY_u8.
kMaxScrolllY = kTallRoomHeightBlocks * kBlockHeightPx - kScreenHeightPx

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
;;; the room anyway).  Since kMaxScrolllY fits in one byte, this only needs to
;;; be one byte (unlike Zp_ScrollGoalX_u16).
.ASSERT kMaxScrolllY <= $ff, error
Zp_ScrollGoalY_u8: .res 1

;;; The high byte of the current horizontal scroll position (the low byte is
;;; stored in Zp_PpuScrollX_u8, and together they form a single u16).  This
;;; high byte doesn't matter for PPU scrolling, but does matter for comparisons
;;; of the current scroll position with Zp_ScrollGoalX_u16.
Zp_ScrollXHi_u8: .res 1

;;; The current X/Y positions of the player avatar, in room-space pixels.
Zp_AvatarPosX_i16: .res 2
Zp_AvatarPosY_i16: .res 2

;;;=========================================================================;;;

.SEGMENT "PRG8_Explore"

;;; Mode for exploring and platforming within rooms.
;;; @prereq Rendering is disabled.
.EXPORT Main_Explore
.PROC Main_Explore
    lda #0
    sta Zp_ScrollGoalX_u16 + 0
    sta Zp_ScrollGoalX_u16 + 1
    sta Zp_ScrollGoalY_u8
    sta Zp_ScrollXHi_u8
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    sta Zp_AvatarPosX_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
    lda #128
    sta Zp_AvatarPosX_i16 + 0
    lda #120
    sta Zp_AvatarPosY_i16 + 0
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
_GameLoop:
    jsr Func_UpdateButtons
    jsr Func_SetScrollGoalFromAvatar
    jsr Func_ScrollTowardsGoal
    jsr Func_ExploreMoveAvatar
    jsr Func_ExploreDrawAvatar
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jmp _GameLoop
.ENDPROC

;;; Sets Zp_ScrollGoalX_u16 and Zp_ScrollGoalY_u8 such that the player avatar
;;; would be as close to the center of the screen as possible, while still
;;; keeping the scroll goal within the valid range for the current room.
.PROC Func_SetScrollGoalFromAvatar
    ;; If we're in a tall room, we can scroll vertically...
    bit <(Zp_Current_sRoom + sRoom::IsTall_bool)
    bmi _Vert
    ;; ...but if we're in a short room, lock the vertical scroll to zero and
    ;; just scroll horizontally.
    lda #0
    sta Zp_ScrollGoalY_u8
    beq _Horz  ; unconditional
.PROC _Vert
    lda Zp_AvatarPosY_i16 + 0
    sub #kScreenHeightPx / 2
    tax
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    bmi _MinGoal
    bne _MaxGoal
    txa
    cmp #kMaxScrolllY
    blt _SetGoal
_MaxGoal:
    lda #kMaxScrolllY
    bne _SetGoal  ; unconditional
_MinGoal:
    lda #0
_SetGoal:
    sta Zp_ScrollGoalY_u8
.ENDPROC
.PROC _Horz
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
.PROC Func_ScrollTowardsGoal
    ;; TODO: track towards the goal instead of locking directly onto it
    ldax Zp_ScrollGoalX_u16
    stx Zp_PpuScrollX_u8
    sta Zp_ScrollXHi_u8
    ;; TODO: transfer terrain tile columns to the PPU as we scroll horizontally
    lda Zp_ScrollGoalY_u8
    sta Zp_PpuScrollY_u8
    rts
.ENDPROC

;;; Updates the player avatar state based on the current joypad state.
.PROC Func_ExploreMoveAvatar
    ;; Check D-pad left.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Left
    beq @noLeft
    lda Zp_AvatarPosX_i16 + 0
    sub #2
    sta Zp_AvatarPosX_i16 + 0
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    sta Zp_AvatarPosX_i16 + 1
    @noLeft:
    ;; Check D-pad right.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Right
    beq @noRight
    lda Zp_AvatarPosX_i16 + 0
    add #2
    sta Zp_AvatarPosX_i16 + 0
    lda Zp_AvatarPosX_i16 + 1
    adc #0
    sta Zp_AvatarPosX_i16 + 1
    @noRight:
    ;; Check D-pad up.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Up
    beq @noUp
    lda Zp_AvatarPosY_i16 + 0
    sub #2
    sta Zp_AvatarPosY_i16 + 0
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    sta Zp_AvatarPosY_i16 + 1
    @noUp:
    ;; Check D-pad down.
    lda Zp_P1ButtonsHeld_bJoypad
    and #bJoypad::Down
    beq @noDown
    lda Zp_AvatarPosY_i16 + 0
    add #2
    sta Zp_AvatarPosY_i16 + 0
    lda Zp_AvatarPosY_i16 + 1
    adc #0
    sta Zp_AvatarPosY_i16 + 1
    @noDown:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the player avatar based on its
;;; current state.
.PROC Func_ExploreDrawAvatar
    ldy Zp_OamOffset_u8
    ;; Set X-position.
    lda Zp_AvatarPosX_i16 + 0
    sub Zp_PpuScrollX_u8
    tax
    lda Zp_AvatarPosX_i16 + 1
    sbc Zp_ScrollXHi_u8
    bne @done
    txa
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    ;; Set Y-position.
    lda Zp_AvatarPosY_i16 + 0
    sub Zp_PpuScrollY_u8
    tax
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    bne @done
    txa
    cmp #kScreenHeightPx
    bge @done
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    ;; Set flags.
    lda #0
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    ;; Set tile IDs.
    lda #0
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ;; Update OAM offset.
    tya
    add #.sizeof(sObj)
    sta Zp_OamOffset_u8
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
