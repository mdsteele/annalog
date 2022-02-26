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

PATTERNS = [
    ('incorrect ZP export', re.compile(r'\.EXPORT +Zp')),
    ('incorrect ZP import', re.compile(r'\.IMPORT +Zp')),
    ('suspicious address', re.compile(
        r'^ *(ad[cd]|and|cmp|cp[xy]|eor|ora|sub|sbc|ld[a-z]+) +'
        r'([a-z0-9$%.]|Func|Main)')),
]

SEGMENT_DECL_PATTERN = re.compile(r'^\.SEGMENT +"([a-zA-Z0-9_]*)"')
PROC_DECL_PATTERN = re.compile(r'^\.PROC +([a-zA-Z0-9_]+)')
BANK_SWITCH_PATTERN = re.compile(r'^ *(?:prga|prgc)_bank ')

LOCAL_PROC_NAME = re.compile(r'^_[a-zA-Z0-9_]+$')  # e.g. _Foobar
PRGA_PROC_NAME = re.compile(  # e.g. FuncA_SegmentName_Foobar
    '^(?:DataA|FuncA|MainA)_([a-zA-Z0-9]+)_[a-zA-Z0-9_]+$')
PRGC_PROC_NAME = re.compile(  # e.g. DataC_SegmentName_Foobar_sBaz_arr
    '^(?:DataC|FuncC|MainC)_([a-zA-Z0-9]+)_[a-zA-Z0-9_]+$')
UNBANKED_PROC_NAME = re.compile(  # e.g. Main_Foobar
    '^(?:Data|Exit|Func|Int|Main|Ppu|Sram)_[a-zA-Z0-9_]+$')

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
            for (message, pattern) in PATTERNS:
                if pattern.search(line):
                    fail(message)
            match = SEGMENT_DECL_PATTERN.match(line)
            if match:
                segment = match.group(1)
            match = PROC_DECL_PATTERN.match(line)
            if match:
                proc = match.group(1)
                if not is_valid_proc_name_for_segment(proc, segment):
                    fail('misnamed proc for segment {}'.format(segment))
                if not proc.startswith('_'):
                    top_proc = proc
            match = BANK_SWITCH_PATTERN.match(line)
            if match:
                if not top_proc.startswith('Main_'):
                    fail('bank switch not in a Main'.format(top_proc))
    return failed[0]

if __name__ == '__main__':
    sys.exit(run_tests())

#=============================================================================#
