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

PERMITTED_OOB_CELLS = set([
    ('GardenLanding', (6, 7)),
])

ROOM_PARENTS = {
    'CryptBoss': 'CryptTomb',
    'GardenBoss': 'GardenTower',
    'MermaidCellar': 'MermaidHut4',
    'MermaidHut1': 'MermaidVillage',
    'MermaidHut2': 'MermaidVillage',
    'MermaidHut3': 'MermaidVillage',
    'MermaidHut4': 'MermaidVillage',
    'MermaidHut5': 'MermaidVillage',
    'MermaidHut6': 'MermaidEast',
    'TempleBoss': 'TempleSpire',
    'TownHouse1': 'TownOutdoors',
    'TownHouse2': 'TownOutdoors',
    'TownHouse3': 'TownOutdoors',
    'TownHouse4': 'TownOutdoors',
    'TownHouse5': 'TownOutdoors',
    'TownHouse6': 'TownOutdoors',
}

PASSAGE_SIDE_OPPOSITES = {
    'Bottom': 'Top',
    'Eastern': 'Western',
    'Top': 'Bottom',
    'Western': 'Eastern',
}

ROOM_NAME_RE = re.compile(r'^([A-Z][a-z]*)([A-Z][a-z0-9]*)$')

D_STRUCT_RE = re.compile(r'^:? *D_STRUCT +(s[A-Za-z0-9]+)')

MARKER_ROW_RE = re.compile(r'^ *d_byte +Row_u8, *([0-9]+)')
MARKER_COL_RE = re.compile(
    r'^ *d_byte +Col_u8, *([0-9]+) *; *room: *([A-Za-z0-9]+)')
MARKER_IF_RE = re.compile(r'^ *d_byte +If_eFlag, *(?:0|eFlag::([A-Za-z0-9]+))')
MARKER_NOT_RE = re.compile(r'^ *d_byte +Not_eFlag, *eFlag::([A-Za-z0-9]+)')

MAX_SCROLL_X_RE = re.compile(r'^ *d_word +MaxScrollX_u16,.*\$([0-9a-fA-F]+)')
ROOM_FLAGS_RE = re.compile(r'^ *d_byte +Flags_bRoom, *(.*)eArea::([A-Za-z]+)$')
START_ROW_RE = re.compile(r'^ *d_byte +MinimapStartRow_u8, *([0-9]+)')
START_COL_RE = re.compile(r'^ *d_byte +MinimapStartCol_u8, *([0-9]+)')

DEVICE_TYPE_RE = re.compile(r'^ *d_byte +Type_eDevice, *eDevice::([A-Za-z]+)')
DEVICE_ROW_RE = re.compile(r'^ *d_byte +BlockRow_u8, *([0-9]+)')
DEVICE_COL_RE = re.compile(r'^ *d_byte +BlockCol_u8, *([0-9]+)')
DOOR_TARGET_RE = re.compile(r'^ *d_byte +Target_u8, *eRoom::([A-Za-z0-9]+)')

PASSAGE_EXIT_RE = re.compile(
    r'^ *d_byte Exit_bPassage, *ePassage::([A-Za-z]+) *'
    r'(\| *bPassage::SameScreen *)?\| *([0-9]+)')
PASSAGE_DEST_RE = re.compile(
    r'^ *d_byte Destination_eRoom, *eRoom::(([A-Z][a-z]+)[A-Za-z0-9]+)')

#=============================================================================#

def area_name_from_room_name(room_name):
    match = ROOM_NAME_RE.match(room_name)
    assert match
    return match.group(1)

#=============================================================================#

def read_match_line(file, pattern):
    line = file.readline()
    match = pattern.match(line)
    assert match, '{} doesn\'t match {} in {}'.format(
        repr(line), repr(pattern), file.name)
    return match

def read_int_line(file, pattern, radix=10):
    return int(read_match_line(file, pattern).group(1), radix)

def try_scan_for_match(file, pattern):
    while True:
        line = file.readline()
        if not line: return None
        match = pattern.match(line)
        if match: return match

def scan_for_match(file, pattern):
    match = try_scan_for_match(file, pattern)
    assert match, 'failed to find {} in {}'.format(repr(pattern), file.name)
    return match

def scan_for_int(file, pattern, radix=10):
    return int(scan_for_match(file, pattern).group(1), radix)

#=============================================================================#

def load_minimap():
    minimap = set()
    with open('src/minimap.bg') as file:
        line = file.readline()
        assert line == '@BG 0 0 0 24x15\n'
        while file.readline().startswith('>'): pass
        for row in range(15):
            line = file.readline()
            assert len(line) == 24 * 2 + 1
            for col in range(24):
                if line[(col * 2):(col * 2 + 2)] != 'AA':
                    minimap.add((row, col))
    return minimap

