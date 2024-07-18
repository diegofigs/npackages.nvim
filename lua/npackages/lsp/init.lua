local client = require("npackages.lsp.client")
local server = require("npackages.lsp.server").server

local M = {}

function M.start()
	return client.start(server)
end

return M
