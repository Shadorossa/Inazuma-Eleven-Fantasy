-- VRFW team captain, game Lua side (every menu VM; docs/framework/team-captain.md). The captain of a team of the
-- active VS team set, from the game's own team data: the team's captain (CMND_GET_TEAM_SET_INFO kind 11), else the
-- member the game marks as captain (kind 8), else its first player.
--   VRFW_Team.Captain([team]) -> card (chara_param), handle; nil when the team has no player
--     team  the team of the set (0 = the 11-a-side team, 1 = the 5-a-side one; default 0)
-- No engine call at load time.
if VRFW_Team == nil then
  local T = {
    VS_SET = 3713813716,        -- CMND_GET_VS_USE_TEAM_SET
    TEAM_SET_INFO = 1033065575, -- CMND_GET_TEAM_SET_INFO (set, team, kind[, handle])
    MEMBER = 1720957768,        -- (set, team, i, 0) -> ok, handle; (set, team, i, 1) -> ok, position
    STATUS = 1131797651,        -- (handle, 4) -> chara_param
    CAPTAIN = 11,               -- kind: the team's captain handle
    IS_CAPTAIN = 8,             -- kind: (handle) -> is the captain
    LEADER = 19,                -- position of the team's leader (the controlled character), never a player
    MEMBERS = 20,
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
end
