-- Match resource rules. Declarations: every active mod's content\resource_rules\*.toml (`VRFW.resource_rule/1`); native side: content\game\resource_rules.toml.
--   * [[VRFW.ShotSpend]] gauge = "kizuna": spend_on_shot = false: a shot does not spend the team's kizuna gauge; return_on_shot = false: nothing is returned after a shot (later mod wins per key).
--   * [[VRFW.OffPitch]]: players kept off the pitch without a red card; IsSentOff / IsSentOffById answer 0 for handles in the exported table Resource.OffPitch.
--     ApplyTeamLayout is bracketed by signals vrfw.off_pitch.layout and vrfw.off_pitch.layout_done so the mod can clear and restore its member bits.
--   * Cost points (aura cost check, aura release, pending pay, tension pay) are hook-bus providers listed in the boot log.

local D = require "lib/declarations"
local E = require "lib/game_entries"

local function info(...) VRFW.log("resource_rules:", ...) end
local function warn(...) VRFW.warn("resource_rules:", ...) end

-- Gauges a [[VRFW.ShotSpend]] may name: gauge -> { key -> patch that turns the key's `false` on }.
local GAUGES = {
  kizuna = { spend_on_shot = "Resource.KizunaSpendSkip", return_on_shot = "Resource.KizunaReturnSkip" },
}

local SIG_LAYOUT, SIG_LAYOUT_DONE = "vrfw.off_pitch.layout", "vrfw.off_pitch.layout_done"
local OFF_TABLE = "Resource.OffPitch"
local OFF_HOOKS = { "Resource.IsSentOff", "Resource.IsSentOffById", "Resource.TeamLayout" }

local COST_ENTRIES = {
  "Stamina.AuraCostCheck", "Stamina.AuraRelease", "Duel.ProcessPending", "Stamina.TensionPay",
  "Stamina.IsSentOff", "Stamina.IsSentOffById", "Match.TeamLayout",
}

local OFF_LIVE = false

-- ---------------------------------------------------------------------------------------------- declarations

local function apply_patch(name)
  local ok, done, e = pcall(VRFW.patch.apply, name)
  if ok and done == true then return true end
  return false, tostring(ok and e or done)
end

local function apply_hook(name)
  local ok, done, e = pcall(VRFW.hook.apply, name)
  if ok and done == true then return true end
  return false, tostring(ok and e or done)
end

local function shot_spend(decls)
  -- gauge -> key -> { value, mod }
  local by = {}
  for _, d in ipairs(decls) do
    if d.entry == "ShotSpend" then
      local g = GAUGES[d.v.gauge]
      if not g then
        local names = {}
        for k in pairs(GAUGES) do names[#names + 1] = k end
        table.sort(names)
        warn(string.format("%s: gauge `%s` is not one of %s: left out", d.where, d.v.gauge, table.concat(names, ", ")))
      else
        by[d.v.gauge] = by[d.v.gauge] or {}
        for key in pairs(g) do
          if d.given[key] then
            local was = by[d.v.gauge][key]
            if was and was.value ~= d.v[key] then
              info(string.format("%s.%s = %s of %s replaces %s of %s (later mod wins)", d.v.gauge, key, tostring(d.v[key]), d.mod,
                tostring(was.value), was.mod))
            end
            by[d.v.gauge][key] = { value = d.v[key], mod = d.mod }
          end
        end
      end
    end
  end
  local gauges = {}
  for g in pairs(GAUGES) do gauges[#gauges + 1] = g end
  table.sort(gauges)
  for _, g in ipairs(gauges) do
    local keys = {}
    for k in pairs(GAUGES[g]) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
      local s = by[g] and by[g][k]
      if s and s.value == false then
        local ok, why = apply_patch(GAUGES[g][k])
        parts[#parts + 1] = string.format("%s = false (%s): %s", k, s.mod, ok and ("written " .. GAUGES[g][k]) or ("NOT written: " .. why))
        if not ok then warn(string.format("%s: %s = false of %s: %s not written (%s): the game's rule stays", g, k, s.mod, GAUGES[g][k], why)) end
      else
        parts[#parts + 1] = string.format("%s = game%s", k, s and (" (" .. s.mod .. ")") or "")
      end
    end
    info(string.format("shot spend: %s: %s", g, table.concat(parts, ", ")))
  end
end

local function off_pitch(decls)
  local mods = {}
  for _, d in ipairs(decls) do
    if d.entry == "OffPitch" then mods[#mods + 1] = d.mod .. "." .. d.v.name end
  end
  if #mods == 0 then
    info("off pitch: no mod declares it: IsSentOff / ApplyTeamLayout stay the game's")
    return
  end
  local parts, all = {}, true
  for _, h in ipairs(OFF_HOOKS) do
    local ok, why = apply_hook(h)
    parts[#parts + 1] = h .. (ok and " installed" or (" NOT installed (" .. why .. ")"))
    all = all and ok
  end
  OFF_LIVE = true
  local ex = E.exporters(OFF_TABLE)
  info(string.format("off pitch: %s; table */%s exported by %s; %s", table.concat(mods, ", "), OFF_TABLE,
    #ex > 0 and table.concat(ex, ", ") or "nobody (no player is ever off the pitch)", table.concat(parts, ", ")))
  if not all then warn("off pitch: a detour is missing: an off-pitch player may show a red card or not be substituted") end
end

local function report_points()
  local ok, e = pcall(function()
    local lines = {}
    for _, name in ipairs(COST_ENTRIES) do
      local chain = E.run_order(E.declarers(name))
      local who = {}
      for _, s in ipairs(chain) do
        local o = tonumber(type(s.decl) == "table" and s.decl.order or nil)
        who[#who + 1] = E.label(s) .. (o and o ~= 0 and string.format(" (order %d)", o) or "")
      end
      lines[#lines + 1] = string.format("%s: %s", name, #who > 0 and table.concat(who, " > ") or "no declared provider")
    end
    info("cost points (declared providers, run order; the engines' own subscribers: the hooks: boot lines): " .. table.concat(lines, " | "))
  end)
  if not ok then warn("cost points not reported: " .. tostring(e)) end
end

local function start()
  local schema, why = D.schema("resource_rule")
  if not schema then
    warn(why .. ": the match resource rules stay the game's")
    return
  end
  local decls, skipped = D.load(schema, warn)
  if (skipped or 0) > 0 then info(string.format("%d declaration(s) left out by `when`", skipped)) end
  shot_spend(decls)
  off_pitch(decls)
  report_points()
end

start()

-- ---------------------------------------------------------------------------------------------- ApplyTeamLayout

if OFF_LIVE then
  VRFW.on("hook:Resource.TeamLayout", function()
    pcall(VRFW.signal, SIG_LAYOUT)
    return nil
  end)
  VRFW.on("hook:Resource.TeamLayout:post", function()
    pcall(VRFW.signal, SIG_LAYOUT_DONE)
    return nil
  end)
end
