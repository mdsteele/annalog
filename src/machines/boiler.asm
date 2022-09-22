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

.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "boiler.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjSteamHorz
.IMPORT Func_InitActorProjSteamUp
.IMPORT Func_MachineFinishResetting
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineParam1_u8_arr
.IMPORT Ram_MachineParam2_i16_0_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformRight_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

kTileIdBoilerLeftCorner  = kTileIdMachineCorner
kTileIdBoilerCenter      = kTileIdBoilerFirst + 0
kTileIdBoilerRightCorner = kTileIdBoilerFirst + 1

;;; OBJ palette numbers used for boiler machines and valves.
kBoilerPalette = 0
kValvePalette = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Reset implemention for boiler machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT Func_MachineBoilerReset
.PROC Func_MachineBoilerReset
    ldx Zp_MachineIndex_u8
    lda #0
    sta Ram_MachineGoalVert_u8_arr, x
    sta Ram_MachineGoalHorz_u8_arr, x
    rts
.ENDPROC

;;; ReadReg implemention for boiler machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.EXPORT Func_MachineBoilerReadReg
.PROC Func_MachineBoilerReadReg
    ldx Zp_MachineIndex_u8
    cmp #$0d
    beq @valve2
    @valve1:
    lda Ram_MachineGoalVert_u8_arr, x
    rts
    @valve2:
    lda Ram_MachineGoalHorz_u8_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; WriteReg implemention for boiler machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The register to write to ($c-$f).
;;; @param X The value to write (0-9).
;;; @return A How many frames to wait before advancing the PC.
.EXPORT FuncA_Machine_BoilerWriteReg
.PROC FuncA_Machine_BoilerWriteReg
    ldy Zp_MachineIndex_u8
    cmp #$0d
    beq @valve2
    @valve1:
    txa
    sta Ram_MachineGoalVert_u8_arr, y
    lda #kBoilerWriteCountdown
    rts
    @valve2:
    txa
    sta Ram_MachineGoalHorz_u8_arr, y
    lda #kBoilerWriteCountdown
    rts
.ENDPROC

;;; Tick implemention for boiler machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_BoilerTick
.PROC FuncA_Machine_BoilerTick
    lda #0
    sta Zp_Tmp1_byte  ; num valves moved
    ldx Zp_MachineIndex_u8
_Valve1:
    lda Ram_MachineGoalVert_u8_arr, x
    mul #kBoilerValveAnimSlowdown
    cmp Ram_MachineParam1_u8_arr, x
    beq @done
    blt @decrement
    @increment:
    inc Ram_MachineParam1_u8_arr, x
    bne @moved  ; unconditional
    @decrement:
    dec Ram_MachineParam1_u8_arr, x
    @moved:
    inc Zp_Tmp1_byte  ; num valves moved
    @done:
_Valve2:
    lda Ram_MachineGoalHorz_u8_arr, x
    mul #kBoilerValveAnimSlowdown
    cmp Ram_MachineParam2_i16_0_arr, x
    beq @done
    blt @decrement
    @increment:
    inc Ram_MachineParam2_i16_0_arr, x
    bne @moved  ; unconditional
    @decrement:
    dec Ram_MachineParam2_i16_0_arr, x
    @moved:
    inc Zp_Tmp1_byte  ; num valves moved
    @done:
_Finish:
    lda Zp_Tmp1_byte  ; num valves moved
    jeq Func_MachineFinishResetting
    rts
.ENDPROC

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

;;; Draws a boiler machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawBoilerMachine
.PROC FuncA_Objects_DrawBoilerMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_Light:
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    bcs @done
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kMachineLightPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @done:
_Corner:
    jsr FuncA_Objects_MoveShapeDownOneTile
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    bcs @done
    lda #kTileIdBoilerLeftCorner
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #bObj::FlipH | kBoilerPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @done:
_Tank:
    jsr FuncA_Objects_MoveShapeRightOneTile
    jsr FuncA_Objects_MoveShapeRightOneTile
    lda #kBoilerPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; returns C and Y
    bcs @done
    lda #kTileIdBoilerCenter
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdBoilerRightCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda #bObj::FlipV | kBoilerPalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;; Draws the second valve for a boiler machine.  The valve platform should be
;;; 8x8 pixels and centered on the center of the valve.
;;; @param X The platform index for the valve.
.EXPORT FuncA_Objects_DrawBoilerValve2
.PROC FuncA_Objects_DrawBoilerValve2
    ldy Zp_MachineIndex_u8
    lda Ram_MachineParam2_i16_0_arr, y
    div #kBoilerValveAnimSlowdown  ; param: valve angle
    bpl FuncA_Objects_DrawBoilerValve  ; unconditional
.ENDPROC

;;; Draws the first valve for a boiler machine.  The valve platform should be
;;; 8x8 pixels and centered on the center of the valve.
;;; @param X The platform index for the valve.
.EXPORT FuncA_Objects_DrawBoilerValve1
.PROC FuncA_Objects_DrawBoilerValve1
    ldy Zp_MachineIndex_u8
    lda Ram_MachineParam1_u8_arr, y
    div #kBoilerValveAnimSlowdown  ; param: valve angle
    .assert * = FuncA_Objects_DrawBoilerValve, error, "fallthrough"
.ENDPROC

;;; Draws a valve for a boiler machine.  The valve platform should be 8x8
;;; pixels and centered on the center of the valve.
;;; @param A The valve angle (0-9).
;;; @param X The platform index for the valve.
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