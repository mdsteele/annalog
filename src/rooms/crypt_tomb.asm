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
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/winch.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"

.IMPORT DataA_Room_Crypt_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GetWinchHorzSpeed
.IMPORT FuncA_Machine_GetWinchVertSpeed
.IMPORT FuncA_Machine_IsWinchFallingFast
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Machine_WinchHitBreakableFloor
.IMPORT FuncA_Machine_WinchReachedGoal
.IMPORT FuncA_Machine_WinchStartFalling
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_DrawWinchBreakableFloor
.IMPORT FuncA_Objects_DrawWinchChain
.IMPORT FuncA_Objects_DrawWinchMachine
.IMPORT FuncA_Objects_DrawWinchSpikeball
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToSpikeballCenter
.IMPORT FuncA_Room_ResetLever
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeFracture
.IMPORT Func_ResetWinchMachineState
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjCrypt
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The device indices for the levers in this room.
kLeverLeftDeviceIndex = 1
kLeverRightDeviceIndex = 2
;;; The device index for the door that leads to the boss room.
kDoorDeviceIndex = 3

;;; The machine index for the CryptTombWinch machine in this room.
kWinchMachineIndex = 0

;;; The platform indices for the CryptTombWinch machine, the crusher that
;;; hangs from its chain, and the breakable floor.
kWeakFloor0PlatformIndex = 0
kWeakFloor1PlatformIndex = 1
kWinchPlatformIndex      = 2
kSpikeballPlatformIndex  = 3

;;; The initial and maximum permitted values for the winch's X-goal.
kWinchInitGoalX = 4
kWinchMaxGoalX  = 9
;;; The initial and maximum permitted values for the winch's Z-goal.
kWinchInitGoalZ = 2
kWinchMaxGoalZ = 9

;;; The winch X and Z-register values at which the spikeball is resting on each
;;; of the breakable floors.
kWeakFloor0GoalX = 0
kWeakFloor0GoalZ = 7
kWeakFloor1GoalX = 9
kWeakFloor1GoalZ = 5

;;; The minimum and initial room pixel position for the left edge of the winch.
.LINECONT +
kWinchMinPlatformLeft = $30
kWinchInitPlatformLeft = \
    kWinchMinPlatformLeft + kBlockWidthPx * kWinchInitGoalX
.LINECONT +

;;; The minimum and initial room pixel position for the top edge of the
;;; spikeball.
.LINECONT +
kSpikeballMinPlatformTop = $22
kSpikeballInitPlatformTop = \
    kSpikeballMinPlatformTop + kBlockHeightPx * kWinchInitGoalZ
.LINECONT +

;;;=========================================================================;;;

;;; Enum for the steps of the CryptTombWinch machine's reset sequence (listed
;;; in reverse order).
.ENUM eResetSeq
    Middle = 0  ; last step: move to mid-center position
    TopCenter   ; move up to top, then move horizontally to center
.ENDENUM

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u8  .byte
    LeverRight_u8 .byte
    ;; Which step of its reset sequence the CryptTombWinch machine is on.
    WinchReset_eResetSeq .byte
    ;; How many more hits each weak floor can take before breaking.
    WeakFloorHp_u8_arr2 .res 2
    ;; How many more frames to blink the weak floors for.
    WeakFloorBlink_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_Tomb_sRoom
