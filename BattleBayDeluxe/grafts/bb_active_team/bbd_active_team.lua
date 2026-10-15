-- bb_chronicle_teams bb_active_team (enjoy_team_select_menu_campaign / _offline; docs/game/modes/estadio-bb.md §16).
-- The «Active team» tile (evt_bbd_active_team) plays the player's active team. 1.5.64 (owner 2026-10-14): its panel
-- previews that team, read from the active team set every time the panel draws the tile (bbd_active_team_common.lua):
--   * the pitch: the active team's players (the tile's member rows, mirrored first by BBD_ACTIVE_TEAM_Sync) on the
--     active team's FORMATION; a card whose row does not hold the active team's player of that position is hidden
--     (never a placeholder player);
--   * the tactics: the active team set's tactics slots;
--   * the crest behind the panel: the active team set's emblem;
--   * the team name: the active team set's name;
--   * the big portrait: the tile's Battle Bay row leader = the active team's captain (written by the mirror);
--   * the grid's crest and model: the tile's team record holds the active team's emblem and kit (the mirror runs
--     before the retail SetupEmblemIcon draws the tile's slot).
-- Whatever the active team cannot answer keeps the retail drawing of the tile (and its placeholder cards hidden, as
-- before). While the Draft screen holds the panel (graft bb_draft) its own wrappers decide. Globals only; nothing runs
-- at chunk load.
BBD_ACTIVE_TEAM = BBD_ACTIVE_TEAM or {}
do
  local B = BBD_ACTIVE_TEAM
  B.LEFT = 3003299608 --[[team00_01_chara_card_left]]
  B.RIGHT = 3825623416 --[[team00_01_chara_card_right]]
  B.FORMATION_LEFT = 1324325467
  B.FORMATION_RIGHT = 187604095
  B.TACTICS_LEFT = 2312417854
  B.TACTICS_RIGHT = 909193856
  B.CREST_LEFT = 2813867952
  B.CREST_RIGHT = 2785921709
  B.NAME_LEFT, B.NAME_RIGHT = 2945114490, 2708277675
  B.NAME_TEXT_LEFT, B.NAME_TEXT_RIGHT = 3778687894 --[[_text_team_name01]], 2016633388
  B.CARDS = 11
  B.TEAM_INFO = 2151743654
  B.MEMBER_INFO = 34355761
  B.FORMATION_INFO = 2649030357 --[[CMND_GET_SOCCER_FORMATION_INFO]]
  B.CARD_SETUP = 2339877830
  B.VISIBLE = 711242136 --[[CMND_SET_LAYER_VISIBLE]]
  B.MESH_VISIBLE = 3405944500 --[[CMND_SET_MESH_VISIBLE]]
  B.LAYER_NUM = 1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]]
  B.ICON_REQUEST = 3190452549
  B.TEXT = 1083631230 --[[CMND_SET_MENU_TEXT_STRING?]]
end

