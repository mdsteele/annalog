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

.IMPORT DataA_Pause_CryptAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_CryptAreaName_u8_arr
.IMPORT DataA_Room_Crypt_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GetWinchHorzSpeed
.IMPORT FuncA_Machine_GetWinchVertSpeed
.IMPORT FuncA_Machine_IsWinchFallingFast
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Machine_WinchHitBreakableFloor
.IMPORT FuncA_Machine_WinchReachedGoal
.IMPORT FuncA_Machine_WinchStartFalling
.IMPORT FuncA_Objects_DrawWinchBreakableFloor
.IMPORT FuncA_Objects_DrawWinchChain
.IMPORT FuncA_Objects_DrawWinchMachine
.IMPORT FuncA_Objects_DrawWinchSpikeball
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToSpikeballCenter
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftToward
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_Noop
.IMPORT Func_ResetWinchMachineParams
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjCrypt
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Ram_RoomState
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_PlatformGoal_i16

;;;=========================================================================;;;

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
    LeverLeft_u1  .byte
    LeverRight_u1 .byte
    ;; Which step of its reset sequence the CryptTombWinch machine is on.
    WinchReset_eResetSeq .byte
    ;; How many more hits each weak floor can take before breaking.
    WeakFloorHp_u8_arr2 .res 2
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_Tomb_sRoom
.PROC DataC_Crypt_Tomb_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 11
    d_byte MinimapStartCol_u8, 0
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCrypt)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Crypt_Tomb_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_CryptAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_CryptAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Crypt_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, FuncC_Crypt_Tomb_InitRoom
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/crypt_tomb.room"
    .assert * - :- = 17 * 16, error
_Machines_sMachine_arr:
:   .assert * - :- = kWinchMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CryptTombWinch
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Winch
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, "L", "R", "X", "Z"
    d_byte MainPlatform_u8, kWinchPlatformIndex
    d_addr Init_func_ptr, FuncC_Crypt_TombWinch_Init
    d_addr ReadReg_func_ptr, FuncC_Crypt_TombWinch_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
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
    d_word Top_i16,   $00de
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 9
    d_byte Target_u8, kWinchMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 5
    d_byte Target_u8, sState::LeverLeft_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 7
    d_byte Target_u8, sState::LeverRight_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::UnlockedDoor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 7
    d_byte Target_u8, eRoom::CryptBoss
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CryptSouth
    d_byte SpawnBlock_u8, 7
    D_END
.ENDPROC

;;; Init function for the CryptTomb room.
.PROC FuncC_Crypt_Tomb_InitRoom
    ;; If the weak floors haven't been broken yet, initialize their HP.
    ;; Otherwise, remove their platforms.
    lda Sram_ProgressFlags_arr + (eFlag::CryptTombWeakFloors >> 3)
    and #1 << (eFlag::CryptTombWeakFloors & $07)
    bne @floorsBroken
    @floorsSolid:
    lda #kNumWinchHitsToBreakFloor
    sta Ram_RoomState + sState::WeakFloorHp_u8_arr2 + 0
    sta Ram_RoomState + sState::WeakFloorHp_u8_arr2 + 1
    rts
    @floorsBroken:
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kWeakFloor0PlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kWeakFloor1PlatformIndex
    rts
.ENDPROC

;;; Draw function for the CryptSouth room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Crypt_Tomb_DrawRoom
    ;; Assert that the weak floor index (0-1) matches each floor's platform
    ;; index.
    .assert kWeakFloor0PlatformIndex = 0, error
    .assert kWeakFloor1PlatformIndex = 1, error
    ldx #1  ; param: platform index
    @loop:
    lda Ram_RoomState + sState::WeakFloorHp_u8_arr2, x  ; param: floor HP
    beq @continue
    jsr FuncA_Objects_DrawWinchBreakableFloor  ; preserves X
    @continue:
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
    lda Ram_RoomState + sState::LeverLeft_u1
    rts
_ReadR:
    lda Ram_RoomState + sState::LeverRight_u1
    rts
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
    ;; the spikeball, storing it in Zp_PlatformGoal_i16.
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    mul #kBlockHeightPx
    add #kSpikeballMinPlatformTop
    .linecont +
    .assert kWinchMaxGoalZ * kBlockHeightPx + \
            kSpikeballMinPlatformTop < $100, error
    .linecont -
    sta Zp_PlatformGoal_i16 + 0
    lda #0
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jsr FuncA_Machine_GetWinchVertSpeed  ; preserves X, returns Z and A
    bne @move
    rts
    @move:
    ;; Move the spikeball vertically, as necessary.
    jsr Func_MovePlatformTopToward  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
    ;; Check if we just hit a breakable floor.
    jsr FuncA_Machine_IsWinchFallingFast  ; sets C if falling fast
    bcc @stopFalling  ; not falling fast enough
    ldy Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex  ; param: goal X
    jsr FuncC_Crypt_GetTombWeakFloorIndex  ; returns C and X
    bcs @stopFalling  ; not over a breakable floor
    lda Ram_RoomState + sState::WeakFloorHp_u8_arr2, x
    beq @stopFalling  ; floor was already broken
    ;; We've hit the breakable floor.
    txa
    pha  ; weak floor/platform index
    tay  ; param: platform index
    jsr FuncA_Machine_WinchHitBreakableFloor
    pla  ; weak floor/platform index
    tax
    dec Ram_RoomState + sState::WeakFloorHp_u8_arr2, x
    bne @stopFalling  ; floor isn't completely broken yet
    ;; The floor is now completely broken.
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr, x
    lda Ram_RoomState + sState::WeakFloorHp_u8_arr2 + 0
    ora Ram_RoomState + sState::WeakFloorHp_u8_arr2 + 1
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
    ;; room-space pixels, storing it in Zp_PlatformGoal_i16.
    lda Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    mul #kBlockWidthPx
    add #kWinchMinPlatformLeft
    sta Zp_PlatformGoal_i16 + 0
    lda #0
    sta Zp_PlatformGoal_i16 + 1
    ;; Move the winch horizontally, if necessary.
    jsr FuncA_Machine_GetWinchHorzSpeed  ; preserves X, returns A
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftToward  ; preserves X, returns Z and A
    beq @reachedGoal
    ;; If the winch moved, move the spikeball platform too.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @reachedGoal:
_Finished:
    lda Ram_RoomState + sState::WinchReset_eResetSeq
    jeq FuncA_Machine_WinchReachedGoal
    .assert * = FuncC_Crypt_TombWinch_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Crypt_TombWinch_Reset
    jsr Func_ResetWinchMachineParams
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
    sta Ram_RoomState + sState::WinchReset_eResetSeq
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
    sta Ram_RoomState + sState::WinchReset_eResetSeq
    rts
.ENDPROC

;;; Returns the CryptTombWinch machine's goal Z value for resting on the floor
;;; for a given goal X, taking the breakable floors into account.
;;; @param Y The goal X value.
;;; @return A The goal Z for the floor.
.PROC FuncC_Crypt_GetTombFloorZ
    jsr FuncC_Crypt_GetTombWeakFloorIndex  ; preserves Y, returns C and X
    bcs @solidFloor
    lda Ram_RoomState + sState::WeakFloorHp_u8_arr2, x
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
