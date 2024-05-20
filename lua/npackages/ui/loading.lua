local SPINNERS = {
	"⠋",
	"⠙",
	"⠹",
	"⠸",
	"⠼",
	"⠴",
	"⠦",
	"⠧",
	"⠇",
	"⠏",
}

local M = {
	---@type {id: string, is_ready: boolean, message: string}[]
	queue = {},
	state = {
		current_spinner = "",
		index = 1,
		is_running = false,
	},
}

---@type uv_timer_t | nil
local timer

M.init = function()
	if not timer then
		timer = vim.loop.new_timer()
		if timer ~= nil then
			timer:start(
				0,
				60,
				vim.schedule_wrap(function()
					M.update_spinner()
					if not M.has() then
						timer:stop()
						timer = nil
					end
				end)
			)
		end
	end
end

--- Spawn a new loading instance
-- @param log: string - message to display in the loading status
-- @return number - id of the created instance
M.new = function(message)
	local instance = {
		id = math.random(),
		message = message,
		is_ready = false,
	}

	table.insert(M.queue, instance)

	return instance.id
end

--- Start the instance by given id by marking it as ready to run
-- @param id: string - id of the instance to start
-- @return nil
M.start = function(id)
	for _, instance in ipairs(M.queue) do
		if instance.id == id then
			instance.is_ready = true
			if not M.state.is_running then
				M.state.is_running = true
				M.init() -- Start the spinner
			end
		end
	end
end

--- Stop the instance by given id by removing it from the list
-- @param id: string - id of the instance to stop and remove
-- @return nil
M.stop = function(id)
	local filtered_list = {}

	for _, instance in ipairs(M.queue) do
		if instance.id ~= id then
			table.insert(filtered_list, instance)
		end
	end

	M.queue = filtered_list
end

--- Update the spinner instance recursively
-- @return nil
M.update_spinner = function()
	M.state.current_spinner = SPINNERS[M.state.index]

	M.state.index = M.state.index + 1

	M.state.index = (M.state.index % #SPINNERS) + 1 -- Simplified cycling through spinner
end

--- Get the first ready instance message if there are instances
-- @return string
M.message = function()
	local active_instance = nil

	for _, instance in pairs(M.queue) do
		if not active_instance and instance.is_ready then
			active_instance = instance
		end
	end

	if not active_instance then
		M.state.is_running = false
		M.state.current_spinner = ""
		M.state.index = 1

		return ""
	end

	return active_instance.message
end

M.spinner = function()
	return M.state.current_spinner
end

M.get = function()
	local message = M.message()
	if message ~= "" then
		local spinner = M.spinner()
		return spinner .. " " .. message
	end
	return ""
end

M.has = function()
	local active_instance = nil

	for _, instance in pairs(M.queue) do
		if not active_instance and instance.is_ready then
			active_instance = instance
		end
	end

	if not active_instance then
		return false
	end

	return true
end

return M
