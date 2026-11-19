; Scopes config.toml's settings can name: inside a string or a comment, a
; bracket or quote isn't closed for you (brackets' not_in).

[(string) (raw_string) (here_string)] @string

; (a line comment's scope runs to its line's end, so typing at its end is in it)
[(comment) (block_comment)] @comment.inclusive
