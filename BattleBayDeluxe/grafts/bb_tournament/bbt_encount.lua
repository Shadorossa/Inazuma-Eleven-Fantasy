-- bb_chronicle_teams bb_tournament, the loading telop's path (fade_menu_encount, the Campaña variant; Battle Bay Deluxe
-- 1.5.47, owner 2026-10-13). Before each Battle Bay campaign match the telop shows the next rival's crest and, under
-- it, the path as a zig-zag row of hexagon nodes (vs01_43, attached to the telop vs11_02's joints _atc_listNN): the
-- beaten rivals' crests, the next one lit, «?» for the rest. Retail: always 7 (the Campaña's 7 rivals). Now the row
-- has as many nodes as the mode the match belongs to can have: CMND_BBD_TOURN_CAMPAIGN_INFO(4) answers it (a
-- tournament match: the champion's match count of its format and size, T.player_matches; any other campaign match:
-- the Campaña block's rival count). The menu (content\menus\bb_tournament.toml) has 12 node instances and a telop
-- layout with 12 joints (evt_bbd_vs11_02: the retail 7 + _atc_list08 .. _atc_list12); here the joints are placed
-- for the count, centred on the screen as the retail 7 (the middle node at x 960), the retail spacing (100 px, every
-- other node 55 px lower) shrunk (with the nodes) only when the row would pass ROW_MAX; the nodes past the count
-- are hidden. With 7 nodes the row is the retail one. Globals only (BBT_ENC); nothing runs at chunk load.
BBT_ENC = {
  TELOP = 1108953785 --[[vs11_02_next_enemy_telop_on_loading]],
  NODE = 106197494 --[[vs01_43_enjoy_team_select_emblem_icon]],
  NODE_POS = 2575768773,        -- (layer, idx, node, axis 0 x / 1 y, value): a joint's local translation
  -- the retail layout (vs11_02.g4pkm): the joints hang from _pos_list01 (screen x 660), _atc_list01 at local (0, 0),
  -- each next one 100 px right, every other one 55 px lower (y up: -55); the middle one (4th) at x 960
  STEP = 100, ZIG = 55, MID = 300, RETAIL = 7,
  ROW_MAX = 1400,               -- px: the widest row (first to last node centre) before the spacing shrinks
  k = nil, joints = nil,
}

function BBT_EncLog(...)
  pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "bb_chronicle_teams path", ...)
end

-- the nodes this telop shows (once per opening): the scripts' answer, the last INFO's, else the retail count;
-- never more than the node instances the menu has
function BBT_EncCount()
  local E = BBT_ENC
  if E.k ~= nil then
    return E.k
  end
  local n
  local ok, handled, v = pcall(funcLuaCommand, BBT.CI, 4, 0)
  if ok and handled == true and type(v) == "number" and v > 0 then
    n = v
  elseif type(BBT_INFO) == "table" and type(BBT_INFO.path) == "number" and BBT_INFO.path > 0 then
    n = BBT_INFO.path
  else
    n = E.RETAIL
  end
  local cap = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], E.NODE) or E.RETAIL
  if n > cap then
    BBT_EncLog("path of", n, "nodes, the menu has", cap)
    n = cap
  end
  E.k = n
  BBT_EncLog("path nodes", n)
  return n
end

-- spacing and node scale for k nodes
function BBT_EncSpacing(k)
  local E = BBT_ENC
  local step = E.STEP
  if k > 1 and step * (k - 1) > E.ROW_MAX then
    step = E.ROW_MAX / (k - 1)
  end
  return step, step / E.STEP
end

-- the telop's joints placed for the count (its instance i)
function BBT_EncPlace(i)
  local E = BBT_ENC
  local k = BBT_EncCount()
  if E.joints == nil then
    E.joints = {}
    for j = 1, funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], E.NODE) or E.RETAIL do
      E.joints[j] = BBT_Crc(string.format("_atc_list%02d", j))
    end
  end
  local step, s = BBT_EncSpacing(k)
  for j = 1, k do
    local x = E.MID + (j - 1 - (k - 1) / 2) * step
    local y = (j % 2 == 0) and -E.ZIG * s or 0
    pcall(funcLuaCommand, E.NODE_POS, E.TELOP, i or 0, E.joints[j], 0, x)
    pcall(funcLuaCommand, E.NODE_POS, E.TELOP, i or 0, E.joints[j], 1, y)
  end
end

do
  local setup_param = SetupParam
  if type(setup_param) == "function" then
    function SetupParam(...)
      BBT_ENC.k = nil
      return setup_param(...)
    end
  end
  local setup = OnSetupLayer
  function OnSetupLayer(a1, a2, ...)
    local r = table.pack(setup(a1, a2, ...))
    if a1 == BBT_ENC.TELOP then
      local ok, err = pcall(BBT_EncPlace, a2)
      if not ok then
        BBT_EncLog("error", tostring(err))
      end
    elseif a1 == BBT_ENC.NODE then
      local ok, err = pcall(function()
        local k = BBT_EncCount()
        if (a2 or 0) >= k then
          funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], a1, a2 or 0, false)
          return
        end
        local _, s = BBT_EncSpacing(k)
        if s < 1 then
          funcLuaMenuCommand(3778714801 --[[CMND_SET_LAYER_SCALE]], a1, s, s, 1, a2 or 0)
        end
        BBT_EncPlace(0)
      end)
      if not ok then
        BBT_EncLog("error", tostring(err))
      end
    end
    return table.unpack(r, 1, r.n)
  end
end
