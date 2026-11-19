return {
	"diegofigs/npackages.nvim",
	dependencies = { "nvim-neotest/nvim-nio" },
	event = { "BufReadPre package.json", "BufNewFile package.json" },
	config = function()
		-- Filetype detection may have run before Lazy's BufNewFile handler.
		if vim.bo.filetype == "json" then
			require("npackages.ft").activate()
		end
	end,
}
