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

#=============================================================================#

PATTERNS = [
    ('incorrect ZP export', re.compile(r'\.EXPORT +Zp')),
    ('incorrect ZP import', re.compile(r'\.IMPORT +Zp')),
    ('indented .DIRECTIVE', re.compile(r'^ +\.[A-Z]')),
    ('over-long line', re.compile(r'^.{80,}\n$')),
    ('suspicious address', re.compile(
        r'^ *(ad[cd]|and|cmp|cp[xy]|eor|ora|sub|sbc|ld[a-z]+) +[a-z0-9$%.]')),
    ('tab character', re.compile(r'\t')),
    ('unindented .directive', re.compile(r'^\.[a-z]')),
]

IMPORT_PATTERN = re.compile(r'^\.IMPORT(?:ZP)? +(.+)$')

#=============================================================================#

def run_tests():
    num_passed = 0
    num_failed = 0
    # Check for suspicious regex patterns.
    for (message, pattern) in PATTERNS:
        num_matches = 0
        for (dirpath, dirnames, filenames) in os.walk('src'):
            for filename in filenames:
                if not (filename.endswith('.asm') or
                        filename.endswith('.inc')):
                    continue
                filepath = os.path.join(dirpath, filename)
                for (line_number, line) in enumerate(open(filepath)):
                    if pattern.search(line):
                        if num_matches == 0:
                            print('LINT: found ' + message)
                        num_matches += 1
                        print('  {}:{}:'.format(filepath, line_number + 1))
                        print('    ' + line.strip())
        if num_matches == 0: num_passed += 1
        else: num_failed += 1
    # Check imports within each ASM file.
    for (dirpath, dirnames, filenames) in os.walk('src'):
        for filename in filenames:
            if not filename.endswith('.asm'): continue
            imports = []
            filepath = os.path.join(dirpath, filename)
            for line in open(filepath):
                match = IMPORT_PATTERN.match(line)
                if match:
                    imports.append(match.group(1))
            # Check that the imports are sorted.
            if imports == sorted(imports):
                num_passed += 1
            else:
                num_failed += 1
                print('LINT: unsorted imports in ' + filepath)
            # Check that all imports are used.
            num_unused = 0
            for identifier in imports:
                for line in open(filepath):
                    if not IMPORT_PATTERN.match(line) and identifier in line:
                        break
                else:
                    num_unused += 1
                    print('LINT: unused import {} in {}'
                          .format(identifier, filepath))
            if num_unused == 0: num_passed += 1
            else: num_failed += 1
    print('lint: {} passed, {} failed'.format(num_passed, num_failed))
    return (num_passed, num_failed)

if __name__ == '__main__':
    run_tests()

#=============================================================================#
