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

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*===========================================================================*/

#define HALF_STEPS_PER_OCTAVE 12
#define NTSC_CPU_FREQ 1.789773e6
#define NUM_LETTERS 26

#define MAX_IDENTIFIER_CHARS 80
#define MAX_INTEGER_DIGITS 6
#define MAX_NOTES_PER_PHRASE 1000
#define MAX_PARTS_PER_SONG NUM_LETTERS
#define MAX_PHRASES_PER_CHAIN 1000
#define MAX_PHRASES_PER_FILE 128
#define MAX_QUOTED_STRING_CHARS 80
#define MAX_SEGMENT_CHARS 80
#define MAX_SONGS_PER_FILE 20

// Pitch number (in half steps above c0) and frequency (in Hz) of a4:
#define A4_PITCH (9 + 4 * HALF_STEPS_PER_OCTAVE)
#define A4_FREQUENCY 440.0

/*===========================================================================*/

static struct {
  int last_char; // the most recent character read
  int line_number;
  int reached_eof;
} input = {
  .line_number = 1,
};

#define ERROR(...) do { \
    fprintf(stderr, "line %d: error: ", input.line_number); \
    fprintf(stderr, __VA_ARGS__); \
    exit(EXIT_FAILURE); \
  } while (0)

static char read_char(void) {
  int ch = fgetc(stdin);
  if (input.last_char == '\n') ++input.line_number;
  if (ch == EOF) {
    input.reached_eof = 1;
    ch = '\n';
  }
  input.last_char = ch;
  return ch;
}

static char peek_char(void) {
  int ch = fgetc(stdin);
  ungetc(ch, stdin);
  return ch == EOF ? '\n' : ch;
}

static void read_zero_or_more_spaces(void) {
  while (peek_char() == ' ') read_char();
}

static void read_one_or_more_spaces(void) {
  if (read_char() != ' ') ERROR("espected space, not '%c'\n", input.last_char);
  read_zero_or_more_spaces();
}

static int read_exactly(const char *str) {
  for (char ch = *str; ch != 0; ch = *++str) {
    if (read_char() != ch) return 0;
  }
  return 1;
}

static unsigned short read_phrase_name(void) {
  unsigned short name = 0;
  for (int i = 0; i < 2; ++i) {
    char ch = read_char();
    if ((ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9')) {
      name = (name << 8) | ch;
    } else ERROR("invalid character in phrase name: '%c'\n", ch);
  }
  return name;
}

static char *read_identifier(void) {
  int num_chars = 0;
  char buffer[MAX_IDENTIFIER_CHARS + 1];
  while (1) {
    const char ch = peek_char();
    if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
        (ch >= '0' && ch <= '9') || ch == '_') {
      read_char();
      if (num_chars >= MAX_IDENTIFIER_CHARS) ERROR("identifier is too long\n");
      buffer[num_chars++] = ch;
    } else if (num_chars == 0) {
      ERROR("expected identifier, not '%c'\n", ch);
    } else break;
  }
  buffer[num_chars] = '\0';
  return strdup(buffer);
}

static char *read_quoted_string(void) {
  if (read_char() != '"') {
    ERROR("expected a quoted string, not '%c'\n", input.last_char);
  }
  int num_chars = 0;
  char buffer[MAX_QUOTED_STRING_CHARS + 1];
  while (read_char() != '"') {
    if (input.last_char == '\n') ERROR("unterminated quoted string\n");
    if (num_chars >= MAX_QUOTED_STRING_CHARS) {
      ERROR("quoted string is too long\n");
    }
    buffer[num_chars++] = input.last_char;
  }
  buffer[num_chars] = '\0';
  return strdup(buffer);
}

static int read_unsigned_decimal_int(void) {
  int value = 0;
  int num_digits = 0;
  while (1) {
    const char ch = peek_char();
    if (ch < '0' || ch > '9') {
      if (num_digits == 0) ERROR("expected integer, not '%c'\n", ch);
      return value;
    }
    read_char();
    ++num_digits;
    if (num_digits > MAX_INTEGER_DIGITS) ERROR("integer value is too large\n");
    value = 10 * value + (ch - '0');
  }
}

static int read_unsigned_hex_or_dec_int(void) {
  if (peek_char() != '$') return read_unsigned_decimal_int();
  read_char();
  int value = 0;
  int num_digits = 0;
  while (1) {
    const char ch = peek_char();
    int digit;
    if (ch >= '0' && ch <= '9') digit = ch - '0';
    else if (ch >= 'a' && ch <= 'f') digit = ch - 'a' + 10;
    else if (ch >= 'A' && ch <= 'F') digit = ch - 'A' + 10;
    else if (num_digits == 0) ERROR("expected hex digit, not '%c'\n", ch);
    else return value;
    read_char();
    ++num_digits;
    if (num_digits > MAX_INTEGER_DIGITS) ERROR("integer value is too large\n");
    value = 0x10 * value + digit;
  }
}

static int read_signed_decimal_int(void) {
  int sign = 1;
  switch (read_char()) {
    case '+': sign = 1; break;
    case '-': sign = -1; break;
    default: ERROR("invalid sign char: '%c'\n", input.last_char);
  }
  return sign * read_unsigned_decimal_int();
}

/*===========================================================================*/

typedef enum {
  CH_NONE = -1,
  CH_PULSE1 = 0,
  CH_PULSE2,
  CH_TRIANGLE,
  CH_NOISE,
  CH_DMC,
  NUM_CHANNELS
} sng_channel_t;

static sng_channel_t read_channel() {
  switch (read_char()) {
    case '1': return CH_PULSE1;
    case '2': return CH_PULSE2;
    case 'T': return CH_TRIANGLE;
    case 'N': return CH_NOISE;
    case 'D': return CH_DMC;
    default: ERROR("invalid channel name: '%c'\n", input.last_char);
  }
}

static char channel_name(sng_channel_t channel) {
  switch (channel) {
    case CH_PULSE1:     return '1';
    case CH_PULSE2:     return '2';
    case CH_TRIANGLE:   return 'T';
    case CH_NOISE:      return 'N';
    case CH_DMC:        return 'D';
    default: assert(0); return '?';
  }
}

