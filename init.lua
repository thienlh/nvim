-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.env.PATH = vim.env.HOME .. "/.rbenv/shims:" .. vim.env.PATH