def load_room(filepath, area_name):
    file = open(filepath)
    # Determine the set of minimap cells that this room occupies.
    max_scroll_x = scan_for_int(file, MAX_SCROLL_X_RE, 16)
    room_flags_match = scan_for_match(file, ROOM_FLAGS_RE)
    is_tall = 'bRoom::Tall' in room_flags_match.group(1)
    assert area_name == room_flags_match.group(2)
    start_row = scan_for_int(file, START_ROW_RE)
    start_col = scan_for_int(file, START_COL_RE)
    height = 2 if is_tall else 1
    width = 1 + (max_scroll_x + 128) // 256
    cells = frozenset((row, col)
                      for row in range(start_row, start_row + height)
                      for col in range(start_col, start_col + width))
    # Load the passage data for this room.
    doors = []
    passages = []
    while True:
        match = try_scan_for_match(file, D_STRUCT_RE)
        if not match: break
        struct_type = match.group(1)
        if struct_type == 'sDevice':
            device_type = read_match_line(file, DEVICE_TYPE_RE).group(1)
            if 'Door' not in device_type: continue
            block_row = read_int_line(file, DEVICE_ROW_RE)
            block_col = read_int_line(file, DEVICE_COL_RE)
            door_dest = read_match_line(file, DOOR_TARGET_RE).group(1)
            cell_row = start_row + (1 if is_tall and block_row >= 12 else 0)
            cell_col = start_col + block_col // 16
            doors.append({
                'cell': (cell_row, cell_col),
                'dest_room': door_dest,
            })
        elif struct_type == 'sPassage':
            exit_match = read_match_line(file, PASSAGE_EXIT_RE)
            dest_match = read_match_line(file, PASSAGE_DEST_RE)
            side = exit_match.group(1)
            same_screen = bool(exit_match.group(2))
            screen = int(exit_match.group(3))
            if side == 'Western':
                cell = (start_row + screen, start_col)
            elif side == 'Eastern':
                cell = (start_row + screen, start_col + width)
            elif side == 'Top':
                cell = (start_row, start_col + screen)
            elif side == 'Bottom':
                cell = (start_row + height, start_col + screen)
            else: assert False, side
            passages.append({
                'side': side,
                'same_screen': same_screen,
                'screen': screen,
                'cell': cell,
                'dest_room': dest_match.group(1),
                'dest_area': dest_match.group(2),
            })
    return {
        'area': area_name,
        'cells': cells,
        'doors': doors,
        'passages': passages,
    }

def load_rooms(areas):
    filename_re = re.compile(r'^([a-z]+)_([a-z0-9]+)\.asm$')
    for (dirpath, dirnames, filenames) in os.walk('src/rooms'):
        for filename in filenames:
            match = filename_re.match(filename)
            if not match: continue
            area_name = match.group(1).capitalize()
            room_name = match.group(2).capitalize()
            full_name = area_name + room_name
            filepath = os.path.join(dirpath, filename)
            room = load_room(filepath, area_name)
            areas[area_name]['rooms'][full_name] = room

def load_areas_and_markers():
    data_re = re.compile(
        r'^\.PROC DataA_Pause_(Minimap_sMarker|([A-Z][a-z]+)AreaCells)')
    cell_entry_re = re.compile(r'^ *\.byte +([0-9]+), *([0-9]+)$')
    areas = {}
    file = open('src/minimap.asm')
    while True:
        match = try_scan_for_match(file, data_re)
        assert match
        if match.group(1).endswith('AreaCells'):
            area_name = match.group(2)
            area_cells = []
            while True:
                line = file.readline()
                if '.byte $ff' in line: break
                match = cell_entry_re.match(line)
                assert match, line
                row = int(match.group(1))
                col = int(match.group(2))
                area_cells.append((row, col))
            areas[area_name] = {'cells': area_cells, 'rooms': {}}
        else:
            assert match.group(1) == 'Minimap_sMarker'
            break
    markers = []
    while True:
        match = try_scan_for_match(file, D_STRUCT_RE)
        if not match: break
        assert match.group(1) == 'sMarker'
        row = read_int_line(file, MARKER_ROW_RE)
        match = read_match_line(file, MARKER_COL_RE)
        col = int(match.group(1))
        room = match.group(2)
        if_flag = read_match_line(file, MARKER_IF_RE).group(1) or ''
        not_flag = read_match_line(file, MARKER_NOT_RE).group(1)
        markers.append({
            'cell': (row, col),
            'name': '{}/{}'.format(if_flag, not_flag),
            'room': room,
        })
    load_rooms(areas)
    return areas, markers

#=============================================================================#

def test_area_cells_sorted(areas):
    failed = False
    for area_name, area in areas.items():
        area_cells = area['cells']
        if area_cells != sorted(area_cells):
            print('SCENARIO: {}AreaCells is not sorted'.format(area_name))
            failed = True
    return failed

