-- Sync Neovim colorscheme to pi theme
-- This automatically exports your current nvim colors to pi's theme system

local M = {}

-- 256 color cube values (6x6x6)
local CUBE_VALUES = { 0, 95, 135, 175, 215, 255 }

-- Convert 256-color index to hex
local function ansi256ToHex(index)
  if index < 16 then
    -- Standard colors (approximate)
    local basic = {
      "#000000",
      "#800000",
      "#008000",
      "#808000",
      "#000080",
      "#800080",
      "#008080",
      "#c0c0c0",
      "#808080",
      "#ff0000",
      "#00ff00",
      "#ffff00",
      "#0000ff",
      "#ff00ff",
      "#00ffff",
      "#ffffff",
    }
    return basic[index + 1] or "#808080"
  elseif index < 232 then
    -- Color cube (16-231)
    local cubeIndex = index - 16
    local r = math.floor(cubeIndex / 36)
    local g = math.floor((cubeIndex % 36) / 6)
    local b = cubeIndex % 6
    local toHex = function(n)
      if n == 0 then
        return "00"
      end
      return string.format("%02x", 55 + n * 40)
    end
    return "#" .. toHex(r) .. toHex(g) .. toHex(b)
  else
    -- Grayscale (232-255)
    local gray = 8 + (index - 232) * 10
    return string.format("#%02x%02x%02x", gray, gray, gray)
  end
end

-- Get color from highlight group, handling both gui and cterm
local function getHighlightColor(group, attr)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })

  -- Try GUI color first (hex)
  if attr == "fg" and hl.fg then
    return string.format("#%06x", hl.fg)
  elseif attr == "bg" and hl.bg then
    return string.format("#%06x", hl.bg)
  end

  -- Fall back to cterm color (convert to hex)
  if attr == "fg" and hl.ctermfg then
    return ansi256ToHex(hl.ctermfg)
  elseif attr == "bg" and hl.ctermbg then
    return ansi256ToHex(hl.ctermbg)
  end

  return nil
end

-- Safely get color with fallback chain
local function getColorWithFallback(groups, attr, fallback)
  for _, group in ipairs(groups) do
    local color = getHighlightColor(group, attr)
    if color then
      return color
    end
  end
  return fallback
end

