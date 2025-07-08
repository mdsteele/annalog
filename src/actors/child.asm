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
.INCLUDE "../cpu.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "child.inc"

.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetNpcActorFlags
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_InitActorWithState1
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes a child NPC actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The bNpcChild param.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorNpcChild
.PROC FuncA_Room_InitActorNpcChild
    pha  ; bNpcChild bits
    and #bNpcChild::EnumMask  ; param: state byte
    ldy #eActor::NpcChild  ; param: actor type
    jsr Func_InitActorWithState1  ; preserves X
    pla  ; bNpcChild bits
    .assert bNpcChild::Pri = bProc::Negative, error
    bpl @done
    lda #bObj::Pri
    sta Ram_ActorFlags_bObj_arr, x
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a child NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcChild
.PROC FuncA_Objects_DrawActorNpcChild
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    jsr FuncA_Objects_GetNpcActorFlags  ; preserves X, returns A
    .assert kPaletteObjChild <> 0, error
    ora #kPaletteObjChild  ; param: objects flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @done
    lda Ram_ActorState1_byte_arr, x
    stx T0  ; actor index
    tax  ; eNpcChild value
    ;; Special case: for eNpcChild::AlexSwimming1, automatically animate
    ;; between AlexSwimming1 and AlexSwimming2.
    cpx #eNpcChild::AlexSwimming1
    bne @setTiles
    lda Zp_FrameCounter_u8
    adc #6  ; offset so swimming animation isn't synced with player avatar
    and #$10
    bne @setTiles
    .assert eNpcChild::AlexSwimming1 + 1 = eNpcChild::AlexSwimming2, error
    inx  ; now eNpcChild::AlexSwimming2
    @setTiles:
    ;; Set tile IDs for the objects.
    lda _Feet_u8_arr, x
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda _Head_u8_arr, x
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #1  ; carry is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    ldx T0  ; actor index
    @done:
    rts
_Head_u8_arr:
    D_ARRAY .enum, eNpcChild
    d_byte AlexBoosting,  kTileIdObjChildStandFirst + $0e
    d_byte AlexHolding,   kTileIdObjChildStandFirst + $0a
    d_byte AlexKneeling,  kTileIdObjChildStandFirst + $0c
    d_byte AlexLooking,   kTileIdObjChildStandFirst + $08
    d_byte AlexSleeping,  $06
    d_byte AlexStanding,  kTileIdObjChildStandFirst + $06
    d_byte AlexSwimDoor,  kTileIdObjChildSwimFirst  + $00
    d_byte AlexSwimming1, kTileIdObjChildStandFirst + $06
    d_byte AlexSwimming2, kTileIdObjChildSwimFirst  + $02
    d_byte AlexWalking1,  kTileIdObjChildStandFirst + $06
    d_byte AlexWalking2,  kTileIdObjChildStandFirst + $06
    d_byte BrunoStanding, kTileIdObjChildStandFirst + $00
    d_byte BrunoWalking1, kTileIdObjChildStandFirst + $00
    d_byte BrunoWalking2, kTileIdObjChildStandFirst + $00
    d_byte MarieStanding, kTileIdObjChildStandFirst + $02
    d_byte MarieWalking1, kTileIdObjChildStandFirst + $02
    d_byte MarieWalking2, kTileIdObjChildStandFirst + $02
    d_byte NoraStanding,  kTileIdObjChildStandFirst + $04
    D_END
_Feet_u8_arr:
    D_ARRAY .enum, eNpcChild
    d_byte AlexBoosting,  kTileIdObjChildStandFirst + $1e
    d_byte AlexHolding,   kTileIdObjChildStandFirst + $1a
    d_byte AlexKneeling,  kTileIdObjChildStandFirst + $1c
    d_byte AlexLooking,   kTileIdObjChildStandFirst + $10
    d_byte AlexSleeping,  kTileIdObjChildSleepFirst + $00
    d_byte AlexStanding,  kTileIdObjChildStandFirst + $10
    d_byte AlexSwimDoor,  kTileIdObjChildSwimFirst  + $04
    d_byte AlexSwimming1, kTileIdObjChildSwimFirst  + $04
    d_byte AlexSwimming2, kTileIdObjChildSwimFirst  + $06
    d_byte AlexWalking1,  kTileIdObjChildStandFirst + $16
    d_byte AlexWalking2,  kTileIdObjChildStandFirst + $18
    d_byte BrunoStanding, kTileIdObjChildStandFirst + $10
    d_byte BrunoWalking1, kTileIdObjChildStandFirst + $16
    d_byte BrunoWalking2, kTileIdObjChildStandFirst + $18
    d_byte MarieStanding, kTileIdObjChildStandFirst + $12
    d_byte MarieWalking1, kTileIdObjChildStandFirst + $16
    d_byte MarieWalking2, kTileIdObjChildStandFirst + $18
    d_byte NoraStanding,  kTileIdObjChildStandFirst + $14
    D_END
.ENDPROC

;;;=========================================================================;;;
