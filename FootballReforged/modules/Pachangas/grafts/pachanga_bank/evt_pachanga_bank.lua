-- chara_bank_menu opened from «Plantilla de equipo» in «Tipo: Pachanga» (docs/game/ui/pachanga-templates.md §3.6).
-- «banco de pachangas con las alineaciones de pachanga» (Nacho): the bank shows and edits the 5v5 team of every dock it
-- shows, on the dock's own 5v5 pitch: layer evt_bank5_field (research/scripts/pachanga_bank_build.py: the dock's
-- mainmenu04_10 pitch placed on the bank pitch area, 5 starter corners, 11 bench, 3 support, coach left of the field).
-- Key evt_pb_dock (value = the dock the bank opens on), set by the dock only in Pachanga; without it the bank is retail.
--   * OnInit: the bank's formation INCLUDE goes to 5v5 mode (retail OnInitFormationCommon(..., true): team kind 1, 5v5
--     formation list, 5 starters, 5v5 bench locators) and its formation layer is evt_bank5_field;
--   * the retail pitch team14_03 stays open (team name, dock number, formation name box, build button) but its field
--     mesh is hidden and its card / coach attach entries are switched off (CMND_SET_LAYER_ATTACH_LOCATOR_TRACE), so the
--     cards hang on evt_bank5_field (its entries have labels of their own);
--   * the bank's own team reads / writes of the dock on screen (team 0 in retail) go to team 1; the place / move
--     193693077 too, except on dock 01 (linked: retail team 0, the engine adds to both teams);
--   * «Añadir al equipo» fills the first free 5v5 slot of the dock on screen (retail: the first dock with room);
--   * Z / C: the dock on screen follows (retail ChangeTeamDock redraws it with the 5v5 formation of that dock);
--   * synergy buttons hidden; the formation button (name box) stays visible, choosing it is refused (formations are
--     changed in Formación).
--   * the archetype button (soccer11_19, left of the formation name) shows the 5v5 team's build type (build-type read
--     2595549521(dock, kind) of the dock on screen -> team 1); choosing it opens «Bonificaciones de equipo» of the 5v5
--     team (EVT_Bonus5, §3.7; NG with an empty 5v5 team) instead of the retail build explanation; V too;
--   * the 5v5 field is drawn opaque (its material fades in with the dock's open motion, which is not used here);
--   * Z / C: the dock number and team name of team14_03 follow (the INCLUDE writes them to the formation layer).
-- Nothing calls funcLuaCommand at chunk load.
@BONUS5@
do
  local PB = {
    KEY = @crc:evt_pb_dock@,
    LAYER = @crc:evt_bank5_field@,
    FRAME = 4234291499,              -- team14_03_formation_frame
    FIELD_MESH = @crc:_formation_field01@,
    FIELD5_MESH = @crc:_formation_field02@,     -- evt_bank5_field's field
    MOVE = 193693077,                -- place / move (toSet, pos, fromSet, hdl, team)
    -- team-data commands (set, team, ...): the bank's retail code passes team 0 (its local n7 is never set)
    TEAMCMDS = {[@crc:CMND_GET_TEAM_SET_INFO@] = true, [@crc:CMND_SET_TEAM_SET_INFO@] = true, [1720957768] = true, [1721292418] = true,
                [2113285063] = true, [1108596907] = true, [748531447] = true,
                [2595549521] = true},    -- team build type (MENU_DEF.GetTeamBuildTypeFromSelectTeamDockAndPartyType)
    -- team14_03's attach entries of the 19 cards, 19 blanks, coach, coach blank (pachanga_bank_build.py, retail objbin)
    FRAME_LABELS = {721783728, 2987186698, 3305892508, 1534033727, 745033641, 3043040787, 3261476485, 1389966100,
                    635306882, 1159301735, 840874737, 3782874155, 2020820369, 259290375, 2433802404, 3860320306,
                    736745326, 3001059028, 3320297026, 1271038294, 3536572652, 2781667450, 1000895961, 1286554959,
                    3584431349, 2728469603, 840841714, 1159268708, 635338881, 1389998103, 3419464109, 3168260411,
                    582173848, 1437889550, 3434948020, 3149534498, 721750195, 1543649317, 1105693035, 2223394934},
    HIDE = {[3966159602] = true,     -- soccer11_40_synergy_attachment_button_pillar
            [212184996] = true},     -- soccer11_40_synergy_attachment_button_flag
    REFUSE = {[2722879973] = true, [3966159602] = true, [212184996] = true},   -- + soccer11_12_formation_button
    on = false, dock = nil, logs = 0,
  }
  EVT_PB = PB

  function PB.log(...)
    if PB.logs < 30 and type(funcLuaCommand) == "function" then
      PB.logs = PB.logs + 1
      pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, "EVT pachanga bank", ...)
    end
  end

  -- funcLuaCommand wrapper (the engine registers it after the chunk: __newindex hook, ui_clean technique)
  local function wrap(f)
    if type(f) ~= "function" or (EVT_PB_WRAPPED or {})[f] then
      return f
    end
    local w = function(h, a1, a2, a3, a4, a5, ...)
      if PB.on then
        if PB.TEAMCMDS[h] and a1 == PB.dock and a2 == 0 then
          return f(h, a1, 1, a3, a4, a5, ...)
        end
        if h == PB.MOVE and (a5 == 0 or a5 == nil) and PB.dock ~= 2 and (a1 == PB.dock or a3 == PB.dock) then
          PB.log("place / move on the 5v5 team", a1, a2, a3)
          return f(h, a1, a2, a3, a4, 1, ...)
        end
      end
      return f(h, a1, a2, a3, a4, a5, ...)
    end
    EVT_PB_WRAPPED = EVT_PB_WRAPPED or {}
    EVT_PB_WRAPPED[w] = true
    return w
  end
  if type(rawget(_ENV, "funcLuaCommand")) == "function" then
    rawset(_ENV, "funcLuaCommand", wrap(rawget(_ENV, "funcLuaCommand")))
  else
    local mt = getmetatable(_ENV)
    if mt == nil then
      mt = {}
      setmetatable(_ENV, mt)
    end
    local prev = mt.__newindex
    mt.__newindex = function(t, k, v)
      if k == "funcLuaCommand" then
        v = wrap(v)
      end
      if prev == nil then
        rawset(t, k, v)
      elseif type(prev) == "function" then
        prev(t, k, v)
      else
        prev[k] = v
      end
    end
  end

  function PB.hide()
    for L in pairs(PB.HIDE) do
      pcall(funcLuaMenuCommand, @crc:CMND_SET_LAYER_VISIBLE@, L, 0, false)
      pcall(funcLuaMenuCommand, @crc:CMND_SET_ENABLE_CTRL_FOCUS@, L, false)
    end
    pcall(funcLuaMenuCommand, @crc:CMND_SET_MESH_VISIBLE@, PB.FRAME, PB.FIELD_MESH, false, 0)
    pcall(funcLuaMenuCommand, @crc:CMND_SET_MESH_VISIBLE@, PB.LAYER, PB.FIELD5_MESH, true, 0)
    pcall(funcLuaMenuCommand, @crc:CMND_SET_LAYER_MODEL_ALPHA@, PB.LAYER, 0, 0, 1)
  end

  -- the retail refreshes show the hidden buttons / the 11v11 field again (CMND_UPDATE_SYNERGY_BUTTON and the
  -- INCLUDE's own layer / mesh / alpha calls): while the bank is on the 5v5 team those calls keep the look of PB.hide
  function PB.guard()
    if type(VRFW_Host) ~= "table" or type(VRFW_Host.HookCommand) ~= "function" then
      return
    end
    local menu = {menu = true}
    VRFW_Host.HookCommand(@crc:CMND_SET_LAYER_VISIBLE@, function(nxt, id, layer, index, visible, ...)
      if PB.on and PB.HIDE[layer] and visible then
        return nxt(id, layer, index, false, ...)
      end
      return nxt(id, layer, index, visible, ...)
    end, "Pachangas.bank_layer_visible", menu)
    VRFW_Host.HookCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, function(nxt, id, layer, enabled, ...)
      if PB.on and PB.HIDE[layer] and enabled then
        return nxt(id, layer, false, ...)
      end
      return nxt(id, layer, enabled, ...)
    end, "Pachangas.bank_layer_focus", menu)
    VRFW_Host.HookCommand(@crc:CMND_SET_MESH_VISIBLE@, function(nxt, id, layer, mesh, visible, ...)
      if PB.on and layer == PB.FRAME and mesh == PB.FIELD_MESH then
        return nxt(id, layer, mesh, false, ...)
      end
      if PB.on and layer == PB.LAYER and mesh == PB.FIELD5_MESH then
        return nxt(id, layer, mesh, true, ...)
      end
      return nxt(id, layer, mesh, visible, ...)
    end, "Pachangas.bank_mesh_visible", menu)
    VRFW_Host.HookCommand(@crc:CMND_SET_LAYER_MODEL_ALPHA@, function(nxt, id, layer, index, a3, alpha, ...)
      if PB.on and layer == PB.LAYER then
        return nxt(id, layer, index, a3, 1, ...)
      end
      return nxt(id, layer, index, a3, alpha, ...)
    end, "Pachangas.bank_field_alpha", menu)
    VRFW_Host.HookCommand({@crc:CMND_UPDATE_SYNERGY_BUTTON@, 3964547760}, function(nxt, id, layer, ...)
      local r = table.pack(nxt(id, layer, ...))
      if PB.on and PB.HIDE[layer] then
        PB.hide()
      end
      return table.unpack(r, 1, r.n)
    end, "Pachangas.bank_synergy_button", menu)
  end

  -- first free 5v5 slot of `set` (positions 0..18: 5 starters, 11 bench, 3 support), -1 = full
  function PB.freeSlot(set)
    for pos = 0, 18 do
      local ok, idx = funcLuaCommand(1721292418, set, 1, pos)
      if not ok or type(idx) ~= "number" then
        idx = pos
      end
      local ok2, h = funcLuaCommand(1720957768, set, 1, idx, 0)
      if not ok2 or h == nil or h == 0 then
        return pos
      end
    end
    return -1
  end

  local function wrapcb(name, make)
    local f = rawget(_ENV, name)
    if type(f) == "function" and not (EVT_PB_WRAPPED or {})[f] then
      local w = make(f)
      EVT_PB_WRAPPED = EVT_PB_WRAPPED or {}
      EVT_PB_WRAPPED[w] = true
      rawset(_ENV, name, w)
    end
  end

  wrapcb("OnInit", function(orig)
    return function(...)
      PB.on, PB.dock = false, nil
      pcall(function()
        if VRFW_Param.Has(PB.KEY) then
          PB.dock = VRFW_Param.Get(PB.KEY)
          VRFW_Param.Clear(PB.KEY)
          PB.on = type(PB.dock) == "number" and funcLuaCommand(@crc:CMND_GET_PLAY_GAME_MODE@) ~= 2
        end
      end)
      if PB.on then
        PB.guard()
      end
      local r = table.pack(orig(...))
      if PB.on and type(OnInitFormationCommon) == "function" and type(SetFormationLayer) == "function" then
        local ok, got, fid = pcall(funcLuaCommand, @crc:CMND_GET_TEAM_SET_INFO@, PB.dock, 1, 4)
        local e = select(2, pcall(OnInitFormationCommon, (ok and got) and fid or nil, nil, PB.dock, nil, nil, nil, true))
        SetFormationLayer(PB.LAYER)
        PB.log("5v5 bank of dock", PB.dock, "formation", tostring(fid), tostring(e))
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  wrapcb("ChangeTeamDock", function(orig)
    return function(a1, ...)
      if PB.on then
        PB.dock = a1
        PB.log("dock on screen", a1)
      end
      return orig(a1, ...)
    end
  end)

  wrapcb("SearchEmptyFormationPosition", function(orig)
    return function(a1, ...)
      if not PB.on or type(PB.dock) ~= "number" then
        return orig(a1, ...)
      end
      if type(IsCharaInTeam) == "function" and IsCharaInTeam(a1, PB.dock) then
        return -1, 255
      end
      local p = PB.freeSlot(PB.dock)
      if p >= 0 then
        return PB.dock, p
      end
      return -1, 255
    end
  end)

  wrapcb("OnOpenLayer", function(orig)
    return function(a1, a2, ...)
      if PB.on and a1 == PB.FRAME then
        -- before the retail open builds the cards: they must not hang on the 11v11 pitch
        for _, label in ipairs(PB.FRAME_LABELS) do
          pcall(funcLuaMenuCommand, @crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, PB.FRAME, 0, label, false)
        end
      end
      local r = table.pack(orig(a1, a2, ...))
      if PB.on and (a1 == PB.FRAME or a1 == PB.LAYER or PB.HIDE[a1]) then
        PB.hide()
      end
      if PB.on and a1 == PB.LAYER then
        pcall(function()
          PB.log("bank5 field open", tostring(funcLuaMenuCommand(@crc:CMND_IS_OPEN_LAYER@, PB.LAYER)),
            "visible", tostring(funcLuaMenuCommand(@crc:CMND_IS_LAYER_VISIBLE@, PB.LAYER, 0)),
            "field mesh", tostring(funcLuaMenuCommand(@crc:CMND_IS_MESH_VISIBLE@, PB.LAYER, PB.FIELD5_MESH, 0)))
        end)
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  for _, cb in ipairs({"OnDecideFocus", "OnEnter"}) do
    wrapcb(cb, function(orig)
      return function(a1, ...)
        if PB.on and PB.REFUSE[a1] then
          pcall(funcLuaCommand, @crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
          return
        end
        return orig(a1, ...)
      end
    end)
  end

  -- Z / C: the INCLUDE writes the dock number and the team name to its formation layer (evt_bank5_field here, which has
  -- neither): the same on team14_03 (retail code of UpdateTeamDockNoCommon / UpdateTeamNameCommon)
  wrapcb("UpdateTeamDockNoCommon", function(orig)
    return function(a1, a2, ...)
      local r = table.pack(orig(a1, a2, ...))
      if PB.on and type(a1) == "number" and type(a2) == "number" then
        pcall(function()
          local p = funcLuaMenuCommand(@crc:CMND_SEARCH_PRIM_INDEX@, PB.FRAME, 0, 2160862211)
          funcLuaMenuCommand(3609943765, PB.FRAME, 0, p, a1 - a2 + 1)
        end)
      end
      return table.unpack(r, 1, r.n)
    end
  end)
  wrapcb("UpdateTeamNameCommon", function(orig)
    return function(a1, a2, ...)
      local r = table.pack(orig(a1, a2, ...))
      if PB.on then
        pcall(function()
          local ok, name = funcLuaCommand(@crc:CMND_GET_TEAM_SET_INFO@, a1, a2, 6)
          funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, PB.FRAME, 2193213954 --[[_text_teamname01]],
            ok and name or "", 0)
        end)
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  -- archetype button (soccer11_19) in Pachanga: «Bonificaciones de equipo» of the 5v5 team (as the dock's CONF. DE
  -- EQUIPO), opened like the retail dock does it (parameter menu over the bank, bank input off while it is open)
  function PB.openBonus()
    MENU_DEF.SetPropertyValueForSoccerParameterMenu(PB.dock, 255, 1, false)
    funcLuaMenuCommand(1558704558, 3358148956 --[[chara_bank_menu]], false)
    if type(SetCharaBankInputEnabled) == "function" then
      SetCharaBankInputEnabled(false)
    end
    funcLuaCommand(@crc:CMND_OPEN_MENU_OBJECT@, 2197290544 --[[soccer_parameter_menu]])
    coroutine.yield()
    waitFalse(function()
      return funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, 2197290544 --[[soccer_parameter_menu]])
    end)
    coroutine.yield()
    funcLuaMenuCommand(1558704558, 3358148956 --[[chara_bank_menu]], true)
    if type(SetCharaBankInputEnabled) == "function" then
      SetCharaBankInputEnabled(true)
    end
  end
  wrapcb("OpenTeamBuildExplanationMenu", function(orig)
    return function(...)
      if PB.on and type(PB.dock) == "number" then
        PB.log("archetype button: 5v5 bonuses of dock", PB.dock)
        return select(2, EVT_Bonus5(PB.dock, "bank archetype", PB.openBonus))
      end
      return orig(...)
    end
  end)

  -- «Bonificaciones de equipo» (V): the 5v5 team of the dock on screen
  wrapcb("OpenAndWaitTeamSkillParameterMenu", function(orig)
    return function(...)
      if PB.on and type(PB.dock) == "number" then
        return select(2, EVT_Bonus5(PB.dock, "bank", orig, ...))
      end
      return orig(...)
    end
  end)
end
