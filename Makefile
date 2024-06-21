.PHONY: test types

test:
	luarocks install --local nlua
	luarocks test --local

types:
	./scripts/gen_types.lua
