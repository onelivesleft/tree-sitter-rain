(constant_declaration value: (procedure body: (block) @function.inside)) @function.around
(constant_declaration value: [(struct_type) (union_type) (enum_type)] @class.inside) @class.around
(constant_declaration value: (module_type body: (block) @class.inside)) @class.around

(parameters (parameter) @parameter.inside)
(parameters ((parameter) @parameter.inside . ","? @parameter.around) @parameter.around)
(arguments (_) @parameter.inside)

[(comment) (block_comment)] @comment.inside
[(comment) (block_comment)]+ @comment.around

(constant_declaration
  value: (procedure (directive (directive_name) @_test) body: (block) @test.inside)
  (#eq? @_test "#test")) @test.around
