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

.INCLUDE "actor.inc"
.INCLUDE "avatar.inc"
.INCLUDE "macros.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "terrain.inc"

.IMPORT FuncA_Actor_TickBadCrab
.IMPORT FuncA_Actor_TickBadCrawler
.IMPORT FuncA_Actor_TickBadFish
.IMPORT FuncA_Actor_TickBadHotheadHorz
.IMPORT FuncA_Actor_TickBadHotheadVert
.IMPORT FuncA_Actor_TickBadSpider
.IMPORT FuncA_Actor_TickBadVinebug
.IMPORT FuncA_Actor_TickNpcAdult
.IMPORT FuncA_Actor_TickNpcChild
.IMPORT FuncA_Actor_TickNpcMermaid
.IMPORT FuncA_Actor_TickNpcToddler
.IMPORT FuncA_Actor_TickProjFireball
.IMPORT FuncA_Actor_TickProjGrenade
.IMPORT FuncA_Actor_TickProjSmoke
.IMPORT FuncA_Actor_TickProjSpike
.IMPORT FuncA_Actor_TickProjSteamHorz
.IMPORT FuncA_Actor_TickProjSteamUp
.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_DrawActorBadCrab
.IMPORT FuncA_Objects_DrawActorBadCrawler
.IMPORT FuncA_Objects_DrawActorBadFish
.IMPORT FuncA_Objects_DrawActorBadHotheadHorz
.IMPORT FuncA_Objects_DrawActorBadHotheadVert
.IMPORT FuncA_Objects_DrawActorBadSpider
.IMPORT FuncA_Objects_DrawActorBadVinebug
.IMPORT FuncA_Objects_DrawActorNpcAdult
.IMPORT FuncA_Objects_DrawActorNpcChild
.IMPORT FuncA_Objects_DrawActorNpcMermaid
.IMPORT FuncA_Objects_DrawActorNpcToddler
.IMPORT FuncA_Objects_DrawActorProjFireball
.IMPORT FuncA_Objects_DrawActorProjGrenade
.IMPORT FuncA_Objects_DrawActorProjSmoke
.IMPORT FuncA_Objects_DrawActorProjSpike
.IMPORT FuncA_Objects_DrawActorProjSteamHorz
.IMPORT FuncA_Objects_DrawActorProjSteamUp
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT Func_GetTerrainColumnPtrForTileIndex
.IMPORT Func_HarmAvatar
.IMPORT Func_InitActorBadHotheadHorz
.IMPORT Func_InitActorBadHotheadVert
.IMPORT Func_InitActorBadVinebug
.IMPORT Func_InitActorProjFireball
.IMPORT Func_InitActorProjGrenade
.IMPORT Func_InitActorProjSmoke
.IMPORT Func_InitActorProjSpike
.IMPORT Func_InitActorProjSteamHorz
.IMPORT Func_InitActorProjSteamUp
.IMPORT Func_Noop
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

;;; The hit radius of various actors, in pixels.
kProjFireballRadius = 3
kProjGrenadeRadius = 2
kProjSmokeRadius = 6
kProjSpikeRadius = 3
kProjSteamMajorRadius = 8
kProjSteamMinorRadius = 5

;;;=========================================================================;;;

Func_InitActorNone       = Func_InitActorDefault
Func_InitActorBadCrab    = Func_InitActorDefault
Func_InitActorBadCrawler = Func_InitActorDefault
Func_InitActorBadFish    = Func_InitActorDefault
Func_InitActorBadSpider  = Func_InitActorDefault
Func_InitActorNpcAdult   = Func_InitActorWithState
Func_InitActorNpcChild   = Func_InitActorWithState
Func_InitActorNpcMermaid = Func_InitActorWithState
Func_InitActorNpcToddler = Func_InitActorWithState

FuncA_Actor_TickNone = Func_Noop
FuncA_Objects_DrawActorNone = Func_Noop

