#!/usr/bin/env bash
set -euo pipefail

export NPACKAGES_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export NPACKAGES_LAZY="$(realpath "${1:?path to lazy.nvim checkout required}")"
export NPACKAGES_NIO="$(realpath "${2:?path to nvim-nio checkout required}")"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export XDG_CONFIG_HOME="$scratch/config" XDG_CACHE_HOME="$scratch/cache"
export XDG_DATA_HOME="$scratch/data" XDG_STATE_HOME="$scratch/state"
mkdir -p "$scratch/existing" "$scratch/new" "$scratch/second"
printf '{}\n' > "$scratch/existing/package.json"
printf '{}\n' > "$scratch/second/package.json"
printf '{}\n' > "$scratch/other.json"
touch "$scratch/other.txt"
export NPACKAGES_SECOND="$scratch/second/package.json"

setup='lua vim.opt.rtp:prepend(vim.env.NPACKAGES_LAZY)
local spec = { "diegofigs/npackages.nvim", dir = vim.env.NPACKAGES_ROOT }
if vim.env.NPACKAGES_MODE == "explicit" then
  spec = dofile(vim.env.NPACKAGES_ROOT .. "/lazy.lua")
  spec.dir = vim.env.NPACKAGES_ROOT
end
require("lazy").setup({
  spec,
  { "nvim-neotest/nvim-nio", dir = vim.env.NPACKAGES_NIO, lazy = true },
}, {
  pkg = { enabled = vim.env.NPACKAGES_MODE ~= "explicit" },
  install = { missing = false },
  change_detection = { enabled = false },
})'
check='lua
local ok, message = pcall(function()
  local expected = vim.env.NPACKAGES_EXPECT == "loaded"
  if vim.env.NPACKAGES_MODE ~= "native" then
    local plugins = require("lazy.core.config").plugins
    for _, name in ipairs({ "npackages.nvim", "nvim-nio" }) do
      assert((plugins[name]._.loaded ~= nil) == expected, name)
    end
  end
  local function clients()
    return vim.lsp.get_clients({ bufnr = 0, name = "npackages_ls" })
  end
  assert(#clients() == (expected and 1 or 0), "unexpected manifest LSP attachment")
  if expected then
    local id = clients()[1].id
    vim.cmd.edit(vim.env.NPACKAGES_SECOND)
    assert(#clients() == 1 and clients()[1].id == id, "client reuse failed")
  end
end)
if not ok then
  vim.api.nvim_err_writeln(message)
  vim.cmd.cquit()
end'

run() {
  local mode=$1 expected=$2 opening=$3 file=${4:-}
  local args=() before=() after=()
  [[ "$mode" == early || "$mode" == explicit ]] && before+=(--cmd 'filetype plugin on')
  if [[ "$mode" == native ]]; then
    before+=(--cmd 'lua vim.opt.rtp:prepend(vim.env.NPACKAGES_ROOT); vim.opt.rtp:append(vim.env.NPACKAGES_NIO)')
  else
    before+=(--cmd "$setup")
  fi
  if [[ "$opening" == startup && -n "$file" ]]; then
    args+=("$file")
  elif [[ -n "$file" ]]; then
    NPACKAGES_EDIT="$file"
    export NPACKAGES_EDIT
    after+=(-c 'lua vim.cmd.edit(vim.env.NPACKAGES_EDIT)')
  fi
  NPACKAGES_MODE="$mode" NPACKAGES_EXPECT="$expected" "${NVIM:-nvim}" \
    --headless -u NORC -i NONE "${before[@]}" "${args[@]}" "${after[@]}" -c "$check" -c 'qa!'
}

run default unloaded startup
run default unloaded startup "$scratch/other.txt"
run default unloaded startup "$scratch/other.json"
for mode in default early explicit native; do
  for opening in startup edit; do
    run "$mode" loaded "$opening" "$scratch/existing/package.json"
    run "$mode" loaded "$opening" "$scratch/new/package.json"
  done
done
