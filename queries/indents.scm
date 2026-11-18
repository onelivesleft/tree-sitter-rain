[
  (block)
  (case_block)
  (literal)
  (arguments)
  (parameters)
  (notes)
] @indent.begin

(case_clause) @indent.begin

["}" ")" "]" "⟩" "⟧"] @indent.end @indent.branch

"case" @indent.branch

[(comment) (block_comment) (here_string) (raw_string)] @indent.auto
