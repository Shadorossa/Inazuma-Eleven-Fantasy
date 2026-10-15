-- Chronicle Deluxe, the battle kinds of the Chronicle board's command menu (docs/game/mods/chronicle-deluxe.md §8). A
-- hook file of the VR-Framework's command menu script (graft route_board, docs/framework/route-board.md §3). Nothing
-- runs at load but the definitions and the registrations (no engine call).
--   * rows: only the difficulties that exist (VRFW_MatchDifficulty, this mod's content\defaults\match_difficulty.toml:
--     a normal piece Crónica and Heroica, a gate piece its gate battle), before the framework's node filter.
--   * panel fit: the blue panel of the battle-kind list («MI EQUIPO»; layout vsroute01_15c on normal pieces, 15d on
--     gate pieces, one quad _list_base01 / _list_base02) is sized for every retail row slot (8 / 5, 70 px each). With
--     fewer rows it is cut to them: height = retail - 70 * (slots - rows), top edge kept (the banner and the rows do not
--     move), so the margin under the last row equals the one over the first (VRFW_RBC_ListLayer). The panel sprites
--     get nine-slice guides (content\images\menu\30_vsroute\vsroute01\vsroute01_15c.toml / 15d.toml) so the rounded
--     corners and the shadow keep their size.
-- With Inazuma Fantasy's Chronicle redesign active (its global EVT_ChrFrameFit, the same fit with its own layouts and
-- the same guides) the fit is IF's: one implementation.
ChronicleDeluxe = ChronicleDeluxe or {}
ChronicleDeluxe.Command = ChronicleDeluxe.Command or {}
local K = ChronicleDeluxe.Command

-- kind 1 = a gate piece; no set declared = every row
function K.Rows(rows, kind)
  local s = VRFW_MatchDifficulty ~= nil and VRFW_MatchDifficulty.Set(kind == 1 and "gate" or "route") or nil
  if s == nil or rows == nil then
    return rows
  end
  local keep = {}
  for i = 1, #rows do
    if s[rows[i].difficultyType] then
      keep[#keep + 1] = rows[i]
    end
  end
  return keep
end

-- per list layer kind (0 normal, 1 gate): the panel quad and its retail size (layouts vsroute01_15c / 15d, v7.1.2)
K.PANEL = {
  [0] = {node = 785322415 --[[_list_base01]], width = 700, height = 644, slots = 8},
  [1] = {node = 3083223061 --[[_list_base02]], width = 700, height = 472, slots = 5}
}
K.ROW_HEIGHT = 70
K.NODE_SCALE = 2885415772         -- (layer, instance, node, width, height): a quad's size in px

function K.FitPanel(layer, kind, rows)
  local p = K.PANEL[kind]
  if p == nil or rows == nil or rows < 1 then
    return
  end
  if rows > p.slots then
    rows = p.slots
  end
  funcLuaMenuCommand(K.NODE_SCALE, layer, 0, p.node, p.width, p.height - K.ROW_HEIGHT * (p.slots - rows))
end

if VRFW_Host ~= nil then
  VRFW_Host.on("vs_route_town_command_select_menu", "VRFW_RBC_Rows", {id = "chronicle_deluxe.board", phase = "around",
    fn = function(nxt, rows, kind, slot)
      return nxt(K.Rows(rows, kind), kind, slot)
    end})
  VRFW_Host.on("vs_route_town_command_select_menu", "VRFW_RBC_ListLayer", {id = "chronicle_deluxe.panel_fit",
    phase = "after", fn = function(r, layer, kind, rows)
      if EVT_ChrFrameFit == nil and VRFW_MatchDifficulty ~= nil
          and VRFW_MatchDifficulty.Set(kind == 1 and "gate" or "route") ~= nil then
        K.FitPanel(layer, kind, rows)
      end
    end})
end
