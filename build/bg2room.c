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

#define HEIGHT_SHORT 15
#define HEIGHT_TALL 24

#define MIN_WIDTH 16
#define MAX_WIDTH 128

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

char *read_tileset_name(void) {
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

unsigned char from_hex(int ch) {
  if (ch >= '0' && ch <= '9') {
    return ch - '0';
  } else if (ch >= 'a' && ch <= 'f') {
    return ch - 'a' + 0xa;
  } else if (ch >= 'A' && ch <= 'F') {
    return ch - 'A' + 0xA;
  } else {
    ERROR("Invalid hex digit character: 0x%02x\n", ch);
  }
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

unsigned char get_block_id(const char *tileset_name, int tile_index) {
  if (tile_index < 0 || tile_index >= 0x10) {
    ERROR("Invalid tile index: %d\n", tile_index);
  }
  const size_t size = strlen(tileset_name);
  if (size < 1) ERROR("Empty tileset name\n");
  const int row_index = from_hex(tileset_name[size - 1]);
  return 0x10 * row_index + tile_index;
}

/*===========================================================================*/

int main(int argc, char **argv) {
  // Read the BG file header.
  int width, height;
  if (fscanf(stdin, "@BG 0 0 0 %ux%u", &width, &height) != 2) {
    ERROR("Invalid header\n");
  }
  if (width < MIN_WIDTH || width > MAX_WIDTH ||
      (height != HEIGHT_SHORT && height != HEIGHT_TALL)) {
    ERROR("Invalid size: %dx%d\n", width, height);
  }
  expect_newline();

  // Read the list of tilesets.
  char *tilesets[MAX_TILESETS] = {0};
  int num_tilesets = 0;
  while (1) {
    char *tileset_name = read_tileset_name();
    if (tileset_name == NULL) break;
    if (num_tilesets >= MAX_TILESETS) {
      ERROR("too many tilesets\n");
    }
    tilesets[num_tilesets++] = tileset_name;
  }

  // Read the BG grid, which appears in row-major order, and store the output
  // data in column-major order.
  const int grid_size = width * height;
  unsigned char *grid = calloc(grid_size, sizeof(unsigned char));
  for (int row = 0; row < height; ++row) {
    for (int col = 0; col < width; ++col) {
      const int ch = fgetc(stdin);
      if (ch == '\n' || ch == EOF) {
        for (; col < width; ++col) {
          grid[height * col + row] = 0x00;
        }
        goto end_row;
      }
      const int tileset_index = from_base64(ch);
      if (tileset_index >= num_tilesets) {
        ERROR("tileset index %d out of range\n", tileset_index);
      }
      const int tile_index = from_base64(fgetc(stdin));
      unsigned char *block = &grid[height * col + row];
      if (tileset_index < 0 || tile_index < 0) {
        *block = 0x00;
      } else {
        *block = get_block_id(tilesets[tileset_index], tile_index);
      }
    }
    expect_newline();
  end_row:;
  }

  // Write output data.
  if (fwrite(grid, sizeof(unsigned char), grid_size, stdout) != grid_size) {
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
