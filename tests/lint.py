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

def run_tests():
    num_passed = 0
    num_failed = 0
    # Check for suspicious regex patterns.
    for (message, pattern) in PATTERNS:
        num_matches = 0
        for filepath in src_and_test_filepaths('.asm', '.inc'):
            for (line_number, line) in enumerate(open(filepath)):
                if pattern.search(line):
                    if num_matches == 0:
                        print('LINT: found ' + message)
                    num_matches += 1
                    print('  {}:{}:'.format(filepath, line_number + 1))
                    print('    ' + line.strip())
        if num_matches == 0: num_passed += 1
        else: num_failed += 1
    print('lint: {} passed, {} failed'.format(num_passed, num_failed))
    return (num_passed, num_failed)

if __name__ == '__main__':
    sys.exit(run_tests()[1])

#=============================================================================#
