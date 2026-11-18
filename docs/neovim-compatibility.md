# Neovim compatibility and daily use

## Supported baseline

This update raises the minimum from the previously advertised Neovim 0.9 to
**0.11**. Client methods now use the 0.11 colon-call API, and timers use `vim.uv`.
There is no replacement public setup API: configure `vim.g.npackages` before
JSON file type activation. Existing commands and attachment callbacks remain.

- [Neovim client-method deprecations](https://neovim.io/doc/user/deprecated/) distinguish deprecations from removals. The old dot-style client methods were deprecated; the embedded transport still uses dot-style functions.
- [Neovim 0.12 changes](https://neovim.io/doc/user/news-0.12/) remove legacy diagnostic APIs; no matching calls were found in npackages.
- [The 0.12.6 RPC implementation](https://github.com/neovim/neovim/blob/v0.12.6/runtime/lua/vim/lsp/rpc.lua) defines transport requests, reply acknowledgements, notification success, and termination.

The plugin continues to use `vim.lsp.start` with an in-process Lua server. It does
not require a migration to nvim-lspconfig or an externally installed server.

## Fixes in this update

- Fetching is limited to four concurrent requests per refresh and deduplicates package names. Curl uses a 5-second connect timeout, a 20-second per-attempt timeout, and a 25-second retry window. Metadata conversion yields every 100 versions; JSON decoding itself is still synchronous. Explicit `workspace:`, `file:`, and `link:` specs are classified as local and skipped for registry fetching, version diagnostics, and registry-link actions. This does not resolve workspace package paths or discover local packages declared with ordinary semver ranges.
- Initial dependency diagnostics wait for metadata loading to finish. Later refreshes retain the last published diagnostics while pending; actual fetch/decode failures are diagnosed after the attempt completes. A diagnostic pull before the document cache exists returns an empty report.
- Registry fetching uses `curl -sL`; the old `sL` argument was interpreted as a URL. The User-Agent is passed as a literal argument rather than shell-quoted inside an argv list.
- Diagnostics and request cancellation use modern client methods. Unknown requests return MethodNotFound; shutdown, exit, and reply acknowledgement follow the embedded transport contract.
- Explicitly disabled hover and code-action capabilities remain disabled. Missing registry metadata no longer crashes code actions; absent homepage/repository URLs do not produce unusable actions.
- npm lockfile detection includes the missing path separator. Yarn's major version is parsed after leading whitespace so Yarn Classic commands are selected correctly.
- Add captures its package manager and buffer at invocation. Package commands retain the original project directory across UI prompts. Reload works from regular callbacks and refreshes the original buffer, including when hidden.
- Add trims surrounding whitespace, rejects embedded whitespace/control characters and option-like input, and shell-quotes the package argument. This is not a complete npm package-spec validator.
- Health checks report the Neovim baseline and nvim-nio availability, including when no user configuration is provided.

## LazyVim, jsonls, and Noice

Keep jsonls attached for schema validation, completion, and formatting. In the
reported Mac LazyVim setup, hover became reliable when **jsonls hover was disabled
and Noice remained enabled**. The precise cause of the competing hover behavior
has not been established; this configuration is a verified workaround.

Remove any previous autocmd that detaches jsonls from `package.json`. Add this
plugin spec, or merge its callback into your existing jsonls attachment callback:

```lua
return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      jsonls = {
        on_attach = function(client)
          client.server_capabilities.hoverProvider = false
        end,
      },
    },
  },
}
```

This disables jsonls hover for **all buffers served by that client**, not only
package.json. Other JSON LSP capabilities remain enabled. Do not toggle the
shared capability conditionally on a filename and assume it is buffer-local.
Restart Neovim and verify in package.json:

```vim
:lua for _, c in ipairs(vim.lsp.get_clients({bufnr=0})) do print(c.name, c:supports_method("textDocument/hover", 0)) end
```

Expect `jsonls false` and `npackages_ls true`.

This follows [LazyVim's documented Ruff/Pyright capability-selection pattern](https://www.lazyvim.org/extras/lang/python).
[Neovim's native hover aggregates responses](https://github.com/neovim/neovim/blob/v0.12.6/runtime/lua/vim/lsp/buf.lua), whereas
[Noice replaces hover and requests individual responses](https://github.com/folke/noice.nvim/blob/main/lua/noice/lsp/init.lua).
These explain why renderer/client interactions matter, without establishing the
exact root cause in the user's config.

## Known limitations

**Automatic insert mode remains unresolved in the reported Mac LazyVim setup.**
The Add prompt attempts to enter insert mode after picker cleanup, and isolated
prompt and real Snacks integration tests pass locally. The user still reported
normal mode after installing the changes. Those tests do not reproduce the full
user configuration and must not be treated as proof that this issue is fixed.
Use `i` in the prompt as a workaround; `o` can create an extra line. Input
normalization handles surrounding newlines but rejects embedded newlines.

Package-manager detection still relies on adjacent lockfiles. Workspace root/package discovery,
ancestor lockfiles, mixed Yarn versions within one session, Yarn PnP, offline
registry recovery, and rapid multi-buffer LSP edits are not covered by the new
standalone-project integration matrix. Package commands change manifests and
lockfiles on disk; save edits before running them. An unsaved modified buffer
is not forcibly discarded by refresh.

## Evidence and verification

Local validation covered Neovim **0.11.5 and 0.12.6**: the Busted specs and
all four real package-manager sequences passed on both versions. Subsequent fetch
responsiveness tests also pass on both: delayed requests, failure handling,
cooperative conversion, explicit local specs, and bounded concurrency.

The [integration guide](../tests/integration/README.md) lists pinned manager
versions, commands, expected assertions, and how to rerun checks. These tests
exercise real CLIs and original-buffer refresh; they do not verify LSP rendering.

Linux headless checks on Neovim 0.12.6 returned nonempty results for hover,
package-name/version completion, actions, symbols, semantic tokens, hints,
script lenses, and definition navigation using a node_modules fixture. Script
execution and applying action edits were not verified by those request checks.

Manual Mac confirmations from this investigation: package/version popups,
code-action diff previews, the coexistence workaround above, and Add/Remove with
Yarn Classic in diegofigs.tech. A diff preview is not evidence that applying every
action is correct. CI results must be checked separately from local runs.
