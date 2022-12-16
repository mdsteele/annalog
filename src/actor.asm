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
.INCLUDE "actors/breakball.inc"
.INCLUDE "avatar.inc"
.INCLUDE "macros.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "terrain.inc"

.IMPORT FuncA_Actor_TickBadBeetleHorz
.IMPORT FuncA_Actor_TickBadBeetleVert
.IMPORT FuncA_Actor_TickBadCrab
.IMPORT FuncA_Actor_TickBadFish
.IMPORT FuncA_Actor_TickBadGrub
.IMPORT FuncA_Actor_TickBadHotheadHorz
.IMPORT FuncA_Actor_TickBadHotheadVert
.IMPORT FuncA_Actor_TickBadSpider
.IMPORT FuncA_Actor_TickBadToad
.IMPORT FuncA_Actor_TickBadVinebug
.IMPORT FuncA_Actor_TickNpcToddler
.IMPORT FuncA_Actor_TickProjBreakball
.IMPORT FuncA_Actor_TickProjBullet
.IMPORT FuncA_Actor_TickProjFireball
.IMPORT FuncA_Actor_TickProjFlamewave
.IMPORT FuncA_Actor_TickProjGrenade
.IMPORT FuncA_Actor_TickProjSmoke
.IMPORT FuncA_Actor_TickProjSpike
.IMPORT FuncA_Actor_TickProjSteamHorz
.IMPORT FuncA_Actor_TickProjSteamUp
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_DrawActorBadBeetleHorz
.IMPORT FuncA_Objects_DrawActorBadBeetleVert
.IMPORT FuncA_Objects_DrawActorBadCrab
.IMPORT FuncA_Objects_DrawActorBadFish
.IMPORT FuncA_Objects_DrawActorBadGrub
.IMPORT FuncA_Objects_DrawActorBadHotheadHorz
.IMPORT FuncA_Objects_DrawActorBadHotheadVert
.IMPORT FuncA_Objects_DrawActorBadSpider
.IMPORT FuncA_Objects_DrawActorBadToad
.IMPORT FuncA_Objects_DrawActorBadVinebug
.IMPORT FuncA_Objects_DrawActorNpcAdult
.IMPORT FuncA_Objects_DrawActorNpcChild
.IMPORT FuncA_Objects_DrawActorNpcMermaid
.IMPORT FuncA_Objects_DrawActorNpcMermaidQueen
.IMPORT FuncA_Objects_DrawActorNpcToddler
.IMPORT FuncA_Objects_DrawActorProjBreakball
.IMPORT FuncA_Objects_DrawActorProjBullet
.IMPORT FuncA_Objects_DrawActorProjFireball
.IMPORT FuncA_Objects_DrawActorProjFlamewave
.IMPORT FuncA_Objects_DrawActorProjGrenade
.IMPORT FuncA_Objects_DrawActorProjSmoke
.IMPORT FuncA_Objects_DrawActorProjSpike
.IMPORT FuncA_Objects_DrawActorProjSteamHorz
.IMPORT FuncA_Objects_DrawActorProjSteamUp
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Room_InitActorBadVinebug
.IMPORT FuncA_Room_InitActorNpcChild
.IMPORT FuncA_Room_InitActorNpcToddler
.IMPORT FuncA_Room_InitActorProjBreakball
.IMPORT Func_HarmAvatar
.IMPORT Func_InitActorProjBullet
.IMPORT Func_InitActorProjFireball
.IMPORT Func_InitActorProjFlamewave
.IMPORT Func_InitActorProjGrenade
.IMPORT Func_InitActorProjSmoke
.IMPORT Func_InitActorProjSpike
.IMPORT Func_InitActorProjSteamHorz
.IMPORT Func_InitActorProjSteamUp
.IMPORT Func_Noop
.IMPORT Func_PointHitsTerrain
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