.LINECONT +
.DEFINE ActorInitFuncs \
    Func_InitActorNone, \
    Func_InitActorBadCrab, \
    Func_InitActorBadCrawler, \
    Func_InitActorBadFish, \
    Func_InitActorBadHotheadHorz, \
    Func_InitActorBadHotheadVert, \
    Func_InitActorBadSpider, \
    Func_InitActorBadVinebug, \
    Func_InitActorNpcAdult, \
    Func_InitActorNpcChild, \
    Func_InitActorNpcMermaid, \
    Func_InitActorNpcToddler, \
    Func_InitActorProjFireball, \
    Func_InitActorProjGrenade, \
    Func_InitActorProjSmoke, \
    Func_InitActorProjSpike, \
    Func_InitActorProjSteamHorz, \
    Func_InitActorProjSteamUp
.LINECONT -

.LINECONT +
.DEFINE ActorTickFuncs \
    FuncA_Actor_TickNone, \
    FuncA_Actor_TickBadCrab, \
    FuncA_Actor_TickBadCrawler, \
    FuncA_Actor_TickBadFish, \
    FuncA_Actor_TickBadHotheadHorz, \
    FuncA_Actor_TickBadHotheadVert, \
    FuncA_Actor_TickBadSpider, \
    FuncA_Actor_TickBadVinebug, \
    FuncA_Actor_TickNpcAdult, \
    FuncA_Actor_TickNpcChild, \
    FuncA_Actor_TickNpcMermaid, \
    FuncA_Actor_TickNpcToddler, \
    FuncA_Actor_TickProjFireball, \
    FuncA_Actor_TickProjGrenade, \
    FuncA_Actor_TickProjSmoke, \
    FuncA_Actor_TickProjSpike, \
    FuncA_Actor_TickProjSteamHorz, \
    FuncA_Actor_TickProjSteamUp
.LINECONT -

.LINECONT +
.DEFINE ActorDrawFuncs \
    FuncA_Objects_DrawActorNone, \
    FuncA_Objects_DrawActorBadCrab, \
    FuncA_Objects_DrawActorBadCrawler, \
    FuncA_Objects_DrawActorBadFish, \
    FuncA_Objects_DrawActorBadHotheadHorz, \
    FuncA_Objects_DrawActorBadHotheadVert, \
    FuncA_Objects_DrawActorBadSpider, \
    FuncA_Objects_DrawActorBadVinebug, \
    FuncA_Objects_DrawActorNpcAdult, \
    FuncA_Objects_DrawActorNpcChild, \
    FuncA_Objects_DrawActorNpcMermaid, \
    FuncA_Objects_DrawActorNpcToddler, \
    FuncA_Objects_DrawActorProjFireball, \
    FuncA_Objects_DrawActorProjGrenade, \
    FuncA_Objects_DrawActorProjSmoke, \
    FuncA_Objects_DrawActorProjSpike, \
    FuncA_Objects_DrawActorProjSteamHorz, \
    FuncA_Objects_DrawActorProjSteamUp
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "RAM_Actor"

;;; The type for each actor in the room (or eActor::None for an empty slot).
.EXPORT Ram_ActorType_eActor_arr
Ram_ActorType_eActor_arr: .res kMaxActors

;;; The current X/Y positions of each actor in the room, in room-space pixels.
.EXPORT Ram_ActorPosX_i16_0_arr, Ram_ActorPosX_i16_1_arr
Ram_ActorPosX_i16_0_arr: .res kMaxActors
Ram_ActorPosX_i16_1_arr: .res kMaxActors
.EXPORT Ram_ActorPosY_i16_0_arr, Ram_ActorPosY_i16_1_arr
Ram_ActorPosY_i16_0_arr: .res kMaxActors
Ram_ActorPosY_i16_1_arr: .res kMaxActors

;;; The current X/Y subpixel positions of each actor in the room.
.EXPORT Ram_ActorSubX_u8_arr, Ram_ActorSubY_u8_arr
Ram_ActorSubX_u8_arr: .res kMaxActors
Ram_ActorSubY_u8_arr: .res kMaxActors

;;; The current velocities of each actor in the room, in subpixels per frame.
.EXPORT Ram_ActorVelX_i16_0_arr, Ram_ActorVelX_i16_1_arr
Ram_ActorVelX_i16_0_arr: .res kMaxActors
Ram_ActorVelX_i16_1_arr: .res kMaxActors
.EXPORT Ram_ActorVelY_i16_0_arr, Ram_ActorVelY_i16_1_arr
Ram_ActorVelY_i16_0_arr: .res kMaxActors
Ram_ActorVelY_i16_1_arr: .res kMaxActors

