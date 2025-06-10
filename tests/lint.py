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
    # This pattern matches instructions using indirect addressing on e.g. T0
    # instead of T1T0.
    ('one-byte T register as address', re.compile(
        r'^ *(ad[cd]|and|cmp|eor|jmp|lda|ora|sbc|sub|sta) +\( *T[0-9] *[),]')),
    # This pattern matches 16-bit load/store macros (e.g. ldax) using e.g. T0
    # instead of T1T0.
    ('one-byte T register as two-byte operand', re.compile(
        r'^ *(ld|st)[axy][axy] +T[0-9][^T]')),
    # This pattern matches instructions that were probably intended to use
    # immediate addressing.
    ('suspicious address', re.compile(
        r'^ *(ad[cd]|and|cmp|cp[xy]|eor|ora|sub|sbc|ld[a-z]+) +'
        r'[-+~<>(]*([a-z0-9$%.]|Func|Main)')),
    # This pattern matches instructions that were probably intended to use
    # zero page indirect Y-indexed addressing.
    ('suspicious direct Y-index', re.compile(
        r'^ *(ad[cd]|and|cmp|eor|lda|ora|sub|sbc|sta) +'
        r'(Zp_[A-Za-z0-9_]+_ptr|T[0-9]T[0-9]), *[yY]')),
]

BEGIN_PATTERN = re.compile(r'^ *;+ *@begin +([a-zA-Z0-9_]+)')
END_PATTERN = re.compile(r'^ *;+ *@end +([a-zA-Z0-9_]+)')
COMMENT_PATTERN = re.compile(r'^ *;')

LOADED_PREREQ_PATTERN = re.compile(
    '^;;; @prereq (PRG[AC]_[A-Za-z0-9]+) is loaded.$')
THREAD_ANNOTATION_PATTERN = re.compile(
    '^;;; @thread ([A-Z]+(?: *, *[A-Z]+)*)$')
SEGMENT_DECL_PATTERN = re.compile(r'^\.SEGMENT +"([a-zA-Z0-9_]*)"')
PROC_DECL_PATTERN = re.compile(r'^\.PROC +([a-zA-Z0-9_]+)')
D_STRUCT_PATTERN = re.compile(r'^:? *D_STRUCT +(s[a-zA-Z0-9_]+)')
PRG_BANK_SWITCH_PATTERN = re.compile(
    r'^ *((?:jsr|jmp|main)_prg[ac]) ')
MAIN_CHR_BANK_SWITCH_PATTERN = re.compile(
    r'^ *(main_chr[01][048c](?:_bank)?) ')
IRQ_CHR_BANK_SWITCH_PATTERN = re.compile(
    r'^ *(irq_chr[01][048c](?:_bank)?) ')
JUMP_PATTERN = re.compile(
    r'^ *([jb](?:mp|sr|cc|cs|eq|ne|mi|pl|vc|vs|le|lt|ge|gt)|fall) +'
    r'([A-Za-z0-9_]+)')
ACCESS_PATTERN = re.compile(
    r'^ *(ad[cd]|and|asl|bit|cmp|cp[xy]|dec|eor|inc|ld[axy]+|lsr|ora'
    r'|ro[lr]|r?sbc|r?sub|st[axy]+) +([A-Za-z0-9_]+)')
FUNC_PTR_PATTERN = re.compile(
    r'^ *d_addr +([a-zA-Z0-9_]+)_func_ptr, *([a-zA-Z0-9_]+)')

LOCAL_PROC_NAME = re.compile(r'^_[a-zA-Z0-9_]+$')  # e.g. _Foobar
PRGA_PROC_NAME = re.compile(  # e.g. FuncA_SegmentName_Foobar
    '^(?:DataA|FuncA|MainA)_([a-zA-Z0-9]+)_[a-zA-Z0-9_]+$')
PRGC_PROC_NAME = re.compile(  # e.g. DataC_SegmentName_Foobar_sBaz_arr
    '^(?:DataC|FuncC|MainC)_([a-zA-Z0-9]+)_[a-zA-Z0-9_]+$')
UNBANKED_PROC_NAME = re.compile(  # e.g. Main_Foobar
    '^(?:Data|Exit|Func|FuncM|Int|Main|Ppu|Ram|Sram)_[a-zA-Z0-9_]+$')

#=============================================================================#

def src_and_test_entries():
    for entry in os.walk('nsf'):
        yield entry
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

