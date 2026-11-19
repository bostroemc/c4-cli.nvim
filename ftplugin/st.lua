if vim.b.loaded_c4_cli_nvim_st then
	return
end
vim.b.loaded_c4_cli_nvim_st = true

vim.keymap.set("n", "<leader>k", function()
	require("c4_cli").open()
end, { desc = "Open CODESYS 4 c4-cli Menu" })

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or "")
	.. "\n unlet! b:loaded_c4_cli_nvim_st"
	.. "\n lua require('c4_cli').detach(vim.api.nvim_get_current_buf())"
