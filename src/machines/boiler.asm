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

.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjSteamHorz
.IMPORT Func_InitActorProjSteamUp
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState2_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformRight_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

kTileIdObjBoilerLeftCorner  = kTileIdObjMachineCorner
kTileIdObjBoilerCenter      = kTileIdObjBoilerFirst + 0
kTileIdObjBoilerRightCorner = kTileIdObjBoilerFirst + 1

;;; OBJ palette numbers used for boiler machines and valves.
kPaletteObjBoiler = 0
kPaletteObjValve = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

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

.SEGMENT "PRGA_Room"

;;; Reset implemention for boiler machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Room_MachineBoilerReset
.PROC FuncA_Room_MachineBoilerReset
    ldx Zp_MachineIndex_u8
    lda #0
    sta Ram_MachineGoalVert_u8_arr, x
    sta Ram_MachineGoalHorz_u8_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; WriteReg implemention for boiler machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
;;; @param X The register to write to ($c-$f).
.EXPORT FuncA_Machine_BoilerWriteReg
.PROC FuncA_Machine_BoilerWriteReg
    ldy Zp_MachineIndex_u8
    cpx #$0d
    beq @valve2
    @valve1:
    cmp Ram_MachineGoalVert_u8_arr, y
    beq @done
    sta Ram_MachineGoalVert_u8_arr, y
    jmp FuncA_Machine_StartWorking
    @valve2:
    cmp Ram_MachineGoalHorz_u8_arr, y
    beq @done
    sta Ram_MachineGoalHorz_u8_arr, y
    jmp FuncA_Machine_StartWorking
    @done:
    rts
.ENDPROC

;;; Tick implemention for boiler machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.EXPORT FuncA_Machine_BoilerTick
.PROC FuncA_Machine_BoilerTick
    lda #0
    sta T0  ; num valves moved
_Valve1:
    lda Ram_MachineGoalVert_u8_arr, x
    mul #kBoilerValveAnimSlowdown
    cmp Ram_MachineState1_byte_arr, x  ; valve 1 angle
    beq @done
    blt @decrement
    @increment:
    inc Ram_MachineState1_byte_arr, x  ; valve 1 angle
    bne @moved  ; unconditional
    @decrement:
    dec Ram_MachineState1_byte_arr, x  ; valve 1 angle
    @moved:
    inc T0  ; num valves moved
    @done:
_Valve2:
    lda Ram_MachineGoalHorz_u8_arr, x
    mul #kBoilerValveAnimSlowdown
    cmp Ram_MachineState2_byte_arr, x  ; valve 2 angle
    beq @done
    blt @decrement
    @increment:
    inc Ram_MachineState2_byte_arr, x  ; valve 2 angle
    bne @moved  ; unconditional
    @decrement:
    dec Ram_MachineState2_byte_arr, x  ; valve 2 angle
    @moved:
    inc T0  ; num valves moved
    @done:
_Finish:
    lda T0  ; num valves moved
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;; TODO: Nothing uses this yet; should we get rid of it?
;;; Given an 8x8 pixel platform covering the end tile of a leftward-facing
;;; pipe, spawns a leftward steam actor emitting from that pipe.
;;; @param Y The platform index for the pipe.
;;; @preserve T0+
.PROC FuncA_Machine_EmitSteamLeftFromPipe
    ;; Set X to the actor index for the steam.
    jsr Func_FindEmptyActorSlot  ; preserves Y and T0+, returns C and X
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
    jmp Func_InitActorProjSteamHorz  ; preserves T0+
    @done:
    rts
.ENDPROC

;;; Given an 8x8 pixel platform covering the end tile of a rightward-facing
;;; pipe, spawns a rightward steam actor emitting from that pipe.
;;; @param Y The platform index for the pipe.
;;; @preserve T0+
.EXPORT FuncA_Machine_EmitSteamRightFromPipe
.PROC FuncA_Machine_EmitSteamRightFromPipe
    ;; Set X to the actor index for the steam.
    jsr Func_FindEmptyActorSlot  ; preserves Y and T0+, returns C and X
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
    jmp Func_InitActorProjSteamHorz  ; preserves T0+
    @done:
    rts
