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

.INCLUDE "../actor.inc"
.INCLUDE "../actors/adult.inc"
.INCLUDE "../actors/orc.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../devices/console.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../fade.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../portrait.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Outdoors_sTileset
.IMPORT DataA_Text2_TownSkyFinaleGaveRemote6_Part2_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleGronta_Banished_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleGronta_WeAreBetter_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleJerome_FoolishEnds_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleJerome_HopedBetter_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleJerome_HumanDesires_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleJerome_LockedAway_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleJerome_MaybeThisTime_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleJerome_OrcDesires_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleJerome_Recorded_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleJerome_ToreApart_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleJerome_Well_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleReactivate4_Part2_u8_arr
.IMPORT DataA_Text2_TownSkyFinaleReactivate6_Part2_u8_arr
.IMPORT Data_Empty_sDevice_arr
.IMPORT FuncA_Cutscene_PlaySfxRumbling
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawCoreInnerPlatform
.IMPORT FuncA_Objects_DrawCoreOuterPlatform
.IMPORT FuncA_Objects_DrawTerminalPlatformInFront
.IMPORT FuncA_Objects_MoveShapeRightHalfTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_FadeOutToBlack
.IMPORT Func_Noop
.IMPORT Func_SetAndTransferFade
.IMPORT Func_ShakeRoom
.IMPORT MainA_Cutscene_StartEpilogue
.IMPORT MainA_Cutscene_StartNextFinaleStep
.IMPORT Ppu_ChrObjFinale
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; Actor indices for the NPCs in this room.
kJeromeActorIndex      = 0
kUpperSquareActorIndex = 1
kLowerSquareActorIndex = 2
kGrontaActorIndex      = 3

;;; Platform indices for various parts of the core.
kFinalTerminalPlatformIndex = 0
kCoreInnerPlatformIndex     = 1
kCoreOuterPlatformIndex     = 2

;;; The screen tile column for the leftmost BG tile of the core inner/outer
;;; platform.
kCoreInnerStartCol = $14
kCoreOuterStartCol = $13

;;; The width of each core platform.
kCoreInnerPlatformWidthTiles = 6
kCoreOuterPlatformWidthTiles = 8
kCoreInnerPlatformWidthPx = kTileWidthPx * kCoreInnerPlatformWidthTiles
kCoreOuterPlatformWidthPx = kTileWidthPx * kCoreOuterPlatformWidthTiles

;;; The initial room pixel position for the center of the top edge of the core
;;; inner platform.
kInitCoreTopCenterX = $00b8
kInitCoreTopCenterY = $00d2

;;; The number of VBlank frames per pixel shown as Jerome's hologram is
;;; revealed.
.DEFINE kRevealSlowdown 8

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The first BG tile row that should have tiles for the core inner/outer
    ;; platform.  This is used by this room's FadeIn function to know what BG
    ;; tiles to draw.  Invariant: InnerCoreTerrainStartRow_u8 <=
    ;; OuterCoreTerrainStartRow_u8 <= kScreenHeightTiles.
    InnerCoreTerrainStartRow_u8 .byte
    OuterCoreTerrainStartRow_u8 .byte
    ;; If false ($00), draw the room normally.  If true ($ff), this room's
    ;; DrawRoom function becomes a no-op.
    DoNotDraw_bool .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Town"

.EXPORT DataC_Town_Sky_sRoom
.PROC DataC_Town_Sky_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte Flags_bRoom, bRoom::Unsafe | eArea::Town
    d_byte MinimapStartRow_u8, 0
    d_byte MinimapStartCol_u8, 14
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjFinale)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Outdoors_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, Data_Empty_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncC_Town_Sky_EnterRoom
    d_addr FadeIn_func_ptr, FuncC_Town_Sky_FadeInRoom
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Town_Sky_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/town_sky.room"
    .assert * - :- = 16 * 15, error
