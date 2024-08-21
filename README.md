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

[![MIT License][license-shield]][license-url]
[![Issues][issues-shield]][issues-url]
[![CI Status][ci-shield]][ci-url]
[![Lint Status][lint-shield]][lint-url]
[![LuaRocks][luarocks-shield]][luarocks-url]

</div>
	
<!-- markdownlint-restore -->

## :link: Quick Links

<!--toc:start-->

- [:link: Quick Links](#link-quick-links)
- [:pencil: Prerequisites](#pencil-prerequisites)
- [:inbox_tray: Installation](#inbox_tray-installation)
- [:zap: Quick Setup](#zap-quick-setup)
- [:books: Usage](#books-usage)
  - [Diagnostics](#diagnostics)
  - [Code Actions](#code-actions)
  - [Code Lens (Run Scripts)](#code-lens-run-scripts)
  - [Go to Definition](#go-to-definition)
- [Related projects](#related-projects)

<!--toc:end-->

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

npackages.nvim supercharges your package.json experience in Neovim by providing a rich set of LSP features. These features help you manage your dependencies with ease, offering functionality like diagnostics, completion, code actions, code lens, document symbols, semantic tokens, and go-to-definition. Here's a breakdown of the main features:

### Diagnostics

npackages.nvim provides real-time diagnostics for your package.json files. It identifies issues such as missing or incorrect dependency versions, helping you ensure your dependencies are always up-to-date and correctly specified.

How it works: Diagnostics are triggered whenever you open, change, or save a package.json file. Issues like missing dependencies or mismatched versions will be highlighted directly in the editor.
Completion (Package Names and Versions)
npackages.nvim offers intelligent completion suggestions for package names and versions as you edit your package.json file.

- Package Name Completion: As you start typing a package name, the LSP client will suggest possible packages from npm, helping you quickly find and add the correct dependencies.

- Version Completion: When specifying a version for a dependency, the plugin suggests the latest versions available, ensuring that you can easily select the correct one.

- How it works: Completion suggestions are triggered as you type, providing inline options for package names and versions based on npm registry data.

### Code Actions

npackages.nvim offers useful code actions to help you fix issues in your package.json files and maintain clean, well-formatted code.

- Diagnostics Fixes: Automatically fix issues identified by diagnostics, such as updating a dependency to the latest version or correcting a version format.

- JSON Formatting: Quickly format your package.json for consistency and readability.

- How it works: Code actions can be triggered via the LSP command palette or through key mappings, providing quick fixes and formatting options.

### Code Lens (Run Scripts)

npackages.nvim adds code lenses above each script defined in your package.json file, allowing you to run scripts directly from the editor.

- How it works: Code lenses appear as actionable text above each script definition. Simply click on the lens to run the associated script using your preferred package manager (npm, yarn, pnpm).
  Document Symbols and Semantic Tokens
  npackages.nvim enhances your editing experience by providing document symbols and semantic tokens, making navigation and understanding your package.json structure easier.

- Document Symbols: These allow you to quickly navigate through different sections of your package.json, such as dependencies, devDependencies, and scripts.

- Semantic Tokens: Provides syntax highlighting for different elements in package.json, differentiating between keys, values, and script names for better readability.

- How it works: Document symbols and semantic tokens are automatically enabled when you open a package.json file, with symbols accessible via your LSP client’s symbol navigation.

### Go to Definition

npackages.nvim enables quick navigation to a dependency’s package.json file within your node_modules directory.

- How it works: Place your cursor on a dependency name in your package.json, and trigger the "Go to Definition" command to jump directly to the package.json of that package in node_modules.

<!-- markdownlint-restore -->

### Commands

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
