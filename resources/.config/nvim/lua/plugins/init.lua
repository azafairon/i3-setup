local is_neovide = vim.g.neovide or false
return {
  {
    "stevearc/conform.nvim",
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = require "configs.treesitter",
    init = function(plugin)
      vim.opt.rtp:append(plugin.dir .. "/runtime")
    end,
  },

}