;;; Type-specific state data for each actor in the room.
.EXPORT Ram_ActorState_byte_arr
Ram_ActorState_byte_arr: .res kMaxActors

;;; The object flags to apply for each actor in the room.  In particular, if
;;; bObj::FlipH is set, then the actor will face left instead of right, and if
;;; bObj::FlipV is set, then the actor will be upside-down.
.EXPORT Ram_ActorFlags_bObj_arr
Ram_ActorFlags_bObj_arr: .res kMaxActors

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Returns the index of the last empty actor slot (if any), or sets the C flag
;;; if all actor slots are full.
;;; @return C Set if all slots were full; cleared if an empty slot was found.
;;; @return X The index of the empty slot (if any).
;;; @preserve Y, Zp_Tmp*
.EXPORT Func_FindEmptyActorSlot
.PROC Func_FindEmptyActorSlot
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    .assert eActor::None = 0, error
    beq @success
    dex
    bpl @loop
    sec  ; set C to indicate failure
    rts
    @success:
    clc  ; clear C to indicate success
    rts
.ENDPROC

;;; Initializes velocity, state, and flags for an actor appropriately based on
;;; the actor's type and pixel position.
;;; @prereq The actor's type has already been initialized.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The actor-type-specific initialization parameter.
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitActor
.PROC Func_InitActor
    sta Zp_Tmp1_byte  ; initialization parameter
    ldy Ram_ActorType_eActor_arr, x
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    lda Zp_Tmp1_byte  ; param: initialization parameter
    jmp (Zp_Tmp_ptr)
_JumpTable_ptr_0_arr: .lobytes ActorInitFuncs
_JumpTable_ptr_1_arr: .hibytes ActorInitFuncs
.ENDPROC

;;; The default actor init function that works for most actor types.  Zeroes
;;; the velocity, flags, and state byte for the specified actor, and sets the
;;; actors type as specified.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @param Y The actor type to set.
;;; @preserve X
.EXPORT Func_InitActorDefault
.PROC Func_InitActorDefault
    lda #0  ; param: state byte
    .assert * = Func_InitActorWithState, error, "fallthrough"
.ENDPROC

;;; Zeroes the velocity and flags for the specified actor, and sets the actor's
;;; state byte and type as specified.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The state byte to set.
;;; @param X The actor index.
;;; @param Y The actor type to set.
;;; @preserve X
.PROC Func_InitActorWithState
    sta Ram_ActorState_byte_arr, x
    tya  ; actor type
    sta Ram_ActorType_eActor_arr, x
    lda #0
    sta Ram_ActorSubX_u8_arr, x
    sta Ram_ActorSubY_u8_arr, x
    sta Ram_ActorVelX_i16_0_arr, x
    sta Ram_ActorVelX_i16_1_arr, x
    sta Ram_ActorVelY_i16_0_arr, x
    sta Ram_ActorVelY_i16_1_arr, x
    sta Ram_ActorFlags_bObj_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; How far an actor's bounding box extends in each direction from the actor's
;;; position, indexed by eActor value.
.PROC DataA_Actor_BoundingBoxUp_u8_arr
    D_ENUM eActor
    d_byte None,           0
    d_byte BadCrab,        6
    d_byte BadCrawler,     0
    d_byte BadFish,        6
    d_byte BadHotheadHorz, 6
    d_byte BadHotheadVert, 6
    d_byte BadSpider,      8
    d_byte BadVinebug,     7
    d_byte NpcAdult,      13
    d_byte NpcChild,       7
    d_byte NpcMermaid,    13
    d_byte NpcToddler,     4
    d_byte ProjFireball,   kProjFireballRadius
    d_byte ProjGrenade,    kProjGrenadeRadius
    d_byte ProjSmoke,      kProjSmokeRadius
    d_byte ProjSpike,      kProjSpikeRadius
    d_byte ProjSteamHorz,  kProjSteamMinorRadius
    d_byte ProjSteamUp,    kProjSteamMajorRadius
    D_END