_Platforms_sPlatform_arr:
:   .assert * - :- = kFinalTerminalPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16, kInitCoreTopCenterX
    d_word Top_i16, kInitCoreTopCenterY - $10
    D_END
    .assert * - :- = kCoreInnerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kCoreInnerPlatformWidthPx
    d_byte HeightPx_u8, kScreenHeightPx - kInitCoreTopCenterY
    d_word Left_i16, kInitCoreTopCenterX - kCoreInnerPlatformWidthPx / 2
    d_word Top_i16, kInitCoreTopCenterY
    D_END
    .assert * - :- = kCoreOuterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kCoreOuterPlatformWidthPx
    d_byte HeightPx_u8, kScreenHeightPx - kInitCoreTopCenterY - kTileHeightPx
    d_word Left_i16, kInitCoreTopCenterX - kCoreOuterPlatformWidthPx / 2
    d_word Top_i16, kInitCoreTopCenterY + kTileHeightPx
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kJeromeActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0070
    d_word PosY_i16, $0080
    d_byte Param_byte, eNpcAdult::GhostJerome
    D_END
    .assert * - :- = kUpperSquareActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcSquare
    d_word PosX_i16, $0070
    d_word PosY_i16, $0074
    d_byte Param_byte, 0  ; ignored
    D_END
    .assert * - :- = kLowerSquareActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcSquare
    d_word PosX_i16, $0070
    d_word PosY_i16, $0084
    d_byte Param_byte, 0  ; ignored
    D_END
    .assert * - :- = kGrontaActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, $00b0
    d_word PosY_i16, $00ca
    d_byte Param_byte, eNpcOrc::GrontaStanding
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
.ENDPROC

.PROC FuncC_Town_Sky_EnterRoom
    ;; Set the Jerome and Gronta NPC actors' State2 bytes to $ff so that we can
    ;; control their facing direction explicitly.
    dec Ram_ActorState2_byte_arr + kJeromeActorIndex  ; now #ff
    ;; Branch setup based on the cutscene to be played (this room is only used
    ;; for cutscenes).
    lda Zp_Next_eCutscene
    cmp #eCutscene::TownSkyFinaleGaveRemote2
    beq _Rising
    cmp #eCutscene::TownSkyFinaleGaveRemote4
    beq _AlreadyRisen
    cmp #eCutscene::TownSkyFinaleGaveRemote6
    beq _AlreadyRisen
    ldy #eActor::None
    sty Ram_ActorType_eActor_arr + kGrontaActorIndex
    cmp #eCutscene::TownSkyFinaleReactivate2
    beq _Rising
    cmp #eCutscene::TownSkyFinaleReactivate4
    beq _AlreadyRisen
_MakeJeromeFaceLeft:
    lda #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr + kJeromeActorIndex
_RemoveNpcSquares:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kUpperSquareActorIndex
    sta Ram_ActorType_eActor_arr + kLowerSquareActorIndex
_AlreadyRisen:
    lda #$80
    sta Ram_ActorPosY_i16_0_arr + kGrontaActorIndex
    lda #15 * kTileHeightPx
    sta Ram_PlatformTop_i16_0_arr + kFinalTerminalPlatformIndex
    lda #17 * kTileHeightPx
    sta Ram_PlatformBottom_i16_0_arr + kFinalTerminalPlatformIndex
    sta Ram_PlatformTop_i16_0_arr + kCoreInnerPlatformIndex
    lda #24 * kTileHeightPx
    sta Ram_PlatformTop_i16_0_arr + kCoreOuterPlatformIndex
    ldy #19  ; inner core terrain start row
    lda #26  ; outer core terrain start row
    bne _SetStartRows  ; unconditional
_Rising:
    ldy #29  ; inner core terrain start row
    tya      ; outer core terrain start row
_SetStartRows:
    sty Zp_RoomState + sState::InnerCoreTerrainStartRow_u8
    sta Zp_RoomState + sState::OuterCoreTerrainStartRow_u8
    rts
.ENDPROC

