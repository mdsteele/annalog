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

.INCLUDE "actor.inc"
.INCLUDE "boss.inc"
.INCLUDE "cpu.inc"
.INCLUDE "device.inc"
.INCLUDE "macros.inc"
.INCLUDE "platform.inc"
.INCLUDE "room.inc"
.INCLUDE "tileset.inc"

.IMPORT DataC_Boss_Crypt_sRoom
.IMPORT DataC_Boss_Garden_sRoom
.IMPORT DataC_Boss_Temple_sRoom
.IMPORT DataC_Core_Elevator_sRoom
.IMPORT DataC_Core_Lock_sRoom
.IMPORT DataC_Crypt_East_sRoom
.IMPORT DataC_Crypt_Escape_sRoom
.IMPORT DataC_Crypt_Flower_sRoom
.IMPORT DataC_Crypt_Gallery_sRoom
.IMPORT DataC_Crypt_Landing_sRoom
.IMPORT DataC_Crypt_North_sRoom
.IMPORT DataC_Crypt_South_sRoom
.IMPORT DataC_Crypt_Tomb_sRoom
.IMPORT DataC_Crypt_West_sRoom
.IMPORT DataC_Factory_Bridge_sRoom
.IMPORT DataC_Factory_Center_sRoom
.IMPORT DataC_Factory_Elevator_sRoom
.IMPORT DataC_Factory_West_sRoom
.IMPORT DataC_Garden_Crossroad_sRoom
.IMPORT DataC_Garden_East_sRoom
.IMPORT DataC_Garden_Flower_sRoom
.IMPORT DataC_Garden_Hallway_sRoom
.IMPORT DataC_Garden_Landing_sRoom
.IMPORT DataC_Garden_Shaft_sRoom
.IMPORT DataC_Garden_Shrine_sRoom
.IMPORT DataC_Garden_Tower_sRoom
.IMPORT DataC_Garden_Tunnel_sRoom
.IMPORT DataC_Lava_East_sRoom
.IMPORT DataC_Lava_Flower_sRoom
.IMPORT DataC_Lava_Shaft_sRoom
.IMPORT DataC_Lava_Station_sRoom
.IMPORT DataC_Lava_Teleport_sRoom
.IMPORT DataC_Lava_West_sRoom
.IMPORT DataC_Mermaid_Cellar_sRoom
.IMPORT DataC_Mermaid_Drain_sRoom
.IMPORT DataC_Mermaid_East_sRoom
.IMPORT DataC_Mermaid_Elevator_sRoom
.IMPORT DataC_Mermaid_Entry_sRoom
.IMPORT DataC_Mermaid_Flower_sRoom
.IMPORT DataC_Mermaid_Hut1_sRoom
.IMPORT DataC_Mermaid_Hut2_sRoom
.IMPORT DataC_Mermaid_Hut3_sRoom
.IMPORT DataC_Mermaid_Hut4_sRoom
.IMPORT DataC_Mermaid_Hut5_sRoom
.IMPORT DataC_Mermaid_Hut6_sRoom
.IMPORT DataC_Mermaid_Village_sRoom
.IMPORT DataC_Mine_Collapse_sRoom
.IMPORT DataC_Mine_Pit_sRoom
.IMPORT DataC_Mine_South_sRoom
.IMPORT DataC_Prison_Cell_sRoom
.IMPORT DataC_Prison_Crossroad_sRoom
.IMPORT DataC_Prison_East_sRoom
.IMPORT DataC_Prison_Escape_sRoom
.IMPORT DataC_Prison_Flower_sRoom
.IMPORT DataC_Prison_Upper_sRoom
.IMPORT DataC_Sewer_Flower_sRoom
.IMPORT DataC_Sewer_West_sRoom
.IMPORT DataC_Shadow_Teleport_sRoom
.IMPORT DataC_Temple_Altar_sRoom
.IMPORT DataC_Temple_Entry_sRoom
.IMPORT DataC_Temple_Flower_sRoom
.IMPORT DataC_Temple_Lobby_sRoom
.IMPORT DataC_Temple_Nave_sRoom
.IMPORT DataC_Temple_Pit_sRoom
.IMPORT DataC_Temple_Spire_sRoom
.IMPORT DataC_Temple_West_sRoom
.IMPORT DataC_Town_House1_sRoom
.IMPORT DataC_Town_House2_sRoom
.IMPORT DataC_Town_House3_sRoom
.IMPORT DataC_Town_House4_sRoom
.IMPORT DataC_Town_House5_sRoom
.IMPORT DataC_Town_House6_sRoom
.IMPORT DataC_Town_Outdoors_sRoom
.IMPORT FuncA_Room_InitActor
.IMPORT FuncA_Room_InitAllMachines
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceBlockCol_u8_arr
.IMPORT Ram_DeviceBlockRow_u8_arr
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformRight_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORTZP Zp_AvatarExit_ePassage
.IMPORTZP Zp_AvatarPlatformIndex_u8
.IMPORTZP Zp_CameraCanScroll_bool
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_HudMachineIndex_u8
.IMPORTZP Zp_RoomShake_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