;;; The hit radius of various actors, in pixels.
kProjBulletRadius = 1
kProjFireballRadius = 3
kProjGrenadeRadius = 2
kProjSmokeRadius = 6
kProjSpikeRadius = 3
kProjSteamMajorRadius = 8
kProjSteamMinorRadius = 5

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
.EXPORT Ram_ActorState1_byte_arr, Ram_ActorState2_byte_arr
Ram_ActorState1_byte_arr: .res kMaxActors
Ram_ActorState2_byte_arr: .res kMaxActors

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

;;; Stores the actor's room pixel position in Zp_Point*_i16.
;;; @param X The actor index.
;;; @preserve X, Y, Zp_Tmp*
.EXPORT Func_SetPointToActorCenter
.PROC Func_SetPointToActorCenter
    lda Ram_ActorPosX_i16_0_arr, x
    sta Zp_PointX_i16 + 0
    lda Ram_ActorPosX_i16_1_arr, x
    sta Zp_PointX_i16 + 1
    lda Ram_ActorPosY_i16_0_arr, x
    sta Zp_PointY_i16 + 0
    lda Ram_ActorPosY_i16_1_arr, x
    sta Zp_PointY_i16 + 1
    rts
.ENDPROC

;;; Sets the actor's room pixel position to Zp_Point*_i16.
;;; @param X The actor index.
;;; @preserve X, Y, Zp_Tmp*
.EXPORT Func_SetActorCenterToPoint
.PROC Func_SetActorCenterToPoint
    lda Zp_PointX_i16 + 0
    sta Ram_ActorPosX_i16_0_arr, x
    lda Zp_PointX_i16 + 1
    sta Ram_ActorPosX_i16_1_arr, x
    lda Zp_PointY_i16 + 0
    sta Ram_ActorPosY_i16_0_arr, x
    lda Zp_PointY_i16 + 1
    sta Ram_ActorPosY_i16_1_arr, x
    rts
.ENDPROC

;;; Zeroes the velocity and state bytes for the specified actor, and sets the
;;; actor's flags and type as specified.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The flags to set.
;;; @param X The actor index.
;;; @param Y The actor type to set.
;;; @preserve X, Zp_Tmp*
.PROC Func_InitActorWithFlags
    pha  ; flags
    jsr Func_InitActorDefault  ; preserves X and Zp_Tmp*
    pla  ; flags
    sta Ram_ActorFlags_bObj_arr, x
    rts
.ENDPROC

;;; The default actor init function that works for most actor types.  Zeroes
;;; the velocity, flags, and state bytes for the specified actor, and sets the
;;; actor's type as specified.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @param Y The actor type to set.
;;; @preserve X, Zp_Tmp*
.EXPORT Func_InitActorDefault
.PROC Func_InitActorDefault
    lda #0  ; param: state byte
    .assert * = Func_InitActorWithState1, error, "fallthrough"
.ENDPROC

;;; Zeroes the velocity and flags for the specified actor, and sets the actor's
;;; first state byte and type as specified.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The state byte to set.
;;; @param X The actor index.
;;; @param Y The actor type to set.
;;; @preserve X, Zp_Tmp*
.EXPORT Func_InitActorWithState1
.PROC Func_InitActorWithState1
    sta Ram_ActorState1_byte_arr, x
    tya  ; actor type
    sta Ram_ActorType_eActor_arr, x
    lda #0
    sta Ram_ActorSubX_u8_arr, x
    sta Ram_ActorSubY_u8_arr, x
    sta Ram_ActorVelX_i16_0_arr, x
    sta Ram_ActorVelX_i16_1_arr, x
    sta Ram_ActorVelY_i16_0_arr, x
    sta Ram_ActorVelY_i16_1_arr, x
    sta Ram_ActorState2_byte_arr, x
    sta Ram_ActorFlags_bObj_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; How far an actor's bounding box extends in each direction from the actor's