.PROC DataC_Crypt_Tomb_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte Flags_bRoom, bRoom::Tall | eArea::Crypt
    d_byte MinimapStartRow_u8, 12
    d_byte MinimapStartCol_u8, 0
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCrypt)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Crypt_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_CryptTomb_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_CryptTomb_TickRoom
    d_addr Draw_func_ptr, FuncC_Crypt_Tomb_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/data/crypt_tomb.room"
    .assert * - :- = 17 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kWinchMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CryptTombWinch
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveHV | bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::Winch
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, "L", "R", "X", "Z"
    d_byte MainPlatform_u8, kWinchPlatformIndex
    d_addr Init_func_ptr, FuncC_Crypt_TombWinch_Init
    d_addr ReadReg_func_ptr, FuncC_Crypt_TombWinch_ReadReg
    d_addr WriteReg_func_ptr, FuncC_Crypt_TombWinch_WriteReg
    d_addr TryMove_func_ptr, FuncC_Crypt_TombWinch_TryMove
    d_addr TryAct_func_ptr, FuncC_Crypt_TombWinch_TryAct
    d_addr Tick_func_ptr, FuncC_Crypt_TombWinch_Tick
    d_addr Draw_func_ptr, FuncA_Objects_CryptTombWinch_Draw
    d_addr Reset_func_ptr, FuncC_Crypt_TombWinch_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kWeakFloor0PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0030
    d_word Top_i16,   $00a0
    D_END
    .assert * - :- = kWeakFloor1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00c0
    d_word Top_i16,   $0080
    D_END
    .assert * - :- = kWinchPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16, kWinchInitPlatformLeft
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kSpikeballPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $0d
    d_byte HeightPx_u8, $0e
    d_word Left_i16, kWinchInitPlatformLeft + 2
    d_word Top_i16, kSpikeballInitPlatformTop
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0010
    d_word Top_i16,   $00ae
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00d0
    d_word Top_i16,   $00ae
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $50
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16,   $016e
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   ;; TODO: add some baddies?
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 9
    d_byte Target_byte, kWinchMachineIndex
    D_END
    .assert * - :- = kLeverLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 5
    d_byte Target_byte, sState::LeverLeft_u8
    D_END
    .assert * - :- = kLeverRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 7
    d_byte Target_byte, sState::LeverRight_u8
    D_END
    .assert * - :- = kDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eRoom::BossCrypt
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 16
    d_byte BlockCol_u8, 11
    d_byte Target_byte, kWinchMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eDialog::CryptTombPlaque
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CryptSouth
    d_byte SpawnBlock_u8, 7
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; Draw function for the CryptTomb room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Crypt_Tomb_DrawRoom
    ;; Assert that the weak floor index (0-1) matches each floor's platform
    ;; index.
    .assert kWeakFloor0PlatformIndex = 0, error
    .assert kWeakFloor1PlatformIndex = 1, error
    ldx #1  ; param: platform index
    @loop:
    ldy Zp_RoomState + sState::WeakFloorHp_u8_arr2, x  ; param: floor HP
    lda Zp_RoomState + sState::WeakFloorBlink_u8  ; param: blink timer
    jsr FuncA_Objects_DrawWinchBreakableFloor  ; preserves X
    dex
    bpl @loop
    rts
.ENDPROC

.PROC FuncC_Crypt_TombWinch_ReadReg
    cmp #$c
    beq _ReadL
    cmp #$d
    beq _ReadR
    cmp #$e
    beq _ReadX
_ReadZ:
    lda Ram_PlatformTop_i16_0_arr + kSpikeballPlatformIndex
    sub #kSpikeballMinPlatformTop - kTileHeightPx
    div #kBlockHeightPx
    rts
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kWinchPlatformIndex
    sub #kWinchMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
_ReadL:
    lda Zp_RoomState + sState::LeverLeft_u8
    rts
_ReadR:
    lda Zp_RoomState + sState::LeverRight_u8
    rts
.ENDPROC

.PROC FuncC_Crypt_TombWinch_WriteReg
    cpx #$d
    beq _WriteR
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncC_Crypt_TombWinch_TryMove
    ldy Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    .assert eDir::Up = 0, error
    txa
    beq _MoveUp
    cpx #eDir::Down
    beq _MoveDown
_MoveHorz:
    cpx #eDir::Left
    beq @moveLeft
    @moveRight:
    cpy #kWinchMaxGoalX
    bge _Error
    iny
    bne @checkFloor  ; unconditional
    @moveLeft:
    tya
    beq _Error
    dey
    @checkFloor:
    jsr FuncC_Crypt_GetTombFloorZ  ; returns A
    cmp Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    blt _Error
    sty Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_MoveUp:
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    beq _Error
    dec Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_MoveDown:
    jsr FuncC_Crypt_GetTombFloorZ  ; returns A
    cmp Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    beq _Error
    inc Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_Error:
    jmp FuncA_Machine_Error
.ENDPROC

;;; @prereq PRGA_Machine is loaded.
.PROC FuncC_Crypt_TombWinch_TryAct
    ldy Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex  ; param: goal X
    jsr FuncC_Crypt_GetTombFloorZ  ; returns A (param: new Z-goal)
    jmp FuncA_Machine_WinchStartFalling
.ENDPROC

