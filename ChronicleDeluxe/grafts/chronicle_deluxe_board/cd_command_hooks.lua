-- Chronicle Deluxe, the battle kinds of the Chronicle board's command menu (docs/game/mods/chronicle-deluxe.md §8). A
-- hook file of the VR-Framework's command menu script (graft route_board, docs/framework/route-board.md §3). Nothing
-- runs at load but the definitions and the registrations (no engine call).
--   * rows: only the difficulties that exist (VRFW_MatchDifficulty, this mod's content\defaults\match_difficulty.toml:
--     a normal piece Crónica and Heroica, a gate piece its gate battle), before the framework's node filter.
-- The blue panel of the list keeps its retail size (cutting it needs nine-slice sprites, which only Inazuma Fantasy
-- ships with its own frame fit).
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

if VRFW_Host ~= nil then
  VRFW_Host.on("vs_route_town_command_select_menu", "VRFW_RBC_Rows", {id = "chronicle_deluxe.board", phase = "around",
    fn = function(nxt, rows, kind, slot)
      return nxt(K.Rows(rows, kind), kind, slot)
    end})
end
