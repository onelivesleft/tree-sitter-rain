/**
 * @file A tree-sitter grammar for 'rain.
 *
 * Statements end at a line's end (the external scanner's _newline, which
 * it gives only where a statement can end: inside brackets, or after an
 * operator still wanting its operand, a line goes on), or at a ';'. Types
 * are expressions, as rain's are ([3] i64, ^T, Holder(f32), struct {...}),
 * so a declaration's type is any expression. Raw strings (#"..."#,
 * ##"..."##) and here-strings (#"END ... END"#) are the scanner's, as their
 * ends depend on how they began; «...» interpolates in every string.
 */

const PREC = {
  or: 1,
  and: 2,
  compare: 3,
  add: 4,
  multiply: 5,
  cast: 7,
  unary: 8,
  postfix: 9,
};

const sep = (rule, by) => optional(seq(rule, repeat(seq(by, rule)), optional(by)));
const sep1 = (rule, by) => seq(rule, repeat(seq(by, rule)), optional(by));

module.exports = grammar({
  name: 'rain',

  externals: $ => [
    $._newline,
    $._raw_string_start,
    $.raw_string_content,
    $._raw_string_end,
    $.here_string_start,
    $.here_string_content,
    $._here_string_end,
    $.block_comment,
    $._program_keyword,
    $._module_keyword,
    $._shader_keyword,
    $.string_content,
    $._error_sentinel,
  ],

  extras: $ => [/[ \t\r\n\f\uFEFF]/, $.comment, $.block_comment],

  word: $ => $.identifier,

  supertypes: $ => [$._statement, $._expression],

  conflicts: $ => [
    [$._names, $._primary],
    [$.procedure],
    [$._primary, $.variadic],
    [$._primary, $.qualified_name],
    [$._names, $.label],
  ],

  rules: {
    source_file: $ => repeat(choice($._statement, $._terminator)),

    _terminator: $ => choice($._newline, ';'),

    comment: _ => token(seq('//', /[^\n]*/)),

    //- statements

    _statement: $ => choice(
      $.constant_declaration,
      $.variable_declaration,
      $.assignment,
      $.expression_statement,
      $.if_statement,
      $.while_statement,
      $.loop_statement,
      $.for_statement,
      $.return_statement,
      $.break_statement,
      $.continue_statement,
      $.fail_statement,
      $.defer_statement,
      $.yield_statement,
      $.with_statement,
      $.compile_if,
      $.block,
      $.arena_block,
      $.preset,
    ),

    block: $ => seq('{', repeat(choice($._statement, $._terminator)), '}'),

    // `scratch { ... }: what the block makes, in that arena.
    arena_block: $ => seq($.arena, $.block),
    arena: $ => seq('`', field('name', $.identifier)),

    _names: $ => sep1(seq(optional('*'), choice($.identifier, $.operator_name, $.qualified_name)), ','),

    // operator+, operator==, operator«», operator[], operator?: an operator's procedure.
    operator_name: _ => token(seq('operator', choice(
      '+', '-', '*', '/', '%', '==', '!=', '<', '<=', '>', '>=', '&', '|', '~', '<<', '>>', '!',
      '«»', '[]', '?', '=', '%%', '++', '--', '<<<', '>>>',
    ))),

    // name :: value, and name : type : value.
    constant_declaration: $ => prec.right(seq(
      field('name', $._names),
      choice('::', seq(':', field('type', $._expression), ':')),
      optional($.global),
      field('value', $._value),
    )),

    // #global: a name written bare by the modules that import it.
    global: _ => '#global',

    // name := value, *name := value, name: type (= value), name: type in arena;
    // a field of a struct too, with its directives and notes.
    variable_declaration: $ => prec.right(seq(
      field('name', $._names),
      choice(
        seq(':=', field('value', $._value)),
        seq(':', field('type', $._expression), optional(seq('=', field('value', $._value)))),
      ),
      repeat($.directive),
      optional($.notes),
    )),

    assignment: $ => prec.right(seq(
      field('left', $._expression),
      field('operator', choice('=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '~=', '<<=', '>>=', '<<<=', '>>>=', '·=', '%%=', '++=', '--=')),
      field('right', $._value),
    )),

    expression_statement: $ => prec.right(seq($._expression, repeat($.directive))),

    // What a declaration, an assignment or a return can be given: an
    // expression, or an if or a block whose way through gives the value.
    _value: $ => choice($._expression, $.if_statement, $.block),

    // if c { }, if c then s, if c (a line's end) s; or a switch, if x is {
    // case ...: }, whose cases are its body; then else.
    if_statement: $ => prec.right(seq(
      'if',
      choice(
        seq(
          field('condition', $._condition),
          choice(
            field('consequence', $.block),
            seq(choice('then', $._newline), field('consequence', choice($.block, $._then))),
          ),
        ),
        field('condition', $.switch),
      ),
      optional(seq('else', field('alternative', choice($.if_statement, $.block, $._then)))),
    )),

    switch: $ => prec.right(seq(
      choice(
        seq(field('name', $._names), ':=', field('value', $._expression)),
        field('value', $._expression),
      ),
      'is',
      $.case_block,
    )),

    _then: $ => choice(
      $._expression,
      $.return_statement,
      $.break_statement,
      $.continue_statement,
      $.fail_statement,
      $.assignment,
      $.variable_declaration,
      $.yield_statement,
    ),

    // a condition, or a call's results bound (if x := f()), then what fails
    // (is name, is not name, is { case ... }).
    _condition: $ => choice(
      $._expression,
      $.binding,
      $.fail_test,
    ),

    // x := f(), and a pool's slot, *c: in chunks[h] (or c: T in ...).
    binding: $ => prec.right(seq(
      field('name', $._names),
      choice(
        seq(':=', field('value', $._expression)),
        seq(':', optional(field('type', $._expression)), 'in', field('value', $._expression)),
      ),
      optional($._is),
    )),

    fail_test: $ => prec.right(seq(field('value', $._expression), $._is)),

    _is: $ => seq('is', optional('not'), field('state', $._expression)),

    case_block: $ => seq('{', repeat(choice($.case_clause, $._terminator)), '}'),

    case_clause: $ => prec.right(seq(
      'case',
      optional(field('value', sep1($._expression, ','))),
      ':',
      repeat(choice($._statement, $._terminator)),
    )),

    while_statement: $ => seq('while', optional($.label), field('condition', $._condition), field('body', $._body)),

    loop_statement: $ => seq('loop', optional($.label), field('body', $.block)),

    // loop outer: { ... break outer ... }
    label: $ => seq(field('name', $.identifier), ':'),

    // a loop's body: a block, or a statement on the next line.
    _body: $ => choice($.block, seq($._newline, $._then)),

    for_statement: $ => seq(
      optional('#unroll'),
      'for',
      optional('<'),
      optional(seq(field('name', $._names), ':')),
      field('over', $._expression),
      field('body', $._body),
    ),

    return_statement: $ => prec.right(seq('return', optional(sep1($._value, ',')))),
    break_statement: $ => prec.right(seq('break', optional(field('label', $.identifier)))),
    continue_statement: $ => prec.right(seq('continue', optional(field('label', $.identifier)))),

    // fail: name, or fail: name = detail.
    fail_statement: $ => prec.right(seq(
      'fail', ':', field('state', $.identifier), optional(seq('=', field('detail', $._expression))),
    )),

    defer_statement: $ => seq('defer', choice($.block, $._then)),

    yield_statement: $ => prec.right(seq('yield', sep1($._expression, ','), optional(seq('#remove', $.block)))),

    // #with x := f(), or #with scratch.rewind()
    with_statement: $ => seq('#with', choice($.variable_declaration, $._expression)),

    compile_if: $ => prec.right(seq(
      '#if',
      field('condition', $._expression),
      field('consequence', $.block),
      repeat(seq('#elseif', field('condition', $._expression), field('consequence', $.block))),
      optional(seq('#else', field('alternative', $.block))),
    )),

    // A program's preset: release { mode: .RELEASE }
    preset: $ => prec(1, seq(field('name', $.identifier), $.block)),

    //- expressions

    _expression: $ => choice(
      $.binary_expression,
      $.unary_expression,
      $.cast_expression,
      $.arena_expression,
      $.inline_expression,
      $._primary,
    ),

    binary_expression: $ => {
      const table = [
        [PREC.or, choice('or', '||')],
        [PREC.and, choice('and', '&&')],
        [PREC.compare, choice('==', '!=', '<', '<=', '>', '>=', 'in')],
        [PREC.add, choice('+', '-', '++', '--', '|', '~')],
        [PREC.multiply, choice('*', '/', '%', '%%', '<<', '>>', '<<<', '>>>', '&', '·')],
      ];
      return choice(...table.map(([p, op]) => prec.left(p, seq(
        field('left', $._expression),
        field('operator', op),
        field('right', $._expression),
      ))));
    },

    // -x !x ~x ^x (an address, or a pointer type), *T (a parameter's type),
    // $T and $$text (known while compiling), ..x, and the array types.
    unary_expression: $ => prec(PREC.unary, choice(
      seq(field('operator', choice('-', '!', '~', '^', '*', '$', '$$', '..')), field('operand', $._expression)),
      seq($.array_type_prefix, field('element', $._expression)),
    )),

    array_type_prefix: $ => seq('[', optional(choice($._expression, '..')), ']'),

    // T'x and T''x (unchecked).
    cast_expression: $ => prec.right(PREC.cast, seq(
      field('type', $._expression),
      field('operator', choice("'", "''")),
      field('value', $._expression),
    )),

    arena_expression: $ => prec(PREC.unary, seq($.arena, $._expression)),

    // #inline f(x): the call's callee's body in its place
    inline_expression: $ => prec(PREC.unary, seq('#inline', field('call', $._expression))),

    _primary: $ => choice(
      $.identifier,
      $.number,
      $.string,
      $.raw_string,
      $.here_string,
      $.true,
      $.false,
      $.null,
      $.enum_value,
      $.literal,
      $.parenthesized_expression,
      $.call_expression,
      $.index_expression,
      $.member_expression,
      $.dereference_expression,
      $.procedure,
      $.struct_type,
      $.union_type,
      $.enum_type,
      $.module_type,
      $.program_type,
      $.shader_type,
      $.directive,
      $.import,
      $.count,
    ),

    parenthesized_expression: $ => seq('(', $._value, ')'),

    call_expression: $ => prec(PREC.postfix, seq(field('function', $._primary), field('arguments', $.arguments))),

    // (and a procedure type's results, Thread(-> i64))
    arguments: $ => seq('(', sep(choice($._expression, $.named_argument, $.spread), ','), optional(seq('->', sep($.result, ','))), ')'),

    // an array's elements as arguments: f(items..)
    spread: $ => seq($._expression, '..'),

    named_argument: $ => seq(field('name', $.identifier), ':', field('value', choice($._expression, $.spread))),

    index_expression: $ => prec(PREC.postfix, seq(
      field('object', $._primary),
      '[',
      choice(field('index', $._expression), $.slice),
      ']',
    )),

    slice: $ => seq(optional(field('from', $._expression)), ':', optional(field('to', $._expression))),

    member_expression: $ => prec(PREC.postfix, seq(
      field('object', $._primary),
      '.',
      optional('$'),
      field('member', $.identifier),
    )),

    dereference_expression: $ => prec(PREC.postfix, seq(field('pointer', $._primary), '^')),

    // .NAME, an enum's value; .name(value), a union's.
    enum_value: $ => prec(PREC.postfix + 1, seq('.', field('name', $.identifier))),

    // ⟨...⟩, or T⟨...⟩
    literal: $ => prec(PREC.postfix, seq(
      optional(field('type', $._primary)),
      '⟨',
      sep(choice($._expression, $.named_argument), ','),
      '⟩',
    )),

    // # inside an index: the count of what's indexed.
    count: _ => '#',

    //- procedures and types

    procedure: $ => prec.right(seq(
      optional(field('kind', choice('#for', '#with', '#signature'))),
      field('parameters', $.parameters),
      optional(field('fail_states', $.fail_states)),
      repeat(choice($.directive, $.foreign, $.c_directive)),
      optional(field('body', $.block)),
    )),

    parameters: $ => seq(
      '(',
      sep(choice($.parameter, $.variadic), ','),
      optional(seq('->', sep($.result, ','))),
      ')',
    ),

    parameter: $ => prec.right(seq(
      optional(choice('$', '$$')),
      field('name', $.identifier),
      choice(
        seq(':', field('type', $._expression), optional(seq('=', field('default', $._expression)))),
        seq(':=', field('default', $._expression)),
      ),
      repeat($.directive),
    )),

    variadic: $ => prec.right(seq(
      '..',
      optional(seq(field('name', $.identifier), optional(seq(':', field('type', $._expression))))),
      repeat($.directive),
    )),

    result: $ => choice(
      seq(field('name', $.identifier), ':', field('type', $._expression)),
      field('type', $._expression),
    ),

    fail_states: $ => seq('[', sep($.fail_state, ','), ']'),

    fail_state: $ => seq(field('name', $.identifier), optional(seq(':', field('type', $._expression)))),

    struct_type: $ => prec.right(seq(
      'struct',
      optional(field('parameters', $.parameters)),
      optional(field('bases', sep1(choice($.identifier, $.qualified_name), ','))),
      repeat(choice($.directive, $.c_directive)),
      field('body', $.block),
    )),

    qualified_name: $ => seq(field('module', $.identifier), '.', field('name', $.identifier)),

    union_type: $ => prec.right(seq(
      'union',
      optional(field('parameters', $.parameters)),
      repeat($.directive),
      field('body', $.block),
    )),

    enum_type: $ => prec.right(seq(
      'enum',
      optional('flags'),
      optional(field('backing', $.identifier)),
      repeat($.directive),
      field('body', $.block),
    )),

    module_type: $ => prec.right(seq(
      optional('#libc'),
      alias($._module_keyword, 'module'),
      optional(field('parameters', $.parameters)),
      field('body', $.block),
    )),

    program_type: $ => seq(optional('#libc'), alias($._program_keyword, 'program'), field('body', $.block)),

    shader_type: $ => seq(alias($._shader_keyword, 'shader'), field('body', $.block)),

    // #import Name, #import Name(PARAMETER: value), as a statement or a
    // named import's value.
    import: $ => prec.right(seq('#import', field('module', $._expression))),

    // #name, with arguments (#cpu(.AVX2), #c(pack: 1), #assert(...)) or a
    // string or name after it (#data "file", #foreign libc).
    directive: $ => prec.right(seq(
      field('name', $.directive_name),
      optional(choice(
        field('arguments', alias($._directive_arguments, $.arguments)),
        field('value', choice($.string, $.raw_string, $.identifier)),
      )),
    )),

    // #c, and #c(pack: N) or #c (pack: N): C's layout or calls.
    c_directive: $ => prec.right(seq('#c', optional(alias($._spaced_arguments, $.arguments)))),

    _spaced_arguments: $ => seq('(', sep(choice($._expression, $.named_argument), ','), ')'),

    // #foreign libc: a procedure from a library, named.
    foreign: $ => prec.right(seq('#foreign', optional(field('library', $.identifier)))),

    _directive_arguments: $ => seq(token.immediate('('), sep(choice($._expression, $.named_argument), ','), ')'),

    directive_name: _ => /#[A-Za-z_][A-Za-z0-9_]*/,

    // ⟦json: "full_name", skip⟧: notes for code to read.
    notes: $ => seq('⟦', sep(choice($.identifier, $.named_argument), ','), '⟧'),

    //- strings

    string: $ => seq(
      '"',
      repeat(choice($.string_content, $.escape_sequence, $.interpolation)),
      token.immediate('"'),
    ),

    escape_sequence: _ => token.immediate(choice(
      /\\x[0-9A-Fa-f]{2}/,
      /\\[^x]/,
      '««',
    )),

    // «value» or «value, ⟨options⟩»
    interpolation: $ => seq('«', field('value', $._expression), optional(seq(',', field('options', $._expression))), '»'),

    raw_string: $ => seq($._raw_string_start, repeat(choice($.raw_string_content, $.interpolation)), $._raw_string_end),

    here_string: $ => seq($.here_string_start, repeat(choice($.here_string_content, $.interpolation)), $._here_string_end),

    //- the rest

    number: _ => token(choice(
      /0x[0-9A-Fa-f_]+/,
      /0b[01_]+/,
      /0o[0-7_]+/,
      /[0-9][0-9_]*\.[0-9][0-9_]*([eE][+-]?[0-9]+)?/,
      /[0-9][0-9_]*[eE][+-]?[0-9]+/,
      /[0-9][0-9_]*/,
    )),

    true: _ => 'true',
    false: _ => 'false',
    null: _ => 'null',

    identifier: _ => /[A-Za-z_][A-Za-z0-9_]*/,
  },
});
