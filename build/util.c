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

#include "util.h"

#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*===========================================================================*/

#define MAX_AHI_PALETTE_LEN 144
#define MAX_BG_TILESETS 64
#define MAX_INTEGER_DIGITS 9

/*===========================================================================*/

void error_fatal(const char *format, ...) {
  va_list args;
  va_start(args, format);
  fprintf(stderr, "error: ");
  vfprintf(stderr, format, args);
  fprintf(stderr, "\n");
  exit(EXIT_FAILURE);
}

/*===========================================================================*/

void input_init(input_t *input, FILE *file) {
  input->file = file;
  input->last_char = '\0';
  input->line_number = 1;
  input->reached_eof = 0;
}

void input_fatal(input_t *input, const char *format, ...) {
  va_list args;
  va_start(args, format);
  fprintf(stderr, "line %d: error: ", input->line_number);
  vfprintf(stderr, format, args);
  fprintf(stderr, "\n");
  exit(EXIT_FAILURE);
}

char input_getc(input_t *input) {
  int ch = fgetc(input->file);
  if (input->last_char == '\n') {
    ++input->line_number;
  }
  if (ch == EOF) {
    input->reached_eof = 1;
    ch = '\n';
  }
  input->last_char = ch;
  return ch;
}

char input_peek(input_t *input) {
  int ch = fgetc(input->file);
  ungetc(ch, input->file);
  return ch == EOF ? '\n' : ch;
}

void input_read_zero_or_more_spaces(input_t *input) {
  while (input_peek(input) == ' ') {
    input_getc(input);
  }
}

void input_read_one_or_more_spaces(input_t *input) {
  if (input_getc(input) != ' ') {
    input_fatal(input, "expected space, got '%c'", input->last_char);
  }
  input_read_zero_or_more_spaces(input);
}

int input_read_nonnegative_int(input_t *input) {
  int value = 0;
  int num_digits = 0;
  while (true) {
    const char ch = input_peek(input);
    if (ch < '0' || ch > '9') {
      if (num_digits == 0) {
        input_fatal(input, "expected integer, got '%c'", ch);
      }
      return value;
    }
    input_getc(input);
    ++num_digits;
    if (num_digits > MAX_INTEGER_DIGITS) {
      input_fatal(input, "integer value is too large");
    }
    value = value * 10 + (ch - '0');
  }
}

void input_expect_eof(input_t *input) {
  char ch = input_getc(input);
  if (!input->reached_eof) {
    input_fatal(input, "expected EOF, got '%c'", ch);
  }
}

void input_expect_newline(input_t *input) {
  int ch = input_getc(input);
  if (ch != '\n') {
    input_fatal(input, "expected newline, got '%c'", ch);
  }
}

void input_expect_string(input_t *input, const char *expected) {
  for (int i = 0; expected[i] != '\0'; ++i) {
    int ch = input_getc(input);
    if (input->reached_eof) {
      input_fatal(input, "expected '%c', got EOF", expected[i]);
    } else if (ch != expected[i]) {
      input_fatal(input, "expected '%c', got '%c'", expected[i], ch);
    }
  }
}

/*===========================================================================*/

ahi_image_t *ahi_new_image(int width, int height) {
  ahi_image_t *image = malloc(sizeof(ahi_image_t));
  image->width = width;
  image->height = height;
  image->data = calloc(width * height, sizeof(unsigned char));
  return image;
}

void ahi_blit_image(ahi_image_t *dest, const ahi_image_t *src, int x, int y) {
  for (int srow = 0; srow < src->height; ++srow) {
    const int drow = srow + y;
    if (drow < 0 || drow >= dest->height) continue;
    for (int scol = 0; scol < src->width; ++scol) {
      const int dcol = scol + x;
      if (dcol < 0 || dcol >= dest->width) continue;
      dest->data[drow * dest->width + dcol] =
        src->data[srow * src->width + scol];
    }
  }
}

void ahi_delete_image(ahi_image_t *image) {
  if (image == NULL) return;
  free(image->data);
  free(image);
}

ahi_collection_t *ahi_new_collection(int num_palettes, int num_images) {
  ahi_collection_t *collection = malloc(sizeof(ahi_collection_t));
  collection->num_palettes = num_palettes;
  collection->palettes = calloc(num_palettes, sizeof(char*));
  collection->num_images = num_images;
  collection->images = calloc(num_images, sizeof(ahi_image_t*));
  return collection;
}

