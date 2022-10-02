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
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_MineAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_MineAreaName_u8_arr
.IMPORT DataA_Room_Mine_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_DrawCraneMachine
.IMPORT FuncA_Objects_DrawTrolleyMachine
.IMPORT FuncA_Objects_DrawTrolleyRopeToCrane
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftToward
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjMine
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_PlatformGoal_i16

;;;=========================================================================;;;

;;; The machine indices for the MineCollapseTrolley and MineCollapseCrane
;;; machines in this room.
kCraneMachineIndex   = 0
kTrolleyMachineIndex = 1

;;; The platform indices for the MineCollapseTrolley and MineCollapseCrane
;;; machines in this room.
kCranePlatformIndex   = 0
kTrolleyPlatformIndex = 1

;;; How many frames each machine spends per move/act operation.
kCraneActCooldown = 8

;;; The initial and maximum permitted values for the crane's Z-goal.
kCraneInitGoalZ = 0
kCraneMaxGoalZ = 8

;;; The initial and maximum permitted values for the trolley's X-goal.
kTrolleyInitGoalX = 0
kTrolleyMaxGoalX  = 7

;;; The minimum, initial, and maximum room pixel position for the top edge of
;;; the crane.
kCraneMinPlatformTop  = $30
kCraneInitPlatformTop = kCraneMinPlatformTop + kBlockHeightPx * kCraneInitGoalZ
kCraneMaxPlatformTop  = kCraneMinPlatformTop + kBlockHeightPx * kCraneMaxGoalZ

;;; The minimum, initial, and maximum room pixel position for the left edge of
;;; the trolley.
.LINECONT +
kTrolleyMinPlatformLeft = $40
kTrolleyInitPlatformLeft = \
    kTrolleyMinPlatformLeft + kBlockWidthPx * kTrolleyInitGoalX
kTrolleyMaxPlatformLeft = \
    kTrolleyMinPlatformLeft + kBlockWidthPx * kTrolleyMaxGoalX
.LINECONT +

;;;=========================================================================;;;

.SEGMENT "PRGC_Mine"

.EXPORT DataC_Mine_Collapse_sRoom
.PROC DataC_Mine_Collapse_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $100
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 19
    d_byte MinimapWidth_u8, 2
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjMine)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_MineAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_MineAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Mine_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/mine_collapse.room"
    .assert * - :- = 33 * 16, error
_Machines_sMachine_arr:
:   .assert * - :- = kCraneMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MineCollapseCrane
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, "D", 0, 0, "Z"
    d_byte MainPlatform_u8, kCranePlatformIndex
    d_addr Init_func_ptr, FuncC_Mine_CollapseCrane_Init
    d_addr ReadReg_func_ptr, FuncC_Mine_CollapseCrane_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_Error
    d_addr TryMove_func_ptr, FuncC_Mine_CollapseCrane_TryMove
    d_addr TryAct_func_ptr, FuncC_Mine_CollapseCrane_TryAct
    d_addr Tick_func_ptr, FuncC_Mine_CollapseCrane_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawCraneMachine
    d_addr Reset_func_ptr, FuncC_Mine_CollapseCrane_Reset
    D_END
    .assert * - :- = kTrolleyMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MineCollapseTrolley
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH
    d_byte Status_eDiagram, eDiagram::Trolley
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, "D", 0, "X", 0
    d_byte MainPlatform_u8, kTrolleyPlatformIndex
    d_addr Init_func_ptr, FuncC_Mine_CollapseTrolley_Init
    d_addr ReadReg_func_ptr, FuncC_Mine_CollapseTrolley_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Mine_CollapseTrolley_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Mine_CollapseTrolley_Tick
    d_addr Draw_func_ptr, FuncA_Objects_MineCollapseTrolley_Draw
    d_addr Reset_func_ptr, FuncC_Mine_CollapseTrolley_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kCranePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16, kTrolleyInitPlatformLeft
    d_word Top_i16, kCraneInitPlatformTop
    D_END
    .assert * - :- = kTrolleyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $0e
    d_word Left_i16, kTrolleyInitPlatformLeft
    d_word Top_i16,   $0020
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 12
    d_byte Target_u8, kTrolleyMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 13
    d_byte Target_u8, kCraneMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::MineCollapse  ; TODO
    d_byte SpawnBlock_u8, 11
    D_END
.ENDPROC

.PROC FuncC_Mine_CollapseTrolley_Reset
    .assert * = FuncC_Mine_CollapseTrolley_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Mine_CollapseTrolley_Init
    lda #kTrolleyInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    rts
.ENDPROC

