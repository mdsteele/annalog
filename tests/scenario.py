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

PERMITTED_DOOR_MISMATCHES = {
    'BossGarden': (10, 7),
    'GardenTower': (9, 7),
    'CityBuilding5': (2, 21),
    'CityCenter': (1, 21),
}

PERMITTED_OOB_CELLS = frozenset([
    ('CoreWest',      (3, 10)),
    ('GardenLanding', (6,  7)),
])

PERMITTED_UNCOVERED_CELLS = {
    'Factory': frozenset([(5, 14)]),
    'Garden': frozenset([(4, 6), (5, 6)]),
    'Lava': frozenset([(12, 14)]),
}

ROOM_PARENTS = {
    'BossCity': 'CitySinkhole',
    'BossCrypt': 'CryptTomb',
    'BossGarden': 'GardenTower',
    'BossLava': 'LavaCavern',
    'BossMine': 'MineBurrow',
    'BossShadow': 'ShadowDepths',
    'BossTemple': 'TempleSpire',
    'CityBuilding1': 'CityOutskirts',
    'CityBuilding2': 'CityCenter',
    'CityBuilding3': 'CityCenter',
    'CityBuilding4': 'CityCenter',
    'CityBuilding5': 'CityCenter',
    'CityBuilding6': 'CityCenter',
    'CityBuilding7': 'CityEast',
    'CityFlower': 'CityDump',
    'MermaidCellar': 'MermaidHut4',
    'MermaidHut1': 'MermaidVillage',
    'MermaidHut2': 'MermaidVillage',
    'MermaidHut3': 'MermaidVillage',
    'MermaidHut4': 'MermaidVillage',
    'MermaidHut5': 'MermaidVillage',
    'MermaidHut6': 'MermaidEast',
    'TownHouse1': 'TownOutdoors',
    'TownHouse2': 'TownOutdoors',
    'TownHouse3': 'TownOutdoors',
    'TownHouse4': 'TownOutdoors',
    'TownHouse5': 'TownOutdoors',
    'TownHouse6': 'TownOutdoors',
    'TownSky': 'TownOutdoors',
}

PASSAGE_SIDE_OPPOSITES = {
    'Bottom': 'Top',
    'Eastern': 'Western',
    'Top': 'Bottom',
    'Western': 'Eastern',
}

ROOM_NAME_RE = re.compile(r'^([A-Z][a-z]*)([A-Z][a-z0-9]*)$')

D_STRUCT_RE = re.compile(r'^:? *D_STRUCT +(s[A-Za-z0-9]+)')

FLAG_ENUM_RE = re.compile(r'^\.ENUM +eFlag')
NEWGAME_FLAGS_RE = re.compile(r'^\.PROC +DataA_Avatar_NewGameFlags_eFlag_arr')
NEWGAME_FLAG_RE = re.compile(
    r'^ *\.byte +eFlag::([A-Za-z0-9]+)(?: *; *room: *([A-Za-z0-9]+))?')

MARKER_ROW_RE = re.compile(r'^ *d_byte +Row_u8, *([0-9]+)')
MARKER_COL_RE = re.compile(
    r'^ *d_byte +Col_u8, *([0-9]+) *; *room: *([A-Za-z0-9]+)')
MARKER_IF_RE = re.compile(r'^ *d_byte +If_eFlag, *(?:0|eFlag::([A-Za-z0-9]+))')
MARKER_NOT_RE = re.compile(r'^ *d_byte +Not_eFlag, *eFlag::([A-Za-z0-9]+)')

PAPER_AREA_RE = re.compile(
    r'^ *d_byte *eFlag::(Paper[A-Za-z0-9]+), *eArea::([A-Za-z]+) *'
    r'; *room: *([A-Za-z0-9]+)')
PAPER_TARGET_RE = re.compile(r'^ *d_byte +Target_byte, *eFlag::([A-Za-z0-9]+)')

