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

.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "boiler.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjSteamHorz
.IMPORT Func_InitActorProjSteamUp
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformRight_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr

;;;=========================================================================;;;

;;; The OBJ palette number used for steam pipe valves.
kValvePalette = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Given an 8x8 pixel platform covering the end tile of a leftward-facing
;;; pipe, spawns a leftward steam actor emitting from that pipe.
;;; @param Y The platform index for the pipe.
.EXPORT FuncA_Machine_EmitSteamLeftFromPipe
.PROC FuncA_Machine_EmitSteamLeftFromPipe
    ;; Set X to the actor index for the steam.
    jsr Func_FindEmptyActorSlot  ; preserves Y, returns C and X
    bcs @done
    ;; Calculate the steam's X-position.
    lda Ram_PlatformLeft_i16_0_arr, y
    sub #kTileWidthPx
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_PlatformLeft_i16_1_arr, y
    sbc #0
    sta Ram_ActorPosX_i16_1_arr, x
    ;; Calculate the steam's Y-position.
    lda Ram_PlatformTop_i16_0_arr, y
    add #kTileHeightPx / 2
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_PlatformTop_i16_1_arr, y
    adc #0
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Spawn the steam.
    lda #bObj::FlipH  ; param: facing dir
    jmp Func_InitActorProjSteamHorz
    @done:
    rts
.ENDPROC

;;; Given an 8x8 pixel platform covering the end tile of a rightward-facing
;;; pipe, spawns a rightward steam actor emitting from that pipe.
;;; @param Y The platform index for the pipe.
.EXPORT FuncA_Machine_EmitSteamRightFromPipe
.PROC FuncA_Machine_EmitSteamRightFromPipe
    ;; Set X to the actor index for the steam.
    jsr Func_FindEmptyActorSlot  ; preserves Y, returns C and X
    bcs @done
    ;; Calculate the steam's X-position.
    lda Ram_PlatformRight_i16_0_arr, y
    add #kTileWidthPx
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_PlatformRight_i16_1_arr, y
    adc #0
    sta Ram_ActorPosX_i16_1_arr, x
    ;; Calculate the steam's Y-position.
    lda Ram_PlatformTop_i16_0_arr, y
    add #kTileHeightPx / 2
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_PlatformTop_i16_1_arr, y
    adc #0
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Spawn the steam.
    lda #0  ; param: facing dir
    jmp Func_InitActorProjSteamHorz
    @done:
    rts
.ENDPROC

;;; Given an 8x8 pixel platform covering the end tile of an upward-facing pipe,
;;; spawns an upward steam actor emitting from that pipe.
;;; @param Y The platform index for the pipe.
.EXPORT FuncA_Machine_EmitSteamUpFromPipe
.PROC FuncA_Machine_EmitSteamUpFromPipe
    ;; Set X to the actor index for the steam.
    jsr Func_FindEmptyActorSlot  ; preserves Y, returns C and X
    bcs @done
    ;; Calculate the steam's X-position.
    lda Ram_PlatformLeft_i16_0_arr, y
    add #kTileWidthPx / 2
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_PlatformLeft_i16_1_arr, y
    adc #0
    sta Ram_ActorPosX_i16_1_arr, x
    ;; Calculate the steam's Y-position.
    lda Ram_PlatformTop_i16_0_arr, y
    sub #kTileHeightPx
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_PlatformTop_i16_1_arr, y
    sbc #0
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Spawn the steam.
    jmp Func_InitActorProjSteamUp
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a valve for a boiler machine.  The valve platform should be 8x8
;;; pixels and centered on the center of the valve.
;;; @param A The valve angle (0-9).
;;; @param X The platform index for the valve.
.EXPORT FuncA_Objects_DrawBoilerValve
.PROC FuncA_Objects_DrawBoilerValve
    pha  ; valve angle (0-9)
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    pla  ; valve angle (0-9)
    bcs @done
    tax  ; valve angle (0-9)
    lda _Tile_u8_arr10, x
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda _Flags_bObj_arr10, x
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @done:
    rts
_Tile_u8_arr10:
:   .byte kTileIdValveFirst + 0
    .byte kTileIdValveFirst + 1
    .byte kTileIdValveFirst + 2
    .byte kTileIdValveFirst + 3
    .byte kTileIdValveFirst + 2
    .byte kTileIdValveFirst + 1
    .byte kTileIdValveFirst + 0
    .byte kTileIdValveFirst + 1
    .byte kTileIdValveFirst + 2
    .byte kTileIdValveFirst + 3
    .assert * - :- = 10, error
_Flags_bObj_arr10:
:   .byte kValvePalette
    .byte kValvePalette
    .byte kValvePalette
    .byte kValvePalette
    .byte kValvePalette | bObj::FlipV
    .byte kValvePalette | bObj::FlipV
    .byte kValvePalette
    .byte kValvePalette
    .byte kValvePalette
    .byte kValvePalette
    .assert * - :- = 10, error
.ENDPROC

;;;=========================================================================;;;
