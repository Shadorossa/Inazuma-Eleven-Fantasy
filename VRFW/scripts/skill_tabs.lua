-- VR-Framework › skill tab registry (service S3 of VRFW 2.3, docs/framework/card-types.md §3). Declarations: every
-- active mod's content\skill_tabs\*.toml (`VRFW.skill_tab/1`, keys and compare units: content\types\skill_tab.toml);
-- native side: content\game\skill_tabs.toml (the tab table stub, the tab count, the team aura list stub, commands).
--
--   * Off (no mod declares a tab or an aura list row, or none whose `when` holds): nothing is written, the move list
--     keeps the game's tabs, the team aura screen the game's rows.
--   * Tabs: the game's own table (read from its code: the `lea` of the fixed-tab branch, the count immediate) with
--     order 10, 20, … in table order; a declaration changes a game tab (`order`, `group`, `hidden`) or adds a category.
--     The native list = the tabs not hidden, by order (ties: the game's order, then declaration order). The stub's
--     table is that list (padded with zeros up to the game's table size); the count immediate is a window
--     `start << 8 | count`: CMND_VRFW_SKILL_TAB_WINDOW(group) narrows it to the tabs of one group (a picker sets it
--     before it opens, "" puts the whole list back). A group's tabs must follow each other (else its first run).
--   * Team aura list: the declared aura types and skills (`[[VRFW.AuraListHide]]`, every mod's, in load order, once
--     each) are left out of the rows; the game's own test (no record = no row) stays first.
--   * CMND_VRFW_SKILL_TABS() -> n, categories; CMND_VRFW_SKILL_TAB_WINDOW([group]) -> start, count;
--     CMND_VRFW_SKILL_TAB_HAS(category) -> bool.

SkillTabs = SkillTabs or {}


local D = require "lib/declarations"

local function info(...) VRFW.log("skill_tabs:", ...) end
local function warn(...) VRFW.warn("skill_tabs:", ...) end

local TAB_ON = false      -- the native list is the registry's
local GAME = nil          -- the game's tabs (categories in table order), read on demand
local LIST = {}           -- the native list's categories (TAB_ON)
local HAS = {}            -- category -> true (TAB_ON)
local GROUPS = {}         -- group name -> { start, count }
local GROUP_ORDER = {}    -- group names in list order (CMND_VRFW_SKILL_TAB_WINDOW(k) = the k-th)
local WIN = { 0, 0 }      -- the window in force: start, count

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local function apply(name, arg)
  local ok, r = pcall(VRFW.patch.apply, name, arg)
  if not ok then
    warn(name .. ": " .. tostring(r))
    return false
  end
  return r == true
end

-- the game's tab table: the fixed-tab branch's `lea rdi, [rip + disp32]` (profile site Technique.SkillTabsTable) and
-- the count immediate (Technique.SkillTabsCount); nil, why when another mod changed them or the build has no such site
local function game_tabs()
  if GAME then return GAME end
  local ok1, lea = pcall(VRFW.game.sym, "Technique.SkillTabsTable")
  local ok2, cnt = pcall(VRFW.game.sym, "Technique.SkillTabsCount")
  if not (ok1 and ok2 and lea and cnt) then return nil, "the tab sites are not on this build" end
  local b0, b1, b2 = rd("u8", lea), rd("u8", lea + 1), rd("u8", lea + 2)
  if not (b0 == 0x48 and b1 == 0x8D and b2 == 0x3D) then
    return nil, "the tab table's `lea` is not the game's (another mod changed it)"
  end
  local disp = rd("i32", lea + 3)
  local n = rd("u32", cnt)
  if not disp or not n or n == 0 or n > 255 then return nil, "the tab count is not readable" end
  local at = lea + 7 + disp
  local t = {}
  for i = 0, n - 1 do
    local c = rd("u8", at + i)
    if not c then return nil, "the tab table is not readable" end
    t[#t + 1] = c
  end
  GAME = t
  return t
end

-- ---------------------------------------------------------------------------------------------- declarations

local function load_decls()
  local schema, why = D.schema("skill_tab")
  if not schema then
    warn(why .. ": the skill tab service stays off")
    return nil
  end
  local decls, skipped = D.load(schema, warn)
  local tabs, hides = {}, {}
  for _, d in ipairs(decls) do
    if d.entry == "SkillTab" then tabs[#tabs + 1] = d else hides[#hides + 1] = d end
  end
  return { schema = schema, tabs = tabs, hides = hides, skipped = skipped }
end

-- ---------------------------------------------------------------------------------------------- tabs

local function build_list(game, tabs)
  local by_cat, seq = {}, {}
  for i, c in ipairs(game) do
    if not by_cat[c] then
      by_cat[c] = { category = c, order = 10 * i, base = i, game = true }
      seq[#seq + 1] = by_cat[c]
    end
  end
  local last = 10 * #game
  for k, d in ipairs(tabs) do
    local c = d.v.category
    local t = by_cat[c]
    if not t then
      last = last + 10
      t = { category = c, order = last, base = #game + k, game = false }
      by_cat[c] = t
      seq[#seq + 1] = t
    end
    for key in pairs(d.given) do
      if key == "order" or key == "group" or key == "hidden" then t[key] = d.v[key] end
    end
    t.from = d.where
  end
  local list = {}
  for _, t in ipairs(seq) do
    if not t.hidden then list[#list + 1] = t end
  end
  table.sort(list, function(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.base < b.base
  end)
  return list
end

local function write_window(start, count)
  if not apply("SkillTabs.Count", string.format("%02X %02X 00 00", count, start)) then
    return false
  end
  WIN = { start, count }
  return true
end

local function start_tabs(d)
  if #d.tabs == 0 then return "no tab declarations" end
  local game, why = game_tabs()
  if not game then
    warn(why .. ": the move list keeps the game's tabs")
    return "off (" .. why .. ")"
  end
  local list = build_list(game, d.tabs)
  if #list == 0 then
    warn("every tab is hidden: the move list keeps the game's tabs")
    return "off (every tab hidden)"
  end
  if #list > 255 then
    warn(string.format("%d tabs: at most 255; the move list keeps the game's tabs", #list))
    return "off (too many tabs)"
  end
  local same = #list == #game
  for i, t in ipairs(list) do
    if t.category ~= game[i] then same = false end
  end
  -- groups: contiguous runs of the list (a group split by another tab keeps its first run)
  local groups, order = {}, {}
  for i, t in ipairs(list) do
    local g = t.group
    if g then
      local w = groups[g]
      if not w then
        groups[g] = { i - 1, 1, last = i }
        order[#order + 1] = g
      elseif not w.split and w.last == i - 1 then
        w[2], w.last = w[2] + 1, i
      else
        w.split = true
        warn(string.format("group %q: tab %d is not next to the group's other tabs: the window keeps its first run", g, t.category))
      end
    end
  end
  GROUPS, GROUP_ORDER = groups, order
  if same and #order == 0 then
    return "declarations change nothing: the game's tabs"
  end
  -- the stub's table: the list, zero-padded to the game's table size
  local bytes = {}
  for _, t in ipairs(list) do bytes[#bytes + 1] = t.category end
  while #bytes < #game do bytes[#bytes + 1] = 0 end
  if not apply("SkillTabs.Table", { append = bytes }) then
    VRFW.error("skill_tabs: the tab table stub was not written (see the patch line above): the move list keeps the game's tabs")
    return "off (stub not written)"
  end
  if not write_window(0, #list) then
    VRFW.error("skill_tabs: the tab count was not written (see the patch line above): the list reads the game's count over the new table")
    return "table only (count not written)"
  end
  TAB_ON = true
  LIST, HAS = {}, {}
  for _, t in ipairs(list) do
    LIST[#LIST + 1] = t.category
    HAS[t.category] = true
  end
  local gs = {}
  for _, g in ipairs(order) do gs[#gs + 1] = string.format("%s %d+%d", g, groups[g][1], groups[g][2]) end
  return string.format("%d tab(s): %s (game: %s)%s", #LIST, table.concat(LIST, " "), table.concat(game, " "),
    #gs > 0 and ("; groups " .. table.concat(gs, ", ")) or "")
end

-- ---------------------------------------------------------------------------------------------- team aura list

local function start_aura_list(d)
  if #d.hides == 0 then return "no aura list declarations" end
  local units = d.schema.code or {}
  local ut, us = units.aura_type, units.skill
  if type(ut) ~= "table" or type(us) ~= "table" then
    warn("content/types/skill_tab.toml: [code.aura_type] / [code.skill] missing: the team aura list keeps the game's rows")
    return "off (no code units)"
  end
  local types, skills, seen_t, seen_s = {}, {}, {}, {}
  for _, h in ipairs(d.hides) do
    for _, t in ipairs(h.v.aura_types or {}) do
      if not seen_t[t] then seen_t[t] = true; types[#types + 1] = t end
    end
    for _, s in ipairs(h.v.skills or {}) do
      if not seen_s[s] then seen_s[s] = true; skills[#skills + 1] = s end
    end
  end
  if #types + #skills == 0 then return "aura list declarations hide nothing" end
  -- the stub's declared code (the game's own test) and its `je`, then one unit per value
  local head = units.head
  if type(head) ~= "table" or type(head.length) ~= "number" or type(head.jump) ~= "number" then
    warn("content/types/skill_tab.toml: [code.head] missing: the team aura list keeps the game's rows")
    return "off (no code head)"
  end
  local head_len = head.length
  local append, refs, imm = {}, { { at = head.jump, branch = head.branch } }, {}
  local function unit(u, v)
    local at = head_len + #append
    for b in tostring(u.bytes):gmatch("%S+") do append[#append + 1] = b end
    imm[#imm + 1] = { at = at + u.value, width = u.width, value = v }
    refs[#refs + 1] = { at = at + u.jump, branch = u.branch }
  end
  for _, t in ipairs(types) do unit(ut, t) end
  for _, s in ipairs(skills) do unit(us, s) end
  if not apply("SkillTabs.AuraList", { append = table.concat(append, " "), refs = refs, imm = imm }) then
    VRFW.error("skill_tabs: the team aura list stub was not written (see the patch line above): the screen keeps the game's rows")
    return "off (stub not written)"
  end
  local ts, ss = {}, {}
  for _, t in ipairs(types) do ts[#ts + 1] = tostring(t) end
  for _, s in ipairs(skills) do ss[#ss + 1] = string.format("0x%04X%04X", math.floor(s / 65536), s % 65536) end
  return string.format("team aura list leaves out aura types %s and %d skill(s) %s", #ts > 0 and table.concat(ts, " ") or "none",
    #ss, table.concat(ss, " "))
end

-- ---------------------------------------------------------------------------------------------- commands

-- () -> n, category 1 … category n (0: the service is off, the game's own tabs)
function SkillTabs.CmdTabs()
  if not TAB_ON then return 0 end
  return #LIST, table.unpack(LIST)
end

-- ([group]) -> start, count of the window in force; group: a name, "" / 0 = the whole list, k = the k-th group
function SkillTabs.CmdWindow(group)
  if not TAB_ON then
    local g = game_tabs()
    return 0, g and #g or 0
  end
  if group ~= nil then
    local w
    if group == "" or group == 0 then
      w = { 0, #LIST }
    elseif type(group) == "number" then
      local name = GROUP_ORDER[group]
      w = name and GROUPS[name] or nil
    else
      w = GROUPS[tostring(group)]
    end
    if not w then
      warn("CMND_VRFW_SKILL_TAB_WINDOW: no group " .. tostring(group) .. ": the whole list")
      w = { 0, #LIST }
    end
    if w[1] ~= WIN[1] or w[2] ~= WIN[2] then
      if not write_window(w[1], w[2]) then
        VRFW.error("skill_tabs: tab window " .. tostring(group) .. " not written (see the patch line above)")
      end
    end
  end
  return WIN[1], WIN[2]
end

-- (category) -> the native list has that tab
function SkillTabs.CmdHas(category)
  local c = tonumber(category)
  if not c then return false end
  if TAB_ON then return HAS[c] == true end
  local g = game_tabs()
  for _, x in ipairs(g or {}) do
    if x == c then return true end
  end
  return false
end

-- ---------------------------------------------------------------------------------------------- start

local function start()
  local d = load_decls()
  if not d then return end
  if #d.tabs == 0 and #d.hides == 0 then
    if (d.skipped or 0) > 0 then
      info(string.format("off: %d declaration(s), none whose `when` holds: the game's tabs and team aura rows", d.skipped))
    else
      info("off: no mod declares a skill tab or a team aura row: the game's tabs and rows")
    end
    return
  end
  local a = start_tabs(d)
  local b = start_aura_list(d)
  info(string.format("on (%d left out by `when`): tabs: %s; %s", d.skipped or 0, a, b))
end

start()