;;; @prereq Rendering is disabled.
.PROC FuncC_Town_Sky_FadeInRoom
_InnerCore:
    ldx Zp_RoomState + sState::InnerCoreTerrainStartRow_u8
    bpl @start  ; unconditional
    @rowLoop:
    lda #kCoreInnerStartCol  ; param: tile column
    jsr _SetUpDirectTransfer  ; preserves X
    ldy #kCoreInnerPlatformWidthTiles - 1
    @tileLoop:
    lda DataC_Town_CoreInnerPlatformBgTiles_u8_arr, y
    sta Hw_PpuData_rw
    dey
    bpl @tileLoop
    inx
    @start:
    cpx Zp_RoomState + sState::OuterCoreTerrainStartRow_u8
    blt @rowLoop
_OuterCore:
    bge @start  ; unconditional
    @rowLoop:
    lda #kCoreOuterStartCol  ; param: tile column
    jsr _SetUpDirectTransfer  ; preserves X
    ldy #kCoreOuterPlatformWidthTiles - 1
    @tileLoop:
    lda DataC_Town_CoreOuterPlatformBgTiles_u8_arr, y
    sta Hw_PpuData_rw
    dey
    bpl @tileLoop
    inx
    @start:
    cpx #kScreenHeightTiles
    blt @rowLoop
    rts
_SetUpDirectTransfer:
    jsr FuncC_Town_GetScreenTilePpuAddr  ; preserves X, returns YA
    sty Hw_PpuAddr_w2  ; destination address (hi)
    sta Hw_PpuAddr_w2  ; destination address (lo)
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    rts
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Town_Sky_DrawRoom
    bit Zp_RoomState + sState::DoNotDraw_bool
    bpl @draw
    rts
    @draw:
_OuterPlatform:
    ldx #kCoreOuterPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawCoreOuterPlatform
_InnerPlatform:
    ldx #kCoreInnerPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawCoreInnerPlatform
_FinalTerminal:
    ldx #kFinalTerminalPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    jsr FuncA_Objects_MoveShapeRightHalfTile  ; preserves X
    lda #kTileIdObjScreen  ; param: tile ID
    ldy #kPaletteObjScreen ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    jmp FuncA_Objects_DrawTerminalPlatformInFront
.ENDPROC

;;; Buffers a PPU transfer to draw BG tiles for one row of the core inner
;;; platform in this room.
;;; @param X The screen tile row.
.PROC FuncC_Town_TransferCoreInnerPlatformRow
    ldy #kCoreInnerStartCol  ; param: first screen tile column
    lda #kCoreInnerPlatformWidthTiles  ; param: platform width in tiles
    jsr FuncC_Town_AllocateCorePlatformTransferEntry  ; returns X and Y
    @loop:
    lda DataC_Town_CoreInnerPlatformBgTiles_u8_arr, y
    sta Ram_PpuTransfer_arr + 4, x
    inx
    dey
    bpl @loop
    rts
.ENDPROC

;;; Buffers a PPU transfer to draw BG tiles for one row of the core outer
;;; platform in this room.
;;; @param X The screen tile row.
.PROC FuncC_Town_TransferCoreOuterPlatformRow
    ldy #kCoreOuterStartCol  ; param: first screen tile column
    lda #kCoreOuterPlatformWidthTiles  ; param: platform width in tiles
    jsr FuncC_Town_AllocateCorePlatformTransferEntry  ; returns X and Y
    @loop:
    lda DataC_Town_CoreOuterPlatformBgTiles_u8_arr, y
    sta Ram_PpuTransfer_arr + 4, x
    inx
    dey
    bpl @loop
    rts
.ENDPROC

;;; Allocates a PPU transfer entry to draw BG tiles for one row of a core
;;; platform, and fills the entry header.  The caller must fill in the payload
;;; of this entry.
;;; @param A The width of the platform, in tiles.
;;; @param Y The screen tile column for the left side of the platform.
;;; @param X The screen tile row.
;;; @return X The byte index into Ram_PpuTransfer_arr for the start of the
;;;     entry (including the entry header).
;;; @return Y The initial loop index, equal to width-in-tiles minus 1.
.PROC FuncC_Town_AllocateCorePlatformTransferEntry
    pha  ; platform width in tiles
    tya  ; param: screen tile column
    jsr FuncC_Town_GetScreenTilePpuAddr  ; returns YA
    ldx Zp_PpuTransferLen_u8
    sta Ram_PpuTransfer_arr + 2, x
    tya  ; PPU addr (hi)
    sta Ram_PpuTransfer_arr + 1, x
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr + 0, x
    pla  ; platform width in tiles
    sta Ram_PpuTransfer_arr + 3, x
    tay  ; platform width in tiles
    add #4  ; to account for transfer entry header
    adc Zp_PpuTransferLen_u8  ; carry is already clear
    sta Zp_PpuTransferLen_u8
    dey  ; initial loop index
    rts
