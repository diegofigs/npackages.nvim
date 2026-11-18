# Package-manager integration tests

Run from a checkout with Bash, Git, Node.js/npm, and Neovim 0.11+ installed:

```sh
./tests/integration/run.sh             # all four, sequentially
./tests/integration/run.sh pnpm        # npm | pnpm | yarn-classic | yarn-modern
```

The runner installs isolated, pinned CLI versions under
`/tmp/npackages-integration-tools` (override with `NPACKAGES_TEST_CACHE`). It
requires network access and reuses npm's normal download cache. Pinned nvim-nio and Snacks
checkouts are bootstrapped there too. It does not change your global CLI versions,
Neovim config, or an existing project. Failed project fixtures are retained at
the path printed in the log; successful fixtures are deleted.

Current baseline: npm 10.9.2, pnpm 9.15.5, Yarn Classic 1.22.22, Yarn 4.6.0.
These are explicit compatibility baselines, not claims about latest releases.
Update pins deliberately and rerun all four before changing the supported set.

Each fresh Neovim process uses real plugin commands and real CLI processes.
Only selection/input UI is scripted; the scripted picker switches to a scratch
buffer to catch wrong-buffer and wrong-directory regressions. The editor stays
outside the fixture project. Checks cover manager detection, install, production
and dev additions, version selection, upgrade, and removal from both sections.
Every successful command must leave the original buffer equal to the on-disk
manifest. Dependency versions/sections and the generated lockfile are checked.
Async task errors, nonzero job exits, and timeouts fail the run. Input checks
cover cancellation, blank input, trimmed surrounding whitespace/newlines,
embedded whitespace/newlines, and option-like input. The input provider must
not open until the selection callback has finished its cleanup. A separate Neovim event-loop test opens a real prompt window in normal mode
and asserts that the input helper enters insert mode and delivers its value.
A real Snacks picker-to-input test also asserts that Add finishes in insert
mode. The previous scheduled-startinsert implementation fails this test; the
timer-turn implementation passes. Your full LazyVim config still merits a
manual smoke test.

CI reports each manager independently. This suite complements the existing
Busted specs; it does not replace them. It currently covers standalone projects,
not workspaces, Yarn PnP, offline registries, or actual LazyVim picker rendering.
It does not exercise LSP features. CLI lifecycle scripts are disabled.

On the sandboxed coding worker, use a writable npm download cache:

```sh
npm_config_cache=/tmp/npackages-npm-cache ./tests/integration/run.sh
```
