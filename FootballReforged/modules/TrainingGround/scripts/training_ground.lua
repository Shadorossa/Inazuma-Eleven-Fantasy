-- Training Ground (module of Football Reforged; docs/game/mods/training-ground.md): a free field to rehearse moves,
-- combos and timings, no real match. This script owns the drill's settings (config.toml [training_ground]: rows,
-- formats, defaults; the player's choices in the global save data) and what they do inside a training match (the
-- framework's state key match.training = 1: the rulebook training_ground, content\rules\training_ground.toml). The game
-- Lua (graft training_ground) starts the drill with Plan() and draws the settings window (VRFW_MatchPanel) with
-- Rows() / Step(); content\game\training_ground.toml declares the commands.
--
--   CMND_TRAININGGROUND_ROWS()          -> { { key, label, value, text, map, pending, kind, disabled }, …, pending = n }
--                                          (pending = restart rows changed since the drill started: «Aplicar cambios»
--                                          restarts the match only then)
--   CMND_TRAININGGROUND_STEP(key, dir)  -> ok, override key ("" none), override value, apply (live / restart / action /
--                                          apply / picker)
--   CMND_TRAININGGROUND_PLAN()          -> { friendly, friendly_team, players, small, game, difficulty, stadium,
--                                          overrides = { { key, value }, … } } (friendly_team: the same drill played
--                                          with the active pachanga team, for a 5v5 whose VS team has no complete 5v5
--                                          line-up; small: the format's row is a small (5v5) match)
--   CMND_TRAININGGROUND_TEAM_NAME(id)   -> the name of a team (team_config id) in the game's language, or nil
--   CMND_TRAININGGROUND_LEAVE(relaunch) -> ok   (1 = start again from the hub, 0 = leave, -1 = the launch failed,
--                                                -2 = the match exit was refused: the drill goes on)
--   CMND_TRAININGGROUND_STATE()         -> training match on, relaunch asked (read once)
--   CMND_TRAININGGROUND_TEAMS(series)   -> { label, index, count, sel, items = { { id, emblem }, … } }: a page of the
--                                          rival team picker (series = 1-based, wraps; 0 = the page of the chosen team)
--   CMND_TRAININGGROUND_SET_TEAM(id, series) -> ok: the rival team (0 = the format row's own)
--
-- In a training match: SELECT (CMD_CHANGE_COACH_MODE) is taken (no coach mode) and asks the game Lua for the window
-- (rule flag training_ground.panel); the cooldown rows set the recast of the moves installed at kick-off (rule engine
-- trigger `recast`, long shots = skill effect bit 4 of the game's skill table); «tensión siempre al máximo» tops the
-- user's tension up; «sin gasto de PE» holds the user's players' PE drain at 0 and refills it (VRFW.resource, the mod
-- Stamina Points' PE); PEG / SP and «todos los tiros como tiros largos»: rule flags (the mod Aura Points' pools, the
-- framework's shot rules). Every effect stops at the end of the match. The way out: the window's «Salir» /
-- «Reiniciar» leave the match the retail way (CMND_VRFW_MATCH_EXIT) and the friendly's return = "menus" brings the
-- player back to the hub he started from with the in-memory game untouched; the drill never writes the save while it
-- runs (friendly save = "sink").

TrainingGround = TrainingGround or {}

local function info(...) VRFW.log("training_ground:", ...) end
-- crc32 of a name (a game id): the mod scripts' VRFW.ui.crc32
local function crc32(s) return bit32.band(VRFW.ui.crc32(s), 0xFFFFFFFF) end
local function warn(...) VRFW.warn("training_ground:", ...) end

local CFG = (VRFW.files and VRFW.files.config and VRFW.files.config("training_ground")) or {}
-- the key Inazuma Fantasy kept the settings under (content\game\save_import.toml copies it once)
local SAVE_KEY = "training_field.settings"
local PANEL_FLAG = "training_ground.panel"
local ARMED_FLAG = "training_ground.armed"  -- 1 while a training match runs (the HUD polls the panel key only then)
local PE = "stamina_points.pe"           -- the mod Stamina Points' match PE (none without it)
local LONG_SHOT_BIT = 4                    -- skill_effect_bit_flag: long shot (hissatsu-balance.md §col 9)
local TENSION_UNITS = 300                  -- a full gauge in the HUD's units (maxTensionPower)
local REFILL_MS = tonumber(CFG.refill_every_ms) or 400

local S = nil                -- the settings (defaults + the player's)
local running = nil          -- the restart settings of the drill being played (Plan)
local relaunch = false       -- the hub starts the drill again (Leave(1))
local launched = false       -- a drill was launched and not left yet
local armed = false          -- this training match's effects are on (first tick of a training match)
local pe_held = {}           -- hdl -> true: PE drain multiplier 0 set this match
local last_refill = {}       -- hdl -> ms
local last_tension = 0
local stadiums = {}          -- format key -> { { map, code }, … } in list order
local small_maps = nil       -- the maps the game plays its small (5v5, game type 2) matches on, first use first
local game_types = nil       -- game key crc -> game type (soccer_game_info)
local team_names = nil       -- team id -> name text id (team_config)
local long_moves = nil       -- skill id -> true (long-shot flag)
local tr_cache, tr_at = false, -1
local teams_by_series = nil  -- the picker's pages: { [series] = { { id, emblem }, … } }

-- ------------------------------------------------------------------------------------------------ settings

local function rows_cfg() return CFG.row or {} end
local function formats() return CFG.formats or {} end
local function format_of(key) return formats()[key] or formats()[(CFG.defaults or {}).format or ""] or {} end

local function row_of(key)
  for _, r in ipairs(rows_cfg()) do
    if r.key == key then return r end
  end
  return nil
end

local function load_settings()
  if S ~= nil then return S end
  S = {}
  for k, v in pairs(CFG.defaults or {}) do S[k] = v end
  local ok, saved = pcall(VRFW.save.global_get, SAVE_KEY)
  if ok and type(saved) == "table" then
    for k, v in pairs(saved) do
      if S[k] ~= nil and type(S[k]) == type(v) then S[k] = v end
    end
  end
  return S
end

local function save_settings()
  pcall(VRFW.save.global_set, SAVE_KEY, S)
  pcall(VRFW.save.commit)
end

local function players_of(fmt) return tonumber(format_of(fmt).players) or 11 end
local function min_rivals() return math.max(0, tonumber(CFG.min_rivals) or 0) end
local function levels_of(fmt)
  local d = format_of(fmt).difficulties
  if type(d) ~= "table" or #d == 0 then return {1} end
  return d
end

local function clamp_settings()
  local s = load_settings()
  if formats()[s.format] == nil then s.format = (CFG.defaults or {}).format end
  local n = players_of(s.format)
  s.rivals = math.max(min_rivals(), math.min(n, math.floor(tonumber(s.rivals) or n)))
  s.level = math.max(1, math.min(#levels_of(s.format), math.floor(tonumber(s.level) or 1)))
end

-- the game's match rows (soccer_game_info): each row's game type and the maps of its small (5v5) matches. A small
-- match draws its pitch at 0.7 with the 5v5 lines and goals (docs/game/modes/formatos-3v3-7v7.md §6.1); only the maps
-- with that line set show them (the b* fields; the s* stadiums carry only the 11v11 lines, so a 5v5 on them showed
-- 11v11 lines: owner 2026-10-12). The maps the game itself plays its small matches on are the ones that have them.
local function game_rows()
  if game_types ~= nil then return end
  game_types, small_maps = {}, {}
  local ok, rows = pcall(VRFW.table.rows, "soccer/soccer_game_info")
  if not ok or type(rows) ~= "table" then
    warn("no match rows (soccer_game_info): " .. tostring(rows))
    return
  end
  local seen = {}
  for _, r in ipairs(rows) do
    local name, ty, map = r.name or r[2], tonumber(r.game_type or r[3]), tonumber(r.stadium_map or r[4])
    if type(name) == "string" and ty ~= nil then game_types[crc32(name)] = ty end
    if ty == 2 and map ~= nil and map ~= 0 then
      map = bit32.band(map, 0xFFFFFFFF)
      if not seen[map] then
        seen[map] = true
        small_maps[#small_maps + 1] = map
      end
    end
  end
  info(string.format("%d match rows, %d maps of small (5v5) matches", #rows, #small_maps))
end

local function game_type_of(game)
  game_rows()
  return game_types[crc32(game or "")]
end

-- the free-match stadium list as the game reads it (SOCCER_OPTION_FIELD_INFO, mods' rows included), list order
local function free_list()
  local out = {}
  local ok, rows = pcall(VRFW.table.rows, "soccer/soccer_option_field_info")
  if not ok or type(rows) ~= "table" then
    warn("no stadium list (soccer_option_field_info): " .. tostring(rows))
    return out
  end
  for _, r in ipairs(rows) do
    local map = tonumber(r.c0 or r[1])
    if map ~= nil and map ~= 0 then
      local pic = tostring(r.c3 or r[4] or "")
      out[#out + 1] = { map = bit32.band(map, 0xFFFFFFFF), order = tonumber(r.c1 or r[2]) or 0,
        code = pic:match("img_room_([%w_]+)%.g4tx") or "" }
    end
  end
  table.sort(out, function(x, y)
    if x.order ~= y.order then return x.order < y.order end
    return x.map < y.map
  end)
  return out
end

-- the stadiums of a format: 11v11 = the free-match list; a small-match format (its row is game type 2) = the
-- free-match stadiums the game plays small matches on, then the other maps of its small matches (the street pitches),
-- so the pitch always shows the 5v5 lines
local function stadium_list(fmt)
  fmt = fmt or load_settings().format
  if stadiums[fmt] ~= nil then return stadiums[fmt] end
  local base = free_list()
  local list = base
  if game_type_of(format_of(fmt).game) == 2 then
    local small, used = {}, {}
    for _, m in ipairs(small_maps) do small[m] = true end
    list = {}
    for _, st in ipairs(base) do
      if small[st.map] then
        list[#list + 1] = st
        used[st.map] = true
      end
    end
    for _, m in ipairs(small_maps) do
      if not used[m] then list[#list + 1] = { map = m, order = 0, code = "" } end
    end
  end
  stadiums[fmt] = list
  info(string.format("format %s: %d stadiums (%s)", tostring(fmt), #list,
    list == base and "the free-match list" or "maps with the 5v5 lines"))
  return list
end

local function stadium_index(map, fmt)
  local l = stadium_list(fmt)
  for i, st in ipairs(l) do
    if st.map == map then return i end
  end
  return 1
end

-- the rival team picker's pages: every team of the game's team table (team_config, mods' teams included) by the key
-- prefixes of config.toml [training_ground.picker] series; a team no series names goes to the `rest` page
local function team_pages()
  if teams_by_series ~= nil then return teams_by_series end
  teams_by_series = {}
  local P = CFG.picker or {}
  local series = P.series or {}
  local rest = nil
  for i, sr in ipairs(series) do
    teams_by_series[i] = {}
    if sr.rest then rest = i end
  end
  local ok, rows = pcall(VRFW.table.rows, "team/team")
  if not ok or type(rows) ~= "table" then
    warn("no team table (team/team): " .. tostring(rows))
    return teams_by_series
  end
  local n = 0
  for _, r in ipairs(rows) do
    local id, key = tonumber(r.id or r[1]), tostring(r.key or r[2] or "")
    local skip = id == nil or id == 0 or key == ""
    for _, x in ipairs(P.exclude or {}) do
      if key:sub(1, #x) == x then skip = true end
    end
    if not skip then
      local page = nil
      for i, sr in ipairs(series) do
        for _, pre in ipairs(sr.prefixes or {}) do
          if page == nil and key:sub(1, #pre) == pre then page = i end
        end
      end
      page = page or rest
      if page ~= nil then
        local e = tonumber(r.emblem or r[7]) or 0
        table.insert(teams_by_series[page], { id = bit32.band(id, 0xFFFFFFFF), emblem = bit32.band(e, 0xFFFFFFFF) })
        n = n + 1
      end
    end
  end
  info(string.format("rival team picker: %d teams in %d series", n, #series))
  return teams_by_series
end

local function current_stadium()
  local s = load_settings()
  local l = stadium_list(s.format)
  return l[stadium_index(tonumber(s.stadium) or 0, s.format)]
end

-- a team's name in the game's language (team_config name_text through the text engine), nil = unknown
local function team_name(id)
  id = bit32.band(math.floor(tonumber(id) or 0), 0xFFFFFFFF)
  if id == 0 then return nil end
  if team_names == nil then
    team_names = {}
    local ok, rows = pcall(VRFW.table.rows, "team/team")
    if ok and type(rows) == "table" then
      for _, r in ipairs(rows) do
        local tid, nt = tonumber(r.id or r[1]), tonumber(r.name_text or r[4])
        if tid and nt and nt ~= 0 then team_names[bit32.band(tid, 0xFFFFFFFF)] = bit32.band(nt, 0xFFFFFFFF) end
      end
    end
  end
  local nt = team_names[id]
  if nt == nil then return nil end
  local ok, name = pcall(VRFW.text, string.format("%d", nt))
  if ok and type(name) == "string" and name ~= "" then return name end
  return nil
end

-- ------------------------------------------------------------------------------------------------ match state

local function training()
  local now = VRFW.now()
  if now ~= tr_at then
    tr_at = now
    local ok, v = pcall(VRFW.state, "match.training")
    tr_cache = ok and tonumber(v) == 1
  end
  return tr_cache
end

local function is_long_shot(skill)
  if long_moves == nil then
    long_moves = {}
    local ok, rows = pcall(VRFW.table.rows, "skill/skill")
    if ok and type(rows) == "table" then
      local n = 0
      for _, r in ipairs(rows) do
        local id, flags = tonumber(r.skill_id or r[1]), tonumber(r.skill_effect_bit_flag or r[10])
        if id and flags and bit32.band(flags, LONG_SHOT_BIT) ~= 0 then
          long_moves[bit32.band(id, 0xFFFFFFFF)] = true
          n = n + 1
        end
      end
      info(string.format("%d long-shot moves in the skill table", n))
    else
      warn("no skill table: every move counts as a special move for the cooldown rows")
    end
  end
  return skill ~= nil and long_moves[bit32.band(skill, 0xFFFFFFFF)] == true
end

local function set_flags(on)
  local s = load_settings()
  for _, r in ipairs(rows_cfg()) do
    if type(r.flag) == "string" then
      pcall(VRFW.set_flag, r.flag, (on and s[r.key] == true) and 1 or 0)
    end
  end
end

local function release_pe()
  for hdl in pairs(pe_held) do
    pcall(VRFW.resource.set_mult, PE, hdl, "training_ground", 1)
  end
  pe_held, last_refill = {}, {}
end

local function arm()
  armed = true
  pe_held, last_refill, last_tension = {}, {}, 0
  set_flags(true)
  pcall(VRFW.set_flag, ARMED_FLAG, 1)
  info("training match: effects on")
end

local function disarm(why)
  if not armed then return end
  armed = false
  set_flags(false)
  release_pe()
  pcall(VRFW.clear_flag, PANEL_FLAG)
  pcall(VRFW.clear_flag, ARMED_FLAG)
  info("training match: effects off (" .. why .. ")")
end

-- ------------------------------------------------------------------------------------------------ commands

local function bool_text(v) return v and "training_ground_on" or "training_ground_off" end

function TrainingGround.Rows()
  clamp_settings()
  local s = S
  local out = {}
  local pending = 0
  if running ~= nil and training() then
    for _, r in ipairs(rows_cfg()) do
      if r.apply == "restart" and running[r.key] ~= s[r.key] then pending = pending + 1 end
    end
  end
  for _, r in ipairs(rows_cfg()) do
    local row = { key = r.key, label = r.label or "", value = "", text = "", map = 0, pending = 0, kind = r.kind or "",
      disabled = 0 }
    local v = s[r.key]
    if r.kind == "stadium" then
      local st = current_stadium()
      row.map = st and st.map or 0
      row.text = st and st.code or ""
    elseif r.kind == "choice" then
      row.value = format_of(v).label or ""
    elseif r.kind == "count" then
      if v == 0 then row.value = "training_ground_val_empty" else row.text = tostring(v) end
    elseif r.kind == "level" then
      local n = #levels_of(s.format)
      row.text = string.format("%d / %d", v or 1, n)
      if n <= 1 then row.disabled = 1 end
    elseif r.kind == "toggle" then
      row.value = bool_text(v == true)
    elseif r.kind == "team" then
      -- the team (0 = the format row's own: the game Lua asks the row for it)
      local f = format_of(s.format)
      local lv = levels_of(s.format)
      row.team = tonumber(v) or 0
      row.game = crc32(f.game or "")
      row.difficulty = lv[s.level] or lv[1]
      row.text = team_name(row.team) or ""
    elseif r.kind == "apply" then
      -- «Aplicar cambios»: restarts the match when a restart row changed; the live rows are applied already
      if pending > 0 then row.value = "training_ground_val_apply_restart" end
    end
    if r.apply == "restart" and running ~= nil and training() and running[r.key] ~= v then row.pending = 1 end
    out[#out + 1] = row
  end
  out.style = CFG.style   -- the window's sprites, nil = the framework's retail look (not a row: ipairs skips it)
  out.pending = pending
  return out
end

local function cycle(i, n, dir)
  if n <= 0 then return 1 end
  return ((i - 1 + dir) % n) + 1
end

function TrainingGround.Step(key, dir)
  clamp_settings()
  local r = row_of(key)
  if r == nil then return false, "", 0, "" end
  dir = (tonumber(dir) or 1) < 0 and -1 or 1
  local s = S
  if r.kind == "action" then return true, "", 0, "action" end
  if r.kind == "apply" then return true, "", 0, "apply" end
  if r.kind == "team" then return true, "", 0, "picker" end   -- the game Lua opens the picker
  if r.kind == "stadium" then
    local l = stadium_list(s.format)
    if #l > 0 then s.stadium = l[cycle(stadium_index(tonumber(s.stadium) or 0, s.format), #l, dir)].map end
  elseif r.kind == "choice" then
    local vals = r.values or {}
    local i = 1
    for k, v in ipairs(vals) do if v == s[key] then i = k end end
    s[key] = vals[cycle(i, #vals, dir)] or s[key]
    if key == "format" then s.rivals = players_of(s.format) end   -- a new format starts full
  elseif r.kind == "count" then
    local lo, hi = min_rivals(), players_of(s.format)
    s.rivals = lo + ((math.floor(tonumber(s.rivals) or hi) - lo + dir) % (hi - lo + 1))
  elseif r.kind == "level" then
    s.level = cycle(math.floor(tonumber(s.level) or 1), #levels_of(s.format), dir)
  elseif r.kind == "toggle" then
    s[key] = not (s[key] == true)
  end
  clamp_settings()
  save_settings()
  local live = r.apply == "live" and training()
  if live then
    if r.flag then pcall(VRFW.set_flag, r.flag, s[key] == true and 1 or 0) end
    if key == "free_pe" and s[key] ~= true then release_pe() end
  end
  info(string.format("setting %s = %s (%s%s)", key, tostring(s[key]), r.apply or "", live and ", live" or ""))
  local okey, oval = "", 0
  if type(r.override) == "string" and r.kind == "toggle" and r.apply == "live" then
    okey, oval = r.override, (s[key] == true) and 1 or 0
  end
  return true, okey, oval, r.apply or ""
end

function TrainingGround.Plan()
  clamp_settings()
  local s = S
  local f = format_of(s.format)
  local lv = levels_of(s.format)
  local st = current_stadium()
  local overrides = {}
  for _, r in ipairs(rows_cfg()) do
    if type(r.override) == "string" then
      local v = s[r.key]
      if type(v) == "boolean" then v = v and 1 or 0 end
      overrides[#overrides + 1] = { r.override, tonumber(v) or 0 }
    end
  end
  running = {}
  for k, v in pairs(s) do running[k] = v end
  launched, armed = true, false
  local plan = { friendly = CFG.friendly or "training_ground", friendly_team = CFG.friendly_team or "",
    players = players_of(s.format), small = game_type_of(f.game) == 2,
    game = crc32(f.game or ""), difficulty = lv[s.level] or lv[1], stadium = st and st.map or 0, overrides = overrides }
  info(string.format("plan: %s game %s (0x%08X) class %s stadium %s (0x%08X), %d rival(s), %d override(s)",
    plan.friendly, tostring(f.game), plan.game, tostring(plan.difficulty), st and st.code or "row", plan.stadium,
    s.rivals or -1, #overrides))
  return plan
end

function TrainingGround.Teams(series)
  local pages = team_pages()
  local n = #pages
  if n == 0 then return { label = "", index = 0, count = 0, sel = 1, items = {} } end
  local s = load_settings()
  local i = math.floor(tonumber(series) or 0)
  local sel = 1
  if i == 0 then
    -- the page of the chosen team (else the last page opened)
    i = math.max(1, math.min(n, math.floor(tonumber(s.rival_series) or 1)))
    for pi, list in ipairs(pages) do
      for k, t in ipairs(list) do
        if t.id == bit32.band(tonumber(s.rival_team) or 0, 0xFFFFFFFF) and s.rival_team ~= 0 then i, sel = pi, k end
      end
    end
  else
    i = ((i - 1) % n) + 1
  end
  local sr = ((CFG.picker or {}).series or {})[i] or {}
  local items = {}
  for k, t in ipairs(pages[i]) do
    items[k] = { id = t.id, emblem = t.emblem, name = team_name(t.id) or "" }
  end
  return { label = sr.label or "", index = i, count = n, sel = sel, items = items }
end

function TrainingGround.TeamName(id)
  return team_name(id)
end

function TrainingGround.SetTeam(id, series)
  local s = load_settings()
  s.rival_team = bit32.band(math.floor(tonumber(id) or 0), 0xFFFFFFFF)
  if tonumber(series) then s.rival_series = math.floor(tonumber(series)) end
  save_settings()
  info(string.format("rival team = 0x%08X (series %s)", s.rival_team, tostring(s.rival_series)))
  return true
end

function TrainingGround.Leave(how)
  how = tonumber(how) or 0
  if how == -2 then
    relaunch = false
    warn("the match exit was refused: the drill goes on")
    return true
  end
  if how < 0 then
    launched, running = false, nil
    info("launch failed: nothing to leave")
    return true
  end
  relaunch = how == 1
  info(relaunch and "leaving the drill to start it again" or "leaving the drill")
  return true
end

function TrainingGround.State()
  local r = relaunch
  relaunch = false
  return training(), r and 1 or 0
end

-- ------------------------------------------------------------------------------------------------ match handlers

VRFW.on("tick", function(ev)
  if not training() then
    if armed then disarm("not a training match") end
    return nil
  end
  if not armed then arm() end
  local s = load_settings()
  if s.tension_full == true then
    local now = VRFW.now()
    if now - last_tension >= REFILL_MS then
      last_tension = now
      return { add_tension = TENSION_UNITS, tension_team = "user" }
    end
  end
  return nil
end)

VRFW.on("actor_tick", function(ev)
  local a = ev.actor
  if a == nil or a.side ~= "user" or not armed or not training() then return nil end
  if load_settings().free_pe ~= true then return nil end
  local hdl = a.handle
  local now = VRFW.now()
  if (last_refill[hdl] or -REFILL_MS) + REFILL_MS > now then return nil end
  last_refill[hdl] = now
  if not pe_held[hdl] then
    pe_held[hdl] = pcall(VRFW.resource.set_mult, PE, hdl, "training_ground", 0)
  end
  local ok, v = pcall(VRFW.resource.get, PE, hdl)
  if ok and type(v) == "table" and type(v.cur) == "number" and type(v.max) == "number" and v.cur < v.max then
    pcall(VRFW.resource.add, PE, hdl, v.max - v.cur)
  end
  return nil
end)

-- a move's PE price (pe_sacrifice moves) comes straight back
VRFW.on("resource:stamina_points.pe:paid", function(ev)
  if not armed or ev.actor == nil or ev.actor.side ~= "user" or load_settings().free_pe ~= true then return nil end
  local ok, v = pcall(VRFW.resource.get, PE, ev.actor.handle)
  if ok and type(v) == "table" and type(v.max) == "number" then
    pcall(VRFW.resource.add, PE, ev.actor.handle, v.max)
  end
  return nil
end)

-- the recast of each move installed in the drill (kick-off, a slot change): the cooldown rows
VRFW.on("recast", function(ev)
  if not training() then return nil end
  local s = load_settings()
  if is_long_shot(ev.skill) then
    if s.cooldown_long_shots == false then return { recast_mult = 0 } end
  elseif s.cooldown_moves == false then
    return { recast_mult = 0 }
  end
  return nil
end)

-- SELECT opens the settings window instead of the coach mode (the game Lua polls the flag)
VRFW.on("button_press:CMD_CHANGE_COACH_MODE", function(ev)
  if not training() then return nil end
  pcall(VRFW.set_flag, PANEL_FLAG, 1)
  return { block = true }
end)

-- the drill's match ended (the window's way out, the retail hold-to-leave): the friendly's way back (return = "menus")
-- reopens the hub with the in-memory game as it was; nothing is reset or reloaded here
VRFW.on("match_end", function(ev)
  disarm("match end")
  if launched then
    launched = false
    info(string.format("drill left: back to the hub with the game kept, relaunch %s", tostring(relaunch)))
  end
  return nil
end)

-- the retail pause menu's return to the title during a drill: the effects stop; the game is the retail one (the title
-- keeps or reads it as the retail rule says; pachanga_title closes the friendly). Nothing is written here.
VRFW.on("game_reset", function(ev)
  disarm("title")
  if launched then
    launched, relaunch = false, false
    info("drill left by a return to the title")
  end
  return nil
end)
