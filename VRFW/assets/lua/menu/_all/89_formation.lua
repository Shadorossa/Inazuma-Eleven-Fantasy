-- VRFW_Formation: the game's formations by their number of players, read from formation_config (the match engine's
-- CMND_VRFW_FORMATION_PLAYERS). Definitions only: no engine call at load.
--   VRFW_Formation.Players(id)     -> the formation's number of players (5 for a 5v5 one, 11 for an 11v11 one);
--                                     0 = not a formation of formation_config; nil = no answer (the command is
--                                     not registered)
--   VRFW_Formation.IsFiveASide(id) -> true for a 5v5 formation (nil = no answer)
if VRFW_Formation == nil then
  local F = { PLAYERS = VRFW_Cmd.VRFW_FORMATION_PLAYERS }  -- CMND_VRFW_FORMATION_PLAYERS (formation id) -> players
  local known = {}                   -- formation id -> players (the table does not change while the game runs)
  VRFW_Formation = F

  function F.Players(id)
    if type(id) ~= "number" then
      return 0
    end
    id = VRFW_Id.u32(id)
    local players = known[id]
    if players == nil then
      players = VRFW_Host.Command(F.PLAYERS, id)
      if type(players) ~= "number" then
        return nil
      end
      known[id] = players
    end
    return players
  end

  function F.IsFiveASide(id)
    local players = F.Players(id)
    if players == nil then
      return nil
    end
    return players == 5
  end
end
