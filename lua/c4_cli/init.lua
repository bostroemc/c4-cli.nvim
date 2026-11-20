local M = {}

function M.setup(opts) end

local function find_fbslib(root_dir)
	local matches = vim.fs.find(function(name)
		return name:match("%.fbslib$") ~= nil
	end, {
		path = root_dir or vim.fn.getcwd(),
		type = "directory",
		limit = 1,
	})
	return matches[1]
end

local lib_path = find_fbslib()
if not lib_path then
	vim.notify("No .fbslib directory found", vim.log.levels.ERROR)
	-- return
end
-- vim.notify(lib_path)

-- c4-cli menu/shortcuts   See https://content.helpme-codesys.com/en/CODESYS%204/_c4_commandline_c4_cli_library.html
local actions = {
	{ key = "c", desc = "Bootapp: Compile", cmd = "c4-cli bootapp compile" },
	{ key = "s", desc = "Library: Save Compiled", cmd = "c4-cli library save-compiled . ./build/ --overwrite -v" },
	{
		key = "S",
		desc = "Library: Save Compiled with documentation",
		cmd = "c4-cli library save-compiled . ./build/ --include-libdoc ./doc.lmd --overwrite -v",
	},
	-- { key = "p", desc = "Library: Pack Source", cmd = "c4-cli library pack " .. lib_path .. " ./build " },
	{ key = "p", desc = "Library: Pack Source", cmd = "c4-cli library pack . ../build/ " },
	-- { key = "r", desc = "Dependencies: Restore", cmd = "c4-cli library restore" },
	{
		key = "i",
		desc = "Dependencies: Install",
		cmd = "c4-cli librepo install C:\\Users\\cpbos\\AppData\\Local\\CODESYS-4\\managed-libraries --all ./build/ --overwrite",
	},
	-- { key = "k", desc = "Dependencies: Check", cmd = "c4-cli library check" },
	-- { key = "x", desc = "Controller: Reset", cmd = "c4-cli reset" },
	{ key = "l", desc = "Library: List references", cmd = "c4-cli library list" },
	{ key = "v", desc = "Version", cmd = "c4-cli version --verbose " },
	{ key = "a", desc = "About", cmd = "c4-cli about --verbose --help " },
}

local function resolve_codesys_file(raw_path)
	local direct_path = vim.trim(raw_path):gsub("%^", "")
	if vim.fn.filereadable(direct_path) == 1 then
		return direct_path
	end

	local root_dir, rel_part = raw_path:match("^(.-)%^\\?(.*)$")
	if root_dir and rel_part then
		-- Strip the '.iecapp' (or similar container) folder name from the root
		local project_dir = vim.fn.fnamemodify(vim.trim(root_dir), ":h")
		local candidate = project_dir .. "\\" .. rel_part
		if vim.fn.filereadable(candidate) == 1 then
			return candidate
		end

		local filename = vim.fn.fnamemodify(rel_part, ":t")
		local matches = vim.fn.globpath(project_dir, "**/" .. filename, false, true)
		if #matches > 0 then
			return matches[1]
		end
	end

	return nil
end

local function parse(lines)
	local qf_items = {}

	for _, line in ipairs(lines) do
		local clean_line = line:gsub("\27%[[0-9;]*m", "")
		local msg, file, lnum, col = clean_line:match("^(.-)%s+([A-Za-z]:\\.-)%s+%((%d+),%s*(%d+),%s*length:%s*%d+%)")

		if msg and file and lnum then
			local real_path = resolve_codesys_file(file)

			if real_path then
				local clean_msg = vim.trim(msg):gsub("^Error:%s*", "")
				table.insert(qf_items, {
					filename = real_path,
					lnum = tonumber(lnum),
					col = tonumber(col) or 1,
					text = clean_msg,
					type = "E",
				})
			else
				vim.notify("CODESYS Jump: Could not find file on disk for " .. file, vim.log.levels.WARN)
			end
		end
	end

	vim.fn.setqflist({}, "r", {
		title = "CODESYS 4 Build",
		items = qf_items,
	})

	if #qf_items > 0 then
		if vim.bo.buftype == "terminal" then
			vim.cmd("wincmd p")
		end
		vim.cmd("copen")
		vim.cmd("cc 1")
	end
