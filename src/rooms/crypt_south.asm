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
.IMPORT FuncA_Objects_DrawWinchCrusher
.IMPORT FuncA_Objects_DrawWinchMachine
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftToward
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Func_ResetWinchMachineParams
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjCrypt
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Ram_RoomState
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarPlatformIndex_u8
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The machine index for the CryptSouthWinch machine in this room.
kWinchMachineIndex = 0

;;; The platform indices for the CryptSouthWinch machine, the crusher that
;;; hangs from its chain, and the breakable floor.
kWinchPlatformIndex        = 0
kCrusherUpperPlatformIndex = 1
kCrusherSpikePlatformIndex = 2
kWeakFloorPlatformIndex    = 3

;;; The initial and maximum permitted values for the winch's X-goal.
kWinchInitGoalX = 0
kWinchMaxGoalX  = 9
;;; The initial and maximum permitted values for the winch's Z-goal.
kWinchInitGoalZ = 5
kWinchMaxGoalZ  = 17

;;; The winch X and Z-register values at which the crusher is resting on the
;;; breakable floor.
kWeakFloorGoalX = 8
kWeakFloorGoalZ = 5

;;; The minimum and initial room pixel position for the left edge of the winch.
.LINECONT +
kWinchMinPlatformLeft = $40
kWinchInitPlatformLeft = \
    kWinchMinPlatformLeft + kBlockWidthPx * kWinchInitGoalX
.LINECONT +

;;; The minimum and initial room pixel position for the top edge of the
;;; crusher.
.LINECONT +
kCrusherMinPlatformTop = $40
kCrusherInitPlatformTop = \
    kCrusherMinPlatformTop + kBlockHeightPx * kWinchInitGoalZ
.LINECONT +

;;;=========================================================================;;;

;;; Enum for the steps of the CryptSouthWinch machine's reset sequence (listed
;;; in reverse order).
.ENUM eResetSeq
    Down = 0  ; last step: move down to initial position
    UpLeft    ; move up (if necessary), then move left
.ENDENUM

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; Which step of its reset sequence the CryptSouthWinch machine is on.
    WinchReset_eResetSeq .byte
    ;; How many more hits the weak floor can take before breaking.
    WeakFloorHp_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_South_sRoom
.PROC DataC_Crypt_South_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 10
    d_byte MinimapStartCol_u8, 1
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCrypt)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Crypt_South_DrawRoom
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
    d_addr Init_func_ptr, FuncC_Crypt_South_InitRoom
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/crypt_south.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kWinchMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CryptSouthWinch
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Winch
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, 0, "W", "X", "Z"
    d_byte MainPlatform_u8, kWinchPlatformIndex
    d_addr Init_func_ptr, FuncC_Crypt_SouthWinch_Init
    d_addr ReadReg_func_ptr, FuncC_Crypt_SouthWinch_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Crypt_SouthWinch_TryMove
    d_addr TryAct_func_ptr, FuncC_Crypt_SouthWinch_TryAct
    d_addr Tick_func_ptr, FuncC_Crypt_SouthWinch_Tick
    d_addr Draw_func_ptr, FuncA_Objects_CryptSouthWinch_Draw
    d_addr Reset_func_ptr, FuncC_Crypt_SouthWinch_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kWinchPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16, kWinchInitPlatformLeft
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kCrusherUpperPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16, kWinchInitPlatformLeft
    d_word Top_i16, kCrusherInitPlatformTop
    D_END
    .assert * - :- = kCrusherSpikePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $0e
    d_byte HeightPx_u8, $06
    d_word Left_i16, kWinchInitPlatformLeft + 1
    d_word Top_i16, kCrusherInitPlatformTop + kTileHeightPx
    D_END
    .assert * - :- = kWeakFloorPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00c0
    d_word Top_i16,   $00a0
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0040
    d_word Top_i16,   $00ae
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00e0
    d_word Top_i16,   $009e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $c0
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0030
    d_word Top_i16,   $015e
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 9
    d_byte Target_u8, kWinchMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 9
    d_byte Target_u8, kWinchMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::CryptWest
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CryptSouth  ; TODO
    d_byte SpawnBlock_u8, 3
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::CryptTomb
    d_byte SpawnBlock_u8, 19
    D_END