void ahi_delete_collection(ahi_collection_t *collection) {
  if (collection == NULL) return;
  for (int p = 0; p < collection->num_palettes; ++p) {
    free(collection->palettes[p]);
  }
  free(collection->palettes);
  for (int i = 0; i < collection->num_images; ++i) {
    ahi_delete_image(collection->images[i]);
  }
  free(collection->images);
  free(collection);
}

static ahi_collection_t *ahi_parse_data(
    input_t *input, int num_palettes, int num_images, int width, int height) {
  ahi_collection_t *collection = ahi_new_collection(num_palettes, num_images);

  if (num_palettes > 0) {
    input_expect_newline(input);
    for (int p = 0; p < num_palettes; ++p) {
      char buffer[MAX_AHI_PALETTE_LEN + 1];
      int index = 0;
      while (true) {
        const char ch = input_getc(input);
        if (ch == '\n') break;
        if (index == MAX_AHI_PALETTE_LEN) {
          input_fatal(input, "over-long palette");
        }
        buffer[index++] = ch;
      }
      buffer[index] = '\0';
      collection->palettes[p] = strdup(buffer);
    }
  }

  for (int n = 0; n < num_images; ++n) {
    ahi_image_t *image = ahi_new_image(width, height);
    input_expect_newline(input);
    for (int pixel_row = 0; pixel_row < height; ++pixel_row) {
      for (int pixel_col = 0; pixel_col < width; ++pixel_col) {
        int ch = input_getc(input);
        int pixel;
        if (ch >= '0' && ch <= '9') {
          pixel = ch - '0';
        } else if (ch >= 'a' && ch <= 'f') {
          pixel = ch - 'a' + 0xa;
        } else if (ch >= 'A' && ch <= 'F') {
          pixel = ch - 'A' + 0xA;
        } else {
          input_fatal(input, "Invalid pixel char: 0x%x", ch);
        }
        image->data[pixel_row * width + pixel_col] = pixel;
      }
      input_expect_newline(input);
    }
    collection->images[n] = image;
  }

  input_expect_eof(input);
  return collection;
}

static int ahi_read_field(input_t *input, char name) {
  input_read_one_or_more_spaces(input);
  char ch = input_getc(input);
  if (ch != name) {
    input_fatal(input, "expected '%c' field, got '%c'", name, ch);
  }
  return input_read_nonnegative_int(input);
}

static ahi_collection_t *ahi_parse_v0(input_t *input) {
  int width = ahi_read_field(input, 'w');
  int height = ahi_read_field(input, 'h');
  int num_images = ahi_read_field(input, 'n');
  input_expect_newline(input);
  return ahi_parse_data(input, 0, num_images, width, height);
}

static ahi_collection_t *ahi_parse_v1(input_t *input) {
  int flags = ahi_read_field(input, 'f');
  if (flags != 0) {
    input_fatal(input, "nonzero ahi1 flags are not supported");
  }
  int num_palettes = ahi_read_field(input, 'p');
  int num_images = ahi_read_field(input, 'i');
  int width = ahi_read_field(input, 'w');
  int height = ahi_read_field(input, 'h');
  input_expect_newline(input);
  return ahi_parse_data(input, num_palettes, num_images, width, height);
}

static int ahi_read_version(input_t *input) {
  for (int i = 0; i < 3; ++i) {
    if (input_getc(input) != "ahi"[i]) {
      input_fatal(input, "invalid version header");
    }
  }
  char digit = input_getc(input);
  return digit - '0';
}

ahi_collection_t *ahi_parse_collection(input_t *input) {
  int version = ahi_read_version(input);
  if (version == 0) {
    return ahi_parse_v0(input);
  } else if (version == 1) {
    return ahi_parse_v1(input);
  } else {
    input_fatal(input, "invalid ahi version (%d)", version);
  }
}