end

-- local function close_existing_c4_term()
-- 	-- 1. Close the Quickfix window and empty the old error list
-- 	vim.cmd("cclose")
-- 	vim.fn.setqflist({}, "r")
--
-- 	-- 2. Wipe any existing CODESYS terminal buffer
-- 	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
-- 		if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].is_c4_term then
-- 			vim.api.nvim_buf_delete(buf, { force = true })
-- 		end
-- 	end
-- end

local function close_existing_c4_term()
	-- 1. Close the Quickfix window and free the entire Quickfix stack
	vim.cmd("cclose")
	vim.fn.setqflist({}, "f")

	-- 2. Wipe both the CODESYS terminal buffer and the Quickfix buffer
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) then
			local is_c4 = vim.b[buf].is_c4_term
			local is_qf = vim.bo[buf].buftype == "quickfix"

			if is_c4 or is_qf then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
	end
end

local function run_c4_command(cmd)
	close_existing_c4_term()

	vim.cmd("botright 12new")
	local temp_buf = vim.api.nvim_get_current_buf()
	-- vim.g.c4_term_buf = term_buf
	vim.bo[temp_buf].bufhidden = "wipe"

	vim.fn.jobstart(cmd, {
		term = true,
		on_exit = function(_, _, _)
			if vim.api.nvim_buf_is_valid(temp_buf) then
				local lines = vim.api.nvim_buf_get_lines(temp_buf, 0, -1, false)
				parse(lines)
			end
		end,
	})
	temp_buf = vim.api.nvim_get_current_buf()
	vim.b[temp_buf].is_c4_term = true

	-- Scroll to the bottom as output streams in, while keeping your cursor in the code window
	vim.cmd("normal! G")
	vim.cmd("wincmd p")
end

function M.open()
	local temp_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[temp_buf].buftype = "nofile"
	vim.bo[temp_buf].bufhidden = "wipe"
	vim.bo[temp_buf].swapfile = false
	vim.bo[temp_buf].filetype = "c4-menu"

	local lines = { " CODESYS 4 Actions ", "" }
	local max_width = #lines[1]

	for _, item in ipairs(actions) do
		local line = string.format("  [%s]  %s", item.key, item.desc)
		table.insert(lines, line)
		if #line > max_width then
			max_width = #line
		end
	end
	table.insert(lines, "")
	table.insert(lines, "  [q/Esc] Close")

	vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, lines)
	vim.bo[temp_buf].modifiable = false

	-- 3. Configure and open the floating window
	local width = max_width + 4
	local height = #lines
	local win = vim.api.nvim_open_win(temp_buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " c4-cli ",
		title_pos = "center",
	})

	local opts = { buffer = temp_buf, silent = true, nowait = true }
	for _, item in ipairs(actions) do
		vim.keymap.set("n", item.key, function()
			vim.api.nvim_win_close(win, true)
			run_c4_command(item.cmd)
		end, opts)
	end

	-- Map close keys
	local close_fn = function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	vim.keymap.set("n", "q", close_fn, opts)
	vim.keymap.set("n", "<Esc>", close_fn, opts)
end

-- local function handle_c4_output(output_lines)
-- 	local qf_items = {}
--
-- 	for _, line in ipairs(output_lines) do
-- 		-- Adjust this Lua pattern to match your exact c4-cli compiler output
-- 		-- Example match: "src/PLC_PRG.st(14,5): Error C0046: Identifier 'x' not defined"
-- 		local file, lnum, col, err_type, msg = line:match("^(.-)%((%d+),(%d+)%):%s*(%a+)%s*(.+)$")
--
-- 		if file and lnum then
-- 			table.insert(qf_items, {
-- 				filename = file,
-- 				lnum = tonumber(lnum),
-- 				col = tonumber(col) or 1,
-- 				text = msg,
-- 				type = (err_type == "Error" or err_type == "FatalError") and "E" or "W",
-- 			})
-- 		end
-- 	end
--
-- 	-- Populate the quickfix list and jump to the first error
-- 	vim.fn.setqflist({}, "r", {
-- 		title = "CODESYS 4 Build",
-- 		items = qf_items,
-- 	})
--
-- 	if #qf_items > 0 then
-- 		vim.cmd("copen") -- Opens the quickfix window
-- 		vim.cmd("cc 1") -- Jumps immediately to the first error buffer & line
-- 	end
-- end

