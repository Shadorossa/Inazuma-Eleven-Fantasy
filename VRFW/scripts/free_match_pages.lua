-- Paged free-match tabs (content/free_match_pages/*.toml, schema VRFW.free_match_page/1); native hook FreeMatch.SetTab is installed only when a mod declares a paged tab.
--   * Page k of a tab lists the rows of tab index `pages[k]`; every title return resets to page 1.
--   * CMND_VRFW_FM_PAGE(tab, delta) -> page (1-based), pages, live

FreeMatchPages = FreeMatchPages or {}

local D = require "lib/declarations"

local function info(...) VRFW.log("free_match_pages:", ...) end
local function warn(...) VRFW.warn("free_match_pages:", ...) end

local T_PAGE = "VRFW.FreeMatch.Page"
local KEY_RESETS = "vrfw.game_resets"

local TABS = {}          -- bar tab index -> { key, mod, pages = { tab index … } }
local PAGE = {}          -- bar tab index -> current page (0-based)
local LIVE = false
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
    if seen_epoch ~= nil then PAGE = {} end
    seen_epoch = e
  end
  return e
end

-- native answer: bar tab -> tab index of its current page (nothing for page 1)
local function publish()
  pcall(VRFW.native.table_clear, T_PAGE)
  local e = check_reset()
  if not e then return end
  for tab, t in pairs(TABS) do
    local p = PAGE[tab] or 0
    local built = t.pages[p + 1]
    if built and built ~= tab then pcall(VRFW.native.table_set, T_PAGE, { e, tab }, built) end
  end
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
  local ok, done, e = pcall(VRFW.hook.apply, "FreeMatch.SetTab")
  LIVE = ok and done == true
  if LIVE then
    publish()
    info(string.format("on: %s", table.concat(parts, ", ")))
  else
    warn(string.format("detour FreeMatch.SetTab not installed (%s): one page per tab (%s)", tostring(ok and e or done), table.concat(parts, ", ")))
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

start()
