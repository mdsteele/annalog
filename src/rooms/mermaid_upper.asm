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
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_MermaidAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_MermaidAreaName_u8_arr
.IMPORT DataA_Room_Mermaid_sTileset
.IMPORT FuncA_Objects_DrawGirderPlatform
.IMPORT Func_DivMod
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_Noop
.IMPORT Ppu_ChrUpgrade
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte

;;;=========================================================================;;;

;;; The machine index for the MermaidUpperLift machine in this room.
kLiftMachineIndex = 0

;;; The platform index for the MermaidUpperLift machine.
kLiftPlatformIndex = 0

;;; The initial and maximum permitted values for sState::LiftGoalY_u8.
kLiftInitGoalY = 0
kLiftMaxGoalY = 9

;;; How many pixels the MermaidUpperLift platform moves per tick of its Y
;;; register.
.DEFINE kLiftMoveInterval $30

;;; How many pixels the MermaidUpperLift platform moves per frame.
kLiftMoveSpeed = 3

;;; How many frames the MermaidUpperLift machine spends per move operation.
.ASSERT kLiftMoveInterval .mod kLiftMoveSpeed = 0, error
kLiftMoveCooldown = kLiftMoveInterval / kLiftMoveSpeed

;;; The maximum and initial Y-positions for the top of the lift platform.
kLiftMaxPlatformTop = $0130
kLiftInitPlatformTop = kLiftMaxPlatformTop - kLiftInitGoalY * kLiftMoveInterval

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the (lower) lever.
    LowerLever_u1 .byte
    ;; The goal value for the MermaidUpperLift machine's Y register.
    LiftGoalY_u8  .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Upper_sRoom
.PROC DataC_Mermaid_Upper_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 8
    d_byte MinimapStartCol_u8, 14
    d_byte MinimapWidth_u8, 1
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
    d_addr AreaName_u8_arr_ptr, DataA_Pause_MermaidAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_MermaidAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Mermaid_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/mermaid_upper.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
    .assert kLiftMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MermaidUpperLift
    d_byte Conduit_eFlag, eFlag::ConduitMine
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift  ; TODO
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $90
    d_byte RegNames_u8_arr4, "U", 0, "L", "Y"
    d_addr Init_func_ptr, FuncC_Mermaid_UpperLift_Init
    d_addr ReadReg_func_ptr, FuncC_Mermaid_UpperLift_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, FuncC_Mermaid_UpperLift_TryMove
    d_addr TryAct_func_ptr, Func_MachineError
    d_addr Tick_func_ptr, FuncC_Mermaid_UpperLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_MermaidUpperLift_Draw
    d_addr Reset_func_ptr, FuncC_Mermaid_UpperLift_Reset
    D_END
_Platforms_sPlatform_arr:
    .assert kLiftPlatformIndex = 0, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0080
    d_word Top_i16, kLiftInitPlatformTop
    D_END
    ;; Water:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $120
    d_byte HeightPx_u8,  $40
    d_word Left_i16,   $0000
    d_word Top_i16,    $0144
    D_END
    ;; Sand:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0030
    d_word Top_i16,   $0168
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0090
    d_word Top_i16,   $0168
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00e0
    d_word Top_i16,   $0158
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 16
    d_byte BlockCol_u8, 15
    d_byte Target_u8, kLiftMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 7
    d_byte Target_u8, sState::LowerLever_u1
    D_END
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::MermaidFlower
    d_byte SpawnBlock_u8, 20
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::MermaidEast
    d_byte SpawnBlock_u8, 20
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Top | 0
    d_byte Destination_eRoom, eRoom::MermaidUpper  ; TODO
    d_byte SpawnBlock_u8, 9
    D_END
.ENDPROC

.PROC FuncC_Mermaid_UpperLift_Reset
    .assert * = FuncC_Mermaid_UpperLift_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Mermaid_UpperLift_Init
    lda #kLiftInitGoalY
    sta Ram_RoomState + sState::LiftGoalY_u8
    rts
