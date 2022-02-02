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

.INCLUDE "../src/macros.inc"

;;;=========================================================================;;;

.SEGMENT "HEADER"
    ;; See https://cc65.github.io/doc/sim65.html#toc5
    .byte "sim65"
    .byte 2      ; version
    .byte 0      ; CPU type (0 = 6502)
    .byte Zp_SyscallStackPtr
    .addr $1000  ; load address
    .addr $1000  ; reset address

;;;=========================================================================;;;

.ZEROPAGE

Zp_SyscallStackPtr: .res 2

Zp_Expected_byte: .res 1
Zp_Actual_byte: .res 1

;;;=========================================================================;;;

.BSS

Ram_SyscallStack: .res $10

Ram_PrintBuffer_arr: .res $80

;;;=========================================================================;;;

.CODE

Data_StrExpected: .asciiz "failed: expected $"
Data_StrActual: .asciiz " but got $"

;;; Terminates the print buffer with a newline, then writes the contents of the
;;; print buffer to stderr.
;;; @param Y The current index into Ram_PrintBuffer_arr.
.PROC Func_WriteBuffer
    lda #$0a  ; '\n'
    sta Ram_PrintBuffer_arr, y
    iny
    ldax #2  ; FD (2 = stderr)
    stax Ram_SyscallStack + 2
    ldax #Ram_PrintBuffer_arr
    stax Ram_SyscallStack + 0
    ldax #Ram_SyscallStack
    stax Zp_SyscallStackPtr
    ldx #0
    tya  ; length in bytes
    jmp $fff7  ; write syscall
.ENDPROC

;;; Appends a single hex digit to the print buffer.
;;; @param A Hex digit value from 0-f.
;;; @param Y The current index into Ram_PrintBuffer_arr.
;;; @return Y The new index into Ram_PrintBuffer_arr.
.PROC Func_BufferHexDigit
    cmp #9
    bge _Letter
    add #$30  ; '0'
    bne _Buffer  ; unconditional
_Letter:
    add #$57  ; 'a' - $a
_Buffer:
    sta Ram_PrintBuffer_arr, y
    iny
    rts
.ENDPROC

;;; Appends the value of A to the print buffer as two hex digits.
;;; @param A The value to serialize into Ram_PrintBuffer_arr as hex.
;;; @param Y The current index into Ram_PrintBuffer_arr.
;;; @return Y New index into Ram_PrintBuffer_arr.
.PROC Func_BufferHexByte
    tax
    .repeat 4
    lsr a
    .endrepeat
    jsr Func_BufferHexDigit
    txa
    and #$0f
    jmp Func_BufferHexDigit
.ENDPROC

;;; Prints and exits with an error if A does not equal Y.
;;; @param A The actual value.
;;; @param Y The expected value.
.EXPORT Func_ExpectAEqualsY
.PROC Func_ExpectAEqualsY
    sty Zp_Expected_byte
    cmp Zp_Expected_byte
    bne _Failure
    rts
_Failure:
    sta Zp_Actual_byte
    ldy #0
_CopyStrExpected:
    ldx #0
    @loop:
    lda Data_StrExpected, x
    beq @break
    sta Ram_PrintBuffer_arr, y
    iny
    inx
    bne @loop  ; unconditional
    @break:
_SerializeExpected:
    lda Zp_Expected_byte
    jsr Func_BufferHexByte
_CopyStrActual:
    ldx #0
    @loop:
    lda Data_StrActual, x
    beq @break
    sta Ram_PrintBuffer_arr, y
    iny
    inx
    bne @loop  ; unconditional
    @break:
_SerializeActual:
    lda Zp_Actual_byte
    jsr Func_BufferHexByte
_Finish:
    jsr Func_WriteBuffer
    .assert * = Exit_Failure, error, "fallthrough"
.ENDPROC

;;; Exits the process with a failing error code.
.PROC Exit_Failure
    lda #1
    jmp $fff9  ; exit process with A as the status code (error if nonzero)
.ENDPROC

;;; Exits the process with a succesful error code.
.EXPORT Exit_Success
.PROC Exit_Success
    lda #0
    jmp $fff9  ; exit process with A as the status code (error if nonzero)
.ENDPROC

;;;=========================================================================;;;
