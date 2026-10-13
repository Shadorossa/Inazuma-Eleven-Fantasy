-- The boot plan of the telops: for every winner, which outputs to make and serve, and the routes of the path hook.
--
--   * a telop the game has no menu object for is NEW: it needs `from` (its menu object is made from `from`'s, once
--     per telop);
--   * a mod's whole file (`source = "mod_file"`) is served by the ModLoader at the game path; the retail copy is
--     served for «Rótulos personalizados» off;
--   * a custom layout: texture, layout, geometry and menu object (the game's texture path keeps the retail telop);
--   * no layout: the texture in the retail format at its own key (route `on`; a NEW telop is shown in both settings);
--   * a TOML without picture or layout over a game telop: the game's telop as it is.
-- Pictures, layouts and the stamp cache are native (VRFW.telop.*); the cache outputs not in `keep` are pruned.
-- (The run time's live reload plans natively: telop_engine::build::build_with.)

local M = {}

local function ends_with(s, tail)
  return s:sub(-#tail) == tail
end

-- plan (telop_engine::script::PlanOut), keep
function M.plan(entries, picks)
  local T = VRFW.telop
  local plan = { serve = {}, routes = {}, objbins = {}, direct = {}, needs = {}, built = 0, reused = 0 }
  local keep = {}
  local function serve(k, p) plan.serve[#plan.serve + 1] = { k, p } end
  -- the telops a mod's whole file overrides: (its folder's language, telop)
  local overridden = {}
  for _, e in ipairs(entries) do
    if e.source == "mod_file" and type(e.langs) == "table" and e.langs[1] then
      overridden[e.langs[1] .. "\0" .. e.technique] = true
    end
  end
  local checked = {}
  -- NEW telops: id -> the menu object they are drawn with (false: it could not be made)
  local new_objs = {}

  local function one(p)
    local lang, id = p.lang, p.id
    local e = entries[p.entry]
    local label = string.format("telop %s [%s] of %s (%s)", id, lang, e.mod, e.origin)
    local from = e.from
    local is_new = T.is_new(id)
    if is_new and from == nil and not checked[id] then
      checked[id] = true
      VRFW.log.warn(string.format("telop %s: the game has no menu object soccer10_01_%s.objbin: no event shows this telop (a NEW telop needs `from` = the game telop it copies; check the id)", id, id))
    end
    if not is_new and from ~= nil and not checked[id] then
      checked[id] = true
      VRFW.log.info(string.format("telop %s: the game has it: `from` is ignored", id))
    end
    -- the menu object of a NEW telop: the template's with this id's texture path, served at the game's path
    local new_obj = nil
    if is_new and from ~= nil then
      if new_objs[id] == nil then
        local k, path = T.new_object(id, from)
        if k then
          keep[#keep + 1] = k
          serve(k, path)
          new_objs[id] = path
        else
          VRFW.log.error(string.format("telop %s: %s: the new telop is left out", id, path))
          new_objs[id] = false
        end
      end
      new_obj = new_objs[id] or nil
      if new_obj == nil then return end
    end
    -- the telop that gives the texture format (and the picture of an entry without one): its own, else `from`'s
    local fmt_id = id
    if not T.has_base(lang, id) then fmt_id = from or id end
    local obj_src = new_obj or T.object(id)
    local route = {}
    local rkey = T.key("route", lang, id)
    if overridden[lang .. "\0" .. id] then
      local retail = T.retail(lang, id)
      if retail then
        local k = T.key("retail", lang, id)
        serve(k, retail)
        route.off = k
      else
        VRFW.log.debug(string.format("telop %s [%s]: a mod's whole file, no retail telop: shown in both settings", id, lang))
      end
    end
    if e.source == "mod_file" then
      -- the ModLoader's overlay serves it at the game path: `on` leaves the path alone
    elseif e.has_layout then
      -- the game's own texture path keeps the retail telop in both settings: the custom one is only named by the
      -- generated menu object
      route.on = route.off
      local set, err = T.layout(p.entry, lang, id, obj_src, fmt_id)
      if set then
        plan.built = plan.built + set.built
        plan.reused = plan.reused + set.reused
        local deps = {}
        for _, f in ipairs(set.files) do
          if f[1] ~= set.obj then deps[#deps + 1] = f[1] end
        end
        for _, f in ipairs(set.files) do
          if not ends_with(f[1], ".g4mg") then keep[#keep + 1] = f[1] end
          serve(f[1], f[2])
        end
        plan.needs[set.obj] = deps
        plan.objbins[id] = plan.objbins[id] or {}
        plan.objbins[id][lang] = set.obj
      else
        VRFW.log.error(string.format("%s: %s: retail telop kept", label, err))
      end
    elseif e.source == "retail" and not is_new then
      -- a TOML without picture or layout: the game's telop as it is
    else
      local b, err = T.banner(p.entry, lang, id, fmt_id)
      if not b then
        VRFW.log.error(string.format("%s: %s: retail telop kept", label, err))
        if route.off then plan.routes[rkey] = route end
        return
      end
      if b.built then plan.built = plan.built + 1 else plan.reused = plan.reused + 1 end
      keep[#keep + 1] = b.key
      serve(b.key, b.path)
      plan.direct[#plan.direct + 1] = { T.key("game", lang, id), b.path }
      route.on = b.key
      -- a telop only the mod has: shown whatever «Rótulos personalizados» says
      if is_new then route.off = b.key end
    end
    if route.on or route.off then plan.routes[rkey] = route end
  end

  for _, p in ipairs(picks) do one(p) end

  -- the hidden set of «Ocultar rótulos» (the run time's path hook routes hidden kinds to its menu object)
  local files, err = T.hidden()
  if files then
    for _, f in ipairs(files) do
      if plan.hidden == nil and ends_with(f[1], ".objbin") then plan.hidden = f[1] end
    end
    for _, f in ipairs(files) do
      if not ends_with(f[1], ".g4mg") then keep[#keep + 1] = f[1] end
      serve(f[1], f[2])
    end
  elseif files == nil then
    VRFW.log.warn(string.format("hidden telop set: %s: «Ocultar rótulos» cannot hide telops this session", err))
  end
  return plan, keep
end

return M
