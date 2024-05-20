# npackages.nvim

[![CI](https://github.com/diegofigs/npackages.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/diegofigs/npackages.nvim/actions/workflows/ci.yml)
![LOC](https://tokei.rs/b1/github/diegofigs/npackages.nvim?category=code)

A neovim plugin that helps managing npm dependencies.
Heavily modified fork of [crates.nvim](https://github.com/Saecki/crates.nvim)
but targeted towards node's package.json

## :inbox_tray: Installation

[**vim-plug**](https://github.com/junegunn/vim-plug)

```vim
Plug 'diegofigs/npackages.nvim'
```

[**lazy.nvim**](https://github.com/folke/lazy.nvim)

```lua
{
  'diegofigs/npackages.nvim',
  lazy = false, -- This plugin is already lazy
}
```

## :zap: Quick Setup

This plugin automatically configures an LSP client
that will provide diagnostics for your package dependencies.

This is a filetype plugin that works out of the box,
so there is no need to call a `setup` function or configure anything
to get this plugin working.

## Related projects

- [Saecki/crates.nvim](https://github.com/Saecki/crates.nvim)
- [vuki656/package-info.nvim](https://github.com/vuki656/package-info.nvim)
