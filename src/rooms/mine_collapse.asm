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
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/crane.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Mine_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GetGenericMoveSpeed
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_DrawBoulderPlatform
.IMPORT FuncA_Objects_DrawCraneMachine
.IMPORT FuncA_Objects_DrawCraneRopeToPulley
.IMPORT FuncA_Objects_DrawTrolleyMachine
.IMPORT FuncA_Room_MachineResetRun
.IMPORT FuncA_Room_ResetLever
.IMPORT Func_DistanceSensorDownDetectPoint
.IMPORT Func_DivAByBlockSizeAndClampTo9
.IMPORT Func_IsPointInPlatform
.IMPORT Func_IsPointInPlatformHorz
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePlatformVert
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointUpByA
.IMPORT Func_Noop
.IMPORT Func_PlaySfxThump
.IMPORT Func_SetMachineIndex
.IMPORT Func_SetPointToAvatarTop
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_ShakeRoom
.IMPORT Ppu_ChrObjMine
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The device indices for the levers in this room.
kLeverLeftDeviceIndex = 2
kLeverRightDeviceIndex = 3

;;; The machine indices for the MineCollapseTrolley and MineCollapseCrane
;;; machines in this room.
kTrolleyMachineIndex = 0
kCraneMachineIndex   = 1

;;; The platform indices for the MineCollapseTrolley and MineCollapseCrane
;;; machines in this room.
kTrolleyPlatformIndex = 2
kCranePlatformIndex   = 3

;;; The initial and maximum permitted values for the crane's Z-goal.
kCraneInitGoalZ = 0
kCraneMaxGoalZ  = 4

;;; The initial and maximum permitted values for the trolley's X-goal.
kTrolleyInitGoalX = 4
kTrolleyMaxGoalX  = 5

;;; The minimum, initial, and maximum room pixel position for the top edge of
;;; the crane.
kCraneMinPlatformTop  = $30
kCraneInitPlatformTop = kCraneMinPlatformTop + kBlockHeightPx * kCraneInitGoalZ
kCraneMaxPlatformTop  = kCraneMinPlatformTop + kBlockHeightPx * kCraneMaxGoalZ

;;; The minimum, initial, and maximum room pixel position for the left edge of
;;; the trolley.
.LINECONT +
kTrolleyMinPlatformLeft = $60
kTrolleyInitPlatformLeft = \
    kTrolleyMinPlatformLeft + kBlockWidthPx * kTrolleyInitGoalX
kTrolleyMaxPlatformLeft = \
    kTrolleyMinPlatformLeft + kBlockWidthPx * kTrolleyMaxGoalX
.LINECONT +

;;;=========================================================================;;;

;;; The width and height of each boulder platform.
kBoulderWidthPx  = kBlockWidthPx
kBoulderHeightPx = kBlockHeightPx

;;; States that a boulder in this room can be in.
.ENUM eBoulder
    OnGround    ; sitting on the ground
    Grasped     ; held by the crane
    Falling     ; in free fall
    NUM_VALUES
.ENDENUM

;;; The number of boulder platforms in this room.
.DEFINE kNumBoulders 2

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u8              .byte
    LeverRight_u8             .byte
    ;; What state each boulder is in, indexed by platform index.
    BoulderState_eBoulder_arr .byte kNumBoulders
    ;; The current Y subpixel position of each boulder, indexed by platform
    ;; index.
    BoulderSubY_u8_arr        .byte kNumBoulders
    ;; The current Y-velocity of each boulder, in subpixels per frame, indexed
    ;; by platform index.
    BoulderVelY_i16_0_arr     .byte kNumBoulders
    BoulderVelY_i16_1_arr     .byte kNumBoulders
    ;; The platform index of the boulder current grasped by the crane, or $ff
    ;; if none.
    GraspedBoulderIndex_u8    .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Mine"

