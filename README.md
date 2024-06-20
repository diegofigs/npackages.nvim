<!-- markdownlint-disable -->
<div align="center">
  <h1>npackages.nvim</h1>
  <p align="center">
    <a href="https://github.com/diegofigs/npackages.nvim/issues/new">Report Bug / Request Feature</a>
    ·
    <a href="https://github.com/diegofigs/npackages.nvim/discussions/new?category=q-a">Ask Question</a>
  </p>
  <p>
    <strong>
      Supercharge your Node experience in <a href="https://neovim.io/">Neovim</a>!<br />
      A heavily modified fork of <a href="https://github.com/Saecki/crates.nvim">crates.nvim</a><br />
    </strong>
  </p>

[![Neovim][neovim-shield]][neovim-url]
[![Lua][lua-shield]][lua-url]
[![npm][npm-shield]][npm-url]
![LoC][loc-shield]

[![MIT License][license-shield]][license-url]
[![Issues][issues-shield]][issues-url]
[![CI Status][ci-shield]][ci-url]
[![Lint Status][lint-shield]][lint-url]
[![LuaRocks][luarocks-shield]][luarocks-url]

</div>
	
<!-- markdownlint-restore -->

## :link: Quick Links

- [:pencil: Prerequisites](#pencil-prerequisites)
- [:inbox_tray: Installation](#inbox_tray-installation)
- [:zap: Quick setup](#zap-quick-setup)
- [:books: Usage / Features](#books-usage)

## :pencil: Prerequisites

### Required

- `neovim >= 0.9`
- `curl`
- [nvim-nio](https://github.com/nvim-neotest/nvim-nio)

### Optional

- `vim.ui` implementation such as [dressing.nvim](https://github.com/stevearc/dressing.nvim)
- `$/progress` display such as [noice.nvim](https://github.com/folke/noice.nvim)

## :inbox_tray: Installation

[**vim-plug**](https://github.com/junegunn/vim-plug)

```vim
Plug 'diegofigs/npackages.nvim'
```

[**packer.nvim**](https://github.com/wbthomason/packer.nvim)

```lua
use { 'diegofigs/npackages.nvim', requires = { "nvim-neotest/nvim-nio" } }
```

[**lazy.nvim**](https://github.com/folke/lazy.nvim)

```lua
{
  'diegofigs/npackages.nvim',
  dependencies = { "nvim-neotest/nvim-nio" }
  lazy = false, -- This plugin is already lazy
}
```

## :zap: Quick Setup

This plugin automatically configures an LSP client
that will provide diagnostics for your package.json dependencies.
See the [Usage](#books-usage) section for more info.

This is a file type plugin that works out of the box,
so there is no need to call a `setup` function or configure anything
to get this plugin working.

You will most likely want to add some keymaps.
Most keymaps are only useful in package.json files,
so I suggest you define them in `vim.g.npackages.on_attach`

Example:

<!-- markdownlint-disable -->

```lua
vim.g.npackages = {
  on_attach = function(bufnr)
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>nt", "<cmd>Npackages toggle<cr>", {
      desc = "Toggle Package Versions",
    })
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>na", "<cmd>Npackages add<cr>", {
      desc = "Add Package",
    })
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>nd", "<cmd>Npackages delete<cr>", {
      desc = "Delete Package",
    })
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>nu", "<cmd>Npackages update<cr>", {
      desc = "Update Package",
    })
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>nc", "<cmd>Npackages change_version<cr>", {
      desc = "Change Version",
    })
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>ni", "<cmd>Npackages install<cr>", {
      desc = "Install Package Dependencies",
    })
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>nr", "<cmd>Npackages refresh<cr>", {
      desc = "Refresh Packages",
    })
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>nR", "<cmd>Npackages reload<cr>", {
      desc = "Reload Packages",
    })
  end,
}
```

<!-- markdownlint-restore -->

## :books: Usage

<!-- markdownlint-disable -->
<details>
  <summary>
	<b>Toggle</b>
  </summary>

- `toggle` toggles diagnostics on/off

```vim
:Npackages toggle
```

```lua
vim.cmd.Npackages('toggle')
```

</details>

<details>
  <summary>
	<b>Refresh</b>
  </summary>

- `refresh` diagnostics by fetching `package.json` dependencies whose cache time has expired

```vim
:Npackages refresh
```

```lua
vim.cmd.Npackages('refresh')
```

</details>

<details>
  <summary>
	<b>Reload</b>
  </summary>

- `reload` refreshes diagnostics and force fetches `package.json` dependencies

```vim
:Npackages reload
```

```lua
vim.cmd.Npackages('reload')
```

</details>

<details>
  <summary>
	<b>Install</b>
  </summary>

- `install` runs `npm|yarn|pnpm install`

```vim
:Npackages install
```

```lua
vim.cmd.Npackages('install')
```

</details>

<details>
  <summary>
	<b>Add</b>
  </summary>

- `add` prompts user for dependency type, package name, version
  and runs `npm|yarn|pnpm add [-D] <package>@<version>`

```vim
:Npackages add
```

```lua
vim.cmd.Npackages('add')
```

</details>

<details>
  <summary>
	<b>Update</b>
  </summary>

- `update` runs for package under cursor `npm|yarn|pnpm install <package>@latest`

```vim
:Npackages update
```

```lua
vim.cmd.Npackages('update')
```

</details>

<details>
  <summary>
	<b>Delete</b>
  </summary>

- `delete` runs for package under cursor `npm|yarn|pnpm remove <package>`

```vim
:Npackages delete
```

```lua
vim.cmd.Npackages('delete')
```

</details>

<details>
  <summary>
	<b>Change Version</b>
  </summary>

- `change_version` prompts user for new version for package under cursor
  and runs `npm|yarn|pnpm install <package>@<version>`

```vim
:Npackages change_version
```

```lua
vim.cmd.Npackages('change_version')
```

</details>
<!-- markdownlint-restore -->

## Related projects

- [Saecki/crates.nvim](https://github.com/Saecki/crates.nvim): base plugin structure
  and lsp functionality
- [mrcjkb/rustaceanvim](https://github.com/mrcjkb/rustaceanvim): huge inspiration
  for readme, plugin structure and testing methodology
- [vuki656/package-info.nvim](https://github.com/vuki656/package-info.nvim):
  similar solution, provides commands but no diagnostics

<!-- markdownlint-disable -->

[neovim-shield]: https://img.shields.io/badge/NeoVim-%2357A143.svg?&style=for-the-badge&logo=neovim&logoColor=white
[neovim-url]: https://neovim.io/
[lua-shield]: https://img.shields.io/badge/lua-%232C2D72.svg?style=for-the-badge&logo=lua&logoColor=white
[lua-url]: https://www.lua.org/
[npm-shield]: https://img.shields.io/badge/npm-CC3534?style=for-the-badge&logo=npm&logoColor=white
[npm-url]: https://www.npmjs.com/
[issues-shield]: https://img.shields.io/github/issues/diegofigs/npackages.nvim.svg?style=for-the-badge
[issues-url]: https://github.com/diegofigs/npackages.nvim/issues
[license-shield]: https://img.shields.io/github/license/diegofigs/npackages.nvim.svg?style=for-the-badge
[license-url]: https://github.com/diegofigs/npackages.nvim/blob/main/LICENSE
[ci-shield]: https://img.shields.io/github/actions/workflow/status/diegofigs/npackages.nvim/ci.yml?style=for-the-badge&label=CI
[ci-url]: https://github.com/diegofigs/npackages.nvim/actions/workflows/ci.yml
[lint-shield]: https://img.shields.io/github/actions/workflow/status/diegofigs/npackages.nvim/lint.yml?style=for-the-badge&label=Lint
[lint-url]: https://github.com/diegofigs/npackages.nvim/actions/workflows/lint.yml
[luarocks-shield]: https://img.shields.io/luarocks/v/diegofigs/npackages.nvim?logo=lua&color=purple&style=for-the-badge
[luarocks-url]: https://luarocks.org/modules/diegofigs/npackages.nvim
[loc-shield]: https://img.shields.io/tokei/lines/github/diegofigs/npackages.nvim?style=for-the-badge&logo=adventofcode