.ENDPROC

;;; Returns the PPU address in the upper nametable for the specified BG tile.
;;; @param A The screen tile column.
;;; @param X The screen tile row.
;;; @return YA The PPU address.
;;; @preserve X, T2+
.EXPORT FuncC_Town_GetScreenTilePpuAddr
.PROC FuncC_Town_GetScreenTilePpuAddr
    sta T1  ; screen tile column
    .assert Ppu_Nametable0_sName .mod $400 = 0, error
    lda #>Ppu_Nametable0_sName >> 2  ; the ROLs below will undo the >> 2
    sta T0  ; destination address (hi)
    txa  ; screen tile row
    asl a
    asl a
    asl a
    asl a
    rol T0  ; destination address (hi)
    asl a
    rol T0  ; destination address (hi)
    ora T1  ; screen tile column
    ldy T0  ; destination address (hi)
    rts
.ENDPROC

;;; The BG tile IDs for one row of the core inner platform, in order from right
;;; to left (so that iterating the index from 5 down to 0 will visit the tile
;;; IDs in left-to-right order).
.PROC DataC_Town_CoreInnerPlatformBgTiles_u8_arr
:   .byte $b9, $bb, $bb, $ba, $bb, $b8
    .assert * - :- = kCoreInnerPlatformWidthTiles, error
.ENDPROC

;;; The BG tile IDs for one row of the core outer platform, in order from right
;;; to left (so that iterating the index from 7 down to 0 will visit the tile
;;; IDs in left-to-right order).
.PROC DataC_Town_CoreOuterPlatformBgTiles_u8_arr
:   .byte $b9, $bb, $bb, $bb, $bb, $ba, $bb, $b8
    .assert * - :- = kCoreOuterPlatformWidthTiles, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

;;; @prereq PRGC_Town is loaded.
.EXPORT DataA_Cutscene_TownSkyFinaleGaveRemote2_sCutscene
.PROC DataA_Cutscene_TownSkyFinaleGaveRemote2_sCutscene
    fall DataA_Cutscene_TownSkyFinaleReactivate2_sCutscene
.ENDPROC

;;; @prereq PRGC_Town is loaded.
.EXPORT DataA_Cutscene_TownSkyFinaleReactivate2_sCutscene
.PROC DataA_Cutscene_TownSkyFinaleReactivate2_sCutscene
    act_CallFunc _PlayOuterRumblingSound
    act_RepeatFunc $80, _RaiseCoreOuterPlatform
    act_CallFunc _PlayInnerRumblingSound
    act_RepeatFunc $c0, _RaiseCoreInnerPlatform
    act_WaitFrames 120
    act_JumpToMain MainA_Cutscene_StartNextFinaleStep
_PlayOuterRumblingSound:
    lda #$80  ; param: frames
    jmp FuncA_Cutscene_PlaySfxRumbling
_PlayInnerRumblingSound:
    lda #$c0  ; param: frames
    jmp FuncA_Cutscene_PlaySfxRumbling
_RaiseCoreOuterPlatform:
    txa  ; repeat count
    mod #4
    bne @done
    lda #4  ; param: shake frames
    jsr Func_ShakeRoom
    jsr _MoveInnerAndOuter
    ldy Ram_PlatformTop_i16_0_arr + kCoreOuterPlatformIndex
    tya  ; platform top
    mod #kTileHeightPx
    bne @done
    tya  ; platform top
    div #kTileHeightPx
    tax
    inx  ; param: tile row
    jmp FuncC_Town_TransferCoreOuterPlatformRow
    @done:
    rts
