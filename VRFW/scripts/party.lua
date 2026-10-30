-- Party / team sets (native side: content\game\party.toml).
-- Publishes the number of party loads since boot as game_state vrfw.party.loads (a load whose handler was skipped is not counted).
-- Logs at boot, per party entry of the profile, who declares it.

local E = require "lib/game_entries"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("party")

local KEY_LOADS = "vrfw.party.loads"
local ENTRIES = {
  "Party.Load", "Party.SetOrganizedFlagBit", "Party.RecountTeamInfo", "Party.LogicalToPhysical",
  "Party.TeamInfoAssign", "Team.SetStruct", "Save.IsJobPending",
}

-- --- load event

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

-- --- shared names

do
  local ok, e = pcall(function()
    local lines = {}
    for _, name in ipairs(ENTRIES) do lines[#lines + 1] = E.describe(name, E.declarers(name)) end
    info("entries: " .. table.concat(lines, " | "))
  end)
  if not ok then warn("party entries not reported: " .. tostring(e)) end
end
