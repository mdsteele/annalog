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

#include "util.h"

/*===========================================================================*/

#define TILE_WIDTH 8
#define TILE_HEIGHT 8

#define BLOCK_WIDTH 16
#define BLOCK_HEIGHT 16

#define NUM_BLOCK_COLS 16
#define MAX_BLOCK_ROWS 16

#define MAX_BLOCKS (NUM_BLOCK_COLS * MAX_BLOCK_ROWS)

/*===========================================================================*/

static const struct {
  unsigned char start;
  const char* name;
} tile_files[] = {
  {0x48, "acid_anim0"},
  {0x48, "anim_conveyor_0"},
  {0x68, "anim_rocks_fall_1"},
  {0x4e, "anim_seaweed_0"},
  {0xb0, "arch"},
  {0xb4, "boiler"},
  {0x80, "building1"},
  {0x90, "building2"},
  {0xa0, "building3"},
  {0xb0, "building4"},
  {0x80, "cave"},
  {0x6a, "circuit_anim0"},
  {0x80, "city1"},
  {0x90, "city2"},
  {0xa0, "city3"},
  {0xb0, "city4"},
  {0x90, "cobweb"},
  {0x80, "core_pipes1"},
  {0x90, "core_pipes2"},
  {0x80, "crypt"},
  {0x80, "crystal"},
  {0xb4, "drawbridge"},
  {0x80, "factory1"},
  {0x90, "factory2"},
  {0xa0, "fullcore1"},
  {0xb0, "fullcore2"},
  {0xb6, "hill"},
  {0xa0, "house"},
  {0x90, "hut"},
  {0x80, "indoors"},
  {0x80, "jungle1"},
  {0x90, "jungle2"},
  {0xa0, "jungle3"},
  {0x40, "lava_anim0"},
  {0x94, "minecart"},
  {0xac, "mine_door"},
  {0x80, "outdoors"},
  {0x90, "prison"},
  {0xbc, "pump"},
  {0x90, "roof"},
  {0xb4, "ropediag"},
  {0xa0, "scaffhold"},
  {0x60, "sewage_anim0"},
  {0x80, "sewer1"},
  {0x90, "sewer2"},
  {0x80, "steam_pipes"},
  {0xb0, "tank"},
  {0x80, "temple1"},
  {0x90, "temple2"},
  {0xa0, "temple3"},
  {0xb0, "temple4"},
  {0xa0, "terrain_furniture"},
  {0xb0, "terrain_hoist"},
  {0x80, "terrain_hut0"},
  {0x90, "terrain_hut1"},
  {0xa0, "terrain_hut2"},
  {0xb0, "terrain_hut3"},
  {0xa0, "terrain_mermaid_2"},
  {0xb0, "terrain_mermaid_3"},
  {0x80, "terrain_shadow_0"},
  {0x90, "terrain_shadow_1"},
  {0xa0, "terrain_shadow_2"},
  {0x00, "terrain_shared_0"},
  {0x10, "terrain_shared_1"},
  {0x40, "terrain_teleport"},
  {0x50, "thorns_anim0"},
  {0xaa, "tree"},
  {0x90, "volcanic1"},
  {0xa0, "volcanic2"},
  {0x40, "water_anim0"},
  {0x4a, "waterfall_anim0"},
  {0x40, "wheel1"},
  {0x4c, "wheel2"},
  {0x5e, "wheel3"},
  {0x6a, "wheel4"},
  {0x9c, "window"},
  {0, NULL},
};

/*===========================================================================*/

typedef struct {
  const char *name;
  ahi_collection_t *tiles;
} tileset_t;

void create_tileset(tileset_t *tileset, const char *name) {
  tileset->name = name;
  char *path = ag_strprintf("src/tiles/%s.ahi", name);
  FILE *file = fopen(path, "r");
  if (file == NULL) ag_fatal("could not open %s", path);
  free(path);
  input_t input;
  input_init(&input, file);
  tileset->tiles = ahi_parse_collection(&input);
  fclose(file);
}

void destroy_tileset(tileset_t *tileset) {
  ahi_delete_collection(tileset->tiles);
}

/*===========================================================================*/

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

