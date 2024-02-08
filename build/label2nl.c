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

#define MAX_LINE_LENGTH 1000

/*===========================================================================*/

void process_line(const char *line, int num_ranges, const int *min,
                  const int *max) {
  unsigned int addr;
  int count;
  char ignored;
  if (sscanf(line, "al %x .%n%c", &addr, &count, &ignored) != 2) return;
  for (int i = 0; i < num_ranges; ++i) {
    if (min[i] <= addr && addr <= max[i]) {
      const char* symbol = line + count;
      // See https://fceux.com/web/help/NLFilesFormat.html
      fprintf(stdout, "$%04X#%s#\n", addr, symbol);
    }
  }
}

int process_input(int num_ranges, const int *min, const int *max) {
  char buffer[MAX_LINE_LENGTH + 1];
  int line_length = 0;
  while (1) {
    const int ch = fgetc(stdin);
    if (ch == EOF || ch == '\n') {
      buffer[line_length] = '\0';
      process_line(buffer, num_ranges, min, max);
      if (ch == EOF) break;
      line_length = 0;
    } else if (line_length >= MAX_LINE_LENGTH) {
      fprintf(stderr, "Overlong input line.\n");
      return EXIT_FAILURE;
    } else {
      buffer[line_length++] = ch;
    }
  }
  return EXIT_SUCCESS;
}

int main(int argc, char **argv) {
  if (argc < 3 || argc % 2 != 1) {
    fprintf(stderr, "Usage: %s min1 max1 ... < in.labels.txt > out.nl\n",
            argv[0]);
    return EXIT_FAILURE;
  }

  const int num_ranges = (argc - 1) / 2;
  int *min = calloc(num_ranges, sizeof(int));
  int *max = calloc(num_ranges, sizeof(int));
  for (int i = 0; i < num_ranges; ++i) {
    min[i] = strtoul(argv[1 + 2 * i], NULL, 16);
    max[i] = strtoul(argv[2 + 2 * i], NULL, 16);
  }

  const int result = process_input(num_ranges, min, max);
  free(max);
  free(min);
  return result;
}

/*===========================================================================*/
