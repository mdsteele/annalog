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
.INCLUDE "actors/grub.inc"
.INCLUDE "actors/orc.inc"
.INCLUDE "actors/solifuge.inc"
.INCLUDE "avatar.inc"
.INCLUDE "macros.inc"
.INCLUDE "ppu.inc"

.IMPORT FuncA_Actor_TickAllDevices
.IMPORT FuncA_Actor_TickBadBat
.IMPORT FuncA_Actor_TickBadBeetleHorz
.IMPORT FuncA_Actor_TickBadBeetleVert
.IMPORT FuncA_Actor_TickBadBird
.IMPORT FuncA_Actor_TickBadCrab
.IMPORT FuncA_Actor_TickBadFirefly
.IMPORT FuncA_Actor_TickBadFish
.IMPORT FuncA_Actor_TickBadFlower
.IMPORT FuncA_Actor_TickBadFlydrop
.IMPORT FuncA_Actor_TickBadGhostMermaid
.IMPORT FuncA_Actor_TickBadGhostOrc
.IMPORT FuncA_Actor_TickBadGooGreen
.IMPORT FuncA_Actor_TickBadGooRed
.IMPORT FuncA_Actor_TickBadGronta
.IMPORT FuncA_Actor_TickBadGrub
.IMPORT FuncA_Actor_TickBadGrubFire
.IMPORT FuncA_Actor_TickBadHotheadHorz
.IMPORT FuncA_Actor_TickBadHotheadVert
.IMPORT FuncA_Actor_TickBadJelly
.IMPORT FuncA_Actor_TickBadLavaball
.IMPORT FuncA_Actor_TickBadOrc
.IMPORT FuncA_Actor_TickBadRhino
.IMPORT FuncA_Actor_TickBadRodent
.IMPORT FuncA_Actor_TickBadSlime
.IMPORT FuncA_Actor_TickBadSolifuge
.IMPORT FuncA_Actor_TickBadSpider
.IMPORT FuncA_Actor_TickBadToad
.IMPORT FuncA_Actor_TickBadVinebug
.IMPORT FuncA_Actor_TickBadWasp
.IMPORT FuncA_Actor_TickNpcDuck
.IMPORT FuncA_Actor_TickNpcToddler
.IMPORT FuncA_Actor_TickProjAcid
.IMPORT FuncA_Actor_TickProjAxeBoomer
.IMPORT FuncA_Actor_TickProjAxeSmash
.IMPORT FuncA_Actor_TickProjBreakball
.IMPORT FuncA_Actor_TickProjBreakbomb
.IMPORT FuncA_Actor_TickProjBreakfire
.IMPORT FuncA_Actor_TickProjBullet
.IMPORT FuncA_Actor_TickProjEgg
.IMPORT FuncA_Actor_TickProjEmber
.IMPORT FuncA_Actor_TickProjFireball
.IMPORT FuncA_Actor_TickProjFireblast
.IMPORT FuncA_Actor_TickProjFlamestrike
.IMPORT FuncA_Actor_TickProjFood
.IMPORT FuncA_Actor_TickProjGrenade
.IMPORT FuncA_Actor_TickProjRocket
.IMPORT FuncA_Actor_TickProjSpike
.IMPORT FuncA_Actor_TickProjSpine
.IMPORT FuncA_Actor_TickProjSteamHorz
.IMPORT FuncA_Actor_TickProjSteamUp
.IMPORT FuncA_Actor_TickSmokeAxe
.IMPORT FuncA_Actor_TickSmokeBeam
.IMPORT FuncA_Actor_TickSmokeBlood
.IMPORT FuncA_Actor_TickSmokeDirt
.IMPORT FuncA_Actor_TickSmokeExplosion
.IMPORT FuncA_Actor_TickSmokeFragment
.IMPORT FuncA_Actor_TickSmokeParticle
.IMPORT FuncA_Actor_TickSmokeRaindrop
.IMPORT FuncA_Actor_TickSmokeSteamHorz
.IMPORT FuncA_Actor_TickSmokeSteamUp
.IMPORT FuncA_Actor_TickSmokeWaterfall
.IMPORT FuncA_Objects_DrawActorBadBat
.IMPORT FuncA_Objects_DrawActorBadBeetleHorz
.IMPORT FuncA_Objects_DrawActorBadBeetleVert
.IMPORT FuncA_Objects_DrawActorBadBird
.IMPORT FuncA_Objects_DrawActorBadCrab
.IMPORT FuncA_Objects_DrawActorBadFirefly
.IMPORT FuncA_Objects_DrawActorBadFish
.IMPORT FuncA_Objects_DrawActorBadFlower
.IMPORT FuncA_Objects_DrawActorBadFlydrop
.IMPORT FuncA_Objects_DrawActorBadGhostMermaid
.IMPORT FuncA_Objects_DrawActorBadGhostOrc
.IMPORT FuncA_Objects_DrawActorBadGooGreen
.IMPORT FuncA_Objects_DrawActorBadGooRed
.IMPORT FuncA_Objects_DrawActorBadGronta
.IMPORT FuncA_Objects_DrawActorBadGrub
.IMPORT FuncA_Objects_DrawActorBadGrubFire
.IMPORT FuncA_Objects_DrawActorBadHotheadHorz
.IMPORT FuncA_Objects_DrawActorBadHotheadVert
.IMPORT FuncA_Objects_DrawActorBadJelly
.IMPORT FuncA_Objects_DrawActorBadLavaball
.IMPORT FuncA_Objects_DrawActorBadOrc
.IMPORT FuncA_Objects_DrawActorBadRhino
.IMPORT FuncA_Objects_DrawActorBadRodent
.IMPORT FuncA_Objects_DrawActorBadSlime
.IMPORT FuncA_Objects_DrawActorBadSolifuge
.IMPORT FuncA_Objects_DrawActorBadSpider
.IMPORT FuncA_Objects_DrawActorBadToad
.IMPORT FuncA_Objects_DrawActorBadVinebug
.IMPORT FuncA_Objects_DrawActorBadWasp
.IMPORT FuncA_Objects_DrawActorNpcAdult
.IMPORT FuncA_Objects_DrawActorNpcBlinky
.IMPORT FuncA_Objects_DrawActorNpcChild
.IMPORT FuncA_Objects_DrawActorNpcDuck
.IMPORT FuncA_Objects_DrawActorNpcOrc
.IMPORT FuncA_Objects_DrawActorNpcOrcSleeping
.IMPORT FuncA_Objects_DrawActorNpcQueen
.IMPORT FuncA_Objects_DrawActorNpcSquare
.IMPORT FuncA_Objects_DrawActorNpcToddler
.IMPORT FuncA_Objects_DrawActorProjAcid
.IMPORT FuncA_Objects_DrawActorProjAxe
.IMPORT FuncA_Objects_DrawActorProjBreakball
.IMPORT FuncA_Objects_DrawActorProjBreakbomb
.IMPORT FuncA_Objects_DrawActorProjBreakfire
.IMPORT FuncA_Objects_DrawActorProjBullet
.IMPORT FuncA_Objects_DrawActorProjEgg
.IMPORT FuncA_Objects_DrawActorProjEmber
.IMPORT FuncA_Objects_DrawActorProjFireball
.IMPORT FuncA_Objects_DrawActorProjFireblast
.IMPORT FuncA_Objects_DrawActorProjFlamestrike
.IMPORT FuncA_Objects_DrawActorProjFood
.IMPORT FuncA_Objects_DrawActorProjGrenade
.IMPORT FuncA_Objects_DrawActorProjRocket
.IMPORT FuncA_Objects_DrawActorProjSpike
.IMPORT FuncA_Objects_DrawActorProjSpine
.IMPORT FuncA_Objects_DrawActorProjSteamHorz
.IMPORT FuncA_Objects_DrawActorProjSteamUp
.IMPORT FuncA_Objects_DrawActorSmokeBeam
.IMPORT FuncA_Objects_DrawActorSmokeBlood
.IMPORT FuncA_Objects_DrawActorSmokeDirt
.IMPORT FuncA_Objects_DrawActorSmokeExplosion
.IMPORT FuncA_Objects_DrawActorSmokeFragment
.IMPORT FuncA_Objects_DrawActorSmokeParticle
.IMPORT FuncA_Objects_DrawActorSmokeRaindrop
.IMPORT FuncA_Objects_DrawActorSmokeSteamHorz
.IMPORT FuncA_Objects_DrawActorSmokeSteamUp
.IMPORT FuncA_Objects_DrawActorSmokeWaterfall
.IMPORT FuncA_Room_InitActorBadBird
.IMPORT FuncA_Room_InitActorBadFirefly
.IMPORT FuncA_Room_InitActorBadFlydrop
.IMPORT FuncA_Room_InitActorBadGooRed
.IMPORT FuncA_Room_InitActorBadLavaball
.IMPORT FuncA_Room_InitActorBadToad
.IMPORT FuncA_Room_InitActorBadWasp
.IMPORT FuncA_Room_InitActorNpcChild
.IMPORT FuncA_Room_InitActorNpcToddler
.IMPORT Func_InitActorBadGronta
.IMPORT Func_InitActorBadOrc
.IMPORT Func_InitActorBadSolifuge
.IMPORT Func_InitActorNpcOrc
.IMPORT Func_Noop
.IMPORT Func_SetPointToAvatarCenter
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

