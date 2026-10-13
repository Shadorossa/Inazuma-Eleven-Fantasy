-- VR-Framework › party / team sets (VRFW 2.3 service S7, docs/framework/team.md §8). Native side:
-- content\game\party.toml.
--
--   * Load event: the post-hook of the party's Load (VRFW.PartyLoad, Party.Load) counts the loads since boot and
--     publishes them as game_state vrfw.party.loads (VRFW.state("vrfw.party.loads") in any mod's script, state(…) in
--     an answer). A mod that keeps data per save slot next to the party (Utilities' team banks) takes its slot data
--     again when the count moved: a load really read the party, a slot switch alone did not. The count starts at 0;
--     a load whose handler was skipped because the scripts were busy is not counted (as before the service).
--   * Shared names: the boot log lists, per party entry of the profile, who declares it (the hook owners in run order
--     and the callers), so the mods that still carry their own inline copy are visible until they move to the
--     profile names (VRFW 2.3 P4).
--
-- Nothing of the game's party changes: the Load's code always runs and its answer is kept.

local E = require "lib/game_entries"

local function info(...) VRFW.log("party:", ...) end
local function warn(...) VRFW.warn("party:", ...) end

local KEY_LOADS = "vrfw.party.loads"
local ENTRIES = {
  "Party.Load", "Party.SetOrganizedFlagBit", "Party.RecountTeamInfo", "Party.LogicalToPhysical",
  "Party.TeamInfoAssign", "Team.SetStruct", "Save.IsJobPending",
}

-- ---------------------------------------------------------------------------------------------- load event

local loads = 0

local function hook_on(name)
  local ok, on = pcall(VRFW.is_on, name)
  return ok and on == true
end

if hook_on("VRFW.PartyLoad") then
  pcall(VRFW.state.set, KEY_LOADS, 0)
  VRFW.on("hook:VRFW.PartyLoad:post", function()
    loads = loads + 1
    pcall(VRFW.state.set, KEY_LOADS, loads)
    return nil
  end)
else
  warn("hook VRFW.PartyLoad is off (Party.Load not resolved): " .. KEY_LOADS .. " is not answered")
end

-- ---------------------------------------------------------------------------------------------- shared names

do
  local ok, e = pcall(function()
    local lines = {}
    for _, name in ipairs(ENTRIES) do lines[#lines + 1] = E.describe(name, E.declarers(name)) end
    info("entries: " .. table.concat(lines, " | "))
  end)
  if not ok then warn("party entries not reported: " .. tostring(e)) end
end
