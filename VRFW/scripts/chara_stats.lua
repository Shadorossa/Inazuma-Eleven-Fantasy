-- VR-Framework › character stats providers (service S10 of VRFW 2.3, docs/framework/card-look.md §6). Native side:
-- content\game\chara_stats.toml (a state key and a command; nothing is written to the game).
--
-- The three game entries that decide a character's numbers (Chara.GetParamStatus, Chara.GetSpecialtyType,
-- Technique.MatchSkillInstall) are one detour each with ordered subscribers: the framework's item transformations
-- (native, when declared) and every mod's `[[VRFW.Hook]]` on the entry's profile name, chained by the loader in install
-- order (the link installed last runs first). This script reports the order at boot, warns when a provider still names
-- the entry with an inline signature (until VRFW 2.3 P4), and answers who provides what:
--
--   * game_state vrfw.chara_stats.providers = the detour owners of Chara.GetParamStatus among the active mods
--   * CMND_VRFW_CHARA_STATS_PROVIDERS(entry) -> n, "<mod>.<hook>" … in run order

CharaStats = CharaStats or {}

local E = require "lib/game_entries"

local function info(...) VRFW.log("chara_stats:", ...) end
local function warn(...) VRFW.warn("chara_stats:", ...) end

local ENTRIES = { "Chara.GetParamStatus", "Chara.GetSpecialtyType", "Technique.MatchSkillInstall" }
local ORDER = {}         -- entry -> { "<mod>.<hook>" … } in run order

local function start()
  local lines = {}
  for _, name in ipairs(ENTRIES) do
    local subs = E.declarers(name)
    local chain = E.run_order(subs)
    local list = {}
    for _, s in ipairs(chain) do list[#list + 1] = E.label(s) end
    ORDER[name] = list
    lines[#lines + 1] = E.describe(name, subs)
    for _, s in ipairs(subs) do
      if s.kind == "hook" and type(s.decl) == "table" and s.decl.game == nil then
        warn(string.format("%s: %s names %s with an inline signature (P4: game = %q)", name, E.label(s), name, name))
      end
    end
  end
  pcall(VRFW.state.set, "vrfw.chara_stats.providers", #(ORDER["Chara.GetParamStatus"] or {}))
  info("providers (run order; the framework's native item transformations run where the loader chained them): " .. table.concat(lines, " | "))
end

-- CMND_VRFW_CHARA_STATS_PROVIDERS(entry) -> n, provider…
function CharaStats.Providers(entry)
  local l = ORDER[tostring(entry or "")]
  if not l then return nil end
  return #l, table.unpack(l)
end

local ok, e = pcall(start)
if not ok then warn("providers not reported: " .. tostring(e)) end
