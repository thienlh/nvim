return {
  "nvim-neotest/neotest",
  dependencies = {
    "zidhuss/neotest-minitest", -- Just add your Ruby adapter
  },
  opts = function(_, opts)
    -- Add minitest to the existing adapters
    table.insert(opts.adapters, require("neotest-minitest"))
  end,
}
