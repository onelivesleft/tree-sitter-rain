// The external scanner for 'rain's grammar: what a context-free lexer can't
// say.
//
// - _newline: a line's end, given only where a statement can end there (so
//   inside brackets, or after an operator that wants its operand, the line
//   goes on, as rain's parser has it), and not before an else (or #else,
//   #elseif) that goes on the statement.
// - raw strings, #"..."# and ##"..."##: they end at a " with as many #s as
//   they began with, and hold no escapes; «...» interpolates in them.
// - here-strings, #"END at a line's end, the lines, then a line starting
//   END"#: they end at their name.
// - block comments, /* ... */, which nest.
//
// Strings open inside an interpolation inside a string are a stack, kept
// in the scanner's state.

#include "tree_sitter/parser.h"

#include <stdlib.h>
#include <string.h>

enum TokenType {
  NEWLINE,
  RAW_STRING_START,
  RAW_STRING_CONTENT,
  RAW_STRING_END,
  HERE_STRING_START,
  HERE_STRING_CONTENT,
  HERE_STRING_END,
  BLOCK_COMMENT,
  PROGRAM_KEYWORD,
  MODULE_KEYWORD,
  SHADER_KEYWORD,
  INTERFACE_KEYWORD,
  STRING_CONTENT,
  ERROR_SENTINEL,
};

#define MAX_OPEN 16
#define MAX_NAME 48

typedef struct {
  unsigned char kind;              // 0 a raw string, 1 a here-string
  unsigned char hashes;            // a raw string's #s
  unsigned char name_length;       // a here-string's name
  char name[MAX_NAME];
} Open;

typedef struct {
  unsigned count;
  Open open[MAX_OPEN];
} Scanner;

void *tree_sitter_rain_external_scanner_create(void) {
  Scanner *s = (Scanner *)calloc(1, sizeof(Scanner));
  return s;
}

void tree_sitter_rain_external_scanner_destroy(void *payload) { free(payload); }

unsigned tree_sitter_rain_external_scanner_serialize(void *payload, char *buffer) {
  Scanner *s = (Scanner *)payload;
  unsigned size = sizeof(unsigned) + s->count * sizeof(Open);
  if (size > TREE_SITTER_SERIALIZATION_BUFFER_SIZE) { return 0; }
  memcpy(buffer, s, size);
  return size;
}

void tree_sitter_rain_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {
  Scanner *s = (Scanner *)payload;
  s->count = 0;
  if (length >= sizeof(unsigned)) {
    memcpy(s, buffer, length);
    if (s->count > MAX_OPEN) { s->count = 0; }
  }
}

static void advance(TSLexer *lexer) { lexer->advance(lexer, false); }
static void skip(TSLexer *lexer) { lexer->advance(lexer, true); }

