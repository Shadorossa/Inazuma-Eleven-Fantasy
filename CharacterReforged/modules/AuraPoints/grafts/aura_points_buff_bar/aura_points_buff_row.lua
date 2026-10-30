-- Aura Points (mod aura_points): the buff row of the match HUD with one entry per aura user, up to the team limit of
-- transformed players (the VR-Framework's [rules] team_aura_max, CMND_VRFW_FORM_TEAM_MAX), instead of the retail 3.
-- Ported from Inazuma Fantasy's graft mx_popup (mx_popup_bar.lua): the retail main-chunk local t5 (the row's last
-- drawn state) grows in place and UpdateAuraBuffCharaIcon is the retail function with a per-pass table as long as t5,
-- bound to the retail locals (t5, n, n4) through lua_patch's EVT_DEBUG (EVT_UpvalueJoin). Without EVT_DEBUG nothing
-- changes (the retail entries).
-- * rows = min(team limit, the portrait layer's open instances: content\menus\buff_row.toml), never below the retail
--   count; t5 grows inside the wrapper (match time), never at chunk load. No limit (-1): every open instance.
-- * AuraPoints_BuffRow.Rows(): the entries of the row now (read by aura_points_buff_bar.lua for its bars).
-- * AuraPoints_BuffRow.drawn: the row's drawn state, the player on each portrait instance (retail or widened).
-- * AuraPoints_BuffRow.PoolsOn(): the mod's PEG or SP part is on (CMND_AURAPOINTS_ACTIVE_PARTS): while not, or not
--   known yet, the row keeps the retail count and aura_points_buff_bar.lua draws nothing.
-- * Face swaps in quick succession: a portrait instance whose face is swapped again while its previous face load may
--   still run (two row redraws a few frames apart, e.g. a player entering and leaving the row) could keep the blank
--   placeholder. Such an instance gets its last face swapped once more RESWAP_FRAMES later (R.Step, from the bar
--   block's Step wrapper); loader.log «aura_points buff row face swapped again».
-- Nothing at chunk load but the debug library's upvalue search; engine calls only inside the wrapper, through pcall.
@UPV@
AuraPoints_BuffRow = AuraPoints_BuffRow or {}
local R = AuraPoints_BuffRow

local CMD_TEAM_MAX = @crc:CMND_VRFW_FORM_TEAM_MAX@
local CMD_PARTS = @crc:CMND_AURAPOINTS_ACTIVE_PARTS@ --[[the mod's parts this start: ok, peg, sp, pe]]
local PORTRAIT = 1535165083 --[[soccer00_53_aura_buff_chara_icon]]
local CMND_IS_OPEN = @crc:CMND_IS_OPEN_LAYER@
local MEMBERS = 29 --[[the retail member loop of UpdateAuraBuffCharaIcon (0..28)]]
R.RESWAP_FRAMES = 30 --[[a second face swap of one instance within this many frames is redone this many frames later]]
R.frame = R.frame or 0
R.faces = R.faces or {} --[[portrait instance -> {hdl, metamorphosed, frame, redo}: its last face swap]]

-- the face swap of portrait instance i (the retail call), remembered for a later redo
function R.SwapFace(hdl, layer, i, metamorphosed)
  local last = R.faces[i]
  local redo = last ~= nil and R.frame - last.frame < R.RESWAP_FRAMES and R.frame + R.RESWAP_FRAMES or nil
  R.faces[i] = {hdl = hdl, layer = layer, metamorphosed = metamorphosed, frame = R.frame, redo = redo}
  SwapLayerFaceIconTexBySoccerCharaHdl(hdl, layer, i, 620971603, 1501523875, faceType, 1, true, true, true, false, metamorphosed)
end

-- every frame (the bar block's Step wrapper): the frame count and the face swaps due again
function R.Step()
  R.frame = R.frame + 1
  for i, f in pairs(R.faces) do
    if f.redo ~= nil and R.frame >= f.redo then
      f.redo = nil
      if IsInvalidSoccerCharaHdl(f.hdl) == false then
        SwapLayerFaceIconTexBySoccerCharaHdl(f.hdl, f.layer, i, 620971603, 1501523875, faceType, 1, true, true, true, false,
          f.metamorphosed)
        pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, "aura_points buff row face swapped again", i, string.format("0x%X", f.hdl))
      end
    end
  end
end

-- the portrait layer's open instances (the menu's layer count); 0 = unknown
function R.Instances()
  local n = 0
  while n < MEMBERS do
    local ok, open = pcall(funcLuaMenuCommand, CMND_IS_OPEN, PORTRAIT, n)
    if not ok or open ~= true then
      break
    end
    n = n + 1
  end
  return n
end

-- the mod's PEG or SP part is on; asked until the command answers (a busy script answers nothing for that frame: false
-- meanwhile), 600 frames without an answer: on
function R.PoolsOn()
  if R.pools_on ~= nil then
    return R.pools_on
  end
  R.asks = (R.asks or 0) + 1
  local ok, answered, peg, sp = pcall(funcLuaCommand, CMD_PARTS)
  if ok and answered == true then
    R.pools_on = peg == 1 or peg == true or sp == 1 or sp == true
  elseif R.asks >= 600 then
    R.pools_on = true
  end
  return R.pools_on == true
end

-- the entries the row may show now
function R.Rows()
  local base = R.retail or 0
  if R.t5 == nil or not R.PoolsOn() then
    return base
  end
  if R.cap == nil then
    local n = R.Instances()
    if n > 0 then
      R.cap = n
    end
  end
  local want = R.cap or base
  local ok, max = pcall(funcLuaCommand, CMD_TEAM_MAX)
  if ok and type(max) == "number" and max >= 0 then
    want = math.min(want, max)
  end
  return math.max(base, want)
end

function R.Grow()
  if R.t5 == nil then
    return
  end
  for k = #R.t5 + 1, R.Rows() do
    R.t5[k] = {auraCharaHdl = 0, auraAttr = 0}
  end
end

local t5 = EVT_UpvalueFind({"UpdateAuraBuffCharaIcon", "OnSetupLayer", "UpdateAuraActiveTimeGauge"}, function(t)
  return #t > 0 and type(t[1]) == "table" and t[1].auraCharaHdl ~= nil and t[1].auraAttr ~= nil
end)
-- the row's drawn state (t5[i + 1] = the player on portrait instance i): read by aura_points_buff_bar.lua to put each
-- bar / label on its player's portrait
R.drawn = t5
local retail_update = UpdateAuraBuffCharaIcon
if t5 ~= nil and type(retail_update) == "function" and retail_update ~= R.wrapper then
  local n, n4
  -- the retail UpdateAuraBuffCharaIcon; only its per-pass table follows #t5 (retail: 3 literal rows). Its upvalues must
  -- be the retail ones in the retail order (t5, _ENV, n, n4): no other local of this file is used inside, the row's
  -- helpers are reached through the global AuraPoints_BuffRow
  local widened = function()
    local n6 = 0
    local l1 = #t5
    local t6 = {}
    for k = 1, l1 do
      t6[k] = {auraCharaHdl = 0, auraAttr = 0}
    end
    for i = 0, 28 do
      local ret2, ret3 = funcLuaCommand(66484325, n, i, true)
      ret2, auraAttr = GetSoccerCharaInfo(ret3, 26)
      if ret2 and auraAttr ~= 0 then
        t6[n6 + 1].auraCharaHdl = ret3
        t6[n6 + 1].auraAttr = auraAttr
        n6 = n6 + 1
        if l1 <= n6 then
          break
        end
      end
    end
    n4 = n6
    local n7 = 1535165083 --[[soccer00_53_aura_buff_chara_icon]]
    local n8 = 698939060 --[[soccer00_54_aura_recast_gauge]]
    n6 = 0
    for i2 = 0, l1 - 1 do
      local aura_chara_hdl = t6[i2 + 1].auraCharaHdl
      local aura_attr = t6[i2 + 1].auraAttr
      local l2 = IsInvalidSoccerCharaHdl(aura_chara_hdl) == false
      local flag = false
      if t5[i2 + 1].auraCharaHdl ~= aura_chara_hdl or t5[i2 + 1].auraAttr ~= aura_attr then
        funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, n7, i2, l2)
        funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, n8, i2, l2)
        flag = true
      end
      t5[i2 + 1].auraCharaHdl = aura_chara_hdl
      t5[i2 + 1].auraAttr = aura_attr
      if flag then
        local n9 = 0
        local convert_aura_attr_to_aura_ty = ConvertAuraAttrToAuraType(aura_attr)
        n9 = GetSkillAuraCategoryIcon(convert_aura_attr_to_aura_ty)
        if n9 == 0 then
          n9 = 1815339204 --[[icon_sp_area05]]
        end
        local n10 = 3669916425
        funcLuaMenuCommand(558735651, n8, 502529699 --[[#/menu/200_icon/15_icon_common/<LG>/icon_common.g4tx]], n9, n10, 0, i2)
        local is_aura_skill_metamorphosed = IsAuraSkillMetamorphosed(convert_aura_attr_to_aura_ty)
        AuraPoints_BuffRow.SwapFace(aura_chara_hdl, n7, i2, is_aura_skill_metamorphosed)
      end
      local l3 = 68 * n6
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, n7, l3, 0, 0, i2)
      n6 = n6 + 1
    end
  end
  local ok, joined = pcall(EVT_UpvalueJoin, widened, retail_update)
  if ok and type(joined) == "number" and joined > 0 then
    R.t5 = t5
    R.retail = #t5
    R.wrapper = function(...)
      pcall(R.Grow)
      return widened(...)
    end
    UpdateAuraBuffCharaIcon = R.wrapper
  end
end
