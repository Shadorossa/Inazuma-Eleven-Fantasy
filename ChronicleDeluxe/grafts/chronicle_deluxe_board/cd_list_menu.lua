-- Chronicle Deluxe, the Chronicle team list (vs_route_town_list_menu; docs/game/mods/chronicle-deluxe.md §8.9): only
-- the difficulties a piece offers (VRFW_MatchDifficulty, this mod's content\defaults\match_difficulty.toml: Crónica +
-- Batalla heroica on normal pieces, the gate battle on gate pieces). Wrappers of the retail globals, appended to the
-- script (no text patch of a retail function); nothing runs at load but definitions.
--   * each row's orb bar (UpdateItem): the orbs of those difficulties on a bar with one socket each, centred
--     (ChronicleDeluxe.OrbBar, cd_orb_bar.lua)
--   * the info window (SetInfoWindowClassName, layout vsroute01_10b): the battle-kind rows of the other difficulties are
--     hidden (socket, orb, class title), the shown rows move up into the first slots, and the window ends right under
--     the last one: the window quad and the rows' vertical line lose the gap, the reward block moves up by it
-- With Inazuma Fantasy's Chronicle redesign active (its global EVT_ChrList, graft chronicle_redesign: the same rules,
-- its own layouts) these wrappers pass: one implementation.
@ORB_BAR@
ChronicleDeluxe = ChronicleDeluxe or {}
ChronicleDeluxe.List = ChronicleDeluxe.List or {}
local T = ChronicleDeluxe.List
T.CMD = {
  NODE_TRANSLATION = 1856671416,  -- (layer, instance, node, x, y, z)
  NODE_SCALE = 2885415772,        -- (layer, instance, node, width, height)
  MESH_VISIBLE = 3405944500,      -- CMND_SET_MESH_VISIBLE (layer, mesh, visible, instance)
  LOCATOR_VISIBLE = 2158717427,   -- (layer, locator, visible[, instance])
  FOCUSED_PIECE = 3963237677,     -- (2): the piece index of the focused row (the retail OnChangeFocus query)
}
T.CLEAR_ICON_LAYER = 2638032167   -- vsroute01_06c_town_map_piece_clear_icon: one instance per row
T.INFO_LAYER = 1917737414         -- vsroute01_10b_info_window
T.GATE = 5                        -- eventType of a gate piece
-- the info window's battle-kind rows (retail layout vsroute01_10b, v7.1.2; key = the row's orb locator, the
-- iconLocatorName of the script's rows): its socket mesh and class-title mesh with their local translations
T.INFO_ROWS = {
  [1611754387] = {socket = 2360951974, socket_x = 1320, socket_y = -568, title = 1941222059, title_x = 1380, title_y = -535}, -- normal 01
  [4179114537] = {socket = 363861276, socket_x = 1320, socket_y = -626, title = 3938312977, title_x = 1380, title_y = -593},  -- normal 02
  [2384399039] = {socket = 1656169866, socket_x = 1320, socket_y = -684, title = 2646266759, title_x = 1380, title_y = -651}, -- normal 03
  [276537116] = {socket = 4241731625, socket_x = 1320, socket_y = -742, title = 64898596, title_x = 1380, title_y = -711},    -- normal 04
  [4269145648] = {socket = 316526853, socket_x = 1320, socket_y = -800, title = 3989841672, title_x = 1380, title_y = -771},  -- normal 06
  [2027773323] = {socket = 2423024043, socket_x = 1320, socket_y = -858, title = 2766389377, title_x = 1380, title_y = -831}, -- normal 08_01
  [1736224650] = {socket = 2345959615, socket_x = 1310, socket_y = -613, title = 1960408754, title_x = 1346, title_y = -570}, -- gate 05
  [2306002598] = {socket = 1708843411, socket_x = 1310, socket_y = -713, title = 2597787550, title_x = 1346, title_y = -670}, -- gate 07
  [3788770353] = {socket = 157628433, socket_x = 1310, socket_y = -813, title = 1038782779, title_x = 1346, title_y = -770}   -- gate 08_02
}
-- the parts the window fit changes (node scale = the quad's px size, translation = local, y up; retail values)
T.INFO_FIT = {
  window = {node = 2590547560 --[[_vsroute_win_base01]], width = 616, height = 1080},
  line = {node = 2875746849 --[[_vsroute_win_line02]], width = 8, height = 351},
  reward = {node = 1919723323 --[[_pos_present01]], x = -1540, y = 490}
}
T.info_gap = nil                  -- the gap applied last (re-cut only when it changes; reset when the window opens)

function T.IfOwns()
  return EVT_ChrList ~= nil
end

-- {[difficulty] = true} of a piece kind; nil = nothing declared (retail)
function T.Shown(kind)
  return VRFW_MatchDifficulty ~= nil and VRFW_MatchDifficulty.Set(kind == T.GATE and "gate" or "route") or nil
end

-- the script's rows of a piece kind as two arrays (retail difficulty, orb locator)
function T.Slots(kind)
  local rows = GetInfoWindowDifficultyArray(kind)
  local difficulties, locators = {}, {}
  for i = 1, #(rows or {}) do
    difficulties[i], locators[i] = rows[i].difficultyType, rows[i].iconLocatorName
  end
  return difficulties, locators
end

function T.FitInfo(gap)
  if gap == nil or gap < 0 then
    gap = 0
  end
  if T.info_gap == gap then
    return
  end
  T.info_gap = gap
  local f, L = T.INFO_FIT, T.INFO_LAYER
  funcLuaMenuCommand(T.CMD.NODE_SCALE, L, 0, f.window.node, f.window.width, f.window.height - gap)
  funcLuaMenuCommand(T.CMD.NODE_SCALE, L, 0, f.line.node, f.line.width, math.max(8, f.line.height - gap))
  funcLuaMenuCommand(T.CMD.NODE_TRANSLATION, L, 0, f.reward.node, f.reward.x, f.reward.y + gap, 0)
end

function T.InfoRows(kind, rows)
  local shown = T.Shown(kind)
  if shown == nil or rows == nil or #rows == 0 then
    return
  end
  local L = T.INFO_LAYER
  local placed = 0
  for i = 1, #rows do
    local row = rows[i]
    local from = T.INFO_ROWS[row.iconLocatorName]
    if from ~= nil then
      if shown[row.difficultyType] then
        placed = placed + 1
        local to = T.INFO_ROWS[rows[placed].iconLocatorName] or from
        funcLuaMenuCommand(T.CMD.NODE_TRANSLATION, L, 0, from.socket, to.socket_x, to.socket_y, 0)
        funcLuaMenuCommand(T.CMD.NODE_TRANSLATION, L, 0, from.title, to.title_x, to.title_y, 0)
        funcLuaMenuCommand(T.CMD.NODE_TRANSLATION, L, 0, row.iconLocatorName, 0, to.socket_y - from.socket_y, 0)
        funcLuaMenuCommand(T.CMD.MESH_VISIBLE, L, from.socket, true, 0)
        funcLuaMenuCommand(T.CMD.MESH_VISIBLE, L, from.title, true, 0)
      else
        funcLuaMenuCommand(T.CMD.MESH_VISIBLE, L, from.socket, false, 0)
        funcLuaMenuCommand(T.CMD.MESH_VISIBLE, L, from.title, false, 0)
        funcLuaMenuCommand(T.CMD.LOCATOR_VISIBLE, L, row.iconLocatorName, false)
      end
    end
  end
  local last = T.INFO_ROWS[rows[#rows].iconLocatorName]
  local last_shown = placed > 0 and T.INFO_ROWS[rows[placed].iconLocatorName] or nil
  T.FitInfo((last ~= nil and last_shown ~= nil) and (last_shown.title_y - last.title_y) or 0)
end

local previous_update_item = UpdateItem
function UpdateItem(a1, a2, a3, a4, a5, ...)
  local r = table.pack(previous_update_item(a1, a2, a3, a4, a5, ...))
  if not T.IfOwns() then
    local ok, kind = GetTownMapResourceEvent(a5, 1, true)
    if ok then
      local layout_kind = kind == T.GATE and T.GATE or 0
      local difficulties, locators = T.Slots(kind)
      ChronicleDeluxe.OrbBar.Fit(T.CLEAR_ICON_LAYER, a2, layout_kind, difficulties, locators)
    end
  end
  return table.unpack(r, 1, r.n)
end

local previous_set_info_window_class_name = SetInfoWindowClassName
function SetInfoWindowClassName(a1, ...)
  local r = table.pack(previous_set_info_window_class_name(a1, ...))
  if not T.IfOwns() then
    local piece = funcLuaMenuCommand(T.CMD.FOCUSED_PIECE, 2)
    local ok, kind = GetTownMapResourceEvent(piece, 1, true)
    if not ok then
      kind = 0
    end
    T.InfoRows(kind, GetInfoWindowDifficultyArray(kind))
  end
  return table.unpack(r, 1, r.n)
end

-- the window comes back in its layout pose when it opens again: forget the cut
local previous_open_close_info_window = OpenCloseInfoWindow
function OpenCloseInfoWindow(a1, a2, ...)
  T.info_gap = nil
  return previous_open_close_info_window(a1, a2, ...)
end
