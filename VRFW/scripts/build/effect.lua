-- Build script of the type `effect`: every active mod's effect declarations, in load order.
-- Assets stage: [[recolor]], [[effect]] (new pooled effects), [[shot_aura]], [[chr_trigger]], then the check of shipped effect packs.
-- Events stage (run by the `technique` type): [[event_effect]], [[attach]], [[event_timing]], [[event_command]]. A bad declaration skips only itself.
-- input = { stage = "assets" | "events", files = { { file, mod, load_index, value = <effects file> } } (each
--           [[recolor]] / [[event_command]] also has `json`), carry = { defined, copies } (event stage),
--           rarity = { [<rarity as written>] = { values = {…} } | { error = "…" } }, consts = { self_id, dir,
--           define_table, define_prefix, trigger_prefix, chara_param_prefix, elements, no_element, neutral, stats,
--           forms } }
-- returns { report = { <fx_engine::Item> }, defined = { [own id] = game name }, copies = { [stem] = objbin },
--           shot_aura = { rules = { <fx_engine::shot_aura::ShotRule> } } } (fx_engine::script::Scripted).

local U = require "lib/util"
local T = require "lib/effect_triggers"
local E = require "lib/effect_events"

local DEFINE_ROW = "EFFECT_DEFINE_INFO"

local function defaults(path)
  local v, err = VRFW.defaults("effect", path)
  if v == nil then error(err, 0) end
  return v
end

