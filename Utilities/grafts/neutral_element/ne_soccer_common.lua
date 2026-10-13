-- Utilities neutral element (docs/game/ui/neutral-element-icon.md): the «neutro» element icon (purple ensō, sprites
-- icon_cmd_type00 / icon_cmd_on_type00 / icon_focus_type00 / icon_type00 in icon_common.g4tx, gaiji_cmd_type00 in
-- gaiji_game.g4tx; research/scripts/neutral_element_build.py).
--
-- Child of the retail soccer_common bytecode: runs once each time a menu VM INCLUDEs LUA_SOCCER_COMMON, after every
-- soccer_common global exists. It only wraps Lua globals (no engine call at load; funcLuaCommand is looked up when a
-- wrapper runs). Retail answers 0 («no icon») for elements outside 1..4; the wrappers answer the neutral sprite for
--   characters: element 0 (coaches, managers, mod characters) and 5 («void»)
--   skills:     element 5 («vacío»; 0 = no element stays without icon, as in retail)
-- Every wrapper forwards all arguments and returns what retail returns in every other case.

UTIL_NEUTRAL = UTIL_NEUTRAL or {}
UTIL_NEUTRAL.CMD = {{icon_cmd_type00}}
UTIL_NEUTRAL.ON = {{icon_cmd_on_type00}}
UTIL_NEUTRAL.FOCUS = {{icon_focus_type00}}
UTIL_NEUTRAL.TYPE = {{icon_type00}}
UTIL_NEUTRAL.GAIJI = "[$gaiji_cmd_type00]"
UTIL_NEUTRAL.prev = UTIL_NEUTRAL.prev or {}

function UTIL_NeutralChara(el)
  return el == 0 or el == 5
end

-- the original of global `name`, kept once per VM (a second run of this block must not wrap the wrapper)
local function orig(name)
  local P = UTIL_NEUTRAL.prev
  if P[name] == nil then
    P[name] = _ENV[name]
  end
  return P[name]
end

-- character by chara status handle: player status plates (UpdateCharaStatusPlateInfo*), focus battle, ...
if orig("GetCharaElementIconNameByCharaStHdl") ~= nil then
  function GetCharaElementIconNameByCharaStHdl(a1, ...)
    local r = UTIL_NEUTRAL.prev.GetCharaElementIconNameByCharaStHdl(a1, ...)
    if r == 0 and a1 ~= nil and a1 ~= 0 and not IsInvalidSoccerCharaHdl(a1) then
      if UTIL_NeutralChara(funcLuaCommand(1131797651, a1, 8)) then
        return UTIL_NEUTRAL.CMD
      end
    end
    return r
  end
end

-- character by chara param id: formation lists, plates by param, match results, mode-change plate, ...
if orig("GetCharaElementIconNameByCharaParamId") ~= nil then
  function GetCharaElementIconNameByCharaParamId(a1, ...)
    local r = UTIL_NEUTRAL.prev.GetCharaElementIconNameByCharaParamId(a1, ...)
    if r == 0 and a1 ~= nil and a1 ~= 0 then
      local ok, el = funcLuaCommand(4060384944 --[[CMND_GET_CHARA_INFO]], a1, 13)
      if ok and UTIL_NeutralChara(el) then
        return UTIL_NEUTRAL.CMD
      end
    end
    return r
  end
end

-- character by soccer handle (match): member change, zone, VS window, focus battle
if orig("GetSoccerCharaElementIcon") ~= nil then
  function GetSoccerCharaElementIcon(a1, ...)
    local r = UTIL_NEUTRAL.prev.GetSoccerCharaElementIcon(a1, ...)
    if r == 0 then
      local ok, el = GetSoccerCharaParamBySoccerHdl(a1, 8)
      if ok ~= false and UTIL_NeutralChara(el) then
        return UTIL_NEUTRAL.CMD
      end
    end
    return r
  end
end

-- element number -> icon (mostly skill elements: ability board, aura / equip lists, special training, VS skill)
if orig("GetElementIcon") ~= nil then
  function GetElementIcon(a1, ...)
    if a1 == 5 then
      return UTIL_NEUTRAL.CMD
    end
    return UTIL_NEUTRAL.prev.GetElementIcon(a1, ...)
  end
end

-- skill element as an inline text icon (parameter screen)
if orig("GetSkillElementGaijiTexture") ~= nil then
  function GetSkillElementGaijiTexture(a1, ...)
    if a1 == 5 then
      return UTIL_NEUTRAL.GAIJI
    end
    return UTIL_NEUTRAL.prev.GetSkillElementGaijiTexture(a1, ...)
  end
end

-- skill info element icon (ability lists): retail hides the icon quad for element 5; show the neutral sprite
if orig("SetupSpecialSkillInfoElementIcon") ~= nil then
  function SetupSpecialSkillInfoElementIcon(a1, a2, a3, a4, ...)
    local r = {UTIL_NEUTRAL.prev.SetupSpecialSkillInfoElementIcon(a1, a2, a3, a4, ...)}
    local ok, el = funcLuaCommand(2580586398, a3, 7)
    if ok and el == 5 then
      local slot = a4 and a4 or 917245562 --[[icon_cmd_type_dmy01]]
      funcLuaMenuCommand(558735651, a1, 502529699 --[[icon_common <LG>]], UTIL_NEUTRAL.CMD, slot, 0, a2)
      funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], a1, 1255155594 --[[_icon_cmd_type_dmy01]], true, a2)
      funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], a1, 2172872396 --[[_icon_cmd_type_base01]], true, a2)
    end
    return table.unpack(r)
  end
end
