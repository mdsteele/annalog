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

;;; The maximum number of instructions in a program.
.DEFINE kMaxProgramLength 16

;;;=========================================================================;;;

;;; Opcode values for program instructions.
.ENUM eOpcode
    Empty = $0  ; (no args)        Jumps to program start (in zero cycles).
    Copy  = $1  ; r, r/i           Sets register to value of second arg.
    Sync  = $2  ; (no args)        Pauses until all machines are at a SYNC
    Add   = $3  ; r, r/i, r/i      Sets register to sum of other args.
    Sub   = $4  ; r, r/i, r/i      Sets register to difference of other args.
    Mul   = $5  ; r, r/i, r/i      Sets register to product of other args.
    Goto  = $6  ; addr             Jumps to an absolute address (0-15).
    Skip  = $7  ; r/i              Skips next N instructions.
    If    = $8  ; oper, r/i, r/i   Skips next instruction if false.
    Til   = $9  ; oper, r/i, r/i   Jumps to prev instruction if false.
    Act   = $a  ; (no args)        Performs machine action (e.g. firing gun).
    Move  = $b  ; dir              Moves machine in the specified direction.
    Wait  = $c  ; (no args)        Pauses for a short time.
    Beep  = $d  ; r/i              Plays a sound with one of ten pitches.
    End   = $e  ; (no args)        Halts the program.
    Nop   = $f  ; (no args)        Does nothing (but still takes a cycle).
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; Types of fields that can appear in written program instructions.
.ENUM eField
    Opcode     ; the instruction's opcode
    LValue     ; a writable register
    RValue     ; an immediate value (0-9) or readable register
    Address    ; an instruction number (for GOTO instructions)
    Compare    ; a comparison operator (for IF and TIL instructions)
    Direction  ; a cardinal direction (for MOVE instructions)
    NUM_VALUES
.ENDENUM

;;; Comparison operators that can be used in IF and TIL instructions.
.ENUM eCmp
    Eq  ; equal
    Ne  ; not equal
    Lt  ; less than
    Le  ; less than or equal
    Gt  ; greater than
    Ge  ; greater than or equal
    NUM_VALUES
.ENDENUM

;;; Directions that can be used in MOVE instructions.
.ENUM eDir
    Up
    Down
    Left
    Right
    NUM_VALUES
.ENDENUM

;;; eDir values less than this are vertical.
kFirstHorzDir = eDir::Left

;;;=========================================================================;;;

;;; One instruction in a program for an in-game machine.
.STRUCT sInst
    ;; The low nibble stores the second argument (if any), and the high nibble
    ;; stores the third argument (if any).
    Arg_byte .byte
    ;; The high nibble stores an eOpcode, and the low nibble stores the first
    ;; argument (if any).
    Op_byte  .byte
.ENDSTRUCT

;;; A program for an in-game machine.
.STRUCT sProgram
    ;; The instructions in the program.  The length of the program is the index
    ;; of the first eOpcode::Empty instruction if any, or kMaxProgramLength
    ;; otherwise.
    Code_sInst_arr .res .sizeof(sInst) * kMaxProgramLength
.ENDSTRUCT

;;;=========================================================================;;;

;;; The list of programs in the save file.  Each machine in the game uses one
;;; of these programs, although in a few cases, multiple machines may share the
;;; same program.
.ENUM eProgram
    BossCoreCannon
    BossCryptWinch
    BossGardenCannon
    BossTempleMinigun
    CoreElevatorJet
    CoreLockLift1
    CoreLockLift2
    CoreLockLift3
    CryptFlowerWinch
    CryptGalleryWinch
    CryptNorthLift
    CryptNorthWinch
    CryptSouthWinch
    CryptTombWinch
    CryptWestWinch
    FactoryWestCrane
    GardenCrossroadLift
    GardenEastBridge
    GardenEastCannon
    GardenHallwayLift
    GardenShaftLowerBridge
    GardenShaftUpperBridge
    GardenTowerCannon
    LavaEastUpperBoiler
    LavaEastLowerBoiler
    LavaFlowerBoiler
    LavaStationBoiler
    LavaTeleportField
    LavaWestBoiler
    MermaidDrainPump
    MermaidElevatorJet
    MineCollapseCrane
    MineCollapseTrolley
    MineEastHoist
    MineEastLift
    MineFlowerHoistEast
    MineFlowerHoistWest
    MinePitHoistEast
    MinePitHoistWest
    MineWestCrane
    PrisonCellLauncher
    PrisonCellLift
    PrisonEastLift
    PrisonEscapeTrolley
    SewerFlowerPump
    SewerPoolMultiplexer
    SewerWestMultiplexer
    ShadowTeleportField
    TempleAltarLowerMinigun
    TempleAltarUpperMinigun
    TempleFoyerCarriage
    TempleNaveLowerCarriage
    TempleNaveUpperCarriage
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;