;;; The hit radius of various actors, in pixels.
kBadGooRadius         = 6
kBadJellyRadius       = 5
kProjAxeRadius        = 5
kProjBreakbombRadius  = 3
kProjBulletRadius     = 1
kProjEggRadius        = 3
kProjFireballRadius   = 3
kProjFireblastRadius  = 3
kProjFoodRadius       = 1
kProjGrenadeRadius    = 2
kProjRocketRadius     = 2
kProjSpikeRadius      = 3
kProjSpineRadius      = 1
kSmokeBloodRadius     = 1
kSmokeDirtRadius      = 1
kSmokeExplosionRadius = 6
kSmokeFragmentRadius  = 1
kSmokeParticleRadius  = 1
kSteamMajorRadius     = 8
kSteamMinorRadius     = 3

;;;=========================================================================;;;

.SEGMENT "RAM_Actor"

;;; The type for each actor in the room (or eActor::None for an empty slot).
.EXPORT Ram_ActorType_eActor_arr
Ram_ActorType_eActor_arr: .res kMaxActors

;;; The object flags to apply for each actor in the room.  In particular, if
;;; bObj::FlipH is set, then the actor will face left instead of right, and if
;;; bObj::FlipV is set, then the actor will be upside-down.
.EXPORT Ram_ActorFlags_bObj_arr
Ram_ActorFlags_bObj_arr: .res kMaxActors

;;; The current X/Y subpixel positions of each actor in the room.
.EXPORT Ram_ActorSubX_u8_arr
Ram_ActorSubX_u8_arr: .res kMaxActors
.EXPORT Ram_ActorSubY_u8_arr
Ram_ActorSubY_u8_arr: .res kMaxActors

;;; The current X/Y positions of each actor in the room, in room-space pixels.
.EXPORT Ram_ActorPosX_i16_0_arr
Ram_ActorPosX_i16_0_arr: .res kMaxActors
.EXPORT Ram_ActorPosX_i16_1_arr
Ram_ActorPosX_i16_1_arr: .res kMaxActors
.EXPORT Ram_ActorPosY_i16_0_arr
Ram_ActorPosY_i16_0_arr: .res kMaxActors
.EXPORT Ram_ActorPosY_i16_1_arr
Ram_ActorPosY_i16_1_arr: .res kMaxActors

;;; The current velocities of each actor in the room, in subpixels per frame.
.EXPORT Ram_ActorVelX_i16_0_arr
Ram_ActorVelX_i16_0_arr: .res kMaxActors
.EXPORT Ram_ActorVelX_i16_1_arr
Ram_ActorVelX_i16_1_arr: .res kMaxActors
.EXPORT Ram_ActorVelY_i16_0_arr
Ram_ActorVelY_i16_0_arr: .res kMaxActors
.EXPORT Ram_ActorVelY_i16_1_arr
Ram_ActorVelY_i16_1_arr: .res kMaxActors

