local nio = require("nio")
--- Rereads the current buffer value and reloads the buffer
---@return nil
return function(buf)
	nio.api.nvim_buf_set_option(buf, "autoread", true)
	nio.api.nvim_cmd({ cmd = "edit" }, {})
end
