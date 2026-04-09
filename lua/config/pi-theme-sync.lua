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

-- Get unique nvim instance ID from process ID with tmp- prefix
local cachedNvimId = nil

local function getNvimId()
  if cachedNvimId then
    return cachedNvimId
  end

  -- Use nvim's process ID with tmp- prefix
  cachedNvimId = "tmp-" .. tostring(vim.fn.getpid())
  return cachedNvimId
end

-- Cleanup old tmp themes: remove oldest tmp-* files if more than 10 total themes exist
local function cleanupOldTmpThemes()
  local piThemesDir = vim.fn.expand("~/.pi/agent/themes")

  -- Get all files in themes directory
  local all_files = vim.fn.glob(piThemesDir .. "/*.json", false, true)
  if #all_files <= 10 then
    return -- No cleanup needed
  end

  -- Collect tmp-* files with their modification times
  local tmp_files = {}
  for _, filepath in ipairs(all_files) do
    local filename = vim.fn.fnamemodify(filepath, ":t")
    if filename:match("^tmp%-") then
      local mtime = vim.fn.getftime(filepath)
      table.insert(tmp_files, { path = filepath, mtime = mtime })
    end
  end

  -- Sort by modification time (oldest first)
  table.sort(tmp_files, function(a, b)
    return a.mtime < b.mtime
  end)

  -- Remove oldest tmp files, keep only the 5 most recent
  local to_remove = #tmp_files - 5
  for i = 1, to_remove do
    vim.fn.delete(tmp_files[i].path)
  end
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

  -- Get theme ID for naming
  local theme_id = getNvimId()

  -- Build theme JSON
  local theme = {
    ["$schema"] = "https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
    name = theme_id, -- Name matches filename: tmp-<pid>
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
  local outputPath = themesDir .. "/" .. getNvimId() .. ".json"
  --]]
  local outputPath = piThemesDir .. "/" .. getNvimId() .. ".json"
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

-- Command to open pi in terminal with correct theme
vim.api.nvim_create_user_command("Pi", function()
  local nvim_id = getNvimId()
  local theme_name = nvim_id -- Theme name matches PID (e.g., "85346")
  local theme_path = vim.fn.expand("~/.pi/agent/themes/" .. nvim_id .. ".json")
  local settings_path = vim.fn.expand("~/.pi/agent/settings.json")

  -- Check if theme file exists, export if not
  if vim.fn.filereadable(theme_path) == 0 then
    M.exportPiTheme()
  end

  -- Update settings.json to use this theme (for hot reload to work)
  local settings = {}
  local file = io.open(settings_path, "r")
  if file then
    local content = file:read("*a")
    file:close()
    local ok, decoded = pcall(vim.json.decode, content)
    if ok then
      settings = decoded
    end
  end
  settings.theme = theme_name
  -- Write back
  file = io.open(settings_path, "w")
  if file then
    file:write(vim.json.encode(settings))
    file:close()
  end

  -- Open terminal in right split with pi (skip default themes to avoid scanning all files)
  vim.cmd("botright vsplit | terminal pi --no-themes --theme " .. vim.fn.shellescape(theme_path))
  vim.cmd("startinsert")

  -- Cleanup old tmp themes after pi is loaded (deferred to not block)
  vim.defer_fn(cleanupOldTmpThemes, 1000)
end, { desc = "Open pi in terminal with current nvim theme" })

return M