MAX_SCROLL_X_RE = re.compile(r'^ *d_word +MaxScrollX_u16,.*\$([0-9a-fA-F]+)')
ROOM_FLAGS_RE = re.compile(r'^ *d_byte +Flags_bRoom, *(.*)eArea::([A-Za-z]+)$')
START_ROW_RE = re.compile(r'^ *d_byte +MinimapStartRow_u8, *([0-9]+)')
START_COL_RE = re.compile(r'^ *d_byte +MinimapStartCol_u8, *([0-9]+)')
TERRAIN_TILESET_RE = re.compile(
    r'^ *d_addr +Terrain_sTileset_ptr, *DataA_Room_([A-Za-z]+)_sTileset')

DEVICE_TYPE_RE = re.compile(
    r'^ *d_byte +Type_eDevice, *eDevice::([A-Za-z0-9]+)')
DEVICE_ROW_RE = re.compile(r'^ *d_byte +BlockRow_u8, *([0-9]+)')
DEVICE_COL_RE = re.compile(r'^ *d_byte +BlockCol_u8, *([0-9]+)')
DOOR_TARGET_RE = re.compile(r'^ *d_byte +Target_byte, *eRoom::([A-Za-z0-9]+)')

PASSAGE_EXIT_RE = re.compile(
    r'^ *d_byte Exit_bPassage, *ePassage::([A-Za-z]+) *'
    r'\| *([0-9]+)( *\| *bPassage::Secondary)?')
PASSAGE_DEST_RE = re.compile(
    r'^ *d_byte Destination_eRoom, *eRoom::(([A-Z][a-z]+)[A-Za-z0-9]+)')
PASSAGE_SPAWN_RE = re.compile(r'^ *d_byte SpawnBlock_u8, *([0-9]+)')
PASSAGE_ADJUST_RE = re.compile(
    r'^ *d_byte SpawnAdjust_byte, *\$?([0-9a-fA-F]+)')

#=============================================================================#

def area_name_from_room_name(room_name):
    match = ROOM_NAME_RE.match(room_name)
    assert match
    prgc_name = match.group(1)
    room_name = match.group(2)
    return prgc_name if prgc_name != 'Boss' else room_name

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

def load_all_flags():
    flags = []
    with open('src/flag.inc') as file:
        scan_for_match(file, FLAG_ENUM_RE)
        for line in file:
            assert line, f'unclosed .ENUM eFlag in {file.name}'
            line = line.lstrip()
            if line.startswith(';'): continue
            if line.startswith('.ENDENUM'): break
            flag = line.split(maxsplit=1)[0]
            if flag == 'NUM_VALUES': continue
            flags.append(flag)
    return flags

def load_newgame_flags():
    flags = []
    with open('src/newgame.asm') as file:
        scan_for_match(file, NEWGAME_FLAGS_RE)
        while True:
            match = scan_for_match(file, NEWGAME_FLAG_RE)
            flag = match.group(1)
            room = match.group(2)
            flags.append((flag, room))
            if flag == 'None': break
    return flags

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

def load_papers():
    papers = {}
    with open('src/paper.asm') as file:
        while True:
            match = try_scan_for_match(file, PAPER_AREA_RE)
            if not match: break
            paper_name = match.group(1)
            area_name = match.group(2)
            room_name = match.group(3)
            papers[paper_name] = {'area': area_name, 'room': room_name}
    return papers

