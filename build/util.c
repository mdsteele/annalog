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
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

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