.ZEROPAGE

;;; The room number for the previously-loaded room.
.EXPORTZP Zp_Previous_eRoom
Zp_Previous_eRoom: .res 1

;;; The room number for the currently-loaded room.
.EXPORTZP Zp_Current_eRoom
Zp_Current_eRoom: .res 1

;;; Data for the currently-loaded room.
.EXPORTZP Zp_Current_sRoom
Zp_Current_sRoom: .tag sRoom

;;; The currently-loaded tileset.
.EXPORTZP Zp_Current_sTileset
Zp_Current_sTileset: .tag sTileset

;;; A chunk of memory that each room can divvy up however it wants to store
;;; state specific to that room.  These bytes are automatically zeroed just
;;; before a room is loaded, but can be further initialized by room
;;; Enter_func_ptr functions and/or machine Init_func_ptr functions.
.EXPORTZP Zp_RoomState
Zp_RoomState: .res kRoomStateSize

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Pointers and PRGC bank numbers for sRoom structs for all rooms in the game,
;;; indexed by eRoom values.
.EXPORT DataA_Room_Banks_u8_arr
.REPEAT 3, table
    D_TABLE_LO table, DataA_Room_Table_sRoom_ptr_0_arr
    D_TABLE_HI table, DataA_Room_Table_sRoom_ptr_1_arr
    D_TABLE_BANK table, DataA_Room_Banks_u8_arr
    D_TABLE eRoom
    d_entry table, BossCrypt,       DataC_Boss_Crypt_sRoom
    d_entry table, BossGarden,      DataC_Boss_Garden_sRoom
    d_entry table, BossTemple,      DataC_Boss_Temple_sRoom
    d_entry table, CoreElevator,    DataC_Core_Elevator_sRoom
    d_entry table, CoreLock,        DataC_Core_Lock_sRoom
    d_entry table, CryptEast,       DataC_Crypt_East_sRoom
    d_entry table, CryptEscape,     DataC_Crypt_Escape_sRoom
    d_entry table, CryptFlower,     DataC_Crypt_Flower_sRoom
    d_entry table, CryptGallery,    DataC_Crypt_Gallery_sRoom
    d_entry table, CryptLanding,    DataC_Crypt_Landing_sRoom
    d_entry table, CryptNorth,      DataC_Crypt_North_sRoom
    d_entry table, CryptSouth,      DataC_Crypt_South_sRoom
    d_entry table, CryptTomb,       DataC_Crypt_Tomb_sRoom
    d_entry table, CryptWest,       DataC_Crypt_West_sRoom
    d_entry table, FactoryBridge,   DataC_Factory_Bridge_sRoom
    d_entry table, FactoryCenter,   DataC_Factory_Center_sRoom
    d_entry table, FactoryElevator, DataC_Factory_Elevator_sRoom
    d_entry table, FactoryWest,     DataC_Factory_West_sRoom
    d_entry table, GardenCrossroad, DataC_Garden_Crossroad_sRoom
    d_entry table, GardenEast,      DataC_Garden_East_sRoom
    d_entry table, GardenFlower,    DataC_Garden_Flower_sRoom
    d_entry table, GardenHallway,   DataC_Garden_Hallway_sRoom
    d_entry table, GardenLanding,   DataC_Garden_Landing_sRoom
    d_entry table, GardenShaft,     DataC_Garden_Shaft_sRoom
    d_entry table, GardenShrine,    DataC_Garden_Shrine_sRoom
    d_entry table, GardenTower,     DataC_Garden_Tower_sRoom
    d_entry table, GardenTunnel,    DataC_Garden_Tunnel_sRoom
    d_entry table, LavaEast,        DataC_Lava_East_sRoom
    d_entry table, LavaFlower,      DataC_Lava_Flower_sRoom
    d_entry table, LavaShaft,       DataC_Lava_Shaft_sRoom
    d_entry table, LavaStation,     DataC_Lava_Station_sRoom
    d_entry table, LavaTeleport,    DataC_Lava_Teleport_sRoom
    d_entry table, LavaWest,        DataC_Lava_West_sRoom
    d_entry table, MermaidCellar,   DataC_Mermaid_Cellar_sRoom
    d_entry table, MermaidDrain,    DataC_Mermaid_Drain_sRoom
    d_entry table, MermaidEast,     DataC_Mermaid_East_sRoom
    d_entry table, MermaidElevator, DataC_Mermaid_Elevator_sRoom
    d_entry table, MermaidEntry,    DataC_Mermaid_Entry_sRoom
    d_entry table, MermaidFlower,   DataC_Mermaid_Flower_sRoom
    d_entry table, MermaidHut1,     DataC_Mermaid_Hut1_sRoom
    d_entry table, MermaidHut2,     DataC_Mermaid_Hut2_sRoom
    d_entry table, MermaidHut3,     DataC_Mermaid_Hut3_sRoom
    d_entry table, MermaidHut4,     DataC_Mermaid_Hut4_sRoom
    d_entry table, MermaidHut5,     DataC_Mermaid_Hut5_sRoom
    d_entry table, MermaidHut6,     DataC_Mermaid_Hut6_sRoom
    d_entry table, MermaidVillage,  DataC_Mermaid_Village_sRoom
    d_entry table, MineCollapse,    DataC_Mine_Collapse_sRoom
    d_entry table, MinePit,         DataC_Mine_Pit_sRoom
    d_entry table, MineSouth,       DataC_Mine_South_sRoom
    d_entry table, PrisonCell,      DataC_Prison_Cell_sRoom
    d_entry table, PrisonCrossroad, DataC_Prison_Crossroad_sRoom
    d_entry table, PrisonEast,      DataC_Prison_East_sRoom
    d_entry table, PrisonEscape,    DataC_Prison_Escape_sRoom
    d_entry table, PrisonFlower,    DataC_Prison_Flower_sRoom
    d_entry table, PrisonUpper,     DataC_Prison_Upper_sRoom
    d_entry table, SewerFlower,     DataC_Sewer_Flower_sRoom
    d_entry table, SewerWest,       DataC_Sewer_West_sRoom
    d_entry table, ShadowTeleport,  DataC_Shadow_Teleport_sRoom
    d_entry table, TempleAltar,     DataC_Temple_Altar_sRoom
    d_entry table, TempleEntry,     DataC_Temple_Entry_sRoom
    d_entry table, TempleFlower,    DataC_Temple_Flower_sRoom
    d_entry table, TempleLobby,     DataC_Temple_Lobby_sRoom
    d_entry table, TempleNave,      DataC_Temple_Nave_sRoom
    d_entry table, TemplePit,       DataC_Temple_Pit_sRoom
    d_entry table, TempleSpire,     DataC_Temple_Spire_sRoom
    d_entry table, TempleWest,      DataC_Temple_West_sRoom
    d_entry table, TownHouse1,      DataC_Town_House1_sRoom
    d_entry table, TownHouse2,      DataC_Town_House2_sRoom
    d_entry table, TownHouse3,      DataC_Town_House3_sRoom
    d_entry table, TownHouse4,      DataC_Town_House4_sRoom
    d_entry table, TownHouse5,      DataC_Town_House5_sRoom
    d_entry table, TownHouse6,      DataC_Town_House6_sRoom
    d_entry table, TownOutdoors,    DataC_Town_Outdoors_sRoom
    D_END
