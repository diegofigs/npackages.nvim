# Updating and releasing

## Scope of this update

This PR restores modern Neovim compatibility and standalone package-manager
workflows. Full pnpm monorepo discovery and operations are a separate follow-up.
Explicit `workspace:` dependencies are skipped by registry operations, but local
workspace versions/navigation are not implemented. The Mac input-mode issue
also remains unresolved; see [known limitations](neovim-compatibility.md).

## Update a local copy while testing

Replace the host and checkout path below, then copy the latest plugin code
and restart Neovim:

```sh
scp -r \
  user@host:/path/to/npackages.nvim/lua \
  ~/src/npackages.nvim/
```

This overwrites matching files in the local copy. It does not copy tests/docs.
Keep the existing lazy.nvim `dir` configuration while testing this copy.

## Merge and release

The previous release is `v0.3.0`. Use **v0.4.0** for this update: the new Neovim
0.11 minimum must be called out as a compatibility change. No tag has been
created by preparing this PR.

1. Verify the current PR checks with `gh pr checks 20`, review the known issues,
   and finish a Mac smoke test. Then mark it ready and merge:

   ```sh
   gh pr ready 20
   gh pr merge 20 --squash
   ```

2. In a normal Git clone of this repository, switch to `main` and pull the merged
   commit. The copied Mac plugin directory is not a normal clone; use a separate
   clone if needed. If `main` is checked out in another worktree, use that
   worktree instead of trying to switch this feature worktree to it.

   ```sh
   git switch main
   git pull --ff-only origin main
   git status --short
   git log -1 --oneline
   ```

   Confirm a clean tree, the expected merged commit, and that `v0.4.0` does not
   already exist locally or on the remote before creating the tag.

3. Tag that exact merged commit and push the tag:

   ```sh
   git tag -a v0.4.0 -m "Neovim 0.11+ compatibility and package-manager fixes"
   git push origin v0.4.0
   ```

   This is the publishing step. The existing `Release` workflow triggers on
   `v*.*.*` tags. It uploads to LuaRocks when `LUAROCKS_API_KEY` is configured,
   then creates the GitHub release with generated notes. The checkout is
   unconditional; the upload guard reads the key from job-level environment.
   A failed LuaRocks job prevents the dependent GitHub release job from running.

4. Check the workflow and published release:

   ```sh
   gh run list --workflow release.yml --limit 3
   gh release view v0.4.0
   ```

   Add release-note highlights: Neovim 0.11+ requirement, four-manager tests,
   registry/refresh fixes, the jsonls/Noice configuration, and remaining
   input-mode/workspace limitations. Do not describe the Mac input issue or
   all editor stalls as fixed. The SCM rockspec stays `scm-1`; the tag-release
   action derives the published version from the tag.

## Switch lazy.nvim back to GitHub

After publishing, replace the local `dir` entry with the repository and release
pin, retaining your existing `init`, dependencies, and keymaps:

```lua
{
  "diegofigs/npackages.nvim",
  version = "v0.4.0",
  dependencies = { "nvim-neotest/nvim-nio" },
  lazy = false,
  init = function()
    -- Keep your existing vim.g.npackages configuration here.
  end,
}
```

Run `:Lazy sync`, then restart Neovim. Later, change the pinned version and run
`:Lazy update npackages.nvim`. Commit the updated lazy.nvim lockfile with your
config if you track it. Remove any old `dir`, `dev`, or feature-branch override
from this plugin's spec when using a release pin.