/*===========================================================================*/

typedef struct {
  enum { NT_REST, NT_INST, NT_TONE, NT_DPCM } kind;
  unsigned char duration;
  unsigned short param;
  const char *id;
} sng_note_t;

typedef struct {
  unsigned short name;
  int num_notes;
  sng_note_t *notes;
} sng_phrase_t;

typedef struct {
  const char *alias_song_id;
  char alias_part_name;
  sng_channel_t alias_channel;
  int num_phrases;
  int *phrase_indices;
} sng_chain_t;

typedef struct {
  char letter;  // from 'A' to 'Z'
  sng_chain_t chains[NUM_CHANNELS];
} sng_part_t;

typedef struct {
  const char *id;
  unsigned char param;
} sng_inst_t;

typedef struct {
  enum { OP_STOP, OP_JUMP, OP_SETF, OP_BFEQ, OP_PLAY } kind;
  signed char delta;   // for JUMP and BFEQ
  unsigned char flag;  // for SETF and BFEQ
  char part;           // for PLAY
} sng_opcode_t;

typedef struct {
  const char *id;
  int num_opcodes;
  sng_opcode_t *opcodes;
  int num_parts;
  sng_part_t *parts;
  int part_index_for_letter[NUM_LETTERS];
  sng_inst_t instruments[NUM_CHANNELS][NUM_LETTERS];
} sng_song_t;

typedef struct {
  const char *id;
  unsigned char length_param;
} sng_sample_t;

static struct {
  const char *segment; // e.g. "PRG8" or "PRGC_Core"
  const char *prefix; // e.g. "Data" or "DataC_Core"
  sng_sample_t samples[NUM_LETTERS];
  int num_songs;
  sng_song_t songs[MAX_SONGS_PER_FILE];
  int num_phrases;
  sng_phrase_t phrases[MAX_PHRASES_PER_FILE];
  enum {
    BEGIN_LINE,
    NEW_NOTE,
    ADJUST_PITCH,
    CONTINUE_DURATION,
    BEGIN_DURATION,
    ADJUST_DURATION,
    DONE_NOTE,
    AFTER_DECL_OR_DIR,
    LINE_COMMENT
  } state;
  int frames_per_whole_note;
  int current_key; // -k = k flats, +k = k sharps
  int global_transpose;  // num half steps
  sng_channel_t current_channel;
  int current_phrase_for_channel[NUM_CHANNELS];
  int is_defining_phrase;  // 0 or 1
  int sample_index; // -1 = non-sample, otherwise index into parser.samples
  int noise_period; // -1 = non-noise, otherwise 0x0-0xF
  int named_pitch; // -1 = rest, 0 = C, 1 = C#, ..., 11 = B
  int base_pitch; // initially, named_pitch with current_key applied
  int pitch_adjust; // 1 = sharp, -1 = flat
  int octave;
  int base_duration; // measured in frames
  int extra_duration; // measured in frames
} parser;

static void begin_line(void) {
  parser.state = BEGIN_LINE;
  parser.octave = -1;
  parser.base_duration = -1;
  assert(parser.extra_duration == 0);
}

static void finish_current_part_if_any(void) {
  if (parser.is_defining_phrase) ERROR("unterminated phrase definition\n");
  parser.current_channel = CH_NONE;
  for (int c = 0; c < NUM_CHANNELS; ++c) {
    parser.current_phrase_for_channel[c] = -1;
  }
}

static void init_parser(void) {
  parser.frames_per_whole_note = 96;  // default tempo
  finish_current_part_if_any();
  begin_line();
}

static void change_channel(sng_channel_t channel) {
  assert(channel != CH_NONE);
  if (parser.num_songs == 0) ERROR("can't set channel outside of a song\n");
  sng_song_t *song = &parser.songs[parser.num_songs - 1];
  if (song->num_parts == 0) ERROR("can't set channel outside of a part\n");
  if (parser.current_channel != channel) {
    if (parser.is_defining_phrase) {
      ERROR("can't set channel within a phrase definition\n");
    }
    parser.current_channel = channel;
  }
  parser.state = NEW_NOTE;
}

static void finish_current_song_if_any(void) {
  finish_current_part_if_any();
  if (parser.num_songs == 0) return;
  const sng_song_t *song = &parser.songs[parser.num_songs - 1];
  // Check that all the parts mentioned in the spec actually exist.
  for (int o = 0; o < song->num_opcodes; ++o) {
    const sng_opcode_t *opcode = &song->opcodes[o];
    if (opcode->kind != OP_PLAY) continue;
    if (song->part_index_for_letter[opcode->part - 'A'] < 0) {
      ERROR("Part %s:%c was never declared\n", song->id, opcode->part);
    }
  }
}

/*===========================================================================*/

static void start_note(void) {
  if (parser.current_channel == CH_NONE) {
    ERROR("can't start a note before setting the channel\n");
  }
  parser.noise_period = -1;
  parser.sample_index = -1;
  parser.named_pitch = -1;
  parser.base_pitch = -1;
  parser.pitch_adjust = 0;
}

static void start_tone(int named_pitch, int flat_key, int sharp_key) {
  start_note();
  if (parser.current_channel == CH_NOISE || parser.current_channel == CH_DMC) {
    ERROR("tonal notes aren't allowed on channel %c\n",
          channel_name(parser.current_channel));
  }
  parser.named_pitch = parser.base_pitch = named_pitch;
  if (parser.current_key <= flat_key) --parser.base_pitch;
  else if (parser.current_key >= sharp_key) ++parser.base_pitch;
  parser.state = ADJUST_PITCH;
}

static void start_noise(void) {
  start_note();
  if (parser.current_channel != CH_NOISE) {
    ERROR("noise notes are only allowed on channel N\n");
  }
  char ch = read_char();
  if (ch >= 'A' && ch <= 'F') parser.noise_period = (ch - 'A') + 0xA;
  else if (ch >= '0' && ch <= '9') parser.noise_period = ch - '0';
  else ERROR("invalid noise period char: '%c'\n", ch);
  parser.state = BEGIN_DURATION;
}

