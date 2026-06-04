require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
map("n","<leader>fs",require("telescope.builtin").lsp_document_symbols,{desc="telescope symbols"})

map("n","<leader>tm", function ()
  if vim.o.mouse=="a" then
    vim.opt.mouse = ""
  else
    vim.opt.mouse = "a"
  end
end, {desc="toogle mouse"})
