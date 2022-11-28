#=============================================================================#
# Copyright 2022 Matthew D. Steele <mdsteele@alum.mit.edu>                    #
#                                                                             #
# This file is part of Annalog.                                               #
#                                                                             #
# Annalog is free software: you can redistribute it and/or modify it under    #
# the terms of the GNU General Public License as published by the Free        #
# Software Foundation, either version 3 of the License, or (at your option)   #
# any later version.                                                          #
#                                                                             #
# Annalog is distributed in the hope that it will be useful, but WITHOUT ANY  #
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS   #
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more      #
# details.                                                                    #
#                                                                             #
# You should have received a copy of the GNU General Public License along     #
# with Annalog.  If not, see <http://www.gnu.org/licenses/>.                  #
#=============================================================================#

from __future__ import print_function

import os
import re
import sys

#=============================================================================#

BAD_CODE_PATTERNS = [
    ('incorrect ZP export', re.compile(r'\.EXPORT +Zp')),
    ('incorrect ZP import', re.compile(r'\.IMPORT +Zp')),
    # This pattern matches instructions that were probably intended to use
    # immediate addressing.
    ('suspicious address', re.compile(
        r'^ *(ad[cd]|and|cmp|cp[xy]|eor|ora|sub|sbc|ld[a-z]+) +'
        r'[<>(]*([a-z0-9$%.]|Func|Main)')),
    # This pattern matches instructions that were probably intended to use
    # zero page indirect Y-indexed addressing.
    ('suspicious direct Y-index', re.compile(
        r'^ *(ad[cd]|and|cmp|eor|lda|ora|sub|sbc|sta) +'
        r'Zp_[A-Za-z0-9_]+_ptr, *[yY]'))
]

SEGMENT_DECL_PATTERN = re.compile(r'^\.SEGMENT +"([a-zA-Z0-9_]*)"')
PROC_DECL_PATTERN = re.compile(r'^\.PROC +([a-zA-Z0-9_]+)')
BANK_SWITCH_PATTERN = re.compile(r'^ *((?:prga|prgc)_bank|jsr_prga) ')
JUMP_PATTERN = re.compile(
    r'^ *([jb](?:mp|sr|cc|cs|eq|ne|mi|pl|vc|vs|le|lt|ge|gt)) +'
    r'([A-Za-z0-9_]+)')

LOCAL_PROC_NAME = re.compile(r'^_[a-zA-Z0-9_]+$')  # e.g. _Foobar
PRGA_PROC_NAME = re.compile(  # e.g. FuncA_SegmentName_Foobar
    '^(?:DataA|FuncA|MainA)_([a-zA-Z0-9]+)_[a-zA-Z0-9_]+$')
PRGC_PROC_NAME = re.compile(  # e.g. DataC_SegmentName_Foobar_sBaz_arr
    '^(?:DataC|FuncC|MainC)_([a-zA-Z0-9]+)_[a-zA-Z0-9_]+$')
UNBANKED_PROC_NAME = re.compile(  # e.g. Main_Foobar
    '^(?:Data|Exit|Func|Int|Main|Ppu|Sram)_[a-zA-Z0-9_]+$')

SORT_PATTERNS = [
    ('src/actor.inc', '.ENUM eActor', 'NUM_VALUES', 1),
    ('src/room.inc', '.ENUM eRoom', 'NUM_VALUES', 0),
]

#=============================================================================#

def src_and_test_entries():
    for entry in os.walk('src'):
        yield entry
    for entry in os.walk('tests'):
        yield entry

def src_and_test_filepaths(*exts):
    for (dirpath, dirnames, filenames) in src_and_test_entries():
        for filename in filenames:
            for ext in exts:
                if filename.endswith(ext):
                    yield os.path.join(dirpath, filename)
                    break

#=============================================================================#

def is_valid_proc_name_for_segment(proc, segment):
    if LOCAL_PROC_NAME.match(proc):
        return True
    elif segment.startswith('PRGA_'):
        match = PRGA_PROC_NAME.match(proc)
        if match is None or match.group(1) != segment[5:]:
            return False
    elif segment.startswith('PRGC_'):
        match = PRGC_PROC_NAME.match(proc)
        if match is None or match.group(1) != segment[5:]:
            return False
    elif not UNBANKED_PROC_NAME.match(proc):
        return False
    return True

def is_valid_jump_dest(dest, top_proc, segment):
    if LOCAL_PROC_NAME.match(dest):
        return True
    match = PRGA_PROC_NAME.match(dest)
    if match:
        if top_proc.startswith('Func_'):
            return False
        if segment.startswith('PRGA_') and match.group(1) != segment[5:]:
            return False
    match = PRGC_PROC_NAME.match(dest)
    if match:
        if top_proc.startswith('Func_'):
            return False
        if segment.startswith('PRGA_'):
            return False
        if segment.startswith('PRGC_') and match.group(1) != segment[5:]:
            return False
    return True

#=============================================================================#

def run_tests():
    failed = [False]
    for filepath in src_and_test_filepaths('.asm', '.inc'):
        segment = ''
        top_proc = ''
        for (line_number, line) in enumerate(open(filepath)):
            def fail(message):
                print('LINT: {}:{}: found {}'.format(
                    filepath, line_number + 1, message))
                print('    ' + line.strip())
                failed[0] = True
            # Check for code that is probably a mistake.
            for (message, pattern) in BAD_CODE_PATTERNS:
                if pattern.search(line):
                    fail(message)
            # Keep track of which segment we're in.
            match = SEGMENT_DECL_PATTERN.match(line)
            if match:
                segment = match.group(1)
            # Check proc definitions.
            match = PROC_DECL_PATTERN.match(line)
            if match:
                proc = match.group(1)
                # Check that procs are named correctly for their segment.
                if not is_valid_proc_name_for_segment(proc, segment):
                    fail('misnamed proc for segment {}'.format(segment))
                # Keep track of which top-level proc we're in.
                if not proc.startswith('_'):
                    top_proc = proc
            if top_proc:
                # Check that bank-switches only happen in Main procs.
                match = BANK_SWITCH_PATTERN.match(line)
                if match:
                    kind = match.group(1)
                    if not (top_proc.startswith('Main_') or
                            top_proc.startswith('MainC_') and 'prga' in kind):
                        fail('{} in {}'.format(kind, top_proc))
                # Check that procs don't jump incorrectly to other procs.
                match = JUMP_PATTERN.match(line)
                if match:
                    opcode = match.group(1)
                    dest = match.group(2)
                    if dest.startswith('Main'):
                        if opcode == 'jsr':
                            fail('call to a Main')
                        if not top_proc.startswith('Main'):
                            fail('jump to a Main outside of a Main')
                    if not is_valid_jump_dest(dest, top_proc, segment):
                        fail('invalid {} from {}'.format(
                            opcode, top_proc))
    for (filepath, start_string, end_string, skip) in SORT_PATTERNS:
        def fail(message):
            print('LINT: {}: {}'.format(filepath, message))
            failed[0] = True
        started = False
        ended = False
        lines = []
        for line in open(filepath):
            if not started:
                if start_string in line:
                    started = True
            elif end_string in line:
                ended = True
                break
            else:
                lines.append(line.strip())
        if not started:
            fail('never found {}'.format(start_string))
            continue
        if not ended:
            fail('never found {} after {}'.format(end_string, start_string))
            continue
        lines = lines[skip:]
        if lines != sorted(lines):
            fail('{} is not sorted'.format(start_string))
    return failed[0]

if __name__ == '__main__':
    sys.exit(run_tests())

#=============================================================================#