.EXPORT DataC_Mine_Collapse_sRoom
.PROC DataC_Mine_Collapse_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, eArea::Mine
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 20
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjMine)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Mine_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Mine_Collapse_TickRoom
    d_addr Draw_func_ptr, FuncC_Mine_Collapse_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/mine_collapse.room"
    .assert * - :- = 18 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kTrolleyMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MineCollapseTrolley
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::Trolley
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, "L", "R", "X", "D"
    d_byte MainPlatform_u8, kTrolleyPlatformIndex
    d_addr Init_func_ptr, FuncC_Mine_CollapseTrolley_Init
    d_addr ReadReg_func_ptr, FuncC_Mine_CollapseTrolley_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_MineCollapse_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_MineCollapseTrolley_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_MineCollapseTrolley_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawTrolleyMachine
    d_addr Reset_func_ptr, FuncC_Mine_CollapseTrolley_Reset
    D_END
    .assert * - :- = kCraneMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MineCollapseCrane
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::Crane
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, "L", "R", "D", "Z"
    d_byte MainPlatform_u8, kCranePlatformIndex
    d_addr Init_func_ptr, FuncC_Mine_CollapseCrane_Init
    d_addr ReadReg_func_ptr, FuncC_Mine_CollapseCrane_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_MineCollapse_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_MineCollapseCrane_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_MineCollapseCrane_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_MineCollapseCrane_Tick
    d_addr Draw_func_ptr, FuncC_Mine_MineCollapseCrane_Draw
    d_addr Reset_func_ptr, FuncC_Mine_CollapseCrane_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   ;; Boulders:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBoulderWidthPx
    d_byte HeightPx_u8, kBoulderHeightPx
    d_word Left_i16, $0070
    d_word Top_i16,  $0080
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBoulderWidthPx
    d_byte HeightPx_u8, kBoulderHeightPx
    d_word Left_i16, $0070
    d_word Top_i16,  $0070
    D_END
    .assert * - :- = kNumBoulders * .sizeof(sPlatform), error
    ;; Machines:
    .assert * - :- = kTrolleyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $0e
    d_word Left_i16, kTrolleyInitPlatformLeft
    d_word Top_i16,   $0020
    D_END
    .assert * - :- = kCranePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16, kTrolleyInitPlatformLeft
    d_word Top_i16, kCraneInitPlatformTop
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 14
    d_byte Target_byte, kTrolleyMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 15
    d_byte Target_byte, kCraneMachineIndex
    D_END
    .assert * - :- = kLeverLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 4
    d_byte Target_byte, sState::LeverLeft_u8
    D_END
    .assert * - :- = kLeverRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 11
    d_byte Target_byte, sState::LeverRight_u8
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::MineBurrow
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::MineNorth
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; Room tick function for the MineCollapse room.
.PROC FuncC_Mine_Collapse_TickRoom
    .assert kNumBoulders = 2, error
    ldx #0  ; param: platform index
    jsr FuncC_Mine_Collapse_TickBoulder
    ldx #1  ; param: platform index
    fall FuncC_Mine_Collapse_TickBoulder
.ENDPROC

;;; Performs per-frame upates for a boulder in this room.
;;; @param X The platform index for the boulder.
.PROC FuncC_Mine_Collapse_TickBoulder
    ;; Branch based on the boulder's current mode.
    ldy Zp_RoomState + sState::BoulderState_eBoulder_arr, x
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
    @done:
    rts
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBoulder
    d_entry table, OnGround,   FuncC_Mine_Collapse_TickBoulderOnGround
    d_entry table, Grasped,    Func_Noop
    d_entry table, Falling,    FuncC_Mine_Collapse_TickBoulderFalling
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs per-frame upates for a boulder when it's on the ground.
;;; @param X The platform index for the boulder.
.PROC FuncC_Mine_Collapse_TickBoulderOnGround
    ;; If the boulder is not aligned to the block grid, slide it into place.
    lda Ram_PlatformLeft_i16_0_arr, x
    .assert kBlockWidthPx = $10, error
    and #$0f
    beq @done
    cmp #$08
    bge @slideRight
    @slideLeft:
    lda #<-1
    bmi @slide  ; unconditional
    @slideRight:
    lda #1
    @slide:
    jsr Func_MovePlatformHorz  ; preserves X
    ;; If the boulder has slid off a cliff and is now above the ground, make
    ;; it start falling.
    jsr FuncC_Mine_Collapse_GetBoulderDistAboveFloor  ; preserves X, returns Z
    beq @done
    lda #eBoulder::Falling
    sta Zp_RoomState + sState::BoulderState_eBoulder_arr, x
    @done:
    rts
.ENDPROC

