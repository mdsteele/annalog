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
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_PrisonAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_PrisonAreaName_u8_arr
.IMPORT DataA_Room_Prison_sTileset
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Ppu_ChrUpgrade
.IMPORT Ram_RoomState

;;;=========================================================================;;;

;;; The machine indices for the machines in this room.
kBarrierMachineIndex = 0
kBlasterMachineIndex = 1

;;; The platform index for the PrisonCellBarrier machine in this room.
kBarrierPlatformIndex = 0

;;; The initial and max values for sState::BarrierRegY_u8.
kBarrierInitRegY = 1
kBarrierMaxRegY = 1

;;; How fast the PrisonCellBarrier platform moves, in pixels per frame.
kBarrierSpeed = 1

;;; How many frames the PrisonCellBarrier machine spends per move operation.
kBarrierCountdown = $10

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current value of the PrisonCellBarrier machine's Y register.
    BarrierRegY_u8      .byte
    ;; The goal value of the PrisonCellBarrier machine's Y register; it will
    ;; keep moving until this is reached.
    BarrierGoalY_u8     .byte
    ;; Nonzero if the PrisonCellBarrier machine is moving; this is how many
    ;; more frames until it finishes the current move operation.
    BarrierCountdown_u8 .byte
    ;; If BarrierCountdown_u8 is nonzero, this is the direction the machine is
    ;; currently moving.
    BarrierMove_eDir    .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

.EXPORT DataC_Prison_Cell_sRoom
.PROC DataC_Prison_Cell_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $110
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 2
    d_byte MinimapStartCol_u8, 5
    d_byte MinimapWidth_u8, 2
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrUpgrade)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_PrisonAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_PrisonAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Prison_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, DataA_Dialog_PrisonCell_sDialog_ptr_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/prison_cell.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
    .assert kBarrierMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::PrisonCellBarrier
    d_byte Conduit_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_addr Init_func_ptr, _Barrier_Init
    d_addr ReadReg_func_ptr, _Barrier_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, _Barrier_TryMove
    d_addr TryAct_func_ptr, Func_MachineError
    d_addr Tick_func_ptr, _Barrier_Tick
    d_addr Draw_func_ptr, FuncA_Objects_PrisonCellBarrier_Draw
    d_addr Reset_func_ptr, _Barrier_Reset
    D_END
    .assert kBlasterMachineIndex = 1, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::PrisonCellBlaster
    d_byte Conduit_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $110
    d_byte ScrollGoalY_u8, $50
    d_byte RegNames_u8_arr4, 0, 0, "X", 0
    d_addr Init_func_ptr, _Blaster_Init
    d_addr ReadReg_func_ptr, _Blaster_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, _Blaster_TryMove
    d_addr TryAct_func_ptr, _Blaster_TryAct
    d_addr Tick_func_ptr, _Blaster_Tick
    d_addr Draw_func_ptr, FuncA_Objects_PrisonCellBlaster_Draw
    d_addr Reset_func_ptr, _Blaster_Reset
    D_END
_Platforms_sPlatform_arr:
    .assert kBarrierPlatformIndex = 0, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_byte WidthPx_u8,  $10
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0020
    d_word Top_i16,   $0080
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 9
    d_byte Target_u8, 0
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 3
    d_byte Target_u8, kBarrierMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 15
    d_byte BlockCol_u8, 31
    d_byte Target_u8, kBlasterMachineIndex
    D_END
    .byte eDevice::None
_Passages_sPassage_arr:
    ;; TODO: Currently, a room cannot have two passages lead to the same room.
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::PrisonEscape
    d_byte SpawnBlock_u8, 9
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::PrisonEscape
    d_byte SpawnBlock_u8, 20
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::PrisonCell  ; TODO
    d_byte SpawnBlock_u8, 11
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 1
    d_byte Destination_eRoom, eRoom::GardenLanding
    d_byte SpawnBlock_u8, 25
    D_END
_Barrier_Init:
    lda #kBarrierInitRegY
    sta Ram_RoomState + sState::BarrierRegY_u8
    sta Ram_RoomState + sState::BarrierGoalY_u8
    rts
_Barrier_ReadReg:
    lda Ram_RoomState + sState::BarrierRegY_u8
    rts
_Barrier_TryMove:
    ldy Ram_RoomState + sState::BarrierRegY_u8
    cpx #eDir::Up
    beq @moveUp
    @moveDown:
    cpy #kBarrierMaxRegY
    bge @error
    iny
    bne @success  ; unconditional
    @moveUp:
    tya
    beq @error
    dey
    @success:
    sty Ram_RoomState + sState::BarrierGoalY_u8
    lda #kBarrierCountdown
    clc  ; clear C to indicate success
    rts
    @error:
    sec  ; set C to indicate failure
    rts
_Barrier_Tick:
    lda Ram_RoomState + sState::BarrierCountdown_u8
    bne @continueMove
    ldy Ram_RoomState + sState::BarrierRegY_u8
    cpy Ram_RoomState + sState::BarrierGoalY_u8
    jeq Func_MachineFinishResetting
    bge @beginMoveUp
    @beginMoveDown:
    ldx #eDir::Down
    iny
    bne @beginMove  ; unconditional
    @beginMoveUp:
    ldx #eDir::Up
    dey
    @beginMove:
    sty Ram_RoomState + sState::BarrierRegY_u8
    stx Ram_RoomState + sState::BarrierMove_eDir
    lda #kBarrierCountdown
    sta Ram_RoomState + sState::BarrierCountdown_u8
    @continueMove:
    dec Ram_RoomState + sState::BarrierCountdown_u8
    ldx Ram_RoomState + sState::BarrierMove_eDir
    cpx #eDir::Up
    beq @continueMoveUp
    @continueMoveDown:
    lda #kBarrierSpeed          ; param: move delta
    ldx #kBarrierPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
    @continueMoveUp:
    lda #$ff & -kBarrierSpeed   ; param: move delta
    ldx #kBarrierPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
_Barrier_Reset:
    lda #kBarrierInitRegY
    sta Ram_RoomState + sState::BarrierGoalY_u8
    ;; TODO: Turn the machine around if it's currently moving up.
    rts
_Blaster_Init:
    ;; TODO
    rts
_Blaster_ReadReg:
    lda #0  ; TODO
    rts
_Blaster_TryMove:
    ;; TODO
    jmp Func_MachineError
_Blaster_TryAct:
    ;; TODO
    jmp Func_MachineError
_Blaster_Tick:
    ;; TODO
    rts
_Blaster_Reset:
    ;; TODO
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the PrisonCell room.
.PROC DataA_Dialog_PrisonCell_sDialog_ptr_arr
    .addr _Dialog0_sDialog
_Dialog0_sDialog:
    .word ePortrait::Sign
    .byte "We were once a great$"
    .byte "civilization. Then one$"
    .byte "day, the orcs came...#"
    .byte 0
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the PrisonCellBarrier machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.PROC FuncA_Objects_PrisonCellBarrier_Draw
    ldx #kBarrierPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawLiftMachine
.ENDPROC

.PROC FuncA_Objects_PrisonCellBlaster_Draw
    ;; TODO
    rts
.ENDPROC

;;;=========================================================================;;;