;;; Type-specific state data for each actor in the room.
.EXPORT Ram_ActorState1_byte_arr
Ram_ActorState1_byte_arr: .res kMaxActors
.EXPORT Ram_ActorState2_byte_arr
Ram_ActorState2_byte_arr: .res kMaxActors
.EXPORT Ram_ActorState3_byte_arr
Ram_ActorState3_byte_arr: .res kMaxActors
.EXPORT Ram_ActorState4_byte_arr
Ram_ActorState4_byte_arr: .res kMaxActors

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Returns the index of the last empty actor slot (if any), or sets the C flag
;;; if all actor slots are full.
;;; @return C Set if all slots were full; cleared if an empty slot was found.
;;; @return X The index of the empty slot (if any).
;;; @preserve Y, T0+
.EXPORT Func_FindEmptyActorSlot
.PROC Func_FindEmptyActorSlot
    lda #eActor::None  ; param: actor type to find
    fall Func_FindActorWithType  ; preserves Y and T0+, returns C and X
.ENDPROC

;;; Finds an actor in the room with the specified type (if any) and returns its
;;; index, or sets the C flag if there isn't any actor of that type right now.
;;; @param A The eActor value to find.
;;; @return C Set if no actor of that type was found.
;;; @return X The index of the found actor (if any).
;;; @preserve Y, T0+
.EXPORT Func_FindActorWithType
.PROC Func_FindActorWithType
    ldx #kMaxActors - 1
    @loop:
    cmp Ram_ActorType_eActor_arr, x
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
;;; @preserve X, Y, T0+
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
;;; @preserve X, Y, T0+
.EXPORT Func_SetActorCenterToPoint
.PROC Func_SetActorCenterToPoint
    lda #0
    sta Ram_ActorSubX_u8_arr, x
    sta Ram_ActorSubY_u8_arr, x
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

;;; Checks if the horizontal and vertical distances between the center of the
;;; actor and the position stored in Zp_Point*_i16 are both less than or equal
;;; to the given distance.
;;; @param A The distance to check for.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X, T1+
.EXPORT Func_IsActorWithinDistanceOfPoint
.PROC Func_IsActorWithinDistanceOfPoint
    pha  ; distance
    jsr Func_IsActorWithinHorzDistanceOfPoint  ; preserves X, T1+; returns C
    pla  ; distance
    bcs @checkVert
    rts
    @checkVert:
    tay  ; param: distance below
    fall Func_IsActorWithinVertDistancesOfPoint  ; preserves X, T1+; returns C
.ENDPROC

;;; Checks if the distance between the vertical center of the actor and
;;; Zp_PointY_i16 is within the given up/down distances.
;;; @param A The distance above the point to check for.
;;; @param Y The distance below the point to check for.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X, T1+
.EXPORT Func_IsActorWithinVertDistancesOfPoint
.PROC Func_IsActorWithinVertDistancesOfPoint
    ;; Check bottom side of actor.
    add Ram_ActorPosY_i16_0_arr, x
    pha     ; y-pos (lo)
    lda #0
    adc Ram_ActorPosY_i16_1_arr, x
    sta T0  ; y-pos (hi)
    pla     ; y-pos (lo)
    cmp Zp_PointY_i16 + 0
    lda T0  ; y-pos (hi)
    sbc Zp_PointY_i16 + 1
    bmi _NoHit
    ;; Check top side of actor.
    tya  ; distance below point
    add Zp_PointY_i16 + 0
    pha     ; y-pos (lo)
    lda #0
    adc Zp_PointY_i16 + 1
    sta T0  ; y-pos (hi)
    pla     ; y-pos (lo)
    cmp Ram_ActorPosY_i16_0_arr, x
    lda T0  ; y-pos (hi)
    sbc Ram_ActorPosY_i16_1_arr, x
    bmi _NoHit
_Hit:
    sec
    rts
_NoHit:
    clc
    rts
.ENDPROC

;;; Checks if the distance between the horizontal center of the actor and
;;; Zp_PointX_i16 is within the given distance.
;;; @param A The distance to check for.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X, T1+
.EXPORT Func_IsActorWithinHorzDistanceOfPoint
.PROC Func_IsActorWithinHorzDistanceOfPoint
    tay  ; distance
    ;; Check actor-left-of-point.
    add Ram_ActorPosX_i16_0_arr, x
    pha     ; x-pos (lo)
    lda #0
    adc Ram_ActorPosX_i16_1_arr, x
    sta T0  ; x-pos (hi)
    pla     ; x-pos (lo)
    cmp Zp_PointX_i16 + 0
    lda T0  ; x-pos (hi)
    sbc Zp_PointX_i16 + 1
    bmi _NoHit
    ;; Check point-left-of-actor.
    tya  ; distance
    add Zp_PointX_i16 + 0
    pha     ; x-pos (lo)
    lda #0
    adc Zp_PointX_i16 + 1
    sta T0  ; x-pos (hi)
    pla     ; x-pos (lo)
    cmp Ram_ActorPosX_i16_0_arr, x
    lda T0  ; x-pos (hi)
    sbc Ram_ActorPosX_i16_1_arr, x
    bmi _NoHit
_Hit:
    sec
    rts
_NoHit:
    clc
    rts
.ENDPROC

;;; Zeroes the velocity and state bytes for the specified actor, and sets the
;;; actor's flags and type as specified.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The flags to set.
;;; @param X The actor index.
;;; @param Y The actor type to set.
;;; @preserve X, T0+
.EXPORT Func_InitActorWithFlags
.PROC Func_InitActorWithFlags
    pha  ; flags
    jsr Func_InitActorDefault  ; preserves X and T0+
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
;;; @preserve X, T0+
.EXPORT Func_InitActorDefault
.PROC Func_InitActorDefault
    lda #0  ; param: state byte
    fall Func_InitActorWithState1  ; preserves X and T0+
.ENDPROC

;;; Zeroes the velocity and flags for the specified actor, and sets the actor's
;;; first state byte and type as specified.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The state byte to set.
;;; @param X The actor index.
;;; @param Y The actor type to set.
;;; @preserve X, T0+
.EXPORT Func_InitActorWithState1
.PROC Func_InitActorWithState1
    sta Ram_ActorState1_byte_arr, x
    tya  ; actor type
    sta Ram_ActorType_eActor_arr, x
    lda #0
    sta Ram_ActorFlags_bObj_arr, x
    sta Ram_ActorSubX_u8_arr, x
    sta Ram_ActorSubY_u8_arr, x
    sta Ram_ActorVelX_i16_0_arr, x
    sta Ram_ActorVelX_i16_1_arr, x
    sta Ram_ActorVelY_i16_0_arr, x
    sta Ram_ActorVelY_i16_1_arr, x
    sta Ram_ActorState2_byte_arr, x
    sta Ram_ActorState3_byte_arr, x
    sta Ram_ActorState4_byte_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; How far an actor's bounding box extends in each direction from the actor's