.ENDPROC

;;; Init function for the CryptSouth room.
.PROC FuncC_Crypt_South_InitRoom
    ;; If the weak floor hasn't been broken yet, initialize its HP.  Otherwise,
    ;; remove its platform.
    lda Sram_ProgressFlags_arr + (eFlag::CryptSouthWeakFloor >> 3)
    and #1 << (eFlag::CryptSouthWeakFloor & $07)
    bne @floorBroken
    @floorSolid:
    lda #kNumWinchHitsToBreakFloor
    sta Ram_RoomState + sState::WeakFloorHp_u8
    rts
    @floorBroken:
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kWeakFloorPlatformIndex
    rts
.ENDPROC

;;; Draw function for the CryptSouth room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Crypt_South_DrawRoom
    lda Ram_RoomState + sState::WeakFloorHp_u8  ; param: floor HP
    beq @done
    ldx #kWeakFloorPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawWinchBreakableFloor
    @done:
    rts
.ENDPROC

.PROC FuncC_Crypt_SouthWinch_ReadReg
    cmp #$f
    beq _ReadZ
    cmp #$e
    beq _ReadX
_ReadW:
    lda #1
    ldx Zp_AvatarPlatformIndex_u8
    cpx #kCrusherUpperPlatformIndex
    beq @done
    lda #0
    @done:
    rts
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kWinchPlatformIndex
    sub #kWinchMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
_ReadZ:
    lda Ram_PlatformTop_i16_0_arr + kCrusherUpperPlatformIndex
    sub #kCrusherMinPlatformTop - kTileHeightPx
    sta Zp_Tmp1_byte
    lda Ram_PlatformTop_i16_1_arr + kCrusherUpperPlatformIndex
    sbc #0
    .assert kBlockHeightPx = 16, error
    .repeat 4
    lsr a
    ror Zp_Tmp1_byte
    .endrepeat
    lda Zp_Tmp1_byte
    cmp #9
    blt @done
    lda #9
    @done:
    rts
.ENDPROC

.PROC FuncC_Crypt_SouthWinch_TryMove
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
    jsr FuncC_Crypt_GetSouthFloorZ  ; returns A
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
    jsr FuncC_Crypt_GetSouthFloorZ  ; returns A
    cmp Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    beq _Error
    inc Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_Error:
    jmp FuncA_Machine_Error
.ENDPROC

;;; @prereq PRGA_Machine is loaded.
.PROC FuncC_Crypt_SouthWinch_TryAct
    ldy Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex  ; param: goal X
    jsr FuncC_Crypt_GetSouthFloorZ  ; returns A (param: new Z-goal)
    jmp FuncA_Machine_WinchStartFalling
.ENDPROC

;;; @prereq PRGA_Machine is loaded.
.PROC FuncC_Crypt_SouthWinch_Tick
_MoveVert:
    ;; Calculate the desired room-space pixel Y-position for the top edge of
    ;; the crusher, storing it in Zp_PlatformGoal_i16.
    lda #0
    sta Zp_PlatformGoal_i16 + 1
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    mul #16
    .assert kWinchMaxGoalZ >= 16, error  ; The multiplication may carry.
    .assert kWinchMaxGoalZ < 32, error  ; There can only be one carry bit.
    rol Zp_PlatformGoal_i16 + 1  ; Handle carry bit from multiplication.
    add #kCrusherMinPlatformTop
    sta Zp_PlatformGoal_i16 + 0
    lda Zp_PlatformGoal_i16 + 1
    adc #0
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx #kCrusherUpperPlatformIndex  ; param: platform index
    jsr FuncA_Machine_GetWinchVertSpeed  ; preserves X, returns Z and A
    bne @move
    rts
    @move:
    ;; Move the crusher vertically, as necessary.
    jsr Func_MovePlatformTopToward  ; returns Z and A
    beq @reachedGoal
    ;; If the crusher moved, move the crusher's other platform too.
    ldx #kCrusherSpikePlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
    @reachedGoal:
    ;; Check if we just hit the breakable floor.
    jsr FuncA_Machine_IsWinchFallingFast  ; sets C if falling fast
    bcc @stopFalling
    lda Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    cmp #kWeakFloorGoalX
    bne @stopFalling  ; not over the breakable floor
    lda Ram_RoomState + sState::WeakFloorHp_u8
    beq @stopFalling  ; floor was already broken
    ;; We've hit the breakable floor.
    ldy #kWeakFloorPlatformIndex  ; param: platform index
    jsr FuncA_Machine_WinchHitBreakableFloor
    dec Ram_RoomState + sState::WeakFloorHp_u8
    bne @stopFalling  ; floor isn't completely broken yet
    ;; The floor is now completely broken.
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kWeakFloorPlatformIndex
    ldx #eFlag::CryptSouthWeakFloor
    jsr Func_SetFlag
    ;; Keep falling past where the breakable floor was.
    ldy #kWeakFloorGoalX  ; param: goal X
    jsr FuncC_Crypt_GetSouthFloorZ  ; returns A
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    rts
    @stopFalling:
