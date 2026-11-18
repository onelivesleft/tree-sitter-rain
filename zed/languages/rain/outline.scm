; The file's declarations, a module's and a program's, and a struct's,
; union's or enum's members inside theirs.

(source_file (constant_declaration name: (_) @name) @item)
(source_file (variable_declaration name: (_) @name) @item)
(module_type (block (constant_declaration name: (_) @name) @item))
(module_type (block (variable_declaration name: (_) @name) @item))
(program_type (block (preset name: (identifier) @name) @item))
(struct_type (block (variable_declaration name: (_) @name) @item))
(union_type (block (variable_declaration name: (_) @name) @item))
(enum_type (block (expression_statement (identifier) @name) @item))
(compile_if (block (constant_declaration name: (_) @name) @item))