;;; position, indexed by eActor value.
.PROC DataA_Actor_BoundingBoxUp_u8_arr
    D_ENUM eActor
    d_byte None,             0
    d_byte BadBeetleHorz,    4
    d_byte BadBeetleVert,    6
    d_byte BadCrab,          6
    d_byte BadFish,          6
    d_byte BadGrub,          0
    d_byte BadHotheadHorz,   6
    d_byte BadHotheadVert,   6
    d_byte BadSpider,        8
    d_byte BadToad,          9
    d_byte BadVinebug,       7
    d_byte NpcAdult,        13
    d_byte NpcChild,         7
    d_byte NpcMermaid,      13
    d_byte NpcMermaidQueen,  2
    d_byte NpcToddler,       4
    d_byte ProjBreakball,   kProjBreakballRadius
    d_byte ProjBullet,      kProjBulletRadius
    d_byte ProjFireball,    kProjFireballRadius
    d_byte ProjFlamewave,   12
    d_byte ProjGrenade,     kProjGrenadeRadius
    d_byte ProjSmoke,       kProjSmokeRadius
    d_byte ProjSpike,       kProjSpikeRadius
    d_byte ProjSteamHorz,   kProjSteamMinorRadius
    d_byte ProjSteamUp,     kProjSteamMajorRadius
    D_END
.ENDPROC
.PROC DataA_Actor_BoundingBoxDown_u8_arr
    D_ENUM eActor
    d_byte None,             0
    d_byte BadBeetleHorz,    4
    d_byte BadBeetleVert,    6
    d_byte BadCrab,          8
    d_byte BadFish,          4
    d_byte BadGrub,          8
    d_byte BadHotheadHorz,   6
    d_byte BadHotheadVert,   6
    d_byte BadSpider,        2
    d_byte BadToad,          0
    d_byte BadVinebug,       7
    d_byte NpcAdult,         8
    d_byte NpcChild,         8
    d_byte NpcMermaid,       8
    d_byte NpcMermaidQueen, 24
    d_byte NpcToddler,       8
    d_byte ProjBreakball,   kProjBreakballRadius
    d_byte ProjBullet,      kProjBulletRadius
    d_byte ProjFireball,    kProjFireballRadius
    d_byte ProjFlamewave,    8
    d_byte ProjGrenade,     kProjGrenadeRadius
    d_byte ProjSmoke,       kProjSmokeRadius
    d_byte ProjSpike,       kProjSpikeRadius
    d_byte ProjSteamHorz,   kProjSteamMinorRadius
    d_byte ProjSteamUp,     kProjSteamMajorRadius
    D_END