.ENDPROC
.PROC DataA_Actor_BoundingBoxDown_u8_arr
    D_ENUM eActor
    d_byte None,           0
    d_byte BadCrab,        8
    d_byte BadCrawler,     8
    d_byte BadFish,        4
    d_byte BadHotheadHorz, 6
    d_byte BadHotheadVert, 6
    d_byte BadSpider,      2
    d_byte BadVinebug,     7
    d_byte NpcAdult,       8
    d_byte NpcChild,       8
    d_byte NpcMermaid,     8
    d_byte NpcToddler,     8
    d_byte ProjFireball,   kProjFireballRadius
    d_byte ProjGrenade,    kProjGrenadeRadius
    d_byte ProjSmoke,      kProjSmokeRadius
    d_byte ProjSpike,      kProjSpikeRadius
    d_byte ProjSteamHorz,  kProjSteamMinorRadius
    d_byte ProjSteamUp,    kProjSteamMajorRadius
    D_END
.ENDPROC
.PROC DataA_Actor_BoundingBoxSide_u8_arr
    D_ENUM eActor
    d_byte None,           0
    d_byte BadCrab,        7
    d_byte BadCrawler,     7
    d_byte BadFish,        6
    d_byte BadHotheadHorz, 6
    d_byte BadHotheadVert, 6
    d_byte BadSpider,      7
    d_byte BadVinebug,     5
    d_byte NpcAdult,       5
    d_byte NpcChild,       5
    d_byte NpcMermaid,     5
    d_byte NpcToddler,     3
    d_byte ProjFireball,   kProjFireballRadius
    d_byte ProjGrenade,    kProjGrenadeRadius
    d_byte ProjSmoke,      kProjSmokeRadius
    d_byte ProjSpike,      kProjSpikeRadius
    d_byte ProjSteamHorz,  kProjSteamMajorRadius
    d_byte ProjSteamUp,    kProjSteamMinorRadius
    D_END
.ENDPROC

;;; Performs per-frame updates for each actor in the room.
.EXPORT FuncA_Actor_TickAllActors
.PROC FuncA_Actor_TickAllActors
    ldx #kMaxActors - 1
    @loop:
    jsr FuncA_Actor_TickOneActor  ; preserves X
    dex
    bpl @loop
    rts
.ENDPROC

;;; Performs per-frame updates for one actor.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickOneActor
_ApplyVelX:
    ldy #0
    lda Ram_ActorVelX_i16_0_arr, x
    add Ram_ActorSubX_u8_arr, x
    sta Ram_ActorSubX_u8_arr, x
    lda Ram_ActorVelX_i16_1_arr, x
    bpl @nonnegative
    dey  ; now y is $ff
    @nonnegative:
    adc Ram_ActorPosX_i16_0_arr, x
    sta Ram_ActorPosX_i16_0_arr, x
    tya
    adc Ram_ActorPosX_i16_1_arr, x
    sta Ram_ActorPosX_i16_1_arr, x
_ApplyVelY:
    ldy #0
    lda Ram_ActorVelY_i16_0_arr, x
    add Ram_ActorSubY_u8_arr, x
    sta Ram_ActorSubY_u8_arr, x
    lda Ram_ActorVelY_i16_1_arr, x
    bpl @nonnegative
    dey  ; now y is $ff
    @nonnegative:
    adc Ram_ActorPosY_i16_0_arr, x
    sta Ram_ActorPosY_i16_0_arr, x
    tya
    adc Ram_ActorPosY_i16_1_arr, x
    sta Ram_ActorPosY_i16_1_arr, x
_TypeSpecificTick:
    lda Ram_ActorType_eActor_arr, x
    tay
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
_JumpTable_ptr_0_arr: .lobytes ActorTickFuncs
_JumpTable_ptr_1_arr: .hibytes ActorTickFuncs
.ENDPROC

