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
    ('indented .DIRECTIVE', re.compile(r'^ +\.[A-Z]')),
    ('over-long line', re.compile(r'^.{80,}\n$')),
    ('tab character', re.compile(r'\t')),
    ('unindented .directive', re.compile(r'^\.[a-z]')),
    ('wrong comment style',
     re.compile(r'^ +;;;|^;;[^;]|^ *; |^[^;]*[^; ][^;]*;;')),
]

IMPORT_PATTERN = re.compile(r'^\.IMPORT(?:ZP)? +(.+)$')

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
                        print('STYLE: found ' + message)
                    num_matches += 1
                    print('  {}:{}:'.format(filepath, line_number + 1))
                    print('    ' + line.strip())
        if num_matches == 0: num_passed += 1
        else: num_failed += 1
    # Check imports within each ASM file.
    for filepath in src_and_test_filepaths('.asm'):
        imports = []
        for line in open(filepath):
            match = IMPORT_PATTERN.match(line)
            if match:
                imports.append(match.group(1))
        # Check that the imports are sorted.
        if imports == sorted(imports):
            num_passed += 1
        else:
            num_failed += 1
            print('STYLE: unsorted imports in ' + filepath)
        # Check that all imports are used.
        num_unused = 0
        for identifier in imports:
            for line in open(filepath):
                if not IMPORT_PATTERN.match(line) and identifier in line:
                    break
            else:
                num_unused += 1
                print('STYLE: unused import {} in {}'
                      .format(identifier, filepath))
        if num_unused == 0: num_passed += 1
        else: num_failed += 1
    print('style: {} passed, {} failed'.format(num_passed, num_failed))
    return (num_passed, num_failed)

if __name__ == '__main__':
    sys.exit(run_tests()[1])

#=============================================================================#