_MoveHorz:
    ;; Calculate the desired X-position for the left edge of the winch, in
    ;; room-space pixels, storing it in Zp_PlatformGoal_i16.
    lda #0
    sta Zp_PlatformGoal_i16 + 1
    lda Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    mul #kBlockWidthPx
    add #kWinchMinPlatformLeft
    sta Zp_PlatformGoal_i16 + 0
    ;; Move the winch horizontally, if necessary.
    jsr FuncA_Machine_GetWinchHorzSpeed  ; returns A
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftToward  ; returns Z and A
    beq @reachedGoal
    ;; If the winch moved, move the crusher platforms too.
    pha  ; move delta
    ldx #kCrusherUpperPlatformIndex  ; param: platform index
    jsr Func_MovePlatformHorz
    pla  ; param: move delta
    ldx #kCrusherSpikePlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @reachedGoal:
_Finished:
    lda Ram_RoomState + sState::WinchReset_eResetSeq
    jeq FuncA_Machine_WinchReachedGoal
    .assert * = FuncC_Crypt_SouthWinch_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Crypt_SouthWinch_Reset
    ;; TODO: heal breakable floor if not totally broken
    lda Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    .assert kWinchInitGoalX = 0, error
    beq FuncC_Crypt_SouthWinch_Init
    lda #kWinchInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    cmp #3
    blt @left
    @up:
    lda #2
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    @left:
    lda #eResetSeq::UpLeft
    sta Ram_RoomState + sState::WinchReset_eResetSeq
    jmp Func_ResetWinchMachineParams
.ENDPROC

.PROC FuncC_Crypt_SouthWinch_Init
    lda #kWinchInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    lda #kWinchInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    lda #0
    sta Ram_RoomState + sState::WinchReset_eResetSeq
    rts
.ENDPROC

;;; Returns the CryptSouthWinch machine's goal Z value for resting on the floor
;;; for a given goal X, taking the breakable floor into account.
;;; @param Y The goal X value.
;;; @return A The goal Z for the floor.
.PROC FuncC_Crypt_GetSouthFloorZ
    cpy #kWeakFloorGoalX
    bne @solidFloor
    lda Ram_RoomState + sState::WeakFloorHp_u8
    beq @solidFloor
    lda #kWeakFloorGoalZ
    rts
    @solidFloor:
    lda _SolidFloor_u8_arr, y
    rts
_SolidFloor_u8_arr:
    .byte 6, 2, 6, 4, 6, 3, 6, 5, 17, 3
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws the CryptSouthWinch machine.
.PROC FuncA_Objects_CryptSouthWinch_Draw
    ;; Draw winch:
    lda Ram_PlatformTop_i16_0_arr + kCrusherUpperPlatformIndex  ; param: chain
    jsr FuncA_Objects_DrawWinchMachine
    ;; Draw crusher:
    ldx #kCrusherUpperPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawWinchCrusher
    ;; Draw chain:
    jsr FuncA_Objects_MoveShapeUpOneTile
    jsr FuncA_Objects_MoveShapeLeftHalfTile
    ldx #kWinchPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawWinchChain
.ENDPROC

;;;=========================================================================;;;
