# tree-sitter-rain

A [tree-sitter](https://tree-sitter.github.io) grammar for 'rain, with
queries for Neovim, Helix and Zed: highlighting, here-strings highlighted as
the language their name ends with (`#"VERTEX_GLSL`), folds, indents, an
outline, locals and text objects.

It parses every file of 'rain's repository but the tests of what isn't
'rain (`tests/err_*`), which rain's suite checks (`tests/tree_sitter.rain`).

## What it reads

- Statements end at a line's end, or at `;`, as rain's parser has it:
  inside brackets, or after an operator still wanting its operand, a line
  goes on. The external scanner ([src/scanner.c](src/scanner.c)) gives the
  line's end only where a statement can end there, and not before an
  `else` (or `#else`, `#elseif`) that goes on the statement.
- Types are expressions, as rain's are (`[3] i64`, `^T`, `Holder(f32)`,
  `struct { ... }`), so a declaration's type is any expression.
- Raw strings (`#"..."#`, `##"..."##`), here-strings (`#"END` ... `END"#`)
  and block comments, which nest, are the scanner's; so is a string's text,
  so a `//` or `/*` in a string is no comment. `«...»` interpolates in every
  string.
- `program`, `module` and `shader` are names too (`program := ...`): each is
  the keyword only where its type begins, the word then a `{` (or a
  module's parameters' `(`).

## Building it

It needs only the [tree-sitter CLI](https://github.com/tree-sitter/tree-sitter/releases),
whose own JavaScript runtime reads [grammar.js](grammar.js): no Node.

```
tree-sitter generate --js-runtime native
tree-sitter test
tree-sitter parse --grammar-path . path/to/file.rain
```

The generated parser (`src/parser.c`, `src/grammar.json`,
`src/node-types.json`) is committed, as the editors build from it.

## Neovim

With nvim-treesitter, in your configuration:

```lua
local parsers = require("nvim-treesitter.parsers").get_parser_configs()
parsers.rain = {
  install_info = {
    url = "C:/repos/tree-sitter-rain",   -- or the repository's URL
    files = { "src/parser.c", "src/scanner.c" },
  },
  filetype = "rain",
}
vim.filetype.add({ extension = { rain = "rain" } })
```

then `:TSInstall rain`, and put this folder on the runtime path
(`vim.opt.runtimepath:append("C:/repos/tree-sitter-rain")`) for its
[queries](queries/). Text objects are nvim-treesitter-textobjects' names.

## Helix

In `languages.toml`:

```toml
[[language]]
name = "rain"
scope = "source.rain"
file-types = ["rain"]
comment-tokens = "//"
block-comment-tokens = { start = "/*", end = "*/" }
indent = { tab-width = 4, unit = "    " }

[[grammar]]
name = "rain"
source = { path = "C:/repos/tree-sitter-rain" }
```

then `hx --grammar build`, and copy (or link) [helix/queries/rain](helix/queries/rain)
to Helix's `runtime/queries/rain`.

## Zed

[zed/](zed/) is the extension: in Zed, `zed: install dev extension` and
choose that folder. Its grammar is this repository at the commit
`zed/extension.toml` names (`rev`), from the folder its `repository` says:
after changing the grammar, commit, and put the new commit in `rev`.

Besides the grammar's queries, it has runnables (a ▶ beside each `#test`
and `main`), tasks (run, build, test, `-check:all`), and the compiler's
language server, `rain -lsp` (errors as you type with quick fixes, go to
definition, hover, find references), which [zed/src/lib.rs](zed/src/lib.rs)
starts. That code is Rust, so installing the dev extension needs rustup. It
uses `rain` from the PATH, or the compiler Zed's settings name:

```json
"lsp": { "rain": { "binary": { "path": "C:/rain/build/rain.exe" } } }
```
