-- VRFW › archetypes declared by mods: the match HUD. The controlled player's circle
-- shows his side's build gauge icon (retail: only builds 0-5); for a side whose archetype is a declared one the
-- declared gauge icon is put there, and each rank it gains plays the circle's charge-up animation (the game's
-- PlayBuildChargeUpEffectAnime), polled from StepSoccerMenu. No engine call at load time.

VRFW_Archetype = VRFW_Archetype or {}
local A = VRFW_Archetype
A.CMD_MATCH = A.CMD_MATCH or 2854479468  -- CMND_VRFW_ARCHETYPE_MATCH
A.CMD_INFO = A.CMD_INFO or 3552358290    -- CMND_VRFW_ARCHETYPE_INFO

local CIRCLE = 2516761505      -- soccer02_20_ctrl_chara_circle_player
local GAUGE_TEX = 529055163    -- the circle's build gauge atlas (retail OnSetupSoccerMenuLayer)
local GAUGE_DMY = 1420168921   -- icon_build_gauge01: the retail slot the icon goes on
local POLL = 15                -- frames between two polls of the rank

local function self_side()
  if type(GetTeamNoSelf) ~= "function" then return nil end
  local ok, t = pcall(GetTeamNoSelf)
  if ok and (t == 0 or t == 1) then return t end
  return nil
end

local function side_archetype(side)
  if side == nil then return nil end
  local ok, b, rank = pcall(funcLuaCommand, A.CMD_MATCH, side)
  if ok and type(b) == "number" and b >= 7 then return b, rank or 0 end
  return nil
end

local function gauge_icon(b)
  local ok, has, _, _, _, _, gauge = pcall(funcLuaCommand, A.CMD_INFO, b)
  if ok and has == true and type(gauge) == "number" and gauge ~= 0 then return gauge end
  return nil
end

A.soccer_menu = A.soccer_menu or {}
local W = A.soccer_menu
local st = { frames = 0, rank = nil }

local function wrap(name, make)
  local cur = _G[name]
  if type(cur) ~= "function" or cur == W[name] then return end
  W[name] = make(cur)
  _G[name] = W[name]
end

wrap("OnInitSoccerMenu", function(orig)
  return function(...)
    local r = orig(...)
    st.frames, st.rank = 0, nil
    return r
  end
end)

wrap("OnSetupSoccerMenuLayer", function(orig)
  return function(a1, a2, ...)
    local r = orig(a1, a2, ...)
    if a1 == CIRCLE then
      local b = side_archetype(self_side())
      local icon = b and gauge_icon(b)
      if icon then pcall(funcLuaMenuCommand, 558735651, a1, GAUGE_TEX, icon, GAUGE_DMY, 0, a2) end
    end
    return r
  end
end)

wrap("StepSoccerMenu", function(orig)
  return function(...)
    local r = orig(...)
    st.frames = st.frames + 1
    if st.frames >= POLL then
      st.frames = 0
      local b, rank = side_archetype(self_side())
      if b then
        if st.rank ~= nil and rank > st.rank and type(PlayBuildChargeUpEffectAnime) == "function" then
          pcall(PlayBuildChargeUpEffectAnime, st.rank, math.min(rank, 5))
        end
        st.rank = rank
      else
        st.rank = nil
      end
    end
    return r
  end
end)