.ENDREPEAT

;;; Loads and initializes data for the specified room.
;;; @prereq The correct PRGC bank has been set for the room to be loaded.
;;; @param X The eRoom value for the room to load.
.EXPORT FuncA_Room_Load
.PROC FuncA_Room_Load
    lda Zp_Current_eRoom
    sta Zp_Previous_eRoom
    stx Zp_Current_eRoom
_CopyRoomStruct:
    ;; Get a pointer to the sRoom struct and store it in Zp_Tmp_ptr.
    lda DataA_Room_Table_sRoom_ptr_0_arr, x
    sta Zp_Tmp_ptr + 0
    lda DataA_Room_Table_sRoom_ptr_1_arr, x
    sta Zp_Tmp_ptr + 1
    ;; Copy the sRoom struct into Zp_Current_sRoom.
    ldy #.sizeof(sRoom) - 1
    .assert .sizeof(sRoom) <= $80, error
    @loop:
    lda (Zp_Tmp_ptr), y
    sta Zp_Current_sRoom, y
    dey
    bpl @loop
_CopyTilesetStruct:
    ;; Copy the current room's Terrain_sTileset_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Terrain_sTileset_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Copy the sTileset struct into Zp_Current_sTileset.
    ldy #.sizeof(sTileset) - 1
    .assert .sizeof(sTileset) <= $80, error
    @loop:
    lda (Zp_Tmp_ptr), y
    sta Zp_Current_sTileset, y
    dey
    bpl @loop
