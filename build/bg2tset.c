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

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*===========================================================================*/

#define MAX_TILESETS 64

#define TILE_WIDTH 8
#define TILE_HEIGHT 8

#define BLOCK_WIDTH 16
#define BLOCK_HEIGHT 16

#define NUM_BLOCK_COLS 16
#define MAX_BLOCK_ROWS 16

#define MAX_BLOCKS (NUM_BLOCK_COLS * MAX_BLOCK_ROWS)

#define ERROR(...) do {           \
    fprintf(stderr, __VA_ARGS__); \
    exit(EXIT_FAILURE);           \
  } while (0)

/*===========================================================================*/

typedef struct {
  unsigned char pixels[BLOCK_WIDTH * BLOCK_HEIGHT];
} block_t;

typedef struct {
  unsigned char pixels[TILE_WIDTH * TILE_HEIGHT];
} tile_t;

typedef struct {
  char *name;
  int num_tiles;
  tile_t *tiles;
} tileset_t;

/*===========================================================================*/

__attribute__((__malloc__, __format__(__printf__, 1, 2)))
char *string_printf(const char *format, ...) {
  va_list args;
  va_start(args, format);
  const size_t size = vsnprintf(NULL, 0, format, args);
  va_end(args);
  char *out = calloc(size + 1, sizeof(char)); // add 1 for trailing '\0'
  va_start(args, format);
  vsprintf(out, format, args);
  va_end(args);
  return out;
}

int ascii_to_lower(int ch) {
  return ch >= 'A' && ch <= 'Z' ? ch - 'A' + 'a' : ch;
}

int ascii_to_upper(int ch) {
  return ch >= 'a' && ch <= 'z' ? ch - 'a' + 'A' : ch;
}

char *capitalized_string(const char *string) {
  const size_t size = strlen(string);
  char *out = calloc(size + 1, sizeof(char)); // add 1 for trailing '\0'
  if (size > 0) {
    out[0] = ascii_to_upper(string[0]);
  }
  for (size_t i = 1; i < size; ++i) {
    out[i] = ascii_to_lower(string[i]);
  }
  return out;
}

/*===========================================================================*/

void read_newline(FILE *file) {
  const int ch = fgetc(file);
  if (ch != '\n') {
    ERROR("Expected newline, got 0x%02x\n", ch);
  }
}

void skip_line(FILE *file) {
  while (1) {
    int ch = fgetc(file);
    if (ch == '\n' || ch == EOF) break;
  }
}

/*===========================================================================*/

int to_hex(unsigned char pixel) {
  return pixel < 10 ? '0' + pixel : 'A' + pixel;
}

