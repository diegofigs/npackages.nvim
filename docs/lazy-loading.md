# Loading on package.json

Lazy.nvim putting a plugin on the runtimepath and Neovim attaching its LSP are
separate events. The previous `lazy = false` recommendation loaded npackages and
nvim-nio at startup. The JSON ftplugin still deferred initialization and the
embedded server until it saw a `package.json`. The filename events now defer
both plugin loading and attachment. A bare install gets the events through
[`lazy.lua` package metadata](https://lazy.folke.io/packages).

- [crates.nvim](https://github.com/saecki/crates.nvim#installation) uses
  `BufRead Cargo.toml` for its embedded LSP plugin. Its
  [setup](https://github.com/saecki/crates.nvim/blob/main/lua/crates/init.lua)
  handles the current manifest as well as registering handlers for future ones.
  Npackages uses `BufReadPre` to load before detection for existing manifests and
  `BufNewFile` to cover new ones.
- [rustaceanvim](https://github.com/mrcjkb/rustaceanvim#-installation) recommends
  `lazy = false` and defers LSP activation to its Rust ftplugin. That matches
  the former npackages recommendation and follows
  [Neovim's guidance on deferred initialization](https://neovim.io/doc/user/lua-plugin/#lua-plugin-lazy).
- [lazydev.nvim](https://github.com/folke/lazydev.nvim#-installation) uses
  `ft = "lua"` for its LuaLS integration. The corresponding `ft = "json"`
  trigger loads npackages on unrelated JSON files.

If filetype plugins are enabled before lazy.nvim, Neovim can finish filetype
detection for a new manifest before the lazy.nvim handler runs.
[Lazy.nvim's event replay](https://github.com/folke/lazy.nvim/blob/main/lua/lazy/core/handler/event.lua)
skips previously registered groups for `BufNewFile`. The lazy.nvim configuration
callback therefore handles an already-detected manifest using the same
activation function as the ftplugin.

Run the headless regression check with local lazy.nvim and nvim-nio checkouts.
Set `NVIM` to select a Neovim binary.

```sh
bash tests/integration/lazy_entrypoint.sh /path/to/lazy.nvim /path/to/nvim-nio
```