def load_room(filepath, prgc_name):
    file = open(filepath)
    # Determine the set of minimap cells that this room occupies.
    max_scroll_x = scan_for_int(file, MAX_SCROLL_X_RE, 16)
    room_flags_match = scan_for_match(file, ROOM_FLAGS_RE)
    is_tall = 'bRoom::Tall' in room_flags_match.group(1)
    area_name = room_flags_match.group(2)
    assert prgc_name == 'Boss' or prgc_name == area_name
    start_row = scan_for_int(file, START_ROW_RE)
    start_col = scan_for_int(file, START_COL_RE)
    height = 2 if is_tall else 1
    width = 1 + (max_scroll_x + 128) // 256
    cells = frozenset((row, col)
                      for row in range(start_row, start_row + height)
                      for col in range(start_col, start_col + width))
    tileset = scan_for_match(file, TERRAIN_TILESET_RE).group(1)
    # Load the passage data for this room.
    devices = []
    doors = []
    papers = []
    passages = []
    while True:
        match = try_scan_for_match(file, D_STRUCT_RE)
        if not match: break
        struct_type = match.group(1)
        if struct_type == 'sDevice':
            device_type = read_match_line(file, DEVICE_TYPE_RE).group(1)
            block_row = read_int_line(file, DEVICE_ROW_RE)
            block_col = read_int_line(file, DEVICE_COL_RE)
            devices.append({
                'type': device_type,
                'block_row': block_row,
                'block_col': block_col,
            })
            if device_type.startswith('Door'):
                door_number = device_type[4]
                assert door_number in '123'
                door_dest = read_match_line(file, DOOR_TARGET_RE).group(1)
                cell_row = start_row + (1 if is_tall and block_row >= 12
                                        else 0)
                cell_col = start_col + (block_col - 1) // 16
                doors.append({
                    'door_number': door_number,
                    'cell': (cell_row, cell_col),
                    'dest_room': door_dest,
                })
            elif device_type == 'Paper' or device_type == 'PaperBg':
                paper_name = scan_for_match(file, PAPER_TARGET_RE).group(1)
                papers.append(paper_name)
        elif struct_type == 'sPassage':
            exit_match = read_match_line(file, PASSAGE_EXIT_RE)
            dest_match = read_match_line(file, PASSAGE_DEST_RE)
            spawn_block = read_int_line(file, PASSAGE_SPAWN_RE)
            spawn_adjust = read_int_line(file, PASSAGE_ADJUST_RE, 16)
            side = exit_match.group(1)
            screen = int(exit_match.group(2))
            secondary = bool(exit_match.group(3))
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
                'screen': screen,
                'secondary': secondary,
                'cell': cell,
                'dest_room': dest_match.group(1),
                'dest_area': dest_match.group(2),
                'spawn_block': spawn_block,
                'spawn_adjust': spawn_adjust,
            })
    return {
        'area': area_name,
        'cells': cells,
        'devices': devices,
        'doors': doors,
        'is_tall': is_tall,
        'max_scroll_x': max_scroll_x,
        'papers': papers,
        'passages': passages,
        'tileset': tileset,
    }

def load_rooms(areas):
    filename_re = re.compile(r'^([a-z]+)_([a-z0-9]+)\.asm$')
    for (dirpath, dirnames, filenames) in os.walk('src/rooms'):
        for filename in filenames:
            match = filename_re.match(filename)
            if not match: continue
            prgc_name = match.group(1).capitalize()
            room_name = match.group(2).capitalize()
            full_name = prgc_name + room_name
            filepath = os.path.join(dirpath, filename)
            room = load_room(filepath, prgc_name)
            areas[room['area']]['rooms'][full_name] = room

def load_areas():
    data_re = re.compile(r'^\.PROC DataA_Pause_([A-Z][a-z]+)AreaCells')
    cell_entry_re = re.compile(r'^ *\.byte +([0-9]+), *([0-9]+)$')
    areas = {}
    file = open('src/area.asm')
    while True:
        match = try_scan_for_match(file, data_re)
        if not match: break
        area_name = match.group(1)
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
    load_rooms(areas)
    return areas

def load_markers():
    file = open('src/marker.asm')
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
            'if_flag': if_flag,
            'not_flag': not_flag,
            'name': '{}/{}'.format(if_flag, not_flag),
            'room': room,
        })
    return markers

def load_tilesets():
    tileset_proc_re = re.compile(r'^\.PROC DataA_Room_([A-Za-z]+)_sTileset$')
    first_solid_re = re.compile(
        r'^ *d_byte +FirstSolidTerrainType_u8,.*\$([0-9a-fA-F]+)')
    file = open('src/tileset.asm')
    tilesets = {}
    while True:
        match = try_scan_for_match(file, tileset_proc_re)
        if not match: break
        name = match.group(1)
        match = scan_for_match(file, D_STRUCT_RE)
        assert match.group(1) == 'sTileset'
        first_solid = scan_for_int(file, first_solid_re, 16)
        tilesets[name] = {
            'first_solid': first_solid,
        }
    return tilesets