FILE *new_blockset_file(const char *area_name, int block_row) {
  char *path = ag_strprintf("out/blocks/%s_%x.ahi", area_name, block_row);
  FILE *file = fopen(path, "w");
  if (file == NULL) ag_fatal("could not open %s", path);
  free(path);
  return file;
}

void blit_tile_to_block(ahi_image_t *block, int tile_row, int tile_col,
                        const ahi_image_t *tile) {
  if (tile == NULL) return;
  ahi_blit_image(block, tile, tile_col * TILE_WIDTH, tile_row * TILE_HEIGHT);
}

char get_tile_id(const char *tileset, int tile_index) {
  for (int i = 0; tile_files[i].name != NULL; ++i) {
    if (0 == strcmp(tileset, tile_files[i].name)) {
      return tile_files[i].start + tile_index;
    }
  }
  ag_fatal("unknown tileset: %s", tileset);
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

  input_t input;
  input_init(&input, stdin);
  bg_background_t *background = bg_parse_background(&input);
  if (background->width != 2 * NUM_BLOCK_COLS || background->height % 2 != 0 ||
      background->height > 2 * MAX_BLOCK_ROWS) {
    ag_fatal("invalid size: %dx%d", background->width, background->height);
  }
  const int num_block_rows = background->height / 2;

  tileset_t *tilesets = calloc(background->num_tilesets, sizeof(tileset_t));
  for (int i = 0; i < background->num_tilesets; ++i) {
    create_tileset(&tilesets[i], background->tilesets[i]);
  }

  // Construct the blocks.
  for (int block_row = 0; block_row < num_block_rows; ++block_row) {
    const ahi_image_t *tiles[4 * NUM_BLOCK_COLS] = {NULL};
    unsigned char tile_ids[4 * NUM_BLOCK_COLS] = {0};
    for (int tile_row = 0; tile_row < 2; ++tile_row) {
      for (int tile_col = 0; tile_col < 2 * NUM_BLOCK_COLS; ++tile_col) {
        const bg_tile_t *tile =
          &background->tiles[block_row * NUM_BLOCK_COLS * 4 +
                             tile_row * NUM_BLOCK_COLS * 2 + tile_col];
        if (!tile->present) continue;
        const tileset_t *tileset = &tilesets[tile->tileset_index];
        if (tile->tile_index >= tileset->tiles->num_images) {
          ag_fatal("tile index %d out of range for tileset '%s'",
                   tile->tile_index, tileset->name);
        }
        const int array_index = 2 * NUM_BLOCK_COLS * tile_row + tile_col;
        tiles[array_index] = tileset->tiles->images[tile->tile_index];
        tile_ids[array_index] = get_tile_id(tileset->name, tile->tile_index);
      }
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
    ahi_collection_t *blocks = ahi_new_collection(1, NUM_BLOCK_COLS);
    blocks->palettes[0] = ag_strdup("000B;0;54;ECEEEC;FF0;FF0;FF0;FF0;"
                                    "FF0;FF0;FF0;FF0;FF0;FF0;FF0;FF0");
    for (int block_col = 0; block_col < NUM_BLOCK_COLS; ++block_col) {
      ahi_image_t *block = ahi_new_image(BLOCK_WIDTH, BLOCK_HEIGHT);
      blit_tile_to_block(block, 0, 0, tiles[2 * block_col]);
      blit_tile_to_block(block, 0, 1, tiles[2 * block_col + 1]);
      blit_tile_to_block(block, 1, 0,
                         tiles[2 * (NUM_BLOCK_COLS + block_col)]);
      blit_tile_to_block(block, 1, 1,
                         tiles[2 * (NUM_BLOCK_COLS + block_col) + 1]);
      blocks->images[block_col] = block;
    }
    FILE *file = new_blockset_file(area_name, block_row);
    ahi_write_collection(file, blocks);
    fclose(file);
    ahi_delete_collection(blocks);
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
  for (int i = 0; i < background->num_tilesets; ++i) {
    destroy_tileset(&tilesets[i]);
  }
  free(tilesets);
  bg_delete_background(background);

  return EXIT_SUCCESS;
}

/*===========================================================================*/