;;; position, indexed by eActor value.
.PROC DataA_Actor_BoundingBoxUp_u8_arr
    D_ARRAY .enum, eActor
    d_byte None,             0
    d_byte BadBat,           4
    d_byte BadBeetleHorz,    4
    d_byte BadBeetleVert,    6
    d_byte BadBird,          4
    d_byte BadCrab,          6
    d_byte BadFirefly,       6
    d_byte BadFish,          6
    d_byte BadFlower,       14
    d_byte BadFlydrop,       6
    d_byte BadGhostMermaid, 13
    d_byte BadGhostOrc,     kOrcBoundingBoxUp
    d_byte BadGooGreen,     kBadGooRadius
    d_byte BadGooRed,       kBadGooRadius
    d_byte BadGronta,       kOrcBoundingBoxUp
    d_byte BadGrub,         kBadGrubBoundingBoxUp
    d_byte BadGrubFire,     kBadGrubBoundingBoxUp
    d_byte BadHotheadHorz,   6
    d_byte BadHotheadVert,   6
    d_byte BadJelly,        kBadJellyRadius
    d_byte BadLavaball,      7
    d_byte BadOrc,          kOrcBoundingBoxUp
    d_byte BadRhino,         4
    d_byte BadRodent,        2
    d_byte BadSlime,         4
    d_byte BadSolifuge,     kBadSolifugeBoundingBoxDown
    d_byte BadSpider,        8
    d_byte BadToad,          9
    d_byte BadVinebug,       7
    d_byte BadWasp,          5
    d_byte NpcAdult,        13
    d_byte NpcBlinky,        1
    d_byte NpcChild,         7
    d_byte NpcDuck,          1
    d_byte NpcOrc,          kOrcBoundingBoxUp
    d_byte NpcOrcSleeping,   3
    d_byte NpcQueen,         2
    d_byte NpcSquare,       kTileHeightPx
    d_byte NpcToddler,       4
    d_byte ProjAcid,         1
    d_byte ProjAxeBoomer,   kProjAxeRadius
    d_byte ProjAxeSmash,    kProjAxeRadius
    d_byte ProjBreakball,   kProjBreakballRadius
    d_byte ProjBreakbomb,   kProjBreakbombRadius
    d_byte ProjBreakfire,   12
    d_byte ProjBullet,      kProjBulletRadius
    d_byte ProjEgg,         kProjEggRadius
    d_byte ProjEmber,        1
    d_byte ProjFireball,    kProjFireballRadius
    d_byte ProjFireblast,   kProjFireblastRadius
    d_byte ProjFlamestrike, 44
    d_byte ProjFood,        kProjFoodRadius
    d_byte ProjGrenade,     kProjGrenadeRadius
    d_byte ProjRocket,      kProjRocketRadius
    d_byte ProjSpike,       kProjSpikeRadius
    d_byte ProjSpine,       kProjSpineRadius
    d_byte ProjSteamHorz,   kSteamMinorRadius
    d_byte ProjSteamUp,     kSteamMajorRadius
    d_byte SmokeAxe,        kProjAxeRadius
    d_byte SmokeBeam,        1
    d_byte SmokeBlood,      kSmokeBloodRadius
    d_byte SmokeDirt,       kSmokeDirtRadius
    d_byte SmokeExplosion,  kSmokeExplosionRadius
    d_byte SmokeFragment,   kSmokeFragmentRadius
    d_byte SmokeParticle,   kSmokeParticleRadius
    d_byte SmokeRaindrop,    2
    d_byte SmokeSteamHorz,  kSteamMinorRadius
    d_byte SmokeSteamUp,    kSteamMajorRadius
    d_byte SmokeWaterfall,   0
    D_END
.ENDPROC
.PROC DataA_Actor_BoundingBoxDown_u8_arr
    D_ARRAY .enum, eActor
    d_byte None,             0
    d_byte BadBat,           4
    d_byte BadBeetleHorz,    4
    d_byte BadBeetleVert,    6
    d_byte BadBird,          4
    d_byte BadCrab,          8
    d_byte BadFirefly,       8
    d_byte BadFish,          4
    d_byte BadFlower,        8
    d_byte BadFlydrop,       6
    d_byte BadGhostMermaid,  7
    d_byte BadGhostOrc,     kOrcBoundingBoxDown
    d_byte BadGooGreen,     kBadGooRadius
    d_byte BadGooRed,       kBadGooRadius
    d_byte BadGronta,       kOrcBoundingBoxDown
    d_byte BadGrub,         kBadGrubBoundingBoxDown
    d_byte BadGrubFire,     kBadGrubBoundingBoxDown
    d_byte BadHotheadHorz,   6
    d_byte BadHotheadVert,   6
    d_byte BadJelly,        kBadJellyRadius
    d_byte BadLavaball,      7
    d_byte BadOrc,          kOrcBoundingBoxDown
    d_byte BadRhino,         8
    d_byte BadRodent,        2
    d_byte BadSlime,         2
    d_byte BadSolifuge,     kBadSolifugeBoundingBoxDown
    d_byte BadSpider,        2
    d_byte BadToad,          0
    d_byte BadVinebug,       7
    d_byte BadWasp,          6
    d_byte NpcAdult,         8
    d_byte NpcBlinky,        1
    d_byte NpcChild,         8
    d_byte NpcDuck,          3
    d_byte NpcOrc,          kOrcBoundingBoxDown
    d_byte NpcOrcSleeping,   5
    d_byte NpcQueen,        24
    d_byte NpcSquare,       kTileHeightPx
    d_byte NpcToddler,       8
    d_byte ProjAcid,         3
    d_byte ProjAxeBoomer,   kProjAxeRadius
    d_byte ProjAxeSmash,    kProjAxeRadius
    d_byte ProjBreakball,   kProjBreakballRadius
    d_byte ProjBreakbomb,   kProjBreakbombRadius
    d_byte ProjBreakfire,    8
    d_byte ProjBullet,      kProjBulletRadius
    d_byte ProjEgg,         kProjEggRadius
    d_byte ProjEmber,        3
    d_byte ProjFireball,    kProjFireballRadius
    d_byte ProjFireblast,   kProjFireblastRadius
    d_byte ProjFlamestrike,  4
    d_byte ProjFood,        kProjFoodRadius
    d_byte ProjGrenade,     kProjGrenadeRadius
    d_byte ProjRocket,      kProjRocketRadius
    d_byte ProjSpike,       kProjSpikeRadius
    d_byte ProjSpine,       kProjSpineRadius
    d_byte ProjSteamHorz,   kSteamMinorRadius
    d_byte ProjSteamUp,     kSteamMajorRadius
    d_byte SmokeAxe,        kProjAxeRadius
    d_byte SmokeBeam,        1
    d_byte SmokeBlood,      kSmokeBloodRadius
    d_byte SmokeDirt,       kSmokeDirtRadius
    d_byte SmokeExplosion,  kSmokeExplosionRadius
    d_byte SmokeFragment,   kSmokeFragmentRadius
    d_byte SmokeParticle,   kSmokeParticleRadius
    d_byte SmokeRaindrop,    2
    d_byte SmokeSteamHorz,  kSteamMinorRadius
    d_byte SmokeSteamUp,    kSteamMajorRadius
    d_byte SmokeWaterfall,   8
    D_END
