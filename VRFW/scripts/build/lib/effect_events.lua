-- Effect build event stage: applies [[event_effect]], [[attach]], [[event_timing]] and [[event_command]] to the served event lists via native `VRFW.effect.*`.

local T = require "lib/effect_triggers"

local M = {}

local function list_key(X, kind, event)
  return string.format(X.D.event_lists[kind], event:lower())
end

-- Formats a list of whole numbers as Rust `{:?}`.
local function show(list)
  local s = {}
  -- %.0f because the game's Lua 5.2 %d rejects u32 ids >= 2^31
  for i, v in ipairs(list) do s[i] = string.format("%.0f", v) end
  return "[" .. table.concat(s, ", ") .. "]"
end

-- Cuts named in `names` of `event` (all when empty): `{ name, start, end }`, or nil and why.
local function cut_ranges(X, event, names)
  local all, err = VRFW.effect.cuts(list_key(X, "evt", event))
  if not all then return nil, err end
  if #names == 0 then return all end
  local out = {}
  for _, n in ipairs(names) do
    local hit
    for _, c in ipairs(all) do
      if c.name:lower() == n:lower() then
        hit = c
        break
      end
    end
    if not hit then
      local have = {}
      for i, c in ipairs(all) do have[i] = c.name end
      return nil, event .. " has no cut `" .. n .. "` (cuts: " .. table.concat(have, ", ") .. ")"
    end
    out[#out + 1] = hit
  end
  return out
end

-- Frame ranges of `cuts` (none = every frame).
local function ranges(X, event, cuts)
  if cuts == nil or #cuts == 0 then return {} end
  local c, err = cut_ranges(X, event, cuts)
  if not c then return nil, err end
  local r = {}
  for i, x in ipairs(c) do r[i] = { x.start, x["end"] } end
  return r
end

local function event_effect(X, mod, d)
  local cut_names = {}
  if d.cut ~= nil then cut_names[1] = d.cut end
  for _, c in ipairs(d.cuts or {}) do cut_names[#cut_names + 1] = c end
  local key = list_key(X, "eff", d.event)
  local offset = d.offset or 0
  local DE = X.D.event_effect
  if d.aura ~= nil then
    -- aura on an event actor between two frames (ATTACH_AURA on / off)
    if d.effect ~= nil or d.object ~= nil then return nil, "write one of `effect` / `object` / `aura`" end
    if d.actor == nil then return nil, "aura: `actor` (the event actor it goes on: b000001_s00_p<VARIATION>…)" end
    local start = d.frame
    if start == nil then
      if #cut_names == 0 then return nil, "aura timing: give `cut` or `frame`" end
      local cuts, e2 = cut_ranges(X, d.event, { cut_names[1] })
      if not cuts then return nil, e2 end
      start = cuts[1].start + offset
    end
    local stop = d["until"]
    if stop == nil and d.until_cut ~= nil then
      local cuts, e3 = cut_ranges(X, d.event, { d.until_cut })
      if not cuts then return nil, e3 end
      stop = cuts[1].start + (d.until_offset or 0)
    end
    local n, e4 = VRFW.effect.add_aura(key, d.actor, d.aura, start, stop)
    if not n then return nil, e4 end
    return { d.aura .. " on " .. d.actor .. " from frame " .. string.format("%.0f", start)
      .. (stop and (" to " .. string.format("%.0f", stop)) or " on") .. ": " .. n .. " command(s)" }
  end
  if d.effect ~= nil and d.object == nil then
    local name, err = X.effect_name(mod, d.effect)
    if not name then return nil, err end
    local frames = {}
    for _, f in ipairs(d.frames or {}) do frames[#frames + 1] = f end
    if d.frame ~= nil then frames[#frames + 1] = d.frame end
    if #frames == 0 then
      if #cut_names == 0 then return nil, "timing: give `cut`, `cuts`, `frame` or `frames`" end
      local cuts, e2 = cut_ranges(X, d.event, cut_names)
      if not cuts then return nil, e2 end
      for i, c in ipairs(cuts) do frames[i] = c.start + offset end
    end
    local inst = d.actor or name
    local a = d.attach or {}
    local target
    if a.actor ~= nil then target = { actor = a.actor, locator = a.locator or DE.locator, motions = a.motions or DE.motions } end
    local n, e3 = VRFW.effect.add_pooled(key, name, inst, frames, target)
    if not n then return nil, e3 end
    return { name .. " at frame(s) " .. show(frames) .. ": " .. n .. " command(s)" }
  elseif d.object ~= nil and d.effect == nil then
    local k = VRFW.effect.object(d.object)
    if not k then return nil, "object `" .. d.object .. "` not found" end
    if not VRFW.effect.exists(k.objbin) then return nil, "object `" .. d.object .. "`: " .. k.objbin .. " not found" end
    local actor = d.actor or k.stem
    local cuts, err = cut_ranges(X, d.event, cut_names)
    if not cuts then return nil, err end
    -- by start frame, stable
    local sorted = {}
    for i, c in ipairs(cuts) do sorted[i] = { c = c, i = i } end
    table.sort(sorted, function(x, y)
      if x.c.start ~= y.c.start then return x.c.start < y.c.start end
      return x.i < y.i
    end)
    local shows = {}
    for i, s in ipairs(sorted) do
      local c = s.c
      shows[i] = { start = c.start + offset, ["end"] = c["end"], clip = (d.clips or {})[c.name] or c.name }
    end
    local at
    if d.attach ~= nil then
      local a = d.attach
      if a.locator == nil then return nil, "attach: `locator` is needed for an effect object" end
      at = { point = a.point or DE.point, locator = a.locator, offset = a.offset or { 0, 0, 0 }, rotation = a.rotation or { 0, 0, 0 } }
    end
    local n, e2 = VRFW.effect.add_object(key, actor, k.objbin, shows, at)
    if not n then return nil, e2 end
    return { actor .. " (" .. k.resource_path .. ") in " .. #shows .. " cut(s): " .. n .. " command(s)" }
  end
  return nil, "write exactly one of `effect` / `object`"
end

local function attach(X, d)
  local range, err = ranges(X, d.event, d.cuts)
  if not range then return nil, err end
  local key = list_key(X, d.list == "evt" and "evt" or "eff", d.event)
  local n, e2 = VRFW.effect.set_attach(key, d.actor, range, d.point, d.locator, d.offset, d.rotation)
  if not n then return nil, e2 end
  if n == 0 then return nil, key .. ": no attach command of `" .. d.actor .. "` in those cuts" end
  return { n .. " attach command(s) changed" }
end

local function timing(X, d)
  local range, err = ranges(X, d.event, d.cuts)
  if not range then return nil, err end
  local n, e2 = VRFW.effect.shift(list_key(X, "eff", d.event), d.target, range, d.shift)
  if not n then return nil, e2 end
  if n == 0 then return nil, "no command of `" .. d.target .. "` to move" end
  return { n .. " command(s) moved " .. string.format("%+d", d.shift) .. " frame(s)" }
end

-- Command id as written by the modder: `CMD_XXXXXXXX` / `0xXXXXXXXX` (hex id) or a name (its crc32).
local function command_id(s)
  local h = s:match("^CMD_(.*)$") or s:match("^0x(.*)$")
  local n = h and T.parse_hex(h)
  return n or VRFW.crc32(s)
end

local function command(X, d)
  if #(d.set or {}) == 0 then return nil, "`set` is empty" end
  local range, err = ranges(X, d.event, d.cuts)
  if not range then return nil, err end
  local key = list_key(X, d.list == "evt" and "evt" or "eff", d.event)
  local n, frames = VRFW.effect.command(key, command_id(d.command), d.json, range)
  if not n then return nil, frames end
  if n == 0 then return nil, "no command " .. d.command .. " to change in " .. key end
  return { n .. " command(s) changed in place at frame(s) " .. show(frames) }
end

function M.run(X)
  for _, f in ipairs(X.files) do
    local v = f.value
    for i, d in ipairs(v.event_effect or {}) do
      local detail, err = event_effect(X, f.mod, d)
      X.item(f, "event_effect", i .. " (" .. d.event .. " " .. (d.effect or d.object or d.aura or "?") .. ")", detail, err)
    end
    for i, d in ipairs(v.attach or {}) do
      local detail, err = attach(X, d)
      X.item(f, "attach", i .. " (" .. d.event .. " " .. d.actor .. ")", detail, err)
    end
    for i, d in ipairs(v.event_timing or {}) do
      local detail, err = timing(X, d)
      X.item(f, "event_timing", i .. " (" .. d.event .. " " .. d.target .. ")", detail, err)
    end
    for i, d in ipairs(v.event_command or {}) do
      local detail, err = command(X, d)
      X.item(f, "event_command", i .. " (" .. d.event .. " " .. d.command .. ")", detail, err)
    end
  end
end

return M
