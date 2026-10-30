-- VRFW team, game Lua side (every menu VM; docs/framework/team-captain.md). The captain of a team of the
-- active VS team set, from the game's own team data: the team's captain (CMND_GET_TEAM_SET_INFO kind 11), else the
-- member the game marks as captain (kind 8), else its first player.
--   VRFW_Team.Captain([team]) -> card (chara_param), handle; nil when the team has no player
--     team  the team of the set (0 = the 11-a-side team, 1 = the 5-a-side one; default 0)
--   VRFW_Team.Name(team) -> the team's name in the game language; "" for no team or an unreadable one
--   VRFW_Team.Emblem(layer, idx, team, shown) -> the team's crest on the instance's emblem quad (_icon_emblem_dmy01)
--     shown  the caller's table (one per screen): the team each instance shows, so a crest is asked only for another team
--   VRFW_Team.EmblemReset(layer, idx, shown) -> the instance's crest slot back to the object's own texture, forgotten
--   VRFW_Team.EmblemForget(layer, idx, shown) -> the instance forgotten (the engine rebuilt it)
-- No engine call at load time.
if VRFW_Team == nil then
  local T = {
    VS_SET = VRFW_Cmd.GET_VS_USE_TEAM_SET,        -- CMND_GET_VS_USE_TEAM_SET
    TEAM_SET_INFO = VRFW_Cmd.GET_TEAM_SET_INFO, -- CMND_GET_TEAM_SET_INFO (set, team, kind[, handle])
    MEMBER = 1720957768,        -- (set, team, i, 0) -> ok, handle; (set, team, i, 1) -> ok, position
    STATUS = 1131797651,        -- (handle, 4) -> chara_param
    CAPTAIN = 11,               -- kind: the team's captain handle
    IS_CAPTAIN = 8,             -- kind: (handle) -> is the captain
    LEADER = 19,                -- position of the team's leader (the controlled character), never a player
    MEMBERS = 20,
    TEAM_INFO = 2151743654,     -- (team, 2) -> has, name; (team, 6, 0) -> has, crest icon
    ICON_REQUEST = 3190452549,  -- (layer, idx, mesh, texture, icon): an icon on an instance's texture slot
    ICON_RESET = 4176779611,    -- (layer, idx, texture): the slot's texture back to the object's own
    EMBLEM_MESH = 3281704751,   -- _icon_emblem_dmy01: the crest quad of the list plates
    EMBLEM_TEXTURE = 255812047, -- icon_emblem_dmy01
  }
  VRFW_Team = T

  local function call(cmd, ...)
    local r = table.pack(pcall(funcLuaCommand, cmd, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end

  local function card_of(h)
    if type(h) ~= "number" or h == 0 then return nil end
    local p = call(T.STATUS, h, 4)
    if type(p) == "number" and p ~= 0 then return p end
    return nil
  end

  function T.Captain(team)
    team = math.floor(tonumber(team) or 0)
    local set = call(T.VS_SET)
    if type(set) ~= "number" then return nil end
    local ok, h = call(T.TEAM_SET_INFO, set, team, T.CAPTAIN)
    if ok == true and card_of(h) ~= nil then return card_of(h), h end
    local first = nil
    for i = 0, T.MEMBERS - 1 do
      local okh, hm = call(T.MEMBER, set, team, i, 0)
      local okp, pos = call(T.MEMBER, set, team, i, 1)
      if okh == true and card_of(hm) ~= nil and not (okp == true and pos == T.LEADER) then
        local okc, is = call(T.TEAM_SET_INFO, set, team, T.IS_CAPTAIN, hm)
        if okc == true and is == true then return card_of(hm), hm end
        first = first or hm
      end
    end
    if first ~= nil then return card_of(first), first end
    return nil
  end

  function T.Name(team)
    if team == nil or team == 0 then return "" end
    local ok, _, name = pcall(funcLuaCommand, T.TEAM_INFO, team, 2)
    if ok and type(name) == "string" then return name end
    return ""
  end

  local function emblem_key(layer, idx)
    return tostring(layer) .. ":" .. tostring(idx)
  end

  function T.Emblem(layer, idx, team, shown)
    local key = emblem_key(layer, idx)
    if shown ~= nil then
      if shown[key] == team then return end
      if shown[key] ~= nil then pcall(funcLuaMenuCommand, T.ICON_RESET, layer, idx, T.EMBLEM_TEXTURE) end
      shown[key] = team
    end
    local ok, has, icon = pcall(funcLuaCommand, T.TEAM_INFO, team, 6, 0)
    if ok and has then pcall(funcLuaMenuCommand, T.ICON_REQUEST, layer, idx, T.EMBLEM_MESH, T.EMBLEM_TEXTURE, icon) end
  end

  function T.EmblemReset(layer, idx, shown)
    local key = emblem_key(layer, idx)
    if shown ~= nil and shown[key] ~= nil then
      pcall(funcLuaMenuCommand, T.ICON_RESET, layer, idx, T.EMBLEM_TEXTURE)
      shown[key] = nil
    end
  end

  function T.EmblemForget(layer, idx, shown)
    if shown ~= nil then shown[emblem_key(layer, idx)] = nil end
  end
end