static void start_rest(void) {
  start_note();
  parser.named_pitch = parser.base_pitch = -1;
  parser.state = BEGIN_DURATION;
}

static void start_sample(void) {
  start_note();
  if (parser.current_channel != CH_DMC) {
    ERROR("DPCM samples are only allowed on channel D\n");
  }
  char letter = read_char();
  if (letter < 'A' || letter > 'Z') {
    ERROR("invalid DPCM sample name: '%c'\n", letter);
  }
  int sample_index = letter - 'A';
  if (parser.samples[sample_index].id == NULL) {
    ERROR("no such DPCM sample: '%c'\n", letter);
  }
  parser.sample_index = sample_index;
  parser.state = BEGIN_DURATION;
}

static void start_base_duration(int denominator) {
  if (parser.frames_per_whole_note % denominator != 0) {
    ERROR("can't emit 1/%d note with tempo of w=%d\n", denominator,
          parser.frames_per_whole_note);
  }
  parser.base_duration = parser.frames_per_whole_note / denominator;
  parser.state = ADJUST_DURATION;
}

static void adjust_base_duration(int numerator, int denominator) {
  int new_base_duration = parser.base_duration * numerator;
  if (new_base_duration % denominator != 0) {
    ERROR("can't multiply note duration of %d frames by %d/%d\n",
          parser.base_duration, numerator, denominator);
  }
  new_base_duration /= denominator;
  parser.base_duration = new_base_duration;
}

static void append_phrase_to_current_chain(int phrase_index) {
  assert(parser.current_channel != CH_NONE);
  sng_song_t *song = &parser.songs[parser.num_songs - 1];
  sng_part_t *part = &song->parts[song->num_parts - 1];
  sng_chain_t *chain = &part->chains[parser.current_channel];
  if (chain->alias_song_id != NULL) {
    ERROR("cannot add notes to an aliased chain\n");
  }
  if (chain->phrase_indices == NULL) {
    chain->phrase_indices = calloc(MAX_PHRASES_PER_CHAIN, sizeof(int));
  }
  if (chain->num_phrases == MAX_PHRASES_PER_CHAIN) {
    ERROR("too many phrases in one chain\n");
  }
  chain->phrase_indices[chain->num_phrases++] = phrase_index;
}

// Returns the phrase that we're currently adding notes to.  If there's no
// active phrase, starts a new one.  The current channel must be set.
static sng_phrase_t *get_current_phrase(void) {
  assert(parser.current_channel != CH_NONE);
  int phrase_index = parser.current_phrase_for_channel[parser.current_channel];
  if (phrase_index >= 0) return &parser.phrases[phrase_index];
  if (parser.num_phrases == MAX_PHRASES_PER_FILE) {
    ERROR("too many distinct phrases");
  }
  phrase_index = parser.num_phrases++;
  append_phrase_to_current_chain(phrase_index);
  parser.current_phrase_for_channel[parser.current_channel] = phrase_index;
  sng_phrase_t *phrase = &parser.phrases[phrase_index];
  phrase->notes = calloc(MAX_NOTES_PER_PHRASE, sizeof(sng_note_t));
  return phrase;
}

// Allocates and returns a new note in the current phrase.
static sng_note_t *new_note(void) {
  sng_phrase_t *phrase = get_current_phrase();
  if (phrase->num_notes == MAX_NOTES_PER_PHRASE) {
    ERROR("too many notes in one phrase");
  }
  return &phrase->notes[phrase->num_notes++];
}

static void change_instrument(void) {
  if (parser.current_channel == CH_NONE) {
    ERROR("can't change instrument before setting the channel\n");
  }
  char inst_name = read_char();
  if (inst_name < 'A' || inst_name > 'Z') {
    ERROR("invalid instrument name: '%c'\n", inst_name);
  }
  int inst_index = inst_name - 'A';
  assert(parser.num_songs > 0);
  sng_song_t *song = &parser.songs[parser.num_songs - 1];
  assert(parser.current_channel != CH_NONE);
  sng_inst_t *inst = &song->instruments[parser.current_channel][inst_index];
  if (inst->id == NULL) {
    ERROR("instrument %c%c was never declared\n",
          channel_name(parser.current_channel), inst_name);
  }
  sng_note_t *note = new_note();
  note->kind = NT_INST;
  note->id = inst->id;
  note->param = inst->param;
  parser.state = DONE_NOTE;
}

// Adds a rest of the given duration to the current phrase.  If the duration is
// very long, this may produce multiple separate rest notes.
static void emit_rest(int num_frames) {
  while (num_frames > 0) {
    unsigned char duration = num_frames > 127 ? 127 : num_frames;
    sng_note_t *note = new_note();
    note->kind = NT_REST;
    note->duration = duration;
    num_frames -= duration;
  }
}

static void emit_tone(int absolute_pitch, int num_frames) {
  if (num_frames > 255) {
    ERROR("can't emit tone with duration of %d (max is 255)\n", num_frames);
  }
  const double a4_relative_pitch = absolute_pitch - A4_PITCH;
  const double frequency =
    A4_FREQUENCY * pow(2.0, a4_relative_pitch / HALF_STEPS_PER_OCTAVE);
  const double multiplier = parser.current_channel == CH_TRIANGLE ? 32. : 16.;
  const double value = NTSC_CPU_FREQ / (multiplier * frequency) - 1.0;
  sng_note_t *note = new_note();
  note->kind = NT_TONE;
  note->param = round(fmin(fmax(0.0, value), 2047.0));
  note->duration = num_frames;
}

static void emit_noise(int noise_period, int num_frames) {
  if (num_frames > 255) {
    ERROR("can't emit noise with duration of %d (max is 255)\n", num_frames);
  }
  sng_note_t *note = new_note();
  note->kind = NT_TONE;
  note->param = noise_period;
  note->duration = num_frames;
}

