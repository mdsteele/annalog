/*=============================================================================
| Copyright 2022 Matthew D. Steele <mdsteele@alum.mit.edu>                    |
|                                                                             |
| This file is part of Annalog.                                               |
|                                                                             |
| Annalog is free software: you can redistribute it and/or modify it under    |
| the terms of the GNU General Public License as published by the Free        |
| Software Foundation, either version 3 of the License, or (at your option)   |
| any later version.                                                          |
|                                                                             |
| Annalog is distributed in the hope that it will be useful, but WITHOUT ANY  |
| WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS   |
| FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more      |
| details.                                                                    |
|                                                                             |
| You should have received a copy of the GNU General Public License along     |
| with Annalog.  If not, see <http://www.gnu.org/licenses/>.                  |
=============================================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "util.h"

/*===========================================================================*/

#define HEIGHT_SHORT 15
#define HEIGHT_TALL 24

#define MIN_WIDTH 16
#define MAX_WIDTH 128

/*===========================================================================*/

static unsigned char from_hex(int ch) {
  if (ch >= '0' && ch <= '9') {
    return ch - '0';
  } else if (ch >= 'a' && ch <= 'f') {
    return ch - 'a' + 0xa;
  } else if (ch >= 'A' && ch <= 'F') {
    return ch - 'A' + 0xA;
  } else {
    error_fatal("invalid hex digit character: '%c'", ch);
  }
}

static unsigned char get_block_id(const char *tileset_name, int tile_index) {
  if (tile_index < 0 || tile_index >= 0x10) {
    error_fatal("invalid tile index: %d", tile_index);
  }
  const size_t size = strlen(tileset_name);
  if (size < 1) error_fatal("empty tileset name");
  const int row_index = from_hex(tileset_name[size - 1]);
  return 0x10 * row_index + tile_index;
}

/*===========================================================================*/

int main(int argc, char **argv) {
  input_t input;
  input_init(&input, stdin);
  bg_background_t *background = bg_parse_background(&input);

  if (background->width < MIN_WIDTH || background->width > MAX_WIDTH ||
      (background->height != HEIGHT_SHORT &&
       background->height != HEIGHT_TALL)) {
    error_fatal("invalid size: %dx%d", background->width, background->height);
  }

  // Read the BG grid, which appears in row-major order, and store the output
  // data in column-major order.
  for (int col = 0; col < background->width; ++col) {
    for (int row = 0; row < background->height; ++row) {
      bg_tile_t *tile = &background->tiles[row * background->width + col];
      unsigned char block_id = 0x00;
      if (tile->present) {
        block_id = get_block_id(background->tilesets[tile->tileset_index],
                                tile->tile_index);
      }
      fputc(block_id, stdout);
    }
  }

  bg_delete_background(background);
  return EXIT_SUCCESS;
}

/*===========================================================================*/