def is_valid_access(dest, segment, loaded_prereqs, permitted_threads,
                    top_proc):
    if LOCAL_PROC_NAME.match(dest):
        return True
    if (dest == 'Hw_Channels_sChanRegs_arr5' or dest.startswith('Hw_Noise') or
        dest.startswith('Hw_Dmc') or dest.startswith('Hw_Apu')):
        return bool(permitted_threads & {'AUDIO', 'RESET'})
    if dest.startswith('Zp_AudioTmp'):
        return bool(permitted_threads & {'AUDIO', 'NMI'})
    if dest == 'Ram_Audio_sChanSfx_arr':
        return bool(permitted_threads & {'AUDIO', 'NMI', 'RESET'})
    if dest == 'Zp_Next_sChanSfx_arr':
        return bool(permitted_threads & {'MAIN', 'NMI'})
    if dest == 'Zp_Active_sIrq':
        return bool(permitted_threads & {'IRQ', 'NMI', 'RESET'})
    if dest == 'Zp_Buffered_sIrq':
        return bool(permitted_threads & {'MAIN', 'NMI'})
    if dest == 'Zp_NextIrq_int_ptr':
        return bool(permitted_threads & {'IRQ', 'NMI', 'RESET'})
    if dest == 'Zp_IrqTmp_byte':
        return bool(permitted_threads & {'IRQ'})
    match = PRGA_PROC_NAME.match(dest)
    if match:
        if top_proc.startswith('Func_'):
            return False
        if segment.startswith('PRGA_'):
            return match.group(1) == segment[5:]
        if segment.startswith('PRGC_'):
            return f'PRGA_{match.group(1)}' in loaded_prereqs
        return True
    match = PRGC_PROC_NAME.match(dest)
    if match:
        if top_proc.startswith('Func_'):
            return False
        if segment.startswith('PRGA_'):
            return f'PRGC_{match.group(1)}' in loaded_prereqs
        if segment.startswith('PRGC_'):
            return match.group(1) == segment[5:]
    return True

def is_valid_func_ptr(struct_type, field_name, dest, segment, top_proc):
    if LOCAL_PROC_NAME.match(dest):
        return True
    if dest.startswith('Func_'):
        return True
    match = PRGC_PROC_NAME.match(dest)
    if match:
        if segment.startswith('PRGC_'):
            return match.group(1) == segment[5:]
        return False
    match = PRGA_PROC_NAME.match(dest)
    if match:
        bank = match.group(1)
        if struct_type == 'sBoss':
            if field_name == 'Draw':
                return bank == 'Objects'
            if field_name == 'Tick':
                return bank == 'Room'
            return False
        if struct_type == 'sMachine':
            if field_name == 'Draw':
                return bank == 'Objects'
            if field_name == 'Init':
                return bank == 'Room'
            if field_name == 'Reset':
                return bank == 'Room'
            if field_name == 'Tick':
                return bank == 'Machine'
            if field_name == 'TryAct':
                return bank == 'Machine'
            if field_name == 'TryMove':
                return bank == 'Machine'
            if field_name == 'WriteReg':
                return bank == 'Machine'
            return False
        if struct_type == 'sRoomExt':
            if field_name == 'Draw':
                return bank == 'Objects'
            if field_name == 'Enter':
                return bank == 'Room'
            if field_name == 'FadeIn':
                return bank == 'Terrain'
            if field_name == 'Tick':
                return bank == 'Room'
            return False
        return False
    return False

#=============================================================================#