def load_all_terrain(areas):
    filename_re = re.compile(r'^([a-z]+)_([a-z0-9]+)\.bg$')
    all_terrain = {}
    for area in areas.values():
        for room_name in area['rooms']:
            filepaths = []
            for (dirpath, dirnames, filenames) in os.walk('src/rooms'):
                for filename in filenames:
                    match = filename_re.match(filename)
                    if not match: continue
                    terrain_name = (match.group(1).capitalize() +
                                    match.group(2).capitalize())
                    if terrain_name.startswith(room_name):
                        filepaths.append(os.path.join(dirpath, filename))
            room_terrain = []
            for filepath in sorted(filepaths):
                room_terrain.extend(load_terrain(filepath))
            all_terrain[room_name] = room_terrain
    return all_terrain

def load_terrain(filepath):
    file = open(filepath)
    match = read_match_line(file, re.compile(r'^@BG 0 0 0 ([0-9]+)x([0-9]+)$'))
    cols = int(match.group(1))
    rows = int(match.group(2))
    tileset_re = re.compile(r'^(>[a-z]+_([0-9]+))?$')
    tilesets = []
    while True:
        match = read_match_line(file, tileset_re)
        if not match.group(1): break
        tilesets.append(int(match.group(2)))
    terrain = [[0] * rows for col in range(cols)]
    row = -1
    while True:
        row += 1
        line = file.readline()
        if not line: break
        for col in range(0, len(line) // 2):
            i = col * 2
            if line[i] == ' ': continue
            tileset_index = ord(line[i]) - ord('A')
            tile_index = ord(line[i + 1]) - ord('A')
            terrain[col][row] = tilesets[tileset_index] * 16 + tile_index
    return terrain

#=============================================================================#

def test_area_cells(areas):
    failed = False
    for area_name, area in areas.items():
        area_cells = area['cells']
        if area_cells != sorted(area_cells):
            print('SCENARIO: {}AreaCells is not sorted'.format(area_name))
            failed = True
        # Each minimap row of each area can contain at most 8 cells (since we
        # draw one OBJ in each minimap cell of the current area on the pause
        # screen, and the NES can't draw more than 8 OBJs on one scanline).
        area_rows = {}
        for row, col in area_cells:
            if row not in area_rows: area_rows[row] = []
            area_rows[row].append(col)
        for row, cols in area_rows.items():
            if len(cols) > 8:
                print('SCENARIO: more than 8 cells in row {} of {}AreaCells'.
                      format(row, area_name))
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
    all_cells = {}  # maps from cell to area name it's in
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
        for cell in area_cells - frozenset(covered_area_cells):
            if cell not in PERMITTED_UNCOVERED_CELLS.get(area_name, ()):
                print('SCENARIO: {} cell {} is not covered by any room'.format(
                    area_name, cell))
                failed = True
    return failed

def test_room_devices(areas):
    failed = False
    for area_name, area in areas.items():
        for room_name, room in area['rooms'].items():
            device_locations = {}
            for device in room['devices']:
                location = (device['block_row'], device['block_col'])
                if location in device_locations:
                    print('SCENARIO: {} has {} and {} both at {}'.format(
                        room_name, device['type'],
                        device_locations[location]['type'], location))
                    failed = True
                else:
                    device_locations[location] = device
    return failed

def test_room_doors(areas):
    failed = False
    for area_name, area in areas.items():
        for room_name, room in area['rooms'].items():
            for door in room['doors']:
                if PERMITTED_DOOR_MISMATCHES.get(room_name) == door['cell']:
                    continue
                door_number = door['door_number']
                dest_room_name = door['dest_room']
                dest_room = area['rooms'][dest_room_name]
                for dest_door in dest_room['doors']:
                    if dest_door['dest_room'] != room_name: continue
                    if dest_door['door_number'] != door_number: continue
                    if dest_door['cell'] != door['cell']:
                        print('SCENARIO: {}/{} door cell mismatch: {} vs. {}'.
                              format(room_name, dest_room_name, door['cell'],
                                     dest_door['cell']))
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
            dest_pairs = set()
            for passage in room['passages']:
                is_secondary = passage['secondary']
                dest_area = areas[passage['dest_area']]
                dest_room_name = passage['dest_room']
                if dest_room_name == room_name:
                    print('SCENARIO: {} has a passage to itself'.format(
                        room_name))
                    failed = True
                    continue
                dest_pair = (dest_room_name, is_secondary)
                if dest_pair in dest_pairs:
                    print('SCENARIO: {} has multiple {} passages to {}'.format(
                        room_name, 'secondary' if is_secondary else 'primary',
                        dest_room_name))
                    failed = True
                    continue
                dest_pairs.add(dest_pair)
                dest_room = dest_area['rooms'][dest_room_name]
                side = passage['side']
                for dest_passage in dest_room['passages']:
                    if dest_passage['dest_room'] != room_name: continue
                    if dest_passage['side'] != PASSAGE_SIDE_OPPOSITES[side]:
                        continue
                    if dest_passage['secondary'] != is_secondary:
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
        if room_name not in area['rooms']:
            print('SCENARIO: marker {} is in nonexistant room {}'.format(
                marker['name'], room_name))
            failed = True
            continue
        room = area['rooms'][room_name]
        cell = marker['cell']
        if cell not in room['cells']:
            print('SCENARIO: marker {} cell {} is not in room {}'.format(
                marker['name'], cell, room_name))
            failed = True
    return failed

def test_flower_rooms(areas, markers):
    failed = False
    flower_rooms = set()
    for area_name, area in areas.items():
        for room_name, room in area['rooms'].items():
            is_flower_room = room_name.endswith('Flower')
            has_flower_device = any(device['type'] == 'Flower'
                                    for device in room['devices'])
            if is_flower_room:
                if has_flower_device:
                    flower_rooms.add(room_name)
                else:
                    print('SCENARIO: no Flower device in room {}'.format(
                        room_name))
                    failed = True
            elif has_flower_device:
                print('SCENARIO: unexpected Flower device in room {}'.format(
                    room_name))
                failed = True
    flower_marker_rooms = set()
    for marker in markers:
        if marker['not_flag'].startswith('Flower') and not marker['if_flag']:
            room_name = marker['room']
            flower_marker_rooms.add(room_name)
    for room_name in sorted(flower_rooms):
        if room_name not in flower_marker_rooms:
            print('SCENARIO: no minimap marker found for {}'.format(room_name))
            failed = True
    return failed

def test_paper_rooms(areas, papers):
    failed = False
    for paper_name, paper in papers.items():
        area_name = paper['area']
        area = areas[area_name]
        room_name = paper['room']
        if room_name not in area['rooms']:
            print('SCENARIO: paper {} is in nonexistant room {}'.format(
                paper_name, room_name))
            failed = True
            continue
        room = area['rooms'][room_name]
        if paper_name not in room['papers']:
            print('SCENARIO: paper {} does not exist in room {}'.format(
                paper_name, room_name))
            failed = True
    for area in areas.values():
        for room_name, room in area['rooms'].items():
            for paper_name in room['papers']:
                if paper_name not in papers:
                    print('SCENARIO: room {} has unlisted paper {}'.format(
                        room_name, paper_name))
                    failed = True
                    continue
                paper = papers[paper_name]
                if room_name != paper['room']:
                    print('SCENARIO: room {} wrongly has paper {}'.format(
                        room_name, paper_name))
                    failed = True
    return failed

def test_newgame_flags(newgame_flags, all_flags, papers):
    failed = False
    unused_flags = set(all_flags)
    for flag, room in newgame_flags:
        if flag not in unused_flags:
            print(f'SCENARIO: repeated newgame flag {flag}')
            failed = True
            continue
        unused_flags.remove(flag)
        if flag.startswith('Paper'):
            if room != papers[flag]['room']:
                print(f'SCENARIO: newgame flag {flag} has room {room} instead'
                      f" of {papers[flag]['room']}")
                failed = True
        elif room is not None:
            print(f'SCENARIO: newgame flag {flag} has needless room comment')
            failed = True
    if unused_flags:
        print('SCENARIO: missing newgame flags:')
        for flag in sorted(unused_flags):
            print(f'    {flag}')
        failed = True
    return failed

def test_spawn_blocks(areas, tilesets, terrain):
    failed = False
    for area_name, area in areas.items():
        for room_name, room in area['rooms'].items():
            def is_solid(terrain_tile):
                return terrain_tile >= tilesets[room['tileset']]['first_solid']
            for passage in room['passages']:
                side = passage['side']
                horz_adjust = passage['spawn_adjust'] >> 4
                if horz_adjust >= 0x8: horz_adjust |= -16
                vert_adjust = passage['spawn_adjust'] & 0x7
                if side == 'Western':
                    kind = 'horz'
                    spawn_block_cols = [0, 1]
                elif side == 'Eastern':
                    kind = 'horz'
                    col = (room['max_scroll_x'] + 0x100) // 16
                    spawn_block_cols = [col, col - 1]
                elif side == 'Top':
                    kind = 'vert'
                    spawn_block_row = 0
                elif side == 'Bottom':
                    kind = 'vert'
                    spawn_block_row = 23 if room['is_tall'] else 14
                    vert_adjust = -vert_adjust
                else: assert False, side
                if kind == 'horz':
                    row = passage['spawn_block']
                    for col in spawn_block_cols:
                        tile = terrain[room_name][col][row]
                        if area_name == 'Mermaid' and tile == 0x1f:
                            continue  # water terrain
                        if is_solid(tile):
                            print(f'SCENARIO: {side} passage in room'
                                  f' {room_name} has spawn block {row} in'
                                  f' solid terrain ${tile:02x} in column'
                                  f' {col}')
                            failed = True
                        tile = terrain[room_name][col][row + 1]
                        if not is_solid(tile):
                            print(f'SCENARIO: {side} passage in room'
                                  f' {room_name} has spawn block {row}'
                                  f' over empty terrain ${tile:02x} in column '
                                  f'{col}')
                            failed = True
                elif kind == 'vert':
                    row = spawn_block_row + vert_adjust
                    col = passage['spawn_block'] + horz_adjust // 2
                    tile = terrain[room_name][col][row]
                    if is_solid(tile):
                        print(f'SCENARIO: {side} passage in room {room_name}'
                              f' has adjusted spawn row={row} col={col} in'
                              f' solid terrain ${tile:02x}')
                        failed = True
                    if vert_adjust != 0:
                        tile = terrain[room_name][col][row + 1]
                        if not is_solid(tile):
                            print(f'SCENARIO: {side} passage in room'
                                  f' {room_name} has adjusted spawn row={row}'
                                  f' col={col} over empty terrain ${tile:02x}')
                            failed = True
                else: assert False, kind
    return failed

#=============================================================================#

def run_tests():
    failed = False
    areas = load_areas()
    failed |= test_area_cells(areas)
    markers = load_markers()
    failed |= test_markers_sorted(markers)
    minimap = load_minimap()
    failed |= test_minimap_coverage(areas, minimap)
    failed |= test_room_cells(areas)
    failed |= test_room_devices(areas)
    failed |= test_room_doors(areas)
    failed |= test_room_passages(areas)
    failed |= test_marker_rooms(areas, markers)
    failed |= test_flower_rooms(areas, markers)
    papers = load_papers()
    failed |= test_paper_rooms(areas, papers)
    all_flags = load_all_flags()
    newgame_flags = load_newgame_flags()
    failed |= test_newgame_flags(newgame_flags, all_flags, papers)
    tilesets = load_tilesets()
    terrain = load_all_terrain(areas)
    failed |= test_spawn_blocks(areas, tilesets, terrain)
    return failed

#=============================================================================#

if __name__ == '__main__':
    sys.exit(run_tests())

#=============================================================================#
