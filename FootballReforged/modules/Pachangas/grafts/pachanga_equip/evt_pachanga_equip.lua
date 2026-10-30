-- Plantilla de equipo in «Tipo: Pachanga»: the emblem / kit pickers and «Conf. de equipo» (soccer_parameter_menu) work
-- on the 5v5 team (docs/game/ui/pachanga-templates.md §3.1). The team dock opens them with the dock number and its
-- team kind (0 = 11v11, 1 = 5v5): params 3357163798 / 4081600465 (pickers) or 2371475758 / 2898803562 (Conf. de
-- equipo). The retail menus read the kind but still read / write TEAM 0 of the dock: CMND_SET_TEAM_SET_INFO(dock, 0,
-- field) (emblem 1, kit 2), CMND_GET_TEAM_SET_INFO(dock, 0, ...) and away_kit's CMND_EVT_TEAM_UNIFORM(dock, 0, ...).
-- With kind 1 (outside story mode) every such call about THAT dock and team 0 is sent to team 1, so the 5v5 team
-- gets its own emblem and kit and the 11v11 team is left alone. (Synergies do not exist in Pachanga: the dock hides
-- their buttons, no redirect for the synergy picker.)
-- Story mode keeps the retail behaviour (one kit / emblem for the story's teams).
-- Installed from OnInit (the params are peeked before the retail OnInit deletes them). funcLuaCommand is registered by
-- the engine after the chunk ran, so the wrapper goes in through a __newindex hook on the globals (ui_clean technique).
-- Nothing calls funcLuaCommand at chunk load.
do
  local PQ = {
    KEYS = {{3357163798, 4081600465}, {2371475758, 2898803562}},   -- (dock, kind) param pairs
    CMDS = {[@crc:CMND_SET_TEAM_SET_INFO@] = true, [@crc:CMND_GET_TEAM_SET_INFO@] = true, [@crc:CMND_EVT_TEAM_UNIFORM@] = true},  -- SET / GET_TEAM_SET_INFO, EVT_TEAM_UNIFORM
    dock = nil, on = false, logs = 0,
  }
  EVT_PQ = PQ

  function PQ.log(...)
    if PQ.logs < 12 and type(funcLuaCommand) == "function" then
      PQ.logs = PQ.logs + 1
      pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, "EVT pachanga_equip", ...)
    end
  end

  local function wrap(f)
    if type(f) ~= "function" or (EVT_PQ_WRAPPED or {})[f] then
      return f
    end
    local w = function(h, a1, a2, ...)
      if PQ.on and PQ.CMDS[h] and a1 == PQ.dock and a2 == 0 then
        if PQ.logs < 12 then
          PQ.log("team 0 -> 1", h, a1, ...)
        end
        return f(h, a1, 1, ...)
      end
      return f(h, a1, a2, ...)
    end
    EVT_PQ_WRAPPED = EVT_PQ_WRAPPED or {}
    EVT_PQ_WRAPPED[w] = true
    return w
  end

  local function hook()
    if type(rawget(_ENV, "funcLuaCommand")) == "function" then
      rawset(_ENV, "funcLuaCommand", wrap(rawget(_ENV, "funcLuaCommand")))
      return
    end
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
  hook()

  local init = rawget(_ENV, "OnInit")
  if type(init) == "function" and not (EVT_PQ_WRAPPED or {})[init] then
    local w = function(...)
      PQ.on, PQ.dock = false, nil
      local ok = pcall(function()
        if funcLuaCommand(@crc:CMND_GET_PLAY_GAME_MODE@) == 2 then
          return
        end
        for _, k in ipairs(PQ.KEYS) do
          if VRFW_Param.Has(k[2]) and VRFW_Param.Get(k[2]) == 1 and VRFW_Param.Has(k[1]) then
            PQ.dock = VRFW_Param.Get(k[1])
            PQ.on = type(PQ.dock) == "number"
            return
          end
        end
      end)
      if ok and PQ.on then
        PQ.log("5v5 team of dock", PQ.dock)
      end
      return init(...)
    end
    EVT_PQ_WRAPPED = EVT_PQ_WRAPPED or {}
    EVT_PQ_WRAPPED[w] = true
    rawset(_ENV, "OnInit", w)
  end
end
