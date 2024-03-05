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

.INCLUDE "../avatar.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../irq.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../spawn.inc"
.INCLUDE "teleporter.inc"

.IMPORT FuncA_Avatar_SpawnAtDevice
.IMPORT FuncM_SwitchPrgcAndLoadRoom
.IMPORT Func_AckIrqAndLatchWindowFromParam4
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_FadeOutToBlack
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetLastSpawnPoint
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Main_Explore_EnterRoom
.IMPORT Ppu_ChrBgTeleport
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_RoomScrollY_u8

;;;=========================================================================;;;

;;; The room pixel Y-position below which no teleporter BG tiles will be drawn.
kTeleportZoneBottomY = $90

;;; The tile row/col in the upper nametable for the top-left corner of the BG
;;; tiles for the teleport zap.
kTeleportZapStartRow = 12
kTeleportZapStartCol = 15

;;; The PPU addresses for the start (left) of each row of the teleport zap.
.LINECONT +
Ppu_TeleportZapRow0Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kTeleportZapStartRow + 0) + kTeleportZapStartCol
Ppu_TeleportZapRow1Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kTeleportZapStartRow + 1) + kTeleportZapStartCol
Ppu_TeleportZapRow2Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kTeleportZapStartRow + 2) + kTeleportZapStartCol
Ppu_TeleportZapRow3Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kTeleportZapStartRow + 3) + kTeleportZapStartCol
Ppu_TeleportZapRow4Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kTeleportZapStartRow + 4) + kTeleportZapStartCol
.LINECONT -

;;; Don't attempt to update the teleport zap BG tiles if the PPU transfer
;;; buffer already has this many bytes or more in it (so we don't risk putting
;;; more in the buffer than can be processed in one VBlank).  The specific
;;; value chosen for this limit is somewhat arbitrary; but in particular, it's
;;; high to still allow for transferring a full window row (which takes $24
;;; buffer bytes).
kTeleportTransferThreshold = $30

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for leaving the current room via a teleporter and entering the next
;;; room.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @prereq There is a Teleporter device in the current room.
.PROC Main_GoThroughTeleporter
    jsr Func_FadeOutToBlack
    ldx Ram_DeviceTarget_byte_arr + kTeleporterDeviceIndex  ; param: eRoom
    jsr FuncM_SwitchPrgcAndLoadRoom
    jsr_prga FuncA_Avatar_EnterRoomViaTeleporter
    jmp Main_Explore_EnterRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Called when entering a new room via a teleporter.  Marks the entrance
;;; teleporter as the last spawn point and positions the player avatar at that
;;; teleporter.  Also sets up the "teleport in" cutscene.
;;; @prereq The new room is loaded.
;;; @prereq There is a Teleporter device in the new room.
.PROC FuncA_Avatar_EnterRoomViaTeleporter
    lda #bSpawn::Device | kTeleporterDeviceIndex  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint
    ldx #kTeleporterDeviceIndex  ; param: device index
    jsr FuncA_Avatar_SpawnAtDevice
_InitCutsceneState:
    lda #eAvatar::Hidden
    sta Zp_AvatarPose_eAvatar
    lda #eCutscene::SharedTeleportIn
    sta Zp_Next_eCutscene
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_SharedTeleportOut_sCutscene
.PROC DataA_Cutscene_SharedTeleportOut_sCutscene
    act_SetAvatarPose eAvatar::Hidden
    act_CallFunc FuncA_Cutscene_MakeTeleportSmokePuff
    act_WaitFrames 75
    act_JumpToMain Main_GoThroughTeleporter
.ENDPROC

.EXPORT DataA_Cutscene_SharedTeleportIn_sCutscene
.PROC DataA_Cutscene_SharedTeleportIn_sCutscene
    act_WaitFrames 50
    act_ShakeRoom kTeleportShakeFrames
    act_SetDeviceAnim kTeleporterDeviceIndex, kTeleporterAnimFull
    act_CallFunc FuncA_Cutscene_MakeTeleportSmokePuff
    act_ContinueExploring
.ENDPROC

