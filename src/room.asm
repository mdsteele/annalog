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
.INCLUDE "audio.inc"
.INCLUDE "boss.inc"
.INCLUDE "cpu.inc"
.INCLUDE "device.inc"
.INCLUDE "flag.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "music.inc"
.INCLUDE "platform.inc"
.INCLUDE "room.inc"
.INCLUDE "tileset.inc"

.IMPORT DataC_Boss_City_sRoom
.IMPORT DataC_Boss_Crypt_sRoom
.IMPORT DataC_Boss_Garden_sRoom
.IMPORT DataC_Boss_Mine_sRoom
.IMPORT DataC_Boss_Shadow_sRoom
.IMPORT DataC_Boss_Temple_sRoom
.IMPORT DataC_City_Building1_sRoom
.IMPORT DataC_City_Building2_sRoom
.IMPORT DataC_City_Building4_sRoom
.IMPORT DataC_City_Building5_sRoom
.IMPORT DataC_City_Building6_sRoom
.IMPORT DataC_City_Building7_sRoom
.IMPORT DataC_City_Center_sRoom
.IMPORT DataC_City_Drain_sRoom
.IMPORT DataC_City_Dump_sRoom
.IMPORT DataC_City_East_sRoom
.IMPORT DataC_City_Flower_sRoom
.IMPORT DataC_City_Outskirts_sRoom
.IMPORT DataC_City_Pit_sRoom
.IMPORT DataC_City_West_sRoom
.IMPORT DataC_Core_Boss_sRoom
.IMPORT DataC_Core_East_sRoom
.IMPORT DataC_Core_Elevator_sRoom
.IMPORT DataC_Core_Flower_sRoom
.IMPORT DataC_Core_Junction_sRoom
.IMPORT DataC_Core_Lock_sRoom
.IMPORT DataC_Core_South_sRoom
.IMPORT DataC_Core_West_sRoom
.IMPORT DataC_Crypt_Center_sRoom
.IMPORT DataC_Crypt_Chains_sRoom
.IMPORT DataC_Crypt_East_sRoom
.IMPORT DataC_Crypt_Escape_sRoom
.IMPORT DataC_Crypt_Flower_sRoom
.IMPORT DataC_Crypt_Gallery_sRoom
.IMPORT DataC_Crypt_Landing_sRoom
.IMPORT DataC_Crypt_Nest_sRoom
.IMPORT DataC_Crypt_North_sRoom
.IMPORT DataC_Crypt_South_sRoom
.IMPORT DataC_Crypt_Spiral_sRoom
.IMPORT DataC_Crypt_Tomb_sRoom
.IMPORT DataC_Crypt_West_sRoom
.IMPORT DataC_Factory_Access_sRoom
.IMPORT DataC_Factory_Bridge_sRoom
.IMPORT DataC_Factory_Center_sRoom
.IMPORT DataC_Factory_Elevator_sRoom
.IMPORT DataC_Factory_Flower_sRoom
.IMPORT DataC_Factory_Lock_sRoom
.IMPORT DataC_Factory_Pass_sRoom
.IMPORT DataC_Factory_Upper_sRoom
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
.IMPORT DataC_Lava_Center_sRoom
.IMPORT DataC_Lava_East_sRoom
.IMPORT DataC_Lava_Flower_sRoom
.IMPORT DataC_Lava_Shaft_sRoom
.IMPORT DataC_Lava_Station_sRoom
.IMPORT DataC_Lava_Teleport_sRoom
.IMPORT DataC_Lava_West_sRoom
.IMPORT DataC_Mermaid_Cellar_sRoom
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
.IMPORT DataC_Mermaid_Spring_sRoom
.IMPORT DataC_Mermaid_Village_sRoom
.IMPORT DataC_Mine_Collapse_sRoom
.IMPORT DataC_Mine_Drift_sRoom
.IMPORT DataC_Mine_East_sRoom
.IMPORT DataC_Mine_Entry_sRoom
.IMPORT DataC_Mine_Flower_sRoom
.IMPORT DataC_Mine_Pit_sRoom
.IMPORT DataC_Mine_South_sRoom
.IMPORT DataC_Mine_West_sRoom
.IMPORT DataC_Prison_Cell_sRoom
.IMPORT DataC_Prison_Crossroad_sRoom
.IMPORT DataC_Prison_East_sRoom
.IMPORT DataC_Prison_Escape_sRoom
.IMPORT DataC_Prison_Flower_sRoom
.IMPORT DataC_Prison_Upper_sRoom
.IMPORT DataC_Sewer_Ascent_sRoom
.IMPORT DataC_Sewer_Basin_sRoom
.IMPORT DataC_Sewer_Flower_sRoom
.IMPORT DataC_Sewer_Pool_sRoom
.IMPORT DataC_Sewer_Trap_sRoom
.IMPORT DataC_Sewer_West_sRoom
.IMPORT DataC_Shadow_Entry_sRoom
.IMPORT DataC_Shadow_Teleport_sRoom
.IMPORT DataC_Temple_Altar_sRoom
.IMPORT DataC_Temple_Apse_sRoom
.IMPORT DataC_Temple_Entry_sRoom
.IMPORT DataC_Temple_Flower_sRoom
.IMPORT DataC_Temple_Foyer_sRoom
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
.IMPORT Func_ProcessFrame
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceBlockCol_u8_arr
.IMPORT Ram_DeviceBlockRow_u8_arr
.IMPORT Ram_DeviceTarget_byte_arr
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
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarExit_ePassage
.IMPORTZP Zp_AvatarPlatformIndex_u8
.IMPORTZP Zp_Camera_bScroll
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_FloatingHud_bHud
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_RoomShake_u8

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