static void emit_sample(int sample_index, int num_frames) {
  if (num_frames > 255) {
    ERROR("can't emit DPCM sample with duration of %d (max is 255)\n",
          num_frames);
  }
  sng_sample_t *sample = &parser.samples[sample_index];
  sng_note_t *note = new_note();
  note->kind = NT_DPCM;
  note->id = sample->id;
  note->param = sample->length_param;
  note->duration = num_frames;
}

static void finish_note(void) {
  parser.state = NEW_NOTE;
  if (parser.base_duration < 0) {
    ERROR("must set explicit duration for first note on the line\n");
  }
  parser.base_duration += parser.extra_duration;
  parser.extra_duration = 0;
  if (parser.noise_period >= 0) {
    assert(parser.current_channel == CH_NOISE);
    emit_noise(parser.noise_period, parser.base_duration);
  } else if (parser.sample_index >= 0) {
    assert(parser.current_channel == CH_DMC);
    emit_sample(parser.sample_index, parser.base_duration);
  } else if (parser.named_pitch < 0) {
    emit_rest(parser.base_duration);
  } else if (parser.octave < 0) {
    ERROR("must set explicit octave for first note on the line\n");
  } else {
    const int absolute_pitch =
      parser.base_pitch + parser.pitch_adjust +
      HALF_STEPS_PER_OCTAVE * parser.octave + parser.global_transpose;
    emit_tone(absolute_pitch, parser.base_duration);
  }
}

/*===========================================================================*/

static void alias_chain(void) {
  if (parser.current_channel == CH_NONE) {
    ERROR("can't alias a chain before setting the channel\n");
  }
  sng_song_t *song = &parser.songs[parser.num_songs - 1];
  sng_part_t *part = &song->parts[song->num_parts - 1];
  sng_chain_t *chain = &part->chains[parser.current_channel];
  if (chain->num_phrases > 0) ERROR("cannot alias a non-empty chain\n");
  if (chain->alias_song_id != NULL) ERROR("cannot re-alias a chain\n");
  const sng_song_t *alias_song = NULL;
  if (peek_char() != ':') {
    const char *alias_song_id = read_identifier();
    for (int s = 0; s < parser.num_songs; ++s) {
      if (0 == strcmp(parser.songs[s].id, alias_song_id)) {
        alias_song = &parser.songs[s];
        break;
      }
    }
    if (alias_song == NULL) ERROR("no such song: '%s'\n", alias_song_id);
  } else alias_song = song;
  if (read_char() != ':') ERROR("Expected ':', not '%c'\n", input.last_char);
  char alias_part_name = read_char();
  if (alias_part_name < 'A' || alias_part_name > 'Z') {
    ERROR("invalid part name: '%c'\n", alias_part_name);
  }
  int alias_part_index =
    alias_song->part_index_for_letter[alias_part_name - 'A'];
  if (alias_part_index < 0) {
    ERROR("cannot alias to nonexistent part %s:%c\n",
          alias_song->id, alias_part_name);
  }
  sng_part_t *alias_part = &alias_song->parts[alias_part_index];
  sng_channel_t alias_channel = read_channel();
  sng_chain_t *alias_chain = &alias_part->chains[alias_channel];
  if (alias_chain->alias_song_id != NULL) {
    chain->alias_song_id = alias_chain->alias_song_id;
    chain->alias_part_name = alias_chain->alias_part_name;
    chain->alias_channel = alias_chain->alias_channel;
  } else {
    chain->alias_song_id = alias_song->id;
    chain->alias_part_name = alias_part_name;
    chain->alias_channel = alias_channel;
  }
}

static int find_phrase_index_for_name(unsigned short phrase_name) {
  for (int p = 0; p < parser.num_phrases; ++p) {
    if (parser.phrases[p].name == phrase_name) return p;
  }
  return -1;
}