.PROC FuncC_Mine_CollapseCrane_Reset
    .assert * = FuncC_Mine_CollapseCrane_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Mine_CollapseCrane_Init
    lda #0
    sta Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    .assert kCraneInitGoalZ = 0, error
    sta Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    rts
.ENDPROC

;;; ReadReg implementation for the MineCollapseTrolley machine.
;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.PROC FuncC_Mine_CollapseTrolley_ReadReg
    cmp #$c
    beq FuncC_Mine_Collapse_ReadRegD
_RegX:
    .assert kTrolleyMaxPlatformLeft < $100, error
    lda Ram_PlatformLeft_i16_0_arr + kTrolleyPlatformIndex
    sub #kTrolleyMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
.ENDPROC

;;; ReadReg implementation for the MineCollapseCrane machine.
;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.PROC FuncC_Mine_CollapseCrane_ReadReg
    cmp #$c
    beq FuncC_Mine_Collapse_ReadRegD
_RegZ:
    .assert kCraneMaxPlatformTop < $100, error
    lda Ram_PlatformTop_i16_0_arr + kCranePlatformIndex
    sub #kCraneMinPlatformTop - kTileHeightPx
    div #kBlockHeightPx
    rts
.ENDPROC

;;; Reads the shared "D" register for the MineCollapseTrolley and
;;; MineCollapseCrane machines, which gives the distance (in blocks) from the
;;; bottom of the crane down to the nearest obstacle.
;;; @return A The value of the shared "D" register (0-9).
.PROC FuncC_Mine_Collapse_ReadRegD
    lda #0  ; TODO: implement this
    rts
.ENDPROC

.PROC FuncC_Mine_CollapseTrolley_TryMove
    cpx #eDir::Left
    beq @moveLeft
    @moveRight:
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    cmp #kTrolleyMaxGoalX
    bge @error
    inc Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    bne @success  ; unconditional
    @moveLeft:
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    beq @error
    dec Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    @success:
    jmp FuncA_Machine_StartWorking
    @error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncC_Mine_CollapseCrane_TryMove
    .assert eDir::Up = 0, error
    txa
    beq @moveUp
    @moveDown:
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    cmp #kCraneMaxGoalZ
    bge @error
    inc Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    bne @success  ; unconditional
    @moveUp:
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    beq @error
    dec Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    @success:
    jmp FuncA_Machine_StartWorking
    @error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncC_Mine_CollapseCrane_TryAct
    lda Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex
    eor #$ff
    sta Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex
    lda #kCraneActCooldown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

.PROC FuncC_Mine_CollapseTrolley_Tick
    ;; Calculate the desired X-position for the left edge of the trolley, in
    ;; room-space pixels, storing it in Zp_PlatformGoal_i16.
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    .assert kTrolleyMaxGoalX * kBlockWidthPx < $100, error
    mul #kBlockWidthPx  ; fits in one byte
    add #<kTrolleyMinPlatformLeft
    sta Zp_PlatformGoal_i16 + 0
    lda #0
    adc #>kTrolleyMinPlatformLeft
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine the horizontal speed of the trolley (faster if resetting).
    lda #1
    ldy Ram_MachineStatus_eMachine_arr + kTrolleyMachineIndex
    cpy #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the trolley horizontally, as necessary.
    ldx #kTrolleyPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftToward  ; returns Z and A
    beq @done
    ;; If the trolley moved, move the crane too.
    ldx #kCranePlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @done:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

.PROC FuncC_Mine_CollapseCrane_Tick
    ;; Calculate the desired Y-position for the top edge of the crane, in
    ;; room-space pixels, storing it in Zp_PlatformGoal_i16.
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    .assert kCraneMaxGoalZ * kBlockHeightPx < $100, error
    mul #kBlockHeightPx  ; fits in one byte
    add #kCraneMinPlatformTop
    sta Zp_PlatformGoal_i16 + 0
    lda #0
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine the vertical speed of the crane (faster if resetting).
    lda #1
    ldy Ram_MachineStatus_eMachine_arr + kCraneMachineIndex
    cpy #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the crane vertically, as necessary.
    ldx #kCranePlatformIndex  ; param: platform index
    jsr Func_MovePlatformTopToward  ; returns Z and A
    beq @done
    rts
    @done:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws the MineCollapseTrolley machine.
.PROC FuncA_Objects_MineCollapseTrolley_Draw
    jsr FuncA_Objects_DrawTrolleyMachine
    ldx #kCranePlatformIndex  ; param: crane platform index
    jmp FuncA_Objects_DrawTrolleyRopeToCrane
.ENDPROC

;;;=========================================================================;;;
