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

#define AMPLITUDE_PER_DM_STEP 500

#define ERROR(...) do {           \
    fprintf(stderr, "ERROR: ");   \
    fprintf(stderr, __VA_ARGS__); \
    exit(EXIT_FAILURE);           \
  } while (0)

/*===========================================================================*/

int try_read_bytes(char *buffer, int count) {
  for (int i = 0; i < count; ++i) {
    int ch = fgetc(stdin);
    if (ch == EOF) {
      return 0;
    }
    buffer[i] = ch;
  }
  return 1;
}

void expect_tag(const char *tag) {
  char buffer[5];
  if (!try_read_bytes(buffer, 4)) {
    ERROR("expected '%s', but found EOF\n", tag);
  }
  buffer[4] = '\0';
  if (strcmp(tag, buffer)) {
    ERROR("expected '%s', but found '%s'\n", tag, buffer);
  }
}

void expect_eof() {
  int ch = fgetc(stdin);
  if (ch != EOF) {
    ERROR("expected EOF, but found '\\x%02x'\n", ch);
  }
}

int read_i16(const char *label) {
  char buffer[2];
  if (!try_read_bytes(buffer, 2)) {
    ERROR("expected i16 %s, but found EOF\n", label);
  }
  return ((int)buffer[1] << 8) | (0xff & (int)buffer[0]);
}

unsigned int read_u16(const char *label) {
  char buffer[2];
  if (!try_read_bytes(buffer, 2)) {
    ERROR("expected u16 %s, but found EOF\n", label);
  }
  return (((0xff & (unsigned int)buffer[1]) << 8) |
          (0xff & (unsigned int)buffer[0]));
}

unsigned long read_u32(const char *label) {
  char buffer[4];
  if (!try_read_bytes(buffer, 4)) {
    ERROR("expected u32 %s, but found EOF\n", label);
  }
  return (((0xff & (unsigned int)buffer[3]) << 24) |
          ((0xff & (unsigned int)buffer[2]) << 16) |
          ((0xff & (unsigned int)buffer[1]) << 8) |
          (0xff & (unsigned int)buffer[0]));
}

void expect_u16(const char *label, unsigned int expected) {
  unsigned int actual = read_u16(label);
  if (actual != expected) {
    ERROR("expected %s to be %u, but found %u\n", label, expected, actual);
  }
}

void expect_u32(const char *label, unsigned long expected) {
  unsigned long actual = read_u32(label);
  if (actual != expected) {
    ERROR("expected %s to be %lu, but found %lu\n", label, expected, actual);
  }
}

/*===========================================================================*/

int main(int argc, char **argv) {
  expect_tag("RIFF");
  read_u32("RIFF chunk size");
  expect_tag("WAVE");

  expect_tag("fmt ");
  expect_u32("fmt subchunk size", 16);
  expect_u16("audio format", 1);  // 1 = PCM
  expect_u16("num channels", 1);
  int sample_rate = read_u32("sample rate");
  expect_u32("byte rate", 2 * sample_rate);
  expect_u16("bytes per sample", 2);
  expect_u16("bits per sample", 16);

  expect_tag("data");
  unsigned long num_samples = read_u32("data subchunk size") / 2;

  unsigned long num_dm_bytes = num_samples / 8;
  num_dm_bytes -= (num_dm_bytes - 1) % 16u;
  unsigned long num_samples_to_use = num_dm_bytes * 8;
  unsigned long num_samples_to_discard = num_samples - num_samples_to_use;

  int dm_value = 0x40;
  for (unsigned long i = 0; i < num_dm_bytes; ++i) {
    unsigned char dm_byte = 0;
    for (int dm_bits = 0; dm_bits < 8; ++dm_bits) {
      int sample = read_i16("sample");
      int dm_amplitude = (dm_value - 0x40) * AMPLITUDE_PER_DM_STEP;
      if (sample > dm_amplitude) {
        dm_byte |= 1 << dm_bits;
        if (dm_value + 2 <= 0x7f) {
          dm_value += 2;
        }
      } else {
        dm_byte |= 0 << dm_bits;
        if (dm_value - 2 >= 0) {
          dm_value -= 2;
        }
      }
    }
    fputc(dm_byte, stdout);
  }
  for (unsigned long i = 0; i < num_samples_to_discard; ++i) {
    read_i16("sample");
  }
  expect_eof();

  fprintf(stderr, "    sample_rate=%d\n", sample_rate);
  fprintf(stderr, "    num_samples=%lu\n", num_samples);
  fprintf(stderr, "    num_dm_bytes=$%04lx\n", num_dm_bytes);
  fprintf(stderr, "    samples_discarded=%lu\n", num_samples_to_discard);
  return EXIT_SUCCESS;
}

/*===========================================================================*/