-- local function compile_codesys()
-- 	-- Replace arguments with your specific c4-cli bootapp/library compile flags
-- 	vim.system({ "c4-cli", "bootapp", "compile" }, { text = true }, function(obj)
-- 		local raw = (obj.stdout or "") .. "\n" .. (obj.stderr or "")
-- 		local lines = vim.split(raw, "\n", { trimempty = true })
--
-- 		vim.schedule(function()
-- 			handle_c4_output(lines)
-- 		end)
-- 	end)
-- end

-- TEST CODE BELOW --------------------------------------------------------------------------

local function has_active_buffers()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].c4_cli_state then
			return true
		end
	end
	return false
end

function M.FS()
	local temp = has_active_buffers()

	pcall(vim.keymap.del, "n", "<leader>k")
	vim.print("Delete c4-cli keymap ", temp)
end

local group = vim.api.nvim_create_augroup("ReopenBufferKeymaps", { clear = true })

vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
	group = group,
	pattern = "*.st", -- change to your file pattern or specific buffer name
	callback = function(args)
		vim.keymap.set("n", "<leader>k", function()
			require("c4_cli").open()
		end, { desc = "Open CODESYS 4 c4-cli Menu" })
	end,
})

vim.api.nvim_create_autocmd("BufWinLeave", {
	pattern = "*.st", -- or a specific buffer/file pattern
	callback = function(ev)
		pcall(vim.keymap.del, "n", "<leader>k")
	end,
})

-- function M.attach(bufnr)
-- 	-- 1. Store buffer-local state (automatically destroyed when buffer wipes out)
-- 	vim.b[bufnr].c4_cli_state = {
-- 		attached = true,
-- 	}
--
-- 	-- 2. Buffer-local keymap (require 'menu' INSIDE callback for on-demand loading)
-- 	vim.keymap.set("n", "<leader>m", function()
-- 		require("your_plugin.menu").toggle()
-- 	end, {
-- 		buffer = bufnr,
-- 		silent = true,
-- 		desc = "Toggle ST Plugin Menu",
-- 	})
--
-- 	-- 3. Buffer-local user command
-- 	vim.api.nvim_buf_create_user_command(bufnr, "StMenu", function()
-- 		require("your_plugin.menu").toggle()
-- 	end, { desc = "Toggle ST Plugin Menu" })
--
-- 	-- 4. Buffer-local cleanup hook when this buffer unloads/wipes out
-- 	local group = vim.api.nvim_create_augroup("YourPluginBuf_" .. bufnr, { clear = true })
-- 	vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
-- 		group = group,
-- 		buffer = bufnr,
-- 		callback = function()
-- 			M.detach(bufnr)
-- 		end,
-- 	})
-- end
--
-- function M.detach(bufnr)
-- 	if vim.api.nvim_buf_is_valid(bufnr) then
-- 		vim.b[bufnr].c4_cli_state = nil
-- 		pcall(vim.keymap.del, "n", "<leader>k", { buffer = bufnr })
-- 		pcall(vim.api.nvim_buf_del_user_command, bufnr, "c4-menu")
-- 	end
--
-- 	-- Wait one tick so Neovim finishes removing the closing buffer from the list
-- 	vim.schedule(function()
-- 		if not has_active_buffers() then
-- 			-- Only load/call menu cleanup if the menu module was actually loaded
-- 			if package.loaded["c4_cli"] then
-- 				-- require("c4_cli").close()
-- 			end
-- 		end
-- 	end)
-- end

return M
