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

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

/*===========================================================================*/

// Reports an error and exits the program.
void error_fatal(const char *format, ...)
  __attribute__((__noreturn__, __format__(__printf__, 1, 2)));

/*===========================================================================*/

typedef struct {
  FILE *file;
  char last_char; // the last character returned from input_getc
  int line_number;
  int reached_eof;
} input_t;

// Initializes the input struct.
void input_init(input_t *input, FILE *file);

// Reports an input error and exits the program.
void input_fatal(input_t *input, const char *format, ...)
  __attribute__((__noreturn__, __format__(__printf__, 2, 3)));

// Consumes and returns the next character from the input, and also sets
// input->last_char to that character. If EOF is reached, returns '\n' and sets
// input->reached_eof.
char input_getc(input_t *input);

// Returns the next character from the input without consuming it. If EOF is
// reached, returns '\n' (but does not set input->reached_eof).
char input_peek(input_t *input);

void input_read_zero_or_more_spaces(input_t *input);
void input_read_one_or_more_spaces(input_t *input);

int input_read_nonnegative_int(input_t *input);

void input_expect_eof(input_t *input);
void input_expect_newline(input_t *input);
void input_expect_string(input_t *input, const char *expected);

/*===========================================================================*/

typedef struct {
  int width;
  int height;
  unsigned char *data;
} ahi_image_t;

typedef struct {
  int num_palettes;
  char **palettes;
  int num_images;
  ahi_image_t **images;
} ahi_collection_t;

ahi_image_t *ahi_new_image(int width, int height)
  __attribute__((__malloc__));
void ahi_blit_image(ahi_image_t *dest, const ahi_image_t *src, int x, int y);
void ahi_delete_image(ahi_image_t *image);

ahi_collection_t *ahi_new_collection(int num_palettes, int num_images)
  __attribute__((__malloc__));
ahi_collection_t *ahi_parse_collection(input_t *input)
  __attribute__((__malloc__));
void ahi_write_collection(FILE *file, const ahi_collection_t* collection);
void ahi_delete_collection(ahi_collection_t *collection);

/*===========================================================================*/

typedef struct {
  bool present;
  unsigned char tileset_index;
  unsigned char tile_index;
} bg_tile_t;

typedef struct {
  int width;
  int height;
  int num_tilesets;
  char **tilesets;
  bg_tile_t *tiles;
} bg_background_t;

bg_background_t *bg_new_background(int width, int height, int num_tilesets)
  __attribute__((__malloc__));
bg_background_t *bg_parse_background(input_t *input)
  __attribute__((__malloc__));
void bg_delete_background(bg_background_t *background);

/*===========================================================================*/

// Allocates a new string with the same text that would be produced by a call
// to printf with the same format and arguments.
char *string_printf(const char *format, ...)
  __attribute__((__malloc__, __format__(__printf__, 1, 2)));

/*===========================================================================*/