.ENDPROC
.PROC DataA_Actor_BoundingBoxSide_u8_arr
    D_ARRAY .enum, eActor
    d_byte None,             0
    d_byte BadBat,           6
    d_byte BadBeetleHorz,    6
    d_byte BadBeetleVert,    4
    d_byte BadBird,          7
    d_byte BadCrab,          7
    d_byte BadFirefly,       6
    d_byte BadFish,          6
    d_byte BadFlower,       12
    d_byte BadFlydrop,       6
    d_byte BadGhostMermaid,  6
    d_byte BadGhostOrc,     kOrcBoundingBoxSide
    d_byte BadGooGreen,     kBadGooRadius
    d_byte BadGooRed,       kBadGooRadius
    d_byte BadGronta,       kOrcBoundingBoxSide
    d_byte BadGrub,         kBadGrubBoundingBoxSide
    d_byte BadGrubFire,     kBadGrubBoundingBoxSide
    d_byte BadHotheadHorz,   6
    d_byte BadHotheadVert,   6
    d_byte BadJelly,        kBadJellyRadius
    d_byte BadLavaball,      6
    d_byte BadOrc,          kOrcBoundingBoxSide
    d_byte BadRhino,        10
    d_byte BadRodent,        2
    d_byte BadSlime,         6
    d_byte BadSolifuge,     kBadSolifugeBoundingBoxSide
    d_byte BadSpider,        6
    d_byte BadToad,          7
    d_byte BadVinebug,       5
    d_byte BadWasp,          6
    d_byte NpcAdult,         5
    d_byte NpcBlinky,        1
    d_byte NpcChild,         5
    d_byte NpcDuck,          3
    d_byte NpcOrc,          kOrcBoundingBoxSide
    d_byte NpcOrcSleeping,   5
    d_byte NpcQueen,         5
    d_byte NpcSquare,       kTileWidthPx
    d_byte NpcToddler,       3
    d_byte ProjAcid,         2
    d_byte ProjAxeBoomer,   kProjAxeRadius
    d_byte ProjAxeSmash,    kProjAxeRadius
    d_byte ProjBreakball,   kProjBreakballRadius
    d_byte ProjBreakbomb,   kProjBreakbombRadius
    d_byte ProjBreakfire,    3
    d_byte ProjBullet,      kProjBulletRadius
    d_byte ProjEgg,         kProjEggRadius
    d_byte ProjEmber,        2
    d_byte ProjFireball,    kProjFireballRadius
    d_byte ProjFireblast,   kProjFireblastRadius
    d_byte ProjFlamestrike,  3
    d_byte ProjFood,        kProjFoodRadius
    d_byte ProjGrenade,     kProjGrenadeRadius
    d_byte ProjRocket,      kProjRocketRadius
    d_byte ProjSpike,       kProjSpikeRadius
    d_byte ProjSpine,       kProjSpineRadius
    d_byte ProjSteamHorz,   kSteamMajorRadius
    d_byte ProjSteamUp,     kSteamMinorRadius
    d_byte SmokeAxe,        kProjAxeRadius
    d_byte SmokeBeam,        1
    d_byte SmokeBlood,      kSmokeBloodRadius
    d_byte SmokeDirt,       kSmokeDirtRadius
    d_byte SmokeExplosion,  kSmokeExplosionRadius
    d_byte SmokeFragment,   kSmokeFragmentRadius
    d_byte SmokeParticle,   kSmokeParticleRadius
    d_byte SmokeRaindrop,    1
    d_byte SmokeSteamHorz,  kSteamMajorRadius
    d_byte SmokeSteamUp,    kSteamMinorRadius
    d_byte SmokeWaterfall,   4
    D_END
.ENDPROC

;;; Performs per-frame updates for each device and actor in the room.
.EXPORT FuncA_Actor_TickAllDevicesAndActors
.PROC FuncA_Actor_TickAllDevicesAndActors
    ldx #kMaxActors - 1
    @loop:
    jsr FuncA_Actor_TickOneActor  ; preserves X
    dex
    bpl @loop
    jmp FuncA_Actor_TickAllDevices
.ENDPROC