static bool is_name_start(int32_t c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'; }
static bool is_name(int32_t c) { return is_name_start(c) || (c >= '0' && c <= '9'); }

// «, as UTF-8 is read: the code point.
#define GUILLEMET_OPEN 0xAB

// program, module and shader are names too (program := ..., module: Handle):
// each is the keyword only where its type begins, the word then a { (or a
// module's or a shader's parameters' ().
static bool scan_keyword(TSLexer *lexer, const char *word, bool parameters) {
  for (const char *c = word; *c; c++) {
    if (lexer->lookahead != *c) { return false; }
    advance(lexer);
  }
  if (is_name(lexer->lookahead)) { return false; }
  lexer->mark_end(lexer);
  while (lexer->lookahead == ' ' || lexer->lookahead == '\t') { advance(lexer); }
  if (lexer->lookahead == '{' || (parameters && lexer->lookahead == '(')) { return true; }
  // module implements Draw_Renderer.Renderer { ... } (a module's parameters
  // may come between, which the ( above takes)
  if (!parameters) { return false; }
  const char *implements = "implements";
  for (const char *c = implements; *c; c++) {
    if (lexer->lookahead != *c) { return false; }
    advance(lexer);
  }
  return !is_name(lexer->lookahead);
}

// After a line's end: does the next line go on with else, #else or #elseif?
static bool continues_with_else(TSLexer *lexer) {
  while (lexer->lookahead == ' ' || lexer->lookahead == '\t' || lexer->lookahead == '\r' || lexer->lookahead == '\n') { advance(lexer); }
  if (lexer->lookahead == '#') { advance(lexer); }
  const char *word = "else";
  for (const char *c = word; *c; c++) {
    if (lexer->lookahead != *c) { return false; }
    advance(lexer);
  }
  if (lexer->lookahead == 'i') {          // #elseif
    advance(lexer);
    if (lexer->lookahead != 'f') { return false; }
    advance(lexer);
  }
  return !is_name(lexer->lookahead);
}

// A string's start, at its first #: #"NAME at a line's end is a
// here-string's, else #"..., ##"... a raw string's.
static bool scan_string_start(Scanner *s, TSLexer *lexer, const bool *valid) {
  unsigned hashes = 0;
  while (lexer->lookahead == '#') { advance(lexer); hashes++; }
  if (lexer->lookahead != '"' || hashes == 0 || s->count >= MAX_OPEN) { return false; }
  advance(lexer);
  lexer->mark_end(lexer);
  Open open = {0};
  open.hashes = (unsigned char)hashes;
  // A here-string's name, then nothing but the line's end.
  if (hashes == 1 && valid[HERE_STRING_START] && is_name_start(lexer->lookahead)) {
    unsigned n = 0;
    while (is_name(lexer->lookahead) && n < MAX_NAME) {
      open.name[n++] = (char)lexer->lookahead;
      advance(lexer);
    }
    while (lexer->lookahead == ' ' || lexer->lookahead == '\t' || lexer->lookahead == '\r') { advance(lexer); }
    if (lexer->lookahead == '\n') {
      open.kind = 1;
      open.name_length = (unsigned char)n;
      lexer->mark_end(lexer);
      s->open[s->count++] = open;
      lexer->result_symbol = HERE_STRING_START;
      return true;
    }
  }
  if (!valid[RAW_STRING_START]) { return false; }
  open.kind = 0;
  s->open[s->count++] = open;
  lexer->result_symbol = RAW_STRING_START;
  return true;
}

// A raw string's text, to an interpolation or its end.
static bool scan_raw_content(Scanner *s, TSLexer *lexer, const bool *valid) {
  Open *open = &s->open[s->count - 1];
  bool any = false;
  for (;;) {
    if (lexer->eof(lexer)) { lexer->mark_end(lexer); lexer->result_symbol = RAW_STRING_CONTENT; return any; }
    int32_t c = lexer->lookahead;
    if (c == GUILLEMET_OPEN) {
      lexer->mark_end(lexer);
      advance(lexer);
      if (lexer->lookahead == GUILLEMET_OPEN) { advance(lexer); any = true; continue; }   // «« is a «
      lexer->result_symbol = RAW_STRING_CONTENT;
      return any;
    }
    if (c == '"') {
      lexer->mark_end(lexer);
      advance(lexer);
      unsigned hashes = 0;
      while (lexer->lookahead == '#' && hashes < open->hashes) { advance(lexer); hashes++; }
      if (hashes == open->hashes) {
        if (any) { lexer->result_symbol = RAW_STRING_CONTENT; return true; }
        if (!valid[RAW_STRING_END]) { return false; }
        lexer->mark_end(lexer);
        s->count--;
        lexer->result_symbol = RAW_STRING_END;
        return true;
      }
      any = true;
      continue;
    }
    advance(lexer);
    any = true;
  }
}

// Is a here-string's end here (a line's start): its name and "#?
static bool at_here_end(Open *open, TSLexer *lexer) {
  while (lexer->lookahead == ' ' || lexer->lookahead == '\t') { advance(lexer); }
  for (unsigned i = 0; i < open->name_length; i++) {
    if (lexer->lookahead != open->name[i]) { return false; }
    advance(lexer);
  }
  if (lexer->lookahead != '"') { return false; }
  advance(lexer);
  if (lexer->lookahead != '#') { return false; }
  advance(lexer);
  return true;
}

// A here-string's text, line by line, to an interpolation or its end.
static bool scan_here_content(Scanner *s, TSLexer *lexer, const bool *valid) {
  Open *open = &s->open[s->count - 1];
  bool any = false;
  bool line_start = (lexer->get_column(lexer) == 0);
  for (;;) {
    if (lexer->eof(lexer)) { lexer->mark_end(lexer); lexer->result_symbol = HERE_STRING_CONTENT; return any; }
    if (line_start) {
      lexer->mark_end(lexer);
      if (at_here_end(open, lexer)) {
        if (any) { lexer->result_symbol = HERE_STRING_CONTENT; return true; }
        if (!valid[HERE_STRING_END]) { return false; }
        lexer->mark_end(lexer);
        s->count--;
        lexer->result_symbol = HERE_STRING_END;
        return true;
      }
      line_start = false;
      any = true;
      continue;
    }
    int32_t c = lexer->lookahead;
    if (c == GUILLEMET_OPEN) {
      lexer->mark_end(lexer);
      advance(lexer);
      if (lexer->lookahead == GUILLEMET_OPEN) { advance(lexer); any = true; continue; }
      lexer->result_symbol = HERE_STRING_CONTENT;
      return any;
    }
    advance(lexer);
    any = true;
    if (c == '\n') { line_start = true; }
  }
}

bool tree_sitter_rain_external_scanner_scan(void *payload, TSLexer *lexer, const bool *valid) {
  Scanner *s = (Scanner *)payload;
  // In error recovery every symbol is valid: give none of these then.
  if (valid[ERROR_SENTINEL]) { return false; }

  if (s->count > 0) {
    Open *open = &s->open[s->count - 1];
    if (open->kind == 0 && (valid[RAW_STRING_CONTENT] || valid[RAW_STRING_END])) { return scan_raw_content(s, lexer, valid); }
    if (open->kind == 1 && (valid[HERE_STRING_CONTENT] || valid[HERE_STRING_END])) { return scan_here_content(s, lexer, valid); }
  }

  // A string's text (here, so a // or /* in it is no comment), to an
  // escape, an interpolation, its end or the line's.
  if (valid[STRING_CONTENT]) {
    bool any = false;
    for (;;) {
      int32_t c = lexer->lookahead;
      if (lexer->eof(lexer) || c == '"' || c == '\\' || c == GUILLEMET_OPEN || c == '\n') { break; }
      advance(lexer);
      any = true;
    }
    if (any) {
      lexer->mark_end(lexer);
      lexer->result_symbol = STRING_CONTENT;
      return true;
    }
    return false;
  }

  // The line's end, where a statement can end.
  if (valid[NEWLINE]) {
    while (lexer->lookahead == ' ' || lexer->lookahead == '\t' || lexer->lookahead == '\r' || lexer->lookahead == '\f') { skip(lexer); }
    // (Not at the file's end, where it would be given again and again: the
    // last statement needs none.)
    if (lexer->lookahead == '\n') {
      advance(lexer);
      lexer->mark_end(lexer);
      if (continues_with_else(lexer)) { return false; }
      lexer->result_symbol = NEWLINE;
      return true;
    }
  } else {
    while (lexer->lookahead == ' ' || lexer->lookahead == '\t' || lexer->lookahead == '\r' || lexer->lookahead == '\n' || lexer->lookahead == '\f') { skip(lexer); }
  }

  if (lexer->lookahead == '/' && valid[BLOCK_COMMENT]) {
    advance(lexer);
    if (lexer->lookahead != '*') { return false; }
    advance(lexer);
    // (the first /* is counted: the comment is depth 1 from here)
    unsigned depth = 1;
    for (;;) {
      if (lexer->eof(lexer)) { lexer->mark_end(lexer); lexer->result_symbol = BLOCK_COMMENT; return true; }
      int32_t c = lexer->lookahead;
      advance(lexer);
      if (c == '/' && lexer->lookahead == '*') { advance(lexer); depth++; }
      else if (c == '*' && lexer->lookahead == '/') {
        advance(lexer);
        if (--depth == 0) { lexer->mark_end(lexer); lexer->result_symbol = BLOCK_COMMENT; return true; }
      }
    }
  }

  if (lexer->lookahead == 'p' && valid[PROGRAM_KEYWORD] && scan_keyword(lexer, "program", false)) {
    lexer->result_symbol = PROGRAM_KEYWORD;
    return true;
  }
  if (lexer->lookahead == 'm' && valid[MODULE_KEYWORD] && scan_keyword(lexer, "module", true)) {
    lexer->result_symbol = MODULE_KEYWORD;
    return true;
  }
  if (lexer->lookahead == 's' && valid[SHADER_KEYWORD] && scan_keyword(lexer, "shader", true)) {   // (shader(LIGHTS: i64 = 4) { ... } has parameters)
    lexer->result_symbol = SHADER_KEYWORD;
    return true;
  }
  if (lexer->lookahead == 'i' && valid[INTERFACE_KEYWORD] && scan_keyword(lexer, "interface", false)) {
    lexer->result_symbol = INTERFACE_KEYWORD;
    return true;
  }

  if (lexer->lookahead == '#' && (valid[RAW_STRING_START] || valid[HERE_STRING_START])) {
    return scan_string_start(s, lexer, valid);
  }
  return false;
}
