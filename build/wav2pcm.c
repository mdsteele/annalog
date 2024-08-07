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

void expect_eof(void) {
  int ch = fgetc(stdin);
  if (ch != EOF) {
    ERROR("expected EOF, but found '\\x%02x'\n", ch);
  }
}

unsigned char read_u8(const char *label) {
  char buffer[1];
  if (!try_read_bytes(buffer, 1)) {
    ERROR("expected u8 %s, but found EOF\n", label);
  }
  return (unsigned char)buffer[0];
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
  const int sample_rate = read_u32("sample rate");
  expect_u32("byte rate", sample_rate);
  expect_u16("bytes per sample", 1);
  expect_u16("bits per sample", 8);

  expect_tag("data");
  const unsigned long num_wav_samples = read_u32("data subchunk size");
  const unsigned long num_pcm_bytes = 0x2000;

  unsigned long wav_samples_remaining = num_wav_samples;
  unsigned long pcm_bytes_remaining = num_pcm_bytes;
  unsigned long num_padding_samples = 0;
  while (pcm_bytes_remaining > 0) {
    // Each PCM sample is seven bits.  Collect eight PCM samples at a time.
    unsigned char pcm_samples[8];
    for (int i = 0; i < 8; ++i) {
      if (wav_samples_remaining > 0) {
        const unsigned char sample = read_u8("sample");
        --wav_samples_remaining;
        pcm_samples[i] = sample / 2;
      } else {
        pcm_samples[i] = 0x40;
        ++num_padding_samples;
      }
    }
    // Emit seven PCM bytes for each group of eight PCM samples.  For the ith
    // byte, the bottom seven bits are the seven bits of pcm_samples[i], and
    // the highest bit is the ith bit from the top of pcm_samples[7].
    for (int i = 0; i < 7; ++i) {
      const unsigned char pcm_byte =
        pcm_samples[i] | (((pcm_samples[7] >> (6 - i)) & 1) << 7);
      if (pcm_bytes_remaining > 0) {
        fputc(pcm_byte, stdout);
        --pcm_bytes_remaining;
      }
    }
  }
  const unsigned long wav_samples_discarded = wav_samples_remaining;
  while (wav_samples_remaining > 0) {
    read_u8("sample");
    --wav_samples_remaining;
  }
  expect_eof();

  fprintf(stderr, "    sample_rate           = %d Hz\n", sample_rate);
  fprintf(stderr, "    num_wav_samples       = $%04lx (%4d ms)\n",
          num_wav_samples,
          (int)(1000 * (double)num_wav_samples / (double)sample_rate));
  fprintf(stderr, "    num_padding_samples   = $%04lx (%4d ms)\n",
          num_padding_samples,
          (int)(1000 * (double)num_padding_samples / (double)sample_rate));
  fprintf(stderr, "    wav_samples_discarded = $%04lx (%4d ms)\n",
          wav_samples_discarded,
          (int)(1000 * (double)wav_samples_discarded / (double)sample_rate));
  return EXIT_SUCCESS;
}

/*===========================================================================*/