.ENDPROC

;;; Given an 8x8 pixel platform covering the end tile of an upward-facing pipe,
;;; spawns an upward steam actor emitting from that pipe.
;;; @param Y The platform index for the pipe.
;;; @preserve T0+
.EXPORT FuncA_Machine_EmitSteamUpFromPipe
.PROC FuncA_Machine_EmitSteamUpFromPipe
    ;; Set X to the actor index for the steam.
    jsr Func_FindEmptyActorSlot  ; preserves Y and T0+, returns C and X
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
    jmp Func_InitActorProjSteamUp  ; preserves T0+
    @done:
    rts
.ENDPROC

;;; Called at the end of a boiler machine's TryAct function after it has
;;; successfully emitted steam from one or more pipes.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_BoilerFinishEmittingSteam
.PROC FuncA_Machine_BoilerFinishEmittingSteam
    ;; TODO play a sound
    lda #kBoilerActCountdown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a boiler machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawBoilerMachine
.PROC FuncA_Objects_DrawBoilerMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_Light:
    jsr FuncA_Objects_GetMachineLightTileId  ; returns A (param: tile ID)
    ldy #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
_Corner:
    jsr FuncA_Objects_MoveShapeDownOneTile
    ldy #bObj::FlipH | kPaletteObjBoiler  ; param: object flags
    lda #kTileIdObjBoilerLeftCorner  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape
_Tank:
    lda #kTileWidthPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #kPaletteObjBoiler  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; returns C and Y
    bcs @done
    lda #kTileIdObjBoilerCenter
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjBoilerRightCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda #bObj::FlipV | kPaletteObjBoiler
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
    lda Ram_MachineState2_byte_arr, y  ; valve 2 angle
    div #kBoilerValveAnimSlowdown  ; param: valve angle
    bpl FuncA_Objects_DrawBoilerValve  ; unconditional
.ENDPROC

;;; Draws the first valve for a boiler machine.  The valve platform should be
;;; 8x8 pixels and centered on the center of the valve.
;;; @param X The platform index for the valve.
.EXPORT FuncA_Objects_DrawBoilerValve1
.PROC FuncA_Objects_DrawBoilerValve1
    ldy Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, y  ; valve 1 angle
    div #kBoilerValveAnimSlowdown  ; param: valve angle
    .assert * = FuncA_Objects_DrawBoilerValve, error, "fallthrough"
.ENDPROC

;;; Draws a valve for a boiler machine.  The valve platform should be 8x8
;;; pixels and centered on the center of the valve.
;;; @param A The valve angle (0-9).
;;; @param X The platform index for the valve.
.PROC FuncA_Objects_DrawBoilerValve
    pha  ; valve angle
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    pla  ; valve angle
    tax  ; valve angle
    ldy _Flags_bObj_arr10, x  ; param: object flags
    lda _Tile_u8_arr10, x  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
_Tile_u8_arr10:
:   .byte kTileIdObjValveFirst + 0
    .byte kTileIdObjValveFirst + 1
    .byte kTileIdObjValveFirst + 2
    .byte kTileIdObjValveFirst + 3
    .byte kTileIdObjValveFirst + 2
    .byte kTileIdObjValveFirst + 1
    .byte kTileIdObjValveFirst + 0
    .byte kTileIdObjValveFirst + 1
    .byte kTileIdObjValveFirst + 2
    .byte kTileIdObjValveFirst + 3
    .assert * - :- = 10, error
_Flags_bObj_arr10:
:   .byte kPaletteObjValve
    .byte kPaletteObjValve
    .byte kPaletteObjValve
    .byte kPaletteObjValve
    .byte kPaletteObjValve | bObj::FlipV
    .byte kPaletteObjValve | bObj::FlipV
    .byte kPaletteObjValve
    .byte kPaletteObjValve
    .byte kPaletteObjValve
    .byte kPaletteObjValve
    .assert * - :- = 10, error
.ENDPROC

;;;=========================================================================;;;
