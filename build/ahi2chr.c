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

#include "util.h"

/*===========================================================================*/

static void convert_image_to_chr(const ahi_image_t *image) {
  if (image->width % 8 != 0 || image->height % 8 != 0) {
    error_fatal("invalid size: %dx%d", image->width, image->height);
  }
  const int horz_tiles = image->width / 8;
  const int vert_tiles = image->height / 8;
  for (int tile_col = 0; tile_col < horz_tiles; ++tile_col) {
    for (int tile_row = 0; tile_row < vert_tiles; ++tile_row) {
      for (int pixel_row = 0; pixel_row < 8; ++pixel_row) {
        unsigned char byte1 = 0;
        for (int pixel_col = 0; pixel_col < 8; ++pixel_col) {
          unsigned char pixel =
            image->data[(tile_row * 8 + pixel_row) * image->width +
                        tile_col * 8 + pixel_col];
          byte1 = (byte1 << 1) | (pixel & 1);
        }
        fputc(byte1, stdout);
      }
      for (int pixel_row = 0; pixel_row < 8; ++pixel_row) {
        unsigned char byte2 = 0;
        for (int pixel_col = 0; pixel_col < 8; ++pixel_col) {
          unsigned char pixel =
            image->data[(tile_row * 8 + pixel_row) * image->width +
                        tile_col * 8 + pixel_col];
          byte2 = (byte2 << 1) | ((pixel >> 1) & 1);
        }
        fputc(byte2, stdout);
      }
    }
  }
}

static void convert_collection_to_chr(const ahi_collection_t *collection) {
  for (int i = 0; i < collection->num_images; ++i) {
    convert_image_to_chr(collection->images[i]);
  }
}

int main(int argc, char **argv) {
  input_t input;
  input_init(&input, stdin);
  ahi_collection_t *collection = ahi_parse_collection(&input);
  convert_collection_to_chr(collection);
  ahi_delete_collection(collection);
  return EXIT_SUCCESS;
}

/*===========================================================================*/
