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

/*===========================================================================*/

#define ERROR(...) do {           \
    fprintf(stderr, __VA_ARGS__); \
    exit(EXIT_FAILURE);           \
  } while (0)

/*===========================================================================*/

void read_newline(void) {
  int ch = fgetc(stdin);
  if (ch != '\n') {
    ERROR("Expected newline, got 0x%x\n", ch);
  }
}

void skip_line(void) {
  while (1) {
    int ch = fgetc(stdin);
    if (ch == '\n' || ch == EOF) break;
  }
}

void expect_eof(void) {
  int ch = fgetc(stdin);
  if (ch != EOF) {
    ERROR("Expected EOF, got 0x%x\n", ch);
  }
}

/*===========================================================================*/

void parse_images(int width, int height, int count) {
  if (width % 8 != 0 || height % 8 != 0) {
    ERROR("Invalid size: %dx%d\n", width, height);
  }
  const int horz_tiles = width / 8;
  const int vert_tiles = height / 8;
  unsigned char *buffer = malloc(width * height);
  for (int n = 0; n < count; ++n) {
    read_newline();
    for (int pixel_row = 0; pixel_row < height; ++pixel_row) {
      for (int pixel_col = 0; pixel_col < width; ++pixel_col) {
        int ch = fgetc(stdin);
        int pixel;
        if (ch >= '0' && ch <= '9') {
          pixel = ch - '0';
        } else if (ch >= 'a' && ch <= 'f') {
          pixel = ch - 'a' + 0xa;
        } else if (ch >= 'A' && ch <= 'F') {
          pixel = ch - 'A' + 0xA;
        } else {
          ERROR("Invalid pixel char: 0x%x\n", ch);
        }
        buffer[pixel_row * width + pixel_col] = pixel % 4;
      }
      read_newline();
    }
    for (int tile_col = 0; tile_col < horz_tiles; ++tile_col) {
      for (int tile_row = 0; tile_row < vert_tiles; ++tile_row) {
        for (int pixel_row = 0; pixel_row < 8; ++pixel_row) {
          unsigned char byte1 = 0;
          for (int pixel_col = 0; pixel_col < 8; ++pixel_col) {
            unsigned char pixel = buffer[(tile_row * 8 + pixel_row) * width +
                                         tile_col * 8 + pixel_col];
            byte1 = (byte1 << 1) | (pixel & 1);
          }
          fputc(byte1, stdout);
        }
        for (int pixel_row = 0; pixel_row < 8; ++pixel_row) {
          unsigned char byte2 = 0;
          for (int pixel_col = 0; pixel_col < 8; ++pixel_col) {
            unsigned char pixel = buffer[(tile_row * 8 + pixel_row) * width +
                                         tile_col * 8 + pixel_col];
            byte2 = (byte2 << 1) | ((pixel >> 1) & 1);
          }
          fputc(byte2, stdout);
        }
      }
    }
  }
  expect_eof();
  free(buffer);
}

void parse_ahi0(void) {
  int width, height, count;
  if (fscanf(stdin, " w%u h%u n%u", &width, &height, &count) != 3) {
    ERROR("Invalid ahi0 header\n");
  }
  read_newline();
  parse_images(width, height, count);
}

void parse_ahi1(void) {
  int num_palettes, num_images, width, height;
  if (fscanf(stdin, " f0 p%u i%u w%u h%u",
             &num_palettes, &num_images, &width, &height) != 4) {
    ERROR("Invalid ahi1 header\n");
  }
  read_newline();
  if (num_palettes > 0) {
    read_newline();
    for (int i = 0; i < num_palettes; ++i) {
      skip_line();
    }
  }
  parse_images(width, height, num_images);
}

int read_version(void) {
  for (int i = 0; i < 3; ++i) {
    int ch = fgetc(stdin);
    if (ch != "ahi"[i]) {
      ERROR("Invalid version header\n");
    }
  }
  return fgetc(stdin) - '0';
}

int main(int argc, char **argv) {
  int version = read_version();
  if (version == 0) {
    parse_ahi0();
  } else if (version == 1) {
    parse_ahi1();
  } else {
    ERROR("Invalid ahi version (%d)", version);
  }
  return EXIT_SUCCESS;
}

/*===========================================================================*/
