rockspec_format = "3.0"
package = "npackages.nvim"
version = "scm-1"

dependencies = {
	"lua >= 5.1",
	"nvim-nio",
}

test_dependencies = {
	"nlua",
	"nvim-nio",
}

source = {
	url = "git+https://github.com/diegofigs/npackages.nvim",
}

build = {
	type = "builtin",
	copy_directories = {
		"ftplugin",
	},
}
