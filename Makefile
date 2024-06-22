.PHONY: test types

test:
	luarocks install --local nlua
	luarocks test --local

lint:
	luacheck lua/npackages

types:
	./scripts/gen_types.lua