def test_markers_sorted(markers):
    failed = False
    prev = (0, 0)
    for marker in markers:
        cell = marker['cell']
        if cell < prev:
            print('SCENARIO: marker {} is not in order'.format(marker['name']))
            failed = True
        else: prev = cell
    return failed

def test_minimap_coverage(areas, minimap):
    failed = False
    all_cells = {}
    for area_name, area in areas.items():
        area_cells = area['cells']
        for cell in area_cells:
            if cell not in minimap:
                print('SCENARIO: {} cell {} is blank on minimap'.format(
                    area_name, cell))
                failed = True
            if cell in all_cells:
                print('SCENARIO: minimap cell {} is in both {} and {}'.format(
                    cell, area_name, all_cells[cell]))
                failed = True
            all_cells[cell] = area_name
    for cell in minimap:
        if cell not in all_cells:
            print('SCENARIO: minimap cell {} is not in any area'.format(
                cell))
            failed = True
    return failed

def test_room_cells(areas):
    failed = False
    for area_name, area in areas.items():
        area_rooms = area['rooms']
        area_cells = frozenset(area['cells'])
        covered_area_cells = {}
        for room_name, room in area_rooms.items():
            parent_name = ROOM_PARENTS.get(room_name)
            for cell in room['cells']:
                if cell not in area_cells and \
                   (room_name, cell) not in PERMITTED_OOB_CELLS:
                    print('SCENARIO: {} cell {} is not in {} cells'.format(
                        room_name, cell, area_name))
                    failed = True
                elif parent_name:
                    if cell not in area_rooms[parent_name]['cells']:
                        print('SCENARIO: {} cell {} is not in {} cells'.format(
                            room_name, cell, parent_name))
                        failed = True
                elif cell in covered_area_cells:
                    print('SCENARIO: {} cell {} overlaps with {}'.format(
                        room_name, cell, covered_area_cells[cell]))
                    failed = True
                else:
                    covered_area_cells[cell] = room_name
        # TODO: Once all rooms are added, require all area cells to be covered.
    return failed

def test_room_doors(areas):
    failed = False
    for area_name, area in areas.items():
        for room_name, room in area['rooms'].items():
            for door in room['doors']:
                dest_room_name = door['dest_room']
                dest_room = area['rooms'][dest_room_name]
                for dest_door in dest_room['doors']:
                    if dest_door['dest_room'] != room_name: continue
                    if dest_door['cell'] != door['cell']:
                        print('SCENARIO: {}/{} door cell mismatch'.format(
                            room_name, dest_room_name))
                        failed = True
                    break
                else:
                    print('SCENARIO: {} has door to but not from {}'.format(
                        room_name, dest_room_name))
                    failed = True
    return failed

def test_room_passages(areas):
    failed = False
    for area_name, area in areas.items():
        for room_name, room in area['rooms'].items():
            for passage in room['passages']:
                dest_area = areas[passage['dest_area']]
                dest_room_name = passage['dest_room']
                # TODO: remove this if statement once all rooms are added.
                if dest_room_name == room_name: continue
                dest_room = dest_area['rooms'][dest_room_name]
                side = passage['side']
                for dest_passage in dest_room['passages']:
                    if dest_passage['dest_room'] != room_name: continue
                    if dest_passage['side'] != PASSAGE_SIDE_OPPOSITES[side]:
                        continue
                    if passage['same_screen'] and \
                       dest_passage['screen'] != passage['screen']:
                        continue
                    if (((side == 'Eastern' or side == 'Western') and
                         dest_passage['cell'] != passage['cell']) or
                        ((side == 'Top' or side == 'Bottom') and
                         dest_passage['cell'][1] != passage['cell'][1])):
                        print('SCENARIO: {}/{} passage cell mismatch'.format(
                            room_name, dest_room_name))
                        failed = True
                    break
                else:
                    print('SCENARIO: {} has passage to but not from {}'.format(
                        room_name, dest_room_name))
                    failed = True
    return failed

def test_marker_rooms(areas, markers):
    failed = False
    for marker in markers:
        room_name = marker['room']
        area_name = area_name_from_room_name(room_name)
        area = areas[area_name]
        room = area['rooms'][room_name]
        cell = marker['cell']
        if cell not in room['cells']:
            print('SCENARIO: marker {} cell {} is not in room {}'.format(
                marker['name'], cell, room_name))
            failed = True
    return failed

#=============================================================================#

def run_tests():
    failed = False
    areas, markers = load_areas_and_markers()
    failed |= test_area_cells_sorted(areas)
    failed |= test_markers_sorted(markers)
    minimap = load_minimap()
    failed |= test_minimap_coverage(areas, minimap)
    failed |= test_room_cells(areas)
    failed |= test_room_doors(areas)
    failed |= test_room_passages(areas)
    failed |= test_marker_rooms(areas, markers)
    return failed

#=============================================================================#

if __name__ == '__main__':
    sys.exit(run_tests())

#=============================================================================#
