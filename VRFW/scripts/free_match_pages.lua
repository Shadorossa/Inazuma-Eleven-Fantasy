-- Paged free-match tabs (content/free_match_pages/*.toml, schema VRFW.free_match_page/1) and the slots of the section
-- bar's later pages (docs/framework/team-sections.md); native hook FreeMatch.SetTab is installed only when a mod declares
-- a paged tab or a later section page is shown.
--   * Page k of a tab lists the rows of tab index `pages[k]`; every title return resets to page 1.
--   * CMND_VRFW_FM_PAGE(tab, delta) -> page (1-based), pages, live
--   * CMND_VRFW_FM_SECTION_SLOTS(index of slot 0, index of slot 1, ...) -> live: the tab index each bar slot lists
--     while a later section page is shown; no argument = page 1 (every slot lists its own index).

FreeMatchPages = FreeMatchPages or {}

local D = require "lib/declarations"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("free_match_pages")

local T_PAGE = "VRFW.FreeMatch.Page"
local KEY_RESETS = "vrfw.game_resets"

local TABS = {}          -- bar tab index -> { key, mod, pages = { tab index … } }
local PAGE = {}          -- bar tab index -> current page (0-based)
local SLOTS = nil        -- bar slot (0-based) -> tab index, while a later section page is shown
local LIVE = false
local hook_tried = false
local seen_epoch = nil

local function epoch()
  local ok, e = pcall(VRFW.state.get, KEY_RESETS)
  if ok and type(e) == "number" then return e end
  return nil
end

-- after a title return every tab goes back to page 1
local function check_reset()
  local e = epoch()
  if e ~= seen_epoch then
    if seen_epoch ~= nil then
      PAGE = {}
      SLOTS = nil
    end
    seen_epoch = e
  end
  return e
end

-- the tab index a tab lists on its current page
local function paged(tab)
  local t = TABS[tab]
  if not t then return tab end
  return t.pages[(PAGE[tab] or 0) + 1] or tab
end

-- native answer: bar slot -> the tab index it lists (nothing when it lists its own)
local function publish()
  pcall(VRFW.native.table_clear, T_PAGE)
  local e = check_reset()
  if not e then return end
  if SLOTS then
    for slot, index in pairs(SLOTS) do
      local built = paged(index)
      if built ~= slot then pcall(VRFW.native.table_set, T_PAGE, { e, slot }, built) end
    end
    return
  end
  for tab in pairs(TABS) do
    local built = paged(tab)
    if built ~= tab then pcall(VRFW.native.table_set, T_PAGE, { e, tab }, built) end
  end
end

-- the detour, installed once on first need
local function ensure_hook(why)
  if LIVE or hook_tried then return LIVE end
  hook_tried = true
  local ok, done, e = pcall(VRFW.hook.apply, "FreeMatch.SetTab")
  LIVE = ok and done == true
  if not LIVE then
    warn(string.format("detour FreeMatch.SetTab not installed (%s): %s", tostring(ok and e or done), why))
  end
  return LIVE
end

local function start()
  local schema, why = D.schema("free_match_page")
  if not schema then
    warn(why .. ": every free-match tab is one page")
    return
  end
  local decls, skipped = D.load(schema, warn)
  for _, d in ipairs(decls) do
    local v = d.v
    if #v.pages < 2 then
      warn(string.format("%s: pages = %d tab index(es): a paged tab needs at least 2: left out", d.where, #v.pages))
    else
      if TABS[v.tab] then
        warn(string.format("tab %d: %s replaces %s (one declaration per tab; later mod wins)", v.tab, d.key, TABS[v.tab].key))
      end
      TABS[v.tab] = { key = d.key, mod = d.mod, pages = v.pages }
    end
  end
  local parts = {}
  for tab, t in pairs(TABS) do
    local p = {}
    for _, x in ipairs(t.pages) do p[#p + 1] = tostring(x) end
    parts[#parts + 1] = string.format("tab %d = %s (%s)", tab, table.concat(p, " / "), t.key)
  end
  table.sort(parts)
  if #parts == 0 then
    if #decls > 0 or (skipped or 0) > 0 then
      info(string.format("off: %d declaration(s) (%d left out by `when`), none in force: one page per tab", #decls, skipped or 0))
    else
      info("off: no mod declares a paged free-match tab: one page per tab")
    end
    return
  end
  if ensure_hook("one page per tab (" .. table.concat(parts, ", ") .. ")") then
    publish()
    info(string.format("on: %s", table.concat(parts, ", ")))
  end
end

-- CMND_VRFW_FM_PAGE(tab, delta) -> page (1-based), pages, live
function FreeMatchPages.Cmd(tab, delta)
  tab = math.floor(tonumber(tab) or -1)
  delta = math.floor(tonumber(delta) or 0)
  check_reset()
  local t = TABS[tab]
  if not t then return 1, 1, LIVE end
  local n = #t.pages
  local old = PAGE[tab] or 0
  local p = old
  if delta ~= 0 then
    if math.abs(delta) > n then p = 0 else p = (old + delta) % n end
  end
  PAGE[tab] = p
  if p ~= old then info(string.format("tab %d: page %d -> %d (tab index %d)", tab, old + 1, p + 1, t.pages[p + 1])) end
  publish()
  return p + 1, n, LIVE
end

-- CMND_VRFW_FM_SECTION_SLOTS(index of slot 0, ...) -> live
function FreeMatchPages.Sections(...)
  local n = select("#", ...)
  local slots, moved = nil, false
  if n > 0 then
    slots = {}
    for k = 1, n do
      local index = math.floor(tonumber((select(k, ...))) or (k - 1))
      slots[k - 1] = index
      if index ~= k - 1 then moved = true end
    end
  end
  check_reset()
  local was = SLOTS ~= nil
  SLOTS = moved and slots or nil
  if SLOTS and not ensure_hook("the section bar keeps page 1") then
    SLOTS = nil
  end
  if (SLOTS ~= nil) ~= was or SLOTS then
    local list = {}
    for k = 0, n - 1 do list[#list + 1] = tostring(slots and slots[k] or k) end
    info(SLOTS and ("section slots: " .. table.concat(list, " ")) or "section slots: page 1")
  end
  publish()
  return LIVE
end

start()
