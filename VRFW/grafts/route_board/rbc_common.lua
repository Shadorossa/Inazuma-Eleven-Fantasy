-- VRFW route_board BEGIN
-- VR-Framework: the hook points of the Chronicle board's command menu, vs_route_town_command_select_menu
-- (docs/framework/route-board.md). The framework owns the one patch of the script (route_nodes + this graft) and makes
-- it a VRFW_Host host (the host call at the end of this graft's file); a mod hooks the points below, or the script's
-- retail globals (OnInit, OnFunction, ...), from its own hook file ([[hooks]] stem = "vs_route_town_command_select_menu").
--   VRFW_RBC_Rows(rows, kind, slot) -> rows   the piece's rows (difficulties) of the menu (OnInit; kind 0 normal piece,
--                                             1 gate piece; slot = the piece's save slot). Default: route_nodes' node
--                                             filter (a [[route_node]] lists only its shown difficulties). A mod's
--                                             «around» handler filters first and passes its rows on with nxt(...)
--   VRFW_RBC_Guide(item, icons, texts, cmds)  the button guide of a focused row (SetupButtonGuide; item = the row,
--                                             {} when none): append entries to the three lists
--   VRFW_RBC_ListLayer(layer, kind, rows)     the battle-kind list panel (layer 14202445 normal / 1695882381 gate) is
--                                             placed and about to open with `rows` rows
-- The script's locals a handler may read / write: VRFW_RBC.L.<name> (decompile names; one line in VRFW_RBC_LOCALS
-- when a mod needs another one).
VRFW_RBC = VRFW_RBC or {}
VRFW_RBC.STEM = "vs_route_town_command_select_menu"
VRFW_RBC_LOCALS = {
  n2 = {function() return n2 end, function(v) n2 = v end},         -- the piece's save slot (statusFlagIndex)
  n4 = {function() return n4 end, function(v) n4 = v end},         -- the piece's game id
  t3 = {function() return t3 end, function(v) t3 = v end},         -- the menu's rows ({difficultyType, ...}, OnInit)
  flag = {function() return flag end, function(v) flag = v end},   -- the menu is closing (a row was decided)
  flag2 = {function() return flag2 end, function(v) flag2 = v end} -- the drop-rate window is open
}
VRFW_RBC.L = setmetatable({}, {
  __index = function(_, k)
    local a = VRFW_RBC_LOCALS[k]
    if a == nil then
      error("VRFW_RBC.L: the command menu serves no local " .. tostring(k), 2)
    end
    return a[1]()
  end,
  __newindex = function(_, k, v)
    local a = VRFW_RBC_LOCALS[k]
    if a == nil then
      error("VRFW_RBC.L: the command menu serves no local " .. tostring(k), 2)
    end
    a[2](v)
  end
})

function VRFW_RBC_Rows(rows, kind, slot)
  if VRFW_RN_Rows ~= nil then
    return VRFW_RN_Rows(rows, slot)
  end
  return rows
end

function VRFW_RBC_Guide(item, icons, texts, cmds)
end

function VRFW_RBC_ListLayer(layer, kind, rows)
end
-- VRFW route_board END