-- the panel side that shows the tile (true / nil = the left one, the player's): its player cards hidden
function BBD_ACTIVE_TEAM_HideCards(left)
  local B = BBD_ACTIVE_TEAM
  local layer = left and B.LEFT or B.RIGHT
  for i = 0, B.CARDS - 1 do
    funcLuaMenuCommand(B.VISIBLE, layer, i, false)
  end
end

-- the Draft screen holds the panel (graft bb_draft): its wrappers decide
function BBD_ACTIVE_TEAM_DraftHolds()
  return type(BBCR_DRAFT) == "table" and BBCR_DRAFT.mode ~= nil
end

-- the active team's data for the panel (mirrored onto the tile first), nil when it cannot be read
function BBD_ACTIVE_TEAM_Panel()
  local ok, d = pcall(BBD_ACTIVE_TEAM_Sync, "panel")
  if ok then
    return d
  end
  BBD_ACTIVE_TEAM_Log("panel error", tostring(d))
  return nil
end

-- the retail UpdateFormation of the tile with the active team's formation; only the cards whose member row holds the
-- active team's player of that position
function BBD_ACTIVE_TEAM_DrawFormation(team, left, d)
  local B = BBD_ACTIVE_TEAM
  local l1 = left and B.LEFT or B.RIGHT
  local l2 = left and B.FORMATION_LEFT or B.FORMATION_RIGHT
  local _, level = funcLuaCommand(B.TEAM_INFO, team, 4)
  level = level or 0
  funcLuaMenuCommand(B.VISIBLE, l2, 0, true)
  for i = 0, B.CARDS - 1 do
    funcLuaMenuCommand(B.VISIBLE, l1, i, false)
  end
  local shown = 0
  for i = 0, 15 do
    local ok, chara, pos, n4, flag = GetTeamMemberInfo(team, i)
    if ok and type(pos) == "number" and type(chara) == "number" and pos < B.CARDS and d.lineup[pos] ~= nil
      and d.lineup[pos] == math.floor(chara) % 4294967296 then
      local okb, bits = funcLuaCommand(B.FORMATION_INFO, 6, d.formation, pos)
      bits = okb and bits or 0
      local _, extra = funcLuaCommand(B.MEMBER_INFO, team, pos, 12)
      local drawn = funcLuaMenuCommand(B.CARD_SETUP, l1, pos, chara, false, false, bits, 0, n4, flag, false, extra, level)
      funcLuaMenuCommand(B.VISIBLE, l1, pos, drawn)
      if drawn then
        shown = shown + 1
        funcLuaMenuCommand(B.MESH_VISIBLE, l1, 69091055 --[[_icon_card02]], false, pos)
        funcLuaMenuCommand(B.MESH_VISIBLE, l1, 2843821468 --[[_icon_lock02]], false, pos)
        SetupFormationIconPosition(l1, pos, d.formation, l2, 0.8)
      end
    end
  end
  if B.logged_panel ~= d.text then
    B.logged_panel = d.text
    -- hex in two halves: the game's %X stops at 2^31
    local function hex(v)
      v = math.floor(v) % 4294967296
      return string.format("0x%04X%04X", math.floor(v / 65536), v % 65536)
    end
    BBD_ACTIVE_TEAM_Log(string.format("panel: team set %d, formation %s, %d of 11 starters drawn, captain %s",
      d.set, hex(d.formation), shown, hex(d.captain)))
  end
end

if UpdateFormation ~= nil then
  local formation = UpdateFormation
  function UpdateFormation(a1, a2, ...)
    local B = BBD_ACTIVE_TEAM
    if a1 ~= B.TEAM or BBD_ACTIVE_TEAM_DraftHolds() then
      return formation(a1, a2, ...)
    end
    local d = BBD_ACTIVE_TEAM_Panel()
    if d ~= nil and d.formation ~= nil then
      local ok, err = pcall(BBD_ACTIVE_TEAM_DrawFormation, a1, a2, d)
      if ok then
        return
      end
      BBD_ACTIVE_TEAM_Log("panel error", tostring(err))
    end
    -- no active team to show: the retail drawing without its placeholder players
    local r = table.pack(formation(a1, a2, ...))
    local ok, err = pcall(BBD_ACTIVE_TEAM_HideCards, a2 ~= false)
    if not ok then
      BBD_ACTIVE_TEAM_Log("panel error", tostring(err))
    end
    return table.unpack(r, 1, r.n)
  end
end

if UpdateTacticsLayer ~= nil then
  local tactics = UpdateTacticsLayer
  function UpdateTacticsLayer(a1, a2, ...)
    local B = BBD_ACTIVE_TEAM
    if a1 ~= B.TEAM or BBD_ACTIVE_TEAM_DraftHolds() then
      return tactics(a1, a2, ...)
    end
    local d = B.data or BBD_ACTIVE_TEAM_Panel()
    if d == nil then
      return tactics(a1, a2, ...)
    end
    local ok, err = pcall(function()
      local l1 = a2 and B.TACTICS_LEFT or B.TACTICS_RIGHT
      local n = funcLuaMenuCommand(B.LAYER_NUM, l1) or 0
      for i = 0, n - 1 do
        funcLuaMenuCommand(B.VISIBLE, l1, i, true)
        UpdateTacticsCmdLayerInfo(l1, i, d.tactics[i] or 0)
      end
    end)
    if not ok then
      BBD_ACTIVE_TEAM_Log("tactics error", tostring(err))
      return tactics(a1, a2, ...)
    end
  end
end

if UpdateBackgroundIcon ~= nil then
  local crest = UpdateBackgroundIcon
  function UpdateBackgroundIcon(a1, a2, ...)
    local B = BBD_ACTIVE_TEAM
    if a1 ~= B.TEAM or BBD_ACTIVE_TEAM_DraftHolds() then
      return crest(a1, a2, ...)
    end
    local d = B.data or BBD_ACTIVE_TEAM_Panel()
    if d == nil or d.emblem == nil then
      return crest(a1, a2, ...)
    end
    local l1 = a2 and B.CREST_LEFT or B.CREST_RIGHT
    local ok, err = pcall(funcLuaMenuCommand, B.ICON_REQUEST, l1, 0, 3275681157, 3208823925, d.emblem, 1)
    if not ok then
      BBD_ACTIVE_TEAM_Log("crest error", tostring(err))
      return crest(a1, a2, ...)
    end
  end
end

if UpdateTeamNameText ~= nil then
  local teamName = UpdateTeamNameText
  function UpdateTeamNameText(a1, a2, ...)
    local B = BBD_ACTIVE_TEAM
    local r = table.pack(teamName(a1, a2, ...))
    if a1 == B.TEAM and not BBD_ACTIVE_TEAM_DraftHolds() then
      local d = B.data or BBD_ACTIVE_TEAM_Panel()
      if d ~= nil and d.name ~= "" then
        pcall(funcLuaMenuCommand, B.TEXT, a2 and B.NAME_LEFT or B.NAME_RIGHT,
          a2 and B.NAME_TEXT_LEFT or B.NAME_TEXT_RIGHT, d.name)
      end
    end
    return table.unpack(r, 1, r.n)
  end
end

if SetupEmblemIcon ~= nil then
  local icon = SetupEmblemIcon
  function SetupEmblemIcon(a1, a2, ...)
    if a2 == BBD_ACTIVE_TEAM.TEAM and not BBD_ACTIVE_TEAM_DraftHolds() then
      local ok, err = pcall(BBD_ACTIVE_TEAM_Sync, "crest")
      if not ok then
        BBD_ACTIVE_TEAM_Log("crest sync error", tostring(err))
      end
    end
    return icon(a1, a2, ...)
  end
end
