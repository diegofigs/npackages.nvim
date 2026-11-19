#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd)
manager=${1:-all}
cache=${NPACKAGES_TEST_CACHE:-/tmp/npackages-integration-tools}
mkdir -p "$cache"
if [[ ! -d "$cache/nio/.git" ]]; then
	git clone --quiet https://github.com/nvim-neotest/nvim-nio "$cache/nio"
fi
git -C "$cache/nio" checkout --quiet edcc181a875301dd21840189aa2f2f9ad69fc172
if [[ ! -d "$cache/snacks/.git" ]]; then
	git clone --quiet https://github.com/folke/snacks.nvim "$cache/snacks"
fi
git -C "$cache/snacks" checkout --quiet 882c996cf28183f4d63640de0b4c02ec886d01f2
run_one() {
	local name=$1 package=$2
	local tools="$cache/$name"
	if [[ ! -f "$tools/.ready" ]] || [[ $(cat "$tools/.ready") != "$package" ]]; then
		npm install --prefix "$tools" --ignore-scripts --no-audit --no-fund "$package"
		printf '%s\n' "$package" >"$tools/.ready"
	fi
	local fixture
	fixture=$(mktemp -d "${TMPDIR:-/tmp}/npackages-$name.XXXXXX")
	echo "Testing $name in $fixture"
	printf '%s\n' '{' '  "name": "npackages-integration",' '  "version": "1.0.0",' '  "private": true' '}' >"$fixture/package.json"
	case "$name" in
	npm) touch "$fixture/package-lock.json" ;;
	pnpm) touch "$fixture/pnpm-lock.yaml" ;;
	yarn*)
		touch "$fixture/yarn.lock"
		printf 'nodeLinker: node-modules\nenableGlobalCache: true\nenableImmutableInstalls: false\n' >"$fixture/.yarnrc.yml"
		;;
	esac
	PATH="$tools/node_modules/.bin:$PATH" NPACKAGES_FIXTURE="$fixture" NPACKAGES_MANAGER="$name" \
		NPACKAGES_NIO="$cache/nio" XDG_STATE_HOME="$cache/state" XDG_CACHE_HOME="$cache/cache" XDG_DATA_HOME="$cache/data" YARN_CACHE_FOLDER="$cache/yarn-cache" YARN_ENABLE_SCRIPTS=false \
		npm_config_ignore_scripts=true npm_config_audit=false npm_config_fund=false \
		nvim --headless -u NONE -l "$repo/tests/integration/package_managers.lua"
	NPACKAGES_NIO="$cache/nio" XDG_STATE_HOME="$cache/state" \
		nvim --headless -u NONE -c "lua dofile('tests/integration/input_mode.lua')"
	NPACKAGES_NIO="$cache/nio" NPACKAGES_SNACKS="$cache/snacks" XDG_STATE_HOME="$cache/state" \
		nvim --headless -u NONE -c "lua dofile('tests/integration/snacks_input.lua')"
	rm -rf "$fixture"
}
cd "$repo"
case "$manager" in
registry-stress)
	NPACKAGES_NIO="$cache/nio" XDG_STATE_HOME="$cache/state" \
		nvim --headless -u NONE -l "$repo/tests/integration/registry_stress.lua"
	;;
npm) run_one npm npm@10.9.2 ;;
pnpm) run_one pnpm pnpm@9.15.5 ;;
yarn-classic) run_one yarn-classic yarn@1.22.22 ;;
yarn-modern) run_one yarn-modern @yarnpkg/cli-dist@4.6.0 ;;
all) for item in npm pnpm yarn-classic yarn-modern; do "$0" "$item"; done ;;
*)
	echo "Usage: $0 [all|npm|pnpm|yarn-classic|yarn-modern|registry-stress]" >&2
	exit 2
	;;
esac
