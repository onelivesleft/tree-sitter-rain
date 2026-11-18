(constant_declaration value: (procedure body: (block) @function.inside)) @function.around
(constant_declaration value: [(struct_type) (union_type) (enum_type)] @class.inside) @class.around
(constant_declaration value: (module_type body: (block) @class.inside)) @class.around
[(comment) (block_comment)] @comment.inside
[(comment) (block_comment)]+ @comment.around
