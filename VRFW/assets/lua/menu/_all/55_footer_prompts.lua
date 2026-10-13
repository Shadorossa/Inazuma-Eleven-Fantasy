-- menu_engine: footer prompts, VRFW.FooterPrompts (VR-Framework base feature, 2026-10-09; docs/framework/footer-prompts.md).
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
--                           When = <Lua command hash> | function() return <bool> end})  -- optional: shown when
--                                                               -- the command answers true / the function says true
-- Where the entries go in:
--   * VRFW_FooterPrompts.Apply(menu, texts, glyphs, offsets, spare1, spare2, commands): appends to those tables IN
--     PLACE (a script the framework patches calls it right before its guide call; vs_route_town_menu's
--     SetupButtonGuideInfo, graft route_board);
--   * VRFW_FooterPrompts.Attach(stem, fn [, guide]): for a script the framework does not patch, wraps its global `fn`
--     (the function that sets the guide) through VRFW_Host: during that call the guide's two commands get the
--     entries appended to copies of their tables.
-- Offsets: the next step of the guide's own row (last + 18, retail {0, 18, 36, ...}); spare lists get 0.
-- When is asked every time the guide is set (no cache). No engine call at load time.
if VRFW_FooterPrompts == nil then
  local F = {
    LOG = 3661580131,            -- CMND_EVT_LOG
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

  -- appends the menu's shown entries to the guide tables (in place); returns how many
  function F.Apply(menu, texts, glyphs, offs, s1, s2, cmds)
    if type(texts) ~= "table" or type(glyphs) ~= "table" then
      return 0
    end
    local list = F.Entries(menu)
    for _, d in ipairs(list) do
      push(texts, glyphs, offs, s1, s2, cmds, d)
    end
    return #list
  end

  local function copy(t)
    local r = {}
    for i = 1, #t do
      r[i] = t[i]
    end
    return r
  end

  -- a script the framework does not patch: wrap its guide-setting global through VRFW_Host
  function F.Attach(stem, fn, guide)
    local key = stem .. "/" .. fn
    if F.attached[key] or VRFW_Host == nil or VRFW_Host.on == nil then
      return false
    end
    F.attached[key] = true
    local layer = guide or F.GUIDE
    VRFW_Host.on(stem, fn, {id = "vrfw.FooterPrompts", phase = "around", fn = function(nxt, ...)
      local list = F.Entries(stem)
      if #list == 0 or type(funcLuaMenuCommand) ~= "function" then
        return nxt(...)
      end
      local orig = funcLuaMenuCommand
      funcLuaMenuCommand = function(cmd, menu, lay, a, b, c, d, e, ...)
        if lay == layer and cmd == F.GUIDE_TEXTS and type(a) == "table" and type(b) == "table" then
          a, b = copy(a), copy(b)
          c = type(c) == "table" and copy(c) or c
          d = type(d) == "table" and copy(d) or d
          e = type(e) == "table" and copy(e) or e
          for _, x in ipairs(list) do
            push(a, b, c, d, e, nil, x)
          end
        elseif lay == layer and cmd == F.GUIDE_KEYS and type(a) == "table" then
          a = copy(a)
          for _, x in ipairs(list) do
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
    end})
    return true
  end
end
