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
.INCLUDE "../boss.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../irq.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/emitter.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/force.inc"
.INCLUDE "../platforms/lava.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_EmitterTryAct
.IMPORT FuncA_Machine_EmitterXWriteReg
.IMPORT FuncA_Machine_EmitterYWriteReg
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_AnimateLavaTerrain
.IMPORT FuncA_Objects_DrawBoss
.IMPORT FuncA_Objects_DrawEmitterXMachine
.IMPORT FuncA_Objects_DrawEmitterYMachine
.IMPORT FuncA_Objects_DrawForcefieldPlatform
.IMPORT FuncA_Room_InitBoss
.IMPORT FuncA_Room_MachineEmitterXInitReset
.IMPORT FuncA_Room_MachineEmitterYInitReset
.IMPORT FuncA_Room_TickBoss
.IMPORT FuncA_Terrain_FadeInShortRoomWithLava
.IMPORT Func_AckIrqAndLatchWindowFromParam4
.IMPORT Func_MachineEmitterReadReg
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Func_ShakeRoom
.IMPORT Func_WriteToLowerAttributeTable
.IMPORT Ppu_ChrObjBoss1
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The platform index for the BossShadowEmitterX machine.
kEmitterXPlatformIndex = 3
;;; The platform index for the BossShadowEmitterY machine.
kEmitterYPlatformIndex = 4

;;; The initial positions of the emitter beams.
kEmitterXInitRegX = 3
kEmitterYInitRegY = 7

;;; The minimum/maximum room pixel X/Y-positions for the top-left of the
;;; forcefield platform.
kForcefieldMinPlatformLeft = $0030
kForcefieldMinPlatformTop  = $0020

;;;=========================================================================;;;

;;; The platform index for the lava in this room.
kLavaPlatformIndex = 5

;;; The maximum value for sState::LavaOffset_u8, for when the lava is fully
;;; raised.
kMaxLavaOffset = $27

;;; How many frames it takes for the lava to rise/fall by one pixel.
kLavaRiseSlowdown = 6
kLavaFallSlowdown = 4

;;; How many frames to wait between when the lava is fully raised and when it
;;; starts falling.
kLavaWaitFrames = 90

;;;=========================================================================;;;

;;; Modes that the boss in this room can be in.
.ENUM eBossMode
    Dead
    LavaRising
    LavaFalling
    ;; TODO: other modes
    NUM_VALUES
.ENDENUM

;;; How many forcefield hits are needed to defeat the boss.
kBossInitHealth = 8

;;; How many frames the boss waits, after you first enter the room, before
;;; taking action.
kBossInitCooldown = 120

;;; The platform index for the boss's body.
kBossBodyPlatformIndex = 2

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; How far the lava is above its base position, in pixels.
    LavaOffset_u8 .byte
    ;; What mode the boss is in.
    Current_eBossMode .byte
    ;; How many more forcefield hits are needed before the boss dies.
    BossHealth_u8 .byte
    ;; Timer that ticks down each frame when nonzero.  Used to time transitions
    ;; between boss modes.
    BossCooldown_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Boss"