;;; Performs per-frame upates for a boulder when it's falling.
;;; @param X The platform index for the boulder.
.PROC FuncC_Mine_Collapse_TickBoulderFalling
    jsr FuncC_Mine_Collapse_GetBoulderDistAboveFloor  ; preserves X, returns A
    sta T0  ; boulder dist above floor
    ;; Apply gravity.
    lda Zp_RoomState + sState::BoulderVelY_i16_0_arr, x
    add #<kAvatarGravity
    sta Zp_RoomState + sState::BoulderVelY_i16_0_arr, x
    lda Zp_RoomState + sState::BoulderVelY_i16_1_arr, x
    adc #>kAvatarGravity
    sta Zp_RoomState + sState::BoulderVelY_i16_1_arr, x
    ;; Update subpixels, and calculate the number of whole pixels to move,
    ;; storing the latter in A.
    lda Zp_RoomState + sState::BoulderSubY_u8_arr, x
    add Zp_RoomState + sState::BoulderVelY_i16_0_arr, x
    sta Zp_RoomState + sState::BoulderSubY_u8_arr, x
    lda #0
    adc Zp_RoomState + sState::BoulderVelY_i16_1_arr, x
_CheckForFloorImpact:
    ;; If the number of pixels to move this frame is >= the distance above the
    ;; floor, then the boulder is hitting the floor this frame.
    cmp T0  ; boulder dist above floor
    blt _MoveBoulderDownByA  ; not hitting the floor
    lda #eBoulder::OnGround
    sta Zp_RoomState + sState::BoulderState_eBoulder_arr, x
    ldy Zp_RoomState + sState::BoulderVelY_i16_1_arr, x
    lda _ShakeFrames_u8_arr, y  ; param: num frames
    beq @noShake
    jsr Func_ShakeRoom  ; preserves X, T0+
    jsr Func_PlaySfxThump  ; preserves X, T0+
    @noShake:
    ;; Zero the boulder's velocity, and move it to exactly hit the floor.
    lda #0
    sta Zp_RoomState + sState::BoulderSubY_u8_arr, x
    sta Zp_RoomState + sState::BoulderVelY_i16_0_arr, x
    sta Zp_RoomState + sState::BoulderVelY_i16_1_arr, x
    lda T0  ; boulder dist above floor
_MoveBoulderDownByA:
    jmp Func_MovePlatformVert
_ShakeFrames_u8_arr:
    .byte 0, 0, 8, 16, 24, 32, 32, 32
.ENDPROC

;;; Returns the distance between the bottom of the boulder and the floor (or
;;; another boulder).
;;; @param X The platform index for the boulder.
;;; @return A The distance to the floor, in pixels.
;;; @return Z Set if the boulder is exactly on the floor.
;;; @preserve X
.PROC FuncC_Mine_Collapse_GetBoulderDistAboveFloor
    .assert kNumBoulders = 2, error
    txa  ; this boulder's index
    eor #1
    tay  ; other boulder's index
    ;; Check if this boulder is above the other boulder.
    lda Ram_PlatformLeft_i16_0_arr, y
    sub Ram_PlatformLeft_i16_0_arr, x
    cmp #kBoulderWidthPx
    blt @linedUpHorz
    cmp #(<-kBoulderWidthPx) + 1
    blt _NotAboveOtherBoulder
    @linedUpHorz:
    lda Ram_PlatformTop_i16_0_arr, y
    sub Ram_PlatformBottom_i16_0_arr, x
    bge _Return  ; on or above other boulder
_NotAboveOtherBoulder:
    ;; Get distance above terrain floor.
    lda Ram_PlatformLeft_i16_0_arr, x
    cmp #$70
    bge @floorLow
    @floorHigh:
    lda #$60
    bne @setFloorPos  ; unconditional
    @floorLow:
    lda #$90
    @setFloorPos:
    sub Ram_PlatformBottom_i16_0_arr, x
_Return:
    rts
.ENDPROC

;;; Draw function for the MineCollapse room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Mine_Collapse_DrawRoom
    .assert kNumBoulders = 2, error
    ldx #0  ; param: platform index
    jsr FuncA_Objects_DrawBoulderPlatform
    ldx #1  ; param: platform index
    jmp FuncA_Objects_DrawBoulderPlatform
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Mine_CollapseTrolley_Reset
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    ldx #kLeverRightDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    ;; Reset the crane machine (if it's not already resetting).
    lda Ram_MachineStatus_eMachine_arr + kCraneMachineIndex
    cmp #kFirstResetStatus
    bge @alreadyResetting
    ldx #kCraneMachineIndex  ; param: machine index
    jsr Func_SetMachineIndex
    jsr FuncA_Room_MachineResetRun
    ldx #kTrolleyMachineIndex  ; param: machine index
    jsr Func_SetMachineIndex
    @alreadyResetting:
    ;; Now reset the trolley machine itself.
    fall FuncC_Mine_CollapseTrolley_Init
