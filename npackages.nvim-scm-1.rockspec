rockspec_format = "3.0"
package = "npackages.nvim"
version = "scm-1"

dependencies = {
	"lua >= 5.1",
}

test_dependencies = {
	"busted == 2.1.2-3",
}

source = {
	url = "git+https://github.com/diegofigs/npackages.nvim",
}

build = {
	type = "builtin",
}
