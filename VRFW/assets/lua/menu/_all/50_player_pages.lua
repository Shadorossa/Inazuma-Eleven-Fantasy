-- menu_engine: the player page's page registry, VRFW.PlayerPages (VR-Framework base feature). Definitions only (this file runs in every script VM, lua\_all): the screens that
-- page the player plate call VRFW_PlayerPages.Attach() from their handler file (lua\<stem>\120_player_pages.lua).
--
-- The player plate (personal_plate_menu, «Ficha») shows one page per page INDEX (the parents' / the plate's page
-- counter: GetNowPageIdx); GetPersonalPlatePageType turns the index into the plate's page TYPE. Retail: 4 pages,
-- index 0..3 = type 1 (moves + radar), 0 (equipment), 2 (team passives), 3 (sixth sense), Q/E +-1 wrapping at 4.
-- Mods only DECLARE their pages; the framework owns the order, the Q/E step, the index -> type map and the dots' data:
--   VRFW_PlayerPages.Add({Name = "<mod>.<Page>", Index = <n>, Type = <t>,
--                         First = true | Last = true | After = "<name>" | Before = "<name>",
--                         Enabled = function() return <bool> end})        -- optional, asked at run time
--   VRFW_PlayerPages.ShowWhen("<page name>", function() return <bool> end) -- an extra condition on any page, retail
--                                                                           -- pages included, asked at run time
-- Names of the retail pages: vrfw.Moves (0), vrfw.Equipment (1), vrfw.TeamPassives (2), vrfw.SixthSense (3).
-- Declarations happen while the mods' chunks load (pure Lua, any order); the order is resolved LAZILY at the first
-- use (a page step, a dot), when every mod of the VM has declared, so nothing depends on the load order. Placement:
-- every First page in front (by name), then each After / Before page next to its anchor (repeated until no page
-- moves, by name within one pass), pages with an unknown anchor after the rest (logged), every Last page at the end
-- (by name). An index declared twice keeps the first declaration (logged).
-- No engine call at load time.
if VRFW_PlayerPages == nil then
  local P = {
    LOG = 3661580131,            -- CMND_EVT_LOG
    SND = 1917805374,            -- CMND_SND_PLAY_SE (the retail page step sound)
    SE_STEP = 2629173176,        -- sy0009
    ANIME = 3781155141,          -- CMND_PLAY_ANIME_TYPE
    L_STATUS = 730911947,        -- soccer11_05_formation_status_base
    ANIM_NEXT = 3183130249,      -- the retail page-step animations of the status base
    ANIM_PREV = 1203080170,
    ANIM_GROUP = 3627544126,
    K_LEFT = 2053629800,
    K_RIGHT = 3033167124,
    RETAIL = {
      {Name = "vrfw.Moves", Index = 0, Type = 1},
      {Name = "vrfw.Equipment", Index = 1, Type = 0},
      {Name = "vrfw.TeamPassives", Index = 2, Type = 2},
      {Name = "vrfw.SixthSense", Index = 3, Type = 3},
    },
    decls = {},                  -- name -> declaration
    conditions = {},             -- page name -> {function, ...}: the ShowWhen conditions of that page
    list = nil,                 -- resolved order (declarations), nil = resolve at the next use
    byIndex = nil,
    wrapped = {},
  }
  VRFW_PlayerPages = P

  function P.Log(...)
    pcall(funcLuaCommand, P.LOG, "vrfw.PlayerPages", ...)
  end

  -- a mod's page (see the header); a second Add with the same Name replaces the first
  function P.Add(d)
    if type(d) ~= "table" or type(d.Name) ~= "string" or type(d.Index) ~= "number" or type(d.Type) ~= "number" then
      return false
    end
    P.decls[d.Name] = d
    P.list = nil
    return true
  end

  -- an extra condition on a page of any mod or a retail page: the page is shown only while every condition of it
  -- (and its own Enabled) answers true; while one says no the page also loses its dot slot (no gap); a condition
  -- that errors counts as true
  function P.ShowWhen(name, fn)
    if type(name) ~= "string" or type(fn) ~= "function" then
      return false
    end
    local list = P.conditions[name] or {}
    list[#list + 1] = fn
    P.conditions[name] = list
    return true
  end

  function P.Resolve()
    if P.list ~= nil then
      return P.list
    end
    local list, byIndex = {}, {}
    for _, r in ipairs(P.RETAIL) do
      list[#list + 1] = r
    end
    local pend, last = {}, {}
    for _, d in pairs(P.decls) do
      if d.Last then
        last[#last + 1] = d
      else
        pend[#pend + 1] = d
      end
    end
    local byName = function(a, b) return a.Name < b.Name end
    table.sort(pend, byName)
    table.sort(last, byName)
    local function pos(name)
      for i, e in ipairs(list) do
        if e.Name == name then
          return i
        end
      end
      return nil
    end
    local firsts = 0
    local moved = true
    while moved and #pend > 0 do
      moved = false
      local rest = {}
      for _, d in ipairs(pend) do
        local a, b = d.After ~= nil and pos(d.After) or nil, d.Before ~= nil and pos(d.Before) or nil
        if d.First then
          firsts = firsts + 1
          table.insert(list, firsts, d)
          moved = true
        elseif a ~= nil then
          table.insert(list, a + 1, d)
          moved = true
        elseif b ~= nil then
          table.insert(list, b, d)
          moved = true
        else
          rest[#rest + 1] = d
        end
      end
      pend = rest
    end
    for _, d in ipairs(pend) do
      P.Log("page " .. d.Name .. ": anchor " .. tostring(d.After or d.Before) .. " not declared: placed at the end")
      list[#list + 1] = d
    end
    for _, d in ipairs(last) do
      list[#list + 1] = d
    end
    local out = {}
    for _, d in ipairs(list) do
      if byIndex[d.Index] == nil then
        byIndex[d.Index] = d
        out[#out + 1] = d
      else
        P.Log("page " .. d.Name .. ": index " .. d.Index .. " already taken by " .. byIndex[d.Index].Name .. ": left out")
      end
    end
    P.list, P.byIndex = out, byIndex
    return out
  end

  -- a ShowWhen condition of the page says no: the page is left out of the order (no step, no dot slot)
  function P.Removed(d)
    for _, fn in ipairs(P.conditions[d.Name] or {}) do
      local ok, v = pcall(fn)
      if ok and v == false then
        return true
      end
    end
    return false
  end

  function P.On(d)
    if type(d.Enabled) == "function" then
      local ok, v = pcall(d.Enabled)
      if ok and v == false then
        return false
      end
    end
    return not P.Removed(d)
  end

  -- the shown pages' indices in order; `count` = only indices below it (a screen whose page table has `count` rows)
  function P.Order(count)
    local o = {}
    for _, d in ipairs(P.Resolve()) do
      if (count == nil or d.Index < count) and P.On(d) then
        o[#o + 1] = d.Index
      end
    end
    return o
  end

  -- page index -> page type (nil = no such page)
  function P.Type(index)
    P.Resolve()
    local d = P.byIndex[index]
    return d ~= nil and d.Type or nil
  end

  -- dots: {[slot] = index} of the shown pages, slot = the page's place in the order (a page whose Enabled says no
  -- keeps its slot empty; a page a ShowWhen condition removes has no slot); SlotOfType(type) = the slot of the page
  -- of that type
  function P.Slots()
    local m, slot = {}, 0
    for _, d in ipairs(P.Resolve()) do
      if not P.Removed(d) then
        slot = slot + 1
        if P.On(d) then
          m[slot] = d.Index
        end
      end
    end
    return m
  end
  function P.SlotOfType(t)
    local slot = 0
    for _, d in ipairs(P.Resolve()) do
      if not P.Removed(d) then
        slot = slot + 1
        if d.Type == t then
          return slot
        end
      end
    end
    return nil
  end

  -- a pointer click: the next Step answers `index` once (nil = clear)
  function P.Goto(index)
    P.target = index
  end

  -- the page after `cur` in direction dir (+1 E / -1 Q), wrapping; `count` as in Order
  function P.Step(cur, dir, count)
    local o = P.Order(count)
    local t = P.target
    P.target = nil
    if type(t) == "number" then
      for _, v in ipairs(o) do
        if v == t then
          return t
        end
      end
    end
    if #o == 0 then
      return cur or 0
    end
    local k = 0
    for i, v in ipairs(o) do
      if v == cur then
        k = i
      end
    end
    if k == 0 then
      k = dir < 0 and #o or 1
    else
      k = k + dir
    end
    if k > #o then
      k = 1
    elseif k < 1 then
      k = #o
    end
    return o[k]
  end

  local function Wrap(name, make)
    local cur = _ENV[name]
    if type(cur) ~= "function" or P.wrapped[cur] then
      return false
    end
    local w = make(cur)
    P.wrapped[w] = true
    _ENV[name] = w
    return true
  end

  -- The screens that page the plate (team dock / formation parents and the plate itself, soccer_formation_menu_inc):
  -- the index -> type map, Q/E (their left / right handler) and the plate's own next / previous page step through
  -- the registry. Wrapped once per VM, over whatever the patches before made of these functions.
  function P.Attach()
    Wrap("GetPersonalPlatePageType", function(orig)
      return function(a1, ...)
        local t = type(a1) == "number" and a1 > 3 and P.Type(a1) or nil
        if t ~= nil then
          return t
        end
        return orig(a1, ...)
      end
    end)
    -- The retail left / right handler adds +-1 to the index and wraps it into 0..3 before calling ChangePageInfo; the
    -- registry's page goes to ChangePageInfo through P.force. Every retail guard (member change mode, detail window,
    -- plate hidden, ...) still runs first: when one refuses, ChangePageInfo is not called.
    Wrap("ChangePageInfo", function(orig)
      return function(a1, ...)
        if P.force ~= nil then
          a1 = P.force
          P.force = nil
        end
        return orig(a1, ...)
      end
    end)
    Wrap("OnFunctionCommonLeftAndRight", function(orig)
      return function(a1, a2, a3, ...)
        if a1 ~= P.K_LEFT and a1 ~= P.K_RIGHT then
          return orig(a1, a2, a3, ...)
        end
        local cur = a3
        if type(cur) ~= "number" then
          cur = type(GetNowPageIdx) == "function" and GetNowPageIdx() or 0
        end
        P.force = P.Step(cur, a1 == P.K_RIGHT and 1 or -1)
        local inrange = cur
        if inrange < 0 or inrange > 3 then
          inrange = 0
        end
        local ok, r = pcall(orig, a1, a2, inrange, ...)
        P.force = nil
        if not ok then
          error(r, 0)
        end
        return r
      end
    end)
    -- the plate's own next / previous page (retail: +-1 over 0..3), with the retail guards, sound and animation
    local function Shift(dir)
      if type(IsChangeMemberMode) == "function" and IsChangeMemberMode() then
        return
      end
      if type(IsShownDetailInfo) == "function" and IsShownDetailInfo() then
        return
      end
      funcLuaCommand(P.SND, P.SE_STEP)
      local nxt = P.Step(GetNowPageIdx(), dir)
      ChangePersonalPlatePageByCharaHdl(GetTargetCharacterStatusHandle(), GetPersonalPlatePageType(nxt))
      SetNowPageIdx(nxt)
      funcLuaMenuCommand(P.ANIME, P.L_STATUS, 0, dir > 0 and P.ANIM_NEXT or P.ANIM_PREV, 0, P.ANIM_GROUP)
    end
    if type(ChangePersonalPlatePageByCharaHdl) == "function" and type(SetNowPageIdx) == "function" then
      Wrap("SetPersonalPlateNextPage", function(orig)
        return function()
          return Shift(1)
        end
      end)
      Wrap("SetPersonalPlatePrevPage", function(orig)
        return function()
          return Shift(-1)
        end
      end)
    end
  end
end