_RaiseCoreInnerPlatform:
    txa  ; repeat count
    mod #4
    bne @done
    lda #4  ; param: shake frames
    jsr Func_ShakeRoom
    jsr _MoveInnerOnly
    ldy Ram_PlatformTop_i16_0_arr + kCoreInnerPlatformIndex
    tya  ; platform top
    mod #kTileHeightPx
    bne @done
    tya  ; platform top
    div #kTileHeightPx
    tax
    inx  ; param: tile row
    jmp FuncC_Town_TransferCoreInnerPlatformRow
    @done:
    rts
_MoveInnerAndOuter:
    dec Ram_PlatformTop_i16_0_arr + kCoreOuterPlatformIndex
_MoveInnerOnly:
    dec Ram_PlatformTop_i16_0_arr + kCoreInnerPlatformIndex
    dec Ram_PlatformTop_i16_0_arr + kFinalTerminalPlatformIndex
    dec Ram_PlatformBottom_i16_0_arr + kFinalTerminalPlatformIndex
    dec Zp_AvatarPosY_i16 + 0
    dec Ram_ActorPosY_i16_0_arr + kGrontaActorIndex
    rts
.ENDPROC

.EXPORT DataA_Cutscene_TownSkyFinaleGaveRemote4_sCutscene
.PROC DataA_Cutscene_TownSkyFinaleGaveRemote4_sCutscene
    act_WaitFrames 60
    act_SetActorState1 kGrontaActorIndex, eNpcOrc::GrontaAxeRaised
    act_RunDialog eDialog::TownSkyFinaleGaveRemote4
    act_WaitFrames 10
    act_JumpToMain MainA_Cutscene_StartNextFinaleStep
.ENDPROC

.EXPORT DataA_Cutscene_TownSkyFinaleReactivate4_sCutscene
.PROC DataA_Cutscene_TownSkyFinaleReactivate4_sCutscene
    .linecont +
    act_WaitFrames 60
    ;; TODO: play a sound for Jerome's hologram appearing
    act_RepeatFunc kBlockHeightPx * kRevealSlowdown, \
                   FuncA_Cutscene_TownSkyRevealJerome
    act_RunDialog eDialog::TownSkyFinaleReactivate4
    act_WaitFrames 60
    act_JumpToMain MainA_Cutscene_StartNextFinaleStep
    .linecont -
.ENDPROC

.EXPORT DataA_Cutscene_TownSkyFinaleGaveRemote6_sCutscene
.PROC DataA_Cutscene_TownSkyFinaleGaveRemote6_sCutscene
    .linecont +
    act_WaitFrames 60
    ;; TODO: play a sound for Jerome's hologram appearing
    act_RepeatFunc kBlockHeightPx * kRevealSlowdown, \
                   FuncA_Cutscene_TownSkyRevealJerome
    act_RunDialog eDialog::TownSkyFinaleGaveRemote6
    act_WaitFrames 60
    act_ForkStart 0, DataA_Cutscene_TownSkyFinaleMaybeThisTime_sCutscene
    .linecont -
.ENDPROC

.EXPORT DataA_Cutscene_TownSkyFinaleReactivate6_sCutscene
.PROC DataA_Cutscene_TownSkyFinaleReactivate6_sCutscene
    act_WaitFrames 30
    act_RunDialog eDialog::TownSkyFinaleReactivate6A
    act_WaitFrames 30
    act_SetActorFlags kJeromeActorIndex, 0
    act_WaitFrames 30
    act_MoveAvatarWalk $00b0
    act_SetAvatarPose eAvatar::Standing
    act_WaitFrames 30
    act_RunDialog eDialog::TownSkyFinaleReactivate6B
    act_WaitFrames 60
    fall DataA_Cutscene_TownSkyFinaleMaybeThisTime_sCutscene
.ENDPROC