;;; Performs per-frame updates for each device and smoke actor in the room.
.EXPORT FuncA_Actor_TickAllDevicesAndSmokeActors
.PROC FuncA_Actor_TickAllDevicesAndSmokeActors
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #kFirstSmokeActorType
    blt @continue
    jsr FuncA_Actor_TickOneActor  ; preserves X
    @continue:
    dex
    bpl @loop
    jmp FuncA_Actor_TickAllDevices
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
    ldy Ram_ActorType_eActor_arr, x
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eActor
    d_entry table, None,            Func_Noop
    d_entry table, BadBat,          FuncA_Actor_TickBadBat
    d_entry table, BadBeetleHorz,   FuncA_Actor_TickBadBeetleHorz
    d_entry table, BadBeetleVert,   FuncA_Actor_TickBadBeetleVert
    d_entry table, BadBird,         FuncA_Actor_TickBadBird
    d_entry table, BadCrab,         FuncA_Actor_TickBadCrab
    d_entry table, BadFirefly,      FuncA_Actor_TickBadFirefly
    d_entry table, BadFish,         FuncA_Actor_TickBadFish
    d_entry table, BadFlower,       FuncA_Actor_TickBadFlower
    d_entry table, BadFlydrop,      FuncA_Actor_TickBadFlydrop
    d_entry table, BadGhostMermaid, FuncA_Actor_TickBadGhostMermaid
    d_entry table, BadGhostOrc,     FuncA_Actor_TickBadGhostOrc
    d_entry table, BadGooGreen,     FuncA_Actor_TickBadGooGreen
    d_entry table, BadGooRed,       FuncA_Actor_TickBadGooRed
    d_entry table, BadGronta,       FuncA_Actor_TickBadGronta
    d_entry table, BadGrub,         FuncA_Actor_TickBadGrub
    d_entry table, BadGrubFire,     FuncA_Actor_TickBadGrubFire
    d_entry table, BadHotheadHorz,  FuncA_Actor_TickBadHotheadHorz
    d_entry table, BadHotheadVert,  FuncA_Actor_TickBadHotheadVert
    d_entry table, BadJelly,        FuncA_Actor_TickBadJelly
    d_entry table, BadLavaball,     FuncA_Actor_TickBadLavaball
    d_entry table, BadOrc,          FuncA_Actor_TickBadOrc
    d_entry table, BadRhino,        FuncA_Actor_TickBadRhino
    d_entry table, BadRodent,       FuncA_Actor_TickBadRodent
    d_entry table, BadSlime,        FuncA_Actor_TickBadSlime
    d_entry table, BadSolifuge,     FuncA_Actor_TickBadSolifuge
    d_entry table, BadSpider,       FuncA_Actor_TickBadSpider
    d_entry table, BadToad,         FuncA_Actor_TickBadToad
    d_entry table, BadVinebug,      FuncA_Actor_TickBadVinebug
    d_entry table, BadWasp,         FuncA_Actor_TickBadWasp
    d_entry table, NpcAdult,        Func_Noop
    d_entry table, NpcBlinky,       Func_Noop
    d_entry table, NpcChild,        Func_Noop
    d_entry table, NpcDuck,         FuncA_Actor_TickNpcDuck
    d_entry table, NpcOrc,          Func_Noop
    d_entry table, NpcOrcSleeping,  Func_Noop
    d_entry table, NpcQueen,        Func_Noop
    d_entry table, NpcSquare,       Func_Noop
    d_entry table, NpcToddler,      FuncA_Actor_TickNpcToddler
    d_entry table, ProjAcid,        FuncA_Actor_TickProjAcid
    d_entry table, ProjAxeBoomer,   FuncA_Actor_TickProjAxeBoomer
    d_entry table, ProjAxeSmash,    FuncA_Actor_TickProjAxeSmash
    d_entry table, ProjBreakball,   FuncA_Actor_TickProjBreakball
    d_entry table, ProjBreakbomb,   FuncA_Actor_TickProjBreakbomb
    d_entry table, ProjBreakfire,   FuncA_Actor_TickProjBreakfire
    d_entry table, ProjBullet,      FuncA_Actor_TickProjBullet
    d_entry table, ProjEgg,         FuncA_Actor_TickProjEgg
    d_entry table, ProjEmber,       FuncA_Actor_TickProjEmber
    d_entry table, ProjFireball,    FuncA_Actor_TickProjFireball
    d_entry table, ProjFireblast,   FuncA_Actor_TickProjFireblast
    d_entry table, ProjFlamestrike, FuncA_Actor_TickProjFlamestrike
    d_entry table, ProjFood,        FuncA_Actor_TickProjFood
    d_entry table, ProjGrenade,     FuncA_Actor_TickProjGrenade
    d_entry table, ProjRocket,      FuncA_Actor_TickProjRocket
    d_entry table, ProjSpike,       FuncA_Actor_TickProjSpike
    d_entry table, ProjSpine,       FuncA_Actor_TickProjSpine
    d_entry table, ProjSteamHorz,   FuncA_Actor_TickProjSteamHorz
    d_entry table, ProjSteamUp,     FuncA_Actor_TickProjSteamUp
    d_entry table, SmokeAxe,        FuncA_Actor_TickSmokeAxe
    d_entry table, SmokeBeam,       FuncA_Actor_TickSmokeBeam
    d_entry table, SmokeBlood,      FuncA_Actor_TickSmokeBlood
    d_entry table, SmokeDirt,       FuncA_Actor_TickSmokeDirt
    d_entry table, SmokeExplosion,  FuncA_Actor_TickSmokeExplosion
    d_entry table, SmokeFragment,   FuncA_Actor_TickSmokeFragment
    d_entry table, SmokeParticle,   FuncA_Actor_TickSmokeParticle
    d_entry table, SmokeRaindrop,   FuncA_Actor_TickSmokeRaindrop
    d_entry table, SmokeSteamHorz,  FuncA_Actor_TickSmokeSteamHorz
    d_entry table, SmokeSteamUp,    FuncA_Actor_TickSmokeSteamUp
    d_entry table, SmokeWaterfall,  FuncA_Actor_TickSmokeWaterfall
    D_END
.ENDREPEAT
.ENDPROC

;;; Checks if the actor is colliding with the player avatar.
;;; @param X The actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X, T1+
.EXPORT FuncA_Actor_IsCollidingWithAvatar
.PROC FuncA_Actor_IsCollidingWithAvatar
    jsr Func_SetPointToAvatarCenter  ; preserves X and T0+
_CheckHorz:
    ldy Ram_ActorType_eActor_arr, x
    lda DataA_Actor_BoundingBoxSide_u8_arr, y
    add #kAvatarBoundingBoxLeft  ; param: distance
    .assert kAvatarBoundingBoxLeft = kAvatarBoundingBoxRight, error
    jsr Func_IsActorWithinHorzDistanceOfPoint  ; preserves X, T1+; returns C
    bcs @hitHorz
    rts
    @hitHorz:
_CheckVert:
    ldy Ram_ActorType_eActor_arr, x
    lda DataA_Actor_BoundingBoxDown_u8_arr, y
    add #kAvatarBoundingBoxUp
    pha  ; distance above avatar
    lda DataA_Actor_BoundingBoxUp_u8_arr, y
    add #kAvatarBoundingBoxDown
    tay  ; param: distance below avatar
    pla  ; param: distance above avatar
    jmp Func_IsActorWithinVertDistancesOfPoint  ; preserves X, T1+; returns C
