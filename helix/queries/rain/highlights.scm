; 'rain's highlights, in Helix's capture names. The first pattern that
; matches wins, so the particular ones come first.

;- punctuation and operators

(interpolation ["«" "»"] @punctuation.special)
["(" ")" "[" "]" "{" "}" "⟨" "⟩" "⟦" "⟧"] @punctuation.bracket
["," ";" ":" "."] @punctuation.delimiter

[
  "=" "+=" "-=" "*=" "/=" "%=" "&=" "|=" "~=" "<<=" ">>=" "<<<=" ">>>=" "·=" "%%=" "++=" "--="
  "==" "!=" "<" "<=" ">" ">=" "+" "-" "++" "--" "|" "~" "*" "/" "%" "%%" "<<" ">>" "<<<" ">>>" "&" "·"
  "!" "^" "$" "$$" ".." "->" "'" "''" ":=" "::" "||" "&&"
] @operator

;- comments, strings, numbers

[(comment) (block_comment)] @comment
(escape_sequence) @constant.character.escape
(here_string_start) @string.special
[(string) (raw_string) (here_string)] @string

((number) @constant.numeric.float
  (#match? @constant.numeric.float "[.eE]"))
(number) @constant.numeric.integer
[(true) (false)] @constant.builtin.boolean
(null) @constant.builtin

;- keywords and directives

["if" "else" "then" "case" "is" "not"] @keyword.control.conditional
["while" "for" "loop"] @keyword.control.repeat
["return" "yield" "fail"] @keyword.control.return
["break" "continue" "defer"] @keyword.control
["and" "or" "in"] @keyword.operator
["struct" "union" "enum" "flags"] @keyword.storage.type
["module" "program" "shader" "interface" "implements"] @keyword.storage.modifier

[
  "#if" "#elseif" "#else" "#unroll" "#with" "#inline" "#for" "#signature" "#import"
  "#remove" "#libc" "#foreign" "#c"
] @keyword.directive
(directive_name) @keyword.directive
(global) @keyword.directive
(count) @variable.builtin

(arena name: (identifier) @attribute)
"`" @attribute
(notes) @attribute

;- declarations

(constant_declaration name: (identifier) @function value: (procedure))
(constant_declaration name: (operator_name) @function)
(constant_declaration name: (identifier) @type value: [(struct_type) (union_type) (enum_type)])
(constant_declaration name: (identifier) @namespace value: [(module_type) (program_type) (import)])
(constant_declaration
  name: (identifier) @constant
  value: [(number) (string) (literal) (raw_string) (here_string) (directive)])

(parameter name: (identifier) @variable.parameter)
(variadic name: (identifier) @variable.parameter)
(result name: (identifier) @variable.parameter)
(fail_state name: (identifier) @constant)
(fail_statement state: (identifier) @constant)

(struct_type body: (block (variable_declaration name: (identifier) @variable.other.member)))
(union_type body: (block (variable_declaration name: (identifier) @variable.other.member)))
(union_type body: (block (expression_statement (identifier) @type.enum.variant)))
(enum_type body: (block (expression_statement (identifier) @type.enum.variant)))
(enum_type body: (block (constant_declaration name: (identifier) @type.enum.variant)))

(label name: (identifier) @label)
(break_statement label: (identifier) @label)
(continue_statement label: (identifier) @label)
(preset name: (identifier) @label)

;- uses

(call_expression function: (member_expression member: (identifier) @function.method))
(call_expression function: (identifier) @function)
(member_expression member: (identifier) @variable.other.member)
(named_argument name: (identifier) @variable.other.member)
(enum_value name: (identifier) @type.enum.variant)
(qualified_name module: (identifier) @namespace)
(import module: (identifier) @namespace)
(import module: (call_expression function: (identifier) @namespace))

((expression_statement (identifier) @keyword)
  (#any-of? @keyword "unreachable" "remove"))

((identifier) @variable.builtin
  (#any-of? @variable.builtin "scratch" "global"))

((identifier) @type.builtin
  (#any-of? @type.builtin
    "i8" "i16" "i32" "i64" "i128" "u8" "u16" "u32" "u64" "u128"
    "f32" "f64" "bool" "string" "void" "Type"))

((identifier) @constant
  (#match? @constant "^[A-Z][A-Z0-9_]*$"))
((identifier) @type
  (#match? @type "^[A-Z][A-Za-z0-9_]*[a-z][A-Za-z0-9_]*$"))

(identifier) @variable