.ENDPROC
.PROC DataA_Actor_BoundingBoxSide_u8_arr
    D_ENUM eActor
    d_byte None,            0
    d_byte BadBeetleHorz,   6
    d_byte BadBeetleVert,   4
    d_byte BadCrab,         7
    d_byte BadFish,         6
    d_byte BadGrub,         7
    d_byte BadHotheadHorz,  6
    d_byte BadHotheadVert,  6
    d_byte BadSpider,       7
    d_byte BadToad,         7
    d_byte BadVinebug,      5
    d_byte NpcAdult,        5
    d_byte NpcChild,        5
    d_byte NpcMermaid,      5
    d_byte NpcMermaidQueen, 5
    d_byte NpcToddler,      3
    d_byte ProjBreakball,   kProjBreakballRadius
    d_byte ProjBullet,      kProjBulletRadius
    d_byte ProjFireball,    kProjFireballRadius
    d_byte ProjFlamewave,   3
    d_byte ProjGrenade,     kProjGrenadeRadius
    d_byte ProjSmoke,       kProjSmokeRadius
    d_byte ProjSpike,       kProjSpikeRadius
    d_byte ProjSteamHorz,   kProjSteamMajorRadius
    d_byte ProjSteamUp,     kProjSteamMinorRadius
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
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eActor
    d_entry table, None,            Func_Noop
    d_entry table, BadBeetleHorz,   FuncA_Actor_TickBadBeetleHorz
    d_entry table, BadBeetleVert,   FuncA_Actor_TickBadBeetleVert
    d_entry table, BadCrab,         FuncA_Actor_TickBadCrab
    d_entry table, BadFish,         FuncA_Actor_TickBadFish
    d_entry table, BadGrub,         FuncA_Actor_TickBadGrub
    d_entry table, BadHotheadHorz,  FuncA_Actor_TickBadHotheadHorz
    d_entry table, BadHotheadVert,  FuncA_Actor_TickBadHotheadVert
    d_entry table, BadSpider,       FuncA_Actor_TickBadSpider
    d_entry table, BadToad,         FuncA_Actor_TickBadToad
    d_entry table, BadVinebug,      FuncA_Actor_TickBadVinebug
    d_entry table, NpcAdult,        Func_Noop
    d_entry table, NpcChild,        Func_Noop
    d_entry table, NpcMermaid,      Func_Noop
    d_entry table, NpcMermaidQueen, Func_Noop
    d_entry table, NpcToddler,      FuncA_Actor_TickNpcToddler
    d_entry table, ProjBreakball,   FuncA_Actor_TickProjBreakball
    d_entry table, ProjBullet,      FuncA_Actor_TickProjBullet
    d_entry table, ProjFireball,    FuncA_Actor_TickProjFireball
    d_entry table, ProjFlamewave,   FuncA_Actor_TickProjFlamewave
    d_entry table, ProjGrenade,     FuncA_Actor_TickProjGrenade
    d_entry table, ProjSmoke,       FuncA_Actor_TickProjSmoke
    d_entry table, ProjSpike,       FuncA_Actor_TickProjSpike
    d_entry table, ProjSteamHorz,   FuncA_Actor_TickProjSteamHorz
    d_entry table, ProjSteamUp,     FuncA_Actor_TickProjSteamUp
    D_END
.ENDREPEAT
.ENDPROC

;;; Checks if the actor is colliding with the player avatar.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X
.EXPORT FuncA_Actor_IsCollidingWithAvatar
.PROC FuncA_Actor_IsCollidingWithAvatar
    ldy Ram_ActorType_eActor_arr, x
    lda DataA_Actor_BoundingBoxSide_u8_arr, y
    add #kAvatarBoundingBoxLeft  ; param: distance
    .assert kAvatarBoundingBoxLeft = kAvatarBoundingBoxRight, error
    jsr FuncA_Actor_IsAvatarWithinHorzDistance  ; preserves X, Y; returns C
    bcc _Return
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
_Return:
    rts
.ENDPROC

;;; Checks if the horizontal distance between the centers of the actor and the
;;; player avatar is within the given distance.
;;; @param A The distance to check for.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X, Y
.EXPORT FuncA_Actor_IsAvatarWithinHorzDistance
.PROC FuncA_Actor_IsAvatarWithinHorzDistance
    sta Zp_Tmp1_byte  ; distance
    ;; Check actor-left-of-avatar.
    lda Ram_ActorPosX_i16_0_arr, x
    add Zp_Tmp1_byte  ; distance
    sta Zp_Tmp2_byte  ; x-pos (lo)
    lda Ram_ActorPosX_i16_1_arr, x
    adc #0
    sta Zp_Tmp3_byte  ; x-pos (hi)
    lda Zp_Tmp2_byte  ; x-pos (lo)
    sub Zp_AvatarPosX_i16 + 0
    lda Zp_Tmp3_byte  ; x-pos (hi)
    sbc Zp_AvatarPosX_i16 + 1
    blt _NoHit
    ;; Check avatar-left-of-actor.
    lda Zp_AvatarPosX_i16 + 0
    add Zp_Tmp1_byte  ; distance
    sta Zp_Tmp2_byte  ; x-pos (lo)
    lda Zp_AvatarPosX_i16 + 1
    adc #0
    sta Zp_Tmp3_byte  ; x-pos (hi)
    lda Zp_Tmp2_byte  ; x-pos (lo)
    sub Ram_ActorPosX_i16_0_arr, x
    lda Zp_Tmp3_byte  ; x-pos (hi)
    sbc Ram_ActorPosX_i16_1_arr, x
    blt _NoHit
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

