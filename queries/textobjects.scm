; nvim-treesitter-textobjects' names.

(constant_declaration value: (procedure body: (block) @function.inner)) @function.outer
(constant_declaration value: [(struct_type) (union_type) (enum_type)] @class.inner) @class.outer
(constant_declaration value: (module_type body: (block) @class.inner)) @class.outer

(parameter) @parameter.inner
(parameters "," @_comma . (parameter) @parameter.inner) @parameter.outer
(arguments [(named_argument) (_)] @parameter.inner)

(call_expression) @call.outer
(call_expression arguments: (arguments) @call.inner)

(if_statement) @conditional.outer
(if_statement consequence: (block) @conditional.inner)
[(while_statement) (for_statement) (loop_statement)] @loop.outer
(while_statement body: (block) @loop.inner)
(for_statement body: (block) @loop.inner)
(loop_statement body: (block) @loop.inner)

(block) @block.outer
[(comment) (block_comment)] @comment.outer
(return_statement) @return.outer
(assignment) @assignment.outer
(assignment left: (_) @assignment.lhs right: (_) @assignment.rhs)