.ENDPROC

;;; Checks if the actor is colliding with another actor.
;;; @param X The actor index.
;;; @param Y The other actor index.
;;; @return C Set if a collision occurred, cleared otherwise.
;;; @preserve X, Y, T3+
.EXPORT FuncA_Actor_IsCollidingWithOtherActor
.PROC FuncA_Actor_IsCollidingWithOtherActor
    jsr FuncA_Actor_SetPointToOtherActorCenter  ; preserves X, Y, and T0+
    sty T2  ; other actor index
    lda Ram_ActorType_eActor_arr, y
    sta T1  ; other actor type
    tay  ; other actor type
_CheckHorz:
    lda DataA_Actor_BoundingBoxSide_u8_arr, y  ; other actor bounding box side
    ldy Ram_ActorType_eActor_arr, x            ; this actor type
    add DataA_Actor_BoundingBoxSide_u8_arr, y  ; this actor bounding box side
    jsr Func_IsActorWithinHorzDistanceOfPoint  ; preserves X, T1+; returns C
    bcc _Finish  ; no collision
_CheckVert:
    ldy T1  ; other actor type
    lda DataA_Actor_BoundingBoxUp_u8_arr, y    ; other actor bounding box up
    ldy Ram_ActorType_eActor_arr, x            ; this actor type
    add DataA_Actor_BoundingBoxDown_u8_arr, y  ; this actor bounding box down
    pha  ; distance above other actor
    ldy T1  ; other actor type
    lda DataA_Actor_BoundingBoxDown_u8_arr, y  ; other actor bounding box down
    ldy Ram_ActorType_eActor_arr, x            ; this actor type
    add DataA_Actor_BoundingBoxDown_u8_arr, y  ; this actor bounding box up
    tay  ; param: distance below other actor
    pla  ; param: distance above other actor
    jsr Func_IsActorWithinVertDistancesOfPoint  ; preserves X, T1+; returns C
_Finish:
    ldy T2  ; other actor index (to preserve Y)
    rts
.ENDPROC

;;; Stores another actor's room pixel position in Zp_Point*_i16.
;;; @param Y The other actor index.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Actor_SetPointToOtherActorCenter
.PROC FuncA_Actor_SetPointToOtherActorCenter
    lda Ram_ActorPosX_i16_0_arr, y
    sta Zp_PointX_i16 + 0
    lda Ram_ActorPosX_i16_1_arr, y
    sta Zp_PointX_i16 + 1
    lda Ram_ActorPosY_i16_0_arr, y
    sta Zp_PointY_i16 + 0
    lda Ram_ActorPosY_i16_1_arr, y
    sta Zp_PointY_i16 + 1
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
    pha  ; initialization parameter
    ldy Ram_ActorType_eActor_arr, x  ; param: actor type
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    pla  ; param: initialization parameter
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE kFirstNonStaticActorType
    d_entry table, eActor::None,            Func_InitActorDefault
    d_entry table, eActor::BadBat,          Func_InitActorWithState1
    d_entry table, eActor::BadBeetleHorz,   Func_InitActorWithFlags
    d_entry table, eActor::BadBeetleVert,   Func_InitActorWithFlags
    d_entry table, eActor::BadBird,         FuncA_Room_InitActorBadBird
    d_entry table, eActor::BadCrab,         Func_InitActorDefault
    d_entry table, eActor::BadFirefly,      FuncA_Room_InitActorBadFirefly
    d_entry table, eActor::BadFish,         Func_InitActorWithFlags
    d_entry table, eActor::BadFlower,       Func_InitActorDefault
    d_entry table, eActor::BadFlydrop,      FuncA_Room_InitActorBadFlydrop
    d_entry table, eActor::BadGhostMermaid, Func_InitActorWithState1
    d_entry table, eActor::BadGhostOrc,     Func_InitActorWithState1
    d_entry table, eActor::BadGooGreen,     Func_InitActorWithFlags
    d_entry table, eActor::BadGooRed,       FuncA_Room_InitActorBadGooRed
    d_entry table, eActor::BadGronta,       Func_InitActorBadGronta
    d_entry table, eActor::BadGrub,         Func_InitActorWithFlags
    d_entry table, eActor::BadGrubFire,     Func_InitActorWithFlags
    d_entry table, eActor::BadHotheadHorz,  Func_InitActorWithFlags
    d_entry table, eActor::BadHotheadVert,  Func_InitActorWithFlags
    d_entry table, eActor::BadJelly,        Func_InitActorWithState1
    d_entry table, eActor::BadLavaball,     FuncA_Room_InitActorBadLavaball
    d_entry table, eActor::BadOrc,          Func_InitActorBadOrc
    d_entry table, eActor::BadRhino,        Func_InitActorWithFlags
    d_entry table, eActor::BadRodent,       Func_InitActorDefault
    d_entry table, eActor::BadSlime,        Func_InitActorWithFlags
    d_entry table, eActor::BadSolifuge,     Func_InitActorBadSolifuge
    d_entry table, eActor::BadSpider,       Func_InitActorDefault
    d_entry table, eActor::BadToad,         FuncA_Room_InitActorBadToad
    d_entry table, eActor::BadVinebug,      Func_InitActorDefault
    d_entry table, eActor::BadWasp,         FuncA_Room_InitActorBadWasp
    d_entry table, eActor::NpcAdult,        Func_InitActorWithState1
    d_entry table, eActor::NpcBlinky,       Func_InitActorWithState1
    d_entry table, eActor::NpcChild,        FuncA_Room_InitActorNpcChild
    d_entry table, eActor::NpcDuck,         Func_InitActorWithFlags
    d_entry table, eActor::NpcOrc,          Func_InitActorNpcOrc
    d_entry table, eActor::NpcOrcSleeping,  Func_InitActorDefault
    d_entry table, eActor::NpcQueen,        Func_InitActorDefault
    d_entry table, eActor::NpcSquare,       Func_InitActorDefault
    d_entry table, eActor::NpcToddler,      FuncA_Room_InitActorNpcToddler
    D_END
