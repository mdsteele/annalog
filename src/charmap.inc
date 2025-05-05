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

;;; BG tile IDs for font characters.
kTileIdBgFontLowerFirst     = $20
kTileIdBgFontUpperFirst     = $40
kTileIdBgFontCopyrightFirst = $ae

.CHARMAP $20, $00  ; ' '
.CHARMAP $60, $40  ; '`'
.CHARMAP $21, $41  ; '!'
.CHARMAP $3f, $42  ; '?'
.CHARMAP $2e, $43  ; '.'
.CHARMAP $3a, $44  ; ':'
.CHARMAP $2c, $45  ; ','
.CHARMAP $27, $46  ; "'"
.CHARMAP $2f, $47  ; '/'
.CHARMAP $2b, $4e  ; '+'
.CHARMAP $2d, $4f  ; '-'
.CHARMAP $3c, $4a  ; '<'
.CHARMAP $3d, $48  ; '='
.CHARMAP $3e, $4c  ; '>'

kTileIdBgCmpNe = $49
kTileIdBgCmpLe = $4b
kTileIdBgCmpGe = $4d

.CHARMAP $30, $50  ; '0'
.CHARMAP $31, $51  ; '1'
.CHARMAP $32, $52  ; '2'
.CHARMAP $33, $53  ; '3'
.CHARMAP $34, $54  ; '4'
.CHARMAP $35, $55  ; '5'
.CHARMAP $36, $56  ; '6'
.CHARMAP $37, $57  ; '7'
.CHARMAP $38, $58  ; '8'
.CHARMAP $39, $59  ; '9'

.CHARMAP $41, $60  ; 'A'
.CHARMAP $42, $61  ; 'B'
.CHARMAP $43, $62  ; 'C'
.CHARMAP $44, $63  ; 'D'
.CHARMAP $45, $64  ; 'E'
.CHARMAP $46, $65  ; 'F'
.CHARMAP $47, $66  ; 'G'
.CHARMAP $48, $67  ; 'H'
.CHARMAP $49, $68  ; 'I'
.CHARMAP $4a, $69  ; 'J'
.CHARMAP $4b, $6a  ; 'K'
.CHARMAP $4c, $6b  ; 'L'
.CHARMAP $4d, $6c  ; 'M'
.CHARMAP $4e, $6d  ; 'N'
.CHARMAP $4f, $6e  ; 'O'
.CHARMAP $50, $6f  ; 'P'
.CHARMAP $51, $70  ; 'Q'
.CHARMAP $52, $71  ; 'R'
.CHARMAP $53, $72  ; 'S'
.CHARMAP $54, $73  ; 'T'
.CHARMAP $55, $74  ; 'U'
.CHARMAP $56, $75  ; 'V'
.CHARMAP $57, $76  ; 'W'
.CHARMAP $58, $77  ; 'X'
.CHARMAP $59, $78  ; 'Y'
.CHARMAP $5a, $79  ; 'Z'

.CHARMAP $61, $20  ; 'a'
.CHARMAP $62, $21  ; 'b'
.CHARMAP $63, $22  ; 'c'
.CHARMAP $64, $23  ; 'd'
.CHARMAP $65, $24  ; 'e'
.CHARMAP $66, $25  ; 'f'
.CHARMAP $67, $26  ; 'g'
.CHARMAP $68, $27  ; 'h'
.CHARMAP $69, $28  ; 'i'
.CHARMAP $6a, $29  ; 'j'
.CHARMAP $6b, $2a  ; 'k'
.CHARMAP $6c, $2b  ; 'l'
.CHARMAP $6d, $2c  ; 'm'
.CHARMAP $6e, $2d  ; 'n'
.CHARMAP $6f, $2e  ; 'o'
.CHARMAP $70, $2f  ; 'p'
.CHARMAP $71, $30  ; 'q'
.CHARMAP $72, $31  ; 'r'
.CHARMAP $73, $32  ; 's'
.CHARMAP $74, $33  ; 't'
.CHARMAP $75, $34  ; 'u'
.CHARMAP $76, $35  ; 'v'
.CHARMAP $77, $36  ; 'w'
.CHARMAP $78, $37  ; 'x'
.CHARMAP $79, $38  ; 'y'
.CHARMAP $7a, $39  ; 'z'

kTileIdBgArrowUp    = $7c
kTileIdBgArrowRight = $7d
kTileIdBgArrowDown  = $7e
kTileIdBgArrowLeft  = $7f

;;;=========================================================================;;;