;;; Spawns a smoke explosion actor at the player avatar's current position,
;;; representing the avatar teleporting in/out.
.PROC FuncA_Cutscene_MakeTeleportSmokePuff
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @done
    jsr Func_SetPointToAvatarCenter  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    jmp Func_InitActorSmokeExplosion
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC DataA_Objects_TeleportTransferBlank_arr
    ;; Row 0:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow0Start + 1  ; transfer destination
    .byte 3
    .byte 0, 0, 0
    ;; Row 1:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow1Start + 1  ; transfer destination
    .byte 6
    .byte 0, 0, 0, 0, 0, 0
    ;; Row 2:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow2Start + 0  ; transfer destination
    .byte 8
    .byte 0, 0, 0, 0, 0, 0, 0, 0
    ;; Row 3:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow3Start + 0  ; transfer destination
    .byte 8
    .byte 0, 0, 0, 0, 0, 0, 0, 0
    ;; Row 4:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow4Start + 3  ; transfer destination
    .byte 4
    .byte 0, 0, 0, 0
.ENDPROC

.PROC DataA_Objects_TeleportTransferBolt1_arr
    ;; Row 0:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow0Start + 1  ; transfer destination
    .byte 3
    .byte 0, $48, 0
    ;; Row 1:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow1Start + 1  ; transfer destination
    .byte 6
    .byte $49, $4a, 0, 0, $4b, $4c
    ;; Row 2:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow2Start + 0  ; transfer destination
    .byte 8
    .byte $4d, $4e, $4f, $50, $51, $52, $53, $54
    ;; Row 3:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow3Start + 0  ; transfer destination
    .byte 8
    .byte $55, 0, 0, $56, $57, 0, 0, $58
    ;; Row 4:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow4Start + 3  ; transfer destination
    .byte 4
    .byte $59, 0, 0, 0
.ENDPROC

.PROC DataA_Objects_TeleportTransferBolt2_arr
    ;; Row 0:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow0Start + 1  ; transfer destination
    .byte 3
    .byte 0, 0, $5a
    ;; Row 1:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow1Start + 1  ; transfer destination
    .byte 6
    .byte 0, $5b, $5c, $5d, 0, 0
    ;; Row 2:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow2Start + 0  ; transfer destination
    .byte 8
    .byte $5e, 0, $5f, $60, $61, $62, 0, $63
    ;; Row 3:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow3Start + 0  ; transfer destination
    .byte 8
    .byte $64, $65, $66, 0, $67, $68, $69, $6a
    ;; Row 4:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow4Start + 3  ; transfer destination
    .byte 4
    .byte 0, 0, $6b, $6c
.ENDPROC

.PROC DataA_Objects_TeleportTransferDisp1_arr
    ;; Row 0:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow0Start + 1  ; transfer destination
    .byte 3
    .byte $6d, 0, 0
    ;; Row 1:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow1Start + 1  ; transfer destination
    .byte 6
    .byte $6e, $6f, 0, 0, 0, $70
    ;; Row 2:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow2Start + 0  ; transfer destination
    .byte 8
    .byte 0, 0, 0, 0, 0, $71, $72, 0
    ;; Row 3:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow3Start + 0  ; transfer destination
    .byte 8
    .byte 0, 0, 0, $73, $74, 0, 0, 0
    ;; Row 4:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow4Start + 3  ; transfer destination
    .byte 4
    .byte $75, 0, 0, 0
.ENDPROC

.PROC DataA_Objects_TeleportTransferDisp2_arr
    ;; Row 0:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow0Start + 1  ; transfer destination
    .byte 3
    .byte $76, 0, 0
    ;; Row 1:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow1Start + 1  ; transfer destination
    .byte 6
    .byte $77, $78, 0, 0, $79, $7a
    ;; Row 2:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow2Start + 0  ; transfer destination
    .byte 8
    .byte 0, 0, 0, 0, 0, 0, 0, 0
    ;; Row 3:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow3Start + 0  ; transfer destination
    .byte 8
    .byte 0, 0, 0, $7b, 0, 0, 0, 0
    ;; Row 4:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TeleportZapRow4Start + 3  ; transfer destination
    .byte 4
    .byte 0, 0, 0, 0
.ENDPROC