.ENDPROC

.PROC FuncC_Mine_CollapseTrolley_Init
    lda #kTrolleyInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    rts
.ENDPROC

.PROC FuncC_Mine_CollapseCrane_Init
    ldx #$ff
    stx Zp_RoomState + sState::GraspedBoulderIndex_u8
    fall FuncC_Mine_CollapseCrane_Reset
.ENDPROC

.PROC FuncC_Mine_CollapseCrane_Reset
    lda #0
    sta Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    .assert kCraneInitGoalZ = 0, error
    sta Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    fall FuncC_Mine_Collapse_DropBoulder
.ENDPROC

;;; If a boulder is currently grasped by the crane, makes it start falling.
;;; Otherwise, does nothing.
.PROC FuncC_Mine_Collapse_DropBoulder
    ldx Zp_RoomState + sState::GraspedBoulderIndex_u8
    bmi @done
    lda #eBoulder::Falling
    sta Zp_RoomState + sState::BoulderState_eBoulder_arr, x
    ldx #$ff
    stx Zp_RoomState + sState::GraspedBoulderIndex_u8
    @done:
    rts
.ENDPROC

;;; ReadReg implementation for the MineCollapseTrolley machine.
;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.PROC FuncC_Mine_CollapseTrolley_ReadReg
    cmp #$e
    blt FuncC_Mine_Collapse_ReadRegLR
    bne FuncC_Mine_Collapse_ReadRegD
    fall FuncC_Mine_CollapseTrolley_ReadRegX
.ENDPROC

;;; ReadReg implementation for the MineCollapseTrolley machine's "X" register.
;;; @return A The value of the register (0-9).
.PROC FuncC_Mine_CollapseTrolley_ReadRegX
    .assert kTrolleyMaxPlatformLeft < $100, error
    lda Ram_PlatformLeft_i16_0_arr + kTrolleyPlatformIndex
    sub #kTrolleyMinPlatformLeft - kTileWidthPx  ; param: distance
    jmp Func_DivAByBlockSizeAndClampTo9  ; returns A
.ENDPROC

;;; ReadReg implementation for the MineCollapseCrane machine.
;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.PROC FuncC_Mine_CollapseCrane_ReadReg
    cmp #$e
    blt FuncC_Mine_Collapse_ReadRegLR
    beq FuncC_Mine_Collapse_ReadRegD
_RegZ:
    .assert kCraneMaxPlatformTop < $100, error
    lda Ram_PlatformTop_i16_0_arr + kCranePlatformIndex
    sub #kCraneMinPlatformTop - kTileHeightPx  ; param: distance
    jmp Func_DivAByBlockSizeAndClampTo9  ; returns A
.ENDPROC

;;; Reads the shared "L" or "R" lever register for the MineCollapseTrolley and
;;; MineCollapseCrane machines.
;;; @param A The register to read ($c or $d).
;;; @return A The value of the register (0-9).
.PROC FuncC_Mine_Collapse_ReadRegLR
    cmp #$d
    beq _RegR
_RegL:
    lda Zp_RoomState + sState::LeverLeft_u8
    rts
_RegR:
    lda Zp_RoomState + sState::LeverRight_u8
    rts
.ENDPROC

;;; Reads the shared "D" distance sensor register for the MineCollapseTrolley
;;; and MineCollapseCrane machines.
;;; @return A The value of the register (0-9).
.PROC FuncC_Mine_Collapse_ReadRegD
    jsr FuncC_Mine_CollapseTrolley_ReadRegX  ; returns A
    tax  ; crane X position
    lda _FloorPosY_u8_arr6, x
    sub Ram_PlatformBottom_i16_0_arr + kCranePlatformIndex
    sta T0  ; param: minimum distance so far, in pixels
    ;; Detect the boulders.
    .assert kNumBoulders = 2, error
    ldy #0  ; param: boulder platform index
    jsr _DetectBoulder  ; returns T0
    ldy #1  ; param: boulder platform index
    jsr _DetectBoulder  ; returns T0
    ;; Detect the player avatar.
    ldy #kCranePlatformIndex  ; param: distance sensor platform index
    jsr Func_SetPointToAvatarTop  ; preserves Y and T0+
    jsr Func_DistanceSensorDownDetectPoint  ; preserves Y, returns T0
    ;; Compute and return the register value.
    lda T0  ; param: minimum distance so far, in pixels
    jmp Func_DivAByBlockSizeAndClampTo9  ; returns A