;;; Sets or clears bObj::FlipH in the actor's flags so as to face the actor
;;; horizontally towards the player avatar.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_FaceTowardsAvatar
.PROC FuncA_Actor_FaceTowardsAvatar
    lda Zp_AvatarPosX_i16 + 0
    cmp Ram_ActorPosX_i16_0_arr, x
    lda Zp_AvatarPosX_i16 + 1
    sbc Ram_ActorPosX_i16_1_arr, x
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    bpl @faceRight
    @faceLeft:
    lda Ram_ActorFlags_bObj_arr, x
    ora #bObj::FlipH
    bne @setFlags  ; unconditional
    @faceRight:
    lda Ram_ActorFlags_bObj_arr, x
    and #<~bObj::FlipH
    @setFlags:
    sta Ram_ActorFlags_bObj_arr, x
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
;;; @preserve X, Zp_Tmp*
.EXPORT FuncA_Actor_CenterHitsTerrain
.PROC FuncA_Actor_CenterHitsTerrain
    jsr Func_SetPointToActorCenter
    jmp Func_PointHitsTerrain  ; preserves X and Zp_Tmp*, returns C
.ENDPROC

;;; Negates the actor's X-velocity.
;;; @param X The actor index.
;;; @preserve X, Y, Zp_Tmp*
.EXPORT FuncA_Actor_NegateVelX
.PROC FuncA_Actor_NegateVelX
    lda #0
    sub Ram_ActorVelX_i16_0_arr, x
    sta Ram_ActorVelX_i16_0_arr, x
    lda #0
    sbc Ram_ActorVelX_i16_1_arr, x
    sta Ram_ActorVelX_i16_1_arr, x
    rts
.ENDPROC

;;; Negates the actor's Y-velocity.
;;; @param X The actor index.
;;; @preserve X, Y, Zp_Tmp*
.EXPORT FuncA_Actor_NegateVelY
.PROC FuncA_Actor_NegateVelY
    lda #0
    sub Ram_ActorVelY_i16_0_arr, x
    sta Ram_ActorVelY_i16_0_arr, x
    lda #0
    sbc Ram_ActorVelY_i16_1_arr, x
    sta Ram_ActorVelY_i16_1_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes velocity, state, and flags for an actor appropriately based on
;;; the actor's type and pixel position.
;;; @prereq The actor's type has already been initialized.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The actor-type-specific initialization parameter.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActor
.PROC FuncA_Room_InitActor
    sta Zp_Tmp1_byte  ; initialization parameter
    ldy Ram_ActorType_eActor_arr, x
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    lda Zp_Tmp1_byte  ; param: initialization parameter
    jmp (Zp_Tmp_ptr)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eActor
    d_entry table, None,            Func_InitActorDefault
    d_entry table, BadBeetleHorz,   Func_InitActorWithFlags
    d_entry table, BadBeetleVert,   Func_InitActorWithFlags
    d_entry table, BadCrab,         Func_InitActorDefault
    d_entry table, BadFish,         Func_InitActorDefault
    d_entry table, BadGrub,         Func_InitActorDefault
    d_entry table, BadHotheadHorz,  Func_InitActorWithFlags
    d_entry table, BadHotheadVert,  Func_InitActorWithFlags
    d_entry table, BadSpider,       Func_InitActorDefault
    d_entry table, BadToad,         Func_InitActorDefault
    d_entry table, BadVinebug,      FuncA_Room_InitActorBadVinebug
    d_entry table, NpcAdult,        Func_InitActorWithState1
    d_entry table, NpcChild,        FuncA_Room_InitActorNpcChild
    d_entry table, NpcMermaid,      Func_InitActorWithState1
    d_entry table, NpcMermaidQueen, Func_InitActorDefault
    d_entry table, NpcToddler,      FuncA_Room_InitActorNpcToddler
    d_entry table, ProjBreakball,   FuncA_Room_InitActorProjBreakball
    d_entry table, ProjBullet,      Func_InitActorProjBullet
    d_entry table, ProjFireball,    Func_InitActorProjFireball
    d_entry table, ProjFlamewave,   Func_InitActorProjFlamewave
    d_entry table, ProjGrenade,     Func_InitActorProjGrenade
    d_entry table, ProjSmoke,       Func_InitActorProjSmoke
    d_entry table, ProjSpike,       Func_InitActorProjSpike
    d_entry table, ProjSteamHorz,   Func_InitActorProjSteamHorz
    d_entry table, ProjSteamUp,     Func_InitActorProjSteamUp
    D_END