-- Export current colorscheme to pi theme
function M.exportPiTheme()
  -- Ensure pi config directory exists (pi looks in ~/.pi/agent/themes/)
  local piThemesDir = vim.fn.expand("~/.pi/agent/themes")
  vim.fn.mkdir(piThemesDir, "p")

  -- Map nvim highlight groups to pi theme colors
  -- Priority: specific groups -> treesitter groups -> standard groups
  local colors = {
    -- Syntax highlighting (most important for code)
    syntaxComment = getColorWithFallback({ "Comment", "@comment", "SpecialComment" }, "fg", "#6A9955"),
    syntaxKeyword = getColorWithFallback(
      { "Keyword", "@keyword", "Statement", "Conditional", "Repeat", "Label" },
      "fg",
      "#569CD6"
    ),
    syntaxFunction = getColorWithFallback({ "Function", "@function", "@method", "@function.call" }, "fg", "#DCDCAA"),
    syntaxVariable = getColorWithFallback({ "Identifier", "@variable", "@identifier" }, "fg", "#9CDCFE"),
    syntaxString = getColorWithFallback({ "String", "@string", "@string.documentation", "Character" }, "fg", "#CE9178"),
    syntaxNumber = getColorWithFallback({ "Number", "@number", "@float", "Boolean" }, "fg", "#B5CEA8"),
    syntaxType = getColorWithFallback({ "Type", "@type", "@type.builtin", "Structure", "Typedef" }, "fg", "#4EC9B0"),
    syntaxOperator = getColorWithFallback({ "Operator", "@operator" }, "fg", "#D4D4D4"),
    syntaxPunctuation = getColorWithFallback(
      { "Delimiter", "@punctuation", "@punctuation.bracket", "@punctuation.delimiter" },
      "fg",
      "#D4D4D4"
    ),

    -- UI colors (derive from nvim's UI)
    accent = getColorWithFallback({ "DiagnosticInfo", "@constant" }, "fg", "#8abeb7"),
    border = getColorWithFallback({ "FloatBorder", "WinSeparator", "VertSplit" }, "fg", "#5f87ff"),
    borderAccent = getColorWithFallback({ "Title", "@text.title" }, "fg", "#00d7ff"),
    borderMuted = getColorWithFallback({ "NonText", "Conceal", "Ignore" }, "fg", "#505050"),
    success = getColorWithFallback({ "DiagnosticOk", "@text.note", "DiffAdd" }, "fg", "#b5bd68"),
    error = getColorWithFallback({ "Error", "DiagnosticError", "DiffDelete" }, "fg", "#cc6666"),
    warning = getColorWithFallback({ "Warning", "DiagnosticWarn", "Todo" }, "fg", "#ffff00"),
    muted = getColorWithFallback({ "Comment", "@comment" }, "fg", "#808080"),
    dim = getColorWithFallback({ "LineNr", "CursorLineNr" }, "fg", "#666666"),
    text = "", -- Empty = terminal default
    thinkingText = getColorWithFallback({ "Comment" }, "fg", "#808080"),

    -- Background colors (use existing or derive)
    selectedBg = getColorWithFallback({ "CursorLine", "Visual", "PmenuSel" }, "bg", "#3a3a4a"),
    userMessageBg = getColorWithFallback({ "NormalFloat", "Pmenu", "Normal" }, "bg", "#343541"),
    userMessageText = "",
    customMessageBg = getColorWithFallback({ "NormalFloat", "Pmenu" }, "bg", "#2d2838"),
    customMessageText = "",
    customMessageLabel = getColorWithFallback({ "Special", "@constant.builtin" }, "fg", "#9575cd"),
    toolPendingBg = getColorWithFallback({ "StatusLineNC", "LineNr" }, "bg", "#282832"),
    toolSuccessBg = getColorWithFallback({ "DiffAdd" }, "bg", "#283228"),
    toolErrorBg = getColorWithFallback({ "DiffDelete" }, "bg", "#3c2828"),
    toolTitle = "",
    toolOutput = getColorWithFallback({ "Comment" }, "fg", "#808080"),

    -- Markdown colors
    mdHeading = getColorWithFallback({ "Title", "@text.title", "markdownH1" }, "fg", "#f0c674"),
    mdLink = getColorWithFallback({ "Underlined", "@text.uri", "markdownLinkText" }, "fg", "#81a2be"),
    mdLinkUrl = getColorWithFallback({ "Comment" }, "fg", "#666666"),
    mdCode = getColorWithFallback({ "@text.literal", "markdownCode" }, "fg", "#8abeb7"),
    mdCodeBlock = getColorWithFallback({ "@text.literal", "markdownCodeBlock" }, "fg", "#b5bd68"),
    mdCodeBlockBorder = getColorWithFallback({ "Comment" }, "fg", "#808080"),
    mdQuote = getColorWithFallback({ "Comment", "@text.quote" }, "fg", "#808080"),
    mdQuoteBorder = getColorWithFallback({ "Comment" }, "fg", "#808080"),
    mdHr = getColorWithFallback({ "Comment" }, "fg", "#808080"),
    mdListBullet = getColorWithFallback({ "Special", "markdownListMarker" }, "fg", "#8abeb7"),

    -- Diff colors
    toolDiffAdded = getColorWithFallback({ "DiffAdd", "@diff.plus" }, "fg", "#b5bd68"),
    toolDiffRemoved = getColorWithFallback({ "DiffDelete", "@diff.minus" }, "fg", "#cc6666"),
    toolDiffContext = getColorWithFallback({ "Comment" }, "fg", "#808080"),

    -- Thinking level borders
    thinkingOff = getColorWithFallback({ "NonText" }, "fg", "#505050"),
    thinkingMinimal = getColorWithFallback({ "Comment" }, "fg", "#6e6e6e"),
    thinkingLow = getColorWithFallback({ "DiagnosticInfo" }, "fg", "#5f87af"),
    thinkingMedium = getColorWithFallback({ "DiagnosticHint" }, "fg", "#81a2be"),
    thinkingHigh = getColorWithFallback({ "DiagnosticWarn" }, "fg", "#b294bb"),
    thinkingXhigh = getColorWithFallback({ "DiagnosticError" }, "fg", "#d183e8"),

    -- Bash mode
    bashMode = getColorWithFallback({ "String", "@string" }, "fg", "#b5bd68"),
  }

  -- Build theme JSON
  local theme = {
    ["$schema"] = "https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
    name = "nvim-sync",
    colors = colors,
    export = {
      pageBg = getColorWithFallback({ "Normal" }, "bg", "#18181e"),
      cardBg = getColorWithFallback({ "NormalFloat", "Normal" }, "bg", "#1e1e24"),
      infoBg = getColorWithFallback({ "Pmenu", "NormalFloat" }, "bg", "#3c3728"),
    },
  }

  -- Write to file (reverted to ~/.pi/agent/themes/)
  --[[ Change for cwd export - commented out:
  local themesDir = vim.fn.getcwd() .. "/.pi/themes"
  vim.fn.mkdir(themesDir, "p")
  local outputPath = themesDir .. "/nvim-sync.json"
  --]]
  local outputPath = piThemesDir .. "/nvim-sync.json"
  -- vim.fn.mkdir(piThemesDir, "p") -- Ensure directory exists
  local json = vim.json.encode(theme)
  -- Fix Lua's empty table encoding: vars must be an object {}, not array []
  -- Since we don't use vars, the encoded JSON won't have it, which is fine
  -- Pretty print JSON
  json = json:gsub("([{,])", "%1\n  "):gsub("}", "\n}")

  local file = io.open(outputPath, "w")
  if file then
    file:write(json)
    file:close()
    -- vim.notify("Pi theme exported: " .. outputPath, vim.log.levels.INFO)
  else
    vim.notify("Failed to write pi theme to " .. outputPath, vim.log.levels.ERROR)
  end
end

-- Set up autocmd to regenerate theme on colorscheme change
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("PiThemeSync", { clear = true }),
  callback = function()
    -- Small delay to ensure highlights are fully applied
    vim.defer_fn(M.exportPiTheme, 100)
  end,
  desc = "Export colorscheme to pi theme",
})

-- Initial export on startup (after UI is ready)
vim.defer_fn(M.exportPiTheme, 500)

-- Command to manually trigger export
vim.api.nvim_create_user_command("PiThemeExport", M.exportPiTheme, {
  desc = "Export current nvim colorscheme to pi theme",
})

return M