_DetectBoulder:
    jsr Func_SetPointToPlatformCenter  ; preserves T0+
    lda #kBoulderHeightPx / 2  ; param: offset
    jsr Func_MovePointUpByA  ; preserves T0+
    ldy #kCranePlatformIndex  ; param: distance sensor platform index
    jmp Func_DistanceSensorDownDetectPoint  ; returns T0
_FloorPosY_u8_arr6:
    .byte $60, $90, $90, $90, $90, $90
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Mine_MineCollapseCrane_Draw
    jsr FuncA_Objects_DrawCraneMachine
    ldx #kTrolleyPlatformIndex  ; param: pulley platform index
    jmp FuncA_Objects_DrawCraneRopeToPulley
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Shared WriteReg implementation for the MineCollapseTrolley and
;;; MineCollapseCrane machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
;;; @param X The register to write to ($c-$f).
.PROC FuncA_Machine_MineCollapse_WriteReg
    cpx #$d
    beq _WriteR
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_MineCollapseTrolley_TryMove
    ldy Ram_PlatformBottom_i16_0_arr + kCranePlatformIndex
    dey
    sty Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    sta Zp_PointX_i16 + 1
    cpx #eDir::Left
    beq _MoveLeft
_MoveRight:
    ;; Check if a boulder is in the way of the crane.
    ldy Ram_PlatformRight_i16_0_arr + kCranePlatformIndex
    sty Zp_PointX_i16 + 0
    jsr _IsAnyBoulderInTheWay  ; returns C
    bcs _Error
    ;; Error if the trolley is already in its rightmost position.
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    cmp #kTrolleyMaxGoalX
    bge _Error
    inc Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    bne _Success  ; unconditional
_MoveLeft:
    ;; Check if a boulder is in the way of the crane.
    ldy Ram_PlatformLeft_i16_0_arr + kCranePlatformIndex
    dey
    sty Zp_PointX_i16 + 0
    jsr _IsAnyBoulderInTheWay  ; returns C
    bcs _Error
    ;; Error if the trolley is already in its leftmost position.
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    beq _Error
    ;; Error if terrain is in the way of the crane.
    cmp #1
    bne @move
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    cmp #2
    bge _Error
    @move:
    dec Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
_Success:
    jmp FuncA_Machine_StartWorking
_Error:
    jmp FuncA_Machine_Error
_IsAnyBoulderInTheWay:
    jsr _IsPointInAnyBoulder  ; returns C
    bcs _Return
    bit Zp_RoomState + sState::GraspedBoulderIndex_u8
    bmi _Return
    lda #kBoulderHeightPx  ; param: offset
    jsr Func_MovePointDownByA
    fall _IsPointInAnyBoulder  ; returns C
_IsPointInAnyBoulder:
    .assert kNumBoulders = 2, error
    ldy #0  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcs _Return
    ldy #1  ; param: platform index
    jmp Func_IsPointInPlatform  ; returns C
_Return:
    rts
.ENDPROC

.PROC FuncA_Machine_MineCollapseCrane_TryMove
    .assert eDir::Up = 0, error
    txa  ; eDir value
    beq _MoveUp
_MoveDown:
    ;; Get the bottom of the crane or grasped boulder.
    lda Ram_PlatformBottom_i16_0_arr + kCranePlatformIndex
    ldx Zp_RoomState + sState::GraspedBoulderIndex_u8
    bmi @setCraneBottom
    lda Ram_PlatformBottom_i16_0_arr, x
    @setCraneBottom:
    sta T1  ; bottom of crane or grasped boulder
    ;; Error if a non-grasped boulder is in the way.
    ldy #kNumBoulders - 1
    @loop:
    cpy Zp_RoomState + sState::GraspedBoulderIndex_u8
    beq @continue  ; this boulder is grasped, so skip it
    sty T0  ; boulder platform index
    jsr Func_SetPointToPlatformCenter  ; preserves T0+
    ldy #kCranePlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatformHorz  ; preserves T0+, returns C
    bcc @restoreY
    lda Zp_PointY_i16 + 0
    sub T1  ; bottom of crane or grasped boulder
    cmp #kBoulderHeightPx / 2
    beq _Error
    @restoreY:
    ldy T0  ; boulder platform index
    @continue:
    dey
    .assert kNumBoulders <= $80, error
    bpl @loop
    ;; Error if the floor is in the way.
    ldx Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    cmp _MaxGoalZ_u8_arr, x
    bge _Error
    inc Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    bne _Success  ; unconditional
