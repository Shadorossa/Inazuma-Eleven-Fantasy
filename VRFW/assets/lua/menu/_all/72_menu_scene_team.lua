-- menu_scene (VR-Framework): the people of a menu scene from the active team. Runs in every menu VM (lua\_all); no
-- engine call at load. VRFW_MenuSceneTeam() -> members, kit, log text: the active team set's players and staff, the
-- captain first then by position, as "role:chara_base:motion set,…" (role player / manager / coach), and the team's
-- kit. Read from the game's team data at every call (setting_top_menu before the map loads; title_menu_2 when the team
-- changes while the scene is up: lua/menu/title_menu_2/151_menu_scene_npc_reload.lua).
if VRFW_MenuSceneTeam == nil then
  local T = {
    VS_SET = VRFW_Cmd.GET_VS_USE_TEAM_SET,       -- CMND_GET_VS_USE_TEAM_SET () -> the active team set
    MEMBER = 1720957768,       -- team set member (set, team type, i, 0 handle | 1 position) -> has, value
    STATUS = 1131797651,       -- character status (handle, 4) -> chara_param card
    SET_INFO = VRFW_Cmd.GET_TEAM_SET_INFO,     -- CMND_GET_TEAM_SET_INFO (set, team type, field, …) -> has, value
    CHARA_BASE = VRFW_Cmd.VRFW_CHARA_BASE,    -- CMND_VRFW_CHARA_BASE (card) -> chara_base
    MOTION_SET = VRFW_Cmd.VRFW_CHARA_MOTION_SET,   -- CMND_VRFW_CHARA_MOTION_SET (chara_base) -> motion set (c000101 …)
    MEMBER_SLOTS = 29,         -- the slots a team set holds
    LAST_POSITION = 19,        -- positions 0..15 players, 16..18 managers, 19 coach
    LAST_PLAYER = 15, LAST_MANAGER = 18,
  }

  local function Call(cmd, ...)
    local r = table.pack(pcall(funcLuaCommand, cmd, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end

  function VRFW_MenuSceneTeam()
    local set = Call(T.VS_SET)
    if type(set) ~= "number" or set < 0 then
      return "", 0, "no active team set"
    end
    local byPos, captain = {}, nil
    for k = 0, T.MEMBER_SLOTS - 1 do
      local has, hdl = Call(T.MEMBER, set, 0, k, 0)
      if has and type(hdl) == "number" and hdl ~= 0 then
        local hasp, pos = Call(T.MEMBER, set, 0, k, 1)
        if hasp and type(pos) == "number" and pos >= 0 and pos <= T.LAST_POSITION and byPos[pos] == nil then
          local card = Call(T.STATUS, hdl, 4)
          if type(card) == "number" and card ~= 0 then
            byPos[pos] = card
            local hask, cap = Call(T.SET_INFO, set, 0, 8, hdl)
            if hask and cap == true then captain = pos end
          end
        end
      end
    end
    local order = {}
    if captain ~= nil then order[1] = captain end
    for pos = 0, T.LAST_POSITION do
      if byPos[pos] ~= nil and pos ~= captain then order[#order + 1] = pos end
    end
    local parts, skipped = {}, 0
    local counts = { players = 0, managers = 0, coaches = 0 }
    for _, pos in ipairs(order) do
      local base = Call(T.CHARA_BASE, byPos[pos])
      local mset = type(base) == "number" and Call(T.MOTION_SET, base) or nil
      if type(base) == "number" and base ~= 0 and type(mset) == "string" then
        local role = pos <= T.LAST_PLAYER and "player" or (pos <= T.LAST_MANAGER and "manager" or "coach")
        parts[#parts + 1] = string.format("%s:%.0f:%s", role, base % 4294967296, mset)
        if role == "player" then counts.players = counts.players + 1
        elseif role == "manager" then counts.managers = counts.managers + 1
        else counts.coaches = counts.coaches + 1 end
      else
        skipped = skipped + 1
      end
    end
    local hasu, uniform = Call(T.SET_INFO, set, 0, 7)
    uniform = (hasu and type(uniform) == "number") and uniform % 4294967296 or 0
    return table.concat(parts, ","), uniform, string.format("team set %d: %d players, %d managers, %d coach, captain at %s, %d unreadable",
      set, counts.players, counts.managers, counts.coaches, tostring(captain), skipped)
  end
end
