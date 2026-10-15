-- menu_engine: the character bank filter header (VR-Framework base feature).
-- Definitions only (this file runs in every script VM, lua\_all): the bank screens' handler files
-- (lua\<stem>\100_card_filter.lua) call VRFW_CardFilter.Attach(stem). Nothing here names a rarity, a series or a mod:
-- the values, their names, the screens, the keys' OnFunction call and the header's offset come from the framework
-- (type card_filter, CMND_VRFW_CARD_FILTER_*), the texts from the framework's text rows (menu_text, 9 languages).
--
-- The header = a 2nd instance of the screen's own retail filter plate (layer team14_02_filter_guide, count 2 in the
-- framework's menus\card_filter.toml), moved by `offset` from instance 0, its text «Q ‹ value › E» (text row
-- vrfw_card_filter_header: the key glyphs are its markup). The keys (pad L2 / R2, keyboard Q / E) arrive as the
-- screen's OnFunction(function, prev | next) declared per screen; the header takes them only while the personal plate
-- is closed. A new value: CMND_VRFW_CARD_FILTER_NEXT, then the screen's own OnListTabChanged rebuilds the list (the
-- framework's post-filter on CharaBankFilter keeps the cards of the value). Step pings ALIVE: the value applies only
-- while a bank screen runs; a ping after a pause (a sub-screen) rebuilds the list once. FinalizeMenu -> LEAVE: the
-- last bank screen closing resets the value to «All» at once (the bank list is a shared engine list: the team dock
-- reads its count right after, and a value left behind showed as ~3000 players missing, beta report).
-- The keys are taken only when the retail script would use them (its select mode local, `idle_local` of the
-- [[screen]], is 0), and while a value is chosen the list counter shows «shown / total» like the retail filter.
-- No engine call at load time.
if VRFW_CardFilter == nil then
  local CF = {
    CMD_ENTER = 3161407831,   -- CMND_VRFW_CARD_FILTER_ENTER(stem) -> on, value, dx, dy, function, prev, next
    CMD_NEXT = 469318363,     -- CMND_VRFW_CARD_FILTER_NEXT(dir) -> value
    CMD_LABEL = 196661713,    -- CMND_VRFW_CARD_FILTER_LABEL(i) -> name, kind, series id, tier
    CMD_ALIVE = 354737002,    -- CMND_VRFW_CARD_FILTER_ALIVE() -> rebuild?
    CMD_LEAVE = 2662269417,   -- CMND_VRFW_CARD_FILTER_LEAVE(stem) -> bank screens still open
    CMD_GET = 4052920195,     -- CMND_VRFW_CARD_FILTER_GET() -> value chosen
    TX_ALL = 3288464882,      -- text row vrfw_card_filter_all («Todas»)
    TX_HEADER = 2923353700,   -- text row vrfw_card_filter_header («<L2> ‹ %s › <R2>»)
    TX_TIER = 2410722143,     -- text row vrfw_card_filter_tier («%d★ %s»)
    TEXT_GET = 4074371074,    -- CMND_TEXT_GET
    SERIES_INFO = 964991930,  -- CMND_GET_CHARA_SERIES_INFO(1, id) -> ok, name
    LAYER = 1199683335,       -- team14_02_filter_guide (instance 1 = the header)
    NODE = 3538663351,        -- _text_filter01
    IDX = 1,
    SET_TEXT = 1083631230,
    TEXT_PLATE = 1172899594,
    VISIBLE = 711242136,
    OPEN = 629267548,
    IS_OPEN = 2640875187,
    GET_POS = 2834507455,     -- CMND_GET_LAYER_LOCAL_POS(layer, idx) -> x, y
    SET_POS = 1389957207,     -- CMND_SET_LAYER_LOCAL_POS(layer, x, y, z, idx)
    SE_MOVE = 2500047763,     -- sy0005
    S = {},                   -- per stem: {on, value, dx, dy, fn, prev, next, idle, plate, shown}
  }
  VRFW_CardFilter = CF

  local function call(f, ...)
    local r = table.pack(pcall(f, ...))
    if not r[1] then
      return nil
    end
    return table.unpack(r, 2, r.n)
  end

  local function text(id, fallback)
    local s = call(funcLuaCommand, CF.TEXT_GET, id)
    if type(s) == "string" and s ~= "" then
      return s
    end
    return fallback
  end

  -- the value's name: «All», a rarity / family name, a series' own name text; a tier gets its stars
  function CF.Name(i)
    local name, kind, sid, tier = call(funcLuaCommand, CF.CMD_LABEL, i)
    if kind == nil or kind == "all" or i == 0 then
      return text(CF.TX_ALL, "Todas")
    end
    if (name == nil or name == "") and kind == "series" then
      local ok, nm = call(funcLuaMenuCommand, CF.SERIES_INFO, 1, sid)
      if ok and type(nm) == "string" then
        name = nm
      end
    end
    name = tostring(name or "")
    if type(tier) == "number" and tier > 0 then
      local f = text(CF.TX_TIER, "%d* %s")
      local ok, s = pcall(string.format, f, tier, name)
      if ok then
        name = s
      end
    end
    return name
  end

  -- the plate is open: the retail flag (host locals) when readable, else the tracked state
  function CF.PlateOpen(stem)
    local h = VRFW_Host ~= nil and VRFW_Host.hosts ~= nil and VRFW_Host.hosts[stem] or nil
    if h ~= nil and h.L ~= nil then
      local ok, v = pcall(function() return h.L.flag end)
      if ok and type(v) == "boolean" then
        return v
      end
    end
    return CF.S[stem] ~= nil and CF.S[stem].plate == true
  end

  -- the retail script would use the keys now: its select mode local (host map name from the [[screen]]) is 0;
  -- no local declared / unreadable = idle
  function CF.Idle(stem)
    local S = CF.S[stem]
    if S == nil or S.idle == nil or S.idle == "" then
      return true
    end
    local h = VRFW_Host ~= nil and VRFW_Host.hosts ~= nil and VRFW_Host.hosts[stem] or nil
    if h == nil or h.L == nil then
      return true
    end
    local ok, v = pcall(function() return h.L[S.idle] end)
    return not ok or type(v) ~= "number" or v == 0
  end

  function CF.Draw(stem)
    local S = CF.S[stem]
    if S == nil then
      return
    end
    local L, k = CF.LAYER, CF.IDX
    if not S.on or S.shown == false then
      call(funcLuaMenuCommand, CF.VISIBLE, L, k, false)
      return
    end
    if not call(funcLuaMenuCommand, CF.IS_OPEN, L, k) then
      call(funcLuaMenuCommand, CF.OPEN, L, k)
    end
    local x, y = call(funcLuaMenuCommand, CF.GET_POS, L, 0)
    if type(x) == "number" and type(y) == "number" then
      call(funcLuaMenuCommand, CF.SET_POS, L, x + S.dx, y + S.dy, 0, k)
    end
    local f = text(CF.TX_HEADER, "<CMD_FUNCL2> < %s > <CMD_FUNCR2>")
    local ok, s = pcall(string.format, f, CF.Name(S.value))
    call(funcLuaMenuCommand, CF.SET_TEXT, L, CF.NODE, ok and s or CF.Name(S.value), k)
    call(funcLuaMenuCommand, CF.TEXT_PLATE, L, k, CF.NODE)
    call(funcLuaMenuCommand, CF.VISIBLE, L, k, true)
  end

  function CF.Enter(stem)
    local on, v, dx, dy, fn, prev, nxt, idle = call(funcLuaCommand, CF.CMD_ENTER, stem)
    CF.S[stem] = {
      on = on == true, value = tonumber(v) or 0, dx = tonumber(dx) or 0, dy = tonumber(dy) or 0,
      fn = tonumber(fn) or 0, prev = tonumber(prev) or 0, next = tonumber(nxt) or 0,
      idle = type(idle) == "string" and idle or nil, plate = false, shown = true,
    }
  end

  -- the screen closes: the last bank screen open resets the value (framework side) and stops the filter at once
  function CF.Leave(stem)
    call(funcLuaCommand, CF.CMD_LEAVE, stem)
    CF.S[stem] = nil
  end

  -- the screen's list again with the value (its own tab refresh: filter params, list update, counters)
  function CF.Rebuild(stem)
    if type(OnListTabChanged) == "function" then
      pcall(OnListTabChanged)
    end
    CF.Draw(stem)
  end

  function CF.Attach(stem)
    if VRFW_Host == nil then
      return
    end
    local id = "vr_framework.card_filter"
    VRFW_Host.on(stem, "OnInit", { id = id, phase = "before", fn = function()
      CF.Enter(stem)
    end })
    -- instance 1 of the filter plate = the header (instance 0 stays the retail one)
    VRFW_Host.on(stem, "OnOpenLayer", { id = id, phase = "after", fn = function(r, a1, a2)
      if a1 == CF.LAYER and a2 == CF.IDX then
        CF.Draw(stem)
      end
    end })
    VRFW_Host.on(stem, "SetFilterGuideVisible", { id = id, phase = "after", fn = function(r, a1)
      local S = CF.S[stem]
      if S ~= nil then
        S.shown = a1 == true
        CF.Draw(stem)
      end
    end })
    VRFW_Host.on(stem, "OpenPersonalPlate", { id = id, phase = "after", fn = function()
      if CF.S[stem] ~= nil then
        CF.S[stem].plate = true
      end
    end })
    -- the plate closes through the screen's own function: chara_bank_menu has ClosePersonalPlate,
    -- chara_bank_menu_for_search only SuspendPersonalPlate; hook the ones this script defines (a lookup, no engine call)
    for _, f in ipairs({"ClosePersonalPlate", "SuspendPersonalPlate"}) do
      if type(_ENV[f]) == "function" then
        VRFW_Host.on(stem, f, { id = id, phase = "after", fn = function()
          if CF.S[stem] ~= nil then
            CF.S[stem].plate = false
          end
        end })
      end
    end
    -- FinalizeMenu: chara_bank_menu_for_search defines it, chara_bank_menu does not (create: hooked anyway)
    VRFW_Host.on(stem, "FinalizeMenu", { id = id, phase = "before", create = true, fn = function()
      CF.Leave(stem)
    end })
    -- the list counter: while a value is chosen the list is a filtered view, so it shows «shown / total» (the
    -- retail filtered layout) instead of the shown count in the bank's total box
    if type(_ENV.UpdateCharaCountInList) == "function" then
      VRFW_Host.on(stem, "UpdateCharaCountInList", { id = id, phase = "around", fn = function(nxt, ...)
        local S = CF.S[stem]
        local M = CHARA_FILTER_MENU
        if S == nil or not S.on or S.value == 0 or type(M) ~= "table" or type(M.IsFilterEnabled) ~= "function" then
          return nxt(...)
        end
        local orig = M.IsFilterEnabled
        M.IsFilterEnabled = function() return true end
        local r = table.pack(pcall(nxt, ...))
        M.IsFilterEnabled = orig
        if not r[1] then
          error(r[2], 0)
        end
        return table.unpack(r, 2, r.n)
      end })
    end
    VRFW_Host.on(stem, "OnFunction", { id = id, phase = "around", fn = function(nxt, a1, a2, ...)
      local S = CF.S[stem]
      if S == nil or not S.on or a1 ~= S.fn or (a2 ~= S.prev and a2 ~= S.next) or CF.PlateOpen(stem) or not CF.Idle(stem) then
        return nxt(a1, a2, ...)
      end
      local v = call(funcLuaCommand, CF.CMD_NEXT, a2 == S.next and 1 or -1)
      if type(v) == "number" and v ~= S.value then
        S.value = v
        call(funcLuaCommand, 1917805374, CF.SE_MOVE)
        CF.Rebuild(stem)
      end
    end })
    VRFW_Host.on(stem, "Step", { id = id, phase = "after", fn = function()
      local S = CF.S[stem]
      if S == nil or not S.on then
        return
      end
      local rebuild = call(funcLuaCommand, CF.CMD_ALIVE) == true
      -- the framework may have reset the value (a bank screen on top closed as the last one): follow it
      local v = tonumber(call(funcLuaCommand, CF.CMD_GET)) or 0
      if v ~= S.value then
        S.value = v
        rebuild = true
      end
      if rebuild then
        CF.Rebuild(stem)
      end
    end })
  end
end
