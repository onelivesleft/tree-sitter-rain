// Starts 'rain's language server, rain -lsp, for Zed: errors as you type
// (with quick fixes), go to definition, hover and find references.
//
// The compiler is the one Zed's settings name, or else rain on the PATH:
//
//   "lsp": { "rain": { "binary": { "path": "C:/rain/build/rain.exe" } } }
//
// (arguments given there are used in place of -lsp).

use zed_extension_api::{self as zed, settings::LspSettings, LanguageServerId, Result};

struct RainExtension;

impl zed::Extension for RainExtension {
    fn new() -> Self {
        RainExtension
    }

    fn language_server_command(&mut self, language_server_id: &LanguageServerId, worktree: &zed::Worktree) -> Result<zed::Command> {
        let binary = LspSettings::for_worktree(language_server_id.as_ref(), worktree)
            .ok()
            .and_then(|settings| settings.binary);
        let path = binary.as_ref().and_then(|b| b.path.clone());
        let arguments = binary.as_ref().and_then(|b| b.arguments.clone());
        let env = binary.as_ref().and_then(|b| b.env.clone()).map(|e| e.into_iter().collect()).unwrap_or_default();
        let command = match path {
            Some(path) => path,
            None => worktree.which("rain").ok_or_else(|| {
                "rain isn't on the PATH: put it there, or name it in Zed's settings, \
                 \"lsp\": { \"rain\": { \"binary\": { \"path\": \"C:/rain/build/rain.exe\" } } }"
                    .to_string()
            })?,
        };
        Ok(zed::Command {
            command,
            args: arguments.unwrap_or_else(|| vec!["-lsp".to_string()]),
            env,
        })
    }
}

zed::register_extension!(RainExtension);