.ENDREPEAT
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
    ldy Ram_ActorType_eActor_arr, x
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eActor
    d_entry table, None,            Func_Noop
    d_entry table, BadBat,          FuncA_Objects_DrawActorBadBat
    d_entry table, BadBeetleHorz,   FuncA_Objects_DrawActorBadBeetleHorz
    d_entry table, BadBeetleVert,   FuncA_Objects_DrawActorBadBeetleVert
    d_entry table, BadBird,         FuncA_Objects_DrawActorBadBird
    d_entry table, BadCrab,         FuncA_Objects_DrawActorBadCrab
    d_entry table, BadFirefly,      FuncA_Objects_DrawActorBadFirefly
    d_entry table, BadFish,         FuncA_Objects_DrawActorBadFish
    d_entry table, BadFlower,       FuncA_Objects_DrawActorBadFlower
    d_entry table, BadFlydrop,      FuncA_Objects_DrawActorBadFlydrop
    d_entry table, BadGhostMermaid, FuncA_Objects_DrawActorBadGhostMermaid
    d_entry table, BadGhostOrc,     FuncA_Objects_DrawActorBadGhostOrc
    d_entry table, BadGooGreen,     FuncA_Objects_DrawActorBadGooGreen
    d_entry table, BadGooRed,       FuncA_Objects_DrawActorBadGooRed
    d_entry table, BadGronta,       FuncA_Objects_DrawActorBadGronta
    d_entry table, BadGrub,         FuncA_Objects_DrawActorBadGrub
    d_entry table, BadGrubFire,     FuncA_Objects_DrawActorBadGrubFire
    d_entry table, BadHotheadHorz,  FuncA_Objects_DrawActorBadHotheadHorz
    d_entry table, BadHotheadVert,  FuncA_Objects_DrawActorBadHotheadVert
    d_entry table, BadJelly,        FuncA_Objects_DrawActorBadJelly
    d_entry table, BadLavaball,     FuncA_Objects_DrawActorBadLavaball
    d_entry table, BadOrc,          FuncA_Objects_DrawActorBadOrc
    d_entry table, BadRhino,        FuncA_Objects_DrawActorBadRhino
    d_entry table, BadRodent,       FuncA_Objects_DrawActorBadRodent
    d_entry table, BadSlime,        FuncA_Objects_DrawActorBadSlime
    d_entry table, BadSolifuge,     FuncA_Objects_DrawActorBadSolifuge
    d_entry table, BadSpider,       FuncA_Objects_DrawActorBadSpider
    d_entry table, BadToad,         FuncA_Objects_DrawActorBadToad
    d_entry table, BadVinebug,      FuncA_Objects_DrawActorBadVinebug
    d_entry table, BadWasp,         FuncA_Objects_DrawActorBadWasp
    d_entry table, NpcAdult,        FuncA_Objects_DrawActorNpcAdult
    d_entry table, NpcBlinky,       FuncA_Objects_DrawActorNpcBlinky
    d_entry table, NpcChild,        FuncA_Objects_DrawActorNpcChild
    d_entry table, NpcDuck,         FuncA_Objects_DrawActorNpcDuck
    d_entry table, NpcOrc,          FuncA_Objects_DrawActorNpcOrc
    d_entry table, NpcOrcSleeping,  FuncA_Objects_DrawActorNpcOrcSleeping
    d_entry table, NpcQueen,        FuncA_Objects_DrawActorNpcQueen
    d_entry table, NpcSquare,       FuncA_Objects_DrawActorNpcSquare
    d_entry table, NpcToddler,      FuncA_Objects_DrawActorNpcToddler
    d_entry table, ProjAcid,        FuncA_Objects_DrawActorProjAcid
    d_entry table, ProjAxeBoomer,   FuncA_Objects_DrawActorProjAxe
    d_entry table, ProjAxeSmash,    FuncA_Objects_DrawActorProjAxe
    d_entry table, ProjBreakball,   FuncA_Objects_DrawActorProjBreakball
    d_entry table, ProjBreakbomb,   FuncA_Objects_DrawActorProjBreakbomb
    d_entry table, ProjBreakfire,   FuncA_Objects_DrawActorProjBreakfire
    d_entry table, ProjBullet,      FuncA_Objects_DrawActorProjBullet
    d_entry table, ProjEgg,         FuncA_Objects_DrawActorProjEgg
    d_entry table, ProjEmber,       FuncA_Objects_DrawActorProjEmber
    d_entry table, ProjFireball,    FuncA_Objects_DrawActorProjFireball
    d_entry table, ProjFireblast,   FuncA_Objects_DrawActorProjFireblast
    d_entry table, ProjFlamestrike, FuncA_Objects_DrawActorProjFlamestrike
    d_entry table, ProjFood,        FuncA_Objects_DrawActorProjFood
    d_entry table, ProjGrenade,     FuncA_Objects_DrawActorProjGrenade
    d_entry table, ProjRocket,      FuncA_Objects_DrawActorProjRocket
    d_entry table, ProjSpike,       FuncA_Objects_DrawActorProjSpike
    d_entry table, ProjSpine,       FuncA_Objects_DrawActorProjSpine
    d_entry table, ProjSteamHorz,   FuncA_Objects_DrawActorProjSteamHorz
    d_entry table, ProjSteamUp,     FuncA_Objects_DrawActorProjSteamUp
    d_entry table, SmokeAxe,        FuncA_Objects_DrawActorProjAxe
    d_entry table, SmokeBeam,       FuncA_Objects_DrawActorSmokeBeam
    d_entry table, SmokeBlood,      FuncA_Objects_DrawActorSmokeBlood
    d_entry table, SmokeDirt,       FuncA_Objects_DrawActorSmokeDirt
    d_entry table, SmokeExplosion,  FuncA_Objects_DrawActorSmokeExplosion
    d_entry table, SmokeFragment,   FuncA_Objects_DrawActorSmokeFragment
    d_entry table, SmokeParticle,   FuncA_Objects_DrawActorSmokeParticle
    d_entry table, SmokeRaindrop,   FuncA_Objects_DrawActorSmokeRaindrop
    d_entry table, SmokeSteamHorz,  FuncA_Objects_DrawActorSmokeSteamHorz
    d_entry table, SmokeSteamUp,    FuncA_Objects_DrawActorSmokeSteamUp
    d_entry table, SmokeWaterfall,  FuncA_Objects_DrawActorSmokeWaterfall
    D_END
.ENDREPEAT
.ENDPROC

;;;=========================================================================;;;