-- Run state shared with the libraries.
local function context(input)
  local X = {
    K = input.consts,
    D = { shot_aura = defaults("shot_aura"), event_lists = defaults("event_lists"), event_effect = defaults("event_effect") },
    files = input.files or {},
    rarity = input.rarity or {},
    report = {},
    -- own id -> game name of the new pooled effects
    defined = {},
    -- game name -> objbin path under common/
    define_paths = {},
    -- ids effect_define already has (new effects avoid them)
    retail = {},
    has_define = false,
    mod_ids = {},
  }
  for _, m in ipairs(VRFW.mods) do X.mod_ids[#X.mod_ids + 1] = m.id end

  -- One report line: `detail` = lines of a declaration that worked, else `err`.
  function X.item(f, kind, what, detail, err)
    if err == nil then
      for _, d in ipairs(detail) do
        if d:sub(1, 5) == "WARN " then VRFW.log.warn(f.file .. ": [[" .. kind .. "]] " .. what .. ": " .. d:sub(6)) end
      end
      X.report[#X.report + 1] = { mod_id = f.mod, file = f.file, kind = kind, what = what, ok = true, detail = detail }
    else
      VRFW.log.error(f.file .. ": [[" .. kind .. "]] " .. what .. ": " .. err .. " (skipped)")
      X.report[#X.report + 1] = { mod_id = f.mod, file = f.file, kind = kind, what = what, ok = false, detail = { err } }
    end
  end

  -- Pooled effect as written -> game name: own (`<mod>.<name>`), a full own id, else the game's.
  function X.effect_name(mod, s)
    local own = VRFW.ids.own(mod, s)
    if own and X.defined[own] then return X.defined[own] end
    if X.defined[s] then return X.defined[s] end
    if X.define_paths[s] then return s end
    return nil, "effect `" .. s .. "` is not in effect_define and no [[effect]] declares it"
  end
  return X
end

-- effect_define base: retail ids and every name's path.
local function read_define(X)
  local key = VRFW.rows.key(X.K.define_prefix)
  if not key then
    VRFW.log.warn("effect_define not found in the game files: [[effect]] and pooled names are not checked")
    return
  end
  local t, err = VRFW.rows.open(key)
  if not t then
    VRFW.log.error(err)
    return
  end
  for _, i in ipairs(t:rows(DEFINE_ROW)) do
    local h, p, n = t:uint(i, 0), t:str(i, 1), t:str(i, 5)
    if h and p and n then
      X.retail[h] = true
      X.define_paths[n] = p
    end
  end
  X.has_define = true
end

-- 1. [[recolor]]
local function recolor(X, d)
  local k
  if d.object ~= nil and d.effect == nil then
    k = VRFW.effect.object(d.object)
    if not k then return nil, "object `" .. d.object .. "` not found" end
  elseif d.effect ~= nil and d.object == nil then
    local p = X.define_paths[d.effect]
    if not p then return nil, "effect `" .. d.effect .. "` is not in effect_define" end
    k = p:find("/", 1, true) and VRFW.effect.object(p)
    if not k then return nil, "effect `" .. d.effect .. "`: path " .. p .. " is not an effect object" end
  else
    return nil, "write exactly one of `object` / `effect`"
  end
  return VRFW.effect.recolor(d.json, k.objbin)
end

-- The string whose crc32 is `id` among `own`, `own#1`, `own#2`...
local function game_name(own, id)
  if VRFW.crc32(own) == id then return own end
  for n = 1, 999 do
    local s = own .. "#" .. n
    if VRFW.crc32(s) == id then return s end
  end
  return own
end

-- 2. one [[effect]]: its effect_define row (`add`) and report line
local function define(X, mod, d)
  local own, err = VRFW.ids.own(mod, d.name)
  if not own then return nil, err end
  local game = X.defined[own]
  if not game then return nil, "no id" end
  local from, e1 = X.effect_name(mod, d.from)
  if not from then return nil, e1 end
  local after = from
  if d.after ~= nil then
    local a, e2 = X.effect_name(mod, d.after)
    if not a then return nil, e2 end
    after = a
  end
  local path
  if d.object ~= nil then
    local k = VRFW.effect.object(d.object)
    if not k then return nil, "object `" .. d.object .. "` not found" end
    if not VRFW.effect.exists(k.objbin) then
      return nil, "object `" .. d.object .. "`: " .. k.objbin .. " is neither a game file, a mod file nor a copy"
    end
    local bad = VRFW.effect.check_new_object(k.objbin)
    if bad then return nil, bad end
    path = k.define_path
  else
    path = X.define_paths[from]
    if not path then return nil, "template `" .. from .. "` has no path" end
  end
  local cells = { { "path", path }, { "name", game } }
  if d.clips then
    for _, c in ipairs({ { "clip_in", d.clips["in"] }, { "clip_loop", d.clips["loop"] }, { "clip_out", d.clips.out } }) do
      if c[2] ~= nil then cells[#cells + 1] = { c[1], c[2] == "" and 0 or c[2] } end
    end
  end
  if d.group ~= nil then cells[#cells + 1] = { "group", d.group } end
  X.define_paths[game] = path
  local add = { key = VRFW.crc32(game), from = VRFW.crc32(from), after = VRFW.crc32(after), cells = cells }
  return add, { game .. " → " .. path .. " (from " .. from .. ")" }
end

local function effects(X)
  -- ids in sorted order (stable whatever the load order)
  local owns, seen = {}, {}
  for _, f in ipairs(X.files) do
    for _, d in ipairs(f.value.effect or {}) do
      local own = VRFW.ids.own(f.mod, d.name)
      if own and not seen[own] then
        seen[own] = true
        owns[#owns + 1] = own
      end
    end
  end
  VRFW.sort(owns)
  for _, o in ipairs(owns) do
    X.defined[o] = game_name(o, VRFW.ids.assign(o, X.retail))
  end
  -- one row file per run of one mod's declarations
  local edits = {}
  for _, f in ipairs(X.files) do
    for _, d in ipairs(f.value.effect or {}) do
      local add, detail = define(X, f.mod, d)
      if add then
        local last = edits[#edits]
        if last and last.owner == f.mod then
          last.add[#last.add + 1] = add
        else
          edits[#edits + 1] = { owner = f.mod, label = "mods/" .. f.mod .. "/" .. X.K.dir, add = { add } }
        end
        X.item(f, "effect", d.name, detail)
      else
        local own = VRFW.ids.own(f.mod, d.name)
        if own then
          local g = X.defined[own]
          X.defined[own] = nil
          if g then X.define_paths[g] = nil end
        end
        X.item(f, "effect", d.name, nil, detail)
      end
    end
  end
  if #edits > 0 then
    if not X.has_define then
      VRFW.log.error("effect_define missing: the new pooled effects are not registered")
    else
      VRFW.effect.table_rows(X.K.self_id, X.K.define_table, edits)
    end
  end
end

-- 5. shipped effect packs (checked, reported)
local function shipped(X)
  for _, s in ipairs(VRFW.effect.shipped()) do
    local file = "mods/" .. s.mod .. "/files/" .. s.rel
    local ok, detail = true, {}
    for _, p in ipairs(s.problems) do
      if p.error then
        ok = false
        VRFW.log.error(file .. ": " .. p.text)
      end
      detail[#detail + 1] = p.text
    end
    X.report[#X.report + 1] = { mod_id = s.mod, file = file, kind = "check", what = s.rel, ok = ok, detail = detail }
  end
end

local function any(X, list)
  for _, f in ipairs(X.files) do
    if not U.is_empty(f.value[list]) then return true end
  end
  return false
end

return function(input)
  local X = context(input)
  local rules = {}
  if input.stage == "events" then
    local carry = input.carry or {}
    for k, v in pairs(carry.defined or {}) do X.defined[k] = v end
    VRFW.effect.use_copies(carry.copies or {})
    read_define(X)
    E.run(X)
  else
    read_define(X)
    for _, f in ipairs(X.files) do
      for i, d in ipairs(f.value.recolor or {}) do
        local detail, err = recolor(X, d)
        X.item(f, "recolor", i .. " (" .. (d.copy or d.object or d.effect or "?") .. ")", detail, err)
      end
    end
    effects(X)
    -- after the new pooled effects: an aura may name one
    if any(X, "shot_aura") then rules = T.shot_auras(X) end
    -- after the shot auras: both edit eff_chr_trigger
    if any(X, "chr_trigger") then T.chr_triggers(X) end
    shipped(X)
  end
  return { report = X.report, defined = X.defined, copies = VRFW.effect.copies(), shot_aura = { rules = rules } }
end