;;; Draws a teleporter device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceTeleporter
.PROC FuncA_Objects_DrawDeviceTeleporter
_SetUpIrq:
    ;; Compute the IRQ latch value to set between the bottom of the teleport
    ;; zone and the top of the window (if any), and set that as Param4_byte.
    lda Zp_Buffered_sIrq + sIrq::Latch_u8
    sub #kTeleportZoneBottomY
    add Zp_RoomScrollY_u8
    sta Zp_Buffered_sIrq + sIrq::Param4_byte  ; window latch
    ;; Set up our own sIrq struct to switch CHR04 banks.
    lda #kTeleportZoneBottomY - 1
    sub Zp_RoomScrollY_u8
    sta Zp_Buffered_sIrq + sIrq::Latch_u8
    ldya #Int_TeleportZoneBottomIrq
    stya Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr
    ;; Store next frame's CHR04 bank for animated terrain so that the IRQ for
    ;; the bottom of the teleport zone can restore it.
    lda Zp_Chr04Bank_u8
    sta Zp_Buffered_sIrq + sIrq::Param3_byte  ; terrain CHR04 bank
    ;; Set up the CHR04 bank used by the teleporter.
    lda #<.bank(Ppu_ChrBgTeleport)
    sta Zp_Chr04Bank_u8
_TransferBgTiles:
    ;; If the PPU transfer buffer already has a fair bit of data in it, don't
    ;; update the teleport zap BG tiles this frame.
    lda Zp_PpuTransferLen_u8
    cmp #kTeleportTransferThreshold
    bge @done
    ;; Use the device animation to determine which animation shape to draw for
    ;; the teleport zap this frame.
    lda Ram_DeviceAnim_u8_arr, x
    stx T3  ; teleporter device index
    div #kTeleportZapSlowdown
    tay
    ldx _Transfer_arr_ptr_0_arr, y  ; param: data pointer (lo)
    lda _Transfer_arr_ptr_1_arr, y  ; param: data pointer (hi)
    ;; The transfer entries we're choosing between are all the same size.
    .linecont +
    .assert .sizeof(DataA_Objects_TeleportTransferBolt1_arr) = \
            .sizeof(DataA_Objects_TeleportTransferBlank_arr), error
    .assert .sizeof(DataA_Objects_TeleportTransferBolt2_arr) = \
            .sizeof(DataA_Objects_TeleportTransferBlank_arr), error
    .assert .sizeof(DataA_Objects_TeleportTransferDisp1_arr) = \
            .sizeof(DataA_Objects_TeleportTransferBlank_arr), error
    .assert .sizeof(DataA_Objects_TeleportTransferDisp2_arr) = \
            .sizeof(DataA_Objects_TeleportTransferBlank_arr), error
    .linecont -
    ldy #.sizeof(DataA_Objects_TeleportTransferBlank_arr)  ; param: data len
    jsr Func_BufferPpuTransfer  ; preserves T3+
    ldx T3  ; teleporter device index
    @done:
    rts
.REPEAT 2, table
    D_TABLE_LO table, _Transfer_arr_ptr_0_arr
    D_TABLE_HI table, _Transfer_arr_ptr_1_arr
    D_TABLE kTeleportZapNumAnimShapes
    d_entry table, 0, DataA_Objects_TeleportTransferBlank_arr
    d_entry table, 1, DataA_Objects_TeleportTransferDisp2_arr
    d_entry table, 2, DataA_Objects_TeleportTransferBlank_arr
    d_entry table, 3, DataA_Objects_TeleportTransferDisp1_arr
    d_entry table, 4, DataA_Objects_TeleportTransferBolt2_arr
    d_entry table, 5, DataA_Objects_TeleportTransferBolt1_arr
    D_END
.ENDREPEAT
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the bottom of the teleportation zone in the
;;; LavaTeleport and ShadowTeleport rooms.  Switches the CHR04 bank to support
;;; animated terrain at the bottom of the room.
.PROC Int_TeleportZoneBottomIrq
    pha
    ;; At this point, the first HBlank is already almost over.  Ack the current
    ;; IRQ and prepare for the next one.
    jsr Func_AckIrqAndLatchWindowFromParam4  ; preserves X and Y
    ;; Busy-wait for a bit, so that the CHR04 bank switch will occur during the
    ;; next HBlank.
    lda #7
    @busyLoop:
    sub #1
    bne @busyLoop
    irq_chr04 Zp_Active_sIrq + sIrq::Param3_byte  ; terrain CHR04 bank
    pla
    rti
.ENDPROC

;;;=========================================================================;;;
