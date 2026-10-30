-- EVT away_kit BEGIN
do
-- Kit picker "Local / Visitante" (docs/game/away-kit.md). The team kit is TeamInfo.uniformId (team-set field 7);
-- the Visitante variant is the retail uniform with the two model sets swapped (away shirt by default, home shirt
-- when the retail same-kit clash rule asks for the alternate). CMD_FUNC3 only switches the 3D PREVIEW of the focused
-- kit between Local and Visitante; decide (A) equips the kit (retail field 2, which writes the home uniform) and then,
-- when the preview shows Visitante, writes the twin with CMND_BETTERQOL_TEAM_UNIFORM (plugin utilities.dll of the mod
-- Utilities, feature away_kit; mask bit 524288 = picker on). The id lives in the save, so face icons, the dock, Kizuna and matches follow
-- it. Back (B) keeps the saved kit. The Y guide label is one word, the variant the focused kit shows now: «Local» or
-- «Visitante» (Utilities' text rows, ids crc32("away_kit.home") / crc32("away_kit.away"); CMND_VRFW_TEXT_ID first),
-- refreshed when it changes (Y preview, A commit, cursor move). The help line at the bottom stays retail.
UTIL_AK_KEY = 3114639549
UTIL_AK_CMD = @crc:CMND_BETTERQOL_TEAM_UNIFORM@
UTIL_AK_LOG = @crc:CMND_EVT_LOG@
UTIL_AK_BTN_ICON = 3794706590
UTIL_AK_BTN_KEY = 3421673595
UTIL_AK_PAIR_CMD = @crc:CMND_BETTERQOL_AK_PAIR@
-- home <-> away pairs: asked to the plugin (CMND_BETTERQOL_AK_PAIR, built from the item_config / uniform_config the game
-- loads, the mods' kits included) and cached per id. UTIL_AK_PAIR[u] = the twin of kit u, or the kit of twin u; nil =
-- none. No table of ids is shipped: a kit a mod or a game update adds gets its pair with no change here.
UTIL_AK_PAIR_NONE = {}
UTIL_AK_PAIR = setmetatable({}, {__index = function(t, u)
  if type(u) ~= "number" or u == 0 or UTIL_AK_PAIR_NONE[u] then
    return nil
  end
  local ok, p = pcall(funcLuaCommand, UTIL_AK_PAIR_CMD, u)
  if ok and type(p) == "number" and p ~= 0 then
    rawset(t, u, p)
    return p
  end
  if ok then
    UTIL_AK_PAIR_NONE[u] = true
  end
  return nil
end})
UTIL_AK_ON = false
UTIL_AK_SWAP_FROM = nil
UTIL_AK_SWAP_TO = nil
UTIL_AK_PEND_INV = 0
UTIL_AK_PEND_AWAY = false
-- Y guide labels: key -> crc32 of the key (the text_engine id unless it collides)
UTIL_AK_TXT = {
  ["away_kit.home"] = 2538732682,
  ["away_kit.away"] = 1087918731,
}
UTIL_AK_TXT_ID = {}
-- the label the button guide shows now (nil = guide not built yet)
UTIL_AK_BTN_SHOWN = nil
function UTIL_AK_TextId(key)
  if UTIL_AK_TXT_ID[key] == nil then
    local ok, id = pcall(funcLuaCommand, @crc:CMND_VRFW_TEXT_ID@, key)
    UTIL_AK_TXT_ID[key] = (ok and type(id) == "number" and id ~= 0) and id or UTIL_AK_TXT[key]
  end
  return UTIL_AK_TXT_ID[key]
end
function UTIL_AK_Check()
  UTIL_AK_ON = false
  local api, mods = funcLuaCommand(@crc:CMND_EVT_LOADER_VERSION@)
  if api == false or api == nil or mods == nil or math.floor(mods / 524288) % 2 ~= 1 then
    return
  end
  UTIL_AK_ON = true
end
function UTIL_AK_Log(a, b, c, d, e)
  if UTIL_AK_ON then
    pcall(funcLuaCommand, UTIL_AK_LOG, "EVT_AK " .. tostring(a), tostring(b), tostring(c), tostring(d), tostring(e))
  end
end
function UTIL_AK_TeamUniform()
  local ok, u = funcLuaCommand(@crc:CMND_GET_TEAM_SET_INFO@, n4, 0, 7)
  if not ok or u == nil then
    return 0
  end
  return u
end
function UTIL_AK_EquippedInv()
  local ok, h = funcLuaCommand(@crc:CMND_GET_TEAM_SET_INFO@, n4, 0, 12)
  if not ok or h == nil then
    return 0
  end
  return h
end
function UTIL_AK_ItemUniform(inv)
  if inv == nil or inv == 0 then
    return 0
  end
  local id = funcLuaCommand(2662166687, inv, 0)
  if not id or id == 0 then
    return 0
  end
  local ok, u = funcLuaCommand(845816129, id)
  if not ok or u == nil then
    return 0
  end
  return u
end
function UTIL_AK_IsAway()
  if not UTIL_AK_ON then
    return false
  end
  local u = UTIL_AK_ItemUniform(UTIL_AK_EquippedInv())
  local t = UTIL_AK_TeamUniform()
  -- the team wears a twin of its kit item (any candidate twin maps back to the kit)
  return u ~= 0 and t ~= 0 and t ~= u and UTIL_AK_PAIR[u] ~= nil and UTIL_AK_PAIR[t] == u
end
-- variant shown for a row: the unsaved preview if any, else the saved variant (equipped kit) or Local
function UTIL_AK_ViewAway(inv)
  if not UTIL_AK_ON or inv == nil or inv == 0 then
    return false
  end
  if UTIL_AK_PEND_INV == inv then
    return UTIL_AK_PEND_AWAY
  end
  return inv == UTIL_AK_EquippedInv() and UTIL_AK_IsAway()
end
function UTIL_AK_FocusUniform(u)
  if UTIL_AK_ON and u ~= nil and u ~= 0 then
    local k = UTIL_AK_ItemUniform(UTIL_AK_EquippedInv())
    if k ~= 0 and k ~= u and UTIL_AK_PAIR[k] ~= nil and UTIL_AK_PAIR[u] == k then
      return k
    end
  end
  return u
end
-- text id of the Y label for the focused kit: «Visitante» when it shows the away variant, else «Local»
function UTIL_AK_BtnText()
  local key = "away_kit.home"
  if UTIL_AK_ViewAway(n3) then
    key = "away_kit.away"
  end
  UTIL_AK_BTN_SHOWN = key
  return UTIL_AK_TextId(key)
end
-- rebuild the button guide when the focused kit's variant no longer matches the label
function UTIL_AK_RefreshGuide()
  if not UTIL_AK_ON or UTIL_AK_BTN_SHOWN == nil then
    return
  end
  local key = UTIL_AK_ViewAway(n3) and "away_kit.away" or "away_kit.home"
  if key ~= UTIL_AK_BTN_SHOWN then
    UpdateButtonGuide()
  end
end
function UTIL_AK_RefreshPreview()
  local cur = n3
  if cur ~= nil and cur ~= 0 then
    n3 = 0
    UpdateItemEquipMenu(cur)
  end
end
function UTIL_AK_Toggle()
  if not UTIL_AK_ON or n3 == nil or n3 == 0 then
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
    return
  end
  local u = UTIL_AK_ItemUniform(n3)
  if u == 0 or UTIL_AK_PAIR[u] == nil then
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
    return
  end
  local away = not UTIL_AK_ViewAway(n3)
  UTIL_AK_PEND_INV, UTIL_AK_PEND_AWAY = n3, away
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
  UTIL_AK_Log("preview", n3, u, away)
  UTIL_AK_RefreshPreview()
  UTIL_AK_RefreshGuide()
end
local UTIL_AK_OnInit_retail = OnInit
function OnInit()
  UTIL_AK_OnInit_retail()
  UTIL_AK_Check()
end
local UTIL_AK_OnEnter_retail = OnEnter
function OnEnter(a1, a2)
  local inv = n3
  local away = UTIL_AK_ViewAway(inv)
  UTIL_AK_OnEnter_retail(a1, a2)
  if UTIL_AK_ON and inv ~= nil and inv ~= 0 then
    local u = UTIL_AK_ItemUniform(inv)
    local p = UTIL_AK_PAIR[u]
    if away and p ~= nil then
      local ok = funcLuaCommand(UTIL_AK_CMD, n4, 0, p)
      if not ok then
        funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
      end
      UTIL_AK_Log("commit Visitante", n4, u, p, ok)
    else
      UTIL_AK_Log("commit Local", n4, u, UTIL_AK_TeamUniform(), true)
    end
    UTIL_AK_PEND_INV, UTIL_AK_PEND_AWAY = 0, false
    UTIL_AK_RefreshPreview()
  end
  UTIL_AK_RefreshGuide()
end
local UTIL_AK_OnFunction_retail = OnFunction
function OnFunction(a1, a2)
  if a1 == UTIL_AK_KEY then
    UTIL_AK_Toggle()
    return
  end
  return UTIL_AK_OnFunction_retail(a1, a2)
end
local UTIL_AK_Check_retail = CheckTeamDockUniformEquip
function CheckTeamDockUniformEquip(a1, a2)
  if UTIL_AK_Check_retail(a1, a2) then
    return true
  end
  if not UTIL_AK_ON or a2 == nil or UTIL_AK_PAIR[a2] == nil then
    return false
  end
  local t = GetTeamDockUniformId(a1)
  return t ~= nil and t ~= a2 and UTIL_AK_PAIR[t] == a2 and UTIL_AK_ItemUniform(UTIL_AK_EquippedInv()) == a2
end
local UTIL_AK_UpdateItemEquipMenu_retail = UpdateItemEquipMenu
function UpdateItemEquipMenu(a1)
  UTIL_AK_SWAP_FROM, UTIL_AK_SWAP_TO = nil, nil
  if UTIL_AK_PEND_INV ~= 0 and a1 ~= UTIL_AK_PEND_INV then
    UTIL_AK_PEND_INV, UTIL_AK_PEND_AWAY = 0, false
  end
  if UTIL_AK_ViewAway(a1) then
    local u = UTIL_AK_ItemUniform(a1)
    local p = UTIL_AK_PAIR[u]
    if u ~= 0 and p ~= nil then
      UTIL_AK_SWAP_FROM, UTIL_AK_SWAP_TO = u, p
    end
  end
  local r = table.pack(UTIL_AK_UpdateItemEquipMenu_retail(a1))
  UTIL_AK_RefreshGuide()
  return table.unpack(r, 1, r.n)
end
local UTIL_AK_UpdateCharaModel_retail = UpdateCharaModel
function UpdateCharaModel(a1, a2, a3, ...)
  if UTIL_AK_SWAP_FROM ~= nil and a3 == UTIL_AK_SWAP_FROM then
    a3 = UTIL_AK_SWAP_TO
  end
  return UTIL_AK_UpdateCharaModel_retail(a1, a2, a3, ...)
end
end
-- EVT away_kit END
