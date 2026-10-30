-- menu_engine: footer prompts, VRFW.FooterPrompts (VR-Framework base feature).
-- Hold prompts (AddHold / WaitHold, at the end): the long-press ring shows only while the key is held.
-- Definitions only (this file runs in every script VM, lua\_all). A retail bottom button guide
-- (mainmenu01_06_base_button_guide) is set by its script in one call: funcLuaMenuCommand(2209673388, menu, guide,
-- texts, glyphs, offsets, spare1, spare2) + funcLuaMenuCommand(452337289, menu, guide, commands). Mods DECLARE extra
-- entries of a menu's guide; the framework appends them to the tables of that call, after the entries the script (and
-- anything before) put there, in Order, so nothing is overwritten and the engine lays all of them out in one row:
--   VRFW_FooterPrompts.Add({Name = "<ModPrefix>.<PascalCase>",   -- a second Add with the same Name replaces it
--                           Menu = "<script stem>",              -- e.g. "vs_route_town_menu"
--                           Text = <text id>,                    -- crc32 of the text row id (a mod's text row)
--                           Icon = <glyph id>,                   -- e.g. 3487556099 <CMD_FUNCR2> (follows the device)
--                           Command = <command hash>,            -- optional: the command a click on it sends (0)
--                           Order = <number>,                    -- optional, lower first (0); then by Name
--                           When = <Lua command hash> | function() return <bool> end,  -- optional: shown when
--                                                               -- the command answers true / the function says true
--                           Replaces = <glyph id>})             -- optional: while shown, the entry takes the
--                                                               -- place of the script's entry with that glyph (its
--                                                               -- text, glyph and command); none there = appended
-- Where the entries go in:
--   * VRFW_FooterPrompts.Apply(menu, texts, glyphs, offsets, spare1, spare2, commands): appends to those tables IN
--     PLACE (a script the framework patches calls it right before its guide call; vs_route_town_menu's
--     SetupButtonGuideInfo, graft route_board);
--   * VRFW_FooterPrompts.Attach(stem, fn [, guide]): for a script the framework does not patch, wraps its global `fn`
--     (the function that sets the guide) through VRFW_Host when the stem is a host, else directly in the VM
--     of the hook file that calls it (the global must exist: call it from a hook file of that stem): during that call
--     the guide's two commands get the entries added to copies of their tables.
-- Offsets: the next step of the guide's own row (last + 18, retail {0, 18, 36, ...}); spare lists get 0.
-- When is asked every time the guide is set (no cache). No engine call at load time.
if VRFW_FooterPrompts == nil then
  local F = {
    LOG = VRFW_Cmd.EVT_LOG,            -- CMND_EVT_LOG
    GUIDE = 1138543975,          -- mainmenu01_06_base_button_guide
    GUIDE_TEXTS = 2209673388,    -- (menu, guide, texts, glyphs, offsets, spare1, spare2)
    GUIDE_KEYS = 452337289,      -- (menu, guide, commands)
    STEP = 18,
    decls = {},                  -- name -> declaration
    attached = {},
  }
  VRFW_FooterPrompts = F

  function F.Log(...)
    pcall(funcLuaCommand, F.LOG, "vrfw.FooterPrompts", ...)
  end

  function F.Add(d)
    if type(d) ~= "table" or type(d.Name) ~= "string" or type(d.Menu) ~= "string" or type(d.Text) ~= "number"
        or type(d.Icon) ~= "number" then
      return false
    end
    F.decls[d.Name] = d
    return true
  end

  local function shown(d)
    local w = d.When
    if w == nil then
      return true
    end
    local ok, on
    if type(w) == "function" then
      ok, on = pcall(w)
    else
      ok, on = pcall(funcLuaCommand, w)
    end
    if not ok then
      if not d.warned then
        d.warned = true
        F.Log(d.Name .. ": When failed: " .. tostring(on))
      end
      return false
    end
    return on == true
  end

  -- the shown entries of a menu, in order
  function F.Entries(menu)
    local list = {}
    for _, d in pairs(F.decls) do
      if d.Menu == menu and shown(d) then
        list[#list + 1] = d
      end
    end
    table.sort(list, function(a, b)
      local oa, ob = a.Order or 0, b.Order or 0
      if oa ~= ob then
        return oa < ob
      end
      return a.Name < b.Name
    end)
    return list
  end

  local function push(texts, glyphs, offs, s1, s2, cmds, d)
    texts[#texts + 1] = d.Text
    glyphs[#glyphs + 1] = d.Icon
    if type(offs) == "table" then
      local last = offs[#offs]
      offs[#offs + 1] = (type(last) == "number") and (last + F.STEP) or (#offs * F.STEP)
    end
    if type(s1) == "table" then
      s1[#s1 + 1] = 0
    end
    if type(s2) == "table" then
      s2[#s2 + 1] = 0
    end
    if type(cmds) == "table" then
      cmds[#cmds + 1] = d.Command or 0
    end
  end

  -- the position of the script's entry a declaration replaces (its Replaces glyph), nil = none / not there
  local function replaced_position(glyphs, d)
    if type(d.Replaces) ~= "number" then
      return nil
    end
    for i = 1, #glyphs do
      if glyphs[i] == d.Replaces then
        return i
      end
    end
    return nil
  end

  -- adds the shown entries to the text tables (in place): a Replaces entry over the script's entry, the others
  -- appended. Returns the replaced positions {position -> declaration} and the appended declarations, in order
  local function add_entries(list, texts, glyphs, offs, s1, s2, cmds)
    local replaced, appended = {}, {}
    for _, d in ipairs(list) do
      local at = replaced_position(glyphs, d)
      if at ~= nil and replaced[at] == nil then
        texts[at], glyphs[at] = d.Text, d.Icon
        replaced[at] = d
        if type(cmds) == "table" then
          cmds[at] = d.Command or cmds[at]
        end
      else
        push(texts, glyphs, offs, s1, s2, cmds, d)
        appended[#appended + 1] = d
      end
    end
    return replaced, appended
  end

  -- adds the shown entries of a menu to the guide tables (in place); returns how many
  function F.Apply(menu, texts, glyphs, offs, s1, s2, cmds)
    if type(texts) ~= "table" or type(glyphs) ~= "table" then
      return 0
    end
    local list = F.Entries(menu)
    add_entries(list, texts, glyphs, offs, s1, s2, cmds)
    return #list
  end

  local function copy(t)
    local r = {}
    for i = 1, #t do
      r[i] = t[i]
    end
    return r
  end

  -- the guide call of a script with the entries added: runs nxt(...) with the two guide commands rewritten
  local function call_with_entries(stem, layer, nxt, ...)
    local list = F.Entries(stem)
    if #list == 0 or type(funcLuaMenuCommand) ~= "function" then
      return nxt(...)
    end
    local orig = funcLuaMenuCommand
    local replaced, appended = {}, {}
    funcLuaMenuCommand = function(cmd, menu, lay, a, b, c, d, e, ...)
      if lay == layer and cmd == F.GUIDE_TEXTS and type(a) == "table" and type(b) == "table" then
        a, b = copy(a), copy(b)
        c = type(c) == "table" and copy(c) or c
        d = type(d) == "table" and copy(d) or d
        e = type(e) == "table" and copy(e) or e
        replaced, appended = add_entries(list, a, b, c, d, e, nil)
      elseif lay == layer and cmd == F.GUIDE_KEYS and type(a) == "table" then
        a = copy(a)
        for at, x in pairs(replaced) do
          a[at] = x.Command or a[at]
        end
        for _, x in ipairs(appended) do
          a[#a + 1] = x.Command or 0
        end
      end
      return orig(cmd, menu, lay, a, b, c, d, e, ...)
    end
    local r = table.pack(pcall(nxt, ...))
    funcLuaMenuCommand = orig
    if not r[1] then
      error(r[2], 0)
    end
    return table.unpack(r, 2, r.n)
  end

  -- a script the framework does not patch: wrap its guide-setting global (through VRFW_Host when the stem is a host,
  -- else directly in this VM; once per stem / function)
  function F.Attach(stem, fn, guide)
    local key = stem .. "/" .. fn
    if F.attached[key] then
      return false
    end
    local layer = guide or F.GUIDE
    local host = VRFW_Host ~= nil and type(VRFW_Host.hosts) == "table" and VRFW_Host.hosts[stem] ~= nil
    if host and VRFW_Host.on ~= nil then
      F.attached[key] = true
      VRFW_Host.on(stem, fn, {id = "vrfw.FooterPrompts", phase = "around", fn = function(nxt, ...)
        return call_with_entries(stem, layer, nxt, ...)
      end})
      return true
    end
    local current = rawget(_ENV, fn)
    if type(current) ~= "function" then
      return false
    end
    F.attached[key] = true
    _ENV[fn] = function(...)
      return call_with_entries(stem, layer, current, ...)
    end
    return true
  end

  -- Hold prompts: a guide entry whose key acts when held. Idle, the guide shows only its glyph and label;
  -- while the key is held the retail long-press ring (object win04_12_long_press_button) sits over the entry's glyph
  -- and fills with the hold; it goes away on release or as soon as the hold completes.
  --   VRFW_FooterPrompts.AddHold({Name = "<ModPrefix>.<PascalCase>",
  --                               Ring = <layer id>,       -- the menu's win04_12_long_press_button layer, added with
  --                                                        -- no opening group (flags [0, 0, 0, 0, 1, 0])
  --                               Icon = <glyph text id>,  -- the key glyph drawn in the ring (follows the device)
  --                               Entry = <number>,        -- the prompt's position in the guide row (0 = first)
  --                               Seconds = <number>,      -- optional: hold time (2)
  --                               HeldSeconds = function() return <seconds the key is held, or nil> end,  -- optional
  --                               Pressed = function() return <bool> end,  -- the key's command this frame
  --                               Menus = function() return {<menu handle>, ...} end,  -- optional: the guide's menus
  --                               OnHeld = function() end})                -- optional: the moment the hold completes
  --   WaitHold(name) -> "tap" | "held": coroutine body (yields every frame); returns once the key is released.
  --   HoldProgress(name, progress 0..1) / HoldHide(name): the ring by hand.
  -- Without HeldSeconds (or before it reports a hold) the key counts as held while Pressed keeps repeating.
  F.HOLD = {
    SECONDS = 2,
    SHOW_AFTER = 0.1,              -- seconds before the ring shows, so a tap never flashes it
    KEY_GRACE = 30,                -- frames without a Pressed repeat = released
    GUIDE_BUTTON = 9396745,        -- mainmenu01_07_button_guide: one instance per guide entry
    GLYPH_NODE = 950238781,        -- its _text_btn01 (50 x 50, top-left)
    RING_TEXT = 950238781,         -- the ring's _text_btn01
    RING_RATE = 1996459178,        -- the ring's rate bar (0 empty .. 1 full)
    RING_SCALE = 50 / 68,          -- the ring's glyph box is 68 px, the guide's 50 px
    RING_DX = 25, RING_DY = -25,   -- glyph top-left -> centre (layout units, y up)
    PRIORITY = 700,
  }
  F.holds = {}

  function F.AddHold(d)
    if type(d) ~= "table" or type(d.Name) ~= "string" or type(d.Ring) ~= "number" or type(d.Icon) ~= "number" then
      return false
    end
    F.holds[d.Name] = d
    return true
  end

  local function glyph_position(menu, entry)
    local ok, x, y
    if menu == nil then
      ok, x, y = pcall(funcLuaMenuCommand, VRFW_Cmd.GET_MESH_GLOBAL_POSITION, F.HOLD.GUIDE_BUTTON, entry,
        F.HOLD.GLYPH_NODE)
    else
      ok, x, y = pcall(funcLuaMenuCommand, VRFW_Cmd.GET_MESH_GLOBAL_POSITION, F.HOLD.GUIDE_BUTTON, entry, F.HOLD.GLYPH_NODE, menu)
    end
    -- (0, 0) is what a missing node answers
    if ok and type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then
      return x, y
    end
    return nil
  end

  -- the ring's centre over the entry's glyph (the guide's menus first, then no menu); nil = not found
  local function ring_position(d)
    local entry = d.Entry or 0
    if type(d.Menus) == "function" then
      local ok, menus = pcall(d.Menus)
      if ok and type(menus) == "table" then
        for _, m in ipairs(menus) do
          if type(m) == "number" and m ~= 0 then
            local x, y = glyph_position(m, entry)
            if x ~= nil then
              return x + F.HOLD.RING_DX, y + F.HOLD.RING_DY
            end
          end
        end
      end
    end
    local x, y = glyph_position(nil, entry)
    if x ~= nil then
      return x + F.HOLD.RING_DX, y + F.HOLD.RING_DY
    end
    return nil
  end

  -- one frame of the hold: the ring at `progress` over the entry's glyph; false = unknown hold / no ring layer
  function F.HoldProgress(name, progress)
    local d = F.holds[name]
    if d == nil then
      return false
    end
    local L = d.Ring
    if funcLuaMenuCommand(VRFW_Cmd.IS_EXIST_LAYER, L) ~= true then
      return false
    end
    if funcLuaMenuCommand(VRFW_Cmd.IS_OPEN_LAYER, L, 0) ~= true then
      funcLuaMenuCommand(VRFW_Cmd.OPEN_LAYER, L, 0)
      d.ready, d.glyph_set = false, false
      return true
    end
    if funcLuaMenuCommand(VRFW_Cmd.IS_LOADING_LAYER, L) == true then
      return true
    end
    if not d.ready then
      d.ready = true
      funcLuaMenuCommand(VRFW_Cmd.SET_DRAW_PRIORITY, L, 0, F.HOLD.PRIORITY, true)
      funcLuaMenuCommand(VRFW_Cmd.SET_LAYER_LOCAL_SCALE, L, F.HOLD.RING_SCALE, F.HOLD.RING_SCALE, 1, 0)
      funcLuaMenuCommand(541357333 --[[rate init]], L, F.HOLD.RING_RATE, 0, 0)
    end
    if not d.glyph_set then
      -- read at every hold, so the glyph follows the device in use
      d.glyph_set = true
      local ok, glyph = pcall(funcLuaCommand, VRFW_Cmd.TEXT_GET, d.Icon)
      funcLuaMenuCommand(VRFW_Cmd.SET_MENU_TEXT_STRING, L, F.HOLD.RING_TEXT,
        (ok and type(glyph) == "string") and glyph or "", 0)
    end
    local x, y = ring_position(d)
    if x == nil then
      if not d.warned then
        d.warned = true
        F.Log(d.Name .. ": the guide glyph of entry " .. tostring(d.Entry or 0) .. " was not found; ring hidden")
      end
      funcLuaMenuCommand(VRFW_Cmd.SET_LAYER_VISIBLE, L, 0, false)
      return true
    end
    funcLuaMenuCommand(VRFW_Cmd.SET_LAYER_LOCAL_POS, L, x, y, 0, 0)
    funcLuaMenuCommand(1595998683 --[[CMND_SET_RATE]], L, F.HOLD.RING_RATE, 0, math.max(0, math.min(1, progress)), 0)
    funcLuaMenuCommand(VRFW_Cmd.SET_LAYER_VISIBLE, L, 0, true)
    return true
  end

  -- the ring emptied and hidden (nothing when it was never opened)
  function F.HoldHide(name)
    local d = F.holds[name]
    if d == nil then
      return
    end
    d.glyph_set = false
    local L = d.Ring
    if funcLuaMenuCommand(VRFW_Cmd.IS_EXIST_LAYER, L) == true and funcLuaMenuCommand(VRFW_Cmd.IS_OPEN_LAYER, L, 0) == true then
      funcLuaMenuCommand(1595998683, L, F.HOLD.RING_RATE, 0, 0, 0)
      funcLuaMenuCommand(VRFW_Cmd.SET_LAYER_VISIBLE, L, 0, false)
    end
  end

  -- the key of a hold prompt was pressed: waits (yielding every frame) until it is released; "held" when it stayed
  -- down for the hold time (OnHeld runs and the ring goes at that moment), else "tap"; nil = unknown hold
  function F.WaitHold(name)
    local d = F.holds[name]
    if d == nil then
      return nil
    end
    local H = F.HOLD
    local seconds = (type(d.Seconds) == "number" and d.Seconds > 0) and d.Seconds or H.SECONDS
    local frames, last_press, timer_seen, result = 0, 0, false, nil
    d.glyph_set = false
    while true do
      local timer = nil
      if type(d.HeldSeconds) == "function" then
        local ok, s = pcall(d.HeldSeconds)
        if ok and type(s) == "number" then
          timer = s
        end
      end
      if timer ~= nil and timer > 0 then
        timer_seen = true
      end
      if type(d.Pressed) == "function" then
        local ok, on = pcall(d.Pressed)
        if ok and on == true then
          last_press = frames
        end
      end
      local held, time
      if timer_seen then
        held, time = timer ~= nil and timer > 0, timer or 0
      else
        held, time = frames - last_press <= H.KEY_GRACE, frames / 60
      end
      if result == nil then
        if not held then
          result = "tap"
          break
        end
        if time >= seconds then
          result = "held"
          pcall(F.HoldHide, name)
          if type(d.OnHeld) == "function" then
            pcall(d.OnHeld)
          end
        elseif time >= H.SHOW_AFTER then
          pcall(F.HoldProgress, name, time / seconds)
        end
      elseif not held then
        break
      end
      coroutine.yield()
      frames = frames + 1
    end
    pcall(F.HoldHide, name)
    return result
  end
end