void ahi_write_collection(FILE *file, const ahi_collection_t* collection) {
  for (int i = 0; i < collection->num_images; ++i) {
    if (collection->images[i] == NULL) {
      error_fatal("collection image #%d is still NULL", i);
    }
  }

  int width = 0;
  int height = 0;
  if (collection->num_images > 0) {
    ahi_image_t *image = collection->images[0];
    width = image->width;
    height = image->height;
  }

  for (int i = 0; i < collection->num_images; ++i) {
    ahi_image_t *image = collection->images[i];
    if (image->width != width || image->height != height) {
      error_fatal("collection image sizes are not all the same");
    }
  }

  if (collection->num_palettes == 0) {
    fprintf(file, "ahi0 w%d h%d n%d\n", width, height, collection->num_images);
  } else {
    fprintf(file, "ahi1 f0 p%d i%d w%d h%d\n\n", collection->num_palettes,
            collection->num_images, width, height);
    for (int p = 0; p < collection->num_palettes; ++p) {
      fprintf(file, "%s\n", collection->palettes[p]);
    }
  }

  for (int i = 0; i < collection->num_images; ++i) {
    ahi_image_t *image = collection->images[i];
    fputc('\n', file);
    for (int row = 0; row < height; ++row) {
      for (int col = 0; col < width; ++col) {
        int pixel = image->data[row * width + col] & 0xf;
        fputc(pixel < 10 ? '0' + pixel : 'A' + pixel, file);
      }
      fputc('\n', file);
    }
  }
}

/*===========================================================================*/

static int bg_read_base64(input_t *input) {
  const char ch = input_getc(input);
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
    input_fatal(input, "expected base64 character, got '%c'", ch);
  }
}

bg_background_t *bg_new_background(int width, int height, int num_tilesets) {
  bg_background_t *background = malloc(sizeof(bg_background_t));
  background->width = width;
  background->height = height;
  background->num_tilesets = num_tilesets;
  background->tilesets = calloc(num_tilesets, sizeof(char*));
  background->tiles = calloc(width * height, sizeof(bg_tile_t));
  return background;
}

static char *bg_parse_tileset(input_t *input) {
  int ch = input_getc(input);
  if (ch == '\n') return NULL;
  int index = 0;
  char buffer[80] = {0};
  while (index + 1 < sizeof(buffer)) {
    ch = input_getc(input);
    if (ch == EOF || ch == '\n') break;
    buffer[index++] = ch;
  }
  return strcpy(calloc(index + 1, sizeof(char)), buffer);
}

bg_background_t *bg_parse_background(input_t *input) {
  input_expect_string(input, "@BG");
  input_read_one_or_more_spaces(input);
  input_read_nonnegative_int(input);  // red
  input_read_one_or_more_spaces(input);
  input_read_nonnegative_int(input);  // green
  input_read_one_or_more_spaces(input);
  input_read_nonnegative_int(input);  // blue
  input_read_one_or_more_spaces(input);
  const int width = input_read_nonnegative_int(input);
  input_expect_string(input, "x");
  const int height = input_read_nonnegative_int(input);
  input_expect_newline(input);

  char *tilesets[MAX_BG_TILESETS] = {0};
  int num_tilesets = 0;
  while (true) {
    char *tileset = bg_parse_tileset(input);
    if (tileset == NULL) break;
    if (num_tilesets >= MAX_BG_TILESETS) {
      input_fatal(input, "too many tilesets");
    }
    tilesets[num_tilesets++] = tileset;
  }

  bg_background_t *background = bg_new_background(width, height, num_tilesets);
  for (int i = 0; i < num_tilesets; ++i) {
    background->tilesets[i] = tilesets[i];
  }

  for (int row = 0; row < height; ++row) {
    for (int col = 0; col < width; ++col) {
      const char ch = input_peek(input);
      if (ch == '\n') break;
      if (ch == ' ') {
        input_expect_string(input, "  ");
        continue;
      }
      const int tileset_index = bg_read_base64(input);
      if (tileset_index >= num_tilesets) {
        input_fatal(input, "tileset index %d out of range", tileset_index);
      }
      bg_tile_t *tile = &background->tiles[width * row + col];
      tile->present = true;
      tile->tileset_index = tileset_index;
      tile->tile_index = bg_read_base64(input);
    }
    input_expect_newline(input);
  }

  return background;
}

void bg_delete_background(bg_background_t *background) {
  if (background == NULL) return;
  for (int i = 0; i < background->num_tilesets; ++i) {
    free(background->tilesets[i]);
  }
  free(background->tilesets);
  free(background->tiles);
  free(background);
}

/*===========================================================================*/

char *string_printf(const char *format, ...) {
  va_list args;
  va_start(args, format);
  const size_t size = vsnprintf(NULL, 0, format, args);
  va_end(args);
  char *out = calloc(size + 1, sizeof(char)); // add 1 for trailing '\0'
  if (out != NULL) {
    va_start(args, format);
    vsnprintf(out, size + 1, format, args);
    va_end(args);
  }
  return out;
}

/*===========================================================================*/
