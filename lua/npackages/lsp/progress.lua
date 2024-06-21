local state = require("npackages.lsp.state")

local progress = {}

---@param workDoneToken lsp.ProgressToken
---@param title string
progress.begin = function(workDoneToken, title)
	---@type lsp.WorkDoneProgressParams
	local begin_params = {
		token = workDoneToken,
		---@type lsp.WorkDoneProgressBegin
		value = {
			kind = "begin",
			title = title,
		},
	}
	state.session.dispatchers.notification(vim.lsp.protocol.Methods.dollar_progress, begin_params)
end

---@param workDoneToken lsp.ProgressToken
---@param message string
progress.report = function(workDoneToken, message)
	---@type lsp.WorkDoneProgressParams
	local progress_params = {
		token = workDoneToken,
		---@type lsp.WorkDoneProgressReport
		value = {
			kind = "report",
			message = message,
		},
	}
	state.session.dispatchers.notification(vim.lsp.protocol.Methods.dollar_progress, progress_params)
end

---@param workDoneToken lsp.ProgressToken
---@param message string?
progress.finish = function(workDoneToken, message)
	---@type lsp.WorkDoneProgressParams
	local end_params = {
		token = workDoneToken,
		---@type lsp.WorkDoneProgressEnd
		value = {
			kind = "end",
			message = message,
		},
	}
	state.session.dispatchers.notification(vim.lsp.protocol.Methods.dollar_progress, end_params)
end

return progress
