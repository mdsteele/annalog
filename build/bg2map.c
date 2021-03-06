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

/*===========================================================================*/

#define MAX_TILESETS 64

/*===========================================================================*/

#define ERROR(...) do {           \
    fprintf(stderr, __VA_ARGS__); \
    exit(EXIT_FAILURE);           \
  } while (0)

/*===========================================================================*/

void expect_newline(void) {
  const int ch = fgetc(stdin);
  if (ch != '\n') {
    ERROR("Expected newline, got 0x%02x\n", ch);
  }
}

char *read_tileset(void) {
  int ch = fgetc(stdin);
  if (ch == '\n') return NULL;
  int index = 0;
  char buffer[80] = {0};
  while (index + 1 < sizeof(buffer)) {
    ch = fgetc(stdin);
    if (ch == EOF || ch == '\n') break;
    buffer[index++] = ch;
  }
  return strcpy(calloc(index + 1, sizeof(char)), buffer);
}

int from_base64(int ch) {
  if (ch >= 'A' && ch <= 'Z') {
    return ch - 'A';
  } else if (ch >= 'a' && ch <= 'z') {
    return ch - 'a' + 26;
  } else if (ch >= '0' && ch <= '9') {
    return ch - '0' + 52;
  } else if (ch == '+') {
    return 62;
  } else if (ch == '/') {
    return 63;
  } else {
    return -1;
  }
}

char get_tile_id(const char *tileset, int tile_index) {
  if (0 == strcmp(tileset, "minimap1")) {
    return 0x80 + tile_index;
  } else if (0 == strcmp(tileset, "minimap2")) {
    return 0x90 + tile_index;
  } else if (0 == strcmp(tileset, "minimap3")) {
    return 0xa0 + tile_index;
  } else if (0 == strcmp(tileset, "title1")) {
    return 0x80 + tile_index;
  } else if (0 == strcmp(tileset, "title2")) {
    return 0x90 + tile_index;
  } else if (0 == strcmp(tileset, "title3")) {
    return 0xa0 + tile_index;
  } else {
    ERROR("unknown tileset: %s\n", tileset);
  }
}

/*===========================================================================*/

int main(int argc, char **argv) {
  // Read the BG file header.
  int width, height;
  if (fscanf(stdin, "@BG 0 0 0 %ux%u", &width, &height) != 2) {
    ERROR("Invalid header\n");
  }
  expect_newline();

  // Read the list of tilesets.
  char *tilesets[MAX_TILESETS] = {0};
  int num_tilesets = 0;
  while (1) {
    char *tileset = read_tileset();
    if (tileset == NULL) break;
    if (num_tilesets >= MAX_TILESETS) {
      ERROR("too many tilesets\n");
    }
    tilesets[num_tilesets++] = tileset;
  }

  // Read the BG grid, which appears in row-major order, and store the output
  // data in row-major order.
  const int grid_size = width * height;
  char *grid = calloc(grid_size, sizeof(char));
  for (int row = 0; row < height; ++row) {
    for (int col = 0; col < width; ++col) {
      const int ch = fgetc(stdin);
      if (ch == '\n' || ch == EOF) {
        for (; col < width; ++col) {
          grid[width * row + col] = 0x00;
        }
        goto end_row;
      }
      const int tileset_index = from_base64(ch);
      if (tileset_index >= num_tilesets) {
        ERROR("tileset index %d out of range\n", tileset_index);
      }
      const int tile_index = from_base64(fgetc(stdin));
      char *tile_id = &grid[width * row + col];
      if (tileset_index < 0 || tile_index < 0) {
        *tile_id = 0x00;
      } else {
        *tile_id = get_tile_id(tilesets[tileset_index], tile_index);
      }
    }
    expect_newline();
  end_row:;
  }

  // Write output data.
  if (fwrite(grid, sizeof(char), grid_size, stdout) != grid_size) {
    ERROR("failed to write output\n");
  }

  // Clean up.
  free(grid);
  for (int i = 0; i < num_tilesets; ++i) {
    free(tilesets[i]);
  }

  return EXIT_SUCCESS;
}

/*===========================================================================*/
