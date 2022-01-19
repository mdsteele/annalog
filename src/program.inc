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

.ENUM eOpcode
    Empty = $0  ; (no args)        Jumps to program start (in zero cycles).
    Copy  = $1  ; r, r/i           Sets register to value of second arg.
    Swap  = $2  ; r, r             Swaps values of two registers.
    Add   = $3  ; r, r/i, r/i      Sets register to sum of other args.
    Sub   = $4  ; r, r/i, r/i      Sets register to difference of other args.
    Mul   = $5  ; r, r/i, r/i      Sets register to product of other args.
    Goto  = $6  ; addr             Jumps to an absolute address (0-15).
    Skip  = $7  ; r/i              Skips next N instructions.
    If    = $8  ; oper, r/i, r/i   Skips next instruction if false.
    Til   = $9  ; oper, r/i, r/i   Jumps to prev instruction if false.
    Act   = $a  ; (no args)        Performs machine action (e.g. firing gun).
    Move  = $b  ; dir              Moves machine in the specified direction.
    End   = $e  ; (no args)        Halts the program.
    Nop   = $f  ; (no args)        Does nothing (but still takes a cycle).
.ENDENUM

;;;=========================================================================;;;

;;; One instruction in a program for an in-game machine.
.STRUCT sInst
    ;; For zero- and one-argument opcodes, this is ignored.  For two-argument
    ;; opcodes, the low nibble stores the second argument.  For three-argument
    ;; opcodes, the high nibble stores the second argument, and the low nibble
    ;; stores the third argument.
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