.ENDREPEAT
.ENDPROC

;;; Checks if the horizontal and vertical distances between the centers of the
;;; two actors are both less than or equal to the given distance.
;;; @param A The distance to check for.
;;; @param X The first actor index.
;;; @param Y The second actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X, Y
.EXPORT FuncA_Room_AreActorsWithinDistance
.PROC FuncA_Room_AreActorsWithinDistance
    sta Zp_Tmp1_byte  ; distance
    ;; Check first-left-of-second.
    lda Ram_ActorPosX_i16_0_arr, x
    add Zp_Tmp1_byte  ; distance
    sta Zp_Tmp2_byte  ; x-pos (lo)
    lda Ram_ActorPosX_i16_1_arr, x
    adc #0
    sta Zp_Tmp3_byte  ; x-pos (hi)
    lda Zp_Tmp2_byte  ; x-pos (lo)
    sub Ram_ActorPosX_i16_0_arr, y
    lda Zp_Tmp3_byte  ; x-pos (hi)
    sbc Ram_ActorPosX_i16_1_arr, y
    blt _NoHit
    ;; Check second-left-of-first.
    lda Ram_ActorPosX_i16_0_arr, y
    add Zp_Tmp1_byte  ; distance
    sta Zp_Tmp2_byte  ; x-pos (lo)
    lda Ram_ActorPosX_i16_1_arr, y
    adc #0
    sta Zp_Tmp3_byte  ; x-pos (hi)
    lda Zp_Tmp2_byte  ; x-pos (lo)
    sub Ram_ActorPosX_i16_0_arr, x
    lda Zp_Tmp3_byte  ; x-pos (hi)
    sbc Ram_ActorPosX_i16_1_arr, x
    blt _NoHit
    ;; Check first-above-of-second.
    lda Ram_ActorPosY_i16_0_arr, x
    add Zp_Tmp1_byte  ; distance
    sta Zp_Tmp2_byte  ; y-pos (lo)
    lda Ram_ActorPosY_i16_1_arr, x
    adc #0
    sta Zp_Tmp3_byte  ; y-pos (hi)
    lda Zp_Tmp2_byte  ; y-pos (lo)
    sub Ram_ActorPosY_i16_0_arr, y
    lda Zp_Tmp3_byte  ; y-pos (hi)
    sbc Ram_ActorPosY_i16_1_arr, y
    blt _NoHit
    ;; Check second-above-of-first.
    lda Ram_ActorPosY_i16_0_arr, y
    add Zp_Tmp1_byte  ; distance
    sta Zp_Tmp2_byte  ; y-pos (lo)
    lda Ram_ActorPosY_i16_1_arr, y
    adc #0
    sta Zp_Tmp3_byte  ; y-pos (hi)
    lda Zp_Tmp2_byte  ; y-pos (lo)
    sub Ram_ActorPosY_i16_0_arr, x
    lda Zp_Tmp3_byte  ; y-pos (hi)
    sbc Ram_ActorPosY_i16_1_arr, x
    blt _NoHit
_Hit:
    sec
    rts
