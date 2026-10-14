-- BetterUI «Ajustes de la IA» (graft clean_hud_team_ai; docs/game/ui/team-commands.md §10). Ported from Inazuma
-- Fantasy's team commands (graft team_cmd_menus, evt_team_cmd_ai.lua) on 2026-10-14. soccer_performance_change_menu
-- (the «CELEBRACIÓN DE GOL» window: two columns of player rows, face + name + value) in AI-role mode: every row shows
-- the player's AI role (the game's own role names, the texts of the retail AI-role chooser), the retail title graphic
-- is hidden, and Enter opens the retail AI-role chooser (MENU_DEF.OpenSubWindowRoleAISettings) and applies the pick
-- like the retail per-player option «Configurar rol de la IA» (team_dock_formation_menu setting type 7):
--   766740776(team, type, index) -> role (-1 none, 0..3), 748531447(team, type, index, role) sets it; a role a team
--   mate already holds is cleared (-1) on him first.
-- The mode comes from the team dock (this graft's dock part, the COMANDOS row «Ajustes de la IA»): param store key
-- clean_hud_team_ai = 1, team type in clean_hud_team_ai_type, both consumed at OnInit. Key absent or 0 -> the retail
-- celebration screen (or BetterUI's shirt-number mode, graft clean_hud_shirt_number, which wraps the same globals:
-- both pass through when off).
-- Bytecode child: every retail function stays byte-identical; the retail globals are wrapped after the main chunk.
local TEAM_AI_KEY = @crc:clean_hud_team_ai@             -- param store: 1 = open the celebration screen in AI-role mode
local TEAM_AI_KEY_TYPE = @crc:clean_hud_team_ai_type@   -- param store: team type of the dock
local ROLE_TEXTS = {3547488057, 2081656054, 185908320, 2451434970, 3843743052} -- the retail chooser's rows: none, 0..3
local PLAYER_LIST = 3043452150      -- win05_35_performance_chara_list
local PLAYER_ROW = 1076657304       -- win05_36_performance_chara_list_item
local THIS_MENU = 927762597         -- soccer_performance_change_menu
local TITLE_MESH = @crc:_gtxt_performance01@
local TEAM_PARAM = 3357163798
local CURSOR_LAYER = 2296367164     -- cmn05_01_cursor
local BLACK_BACKGROUND = 3801549073 -- cmn02_01_blackbg
local SUB_WINDOW = 968210065        -- sub_window
local CMND_PARAM_HAS = 2947612279
local CMND_PARAM_GET = 3522198769
local CMND_PARAM_DELETE = 3363400568
local CMND_TEXT_GET = 4074371074
local CMND_SET_MESH_VISIBLE = 3405944500
local CMND_SET_LAYER_VISIBLE = 711242136
local CMND_SET_MENU_INPUT = 1558704558
local CMND_SET_DRAW_PRIORITY = 1491630496
local CMND_CLOSE_MENU_OBJECT = 320421347
local CMND_IS_OPEN_MENU_OBJECT = 3693934564
local CMND_IS_EXIST_MENU_OBJECT = 2231168902
local CMND_SUB_WINDOW_POSITION = 63483614
local CMND_TEAM_CHARA_INDEX = 2113285063
local CMND_TEAM_MEMBER_INFO = 1720957768 -- (team, type, index, what): 0 handle
local CMND_GET_AI_ROLE = 766740776
local CMND_SET_AI_ROLE = 748531447
local TEAM_SLOTS = 29               -- team member indices 0..28

BetterUI_TeamAI = {on = false, teamType = 0, team = nil, rows = {}, focused = nil, picked = nil}
local A = BetterUI_TeamAI

local function Log(...)
  if PRINT ~= nil then
    pcall(PRINT, "BetterUI team_ai", ...)
  end
end

local function ReadMode()
  local mode = 0
  if funcLuaCommand(CMND_PARAM_HAS, TEAM_AI_KEY) then
    mode = funcLuaCommand(CMND_PARAM_GET, TEAM_AI_KEY) or 0
    funcLuaCommand(CMND_PARAM_DELETE, TEAM_AI_KEY)
  end
  A.teamType = 0
  if funcLuaCommand(CMND_PARAM_HAS, TEAM_AI_KEY_TYPE) then
    A.teamType = funcLuaCommand(CMND_PARAM_GET, TEAM_AI_KEY_TYPE) or 0
    funcLuaCommand(CMND_PARAM_DELETE, TEAM_AI_KEY_TYPE)
  end
  A.on = mode == 1
  A.rows = {}
  A.focused = nil
  if funcLuaCommand(CMND_PARAM_HAS, TEAM_PARAM) then
    A.team = funcLuaCommand(CMND_PARAM_GET, TEAM_PARAM)
  end
  if A.on then
    Log("AI-role mode team", A.team, "type", A.teamType)
  end
end

local function Team()
  return A.team or 0
end

-- team index of a chara handle
local function TeamIndex(handle)
  if handle == nil or handle == 0 then
    return nil
  end
  local ok, index = funcLuaCommand(CMND_TEAM_CHARA_INDEX, Team(), A.teamType, handle)
  if not ok then
    return nil
  end
  return index
end

local function RoleOf(index)
  if index == nil then
    return nil
  end
  local ok, role = funcLuaCommand(CMND_GET_AI_ROLE, Team(), A.teamType, index)
  if ok and type(role) == "number" and role >= -1 and role < 4 then
    return role
  end
  return -1
end

local function SetRowText(row, handle)
  local text = "-"
  local role = RoleOf(TeamIndex(handle))
  if role ~= nil then
    text = funcLuaCommand(CMND_TEXT_GET, ROLE_TEXTS[role + 2]) or ""
  end
  _SetPerformanceText(PLAYER_ROW, row, text, false)
end

local function RefreshRows()
  for row, handle in pairs(A.rows) do
    SetRowText(row, handle)
  end
end

local function HideTitle()
  funcLuaMenuCommand(CMND_SET_MESH_VISIBLE, PLAYER_LIST, TITLE_MESH, false)
end

-- the role for team index `index`; a team mate holding the same role loses it first
local function SetRole(index, role)
  if role >= 0 then
    for slot = 0, TEAM_SLOTS - 1 do
      local ok, handle = funcLuaCommand(CMND_TEAM_MEMBER_INFO, Team(), A.teamType, slot, 0)
      if ok and handle ~= nil and handle ~= 0 then
        local ok_index, other = funcLuaCommand(CMND_TEAM_CHARA_INDEX, Team(), A.teamType, handle)
        if ok_index and other ~= index then
          local ok_role, held = funcLuaCommand(CMND_GET_AI_ROLE, Team(), A.teamType, other)
          if ok_role and held == role then
            funcLuaCommand(CMND_SET_AI_ROLE, Team(), A.teamType, other, -1)
            Log("role cleared", handle, role)
          end
        end
      end
    end
  end
  funcLuaCommand(CMND_SET_AI_ROLE, Team(), A.teamType, index, role)
  Log("role set", index, role)
end

-- the retail AI-role chooser for the focused player (as the retail per-player option opens it)
local function OpenRoleChooser()
  local handle = A.focused
  if handle == nil or handle == 0 then
    return
  end
  local index = TeamIndex(handle)
  if index == nil then
    return
  end
  local role = RoleOf(index) or -1
  A.picked = nil
  funcLuaMenuCommand(CMND_SET_MENU_INPUT, THIS_MENU, false)
  funcLuaMenuCommand(CMND_SET_DRAW_PRIORITY, BLACK_BACKGROUND, 0, 750, true)
  funcLuaMenuCommand(CMND_SET_LAYER_VISIBLE, CURSOR_LAYER, 0, false)
  MENU_DEF.OpenSubWindowRoleAISettings("BetterUI_TeamAI_OnRolePicked", "", role + 1)
  waitTrue(function()
    return funcLuaCommand(CMND_IS_OPEN_MENU_OBJECT, SUB_WINDOW, CURSOR_LAYER)
  end)
  funcLuaCommand(CMND_SUB_WINDOW_POSITION, 960, -350)
  waitFalse(function()
    return funcLuaMenuCommand(CMND_IS_EXIST_MENU_OBJECT, SUB_WINDOW)
  end)
  funcLuaMenuCommand(CMND_SET_DRAW_PRIORITY, BLACK_BACKGROUND, 0, 740, true)
  funcLuaMenuCommand(CMND_SET_LAYER_VISIBLE, CURSOR_LAYER, 0, true)
  funcLuaMenuCommand(CMND_SET_MENU_INPUT, THIS_MENU, true)
  local picked = A.picked
  if type(picked) == "number" and picked >= 0 and picked <= 4 then
    SetRole(index, picked - 1)
  end
  RefreshRows()
end

function BetterUI_TeamAI_OnRolePicked(pick)
  A.picked = pick
  funcLuaCommand(CMND_CLOSE_MENU_OBJECT, SUB_WINDOW)
end

-- ---------------------------------------------------------------- wrappers of the retail globals
local retailOnInit = OnInit
OnInit = function(...)
  ReadMode()
  return retailOnInit(...)
end

local retailInitInfo = InitPerformanceChangeMenuInfo
InitPerformanceChangeMenuInfo = function(team, ...)
  A.team = team
  return retailInitInfo(team, ...)
end

local retailSetupLayer = OnSetupLayer
OnSetupLayer = function(layer, index, ...)
  local results = table.pack(retailSetupLayer(layer, index, ...))
  if A.on and layer == PLAYER_LIST then
    HideTitle()
  end
  return table.unpack(results, 1, results.n)
end

local retailUpdateListItem = UpdateListItem
UpdateListItem = function(layer, row, handle, focused, ...)
  local results = table.pack(retailUpdateListItem(layer, row, handle, focused, ...))
  if A.on and layer == PLAYER_ROW and handle ~= nil then
    A.rows[row] = handle
    if focused then
      A.focused = handle
    end
    SetRowText(row, handle)
    HideTitle()
  end
  return table.unpack(results, 1, results.n)
end

local retailDecideFocus = OnDecideFocus
OnDecideFocus = function(layer, index, ...)
  if A.on and layer == PLAYER_LIST then
    return OpenRoleChooser()
  end
  return retailDecideFocus(layer, index, ...)
end