.SEGMENT "PRG8"

;;; Queues up the music for the specified room (if it's not already playing),
;;; switches PRGC banks, then loads and initializes data for the room.
;;; @prereq Rendering is disabled.
;;; @param X The eRoom value for the room to load.
.EXPORT FuncM_SwitchPrgcAndLoadRoom
.PROC FuncM_SwitchPrgcAndLoadRoom
    jsr_prga FuncA_Room_ChooseMusicForRoom  ; preserves X, returns Y
    .assert * = FuncM_SwitchPrgcAndLoadRoomWithMusic, error
.ENDPROC

;;; Queues up the specified music (if it's not already playing), switches PRGC
;;; banks, then loads and initializes data for the specified room.
;;; @prereq Rendering is disabled.
;;; @param X The eRoom value for the room to load.
;;; @param Y The eMusic value for the music to play in the new room.
.EXPORT FuncM_SwitchPrgcAndLoadRoomWithMusic
.PROC FuncM_SwitchPrgcAndLoadRoomWithMusic
_ChangeMusicIfNeeded:
    ;; If the music will be different in the new room, then we need to disable
    ;; audio before performing the PRGC bank switch (since the old music may be
    ;; in the old PRGC bank).
    cpy Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    beq @done
    sty Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    lda #0
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Enable_bool
    txa  ; eRoom to load
    pha  ; eRoom to load
    jsr Func_ProcessFrame
    lda #$ff
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Enable_bool
    pla  ; eRoom to load
    tax  ; eRoom to load
    @done:
_LoadNewRoom:
    prga_bank #<.bank(DataA_Room_Banks_u8_arr)
    prgc_bank DataA_Room_Banks_u8_arr, x
    jmp FuncA_Room_Load
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Pointers and PRGC bank numbers for sRoom structs for all rooms in the game,
;;; indexed by eRoom values.
.REPEAT 3, table
    D_TABLE_LO table, DataA_Room_Table_sRoom_ptr_0_arr
    D_TABLE_HI table, DataA_Room_Table_sRoom_ptr_1_arr
    D_TABLE_BANK table, DataA_Room_Banks_u8_arr
    D_TABLE .enum, eRoom
    d_entry table, BossCity,        DataC_Boss_City_sRoom
    d_entry table, BossCrypt,       DataC_Boss_Crypt_sRoom
    d_entry table, BossGarden,      DataC_Boss_Garden_sRoom
    d_entry table, BossMine,        DataC_Boss_Mine_sRoom
    d_entry table, BossShadow,      DataC_Boss_Shadow_sRoom
    d_entry table, BossTemple,      DataC_Boss_Temple_sRoom
    d_entry table, CityBuilding1,   DataC_City_Building1_sRoom
    d_entry table, CityBuilding2,   DataC_City_Building2_sRoom
    d_entry table, CityBuilding4,   DataC_City_Building4_sRoom
    d_entry table, CityBuilding5,   DataC_City_Building5_sRoom
    d_entry table, CityBuilding6,   DataC_City_Building6_sRoom
    d_entry table, CityBuilding7,   DataC_City_Building7_sRoom
    d_entry table, CityCenter,      DataC_City_Center_sRoom
    d_entry table, CityDrain,       DataC_City_Drain_sRoom
    d_entry table, CityDump,        DataC_City_Dump_sRoom
    d_entry table, CityEast,        DataC_City_East_sRoom
    d_entry table, CityFlower,      DataC_City_Flower_sRoom
    d_entry table, CityOutskirts,   DataC_City_Outskirts_sRoom
    d_entry table, CityPit,         DataC_City_Pit_sRoom
    d_entry table, CityWest,        DataC_City_West_sRoom
    d_entry table, CoreBoss,        DataC_Core_Boss_sRoom
    d_entry table, CoreEast,        DataC_Core_East_sRoom
    d_entry table, CoreElevator,    DataC_Core_Elevator_sRoom
    d_entry table, CoreFlower,      DataC_Core_Flower_sRoom
    d_entry table, CoreJunction,    DataC_Core_Junction_sRoom
    d_entry table, CoreLock,        DataC_Core_Lock_sRoom
    d_entry table, CoreSouth,       DataC_Core_South_sRoom
    d_entry table, CoreWest,        DataC_Core_West_sRoom
    d_entry table, CryptCenter,     DataC_Crypt_Center_sRoom
    d_entry table, CryptChains,     DataC_Crypt_Chains_sRoom
    d_entry table, CryptEast,       DataC_Crypt_East_sRoom
    d_entry table, CryptEscape,     DataC_Crypt_Escape_sRoom
    d_entry table, CryptFlower,     DataC_Crypt_Flower_sRoom
    d_entry table, CryptGallery,    DataC_Crypt_Gallery_sRoom
    d_entry table, CryptLanding,    DataC_Crypt_Landing_sRoom
    d_entry table, CryptNest,       DataC_Crypt_Nest_sRoom
    d_entry table, CryptNorth,      DataC_Crypt_North_sRoom
    d_entry table, CryptSouth,      DataC_Crypt_South_sRoom
    d_entry table, CryptSpiral,     DataC_Crypt_Spiral_sRoom
    d_entry table, CryptTomb,       DataC_Crypt_Tomb_sRoom
    d_entry table, CryptWest,       DataC_Crypt_West_sRoom
    d_entry table, FactoryAccess,   DataC_Factory_Access_sRoom
    d_entry table, FactoryBridge,   DataC_Factory_Bridge_sRoom
    d_entry table, FactoryCenter,   DataC_Factory_Center_sRoom
    d_entry table, FactoryElevator, DataC_Factory_Elevator_sRoom
    d_entry table, FactoryFlower,   DataC_Factory_Flower_sRoom
    d_entry table, FactoryLock,     DataC_Factory_Lock_sRoom
    d_entry table, FactoryPass,     DataC_Factory_Pass_sRoom
    d_entry table, FactoryUpper,    DataC_Factory_Upper_sRoom
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
    d_entry table, LavaCenter,      DataC_Lava_Center_sRoom
    d_entry table, LavaEast,        DataC_Lava_East_sRoom
    d_entry table, LavaFlower,      DataC_Lava_Flower_sRoom
    d_entry table, LavaShaft,       DataC_Lava_Shaft_sRoom
    d_entry table, LavaStation,     DataC_Lava_Station_sRoom
    d_entry table, LavaTeleport,    DataC_Lava_Teleport_sRoom
    d_entry table, LavaWest,        DataC_Lava_West_sRoom
    d_entry table, MermaidCellar,   DataC_Mermaid_Cellar_sRoom
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
    d_entry table, MermaidSpring,   DataC_Mermaid_Spring_sRoom
    d_entry table, MermaidVillage,  DataC_Mermaid_Village_sRoom
    d_entry table, MineCollapse,    DataC_Mine_Collapse_sRoom
    d_entry table, MineDrift,       DataC_Mine_Drift_sRoom
    d_entry table, MineEast,        DataC_Mine_East_sRoom
    d_entry table, MineEntry,       DataC_Mine_Entry_sRoom
    d_entry table, MineFlower,      DataC_Mine_Flower_sRoom
    d_entry table, MinePit,         DataC_Mine_Pit_sRoom
    d_entry table, MineSouth,       DataC_Mine_South_sRoom
    d_entry table, MineWest,        DataC_Mine_West_sRoom
    d_entry table, PrisonCell,      DataC_Prison_Cell_sRoom
    d_entry table, PrisonCrossroad, DataC_Prison_Crossroad_sRoom
    d_entry table, PrisonEast,      DataC_Prison_East_sRoom
    d_entry table, PrisonEscape,    DataC_Prison_Escape_sRoom
    d_entry table, PrisonFlower,    DataC_Prison_Flower_sRoom
    d_entry table, PrisonUpper,     DataC_Prison_Upper_sRoom
    d_entry table, SewerAscent,     DataC_Sewer_Ascent_sRoom
    d_entry table, SewerBasin,      DataC_Sewer_Basin_sRoom
    d_entry table, SewerFlower,     DataC_Sewer_Flower_sRoom
    d_entry table, SewerPool,       DataC_Sewer_Pool_sRoom
    d_entry table, SewerTrap,       DataC_Sewer_Trap_sRoom
    d_entry table, SewerWest,       DataC_Sewer_West_sRoom
    d_entry table, ShadowEntry,     DataC_Shadow_Entry_sRoom
    d_entry table, ShadowTeleport,  DataC_Shadow_Teleport_sRoom
    d_entry table, TempleAltar,     DataC_Temple_Altar_sRoom
    d_entry table, TempleApse,      DataC_Temple_Apse_sRoom
    d_entry table, TempleEntry,     DataC_Temple_Entry_sRoom
    d_entry table, TempleFlower,    DataC_Temple_Flower_sRoom
    d_entry table, TempleFoyer,     DataC_Temple_Foyer_sRoom
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

;;; Chooses the music that should play in the specified room, based partly on
;;; the current progress flags.  The room does *not* need to be loaded already,
;;; nor its PRGC bank set.
;;; @param X The eRoom value for the room to choose music for.
;;; @return Y The eMusic value for the music to play in the specified room.
;;; @preserve X
.PROC FuncA_Room_ChooseMusicForRoom
    ldy DataA_Room_DefaultMusic_eMusic_arr, x
_PrisonMusic:
    ;; When returning to the Prison Caves after escaping, play the Prison2
    ;; music instead of Prison1.
    cpy #eMusic::Prison1
    bne @done
    flag_bit Sram_ProgressFlags_arr, eFlag::GardenLandingDroppedIn
    beq @done
    ldy #eMusic::Prison2
    @done:
    rts
.ENDPROC

;;; Maps from eRoom values to the default eMusic to play in each room.
.PROC DataA_Room_DefaultMusic_eMusic_arr
    D_ARRAY .enum, eRoom
    d_byte BossCity,        eMusic::Boss1
    d_byte BossCrypt,       eMusic::Boss1
    d_byte BossGarden,      eMusic::Boss1
    d_byte BossMine,        eMusic::Boss1
    d_byte BossShadow,      eMusic::Boss1
    d_byte BossTemple,      eMusic::Boss1
    d_byte CityBuilding1,   eMusic::Silence
    d_byte CityBuilding2,   eMusic::Silence
    d_byte CityBuilding4,   eMusic::Silence
    d_byte CityBuilding5,   eMusic::Silence
    d_byte CityBuilding6,   eMusic::Silence
    d_byte CityBuilding7,   eMusic::Silence
    d_byte CityCenter,      eMusic::Silence
    d_byte CityDrain,       eMusic::Silence
    d_byte CityDump,        eMusic::Silence
    d_byte CityEast,        eMusic::Silence
    d_byte CityFlower,      eMusic::Silence
    d_byte CityOutskirts,   eMusic::Silence
    d_byte CityPit,         eMusic::Silence
    d_byte CityWest,        eMusic::Silence
    d_byte CoreBoss,        eMusic::Silence
    d_byte CoreEast,        eMusic::Silence
    d_byte CoreElevator,    eMusic::Silence
    d_byte CoreFlower,      eMusic::Silence
    d_byte CoreJunction,    eMusic::Silence
    d_byte CoreLock,        eMusic::Silence
    d_byte CoreSouth,       eMusic::Silence
    d_byte CoreWest,        eMusic::Silence
    d_byte CryptCenter,     eMusic::Crypt
    d_byte CryptChains,     eMusic::Crypt
    d_byte CryptEast,       eMusic::Crypt
    d_byte CryptEscape,     eMusic::Crypt
    d_byte CryptFlower,     eMusic::Crypt
    d_byte CryptGallery,    eMusic::Crypt
    d_byte CryptLanding,    eMusic::Crypt
    d_byte CryptNest,       eMusic::Crypt
    d_byte CryptNorth,      eMusic::Crypt
    d_byte CryptSouth,      eMusic::Crypt
    d_byte CryptSpiral,     eMusic::Crypt
    d_byte CryptTomb,       eMusic::Crypt
    d_byte CryptWest,       eMusic::Crypt
    d_byte FactoryAccess,   eMusic::Silence
    d_byte FactoryBridge,   eMusic::Silence
    d_byte FactoryCenter,   eMusic::Silence
    d_byte FactoryElevator, eMusic::Silence
    d_byte FactoryFlower,   eMusic::Silence
    d_byte FactoryLock,     eMusic::Silence
    d_byte FactoryPass,     eMusic::Silence
    d_byte FactoryUpper,    eMusic::Silence
    d_byte FactoryWest,     eMusic::Silence
    d_byte GardenCrossroad, eMusic::Silence
    d_byte GardenEast,      eMusic::Silence
    d_byte GardenFlower,    eMusic::Silence
    d_byte GardenHallway,   eMusic::Silence
    d_byte GardenLanding,   eMusic::Silence
    d_byte GardenShaft,     eMusic::Silence
    d_byte GardenShrine,    eMusic::Silence
    d_byte GardenTower,     eMusic::Silence
    d_byte GardenTunnel,    eMusic::Silence
    d_byte LavaCenter,      eMusic::Silence
    d_byte LavaEast,        eMusic::Silence
    d_byte LavaFlower,      eMusic::Silence
    d_byte LavaShaft,       eMusic::Silence
    d_byte LavaStation,     eMusic::Silence
    d_byte LavaTeleport,    eMusic::Silence
    d_byte LavaWest,        eMusic::Silence
    d_byte MermaidCellar,   eMusic::Silence
    d_byte MermaidEast,     eMusic::Silence
    d_byte MermaidElevator, eMusic::Silence
    d_byte MermaidEntry,    eMusic::Silence
    d_byte MermaidFlower,   eMusic::Silence
    d_byte MermaidHut1,     eMusic::Silence
    d_byte MermaidHut2,     eMusic::Silence
    d_byte MermaidHut3,     eMusic::Silence
    d_byte MermaidHut4,     eMusic::Silence
    d_byte MermaidHut5,     eMusic::Silence
    d_byte MermaidHut6,     eMusic::Silence
    d_byte MermaidSpring,   eMusic::Silence
    d_byte MermaidVillage,  eMusic::Silence
    d_byte MineCollapse,    eMusic::Mine
    d_byte MineDrift,       eMusic::Mine
    d_byte MineEast,        eMusic::Mine
    d_byte MineEntry,       eMusic::Mine
    d_byte MineFlower,      eMusic::Mine
    d_byte MinePit,         eMusic::Mine
    d_byte MineSouth,       eMusic::Mine
    d_byte MineWest,        eMusic::Mine
    d_byte PrisonCell,      eMusic::Prison1
    d_byte PrisonCrossroad, eMusic::Prison2
    d_byte PrisonEast,      eMusic::Prison2
    d_byte PrisonEscape,    eMusic::Prison1
    d_byte PrisonFlower,    eMusic::Prison2
    d_byte PrisonUpper,     eMusic::Prison2
    d_byte SewerAscent,     eMusic::Silence
    d_byte SewerBasin,      eMusic::Silence
    d_byte SewerFlower,     eMusic::Silence
    d_byte SewerPool,       eMusic::Silence
    d_byte SewerTrap,       eMusic::Silence
    d_byte SewerWest,       eMusic::Silence
    d_byte ShadowEntry,     eMusic::Silence
    d_byte ShadowTeleport,  eMusic::Silence
    d_byte TempleAltar,     eMusic::Temple
    d_byte TempleApse,      eMusic::Temple
    d_byte TempleEntry,     eMusic::Temple
    d_byte TempleFlower,    eMusic::Temple
    d_byte TempleFoyer,     eMusic::Temple
    d_byte TempleNave,      eMusic::Temple
    d_byte TemplePit,       eMusic::Temple
    d_byte TempleSpire,     eMusic::Temple
    d_byte TempleWest,      eMusic::Temple
    d_byte TownHouse1,      eMusic::Silence
    d_byte TownHouse2,      eMusic::Silence
    d_byte TownHouse3,      eMusic::Silence
    d_byte TownHouse4,      eMusic::Silence
    d_byte TownHouse5,      eMusic::Silence
    d_byte TownHouse6,      eMusic::Silence
    d_byte TownOutdoors,    eMusic::Silence
    D_END
.ENDPROC

;;; Loads and initializes data for the specified room.
;;; @prereq The correct PRGC bank has been set for the room to be loaded.
;;; @param X The eRoom value for the room to load.
.PROC FuncA_Room_Load
    lda Zp_Current_eRoom
    sta Zp_Previous_eRoom
    stx Zp_Current_eRoom
_CopyRoomStruct:
    ;; Get a pointer to the sRoom struct and store it in T1T0.
    lda DataA_Room_Table_sRoom_ptr_0_arr, x
    sta T0
    lda DataA_Room_Table_sRoom_ptr_1_arr, x
    sta T1
    ;; Copy the sRoom struct into Zp_Current_sRoom.
    ldy #.sizeof(sRoom) - 1
    @loop:
    lda (T1T0), y
    sta Zp_Current_sRoom, y
    dey
    .assert .sizeof(sRoom) <= $80, error
    bpl @loop
_CopyTilesetStruct:
    ;; Copy the current room's Terrain_sTileset_ptr into T1T0.
    ldy #sRoomExt::Terrain_sTileset_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    ;; Copy the sTileset struct into Zp_Current_sTileset.
    ldy #.sizeof(sTileset) - 1
    @loop:
    lda (T1T0), y
    sta Zp_Current_sTileset, y
    dey
    .assert .sizeof(sTileset) <= $80, error
    bpl @loop
_ClearRoomState:
    lda #0
    ldx #kRoomStateSize
    @loop:
    dex
    sta Zp_RoomState, x
    bne @loop
_LoadPlatforms:
    ;; Copy the current room's Platforms_sPlatform_arr_ptr into T1T0.
    ldy #sRoomExt::Platforms_sPlatform_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    ;; Copy room platform structs into platform RAM.
    ldx #0  ; platform index
    .assert kMaxPlatforms * .sizeof(sPlatform) < $100, error
    ldy #0  ; byte offset into Platforms_sPlatform_arr_ptr
    @copyLoop:
    .assert sPlatform::Type_ePlatform = 0, error
    lda (T1T0), y
    .assert ePlatform::None = 0, error
    beq @copyDone
    sta Ram_PlatformType_ePlatform_arr, x
    iny
    .assert sPlatform::WidthPx_u16 = 1, error
    lda (T1T0), y
    sta T2  ; platform width (lo)
    iny
    lda (T1T0), y
    sta T3  ; platform width (hi)
    iny
    .assert sPlatform::HeightPx_u8 = 3, error
    lda (T1T0), y
    sta T4  ; platform height
    iny
    .assert sPlatform::Left_i16 = 4, error
    lda (T1T0), y
    sta Ram_PlatformLeft_i16_0_arr, x
    add T2  ; platform width (lo)
    sta Ram_PlatformRight_i16_0_arr, x
    iny
    lda (T1T0), y
    sta Ram_PlatformLeft_i16_1_arr, x
    adc T3  ; platform width (hi)
    sta Ram_PlatformRight_i16_1_arr, x
    iny
    .assert sPlatform::Top_i16 = 6, error
    lda (T1T0), y
    sta Ram_PlatformTop_i16_0_arr, x
    add T4  ; platform height
    sta Ram_PlatformBottom_i16_0_arr, x
    iny
    lda (T1T0), y
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
    ;; Copy the current room's Actors_sActor_arr_ptr into T1T0.
    ldy #sRoomExt::Actors_sActor_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    ;; Copy room actor structs into actor RAM.
    ldx #0  ; actor index
    .assert kMaxActors * .sizeof(sActor) < $100, error
    ldy #0  ; byte offset into Actors_sActor_arr_ptr
    @copyLoop:
    ;; Actor type:
    .assert sActor::Type_eActor = 0, error
    lda (T1T0), y
    .assert eActor::None = 0, error
    beq @copyDone
    sta Ram_ActorType_eActor_arr, x
    iny
    ;; X-position:
    .assert sActor::PosX_i16 = 1, error
    lda (T1T0), y
    iny
    sta Ram_ActorPosX_i16_0_arr, x
    lda (T1T0), y
    iny
    sta Ram_ActorPosX_i16_1_arr, x
    ;; Y-position:
    .assert sActor::PosY_i16 = 3, error
    lda (T1T0), y
    iny
    sta Ram_ActorPosY_i16_0_arr, x
    lda (T1T0), y
    iny
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Temporarily store param byte in Ram_ActorState1_byte_arr:
    .assert sActor::Param_byte = 5, error
    lda (T1T0), y
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
    ;; Copy the current room's Devices_sDevice_arr_ptr into T1T0.
    ldy #sRoomExt::Devices_sDevice_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    ;; Copy room device structs into device RAM.
    ldx #0  ; device index
    .assert kMaxDevices * .sizeof(sDevice) < $100, error
    ldy #0  ; byte offset into Devices_sDevice_arr_ptr
    @copyLoop:
    .assert sDevice::Type_eDevice = 0, error
    lda (T1T0), y
    .assert eDevice::None = 0, error
    beq @copyDone
    sta Ram_DeviceType_eDevice_arr, x
    iny
    .assert sDevice::BlockRow_u8 = 1, error
    lda (T1T0), y
    sta Ram_DeviceBlockRow_u8_arr, x
    iny
    .assert sDevice::BlockCol_u8 = 2, error
    lda (T1T0), y
    sta Ram_DeviceBlockCol_u8_arr, x
    iny
    .assert sDevice::Target_byte = 3, error
    lda (T1T0), y
    sta Ram_DeviceTarget_byte_arr, x
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
    stx Zp_Camera_bScroll
    stx Zp_RoomShake_u8
    dex  ; now X is $ff
    stx Zp_AvatarPlatformIndex_u8
    stx Zp_ConsoleMachineIndex_u8
    stx Zp_FloatingHud_bHud  ; disable the floating HUD
    rts
.ENDPROC

;;; Calls the current room's Tick_func_ptr function.
.EXPORT FuncA_Room_CallRoomTick
.PROC FuncA_Room_CallRoomTick
    ldy #sRoomExt::Tick_func_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    jmp (T1T0)
.ENDPROC

;;;=========================================================================;;;