.PROC DataA_Cutscene_TownSkyFinaleMaybeThisTime_sCutscene
    act_CallFunc _FadeRoomToBlack
    act_WaitFrames 60
    act_RunDialog eDialog::TownSkyFinaleMaybeThisTime
    act_JumpToMain MainA_Cutscene_StartEpilogue
_FadeRoomToBlack:
    jsr Func_FadeOutToBlack
    ;; Stop drawing special platforms for this room.
    dec Zp_RoomState + sState::DoNotDraw_bool  ; now $ff
    ;; Stop drawing the player avatar.
    lda #eAvatar::Hidden
    sta Zp_AvatarPose_eAvatar
    ;; Remove all actors.
    .assert eAvatar::Hidden = eActor::None, error
    ldx #kMaxActors - 1
    @actorLoop:
    sta Ram_ActorType_eActor_arr, x
    dex
    bpl @actorLoop
    ;; Clear BG tiles in upper nametable.
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldax #Ppu_Nametable0_sName + sName::Tiles_u8_arr
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda #' '
    ldxy #kScreenWidthTiles * kScreenHeightTiles
    @bgLoop:
    sta Hw_PpuData_rw
    dey
    bne @bgLoop
    dex
    bpl @bgLoop
    ;; Re-enable rendering:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    ldy #eFade::Normal  ; param: eFade value
    jsr Func_SetAndTransferFade
    jmp Func_ClearRestOfOamAndProcessFrame
.ENDPROC

;;; Called repeatedly via act_RepeatFunc to reveal Jerome's hologram.
;;; @param X The repeat counter.
.PROC FuncA_Cutscene_TownSkyRevealJerome
    txa  ; repeat counter
    mod #kRevealSlowdown
    bne @done
    dec Ram_ActorPosY_i16_0_arr + kUpperSquareActorIndex
    inc Ram_ActorPosY_i16_0_arr + kLowerSquareActorIndex
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_TownSkyFinaleGaveRemote4_sDialog
.PROC DataA_Dialog_TownSkyFinaleGaveRemote4_sDialog
    dlg_Text OrcGrontaShout, DataA_Text2_TownSkyFinaleGronta_Banished_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownSkyFinaleGaveRemote6_sDialog
.PROC DataA_Dialog_TownSkyFinaleGaveRemote6_sDialog
    .assert kTileIdBgPortraitJeromeFirst = kTileIdBgPortraitGrontaFirst, error
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_Recorded_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleGaveRemote6_Part2_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_HopedBetter_u8_arr
    dlg_Call _RaiseGrontaAxe
    dlg_Text OrcGrontaShout, DataA_Text2_TownSkyFinaleGronta_WeAreBetter_u8_arr
    dlg_Call _LowerGrontaAxe
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_FoolishEnds_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_ToreApart_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_LockedAway_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_OrcDesires_u8_arr
    dlg_Done
_RaiseGrontaAxe:
    lda #eNpcOrc::GrontaAxeRaised
    sta Ram_ActorState1_byte_arr + kGrontaActorIndex
    rts
_LowerGrontaAxe:
    lda #eNpcOrc::GrontaStanding
    sta Ram_ActorState1_byte_arr + kGrontaActorIndex
    rts
.ENDPROC

.EXPORT DataA_Dialog_TownSkyFinaleReactivate4_sDialog
.PROC DataA_Dialog_TownSkyFinaleReactivate4_sDialog
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_Recorded_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleReactivate4_Part2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownSkyFinaleReactivate6A_sDialog
.PROC DataA_Dialog_TownSkyFinaleReactivate6A_sDialog
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_HopedBetter_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownSkyFinaleReactivate6B_sDialog
.PROC DataA_Dialog_TownSkyFinaleReactivate6B_sDialog
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleReactivate6_Part2_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_FoolishEnds_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_ToreApart_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_LockedAway_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_HumanDesires_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownSkyFinaleMaybeThisTime_sDialog
.PROC DataA_Dialog_TownSkyFinaleMaybeThisTime_sDialog
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_Well_u8_arr
    dlg_Text AdultJerome, DataA_Text2_TownSkyFinaleJerome_MaybeThisTime_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
