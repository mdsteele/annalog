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

;;; The height of a "tall" room, in blocks.  A "short" room is
;;; kScreenHeightBlocks = 15 blocks tall, fitting vertically in the first
;;; nametable.  A "tall" room extends into the top portion of the second
;;; nametable by (kTallRoomHeightBlocks - kScreenHeightBlocks) = 9 blocks.
kTallRoomHeightBlocks = 24

kTallRoomHeightTiles = kTallRoomHeightBlocks * 2

;;; Some parts of the code assume that a room tile column fits in one byte.
;;; This puts the maximum width of a room at 8 screens, which is plenty wide.
kMaxRoomWidthTiles = $100
kMaxRoomWidthBlocks = kMaxRoomWidthTiles / 2

;;; How many bytes of RAM are reserved for room-specific state.
kRoomStateSize = $100

;;;=========================================================================;;;

;;; The list of rooms in the game.
.ENUM eRoom
    CryptFlower
    GardenBoss
    GardenLanding
    GardenShrine
    MermaidFlower
    MermaidHouse1
    PrisonCell
    PrisonEscape
    PrisonTunnel
    TownHouse1
    TownHouse2
    TownOutdoors
    NUM_VALUES
.ENDENUM

.DEFINE kNumRooms 12
.ASSERT kNumRooms = eRoom::NUM_VALUES, error

;;;=========================================================================;;;

;;; Specifies which side of the room a given passage is on.
.ENUM ePassage
    None       = 0
    Top        = %01000000
    Bottom     = %01100000
    Western    = %10000000
    Eastern    = %10100000
.ENDENUM

;;; Specifies a particular passage exit from a room.  The three highest bits
;;; specify the side of the room the passage is on (as an ePassage value), and
;;; the three lowest bits specify which screen of the room the passage is on:
;;;     * For east/west passages in short rooms, the screen number is 0.
;;;     * For east/west passages in tall rooms, the screen number is 0 for the
;;;       top half of the room, or 1 for the bottom half.
;;;     * For up/down passages, the screen number is 0 for the westernmost
;;;       screen of the room, and (N - 1) for the easternmost screen of a room
;;;       that's N screens wide.
.SCOPE bPassage
    EastWest   = %10000000  ; if set, this is an east/west passage
    UpDown     = %01000000  ; if set, this is an up/down passage
    SideMask   = %11100000  ; bits used for the ePassage value
    ScreenMask = %00000111  ; bits used for the screen number
.ENDSCOPE

;;; Stores attributes for a particular passage exit from a room.
.STRUCT sPassage
    ;; Where in the room the exit is (which side and which screen number).
    Exit_bPassage      .byte
    ;; The number (in pixels) to add to Zp_AvatarPosY_i16 (for east/west
    ;; passages) or Zp_AvatarPosX_i16 (for up/down passages) when transitioning
    ;; through this exit, in order to line up with the entrance in the other
    ;; room.
    PositionAdjust_i16 .word
    ;; The room number that this passage leads to.
    Destination_eRoom  .byte
.ENDSTRUCT

;;;=========================================================================;;;

;;; Stores basic information about a single room.
.STRUCT sRoom
    ;; The minimum permitted scroll X-coordinate, in pixels.
    ;;     * If the room has no passages on the western edge, this should be 0.
    ;;     * If the room does have a western passage, this should generally be
    ;;       either 8 or 16.
    MinScrollX_u8             .byte
    ;; The maximum permitted scroll X-coordinate, in pixels.  If the terrain
    ;; data is N blocks wide, then:
    ;;     * If the room has no passages on the eastern edge, this should be
    ;;       equal to (N - kScreenWidthBlocks) * kBlockWidthPx.
    ;;     * If the room does have an eastern passage, this should be equal to
    ;;       (N - kScreenWidthBlocks - 1) * kBlockWidthPx, so that the last
    ;;       terrain column will be hidden offscreen.
    MaxScrollX_u16            .word
    ;; True ($ff) if the room is "tall" (kTallRoomHeightBlocks blocks tall), or
    ;; false ($00) if it is short (kScreenHeightBlocks blocks tall).
    IsTall_bool               .byte
    ;; The minimap row number for the room (if it's a short room) or for the
    ;; top half of the room (if it's a tall room).
    MinimapStartRow_u8        .byte
    ;; The minimap column number for the leftmost screen of the room.
    MinimapStartCol_u8        .byte
    ;; How many minimap columns this room spans (1-8).
    MinimapWidth_u8           .byte
    ;; A pointer to the terrain block data for this room, which stores 1 byte
    ;; per block in column-major order.  For "short" rooms, new columns start
    ;; every 16 bytes; for "tall" rooms, new columns start every 24 bytes.
    TerrainData_ptr           .addr
    ;; The number of entries in the Machines_sMachine_arr_ptr array.  This must
    ;; be no greater than kMaxMachines.
    NumMachines_u8            .byte
    ;; A pointer to the machine data array for this room.
    Machines_sMachine_arr_ptr .addr
    ;; The default CHR18 bank number to set for this room.  The room's
    ;; Init_func_ptr can modify this in Zp_Current_sRoom to override the
    ;; default.
    Chr18Bank_u8              .byte
    ;; Function to call each frame to update room state.
    Tick_func_ptr             .addr
    ;; Function to call each frame to draw room decor (e.g. for bosses).  When
    ;; this is called, the PRGA bank will be set to PRGA_Objects.
    Draw_func_ptr             .addr
    ;; Extended information about the room.
    Ext_sRoomExt_ptr          .addr
.ENDSTRUCT

;;; Extended information about a room that (compared to the information in
;;; sRoom) doesn't need to be as directly accessible from Zp_Current_sRoom.
.STRUCT sRoomExt
    ;; A pointer to a $ff-terminated string with the name of the area that this
    ;; room belongs to.
    AreaName_u8_arr_ptr         .addr
    ;; A pointer to a $ff-terminated array of row/col pairs listing the minimap
    ;; cells that constitute the area that this room belongs to.
    AreaCells_u8_arr2_arr_ptr   .addr
    ;; A pointer to the tileset used for this room's terrain.
    Terrain_sTileset_ptr        .addr
    ;; A pointer to a static array of platforms that should always be loaded
    ;; into the room upon entering, terminated by an ePlatform::None byte.  The
    ;; dynamic set of platforms can optionally be modified afterwards by the
    ;; room's Init_func_ptr.
    Platforms_sPlatform_arr_ptr .addr
    ;; A pointer to a static array of actors that should always be loaded into
    ;; the room upon entering, terminated by an eActor::None byte.  The dynamic
    ;; set of actors can optionally be modified afterwards by the room's
    ;; Init_func_ptr.
    Actors_sActor_arr_ptr       .addr
    ;; A pointer to a static array of devices that should always be loaded into
    ;; the room upon entering, terminated by an eDevice::None byte.  The
    ;; dynamic set of devices can optionally be modified afterwards by the
    ;; room's Init_func_ptr.
    Devices_sDevice_arr_ptr     .addr
    ;; A pointer to an array of pointers to dialogs used in this room.
    Dialogs_sDialog_ptr_arr_ptr .addr
    ;; A pointer to the list of passage exits from this room.
    Passages_sPassage_arr_ptr   .addr
    ;; Function to initialize room-specific state when entering the room.
    Init_func_ptr               .addr
.ENDSTRUCT

;;;=========================================================================;;;