def run_tests():
    failed = [False]
    for filepath in src_and_test_filepaths('.asm', '.inc'):
        segment = ''
        last_d_struct = ''
        proc_stack = []
        dialog_text_lines = []
        loaded_prereqs = set()
        permitted_threads = {'MAIN'}
        sorted_lines = None
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
            # Track regions of code that should be in sorted order.
            match = END_PATTERN.match(line)
            if match and match.group(1) == 'SORTED':
                if sorted_lines is None:
                    fail('mismatched @end SORTED')
                else:
                    if sorted_lines != sorted(sorted_lines):
                        fail('unsorted SORTED region')
                    sorted_lines = None
            if sorted_lines is not None and not COMMENT_PATTERN.match(line):
                sorted_lines.append(line.strip())
            match = BEGIN_PATTERN.match(line)
            if match and match.group(1) == 'SORTED':
                if sorted_lines is not None:
                    fail('nested SORTED region')
                else:
                    sorted_lines = []
            # Keep track of which segment we're in.
            match = SEGMENT_DECL_PATTERN.match(line)
            if match:
                segment = match.group(1)
            # Keep track of prereqs for loaded banks.
            match = LOADED_PREREQ_PATTERN.match(line)
            if match:
                loaded_prereqs.add(match.group(1))
            # Keep track of thread annotations.
            match = THREAD_ANNOTATION_PATTERN.match(line)
            if match:
                permitted_threads = set(
                    name.strip() for name in match.group(1).split(','))
            # Track D_STRUCT declarations.
            match = D_STRUCT_PATTERN.match(line)
            if match:
                last_d_struct = match.group(1)
            # Check proc definitions.
            match = PROC_DECL_PATTERN.match(line)
            if match:
                proc = match.group(1)
                if not proc_stack:
                    dialog_text_lines = []
                    # Check that top-level procs are named correctly for their
                    # segment.
                    if not is_valid_proc_name_for_segment(proc, segment):
                        fail('misnamed proc for segment {}'.format(segment))
                    # All Int_ functions must be for IRQ or for NMI only.
                    if (proc.startswith('Int_') and
                        'IRQ' not in permitted_threads and
                        'NMI' not in permitted_threads):
                        fail(f'Int_ function on {permitted_threads} threads')
                proc_stack.append(proc)
            if line.startswith('.ENDPROC'):
                proc_stack.pop()
                if not proc_stack:
                    loaded_prereqs.clear()
                    permitted_threads = {'MAIN'}
            if proc_stack:
                # Check that PRG bank-switches only happen in Main or FuncM
                # procs.
                match = PRG_BANK_SWITCH_PATTERN.match(line)
                if match:
                    kind = match.group(1)
                    if not (proc_stack[0].startswith('Main_') or
                            proc_stack[0].startswith('FuncM_') or
                            (proc_stack[0].startswith('MainC_') and
                             'prga' in kind)):
                        fail('{} in {}'.format(kind, proc_stack[0]))
                # Check that main-thread CHR bank-switches don't happen within
                # interrupts.
                match = MAIN_CHR_BANK_SWITCH_PATTERN.match(line)
                if match:
                    kind = match.group(1)
                    if proc_stack[0].startswith('Int'):
                        fail('{} in {}'.format(kind, proc_stack[0]))
                # Check that IRQ-thread CHR bank-switches only happen within
                # interrupts.
                match = IRQ_CHR_BANK_SWITCH_PATTERN.match(line)
                if match:
                    kind = match.group(1)
                    if not proc_stack[0].startswith('Int'):
                        fail('{} in {}'.format(kind, proc_stack[0]))
                # Check that procs don't jump incorrectly to other procs.
                match = JUMP_PATTERN.match(line)
                if match:
                    opcode = match.group(1)
                    dest = match.group(2)
                    if dest.startswith('Main'):
                        if opcode == 'jsr':
                            fail('call to a Main')
                        elif not proc_stack[0].startswith('Main'):
                            fail('jump to a Main outside of a Main')
                    elif dest.startswith('Int'):
                        if opcode == 'jsr':
                            fail('call to an Int')
                        elif not proc_stack[0].startswith('Int'):
                            fail('jump to an Int outside of an Int')
                    if not is_valid_access(dest, segment, loaded_prereqs,
                                           permitted_threads, proc_stack[0]):
                        fail('invalid {} from {}'.format(
                            opcode, proc_stack[0]))
                # Check that procs don't read/write things they can't or
                # shouldn't access.
                match = ACCESS_PATTERN.match(line)
                if match:
                    source = match.group(2)
                    if not is_valid_access(source, segment, loaded_prereqs,
                                           permitted_threads, proc_stack[0]):
                        fail('invalid access in {}'.format(proc_stack[0]))
                # Check that function pointers in structs are in valid banks.
                match = FUNC_PTR_PATTERN.match(line)
                if match:
                    field_name = match.group(1)
                    dest = match.group(2)
                    if not is_valid_func_ptr(last_d_struct, field_name, dest,
                                             segment, proc_stack[0]):
                        fail('invalid func ptr in {}'.format(proc_stack[0]))
    return failed[0]

if __name__ == '__main__':
    sys.exit(run_tests())

#=============================================================================#
