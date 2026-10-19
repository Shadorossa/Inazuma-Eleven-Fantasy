-- Definitions only. Shared by the four menu VMs participating in BetterMenu's
-- free-match drawer; ordinary menus never call these helpers.
BetterMenu = type(BetterMenu) == "table" and BetterMenu or {}
BetterMenu.Competition = BetterMenu.Competition or {}
do
  local C = BetterMenu.Competition
  function C.Hash(s)
    local n = 0xFFFFFFFF
    for i = 1, #s do
      n = bit32.bxor(n, s:byte(i))
      for _ = 1, 8 do n = bit32.bxor(bit32.rshift(n, 1), bit32.band(n, 1) ~= 0 and 0xEDB88320 or 0) end
    end
    return bit32.bxor(n, 0xFFFFFFFF)
  end
  local function call(fn, ...)
    local r = table.pack(pcall(fn, ...))
    if r[1] then return table.unpack(r, 2, r.n) end
  end
  function C.F(...) return call(funcLuaCommand, ...) end
  function C.M(...) return call(funcLuaMenuCommand, ...) end
  C.COMMAND = C.Hash("CMND_BetterMenu_Competition")
  C.OVERLAY = C.Hash("better_menu_competition_overlay")
  C.LAUNCH = C.Hash("better_menu_competition_launch")
  C.TRAVEL = C.Hash("CMND_VRFW_MENU_SCENE_TRAVEL")
  C.FOLLOW_CAMERA = C.Hash("CMND_VRFW_MENU_SCENE_FOLLOW_CAMERA")
  C.MENU_CAMERA = "MenuCamera"        -- the engine camera the menus' 3D models are drawn with
  C.LIST, C.CLASS, C.TITLE = 1970579282, 1605164450, C.Hash("title_menu_2")
  C.ROW, C.MODE = C.Hash("title00_07_item_button_upper"), 2477753773
  function C.State(op, ...) return C.F(C.COMMAND, op or "get", ...) end
  -- The selected team's crest centre (x) and the name's y on the Competition list; other mods may reserve a band of
  -- `height` px between the crest and the name (the name moves down by the sum of the reserved bands).
  C.CREST_X, C.NAME_Y = 1440, 235
  -- On-screen geometry of the strip in the menu's 1920 x 1080 frame, measured in the owner's screenshots
  -- (2026-10-19; the layout figures alone placed things 30+ px off): the selected crest's visible bottom is y 167, and
  -- the team name's glyphs start 8.4 px above its line (NAME_Y + the bands).
  C.CREST_BOTTOM = 167
  C.NAME_GLYPH_TOP = -8.4
  C.under_crest = C.under_crest or {}
  -- Reserve (height > 0) or free (0 / nil) the band `id` (the caller's own name); returns its top y (the name's old
  -- line), the crest x, the crest's visible bottom and the name glyphs' top relative to its line (for an even spacing).
  function C.ReserveUnderCrest(id, height)
    C.under_crest[id] = (height and height > 0) and height or nil
    local top = C.NAME_Y
    for k, h in pairs(C.under_crest) do if k < id then top = top + h end end
    return top, C.CREST_X, C.CREST_BOTTOM, C.NAME_GLYPH_TOP
  end
  -- listeners told when the Competition strip turns on (its overlay set), by id: C.strip_listeners[id] = function
  C.strip_listeners = C.strip_listeners or {}
  function C.NotifyStrip()
    for id, fn in pairs(C.strip_listeners) do
      local ok, why = pcall(fn)
      if not ok then C.Log("strip listener error", id, tostring(why)) end
    end
  end
  function C.UnderCrestHeight()
    local h = 0
    for _, v in pairs(C.under_crest) do h = h + v end
    return h
  end
  function C.Log(...) C.F(3661580131, "BetterMenu competition", ...) end
  function C.Active() return C.F(2947612279, C.OVERLAY) == true end
  function C.Set(k, v) C.F(3860611758, k, 0, v or 1, 1) end
  function C.Clear(k) if C.F(2947612279, k) == true then C.F(3363400568, k) end end
  -- The game's data stays in memory; the scene and its objects go with the RPG
  -- reset. No match reservation is allowed to survive this reset.
  function C.Reset()
    if C.F(1979970074) == true then return false, "save busy" end
    local travel = C.F(C.TRAVEL)
    if type(travel) ~= "table" or not travel.pending then return false, "no queued scene travel" end
    local kept = C.F(2310157611, 1)
    if kept ~= true then return false, "save carry unavailable" end
    C.M(3479138216, 1936716961) -- menu command: next root setting_top_menu (the scene loader)
    C.F(419468738, false)
    C.F(1507811093, false)
    C.F(937976662, true)
    C.F(3897105282)
    local direct = C.F(2048294502)
    if direct ~= true then
      C.Log("direct scene reset refused; the title will recover the scene")
      C.F(C.TRAVEL, "cancel")
      C.F(2310157611, 0)
    end
    return true
  end
  -- The Competition players in contre-jour (a team not beaten yet): the game's light-data push over the scene's light,
  -- as the special tactics do (CMND_CREATE_OBJECT of a light resource, CMND_REGIST_LIGHT_DATA, 0x432ADFBC, 0xDCF7FAC9;
  -- removed with 0xD96391F2 / 0xEF6D8470 / 0xCF17FA37). The resource is the tactics' Light_wht20110, served with the
  -- contraluz chara parameters while the scene runs (content\menu_scenes\clubhouse_contraluz.toml). The light applies to
  -- the characters on screen (the Competition shot shows only the three). One owner: the light's handles live in game
  -- params, so the list (it pushes the light when a team is served) and the title (it takes it off when the list
  -- closes) act on the same light.
  local LIGHT = {
    OBJECT = "BetterMenuContraluzObj", DATA = "BetterMenuContraluzData", RESOURCE = "Light_wht20110",
    FADE = 0.4,                                              -- seconds of the light's blend
    OBJECT_PARAM = C.Hash("better_menu_contraluz_object"),   -- the light object's handle + 1
    DATA_PARAM = C.Hash("better_menu_contraluz_data"),       -- the registered light data's handle + 1
  }
  local wanted_light, light_steps = nil, 0
  local LIGHT_STEPS = 300                                     -- steps a light object may take to load
  local function param(k)
    if C.F(2947612279, k) ~= true then return nil end
    local v = tonumber(C.F(3522198769, k))
    return v and v - 1 or nil
  end
  -- Ask for the contre-jour (on) or the scene's light (off); C.ContraluzStep carries it out (the light object may take
  -- a few frames to load). Logged on change.
  function C.Contraluz(on)
    on = on == true
    if wanted_light == on then return end
    wanted_light, light_steps = on, 0
    C.Log("contraluz", on and "on (a team not beaten)" or "off")
    C.ContraluzStep()
  end
  function C.ContraluzStep()
    if wanted_light == nil then return end
    local data = param(LIGHT.DATA_PARAM)
    if wanted_light == false then
      if data ~= nil then
        if C.F(3647181298, data) ~= false then C.F(4016931952, data) end
        C.F(3474455095, C.Hash(LIGHT.DATA))
        C.Clear(LIGHT.DATA_PARAM)
      end
      local object = param(LIGHT.OBJECT_PARAM)
      if object ~= nil and object ~= 0 then C.F(1631712417, object) end
      C.Clear(LIGHT.OBJECT_PARAM)
      wanted_light = nil
      return
    end
    if data ~= nil and C.F(3647181298, data) == false then  -- a light of an earlier scene (gone with its reset)
      C.Clear(LIGHT.DATA_PARAM)
      C.Clear(LIGHT.OBJECT_PARAM)
      data = nil
    end
    if data ~= nil then
      wanted_light = nil                                     -- already on
      return
    end
    local oc = C.Hash(LIGHT.OBJECT)
    light_steps = light_steps + 1
    if light_steps > LIGHT_STEPS then
      C.Log("contraluz light object not ready after", LIGHT_STEPS, "steps: left off")
      wanted_light = nil
      return
    end
    if C.F(2140355381, oc) ~= true and param(LIGHT.OBJECT_PARAM) == nil then
      local object = C.F(866495788, LIGHT.OBJECT, "MEM_ID_SCENE_OBJ", C.Hash(LIGHT.RESOURCE), "MEM_ID_SCENE_RES")
      C.Set(LIGHT.OBJECT_PARAM, (tonumber(object) or 0) + 1)
      C.Log("contraluz light object", tostring(object))
    end
    if C.F(4251655208, oc) ~= true then return end           -- still loading: the next step
    local regist = C.F(3423152028, oc, true)
    if type(regist) ~= "number" or regist == 65535 then
      C.Log("contraluz light data not registered", tostring(regist))
      wanted_light = nil
      return
    end
    C.F(1126883260, regist, true, 2)
    C.F(3707239113, oc, C.Hash(LIGHT.DATA), 65535, LIGHT.FADE, true)
    C.Set(LIGHT.DATA_PARAM, regist + 1)
    C.Log("contraluz light on (data", regist, ")")
    wanted_light = nil
  end

  -- a light pushed by 0.7.11 still held (its handles in the game params) is taken off when any of these menus opens:
  -- the title, the Competition list, the match HUD, the options the scene loads through
  if VRFW_Host ~= nil then
    for _, menu in ipairs({ "title_menu_2", "soccer_vs_cpu_list_menu", "soccer_constant_menu", "setting_top_menu" }) do
      VRFW_Host.on(menu, "OnInit", { id = "better_menu.contraluz_cleanup", phase = "after", fn = function()
        if C.F(2947612279, LIGHT.DATA_PARAM) == true or C.F(2947612279, LIGHT.OBJECT_PARAM) == true then
          wanted_light = false
          C.ContraluzStep()
          C.Log("contraluz light taken off at", menu)
        end
      end })
    end
  end

  -- Preserve native confirmation, difficulty/unlock logic and cancellation. Only
  -- the final reservation is handed to the properly initialised competition root.
  function C.Capture(nxt, ...)
    if not C.Active() then return nxt(...) end
    local raw, bright = funcLuaCommand, BrightFadeAllMenu
    funcLuaCommand = function(id, ...)
      if id == 1620561217 then
        local game, map, difficulty = ...
        for _ = 1, 30 do
          local accepted = raw(C.COMMAND, "launch", game, map, difficulty)
          if accepted ~= nil then return accepted end
          coroutine.yield()
        end
        C.Log("match hand-off timed out")
        return false
      elseif id == 3014583614 or id == 1104380539 then
        return true
      end
      return raw(id, ...)
    end
    BrightFadeAllMenu = function(...) if not C.Active() and bright then return bright(...) end end
    local r = table.pack(pcall(nxt, ...))
    funcLuaCommand, BrightFadeAllMenu = raw, bright
    if not r[1] then error(r[2], 0) end
    return table.unpack(r, 2, r.n)
  end
  -- Top-left probe: every layer this VM opened (OnOpenLayer), and on request one log line per visible instance
  -- with its position (layout units, origin top left, y down negative), the ones at the screen's top-left corner
  -- (PROBE_LEFT_OF x PROBE_ABOVE) marked «*». The layer crc is named by research\grafts\_names.json.
  C.PROBE_LEFT_OF, C.PROBE_ABOVE = 100, -60
  C.probe_opened = {}
  function C.ProbeTrack(layer, idx)
    if type(layer) ~= "number" then return end
    idx = type(idx) == "number" and idx or 0
    C.probe_opened[layer] = math.max(C.probe_opened[layer] or 0, idx)
  end
  function C.Probe(menu, why)
    local marked, others = {}, 0
    for layer, top in pairs(C.probe_opened) do
      if C.M(262659071, layer) == true then
        for idx = 0, top do
          if C.M(1262717583, layer, idx) == true then
            local x, y = C.M(4002164178, layer, idx)
            if type(x) == "number" and type(y) == "number" then
              if x < C.PROBE_LEFT_OF and y > C.PROBE_ABOVE then
                marked[#marked + 1] = string.format("*0x%08X/%d (%.0f, %.0f)", layer % 4294967296, idx, x, y)
              else
                others = others + 1
              end
            end
          end
        end
      end
    end
    table.sort(marked)
    C.Log("top-left probe", menu, why, #marked .. " visible layer(s) at the top left", table.concat(marked, ", "),
      others .. " other visible layer(s)")
  end
end