_NoHit:
    clc
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
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eActor
    d_entry table, None,            Func_Noop
    d_entry table, BadBeetleHorz,   FuncA_Objects_DrawActorBadBeetleHorz
    d_entry table, BadBeetleVert,   FuncA_Objects_DrawActorBadBeetleVert
    d_entry table, BadCrab,         FuncA_Objects_DrawActorBadCrab
    d_entry table, BadFish,         FuncA_Objects_DrawActorBadFish
    d_entry table, BadGrub,         FuncA_Objects_DrawActorBadGrub
    d_entry table, BadHotheadHorz,  FuncA_Objects_DrawActorBadHotheadHorz
    d_entry table, BadHotheadVert,  FuncA_Objects_DrawActorBadHotheadVert
    d_entry table, BadSpider,       FuncA_Objects_DrawActorBadSpider
    d_entry table, BadToad,         FuncA_Objects_DrawActorBadToad
    d_entry table, BadVinebug,      FuncA_Objects_DrawActorBadVinebug
    d_entry table, NpcAdult,        FuncA_Objects_DrawActorNpcAdult
    d_entry table, NpcChild,        FuncA_Objects_DrawActorNpcChild
    d_entry table, NpcMermaid,      FuncA_Objects_DrawActorNpcMermaid
    d_entry table, NpcMermaidQueen, FuncA_Objects_DrawActorNpcMermaidQueen
    d_entry table, NpcToddler,      FuncA_Objects_DrawActorNpcToddler
    d_entry table, ProjBreakball,   FuncA_Objects_DrawActorProjBreakball
    d_entry table, ProjBullet,      FuncA_Objects_DrawActorProjBullet
    d_entry table, ProjFireball,    FuncA_Objects_DrawActorProjFireball
    d_entry table, ProjFlamewave,   FuncA_Objects_DrawActorProjFlamewave
    d_entry table, ProjGrenade,     FuncA_Objects_DrawActorProjGrenade
    d_entry table, ProjSmoke,       FuncA_Objects_DrawActorProjSmoke
    d_entry table, ProjSpike,       FuncA_Objects_DrawActorProjSpike
    d_entry table, ProjSteamHorz,   FuncA_Objects_DrawActorProjSteamHorz
    d_entry table, ProjSteamUp,     FuncA_Objects_DrawActorProjSteamUp
    D_END
.ENDREPEAT
.ENDPROC

;;; Sets Zp_ShapePosX_i16 and Zp_ShapePosY_i16 to the screen-space position of
;;; the specified actor.
;;; @param X The actor index.
;;; @preserve X, Y, Zp_Tmp*
.EXPORT FuncA_Objects_SetShapePosToActorCenter
.PROC FuncA_Objects_SetShapePosToActorCenter
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

;;; Draws a 1x1-tile actor, with the tile centered on the actor position.
;;; @param A The tile ID.
;;; @param X The actor index.
;;; @param Y The OBJ palette to use when drawing the actor.
;;; @preserve X
.EXPORT FuncA_Objects_Draw1x1Actor
.PROC FuncA_Objects_Draw1x1Actor
    pha  ; tile ID
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X and Y
    ;; Adjust position.
    jsr FuncA_Objects_MoveShapeLeftHalfTile  ; preserves X and Y
    lda #kTileHeightPx / 2
    jsr FuncA_Objects_MoveShapeUpByA  ; preserves X and Y
    ;; Draw object.
    tya
    ora Ram_ActorFlags_bObj_arr, x
    tay  ; param: object flags
    pla  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
.ENDPROC

;;; Allocates and populates OAM slots for the specified actor, using the given
;;; first tile ID and the three subsequent tile IDs.  The caller can then
;;; further modify the objects if needed.
;;; @param A The first tile ID.
;;; @param X The actor index.
;;; @param Y The OBJ palette to use when drawing the actor.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the four objects.
;;; @preserve X
.EXPORT FuncA_Objects_Draw2x2Actor
.PROC FuncA_Objects_Draw2x2Actor
    pha  ; first tile ID
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X and Y
    tya
    ora Ram_ActorFlags_bObj_arr, x
    tay  ; param: object flags
    pla  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X, returns C and Y
.ENDPROC

;;;=========================================================================;;;
