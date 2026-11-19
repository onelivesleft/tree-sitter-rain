; A here-string whose name ends with a language's (#"GLSL, #"VERTEX_HLSL,
; #"QUERY_SQL) is that language. Its pieces between interpolations are one.
;
; Not rain's own (#"RAIN), as Neovim's and Helix's are: Zed (1.29) loads a
; language's injected languages as it loads it, so rain injecting rain loads
; it again and again, its memory growing by gigabytes a minute with nothing
; highlighted.

((here_string
  (here_string_start) @_start
  (here_string_content) @injection.content)
  (#match? @_start "GLSL\\s*$")
  (#set! injection.language "glsl")
  (#set! injection.combined))

((here_string
  (here_string_start) @_start
  (here_string_content) @injection.content)
  (#match? @_start "HLSL\\s*$")
  (#set! injection.language "hlsl")
  (#set! injection.combined))

((here_string
  (here_string_start) @_start
  (here_string_content) @injection.content)
  (#match? @_start "WGSL\\s*$")
  (#set! injection.language "wgsl")
  (#set! injection.combined))

((here_string
  (here_string_start) @_start
  (here_string_content) @injection.content)
  (#match? @_start "JSON\\s*$")
  (#set! injection.language "json")
  (#set! injection.combined))

((here_string
  (here_string_start) @_start
  (here_string_content) @injection.content)
  (#match? @_start "XML\\s*$")
  (#set! injection.language "xml")
  (#set! injection.combined))

((here_string
  (here_string_start) @_start
  (here_string_content) @injection.content)
  (#match? @_start "HTML\\s*$")
  (#set! injection.language "html")
  (#set! injection.combined))

((here_string
  (here_string_start) @_start
  (here_string_content) @injection.content)
  (#match? @_start "SQL\\s*$")
  (#set! injection.language "sql")
  (#set! injection.combined))

((here_string
  (here_string_start) @_start
  (here_string_content) @injection.content)
  (#match? @_start "(^|_)C\\s*$")
  (#set! injection.language "c")
  (#set! injection.combined))

((here_string
  (here_string_start) @_start
  (here_string_content) @injection.content)
  (#match? @_start "(SH|BASH)\\s*$")
  (#set! injection.language "bash")
  (#set! injection.combined))

((here_string
  (here_string_start) @_start
  (here_string_content) @injection.content)
  (#match? @_start "(MARKDOWN|MD)\\s*$")
  (#set! injection.language "markdown")
  (#set! injection.combined))

((here_string
  (here_string_start) @_start
  (here_string_content) @injection.content)
  (#match? @_start "(JS|JAVASCRIPT)\\s*$")
  (#set! injection.language "javascript")
  (#set! injection.combined))

((here_string
  (here_string_start) @_start
  (here_string_content) @injection.content)
  (#match? @_start "PYTHON\\s*$")
  (#set! injection.language "python")
  (#set! injection.combined))