.EXPORT DataC_Boss_Shadow_sRoom
.PROC DataC_Boss_Shadow_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte Flags_bRoom, bRoom::Unsafe | eArea::Shadow
    d_byte MinimapStartRow_u8, 14
    d_byte MinimapStartCol_u8, 9
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss1)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Shadow_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncC_Boss_Shadow_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_BossShadow_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_BossShadow_TickRoom
    d_addr Draw_func_ptr, FuncC_Boss_Shadow_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/boss_shadow.room"
    .assert * - :- = 16 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kEmitterXMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossShadowEmitterX
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteE
    d_byte Status_eDiagram, eDiagram::MinigunDown  ; TODO
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, 0, 0, "X", 0
    d_byte MainPlatform_u8, kEmitterXPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_BossShadowEmitterX_InitReset
    d_addr ReadReg_func_ptr, Func_MachineEmitterReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_EmitterXWriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_EmitterTryAct
    d_addr Tick_func_ptr, FuncA_Machine_ReachedGoal
    d_addr Draw_func_ptr, FuncA_Objects_BossShadowEmitterX_Draw
    d_addr Reset_func_ptr, FuncA_Room_BossShadowEmitterX_InitReset
    D_END
    .assert * - :- = kEmitterYMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossShadowEmitterY
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteF
    d_byte Status_eDiagram, eDiagram::MinigunRight  ; TODO
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kEmitterYPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_BossShadowEmitterY_InitReset
    d_addr ReadReg_func_ptr, Func_MachineEmitterReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_EmitterYWriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_EmitterTryAct
    d_addr Tick_func_ptr, FuncA_Machine_ReachedGoal
    d_addr Draw_func_ptr, FuncA_Objects_BossShadowEmitterY_Draw
    d_addr Reset_func_ptr, FuncA_Room_BossShadowEmitterY_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .linecont +
    .assert * - :- = kEmitterForcefieldPlatformIndex * .sizeof(sPlatform), \
            error
    .linecont -
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kForcefieldPlatformWidth
    d_byte HeightPx_u8, kForcefieldPlatformHeight
    d_word Left_i16, kForcefieldMinPlatformLeft
    d_word Top_i16, kForcefieldMinPlatformTop
    D_END
    .assert * - :- = kEmitterRegionPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $a0
    d_byte HeightPx_u8, $a0
    d_word Left_i16, kForcefieldMinPlatformLeft
    d_word Top_i16, kForcefieldMinPlatformTop
    D_END
    .assert * - :- = kBossBodyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $40  ; TODO
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $0040
    d_word Top_i16,   $0050
    D_END
    .assert * - :- = kEmitterXPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00c8
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kEmitterYPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0018
    d_word Top_i16,   $0020
    D_END
    .assert * - :- = kLavaPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $100
    d_byte HeightPx_u8, kLavaPlatformHeightPx
    d_word Left_i16,   $0000
    d_word Top_i16, kLavaPlatformTopShortRoom
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   .assert * - :- = kBossDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eRoom::ShadowDepths
    D_END
    .assert * - :- = kBossUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be an upgrade
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eFlag::UpgradeOpMul
    D_END
    .assert * - :- = kBossBreakerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be a breaker
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eFlag::BreakerShadow
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 3
    d_byte Target_byte, kEmitterYMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 12
    d_byte Target_byte, kEmitterXMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC DataC_Boss_Shadow_sBoss
    D_STRUCT sBoss
    d_byte Boss_eFlag, eFlag::BossShadow
    d_byte BodyPlatform_u8, kBossBodyPlatformIndex
    d_addr Tick_func_ptr, FuncC_Boss_Shadow_TickBoss
    d_addr Draw_func_ptr, FuncC_Boss_Shadow_DrawBoss
    D_END
.ENDPROC

;;; Room init function for the BossShadow room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Shadow_EnterRoom
    ldax #DataC_Boss_Shadow_sBoss  ; param: sBoss ptr
    jsr FuncA_Room_InitBoss  ; sets Z if boss is alive
    bne _BossIsDead
_BossIsAlive:
    lda #kBossInitHealth
    sta Zp_RoomState + sState::BossHealth_u8
    lda #kBossInitCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #eBossMode::LavaRising  ; TODO
    sta Zp_RoomState + sState::Current_eBossMode
_BossIsDead:
    rts
.ENDPROC

;;; Performs per-frame upates for the boss in this room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Shadow_TickBoss
    ;; TODO: if boss is in platform, damage it
_CoolDown:
    lda Zp_RoomState + sState::BossCooldown_u8
    beq @done
    dec Zp_RoomState + sState::BossCooldown_u8
    @done:
_CheckMode:
    ;; Branch based on the current boss mode.
    ldy Zp_RoomState + sState::Current_eBossMode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBossMode
    d_entry table, Dead,        Func_Noop
    d_entry table, LavaRising,  _BossLavaRising
    d_entry table, LavaFalling, _BossLavaFalling
    D_END
.ENDREPEAT
_BossLavaRising:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Raise the lava.
    inc Zp_RoomState + sState::LavaOffset_u8
    ldx #kLavaPlatformIndex  ; param: platform index
    lda #<-1  ; param: move delta
    jsr Func_MovePlatformVert
    lda Zp_RoomState + sState::LavaOffset_u8
    cmp #kMaxLavaOffset
    bge @lavaFullyRaised
    ;; If the lava isn't fully raised yet, shake the room and keep going.
    lda #kLavaRiseSlowdown  ; param: num frames
    sta Zp_RoomState + sState::BossCooldown_u8
    jmp Func_ShakeRoom
    ;; Once the lava is fully raised, set the cooldown and prepare to make the
    ;; lava fall.
    @lavaFullyRaised:
    lda #kLavaWaitFrames
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #eBossMode::LavaFalling
    sta Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_BossLavaFalling:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Lower the lava.
    dec Zp_RoomState + sState::LavaOffset_u8
    ldx #kLavaPlatformIndex  ; param: platform index
    lda #1  ; param: move delta
    jsr Func_MovePlatformVert
    lda Zp_RoomState + sState::LavaOffset_u8
    beq @lavaFullyLowered
    ;; If the lava isn't fully lowered yet, shake the room and keep going.
    lda #kLavaFallSlowdown  ; param: num frames
    sta Zp_RoomState + sState::BossCooldown_u8
    jmp Func_ShakeRoom
    ;; Once the lava is fully lowered, set the cooldown and switch modes.
    @lavaFullyLowered:
    lda #kLavaWaitFrames  ; TODO
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #eBossMode::LavaRising  ; TODO
    sta Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
