-- EVT hud_layout, soccer_focus_battle_menu: time line under the «FOCO» banner (drawn by hud_layout_area_title.lua in
-- soccer_area_title_menu). The retail focus stopwatch (soccer08_23_focus_count_down, kept as is) shows the rate the
-- engine gives UpdateFocusCountDownTimer(rate, low) (the focus time limit, exe 0x14113160) or, once the rival has
-- decided and the player picks a technique, UpdateSkillDecideCountDownTimer(rate, low); each retail function ignores
-- the other phase (local flag). Both run with a proxy of funcLuaMenuCommand that only watches for the stopwatch's
-- rate command (1595998683 on bar_time01 of soccer08_23); every call passes through with exactly its arguments. The
-- rate the stopwatch got goes to the parameter store as per-mille (key evt_hl_timeline_focus). Engine calls only from
-- the wrapped callbacks.
EVT_HL_TIMELINE_ON = true

local HLF_KEY = 1435113398 --[[evt_hl_timeline_focus]]
local HLF_LAYER = 3070268158 --[[soccer08_23_focus_count_down]]
local HLF_MESH = 1261530200 --[[bar_time01]]
local HLF_CMND_RATE = 1595998683

local function HLF_Pack(...)
  return {n = select("#", ...), ...}
end

local function HLF_Spy(prev, ...)
  local real = rawget(_ENV, "funcLuaMenuCommand")
  if not EVT_HL_TIMELINE_ON or type(real) ~= "function" then
    return prev(...)
  end
  local seen
  rawset(_ENV, "funcLuaMenuCommand", function(...)
    local c, layer, mesh, _, v = ...
    if c == HLF_CMND_RATE and layer == HLF_LAYER and mesh == HLF_MESH and type(v) == "number" then
      seen = v
    end
    return real(...)
  end)
  local r = HLF_Pack(pcall(prev, ...))
  rawset(_ENV, "funcLuaMenuCommand", real)
  if not r[1] then
    error(r[2], 0)
  end
  if seen ~= nil and seen == seen and type(funcLuaCommand) == "function" then
    VRFW_Param.Clear(HLF_KEY)
    VRFW_Param.Set(HLF_KEY, math.floor(math.max(0, math.min(1, seen)) * 1000 + 0.5), "plain")
  end
  return table.unpack(r, 2, r.n)
end

local function HLF_Wrap(name)
  local prev = rawget(_ENV, name)
  if type(prev) ~= "function" then
    return
  end
  rawset(_ENV, name, function(...)
    return HLF_Spy(prev, ...)
  end)
end

HLF_Wrap("UpdateFocusCountDownTimer")
HLF_Wrap("UpdateSkillDecideCountDownTimer")
