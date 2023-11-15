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

static unsigned char get_tile_id(const char *tileset, int tile_index) {
  if (0 == strcmp(tileset, "minimap1")) {
    return 0xc0 + tile_index;
  } else if (0 == strcmp(tileset, "minimap2")) {
    return 0xd0 + tile_index;
  } else if (0 == strcmp(tileset, "minimap3")) {
    return 0xe0 + tile_index;
  } else if (0 == strcmp(tileset, "title1")) {
    return 0x80 + tile_index;
  } else if (0 == strcmp(tileset, "title2")) {
    return 0x90 + tile_index;
  } else if (0 == strcmp(tileset, "title3")) {
    return 0xa0 + tile_index;
  } else {
    error_fatal("unknown tileset: '%s'", tileset);
  }
}

/*===========================================================================*/

int main(int argc, char **argv) {
  input_t input;
  input_init(&input, stdin);
  bg_background_t *background = bg_parse_background(&input);

  // Read the BG grid, which appears in row-major order, and store the output
  // data in row-major order.
  for (int row = 0; row < background->height; ++row) {
    for (int col = 0; col < background->width; ++col) {
      bg_tile_t *tile = &background->tiles[row * background->width + col];
      unsigned char tile_id = 0x00;
      if (tile->present) {
        tile_id = get_tile_id(background->tilesets[tile->tileset_index],
                              tile->tile_index);
      }
      fputc(tile_id, stdout);
    }
  }

  bg_delete_background(background);
  return EXIT_SUCCESS;
}

/*===========================================================================*/
