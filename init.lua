-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
require("config.pi-theme-sync")
vim.env.PATH = vim.env.HOME .. "/.local/share/mise/shims:" .. vim.env.PATH
