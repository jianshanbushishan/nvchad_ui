dofile(vim.g.base46_cache .. "nvcheatsheet")

local nvcheatsheet = vim.api.nvim_create_namespace("nvcheatsheet")
local mappings_tb = require("nvchad_ui").cheatsheet.mappings

vim.api.nvim_create_autocmd("BufWinLeave", {
  callback = function()
    if vim.bo.ft == "nvcheatsheet" then
      vim.g.nvcheatsheet_displayed = false
    end
  end,
})

-- cheatsheet header!
local ascii = {
  "                                      ",
  "                                      ",
  "                                      ",
  "█▀▀ █░█ █▀▀ ▄▀█ ▀█▀ █▀ █░█ █▀▀ █▀▀ ▀█▀",
  "█▄▄ █▀█ ██▄ █▀█ ░█░ ▄█ █▀█ ██▄ ██▄ ░█░",
  "                                      ",
  "                                      ",
  "                                      ",
}

-- basically the draw function
return function()
  local buf = vim.api.nvim_create_buf(false, true)

  -- add left padding (strs) to ascii so it looks centered
  local ascii_header = vim.tbl_values(ascii)

  local win = require("nvchad_ui.cheatsheet").getLargestWin()
  vim.api.nvim_set_current_win(win)

  local ascii_padding = (vim.api.nvim_win_get_width(win) / 2) - (#ascii_header[1] / 2)

  for i, str in ipairs(ascii_header) do
    ascii_header[i] = string.rep(" ", ascii_padding) .. str
  end

  -- set ascii
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, ascii_header)

  -- convert "<leader>th" to "<leader> + th"
  local function prettify_Str(str)
    local one, two = str:match("([^,]+)>([^,]+)")
    return one and one .. "> + " .. two or str
  end

  -- column width
  local column_width = 0

  for _, mappings in pairs(mappings_tb) do
    local keys = {}
    for k in pairs(mappings) do
      table.insert(keys, k)
    end
    table.sort(keys)

    for _, keybind in ipairs(keys) do
      local desc = mappings[keybind]
      column_width = column_width > vim.fn.strdisplaywidth(desc .. prettify_Str(keybind)) and column_width
        or vim.fn.strdisplaywidth(desc .. prettify_Str(keybind))
    end
  end

  -- 10 = space between mapping txt , 4 = 2 & 2 space around mapping txt
  column_width = column_width + 10 + 4

  local win_width = vim.api.nvim_win_get_width(win) - vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff - 4
  local columns_qty = math.floor(win_width / column_width)

  column_width = math.floor((win_width - (column_width * columns_qty)) / columns_qty) + column_width

  -- add mapping tables with their headings as key names
  local cards = {}
  local card_headings = {}

  for plugin, mappings in pairs(mappings_tb) do
    local card_name = plugin
    local padding_left = math.floor((column_width - vim.fn.strdisplaywidth(card_name)) / 2)

    -- center the heading
    card_name = string.rep(" ", padding_left)
      .. card_name
      .. string.rep(" ", column_width - vim.fn.strdisplaywidth(card_name) - padding_left)

    card_headings[#card_headings + 1] = card_name

    cards[card_name] = {}
    cards[card_name][#cards[card_name] + 1] = string.rep(" ", column_width)

    local keys = {}
    for k in pairs(mappings) do
      table.insert(keys, k)
    end
    table.sort(keys)

    for _, keybind in ipairs(keys) do
      local desc = mappings[keybind]
      local whitespace_len = column_width - 4 - vim.fn.strdisplaywidth(prettify_Str(keybind) .. desc)
      local pretty_mapping = desc .. string.rep(" ", whitespace_len) .. prettify_Str(keybind)

      cards[card_name][#cards[card_name] + 1] = "  " .. pretty_mapping .. "  "
      cards[card_name][#cards[card_name] + 1] = string.rep(" ", column_width)
    end

    cards[card_name][#cards[card_name] + 1] = string.rep(" ", column_width)
  end

  -- divide cheatsheet layout into columns
  local columns = {}

  for i = 1, columns_qty, 1 do
    columns[i] = {}
  end

  local function getColumn_height(tb)
    local res = 0

    for _, value in pairs(tb) do
      res = res + #value + 1
    end

    return res
  end

  local function append_table(tb1, tb2)
    for _, val in ipairs(tb2) do
      tb1[#tb1 + 1] = val
    end
  end

  local cards_headings_sorted = vim.tbl_keys(cards)

  table.sort(cards_headings_sorted, function(first, second)
    return first:gsub("%s*", "") < second:gsub("%s*", "")
  end)

  -- imitate masonry layout
  for _, heading in pairs(cards_headings_sorted) do
    for column, mappings in ipairs(columns) do
      if column == 1 and getColumn_height(columns[1]) == 0 then
        columns[1][1] = cards_headings_sorted[1]
        append_table(columns[1], cards[cards_headings_sorted[1]])
        break
      elseif column == 1 and getColumn_height(mappings) < getColumn_height(columns[#columns]) then
        columns[column][#columns[column] + 1] = heading
        append_table(columns[column], cards[heading])
        break
      elseif column == 1 and getColumn_height(mappings) == getColumn_height(columns[#columns]) then
        columns[column][#columns[column] + 1] = heading
        append_table(columns[column], cards[heading])
        break
      elseif column ~= 1 and (getColumn_height(columns[column - 1]) > getColumn_height(mappings)) then
        if not vim.tbl_contains(columns[1], heading) then
          columns[column][#columns[column] + 1] = heading
          append_table(columns[column], cards[heading])
        end
        break
      end
    end
  end

  local longest_column = 0

  for _, value in ipairs(columns) do
    longest_column = longest_column > #value and longest_column or #value
  end

  local max_col_height = 0

  -- get max_col_height
  for _, value in ipairs(columns) do
    max_col_height = max_col_height < #value and #value or max_col_height
  end

  -- fill empty lines with whitespaces
  -- so all columns will have the same height
  for i, _ in ipairs(columns) do
    for _ = 1, max_col_height - #columns[i], 1 do
      columns[i][#columns[i] + 1] = string.rep(" ", column_width)
    end
  end

  local result = vim.tbl_values(columns[1])

  -- merge all the column strings
  for index, value in ipairs(result) do
    local line = value

    for col_index = 2, #columns, 1 do
      line = line .. "  " .. columns[col_index][index]
    end

    result[index] = line
  end

  vim.api.nvim_buf_set_lines(buf, #ascii_header, -1, false, result)

  -- list all hl groups that start with NvChHead
  -- thanks to @max397574 for teaching me
  local highlights_raw = vim.split(vim.api.nvim_exec("filter " .. "NvChHead" .. " hi", true), "\n")
  local highlight_groups = {}

  for _, raw_hi in ipairs(highlights_raw) do
    table.insert(highlight_groups, string.match(raw_hi, "NvChHead" .. "%S+"))
  end

  -- add highlight to the columns
  for i = 0, max_col_height, 1 do
    for column_i, _ in ipairs(columns) do
      local col_start = column_i == 1 and 0 or (column_i - 1) * column_width + ((column_i - 1) * 2)
      -- local col_end = column_i == 1 and column_width or col_start + column_width

      if columns[column_i][i] then
        -- highlight headings & one line after it
        if vim.tbl_contains(card_headings, columns[column_i][i]) then
          local lines = vim.api.nvim_buf_get_lines(buf, i + #ascii_header - 1, i + #ascii_header + 1, false)

          -- highlight area around card heading
          vim.api.nvim_buf_add_highlight(
            buf,
            nvcheatsheet,
            "NvChSection",
            i + #ascii_header - 1,
            vim.fn.byteidx(lines[1], col_start),
            vim.fn.byteidx(lines[1], col_start)
              + column_width
              + vim.fn.strlen(columns[column_i][i])
              - vim.fn.strdisplaywidth(columns[column_i][i])
          )
          -- highlight card heading & randomize hl groups for colorful colors
          vim.api.nvim_buf_add_highlight(
            buf,
            nvcheatsheet,
            highlight_groups[math.random(1, #highlight_groups)],
            i + #ascii_header - 1,
            vim.fn.stridx(lines[1], vim.trim(columns[column_i][i]), col_start) - 1,
            vim.fn.stridx(lines[1], vim.trim(columns[column_i][i]), col_start)
              + vim.fn.strlen(vim.trim(columns[column_i][i]))
              + 1
          )
          vim.api.nvim_buf_add_highlight(
            buf,
            nvcheatsheet,
            "NvChSection",
            i + #ascii_header,
            vim.fn.byteidx(lines[2], col_start),
            vim.fn.byteidx(lines[2], col_start) + column_width
          )

          -- highlight mappings & one line after it
        elseif string.match(columns[column_i][i], "%s+") ~= columns[column_i][i] then
          local lines = vim.api.nvim_buf_get_lines(buf, i + #ascii_header - 1, i + #ascii_header + 1, false)
          vim.api.nvim_buf_add_highlight(
            buf,
            nvcheatsheet,
            "NvChSection",
            i + #ascii_header - 1,
            vim.fn.stridx(lines[1], columns[column_i][i], col_start),
            vim.fn.stridx(lines[1], columns[column_i][i], col_start) + vim.fn.strlen(columns[column_i][i])
          )
          vim.api.nvim_buf_add_highlight(
            buf,
            nvcheatsheet,
            "NvChSection",
            i + #ascii_header,
            vim.fn.byteidx(lines[2], col_start),
            vim.fn.byteidx(lines[2], col_start) + column_width
          )
        end
      end
    end
  end

  -- set highlights for  ascii header
  for i = 0, #ascii_header - 1, 1 do
    vim.api.nvim_buf_add_highlight(buf, nvcheatsheet, "NvChAsciiHeader", i, 0, -1)
  end

  vim.api.nvim_set_current_buf(buf)

  -- buf only options
  vim.opt_local.buflisted = false
  vim.opt_local.modifiable = false
  vim.opt_local.buftype = "nofile"
  vim.opt_local.filetype = "nvcheatsheet"
  vim.opt_local.number = false
  vim.opt_local.list = false
  vim.opt_local.wrap = false
  vim.opt_local.relativenumber = false
  vim.opt_local.cul = false
  vim.g.nvcheatsheet_displayed = true

  vim.keymap.set("n", "<ESC>", function()
    require("nvchad_ui.tabufline").close_buffer(buf)
  end, { buffer = buf }) -- use ESC to close
end