_ClearRoomState:
    lda #0
    ldx #kRoomStateSize
    @loop:
    dex
    sta Zp_RoomState, x
    bne @loop
_LoadPlatforms:
    ;; Copy the current room's Platforms_sPlatform_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Platforms_sPlatform_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Copy room platform structs into platform RAM.
    ldx #0  ; platform index
    .assert kMaxPlatforms * .sizeof(sPlatform) < $100, error
    ldy #0  ; byte offset into Platforms_sPlatform_arr_ptr
    @copyLoop:
    .assert sPlatform::Type_ePlatform = 0, error
    lda (Zp_Tmp_ptr), y
    .assert ePlatform::None = 0, error
    beq @copyDone
    sta Ram_PlatformType_ePlatform_arr, x
    iny
    .assert sPlatform::WidthPx_u16 = 1, error
    lda (Zp_Tmp_ptr), y
    sta Zp_Tmp1_byte  ; platform width (lo)
    iny
    lda (Zp_Tmp_ptr), y
    sta Zp_Tmp2_byte  ; platform width (hi)
    iny
    .assert sPlatform::HeightPx_u8 = 3, error
    lda (Zp_Tmp_ptr), y
    sta Zp_Tmp3_byte  ; platform height
    iny
    .assert sPlatform::Left_i16 = 4, error
    lda (Zp_Tmp_ptr), y
    sta Ram_PlatformLeft_i16_0_arr, x
    add Zp_Tmp1_byte  ; platform width (lo)
    sta Ram_PlatformRight_i16_0_arr, x
    iny
    lda (Zp_Tmp_ptr), y
    sta Ram_PlatformLeft_i16_1_arr, x
    adc Zp_Tmp2_byte  ; platform width (hi)
    sta Ram_PlatformRight_i16_1_arr, x
    iny
    .assert sPlatform::Top_i16 = 6, error
    lda (Zp_Tmp_ptr), y
    sta Ram_PlatformTop_i16_0_arr, x
    add Zp_Tmp3_byte  ; platform height
    sta Ram_PlatformBottom_i16_0_arr, x
    iny
    lda (Zp_Tmp_ptr), y
    sta Ram_PlatformTop_i16_1_arr, x
    adc #0
    sta Ram_PlatformBottom_i16_1_arr, x
    iny
    .assert .sizeof(sPlatform) = 8, error
    inx
    bne @copyLoop  ; unconditional
    ;; Clear remaining slots in platform RAM.
    @clearLoop:
    sta Ram_PlatformType_ePlatform_arr, x  ; A is already ePlatform::None
    inx
    @copyDone:
    cpx #kMaxPlatforms
    blt @clearLoop
