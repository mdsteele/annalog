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
    ('mixed-case .directive', re.compile(r'^ *\.([A-Z]+[a-z]|[a-z]+[A-Z])')),
    ('multiple exports per line', re.compile(r'\.EXPORT[^;]*,')),
    ('multiple imports per line', re.compile(r'\.IMPORT[^;]*,')),
    ('over-long line', re.compile(r'^.{80,}\n$')),
    ('@preserves instead of @preserve', re.compile(r'@preserves')),
    ('@returns instead of @return', re.compile(r'@returns')),
    ('tab character', re.compile(r'\t')),
    ('trailing whitespace', re.compile(r' $')),
    ('unindented .directive', re.compile(r'^\.[a-z]')),
    ('wrong comment style',
     re.compile(r'^[ \t]+;;;|^;;[^;]|^[ \t]*; |^[^;]*[^;: \t][^;]*;;')),
]

EXPORT_PATTERN = re.compile(r'^\.EXPORT(?:ZP)? +([A-Za-z0-9_]+)(?: *;.*)?$')

IMPORT_PATTERN = re.compile(r'^\.IMPORT(?:ZP)? +([A-Za-z0-9_]+)(?: *;.*)?$')

INCLUDE_PATTERN = re.compile(r'^\.INCLUDE +"([^"]+)"')

USE_PATTERN = re.compile(r'[^.A-Za-z0-9_]([A-Z][A-Za-z0-9_]+)')

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

def run_tests():
    failed = [False]
    files = {}
    errors = {}
    all_imports = set()
    for filepath in src_and_test_filepaths('.asm', '.inc'):
        includes = []
        imports = []
        exports = set()
        uses = set()
        def fail(message, examples=()):
            failed[0] = True
            print('STYLE: found {} in {}'.format(message, filepath))
            for example in examples:
                print('  {}'.format(example))
        for (line_number, line) in enumerate(open(filepath)):
            def add_error(message):
                if message not in errors:
                    errors[message] = []
                errors[message].append((filepath, line_number, line.strip()))
            # Check for style errors.
            for (message, pattern) in PATTERNS:
                if pattern.search(line):
                    add_error(message)
            # Collect includes within each ASM file.
            match = INCLUDE_PATTERN.match(line)
            if match:
                if not filepath.endswith('.asm'):
                    add_error('.INCLUDE in non-ASM file')
                else:
                    include = match.group(1)
                    # Check that nothing is imported twice.
                    if include in includes:
                        add_error('repeated .INCLUDE')
                    else:
                        includes.append(include)
                continue
            # Collect imports within each ASM file.
            match = IMPORT_PATTERN.match(line)
            if match:
                if not filepath.endswith('.asm'):
                    add_error('.IMPORT in non-ASM file')
                else:
                    identifier = match.group(1)
                    # Check that nothing is imported twice.
                    if identifier in imports:
                        add_error('repeated .IMPORT')
                    else:
                        imports.append(identifier)
                        all_imports.add(identifier)
                continue
            # Collect exports within each ASM file.
            match = EXPORT_PATTERN.match(line)
            if match:
                if not filepath.endswith('.asm'):
                    add_error('.EXPORT in non-ASM file')
                else:
                    identifier = match.group(1)
                    # Check that nothing is exported twice.
                    if identifier in exports:
                        add_error('repeated .EXPORT')
                    else:
                        exports.add(identifier)
                continue
            # Check which imports are used.
            for match in USE_PATTERN.finditer(line.split(';', 1)[0]):
                uses.add(match.group(1))
        files[filepath] = {'exports': exports}
        # Check that the includes are sorted.
        if includes != sorted(includes):
            fail('unsorted includes')
        # Check that the imports are sorted.
        if imports != sorted(imports):
            fail('unsorted imports')
        # Check that all imports are used.
        unused_imports = [ident for ident in imports if ident not in uses]
        if unused_imports:
            fail('unused imports', unused_imports)
    # Check that all exports are imported.
    for (filepath, data) in files.items():
        unused_exports = set()
        for identifier in data['exports']:
            if identifier not in all_imports:
                unused_exports.add(identifier)
        if unused_exports:
            failed[0] = True
            print('STYLE: found unused exports in {}'.format(filepath))
            for identifier in sorted(unused_exports):
                print('  {}'.format(identifier))
    # Report errors.
    for (message, examples) in errors.items():
        failed[0] = True
        print('STYLE: found {}'.format(message))
        for (filepath, line_number, line) in examples:
            print('  {}:{}:'.format(filepath, line_number + 1))
            print('    {}'.format(line))
    return failed[0]

if __name__ == '__main__':
    sys.exit(run_tests())

#=============================================================================#
