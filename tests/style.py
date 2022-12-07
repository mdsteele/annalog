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
    ('trailing whitespace', re.compile(r' $')),
    ('unindented .directive', re.compile(r'^\.[a-z]')),
    ('wrong comment style',
     re.compile(r'^[ \t]+;;;|^;;[^;]|^[ \t]*; |^[^;]*[^; \t][^;]*;;')),
]

IMPORT_PATTERN = re.compile(r'^\.IMPORT(?:ZP)? +(.+)$')

INCLUDE_PATTERN = re.compile(r'^\.INCLUDE +"([^"]+)"')

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
    failed = False
    # Check for suspicious regex patterns.
    for (message, pattern) in PATTERNS:
        num_matches = 0
        for filepath in src_and_test_filepaths('.asm', '.inc'):
            for (line_number, line) in enumerate(open(filepath)):
                if pattern.search(line):
                    failed = True
                    if num_matches == 0:
                        print('STYLE: found ' + message)
                    num_matches += 1
                    print('  {}:{}:'.format(filepath, line_number + 1))
                    print('    ' + line.strip())
    # Check imports within each ASM file.
    for filepath in src_and_test_filepaths('.asm'):
        imports = []
        repeated_imports = []
        for line in open(filepath):
            match = IMPORT_PATTERN.match(line)
            if match:
                identifier = match.group(1)
                if identifier in imports:
                    repeated_imports.append(identifier)
                imports.append(identifier)
        # Check that nothing is imported twice.
        if repeated_imports:
            failed = True
            print('STYLE: repeated imports in {}'.format(filepath))
            for identifier in repeated_imports:
                print('    {}'.format(identifier))
        # Check that the imports are sorted.
        if imports != sorted(imports):
            failed = True
            print('STYLE: unsorted imports in ' + filepath)
        # Check that all imports are used.
        unused_imports = []
        for identifier in imports:
            for line in open(filepath):
                if IMPORT_PATTERN.match(line): continue
                if identifier in line.split(';', 1)[0]: break
            else:
                unused_imports.append(identifier)
        if unused_imports:
            failed = True
            print('STYLE: unused imports in {}'.format(filepath))
            for identifier in unused_imports:
                print('    {}'.format(identifier))
    # Check includes within each ASM file.
    for filepath in src_and_test_filepaths('.asm'):
        includes = []
        for line in open(filepath):
            match = INCLUDE_PATTERN.match(line)
            if match:
                includes.append(match.group(1))
        # Check that the includes are sorted.
        if includes != sorted(includes):
            failed = True
            print('STYLE: unsorted includes in ' + filepath)
    return failed

if __name__ == '__main__':
    sys.exit(run_tests())

#=============================================================================#