_LoadActors:
    ;; Copy the current room's Actors_sActor_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Actors_sActor_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Copy room actor structs into actor RAM.
    ldx #0  ; actor index
    .assert kMaxActors * .sizeof(sActor) < $100, error
    ldy #0  ; byte offset into Actors_sActor_arr_ptr
    @copyLoop:
    ;; Actor type:
    .assert sActor::Type_eActor = 0, error
    lda (Zp_Tmp_ptr), y
    .assert eActor::None = 0, error
    beq @copyDone
    sta Ram_ActorType_eActor_arr, x
    iny
    ;; X-position:
    .assert sActor::PosX_i16 = 1, error
    lda (Zp_Tmp_ptr), y
    iny
    sta Ram_ActorPosX_i16_0_arr, x
    lda (Zp_Tmp_ptr), y
    iny
    sta Ram_ActorPosX_i16_1_arr, x
    ;; Y-position:
    .assert sActor::PosY_i16 = 3, error
    lda (Zp_Tmp_ptr), y
    iny
    sta Ram_ActorPosY_i16_0_arr, x
    lda (Zp_Tmp_ptr), y
    iny
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Temporarily store param byte in Ram_ActorState1_byte_arr:
    .assert sActor::Param_byte = 5, error
    lda (Zp_Tmp_ptr), y
    iny
    sta Ram_ActorState1_byte_arr, x
    ;; Continue to next sActor entry.
    .assert .sizeof(sActor) = 6, error
    inx
    bne @copyLoop  ; unconditional
    ;; Clear remaining slots in actor RAM.
    @clearLoop:
    sta Ram_ActorType_eActor_arr, x  ; A is already eActor::None
    inx
    @copyDone:
    cpx #kMaxActors
    blt @clearLoop
    ;; Call all actor init functions, using the param bytes we stored in
    ;; Ram_ActorState1_byte_arr.
    dex
    @initLoop:
    lda Ram_ActorState1_byte_arr, x
    jsr FuncA_Room_InitActor  ; preserves X
    dex
    .assert kMaxActors < $80, error
    bpl @initLoop
_LoadDevices:
    ;; Copy the current room's Devices_sDevice_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::Devices_sDevice_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Copy room device structs into device RAM.
    ldx #0  ; device index
    .assert kMaxDevices * .sizeof(sDevice) < $100, error
    ldy #0  ; byte offset into Devices_sDevice_arr_ptr
    @copyLoop:
    .assert sDevice::Type_eDevice = 0, error
    lda (Zp_Tmp_ptr), y
    .assert eDevice::None = 0, error
    beq @copyDone
    sta Ram_DeviceType_eDevice_arr, x
    iny
    .assert sDevice::BlockRow_u8 = 1, error
    lda (Zp_Tmp_ptr), y
    sta Ram_DeviceBlockRow_u8_arr, x
    iny
    .assert sDevice::BlockCol_u8 = 2, error
    lda (Zp_Tmp_ptr), y
    sta Ram_DeviceBlockCol_u8_arr, x
    iny
    .assert sDevice::Target_u8 = 3, error
    lda (Zp_Tmp_ptr), y
    sta Ram_DeviceTarget_u8_arr, x
    iny
    .assert .sizeof(sDevice) = 4, error
    lda #0
    sta Ram_DeviceAnim_u8_arr, x
    inx
    bne @copyLoop  ; unconditional
    ;; Clear remaining slots in device RAM.
    @clearLoop:
    sta Ram_DeviceType_eDevice_arr, x  ; A is already eDevice::None
    inx
    @copyDone:
    cpx #kMaxDevices
    blt @clearLoop
_SetVars:
    ldx #0
    .assert ePassage::None = 0, error
    stx Zp_AvatarExit_ePassage
    stx Zp_RoomShake_u8
    dex  ; now X is $ff
    stx Zp_AvatarPlatformIndex_u8
    stx Zp_CameraCanScroll_bool
    stx Zp_ConsoleMachineIndex_u8
    stx Zp_HudMachineIndex_u8
_CallInit:
    jmp FuncA_Room_InitAllMachines
.ENDPROC

;;; Calls the current room's Tick_func_ptr function.
.EXPORT FuncA_Room_CallRoomTick
.PROC FuncA_Room_CallRoomTick
    jmp (Zp_Current_sRoom + sRoom::Tick_func_ptr)
.ENDPROC

;;;=========================================================================;;;