;;; @prereq PRGA_Machine is loaded.
.PROC FuncC_Crypt_TombWinch_Tick
_MoveVert:
    ;; Calculate the desired room-space pixel Y-position for the top edge of
    ;; the spikeball, storing it in Zp_PointY_i16.
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    mul #kBlockHeightPx
    add #kSpikeballMinPlatformTop
    .linecont +
    .assert kWinchMaxGoalZ * kBlockHeightPx + \
            kSpikeballMinPlatformTop < $100, error
    .linecont -
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jsr FuncA_Machine_GetWinchVertSpeed  ; preserves X, returns Z and A
    bne @move
    rts
    @move:
    ;; Move the spikeball vertically, as necessary.
    jsr Func_MovePlatformTopTowardPointY  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
    ;; Check if we just hit a breakable floor.
    jsr FuncA_Machine_IsWinchFallingFast  ; sets C if falling fast
    bcc @stopFalling  ; not falling fast enough
    ldy Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex  ; param: goal X
    jsr FuncC_Crypt_GetTombWeakFloorIndex  ; returns C and X
    bcs @stopFalling  ; not over a breakable floor
    lda Zp_RoomState + sState::WeakFloorHp_u8_arr2, x
    beq @stopFalling  ; floor was already broken
    ;; We've hit the breakable floor.
    txa
    pha  ; weak floor/platform index
    tay  ; param: platform index
    jsr FuncA_Machine_WinchHitBreakableFloor
    pla  ; weak floor/platform index
    tax
    dec Zp_RoomState + sState::WeakFloorHp_u8_arr2, x
    bne @stopFalling  ; floor isn't completely broken yet
    ;; The floor is now completely broken.
    jsr Func_PlaySfxExplodeFracture
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr, x
    lda Zp_RoomState + sState::WeakFloorHp_u8_arr2 + 0
    ora Zp_RoomState + sState::WeakFloorHp_u8_arr2 + 1
    bne @notBothBroken
    ldx #eFlag::CryptTombWeakFloors
    jsr Func_SetFlag
    @notBothBroken:
    ;; Keep falling past where the breakable floor was.
    ldy Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex  ; param: goal X
    jsr FuncC_Crypt_GetTombFloorZ  ; returns A
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    rts
    @stopFalling:
_MoveHorz:
    ;; Calculate the desired X-position for the left edge of the winch, in
    ;; room-space pixels, storing it in Zp_PointX_i16.
    lda Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    mul #kBlockWidthPx
    add #kWinchMinPlatformLeft
    sta Zp_PointX_i16 + 0
    lda #0
    sta Zp_PointX_i16 + 1
    ;; Move the winch horizontally, if necessary.
    jsr FuncA_Machine_GetWinchHorzSpeed  ; returns A
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftTowardPointX  ; returns Z and A
    beq @reachedGoal
    ;; If the winch moved, move the spikeball platform too.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @reachedGoal:
_Finished:
    lda Zp_RoomState + sState::WinchReset_eResetSeq
    bne FuncC_Crypt_TombWinch_ContinueResetting
    jmp FuncA_Machine_WinchReachedGoal
.ENDPROC

.PROC FuncC_Crypt_TombWinch_Reset
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    ldx #kLeverRightDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    .assert * = FuncC_Crypt_TombWinch_ContinueResetting, error, "fallthrough"
.ENDPROC

.PROC FuncC_Crypt_TombWinch_ContinueResetting
_ResetBreakbleFloor:
    lda Zp_RoomState + sState::WeakFloorBlink_u8
    bne @done  ; floors are already blinking
    lda Zp_RoomState + sState::WeakFloorHp_u8_arr2 + 0
    add Zp_RoomState + sState::WeakFloorHp_u8_arr2 + 1
    beq @done  ; both floors are already broken
    cmp #kNumWinchHitsToBreakFloor * 2
    bge @done  ; both floors are undamaged
    lda #kWinchBreakableFloorBlinkFrames
    sta Zp_RoomState + sState::WeakFloorBlink_u8
    @done:
_ResetMachine:
    jsr Func_ResetWinchMachineState
    ;; TODO: heal breakable floors if not both totally broken
    lda Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    cmp #3
    blt _Outer
    cmp #6
    blt _Inner
_Outer:
    lda #kWinchInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    lda #0
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    lda #eResetSeq::TopCenter
    sta Zp_RoomState + sState::WinchReset_eResetSeq
    rts
_Inner:
    .assert * = FuncC_Crypt_TombWinch_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Crypt_TombWinch_Init
    lda #kWinchInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    lda #kWinchInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    lda #0
    sta Zp_RoomState + sState::WinchReset_eResetSeq
    rts
.ENDPROC

;;; Returns the CryptTombWinch machine's goal Z value for resting on the floor
;;; for a given goal X, taking the breakable floors into account.
;;; @param Y The goal X value.
;;; @return A The goal Z for the floor.
.PROC FuncC_Crypt_GetTombFloorZ
    jsr FuncC_Crypt_GetTombWeakFloorIndex  ; preserves Y, returns C and X
    bcs @solidFloor
    lda Zp_RoomState + sState::WeakFloorHp_u8_arr2, x
    beq @solidFloor
    lda _WeakFloorZ_u8_arr2, x
    rts
    @solidFloor:
    lda _SolidFloorZ_u8_arr, y
    rts