static void start_inserting_phrase(void) {
  if (parser.is_defining_phrase) {
    ERROR("can't nest a phrase within a phrase definition\n");
  }
  if (parser.current_channel == CH_NONE) {
    ERROR("can't start a phrase before setting the channel\n");
  }
  parser.current_phrase_for_channel[parser.current_channel] = -1;
  char ch = peek_char();
  if (ch == '(') {
    read_char();
    parser.is_defining_phrase = 1;
  } else if ((ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9')) {
    unsigned short phrase_name = read_phrase_name();
    int phrase_index = find_phrase_index_for_name(phrase_name);
    if (phrase_index == -1) {
      ERROR("no such phrase: %c%c\n", phrase_name >> 8, phrase_name & 0xff);
    }
    append_phrase_to_current_chain(phrase_index);
  } else {
    ERROR("expected '(' or phrase name after 'p', not '%c'\n", ch);
  }
  parser.state = NEW_NOTE;
}

static void finish_defining_phrase(void) {
  if (!parser.is_defining_phrase) {
    ERROR("unexpected ')' while not defining a phrase\n");
  }
  parser.is_defining_phrase = 0;
  assert(parser.current_channel != CH_NONE);
  int phrase_index = parser.current_phrase_for_channel[parser.current_channel];
  if (phrase_index < 0) ERROR("cannot define empty phrase\n");
  unsigned short phrase_name = read_phrase_name();
  if (find_phrase_index_for_name(phrase_name) != -1) {
    ERROR("reused phrase name: %c%c\n", phrase_name >> 8, phrase_name & 0xff);
  }
  parser.phrases[phrase_index].name = phrase_name;
  parser.current_phrase_for_channel[parser.current_channel] = -1;
  parser.state = DONE_NOTE;
}

/*===========================================================================*/

static void read_song_spec(sng_song_t *song) {
  char *spec = read_quoted_string();
  // Validate spec syntax, count opcodes, and build label table.
  int label_table[NUM_LETTERS];
  for (int i = 0; i < NUM_LETTERS; ++i) label_table[i] = -1;
  int loop_point = -1;
  int num_opcodes = 0;
  for (const char *ptr = spec; *ptr != '\0'; ++ptr) {
    char ch = *ptr;
    if (ch >= 'A' && ch <= 'Z') ++num_opcodes;
    else if (ch >= 'a' && ch <= 'z') {
      int *dest = &label_table[ch - 'a'];
      if (*dest >= 0) ERROR("reused label '%c' in song spec\n", ch);
      *dest = num_opcodes;
    } else if (ch == '|') {
      if (loop_point != -1) ERROR("song spec has multiple loop points\n");
      loop_point = num_opcodes;
    } else if (ch == '!') {
      ch = *++ptr;
      if (ch == '\0') ERROR("incomplete '!' in song spec\n");
      if (ch != '0' && ch != '1') ERROR("invalid '!' flag value '%c'\n", ch);
      ++num_opcodes;
    } else if (ch == '?') {
      ch = *++ptr;
      if (ch == '\0') ERROR("incomplete '?' in song spec\n");
      if (ch != '0' && ch != '1') ERROR("invalid '?' flag value '%c'\n", ch);
      ch = *++ptr;
      if (ch == '\0') ERROR("incomplete '?' in song spec\n");
      if (ch < 'a' || ch > 'z') ERROR("invalid '?' label '%c'\n", ch);
      ++num_opcodes;
    } else if (ch == '@') {
      ch = *++ptr;
      if (ch == '\0') ERROR("incomplete '@' in song spec\n");
      if (ch < 'a' || ch > 'z') ERROR("invalid '@' label '%c'\n", ch);
      ++num_opcodes;
    } else if (ch != ' ') ERROR("unexpected '%c' in song spec\n", ch);
  }
  ++num_opcodes;  // add one for the implicit STOP/JUMP at the end
  // Compile the spec into an array of sng_opcode_t structs.  We'll validate
  // the part names once the rest of the song definition is finished.
  song->num_opcodes = num_opcodes;
  song->opcodes = calloc(num_opcodes, sizeof(sng_opcode_t));
  int pc = 0;
  for (const char *ptr = spec; *ptr != '\0'; ++ptr) {
    char ch = *ptr;
    if (ch >= 'A' && ch <= 'Z') {
      song->opcodes[pc++] = (sng_opcode_t){ .kind = OP_PLAY, .part = ch };
    } else if (ch == '!') {
      int flag = (*++ptr - '0') & 1;
      song->opcodes[pc++] = (sng_opcode_t){ .kind = OP_SETF, .flag = flag };
    } else if (ch == '?') {
      int flag = (*++ptr - '0') & 1;
      char label = *++ptr;
      int index = label - 'a';
      if (label_table[index] < 0) ERROR("no such label: '%c'\n", label);
      int delta = label_table[index] - pc;
      if (delta == 0) ERROR("illegal BFEQ destination\n");
      if (delta > 31 || delta < -32) ERROR("BFEQ destination out of range\n");
      song->opcodes[pc++] = (sng_opcode_t){
        .kind = OP_BFEQ,
        .flag = flag,
        .delta = delta,
      };
    } else if (ch == '@') {
      char label = *++ptr;
      int index = label - 'a';
      if (label_table[index] < 0) ERROR("no such label: '%c'\n", label);
      int delta = label_table[index] - pc;
      if (delta > 31 || delta < -32) ERROR("JUMP destination out of range\n");
      song->opcodes[pc++] = (sng_opcode_t){ .kind = OP_JUMP, .delta = delta };
    }
  }
  if (loop_point >= 0 && loop_point < pc) {
    int delta = loop_point - pc;
    song->opcodes[pc++] = (sng_opcode_t){ .kind = OP_JUMP, .delta = delta };
  } else song->opcodes[pc++] = (sng_opcode_t){ .kind = OP_STOP };
  assert(pc == song->num_opcodes);
  free(spec);
}

/*===========================================================================*/

static void parse_dpcm_declaration(void) {
  read_one_or_more_spaces();
  const char letter = read_char();
  if (letter < 'A' || letter > 'Z') {
    ERROR("invalid DPCM sample name: '%c'\n", letter);
  }
  sng_sample_t *sample = &parser.samples[letter - 'A'];
  if (sample->id != NULL) {
    ERROR("reused DPCM sample name: '%c'\n", letter);
  }
  read_one_or_more_spaces();
  sample->id = read_identifier();
  read_one_or_more_spaces();
  int length = read_unsigned_hex_or_dec_int();
  if ((length >> 4) > 0x3f) {
    ERROR("sample byte length is too high\n");
  } else if (length % 16 != 1) {
    ERROR("sample byte length must be 1 mod 16\n");
  }
  sample->length_param = length >> 4;
}

static void parse_inst_declaration(void) {
  if (parser.num_songs == 0) {
    ERROR("can't declare an instrument outside of a song\n");
  }
  sng_song_t *song = &parser.songs[parser.num_songs - 1];
  read_one_or_more_spaces();
  sng_channel_t channel = read_channel();
  char inst_name = read_char();
  if (inst_name < 'A' || inst_name > 'Z') {
    ERROR("invalid instrument name: '%c'\n", inst_name);
  }
  sng_inst_t *inst = &song->instruments[channel][inst_name - 'A'];
  if (inst->id != NULL) {
    ERROR("reused instrument channel/name: '%c%c'\n",
          channel_name(channel), inst_name);
  }
  read_one_or_more_spaces();
  inst->id = read_identifier();
  read_one_or_more_spaces();
  int param = read_unsigned_hex_or_dec_int();
  if (param > 255) ERROR("invalid instrument param: %d\n", param);
  inst->param = param;
}

static void parse_part_declaration(void) {
  finish_current_part_if_any();
  if (parser.num_songs == 0) {
    ERROR("can't declare a part outside of a song\n");
  }
  sng_song_t *song = &parser.songs[parser.num_songs - 1];
  read_one_or_more_spaces();
  const char letter = read_char();
  if (letter < 'A' || letter > 'Z') {
    ERROR("invalid part name: '%c'\n", letter);
  }
  if (song->part_index_for_letter[letter - 'A'] >= 0) {
    ERROR("reused part name: '%c'\n", letter);
  }
  assert(song->num_parts < MAX_PARTS_PER_SONG);
  song->part_index_for_letter[letter - 'A'] = song->num_parts;
  sng_part_t *part = &song->parts[song->num_parts++];
  part->letter = letter;
}

static void parse_song_declaration(void) {
  finish_current_song_if_any();
  if (parser.num_songs == MAX_SONGS_PER_FILE) {
    ERROR("too many songs in one file\n");
  }
  read_one_or_more_spaces();
  const char *id = read_identifier();
  for (int s = 0; s < parser.num_songs; ++s) {
    if (0 == strcmp(parser.songs[s].id, id)) {
      ERROR("reused song name: '%s'\n", id);
    }
  }
  sng_song_t* song = &parser.songs[parser.num_songs++];
  song->id = id;
  read_one_or_more_spaces();
  read_song_spec(song);
  song->parts = calloc(MAX_PARTS_PER_SONG, sizeof(sng_part_t));
  for (int p = 0; p < MAX_PARTS_PER_SONG; ++p) {
    song->part_index_for_letter[p] = -1;
  }
}

static void parse_declaration(void) {
  switch (read_char()) {
    case 'D':
      if (!read_exactly("PCM")) goto invalid;
      parse_dpcm_declaration();
      break;
    case 'I':
      if (!read_exactly("NST")) goto invalid;
      parse_inst_declaration();
      break;
    case 'P':
      if (!read_exactly("ART")) goto invalid;
      parse_part_declaration();
      break;
    case 'S':
      if (!read_exactly("ONG")) goto invalid;
      parse_song_declaration();
      break;
    default:
    invalid:
      ERROR("invalid declaration\n");
  }
  parser.state = AFTER_DECL_OR_DIR;
}

/*===========================================================================*/

static void parse_key_directive(void) {
  read_one_or_more_spaces();
  int num_accidentals = read_unsigned_decimal_int();
  if (num_accidentals > 7) ERROR("invalid key signature number\n");
  switch (read_char()) {
    case '#': parser.current_key = num_accidentals; break;
    case 'b': parser.current_key = -num_accidentals; break;
    case 'N': parser.current_key = 0; break;
    default: ERROR("invalid key signature accidental\n");
  }
}

static void parse_tempo_directive(void) {
  read_one_or_more_spaces();
  int multiplier = 1;
  switch (read_char()) {
    case 'w': multiplier = 1; break;
    case 'h': multiplier = 2; break;
    case 'q': multiplier = 4; break;
    case 'e': multiplier = 8; break;
    case 's': multiplier = 16; break;
    case 't': multiplier = 32; break;
    case 'x': multiplier = 64; break;
    default: ERROR("invalid tempo basis '%c'\n", input.last_char);
  }
  int num_frames = read_unsigned_decimal_int();
  parser.frames_per_whole_note = multiplier * num_frames;
}

static void parse_transpose_directive(void) {
  read_one_or_more_spaces();
  parser.global_transpose = read_signed_decimal_int();
}

void parse_directive(void) {
  switch (read_char()) {
    case 'k':
      if (!read_exactly("ey")) goto invalid;
      parse_key_directive();
      break;
    case 't':
      switch (read_char()) {
        case 'e':
          if (!read_exactly("mpo")) goto invalid;
          parse_tempo_directive();
          break;
        case 'r':
          if (!read_exactly("anspose")) goto invalid;
          parse_transpose_directive();
          break;
        default: goto invalid;
      }
      break;
    default:
    invalid:
      ERROR("invalid directive\n");
  }
  parser.state = AFTER_DECL_OR_DIR;
}

/*===========================================================================*/

static void parse_segment(void) {
  if (parser.num_songs > 0) {
    ERROR("segment must be set before first song\n");
  } else if (parser.segment != NULL) {
    ERROR("segment has already been set to \"%s\"\n", parser.segment);
  }
  parser.segment = read_identifier();
  parser.state = AFTER_DECL_OR_DIR;
}

/*===========================================================================*/

static void parse_input(void) {
  init_parser();
  while (!input.reached_eof) {
    const char ch = read_char();
    switch (parser.state) {
      case BEGIN_LINE: {
        switch (ch) {
          case '@': parse_segment(); break;
          case '!': parse_declaration(); break;
          case '=': parse_directive(); break;
          case '1': change_channel(CH_PULSE1); break;
          case '2': change_channel(CH_PULSE2); break;
          case 'T': change_channel(CH_TRIANGLE); break;
          case 'N': change_channel(CH_NOISE); break;
          case 'D': change_channel(CH_DMC); break;
          case '%': parser.state = LINE_COMMENT; break;
          case ' ': parser.state = NEW_NOTE; break;
          case '\n': break;
          default: ERROR("invalid char at start-of-line: '%c'\n", ch);
        }
      } break;
      case NEW_NOTE: {
        switch (ch) {
          case '=': alias_chain(); break;
          case 'a': start_tone( 9, -3, 5); break;
          case 'b': start_tone(11, -1, 7); break;
          case 'c': start_tone( 0, -6, 2); break;
          case 'd': start_tone( 2, -4, 4); break;
          case 'e': start_tone( 4, -2, 6); break;
          case 'f': start_tone( 5, -7, 1); break;
          case 'g': start_tone( 7, -5, 3); break;
          case 'r': start_rest(); break;
          case 'x': start_noise(); break;
          case 's': start_sample(); break;
          case 'i': change_instrument(); break;
          case 'p': start_inserting_phrase(); break;
          case ')': finish_defining_phrase(); break;
          case '%': parser.state = LINE_COMMENT; break;
          case ' ': case '|': case '\'': break;
          case '\n': break;
          default: ERROR("invalid char at start-of-note: '%c'\n", ch);
        }
      } break;
      case ADJUST_PITCH: {
        switch (ch) {
          case '#':
            parser.base_pitch = parser.named_pitch;
            ++parser.pitch_adjust;
            break;
          case 'b':
            parser.base_pitch = parser.named_pitch;
            --parser.pitch_adjust;
            break;
          case 'N':
            parser.base_pitch = parser.named_pitch;
            parser.pitch_adjust = 0;
            break;
          case '0': case '1': case '2': case '3': case '4':
          case '5': case '6': case '7': case '8': case '9':
            parser.octave = ch - '0';
            parser.state = BEGIN_DURATION;
            break;
          case 'w': case 'h': case 'q': case 'e': case 's': case 't': case 'x':
            goto begin_duration;
          case ')': finish_note(); finish_defining_phrase(); break;
          case '%': finish_note(); parser.state = LINE_COMMENT; break;
          case ' ': case '|': case '\'': case '\n': finish_note(); break;
          default: ERROR("invalid char within note: '%c'\n", ch);
        }
      } break;
      case CONTINUE_DURATION: {
        switch (ch) {
          case 'w': case 'h': case 'q': case 'e': case 's': case 't': case 'x':
            goto begin_duration;
          case '+': break;
          case ' ': case '|': case '\'': break;
          case '\n':
            ERROR("unterminated duration continuation\n");
          default:
            ERROR("invalid duration continuation char: '%c'\n", ch);
        }
      } break;
      begin_duration:
      case BEGIN_DURATION: {
        switch (ch) {
          case 'w': start_base_duration(1); break;
          case 'h': start_base_duration(2); break;
          case 'q': start_base_duration(4); break;
          case 'e': start_base_duration(8); break;
          case 's': start_base_duration(16); break;
          case 't': start_base_duration(32); break;
          case 'x': start_base_duration(64); break;
          case ')': finish_note(); finish_defining_phrase(); break;
          case '%': finish_note(); parser.state = LINE_COMMENT; break;
          case ' ': case '|': case '\'': case '\n': finish_note(); break;
          default: ERROR("invalid duration char: '%c'\n", ch);
        }
      } break;
      case ADJUST_DURATION: {
        switch (ch) {
          case '.':
            parser.extra_duration += parser.base_duration;
            adjust_base_duration(1, 2);
            break;
          case '3': adjust_base_duration(2, 3); break;
          case '5': adjust_base_duration(4, 5); break;
          case '+':
            parser.extra_duration += parser.base_duration;
            parser.base_duration = 0;
            parser.state = CONTINUE_DURATION;
            break;
          case ')': finish_note(); finish_defining_phrase(); break;
          case '%': finish_note(); parser.state = LINE_COMMENT; break;
          case ' ': case '|': case '\'': case '\n': finish_note(); break;
          default: ERROR("invalid duration adjustment char: '%c'\n", ch);
        }
      } break;
      case DONE_NOTE: {
        switch (ch) {
          case '%': parser.state = LINE_COMMENT; break;
          case ' ': case '|': case '\'': parser.state = NEW_NOTE; break;
          case '\n': break;
          default: ERROR("invalid char after note: '%c'\n", ch);
        }
      } break;
      case AFTER_DECL_OR_DIR: {
        switch (ch) {
          case '%': parser.state = LINE_COMMENT; break;
          case ' ': break;
          case '\n': break;
          default:
            ERROR("invalid char after declaration/directive: '%c'\n", ch);
        }
      } break;
      case LINE_COMMENT: break;
    }
    if (ch == '\n') begin_line();
  }
  finish_current_song_if_any();
  if (parser.segment == NULL) parser.segment = "PRG8";
  parser.prefix = "Data";
  int segment_len = strlen(parser.segment);
  if (segment_len > 3 && parser.segment[3] == 'C') {
    char *prefix = calloc(segment_len + 2, sizeof(char));
    strncpy(prefix, "Data", 4);
    strncpy(prefix + 4, parser.segment + 3, segment_len - 3);
    parser.prefix = prefix;
  }
}

/*===========================================================================*/

static void write_separator(void) {
  fprintf(stdout,
          "\n;;;====================================="
          "====================================;;;\n");
}

static void write_notes(const sng_phrase_t *phrase) {
  assert(phrase->num_notes > 0);
  for (int n = 0; n < phrase->num_notes; ++n) {
    const sng_note_t *note = &phrase->notes[n];
    switch (note->kind) {
      case NT_REST: {
        assert(note->duration <= 127);
        fprintf(stdout, "    .byte $%02x            ; REST %d\n",
                note->duration, note->duration);
      } break;
      case NT_INST: {
        fprintf(stdout, "    .byte $80 | eInst::%s, $%02x\n",
                note->id, note->param);
      } break;
      case NT_TONE: {
        fprintf(stdout, "    .byte $%02x, $%02x, $%02x  ; TONE %d, %d\n",
                0xc0 | (note->param >> 8), note->param & 0xff,
                note->duration, note->param, note->duration);
      } break;
      case NT_DPCM: {
        fprintf(stdout, "    .byte $%02x, <(%s >> 6), $%02x\n",
                0xc0 | (note->param & 0xff), note->id, note->duration);
      } break;
    }
  }
  fprintf(stdout, "    .byte $00            ; DONE\n");
}

static void write_opcode(const sng_song_t *song, const sng_opcode_t *opcode) {
  switch (opcode->kind) {
    case OP_STOP:
      fprintf(stdout, "    .byte $00  ; STOP\n");
      break;
    case OP_JUMP:
      fprintf(stdout, "    .byte $%02x  ; JUMP %d\n",
              0x3f & opcode->delta, opcode->delta);
      break;
    case OP_SETF:
      fprintf(stdout, "    .byte $%02x  ; SETF %d\n",
              0x80 | (opcode->flag << 6), opcode->flag);
      break;
    case OP_BFEQ:
      fprintf(stdout, "    .byte $%02x  ; BFEQ %d, %d\n",
              0x80 | (opcode->flag << 6) | (0x3f & opcode->delta),
              opcode->flag, opcode->delta);
      break;
    case OP_PLAY: {
      int part_index = song->part_index_for_letter[opcode->part - 'A'];
      fprintf(stdout, "    .byte $%02x  ; PLAY %d (%c)\n", 0x40 | part_index,
              part_index, opcode->part);
    } break;
  }
}

static void write_part(const sng_song_t *song, const sng_part_t *part) {
  fprintf(stdout, "    D_STRUCT sPart  ; Part %c\n", part->letter);
  for (sng_channel_t c = 0; c < NUM_CHANNELS; ++c) {
    const sng_chain_t *chain = &part->chains[c];
    fprintf(stdout, "    d_addr Chain%c_u8_arr_ptr, ", channel_name(c));
    if (chain->alias_song_id != NULL) {
      assert(chain->num_phrases == 0);
      fprintf(stdout, "%s_%s_Chain%c%c_u8_arr\n", parser.prefix,
              chain->alias_song_id, chain->alias_part_name,
              channel_name(chain->alias_channel));
    } else if (chain->num_phrases == 0) {
      fprintf(stdout, "Data_EmptyChain_u8_arr\n");
    } else {
      fprintf(stdout, "%s_%s_Chain%c%c_u8_arr\n", parser.prefix,
              song->id, part->letter, channel_name(c));
    }
  }
  fprintf(stdout, "    D_END\n");
}

static void write_song(const sng_song_t *song) {
  fprintf(stdout, "\n.EXPORT %s_%s_sMusic\n", parser.prefix, song->id);
  fprintf(stdout, ".PROC %s_%s_sMusic\n", parser.prefix, song->id);
  fprintf(stdout,
          "    D_STRUCT sMusic\n"
          "    d_addr Opcodes_bMusic_arr_ptr, _Opcodes_bMusic_arr\n"
          "    d_addr Parts_sPart_arr_ptr, _Parts_sPart_arr\n");
  fprintf(stdout,
          "    d_addr Phrases_sPhrase_ptr_arr_ptr, %s_%s_sPhrase_ptr_arr\n",
          parser.prefix, parser.songs[0].id);
  fprintf(stdout,
          "    D_END\n"
          "_Opcodes_bMusic_arr:\n");
  for (int o = 0; o < song->num_opcodes; ++o) {
    write_opcode(song, &song->opcodes[o]);
  }
  fprintf(stdout, "_Parts_sPart_arr:\n");
  for (int p = 0; p < song->num_parts; ++p) {
    write_part(song, &song->parts[p]);
  }
  fprintf(stdout, ".ENDPROC\n");
}

static void write_chain(const sng_song_t *song, const sng_part_t *part,
                        sng_channel_t channel, const sng_chain_t *chain) {
  fprintf(stdout, "\n.PROC %s_%s_Chain%c%c_u8_arr\n",
          parser.prefix, song->id, part->letter, channel_name(channel));
  int i = 0;
  for (; i < chain->num_phrases; ++i) {
    int phrase_index = chain->phrase_indices[i];
    if (i % 14 == 0) {
      if (i != 0) fprintf(stdout, "\n");
      fprintf(stdout, "    .byte $%02x", phrase_index);
    } else fprintf(stdout, ", $%02x", phrase_index);
  }
  if (i % 14 == 0) fprintf(stdout, "\n    .byte $ff\n");
  else fprintf(stdout, ", $ff\n");
  fprintf(stdout, ".ENDPROC\n");
}

static void write_chains(void) {
  for (int s = 0; s < parser.num_songs; ++s) {
    const sng_song_t *song = &parser.songs[s];
    for (int p = 0; p < song->num_parts; ++p) {
      const sng_part_t *part = &song->parts[p];
      for (sng_channel_t c = 0; c < NUM_CHANNELS; ++c) {
        const sng_chain_t *chain = &part->chains[c];
        if (chain->num_phrases != 0) {
          assert(chain->alias_part_name == '\0');
          write_chain(song, part, c, chain);
        }
      }
    }
  }
}

static void write_phrase_name(const sng_phrase_t *phrase) {
  if (phrase->name != 0) {
    fprintf(stdout, "  ; [%c%c]", phrase->name >> 8, phrase->name & 0xff);
  }
  fprintf(stdout, "\n");
}

static void write_phrases(void) {
  fprintf(stdout, "\n.PROC %s_%s_sPhrase_ptr_arr\n",
          parser.prefix, parser.songs[0].id);
  for (int p = 0; p < parser.num_phrases; ++p) {
    fprintf(stdout, "    .addr _Phrase%02X_sPhrase", p);
    write_phrase_name(&parser.phrases[p]);
  }
  for (int p = 0; p < parser.num_phrases; ++p) {
    const sng_phrase_t *phrase = &parser.phrases[p];
    fprintf(stdout, "_Phrase%02X_sPhrase:", p);
    write_phrase_name(phrase);
    write_notes(phrase);
  }
  fprintf(stdout, ".ENDPROC\n");
}

static void write_samples(void) {
  int num_samples = 0;
  for (int s = 0; s < NUM_LETTERS; ++s) {
    sng_sample_t *sample = &parser.samples[s];
    if (sample->id != NULL) {
      fprintf(stdout, ".IMPORT %s\n", sample->id);
      ++num_samples;
    }
  }
  if (num_samples == 0) return;
  write_separator();
  fprintf(stdout, "\n");
  for (int s = 0; s < NUM_LETTERS; ++s) {
    sng_sample_t *sample = &parser.samples[s];
    if (sample->id != NULL) {
      fprintf(stdout, ".ASSERT %s >= $c000, error\n", sample->id);
      fprintf(stdout, ".ASSERT %s .mod $40 = 0, error\n", sample->id);
    }
  }
}

static void write_output(void) {
  fprintf(stdout,
          ";;; This file was generated by sng2asm.\n\n"
          ".INCLUDE \"../../../src/inst.inc\"\n"
          ".INCLUDE \"../../../src/macros.inc\"\n"
          ".INCLUDE \"../../../src/music.inc\"\n\n"
          ".IMPORT Data_EmptyChain_u8_arr\n");
  write_samples();
  write_separator();
  if (parser.num_songs == 0) return;
  fprintf(stdout, "\n.SEGMENT \"%s\"\n", parser.segment);
  for (int s = 0; s < parser.num_songs; ++s) {
    write_song(&parser.songs[s]);
  }
  write_chains();
  write_phrases();
  write_separator();
}

/*===========================================================================*/

int main(int argc, char **argv) {
  parse_input();
  write_output();
  return EXIT_SUCCESS;
}

/*===========================================================================*/
