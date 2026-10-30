-- InaRogue › the tabs of the INAROGUE «Tienda» (content/rogue/shop_tabs.toml): one per shop of the mode, in order.
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_INAROGUE_RL_SHOP_TAB | -1 / i (0-based) | count / ok, id, text id (crc32 of its text row), retail tab icon type |

local U = require "lib/rogue/util"
local info, warn = U.logger("rogue")

local KIND = "InaRogue.shop_tabs/1"
local FILE = "content/rogue/shop_tabs.toml"
local MAX_TABS = 9          -- the retail tab bar's instances (cmn06_20_list_tab_item)

local T = {}
local tabs = nil

local function read()
  local list = {}
  local ok, doc = pcall(VRFW.files.toml, FILE)
  if not ok or type(doc) ~= "table" then
    warn(FILE .. " not readable (" .. tostring(doc) .. "): no shop tabs")
    return list
  end
  if doc.schema ~= KIND then
    warn(FILE .. ": schema is not " .. KIND .. " (no shop tabs)")
    return list
  end
  for k, e in ipairs(type(doc.tab) == "table" and doc.tab or {}) do
    local where = string.format("%s [[tab]] #%d", FILE, k)
    if type(e.id) ~= "string" or e.id == "" then
      warn(where .. ": no id (skipped)")
    elseif type(e.icon) ~= "number" or e.icon < 0 then
      warn(where .. " (" .. e.id .. "): icon must be a retail tab icon type (skipped)")
    elseif #list >= MAX_TABS then
      warn(where .. " (" .. e.id .. "): more than " .. MAX_TABS .. " tabs (skipped)")
    else
      local text = type(e.text) == "string" and e.text ~= "" and U.crc32(e.text) or 0
      list[#list + 1] = { id = e.id, text = text, icon = math.floor(e.icon) }
    end
  end
  info("shop tabs: " .. #list .. " from " .. FILE)
  return list
end

function T.Tab(i)
  tabs = tabs or read()
  if type(i) ~= "number" or i < 0 then
    return #tabs
  end
  local t = tabs[math.floor(i) + 1]
  if t == nil then
    return false
  end
  return true, t.id, t.text, t.icon
end

return T
