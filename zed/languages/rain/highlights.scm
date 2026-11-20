; 'rain's highlights, in Zed's capture names. Later patterns win, so the
; general ones come first.

(identifier) @variable

((identifier) @type
  (#match? @type "^[A-Z][A-Za-z0-9_]*[a-z][A-Za-z0-9_]*$"))
((identifier) @constant
  (#match? @constant "^[A-Z][A-Z0-9_]*$"))

((identifier) @type.builtin
  (#any-of? @type.builtin
    "i8" "i16" "i32" "i64" "i128" "u8" "u16" "u32" "u64" "u128"
    "f32" "f64" "bool" "string" "void" "Type"))

((identifier) @variable.special
  (#any-of? @variable.special "scratch" "global"))

((expression_statement (identifier) @keyword)
  (#any-of? @keyword "unreachable" "remove"))

(constant_declaration name: (identifier) @function value: (procedure))
(constant_declaration name: (operator_name) @function)
(constant_declaration name: (identifier) @type value: [(struct_type) (union_type) (enum_type)])
(constant_declaration name: (identifier) @type value: [(module_type) (program_type) (import)])
(constant_declaration
  name: (identifier) @constant
  value: [(number) (string) (literal) (raw_string) (here_string) (directive)])

(parameter name: (identifier) @variable.parameter)
(variadic name: (identifier) @variable.parameter)
(result name: (identifier) @variable.parameter)
(fail_state name: (identifier) @constant)
(fail_statement state: (identifier) @constant)

(struct_type body: (block (variable_declaration name: (identifier) @property)))
(union_type body: (block (variable_declaration name: (identifier) @property)))
(union_type body: (block (expression_statement (identifier) @variant)))
(enum_type body: (block (expression_statement (identifier) @variant)))
(enum_type body: (block (constant_declaration name: (identifier) @variant)))

(label name: (identifier) @label)
(break_statement label: (identifier) @label)
(continue_statement label: (identifier) @label)
(preset name: (identifier) @label)

(call_expression function: (identifier) @function)
(call_expression function: (member_expression member: (identifier) @function.method))

(member_expression member: (identifier) @property)
(named_argument name: (identifier) @property)
(enum_value name: (identifier) @variant)
(qualified_name module: (identifier) @type)
(import module: (identifier) @type)
(import module: (call_expression function: (identifier) @type))

(arena name: (identifier) @attribute)
"`" @attribute
(notes) @attribute

(directive_name) @preproc
[
  "#if" "#elseif" "#else" "#unroll" "#with" "#inline" "#for" "#signature" "#import"
  "#remove" "#libc" "#foreign" "#c"
] @preproc
(global) @preproc
(count) @variable.special

[
  "if" "else" "then" "case" "is" "not" "while" "for" "loop" "return" "yield"
  "fail" "break" "continue" "defer" "and" "or" "in" "struct" "union" "enum"
  "flags" "module" "program" "shader"
] @keyword

[(true) (false)] @boolean
(null) @constant

(number) @number

[(string) (raw_string) (here_string)] @string
(here_string_start) @string.special
(escape_sequence) @string.escape
(interpolation ["«" "»"] @punctuation.special)

[(comment) (block_comment)] @comment

[
  "=" "+=" "-=" "*=" "/=" "%=" "&=" "|=" "~=" "<<=" ">>=" "<<<=" ">>>=" "·=" "%%=" "++=" "--="
  "==" "!=" "<" "<=" ">" ">=" "+" "-" "++" "--" "|" "~" "*" "/" "%" "%%" "<<" ">>" "<<<" ">>>" "&" "·"
  "!" "^" "$" "$$" ".." "->" "'" "''" ":=" "::" "||" "&&"
] @operator

["(" ")" "[" "]" "{" "}" "⟨" "⟩" "⟦" "⟧"] @punctuation.bracket
["," ";" ":" "."] @punctuation.delimiter