;;; Checks if the actor is colliding with the player avatar.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X
.EXPORT FuncA_Actor_IsCollidingWithAvatar
.PROC FuncA_Actor_IsCollidingWithAvatar
    ldy Ram_ActorType_eActor_arr, x
    ;; Check right side.
    lda DataA_Actor_BoundingBoxSide_u8_arr, y
    add #kAvatarBoundingBoxLeft
    adc Ram_ActorPosX_i16_0_arr, x
    sta Zp_Tmp1_byte
    lda Ram_ActorPosX_i16_1_arr, x
    adc #0
    cmp Zp_AvatarPosX_i16 + 1
    blt _NoHit
    bne @hitRight
    lda Zp_Tmp1_byte
    cmp Zp_AvatarPosX_i16 + 0
    ble _NoHit
    @hitRight:
    ;; Check left side.
    lda DataA_Actor_BoundingBoxSide_u8_arr, y
    add #kAvatarBoundingBoxRight
    sta Zp_Tmp1_byte
    lda Ram_ActorPosX_i16_0_arr, x
    sub Zp_Tmp1_byte
    sta Zp_Tmp1_byte
    lda Ram_ActorPosX_i16_1_arr, x
    sbc #0
    cmp Zp_AvatarPosX_i16 + 1
    blt @hitLeft
    bne _NoHit
    lda Zp_Tmp1_byte
    cmp Zp_AvatarPosX_i16 + 0
    bge _NoHit
    @hitLeft:
    ;; Check top side.
    lda DataA_Actor_BoundingBoxUp_u8_arr, y
    add #kAvatarBoundingBoxDown
    sta Zp_Tmp1_byte
    lda Ram_ActorPosY_i16_0_arr, x
    sub Zp_Tmp1_byte
    sta Zp_Tmp1_byte
    lda Ram_ActorPosY_i16_1_arr, x
    sbc #0
    cmp Zp_AvatarPosY_i16 + 1
    blt @hitTop
    bne _NoHit
    lda Zp_Tmp1_byte
    cmp Zp_AvatarPosY_i16 + 0
    bge _NoHit
    @hitTop:
    ;; Check bottom side.
    lda DataA_Actor_BoundingBoxDown_u8_arr, y
    add #kAvatarBoundingBoxUp
    adc Ram_ActorPosY_i16_0_arr, x
    sta Zp_Tmp1_byte
    lda Ram_ActorPosY_i16_1_arr, x
    adc #0
    cmp Zp_AvatarPosY_i16 + 1
    blt _NoHit
    bne @hitBottom
    lda Zp_Tmp1_byte
    cmp Zp_AvatarPosY_i16 + 0
    ble _NoHit
    @hitBottom:
_Hit:
    sec
    rts
_NoHit:
    clc
    rts
.ENDPROC

;;; Checks if the actor is colliding with the player avatar; if so, harms the
;;; avatar.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X
.EXPORT FuncA_Actor_HarmAvatarIfCollision
.PROC FuncA_Actor_HarmAvatarIfCollision
    jsr FuncA_Actor_IsCollidingWithAvatar  ; preserves X, returns C
    bcc @done
    jsr Func_HarmAvatar  ; preserves X
    sec
    @done:
    rts
.ENDPROC

;;; Returns the room tile column index for the actor position.
;;; @param X The actor index.
;;; @return A The room tile column index.
;;; @preserve X
.EXPORT FuncA_Actor_GetRoomTileColumn
.PROC FuncA_Actor_GetRoomTileColumn
    lda Ram_ActorPosX_i16_1_arr, x
    sta Zp_Tmp1_byte
    lda Ram_ActorPosX_i16_0_arr, x
    .assert kTileWidthPx = (1 << 3), error
    .repeat 3
    lsr Zp_Tmp1_byte
    ror a
    .endrepeat
    rts
.ENDPROC

;;; Returns the room block row index for the actor position.
;;; @param X The actor index.
;;; @return Y The room block row index.
;;; @preserve X
.EXPORT FuncA_Actor_GetRoomBlockRow
.PROC FuncA_Actor_GetRoomBlockRow
    lda Ram_ActorPosY_i16_1_arr, x
    sta Zp_Tmp1_byte
    lda Ram_ActorPosY_i16_0_arr, x
    .assert kBlockHeightPx = (1 << 4), error
    .repeat 4
    lsr Zp_Tmp1_byte
    ror a
    .endrepeat
    tay
    rts
.ENDPROC

