.PHONY: test types

test:
	./scripts/run-tests.sh

types:
	./scripts/gen_types.lua