_WeakFloorZ_u8_arr2:
    .byte kWeakFloor0GoalZ, kWeakFloor1GoalZ
_SolidFloorZ_u8_arr:
    .byte 9, 0, 0, 5, 5, 5, 0, 5, 5, 7
.ENDPROC

;;; Returns the weak floor index that the CryptTombWinch machine is over, if
;;; any.
;;; @param Y The goal X value.
;;; @return C Cleared if over a weak floor, set otherwise.
;;; @return X The weak floor index (0-1), if over a weak floor.
;;; @preserve Y
.PROC FuncC_Crypt_GetTombWeakFloorIndex
    cpy #kWeakFloor0GoalX
    beq @weakFloor0
    cpy #kWeakFloor1GoalX
    beq @weakFloor1
    @solidFloor:
    sec
    rts
    @weakFloor0:
    ldx #0
    clc
    rts
    @weakFloor1:
    ldx #1
    clc
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Enter function for the CryptTomb room.
;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncA_Room_CryptTomb_EnterRoom
    ;; If the player avatar enters the room from the doorway, remove the
    ;; breakable floors (to ensure they aren't stuck down there).
    cmp #bSpawn::Device | kDoorDeviceIndex
    beq FuncA_Room_CryptTomb_RemoveBreakableFloors
    ;; If the weak floors have already been broken, remove them platforms.
    flag_bit Sram_ProgressFlags_arr, eFlag::CryptTombWeakFloors
    bne FuncA_Room_CryptTomb_RemoveBreakableFloors
    ;; Otherwise, initialize the floors' HP.
    lda #kNumWinchHitsToBreakFloor
    sta Zp_RoomState + sState::WeakFloorHp_u8_arr2 + 0
    sta Zp_RoomState + sState::WeakFloorHp_u8_arr2 + 1
    rts
.ENDPROC

;;; Helper function for this room's Init and Enter functions; removes the two
;;; breakable floors from this room.
.PROC FuncA_Room_CryptTomb_RemoveBreakableFloors
    lda #0
    sta Zp_RoomState + sState::WeakFloorHp_u8_arr2 + 0
    sta Zp_RoomState + sState::WeakFloorHp_u8_arr2 + 1
    .assert ePlatform::None = 0, error
    sta Ram_PlatformType_ePlatform_arr + kWeakFloor0PlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kWeakFloor1PlatformIndex
    rts
.ENDPROC

.PROC FuncA_Room_CryptTomb_TickRoom
    lda Zp_RoomState + sState::WeakFloorBlink_u8
    beq @done
    dec Zp_RoomState + sState::WeakFloorBlink_u8
    bne @done
    lda #kNumWinchHitsToBreakFloor
    sta Zp_RoomState + sState::WeakFloorHp_u8_arr2 + 0
    sta Zp_RoomState + sState::WeakFloorHp_u8_arr2 + 1
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws the CryptTombWinch machine.
.PROC FuncA_Objects_CryptTombWinch_Draw
    lda Ram_PlatformTop_i16_0_arr + kSpikeballPlatformIndex  ; param: chain
    jsr FuncA_Objects_DrawWinchMachine
_Spikeball:
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToSpikeballCenter
    jsr FuncA_Objects_DrawWinchSpikeball
_Chain:
    jsr FuncA_Objects_MoveShapeUpOneTile
    jsr FuncA_Objects_MoveShapeLeftHalfTile
    ldx #kWinchPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawWinchChain
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_CryptTombPlaque_sDialog
.PROC DataA_Dialog_CryptTombPlaque_sDialog
    dlg_Text Plaque, DataA_Text0_CryptTombPlaque_Page1_u8_arr
    dlg_Text Plaque, DataA_Text0_CryptTombPlaque_Page2_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_CryptTombPlaque_Page1_u8_arr
    .byte "Here lies Dr. Zoe Alda$"
    .byte "$"
    .byte "Daughter of humans and$"
    .byte "The mother of mermaids#"
.ENDPROC

.PROC DataA_Text0_CryptTombPlaque_Page2_u8_arr
    .byte "May we ever remember$"
    .byte "    her service,$"
    .byte "  And never repeat$"
    .byte "    her mistakes#"
.ENDPROC

;;;=========================================================================;;;