.ENDPROC

;;; Draw function for the BossShadow room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Shadow_DrawRoom
    jsr FuncA_Objects_AnimateLavaTerrain
_SetUpIrq:
    lda Zp_RoomState + sState::LavaOffset_u8
    beq @done
    ;; Compute the IRQ latch value to set between the top of the lava and the
    ;; top of the window (if any), and set that as Param4_byte.
    rsub #kLavaTerrainTopShortRoom
    sta T0  ; lava terrain top (in room pixels)
    add Zp_RoomScrollY_u8
    rsub Zp_Buffered_sIrq + sIrq::Latch_u8
    blt @done  ; window top is above lava top
    sta <(Zp_Buffered_sIrq + sIrq::Param4_byte)  ; window latch
    ;; Set up our own sIrq struct to handle lava movement.
    lda T0  ; lava terrain top (in room pixels)
    sub Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    ldax #Int_BossShadowLavaIrq
    stax <(Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr)
    @done:
_Forcefield:
    ldx #kEmitterForcefieldPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawForcefieldPlatform
_DrawBoss:
    jmp FuncA_Objects_DrawBoss
.ENDPROC

;;; Draw function for the city boss.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Shadow_DrawBoss
    ;; TODO: draw the boss
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Room tick function for the BossShadow room.
.PROC FuncA_Room_BossShadow_TickRoom
    .assert eBossMode::Dead = 0, error
    lda Zp_RoomState + sState::Current_eBossMode  ; param: zero if boss dead
    jmp FuncA_Room_TickBoss
.ENDPROC

.PROC FuncA_Room_BossShadowEmitterX_InitReset
    lda #kEmitterXInitRegX  ; param: X register value
    jmp FuncA_Room_MachineEmitterXInitReset
.ENDPROC

.PROC FuncA_Room_BossShadowEmitterY_InitReset
    lda #kEmitterYInitRegY  ; param: X register value
    jmp FuncA_Room_MachineEmitterYInitReset
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

.PROC FuncA_Terrain_BossShadow_FadeInRoom
_Tiles:
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    ldax #Ppu_Nametable3_sName + sName::Tiles_u8_arr + 0
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    lda #4
    sta T0  ; num block rows
    @loop:
    ldy #$40  ; param: left tile ID
    lda #$41  ; param: right tile ID
    jsr _WriteLavaTileRow  ; preserves A, Y, and T0+
    tya  ; param: right tile ID (now $40)
    iny  ; param: left tile ID (now $41)
    jsr _WriteLavaTileRow  ; preserves A, Y, and T0+
    dec T0  ; num block rows
    bne @loop
_Attributes:
    jsr FuncA_Terrain_FadeInShortRoomWithLava
    ldx #16   ; param: num bytes to write
    ldy #$55  ; param: attribute value
    lda #$00  ; param: initial byte offset
    jmp Func_WriteToLowerAttributeTable
_WriteLavaTileRow:
    ldx #kScreenWidthBlocks
    @loop:
    sty Hw_PpuData_rw
    sta Hw_PpuData_rw
    dex
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_BossShadowEmitterX_Draw
    ldx Ram_MachineGoalHorz_u8_arr + kEmitterXMachineIndex
    ldy _BeamLength_u8_arr, x  ; param: beam length in tiles
    jmp FuncA_Objects_DrawEmitterXMachine
_BeamLength_u8_arr:
    .byte 18, 20, 20, 20, 20, 20, 20, 20, 20, 18
.ENDPROC

.PROC FuncA_Objects_BossShadowEmitterY_Draw
    ldy #2  ; param: beam length in tiles
    ldx Ram_MachineGoalVert_u8_arr + kEmitterYMachineIndex
    beq @draw
    ldy #24  ; param: beam length in tiles
    @draw:
    jmp FuncA_Objects_DrawEmitterYMachine
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top of the lava in the BossShadow room.
;;; Sets the scroll so as to make the lava appear to start here.
.PROC Int_BossShadowLavaIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ and prepare for the next one.
    jsr Func_AckIrqAndLatchWindowFromParam4  ; preserves Y
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #7  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the upper
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #0 << 2  ; nametable number << 2
    sta Hw_PpuAddr_w2
    lda #kLavaTerrainTopShortRoom  ; new scroll-Y value
    sta Hw_PpuScroll_w2
    lda #((kLavaTerrainTopShortRoom & $38) << 2) | (0 >> 3)
    ;; We should now be in the second HBlank.
    stx Hw_PpuScroll_w2  ; new scroll-X value (zero)
    sta Hw_PpuAddr_w2    ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;;=========================================================================;;;