.ENDPROC

.PROC FuncC_Mermaid_UpperLift_ReadReg
    cmp #$c
    beq _ReadU
    cmp #$e
    beq _ReadL
_ReadY:
    ;; Compute the platform's 16-bit relative position, storing the lo byte in
    ;; Zp_Tmp1_byte and the hi byte in A.
    lda #<(kLiftMaxPlatformTop + kLiftMoveInterval / 2)
    sub Ram_PlatformTop_i16_0_arr + kLiftPlatformIndex
    sta Zp_Tmp1_byte
    lda #>(kLiftMaxPlatformTop + kLiftMoveInterval / 2)
    sbc Ram_PlatformTop_i16_1_arr + kLiftPlatformIndex
    ;; We need to divide the 16-bit relative position by kLiftMoveInterval, but
    ;; it's not a power of two, so we need to use Func_DivMod.  Assert that
    ;; dividing by two will make the relative position fit in 8 bits.
    .assert kLiftMoveInterval * (kLiftMaxGoalY + 1) < $200, error
    .assert kLiftMoveInterval .mod 2 = 0, error
    lsr a
    ror Zp_Tmp1_byte
    lda Zp_Tmp1_byte  ; relative position / 2
    ldy #kLiftMoveInterval / 2  ; param: divisor
    jsr Func_DivMod  ; returns quotient in Y
    tya
    rts
_ReadU:
    lda #0  ; TODO read upper lever (in room above)
    rts
_ReadL:
    lda Ram_RoomState + sState::LowerLever_u1
    rts
.ENDPROC

.PROC FuncC_Mermaid_UpperLift_TryMove
    ldy Ram_RoomState + sState::LiftGoalY_u8
    cpx #eDir::Up
    bne @moveDown
    @moveUp:
    cpy #kLiftMaxGoalY
    bge @error
    iny
    bne @success  ; unconditional
    @moveDown:
    tya
    beq @error
    dey
    @success:
    sty Ram_RoomState + sState::LiftGoalY_u8
    lda #kLiftMoveCooldown
    clc  ; success
    rts
    @error:
    sec  ; failure
    rts
.ENDPROC

.PROC FuncC_Mermaid_UpperLift_Tick
    ;; Calculate the desired Y-position for the top edge of the lift, in
    ;; room-space pixels, storing it in Zp_PlatformGoal_i16.
    .assert kLiftMoveInterval = %110000, error
    lda #0
    sta Zp_Tmp2_byte
    lda Ram_RoomState + sState::LiftGoalY_u8
    .assert kLiftMaxGoalY * %10000 < $100, error
    mul #%10000  ; fits in one byte
    sta Zp_Tmp1_byte
    asl a
    .assert kLiftMaxGoalY * %100000 >= $100, error
    rol Zp_Tmp2_byte
    adc Zp_Tmp1_byte  ; carry is already cleared
    sta Zp_Tmp1_byte
    lda Zp_Tmp2_byte
    adc #0
    sta Zp_Tmp2_byte
    lda #<kLiftMaxPlatformTop
    sub Zp_Tmp1_byte
    sta Zp_PlatformGoal_i16 + 0
    lda #>kLiftMaxPlatformTop
    sbc Zp_Tmp2_byte
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine the vertical speed of the lift (faster if resetting).
    lda #kLiftMoveSpeed
    ldy Ram_MachineStatus_eMachine_arr + kLiftMachineIndex
    cpy #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the lift vertically, as necessary.
    ldx #kLiftPlatformIndex  ; param: platform index
    jsr Func_MovePlatformTopToward  ; returns Z and A
    beq @done
    ;; TODO: If moving down, check if the actor got crushed.
    rts
    @done:
    jmp Func_MachineFinishResetting
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the MermaidUpperLift machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.PROC FuncA_Objects_MermaidUpperLift_Draw
    ldx #kLiftPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawGirderPlatform  ; TODO
.ENDPROC

;;;=========================================================================;;;