;;; Checks if the actor's center position is colliding with solid terrain.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X
.EXPORT FuncA_Actor_CenterHitsTerrain
.PROC FuncA_Actor_CenterHitsTerrain
    ;; Get the terrain for the actor's current tile column.
    jsr FuncA_Actor_GetRoomTileColumn  ; preserves X, returns A
    stx Zp_Tmp1_byte
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*
    ldx Zp_Tmp1_byte
    ;; Check the terrain block that the actor position is in, and set C if the
    ;; terrain is solid.
    jsr FuncA_Actor_GetRoomBlockRow  ; preserves X, returns Y
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for all actors in the room.
.EXPORT FuncA_Objects_DrawAllActors
.PROC FuncA_Objects_DrawAllActors
    ldx #kMaxActors - 1
    @loop:
    jsr FuncA_Objects_DrawOneActor  ; preserves X
    dex
    bpl @loop
    rts
.ENDPROC

;;; Allocates and populates OAM slots (if any) for one actor.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_DrawOneActor
    lda Ram_ActorType_eActor_arr, x
    tay
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
_JumpTable_ptr_0_arr: .lobytes ActorDrawFuncs
_JumpTable_ptr_1_arr: .hibytes ActorDrawFuncs
.ENDPROC

;;; Sets Zp_ShapePosX_i16 and Zp_ShapePosY_i16 to the screen-space position of
;;; the specified actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_PositionActorShape
.PROC FuncA_Objects_PositionActorShape
    ;; Calculate screen-space Y-position.
    lda Ram_ActorPosY_i16_0_arr, x
    sub Zp_RoomScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda Ram_ActorPosY_i16_1_arr, x
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Calculate screen-space X-position.
    lda Ram_ActorPosX_i16_0_arr, x
    sub Zp_RoomScrollX_u16 + 0
    sta Zp_ShapePosX_i16 + 0
    lda Ram_ActorPosX_i16_1_arr, x
    sbc Zp_RoomScrollX_u16 + 1
    sta Zp_ShapePosX_i16 + 1
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the specified actor, using the given
;;; tile ID.
;;; @param A The tile ID.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_Draw1x1Actor
.PROC FuncA_Objects_Draw1x1Actor
    pha  ; tile ID
    jsr FuncA_Objects_PositionActorShape  ; preserves X
    ;; Adjust X-position.
    lda Zp_ShapePosX_i16 + 0
    sub #kTileWidthPx / 2
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    sbc #0
    sta Zp_ShapePosX_i16 + 1
    ;; Adjust Y-position.
    lda Zp_ShapePosY_i16 + 0
    sub #kTileWidthPx / 2
    sta Zp_ShapePosY_i16 + 0
    lda Zp_ShapePosY_i16 + 1
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Allocate object.
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X
    pla  ; tile ID
    bcs @done
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda Ram_ActorFlags_bObj_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the specified actor, using the given
;;; first tile ID and the subsequent tile ID.
;;; @param A The first tile ID.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_Draw1x2Actor
.PROC FuncA_Objects_Draw1x2Actor
    pha  ; first tile ID
    jsr FuncA_Objects_PositionActorShape  ; preserves X
    ;; Adjust X-position.
    lda Zp_ShapePosX_i16 + 0
    sub #kTileWidthPx / 2
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    sbc #0
    sta Zp_ShapePosX_i16 + 1
    ;; Allocate lower object.
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X
    bcs @doneLower
    pla  ; first tile ID
    pha  ; first tile ID
    adc #1  ; carry bit is already clear
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda Ram_ActorFlags_bObj_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @doneLower:
    ;; Allocate upper object.
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X
    pla  ; first tile ID
    bcs @doneUpper
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda Ram_ActorFlags_bObj_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @doneUpper:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the specified actor, using the given
;;; first tile ID and the three subsequent tile IDs.  The caller can then
;;; further modify the objects if needed.
;;; @param A The first tile ID.
;;; @param X The actor index.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the four objects.
;;; @preserve X
.EXPORT FuncA_Objects_Draw2x2Actor
.PROC FuncA_Objects_Draw2x2Actor
    pha  ; first tile ID
    jsr FuncA_Objects_PositionActorShape  ; preserves X
    lda Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    pla  ; first tile ID
    bcs @done
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #1  ; carry bit is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    clc  ; success
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
