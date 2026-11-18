vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(assert(vim.env.NPACKAGES_NIO))
local fixture = assert(vim.env.NPACKAGES_FIXTURE)
local manager = assert(vim.env.NPACKAGES_MANAGER)
local buf, done, failure, choices, input
local jobs, cancelled, input_completed = 0, false, false
local selection_closing = false
local original_cwd = vim.fn.getcwd()
-- Exercise asynchronous pickers that temporarily make a scratch buffer current.
vim.ui.select = function(items, _, callback)
	local choice = table.remove(choices, 1)
	assert(choice, "unexpected select prompt")
	if choice == "VERSION" then
		choice = "6.0.0"
	end
	assert(vim.tbl_contains(items, choice), "choice unavailable: " .. choice)
	vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
	vim.schedule(function()
		selection_closing = true
		callback(choice)
		selection_closing = false
		if choice == "Cancel" then
			cancelled = true
		end
	end)
end
vim.ui.input = function(_, callback)
	assert(not selection_closing, "input opened before selection UI finished closing")
	vim.schedule(function()
		callback(input)
		input_completed = true
	end)
end
local nio = require("nio")
local nio_run = nio.run
nio.run = function(fn, cb, ...)
	return nio_run(fn, cb or function(ok, err)
		if not ok then
			failure = tostring(err)
			done = true
		end
	end, ...)
end
local job = require("npackages.lib.job")
package.loaded["npackages.lib.job"] = function(props)
	if not props.output then
		return job(props)
	end
	jobs = jobs + 1
	local success, error_callback = props.on_success, props.on_error
	props.on_success = function(output)
		local ok, err = pcall(success or function() end, output)
		failure = not ok and err or nil
		done = true
	end
	props.on_error = function(...)
		failure = "command failed: " .. props.command
		if error_callback then
			error_callback(...)
		end
		done = true
	end
	return job(props)
end
local function manifest()
	return vim.json.decode(table.concat(vim.fn.readfile(fixture .. "/package.json"), "\n"))
end
local function run(command, selections, value)
	vim.api.nvim_set_current_buf(buf)
	choices, input, done, failure = selections or {}, value, false, nil
	print("RUN " .. command .. " " .. vim.api.nvim_get_current_line())
	vim.cmd("Npackages " .. command)
	assert(
		vim.wait(120000, function()
			return done
		end),
		command .. " timed out"
	)
	assert(not failure, failure)
	assert(
		vim.wait(3000, function()
			return vim.deep_equal(
				vim.json.decode(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")),
				manifest()
			)
		end),
		command .. ": buffer differs from disk"
	)
	assert(vim.fn.getcwd() == original_cwd, "editor cwd changed")
	print("PASS " .. manager .. " " .. command)
end
local function position(package)
	vim.api.nvim_set_current_buf(buf)
	for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		if line:find('"' .. package .. '"', 1, true) then
			vim.api.nvim_win_set_cursor(0, { i, 0 })
			return
		end
	end
	error("dependency line not found: " .. package)
end
local ok, err = xpcall(function()
	vim.cmd.edit(fixture .. "/package.json")
	buf = vim.api.nvim_get_current_buf()
	require("npackages.ft").setup({ lsp = { enabled = false } })
	local state = require("npackages.state")
	local expected = manager:match("yarn") and "yarn" or manager
	assert(state.package_manager[buf] == expected, "wrong package manager")
	if expected == "yarn" then
		assert(
			vim.wait(10000, function()
				return state.has_old_yarn == (manager == "yarn-classic")
			end),
			"wrong yarn generation"
		)
	end
	run("install", { "Confirm" })
	local before_cancel, jobs_before_cancel = manifest(), jobs
	choices, cancelled = { "Cancel" }, false
	vim.api.nvim_set_current_buf(buf)
	vim.cmd("Npackages add")
	assert(
		vim.wait(1000, function()
			return cancelled
		end),
		"cancel callback missing"
	)
	assert(
		jobs == jobs_before_cancel and vim.deep_equal(before_cancel, manifest()),
		"cancel started a job or changed manifest"
	)
	print("PASS " .. manager .. " cancel")
	for _, bad_input in ipairs({ "", "  ", "is-number\nis-odd", "is-number is-odd", "--global" }) do
		local before, count = manifest(), jobs
		vim.api.nvim_set_current_buf(buf)
		choices, input, input_completed = { "Production" }, bad_input, false
		vim.cmd("Npackages add")
		assert(
			vim.wait(1000, function()
				return input_completed
			end),
			"input callback missing"
		)
		assert(jobs == count and vim.deep_equal(before, manifest()), "invalid input executed a job")
	end
	print("PASS " .. manager .. " rejects malformed input")
	run("add", { "Production" }, " \n is-number@5.0.0 \n ")
	assert(manifest().dependencies["is-number"]:find("5.0.0", 1, true))
	run("add", { "Development" }, "is-odd@3.0.1")
	assert(manifest().devDependencies["is-odd"])
	position("is-number")
	run("change_version", { "VERSION" })
	assert(manifest().dependencies["is-number"]:find("6.0.0", 1, true))
	position("is-number")
	run("update", { "Confirm" })
	assert(manifest().dependencies["is-number"]:find("7.0.0", 1, true))
	for _, package in ipairs({ "is-number", "is-odd" }) do
		position(package)
		run("delete", { "Confirm" })
		local m = manifest()
		assert(not (m.dependencies or {})[package] and not (m.devDependencies or {})[package])
	end
	local lock = expected == "npm" and "package-lock.json" or expected == "pnpm" and "pnpm-lock.yaml" or "yarn.lock"
	assert(vim.fn.getfsize(fixture .. "/" .. lock) > 0, "missing lockfile")
end, debug.traceback)
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
end
vim.cmd("qa!")
