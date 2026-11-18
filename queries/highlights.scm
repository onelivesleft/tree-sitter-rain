; 'rain's highlights, in Neovim's capture names (nvim-treesitter's). Later
; patterns win, so the general ones come first.

(identifier) @variable

; Names in capitals: constants (LIMIT, MEOW_DEFAULT_SEED); capitalised: types (Money).
((identifier) @type
  (#match? @type "^[A-Z][A-Za-z0-9_]*[a-z][A-Za-z0-9_]*$"))
((identifier) @constant
  (#match? @constant "^[A-Z][A-Z0-9_]*$"))

((identifier) @type.builtin
  (#any-of? @type.builtin
    "i8" "i16" "i32" "i64" "i128" "u8" "u16" "u32" "u64" "u128"
    "f32" "f64" "bool" "string" "void" "Type"))

((identifier) @variable.builtin
  (#any-of? @variable.builtin "scratch" "global"))

; Statements that are words a program can use as names too.
((expression_statement (identifier) @keyword)
  (#any-of? @keyword "unreachable" "remove"))

;- declarations

(constant_declaration
  name: (identifier) @function
  value: (procedure))
(constant_declaration
  name: (operator_name) @function)
(constant_declaration
  name: (identifier) @type.definition
  value: [(struct_type) (union_type) (enum_type)])
(constant_declaration
  name: (identifier) @module
  value: [(module_type) (program_type) (import)])
(constant_declaration
  name: (identifier) @constant
  value: [(number) (string) (literal) (raw_string) (here_string) (directive)])

(parameter name: (identifier) @variable.parameter)
(variadic name: (identifier) @variable.parameter)
(result name: (identifier) @variable.parameter)
(fail_state name: (identifier) @constant)
(fail_statement state: (identifier) @constant)

(struct_type body: (block (variable_declaration name: (identifier) @variable.member)))
(union_type body: (block (variable_declaration name: (identifier) @variable.member)))
(union_type body: (block (expression_statement (identifier) @variable.member)))
(enum_type body: (block (expression_statement (identifier) @constant)))
(enum_type body: (block (constant_declaration name: (identifier) @constant)))

(label name: (identifier) @label)
(break_statement label: (identifier) @label)
(continue_statement label: (identifier) @label)
(preset name: (identifier) @label)

;- uses

(call_expression function: (identifier) @function.call)
(call_expression
  function: (member_expression member: (identifier) @function.method.call))
(call_expression
  function: (member_expression
    object: (identifier) @module
    member: (identifier) @function.call)
  (#match? @module "^[A-Z]"))

(member_expression member: (identifier) @variable.member)
(named_argument name: (identifier) @property)
(enum_value name: (identifier) @constant)
(qualified_name module: (identifier) @module)

(import module: (identifier) @module)
(import module: (call_expression function: (identifier) @module))

(arena name: (identifier) @attribute)
"`" @attribute

(notes) @attribute

;- directives

(directive_name) @keyword.directive
[
  "#if" "#elseif" "#else" "#unroll" "#with" "#for" "#signature" "#import"
  "#remove" "#libc" "#foreign" "#c"
] @keyword.directive
(global) @keyword.directive
(count) @variable.builtin

;- keywords

["if" "else" "then" "case" "is" "not"] @keyword.conditional
["while" "for" "loop"] @keyword.repeat
["return" "yield" "fail"] @keyword.return
["break" "continue" "defer"] @keyword
["and" "or" "in"] @keyword.operator
["struct" "union" "enum" "flags"] @keyword.type
["module" "program" "shader"] @keyword.modifier

[(true) (false)] @boolean
(null) @constant.builtin

;- literals

(number) @number
((number) @number.float
  (#match? @number.float "[.eE]"))

[(string) (raw_string) (here_string)] @string
(here_string_start) @string.special
(escape_sequence) @string.escape
(interpolation ["«" "»"] @punctuation.special)

[(comment) (block_comment)] @comment @spell

;- operators and punctuation

[
  "=" "+=" "-=" "*=" "/=" "%=" "&=" "|=" "~=" "<<=" ">>=" "<<<=" ">>>=" "·=" "%%=" "++=" "--="
  "==" "!=" "<" "<=" ">" ">=" "+" "-" "++" "--" "|" "~" "*" "/" "%" "%%" "<<" ">>" "<<<" ">>>" "&" "·"
  "!" "^" "$" "$$" ".." "->" "'" "''" ":=" "::" "||" "&&"
] @operator

["(" ")" "[" "]" "{" "}" "⟨" "⟩" "⟦" "⟧"] @punctuation.bracket
["," ";" ":" "."] @punctuation.delimiter