_MoveUp:
    ;; Error if the crane is already in its uppermost position.
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    beq _Error
    dec Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
_Success:
    jmp FuncA_Machine_StartWorking
_Error:
    jmp FuncA_Machine_Error
_MaxGoalZ_u8_arr:
:   .byte 1
    .byte kCraneMaxGoalZ
    .byte kCraneMaxGoalZ
    .byte kCraneMaxGoalZ
    .byte kCraneMaxGoalZ
    .byte kCraneMaxGoalZ
    .assert * - :- = kTrolleyMaxGoalX + 1, error
.ENDPROC

;;; @prereq PRGC_Mine is loaded.
.PROC FuncA_Machine_MineCollapseCrane_TryAct
    lda Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    eor #$ff
    sta Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    bpl _LetGo
_TryGrasp:
    ldx #kNumBoulders - 1
    @loop:
    lda Zp_RoomState + sState::BoulderState_eBoulder_arr, x
    .assert eBoulder::OnGround = 0, error
    bne @continue  ; this boulder isn't on the ground
    lda Ram_PlatformLeft_i16_0_arr + kCranePlatformIndex
    cmp Ram_PlatformLeft_i16_0_arr, x
    bne @continue  ; the crane isn't lined up horizontally with this boulder
    lda Ram_PlatformBottom_i16_0_arr + kCranePlatformIndex
    cmp Ram_PlatformTop_i16_0_arr, x
    bne @continue  ; the crane isn't touching the top of the boulder
    stx Zp_RoomState + sState::GraspedBoulderIndex_u8
    lda #eBoulder::Grasped
    sta Zp_RoomState + sState::BoulderState_eBoulder_arr, x
    .assert eBoulder::Grasped <> 0, error
    bne _StartWaiting  ; unconditional
    @continue:
    dex
    .assert kNumBoulders <= $80, error
    bpl @loop
    bmi _StartWaiting  ; unconditional
_LetGo:
    jsr FuncC_Mine_Collapse_DropBoulder
_StartWaiting:
    lda #kCraneActCooldown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

.PROC FuncA_Machine_MineCollapseTrolley_Tick
    ;; If the crane is resetting, wait until it's done.
    lda Ram_MachineStatus_eMachine_arr + kCraneMachineIndex
    cmp #kFirstResetStatus
    blt @craneDoneResetting
    rts
    @craneDoneResetting:
    ;; Calculate the desired X-position for the left edge of the trolley, in
    ;; room-space pixels, storing it in Zp_PointX_i16.
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    .assert kTrolleyMaxGoalX * kBlockWidthPx < $100, error
    mul #kBlockWidthPx  ; fits in one byte
    add #<kTrolleyMinPlatformLeft
    sta Zp_PointX_i16 + 0
    lda #0
    adc #>kTrolleyMinPlatformLeft
    sta Zp_PointX_i16 + 1
    ;; Move the trolley horizontally, as necessary.
    jsr FuncA_Machine_GetGenericMoveSpeed  ; returns A
    ldx #kTrolleyPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftTowardPointX  ; returns Z and A
    beq @done
    ;; If the trolley moved, move the crane too (and the boulder, if it's being
    ;; grasped by the crane).
    ldx Zp_RoomState + sState::GraspedBoulderIndex_u8
    bmi @noBoulder
    pha  ; move delta
    jsr Func_MovePlatformHorz
    pla  ; param: move delta
    @noBoulder:
    ldx #kCranePlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @done:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

.PROC FuncA_Machine_MineCollapseCrane_Tick
    ;; Calculate the desired Y-position for the top edge of the crane, in
    ;; room-space pixels, storing it in Zp_PointY_i16.
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    .assert kCraneMaxGoalZ * kBlockHeightPx < $100, error
    mul #kBlockHeightPx  ; fits in one byte
    add #kCraneMinPlatformTop
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    ;; Move the crane vertically, as necessary.
    jsr FuncA_Machine_GetGenericMoveSpeed  ; returns A
    ldx #kCranePlatformIndex  ; param: platform index
    jsr Func_MovePlatformTopTowardPointY  ; returns Z and A
    beq @reachedGoal
    ;; If the crane moved, move the grasped boulder too (if any).
    ldx Zp_RoomState + sState::GraspedBoulderIndex_u8
    bmi @noBoulder
    jmp Func_MovePlatformVert
    @noBoulder:
    rts
    @reachedGoal:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

;;;=========================================================================;;;