unsigned char from_hex(int ch) {
  if (ch >= '0' && ch <= '9') {
    return ch - '0';
  } else if (ch >= 'a' && ch <= 'f') {
    return ch - 'a' + 0xa;
  } else if (ch >= 'A' && ch <= 'F') {
    return ch - 'A' + 0xA;
  } else {
    ERROR("Invalid pixel char: 0x%x\n", ch);
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

/*===========================================================================*/

int read_ahi_version(FILE *file) {
  for (int i = 0; i < 3; ++i) {
    int ch = fgetc(file);
    if (ch != "ahi"[i]) {
      ERROR("Invalid version header\n");
    }
  }
  return fgetc(file) - '0';
}

int read_ahi0_header(FILE *file) {
  int width, height, num_images;
  if (fscanf(file, " w%u h%u n%u", &width, &height, &num_images) != 3) {
    ERROR("Invalid ahi0 header\n");
  }
  if (width != TILE_WIDTH || height != TILE_HEIGHT) {
    ERROR("Invalid tile size: %dx%d\n", width, height);
  }
  read_newline(file);
  return num_images;
}

int read_ahi1_header(FILE *file) {
  int num_palettes, num_images, width, height;
  if (fscanf(file, " f0 p%u i%u w%u h%u",
             &num_palettes, &num_images, &width, &height) != 4) {
    ERROR("Invalid ahi1 header\n");
  }
  if (width != TILE_WIDTH || height != TILE_HEIGHT) {
    ERROR("Invalid tile size: %dx%d\n", width, height);
  }
  read_newline(file);
  if (num_palettes > 0) {
    read_newline(file);
    for (int i = 0; i < num_palettes; ++i) {
      skip_line(file);
    }
  }
  return num_images;
}

void read_ahi_tile(FILE *file, tile_t *tile) {
  read_newline(file);
  for (int row = 0; row < TILE_HEIGHT; ++row) {
    for (int col = 0; col < TILE_WIDTH; ++col) {
      tile->pixels[row * TILE_WIDTH + col] = from_hex(fgetc(file));
    }
    read_newline(file);
  }
}

void create_tileset(tileset_t *tileset, char *name) {
  tileset->name = name;
  char *path = string_printf("src/tiles/%s.ahi", name);
  FILE *file = fopen(path, "r");
  if (file == NULL) ERROR("Could not open %s\n", path);
  free(path);

  const int version = read_ahi_version(file);
  if (version == 0) {
    tileset->num_tiles = read_ahi0_header(file);
  } else if (version == 1) {
    tileset->num_tiles = read_ahi1_header(file);
  } else {
    ERROR("Invalid ahi version (%d)", version);
  }

  tileset->tiles = calloc(tileset->num_tiles, sizeof(tile_t));
  for (int i = 0; i < tileset->num_tiles; ++i) {
    read_ahi_tile(file, &tileset->tiles[i]);
  }
  fclose(file);
}

void destroy_tileset(tileset_t *tileset) {
  free(tileset->name);
  free(tileset->tiles);
}

/*===========================================================================*/

FILE *new_blockset_file(const char *area_name, int block_row) {
  char *path = string_printf("out/blocks/%s_%x.ahi", area_name, block_row);
  FILE *file = fopen(path, "w");
  if (file == NULL) ERROR("Could not open %s\n", path);
  free(path);
  fprintf(file, "ahi1 f0 p1 i16 w16 h16\n\n"
          "000B;0;54;ECEEEC;FF0;FF0;FF0;FF0;"
          "FF0;FF0;FF0;FF0;FF0;FF0;FF0;FF0\n");
  return file;
}

void write_block_to_blockset_file(FILE *file, const block_t *block) {
  fputc('\n', file);
  for (int row = 0; row < BLOCK_HEIGHT; ++row) {
    for (int col = 0; col < BLOCK_WIDTH; ++col) {
      fputc(to_hex(block->pixels[row * BLOCK_WIDTH + col]), file);
    }
    fputc('\n', file);
  }
}

void blit_tile_to_block(block_t *block, int tile_row, int tile_col,
                        const tile_t *tile) {
  for (int pixel_row = 0; pixel_row < TILE_HEIGHT; ++pixel_row) {
    for (int pixel_col = 0; pixel_col < TILE_WIDTH; ++pixel_col) {
      const int pixel =
        tile == NULL ? 0 : tile->pixels[pixel_row * TILE_WIDTH + pixel_col];
      block->pixels[(tile_row * TILE_HEIGHT + pixel_row) * BLOCK_WIDTH +
                    tile_col * TILE_WIDTH + pixel_col] = pixel;
    }
  }
}

/*===========================================================================*/

char *read_tileset_name(FILE *file) {
  int ch = fgetc(file);
  if (ch == '\n') return NULL;
  int index = 0;
  char buffer[80] = {0};
  while (index + 1 < sizeof(buffer)) {
    ch = fgetc(file);
    if (ch == EOF || ch == '\n') break;
    buffer[index++] = ch;
  }
  return strcpy(calloc(index + 1, sizeof(char)), buffer);
}

char get_tile_id(const char *tileset, int tile_index) {
  if (0 == strcmp(tileset, "anim01")) {
    return 0xc0 + tile_index;
  } else if (0 == strcmp(tileset, "arch")) {
    return 0xb0 + tile_index;
  } else if (0 == strcmp(tileset, "beach")) {
    return 0xa0 + tile_index;
  } else if (0 == strcmp(tileset, "cave")) {
    return 0x80 + tile_index;
  } else if (0 == strcmp(tileset, "cobweb")) {
    return 0x90 + tile_index;
  } else if (0 == strcmp(tileset, "crypt")) {
    return 0x80 + tile_index;
  } else if (0 == strcmp(tileset, "crystal")) {
    return 0x80 + tile_index;
  } else if (0 == strcmp(tileset, "device")) {
    return 0xb8 + tile_index;
  } else if (0 == strcmp(tileset, "drawbridge")) {
    return 0xb4 + tile_index;
  } else if (0 == strcmp(tileset, "field_bg")) {
    return 0xb0 + tile_index;
  } else if (0 == strcmp(tileset, "font_lower")) {
    return 0x40 + tile_index;
  } else if (0 == strcmp(tileset, "furniture")) {
    return 0xa0 + tile_index;
  } else if (0 == strcmp(tileset, "house")) {
    return 0xa0 + tile_index;
  } else if (0 == strcmp(tileset, "hut")) {
    return 0x90 + tile_index;
  } else if (0 == strcmp(tileset, "hut1")) {
    return 0x80 + tile_index;
  } else if (0 == strcmp(tileset, "hut2")) {
    return 0x90 + tile_index;
  } else if (0 == strcmp(tileset, "indoors")) {
    return 0x80 + tile_index;
  } else if (0 == strcmp(tileset, "jungle1")) {
    return 0x80 + tile_index;
  } else if (0 == strcmp(tileset, "jungle2")) {
    return 0x90 + tile_index;
  } else if (0 == strcmp(tileset, "jungle3")) {
    return 0xa0 + tile_index;
  } else if (0 == strcmp(tileset, "metal")) {
    return 0x90 + tile_index;
  } else if (0 == strcmp(tileset, "outdoors")) {
    return 0x80 + tile_index;
  } else if (0 == strcmp(tileset, "roof")) {
    return 0x90 + tile_index;
  } else if (0 == strcmp(tileset, "steam_pipes")) {
    return 0x80 + tile_index;
  } else if (0 == strcmp(tileset, "temple1")) {
    return 0x80 + tile_index;
  } else if (0 == strcmp(tileset, "temple2")) {
    return 0x90 + tile_index;
  } else if (0 == strcmp(tileset, "volcanic")) {
    return 0x90 + tile_index;
  } else if (0 == strcmp(tileset, "window")) {
    return 0x9c + tile_index;
  } else {
    ERROR("unknown tileset: %s\n", tileset);
  }
}

/*===========================================================================*/

void write_separator(void) {
  fprintf(stdout,
          "\n;;;====================================="
          "====================================;;;\n");
}

void write_terrain_table(const char *quadrant, const char *area_name,
                         const unsigned char *tile_ids, int num_block_rows) {
  char *capitalized_name = capitalized_string(area_name);
  fprintf(stdout, "\n.EXPORT DataA_Terrain_%s%s_u8_arr\n", capitalized_name,
          quadrant);
  fprintf(stdout, ".PROC DataA_Terrain_%s%s_u8_arr\n", capitalized_name,
          quadrant);
  free(capitalized_name);
  for (int row = 0; row < num_block_rows; ++row) {
    for (int start = 0; start < 16; start += 8) {
      fprintf(stdout, "    .byte");
      for (int i = 0; i < 8; ++i) {
        const int col = start + i;
        const int block_index = row * NUM_BLOCK_COLS + col;
        const unsigned char tile_id = tile_ids[block_index];
        if (i != 0) fputc(',', stdout);
        fprintf(stdout, " $%02x", tile_id);
      }
      fputc('\n', stdout);
    }
  }
  fprintf(stdout, ".ENDPROC\n");
}

/*===========================================================================*/

static tileset_t tilesets[MAX_TILESETS];

static unsigned char block_nw[MAX_BLOCKS];
static unsigned char block_sw[MAX_BLOCKS];
static unsigned char block_ne[MAX_BLOCKS];
static unsigned char block_se[MAX_BLOCKS];

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "Usage: bg2tset AREA_NAME < in.bg > out.asm\n");
    return EXIT_FAILURE;
  }
  const char *area_name = argv[1];

  // Read the BG file header.
  int width, height;
  if (fscanf(stdin, "@BG 0 0 0 %ux%u", &width, &height) != 2) {
    ERROR("Invalid header\n");
  }
  if (width != 2 * NUM_BLOCK_COLS || height % 2 != 0 ||
      height > 2 * MAX_BLOCK_ROWS) {
    ERROR("Invalid size: %dx%d\n", width, height);
  }
  read_newline(stdin);
  const int num_block_rows = height / 2;

  // Read in the tilesets.
  int num_tilesets = 0;
  while (1) {
    char *name = read_tileset_name(stdin);
    if (name == NULL) break;
    if (num_tilesets >= MAX_TILESETS) {
      ERROR("Too many tilesets\n");
    }
    create_tileset(&tilesets[num_tilesets++], name);
  }

  // Construct the blocks.
  for (int block_row = 0; block_row < num_block_rows; ++block_row) {
    tile_t *tiles[4 * NUM_BLOCK_COLS] = {NULL};
    unsigned char tile_ids[4 * NUM_BLOCK_COLS] = {0};
    for (int tile_row = 0; tile_row < 2; ++tile_row) {
      for (int tile_col = 0; tile_col < 2 * NUM_BLOCK_COLS; ++tile_col) {
        const int ch = fgetc(stdin);
        if (ch == '\n' || ch == EOF) {
          goto end_tile_row;
        }
        const int tileset_index = from_base64(ch);
        if (tileset_index >= num_tilesets) {
          ERROR("Tileset index %d out of range\n", tileset_index);
        }
        const int tile_index = from_base64(fgetc(stdin));
        if (tileset_index < 0 || tile_index < 0) continue;
        const tileset_t *tileset = &tilesets[tileset_index];
        if (tile_index >= tileset->num_tiles) {
          ERROR("Tile index %d out of range for tileset %s\n",
                tile_index, tileset->name);
        }
        const int array_index = 2 * NUM_BLOCK_COLS * tile_row + tile_col;
        tiles[array_index] = &tileset->tiles[tile_index];
        tile_ids[array_index] =
          get_tile_id(tilesets[tileset_index].name, tile_index);
      }
      read_newline(stdin);
    end_tile_row:;
    }
    // Record tile IDs for this row of blocks.
    for (int block_col = 0; block_col < NUM_BLOCK_COLS; ++block_col) {
      const int block_index = block_row * NUM_BLOCK_COLS + block_col;
      block_nw[block_index] = tile_ids[2 * block_col];
      block_ne[block_index] = tile_ids[2 * block_col + 1];
      block_sw[block_index] = tile_ids[2 * (NUM_BLOCK_COLS + block_col)];
      block_se[block_index] = tile_ids[2 * (NUM_BLOCK_COLS + block_col) + 1];
    }
    // Write AHI file for this row of blocks.
    FILE *file = new_blockset_file(area_name, block_row);
    for (int block_col = 0; block_col < NUM_BLOCK_COLS; ++block_col) {
      block_t block;
      blit_tile_to_block(&block, 0, 0, tiles[2 * block_col]);
      blit_tile_to_block(&block, 0, 1, tiles[2 * block_col + 1]);
      blit_tile_to_block(&block, 1, 0,
                         tiles[2 * (NUM_BLOCK_COLS + block_col)]);
      blit_tile_to_block(&block, 1, 1,
                         tiles[2 * (NUM_BLOCK_COLS + block_col) + 1]);
      write_block_to_blockset_file(file, &block);
    }
    fclose(file);
  }

  // Write ASM for terrain tables.
  fprintf(stdout, ";;; This file was generated by bg2tset.\n");
  write_separator();
  fprintf(stdout, "\n.SEGMENT \"PRGA_Terrain\"\n");
  write_terrain_table("UpperLeft", area_name, block_nw, num_block_rows);
  write_terrain_table("LowerLeft", area_name, block_sw, num_block_rows);
  write_terrain_table("UpperRight", area_name, block_ne, num_block_rows);
  write_terrain_table("LowerRight", area_name, block_se, num_block_rows);
  write_separator();

  // Clean up.
  for (int i = 0; i < num_tilesets; ++i) {
    destroy_tileset(&tilesets[i]);
  }

  return EXIT_SUCCESS;
}

/*===========================================================================*/
