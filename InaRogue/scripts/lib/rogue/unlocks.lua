-- InaRogue › INAROGUE unlocks -> the office (docs/game/modes/inarogue-unlocks.md). Was unlocks.rs /
-- unlocks_rt.rs of the DLL's module rogue.
--
-- * Catalogue (content\rogue\unlocks.toml, [rogue.unlocks] file): one [[card]] per unlockable card (param, price, level, hint,
--   [[card.when]] conditions, all must hold). Nothing is granted: an unlock opens the card's office row.
-- * Store: ONE global blob rogue_unlocks.json (every normal slot sees the same unlocks; the DLL's JSON): lifetime
--   counters, latched event conditions, unlocked cards, the announcements already shown, the per-coach counters and
--   every rival ever beaten.
-- * Counter rules: phase, wins, bosses, runs, runs_won, album, coach_runs_won, coach_boss_phase, coach_wins. Event rules
--   (latched per card): boss_phase, beat, with_player, rival_with_player, beat_era.

local U = require "lib/rogue/util"
local J = require "lib/rogue/json"
local Rules = require "lib/rogue/run_rules"
local info, warn, err = U.logger("rogue unlocks")

local X = {}

X.SCHEMA, X.STORE_SCHEMA, X.STORE_VERSION, X.BLOB = "inazuma_fantasy.rogue_unlocks/1", "inazuma_fantasy.rogue_unlocks_store/1", 1, "rogue_unlocks.json"
X.KIND_SMALL, X.KIND_FULL, X.KIND_BOSS, X.KIND_ELITE = 1, 2, 3, 7

local EVENT = { boss_phase = true, beat = true, with_player = true, rival_with_player = true, beat_era = true }
local COUNTER = { phase = true, wins = true, bosses = true, runs = true, runs_won = true, album = true,
  coach_runs_won = true, coach_boss_phase = true, coach_wins = true }
local NODE_SEL = { any = true, boss = true, elite = true, boss_or_elite = true }
-- the fields each rule type takes (the DLL refused a file with an unknown one)
local FIELDS = {
  phase = { "phase" }, boss_phase = { "phase" }, beat = { "rival", "node", "phase" },
  with_player = { "params", "label", "node", "phase" }, wins = { "count" }, bosses = { "count" }, runs = { "count" },
  runs_won = { "count" }, album = { "count" }, rival_with_player = { "rival", "params", "label", "node", "phase" },
  beat_era = { "era", "node", "phase" }, coach_runs_won = { "coach", "count" }, coach_boss_phase = { "coach", "phase" },
  coach_wins = { "coach", "count" },
}
local REQUIRED = {
  phase = { "phase" }, boss_phase = { "phase" }, beat = { "rival" }, with_player = { "params" }, wins = { "count" },
  bosses = { "count" }, runs = { "count" }, runs_won = { "count" }, album = { "count" },
  rival_with_player = { "rival", "params" }, beat_era = { "era" }, coach_runs_won = { "coach", "count" },
  coach_boss_phase = { "coach", "phase" }, coach_wins = { "coach", "count" },
}

function X.is_event(c) return EVENT[c.type] == true end

local function node_accepts(sel, kind)
  if sel == "any" then return kind == 1 or kind == 2 or kind == 3 or kind == 7 end
  if sel == "elite" then return kind == 7 end
  if sel == "boss_or_elite" then return kind == 3 or kind == 7 end
  return kind == 3
end

-- the rule texts: InaRogue.unlock.* rows (text/rows/rogue_screens.toml), in the game's language
local function T(name, ...)
  return Rules.text("InaRogue.unlock." .. name, ...)
end

local function node_word(sel)
  if sel == "any" then return T("node_any") end
  if sel == "elite" then return T("node_elite") end
  if sel == "boss_or_elite" then return T("node_boss_or_elite") end
  return T("node_boss")
end

-- one condition table -> a rule, or nil + why
function X.parse_cond(t)
  if type(t) ~= "table" or type(t.type) ~= "string" then return nil, "a rule needs `type`" end
  local ty = t.type
  local fields = FIELDS[ty]
  if not fields then return nil, "unknown rule type `" .. ty .. "`" end
  local allowed = { type = true }
  for _, f in ipairs(fields) do allowed[f] = true end
  for k in pairs(t) do
    if not allowed[k] then return nil, "rule `" .. ty .. "`: unknown field `" .. tostring(k) .. "`" end
  end
  for _, f in ipairs(REQUIRED[ty]) do
    if t[f] == nil then return nil, "rule `" .. ty .. "`: missing field `" .. f .. "`" end
  end
  local node = t.node or "boss"
  if not NODE_SEL[node] then return nil, "rule `" .. ty .. "`: node `" .. tostring(node) .. "`" end
  local params = {}
  for _, p in ipairs(type(t.params) == "table" and t.params or {}) do params[#params + 1] = p % U.TWO32 end
  return {
    type = ty, phase = U.int(t.phase, 0), count = U.int(t.count, 0), rival = t.rival and tostring(t.rival) or "",
    params = params, label = t.label and tostring(t.label) or "", node = node, era = t.era and tostring(t.era) or "",
    coach = t.coach and tostring(t.coach) or "",
  }
end

-- the description of a rule in the game's language (the hint when the card has none)
function X.describe(c, coach_name)
  local ty = c.type
  local function ph(s)
    if c.phase > 1 then return T("from_phase", s, c.phase) end
    return s
  end
  if ty == "phase" then return T("phase", c.phase) end
  if ty == "boss_phase" then
    if c.phase <= 1 then return T("first_boss") end
    return T("boss_phase", c.phase)
  end
  if ty == "beat" then
    local key = "beat"
    if c.node == "boss" then key = "beat_boss" elseif c.node == "elite" then key = "beat_elite"
    elseif c.node == "boss_or_elite" then key = "beat_boss_or_elite" end
    return ph(T(key, c.rival))
  end
  if ty == "with_player" then
    local who = c.label ~= "" and c.label or T("chosen_players", #c.params)
    return ph(T("with_player", node_word(c.node), who))
  end
  if ty == "wins" then return T("wins", c.count) end
  if ty == "bosses" then return T("bosses", c.count) end
  if ty == "runs" then return T("runs", c.count) end
  if ty == "runs_won" then return T("runs_won", c.count) end
  if ty == "album" then return T("album", c.count) end
  if ty == "rival_with_player" then
    local who = c.label ~= "" and c.label or T("guest_players", #c.params)
    return T("rival_with_player", c.rival, who)
  end
  if ty == "beat_era" then return T("beat_era", node_word(c.node), string.upper(c.era)) end
  local name = (coach_name and coach_name(c.coach)) or c.coach
  if ty == "coach_runs_won" then
    if c.count <= 1 then return T("coach_run_won", name) end
    return T("coach_runs_won", c.count, name)
  end
  if ty == "coach_boss_phase" then return T("coach_boss_phase", c.phase, name) end
  if ty == "coach_wins" then return T("coach_wins", c.count, name) end
  return ""
end

-- the rule descriptions joined as «a and b and c» in the game's language
function X.join(parts)
  local s = parts[1] or ""
  for i = 2, #parts do s = T("and", s, parts[i]) end
  return s
end

-- ---------------------------------------------------------------------------------------- catalogue

local cat = nil

local function parse_catalogue(t)
  if t.schema ~= X.SCHEMA then return nil, "schema `" .. tostring(t.schema) .. "` (expected `" .. X.SCHEMA .. "`)" end
  local o = type(t.office) == "table" and t.office or {}
  local c = {
    office = {
      shop = type(o.shop) == "string" and o.shop or "evt_oficina_4", slot = U.int(o.slot, 51),
      game = type(o.game) == "string" and o.game or "evt_ofi_inarogue", title = type(o.title) == "string" and o.title or "INAROGUE",
      show_locked = o.show_locked ~= false,
    },
    cards = {},
  }
  local ids, params = {}, {}
  for _, k in ipairs(type(t.card) == "table" and t.card or {}) do
    local id = type(k.id) == "string" and k.id or ""
    if id == "" or id:find("[^a-z0-9_]") then return nil, "card id `" .. id .. "`: a-z 0-9 _" end
    if ids[id] then return nil, "card `" .. id .. "` declared twice" end
    ids[id] = true
    local param = type(k.param) == "number" and k.param % U.TWO32 or 0
    if param == 0 or params[param] then return nil, string.format("card `%s`: param 0x%08X missing or used twice", id, param) end
    params[param] = true
    if type(k.name) ~= "string" then return nil, "card `" .. id .. "`: missing field `name`" end
    local when = {}
    for _, w in ipairs(type(k.when) == "table" and k.when or {}) do
      local r, why = X.parse_cond(w)
      if not r then return nil, "card `" .. id .. "`: " .. why end
      if (r.type == "with_player" or r.type == "rival_with_player") and #r.params == 0 then
        return nil, "card `" .. id .. "`: with_player needs params"
      end
      when[#when + 1] = r
    end
    if k.enabled ~= false then
      c.cards[#c.cards + 1] = { id = id, param = param, name = k.name, hint = type(k.hint) == "string" and k.hint or "",
        price = U.int(k.price, 0), level = U.int(k.level, 1), when = when }
    end
  end
  return c
end

function X.catalogue(ucfg)
  if cat then return cat end
  cat = { office = { shop = "evt_oficina_4", slot = 51, game = "evt_ofi_inarogue", title = "INAROGUE", show_locked = true }, cards = {} }
  local ok, t = pcall(VRFW.files.toml, ucfg.file)
  if not ok or type(t) ~= "table" then
    warn(ucfg.file .. ": " .. tostring(t) .. "; no INAROGUE unlocks")
  else
    local c, why = parse_catalogue(t)
    if c then cat = c else warn(ucfg.file .. ": " .. why .. "; no INAROGUE unlocks") end
  end
  info(string.format("%d cards (office %s slot %d, show_locked %s), enabled %s unlock_all %s", #cat.cards, cat.office.shop,
    cat.office.slot, tostring(cat.office.show_locked), tostring(ucfg.enabled), tostring(ucfg.unlock_all)))
  return cat
end

function X.card_by_param(c, param)
  for _, k in ipairs(c.cards) do
    if k.param == param then return k end
  end
  return nil
end

function X.card_by_id(c, id)
  for _, k in ipairs(c.cards) do
    if k.id == id then return k end
  end
  return nil
end

function X.hint_text(card)
  local h = U.trim(card.hint)
  if h ~= "" then return h end
  if #card.when == 0 then return T("in_inarogue") end
  local parts = {}
  for i, w in ipairs(card.when) do parts[i] = X.describe(w) end
  return X.join(parts)
end

-- ---------------------------------------------------------------------------------------- store

local STATS = { "wins", "bosses", "runs", "runs_won", "best_phase", "best_boss_phase", "album" }
local CSTATS = { "wins", "bosses", "best_boss_phase", "runs", "runs_won" }

function X.new_store()
  local s = { seeded = false, stats = {}, latched = {}, unlocked = {}, seen_rogue = {}, seen_office = {}, coach = {}, beaten = {} }
  for _, k in ipairs(STATS) do s.stats[k] = 0 end
  return s
end

local function set_of(v)
  local o = {}
  if type(v) == "table" then
    for _, x in ipairs(v) do
      if type(x) == "string" then o[x] = true end
    end
  end
  return o
end

function X.store_from_json(j)
  if type(j) ~= "table" then return nil, "not an object" end
  if type(j.schema) == "string" and j.schema ~= "" and j.schema ~= X.STORE_SCHEMA then
    return nil, "schema `" .. j.schema .. "` (expected `" .. X.STORE_SCHEMA .. "`)"
  end
  local s = X.new_store()
  s.seeded = U.val(j.seeded) == true
  local st = type(U.val(j.stats)) == "table" and j.stats or {}
  for _, k in ipairs(STATS) do s.stats[k] = U.int(st[k], 0) end
  s.latched = set_of(j.latched)
  for _, u in ipairs(type(j.unlocked) == "table" and j.unlocked or {}) do
    if type(u) == "table" and type(u.id) == "string" and type(u.param) == "number" then
      s.unlocked[#s.unlocked + 1] = { id = u.id, param = u.param, date = U.int(u.date, 0), phase = U.int(u.phase, 0) }
    end
  end
  s.seen_rogue = set_of(j.seen_rogue)
  if type(U.val(j.seen_office)) == "table" then
    for k, v in pairs(j.seen_office) do s.seen_office[tostring(k)] = set_of(v) end
  end
  if type(U.val(j.coach)) == "table" then
    for k, v in pairs(j.coach) do
      local c = {}
      for _, f in ipairs(CSTATS) do c[f] = U.int(type(v) == "table" and v[f] or nil, 0) end
      s.coach[tostring(k)] = c
    end
  end
  s.beaten = set_of(j.beaten)
  return s
end

function X.store_to_json(s)
  local stats = {}
  for i, k in ipairs(STATS) do stats[i] = { k, s.stats[k] } end
  local unlocked = {}
  for i, u in ipairs(s.unlocked) do
    unlocked[i] = J.obj({ { "id", u.id }, { "param", u.param }, { "date", u.date }, { "phase", u.phase } })
  end
  local office = {}
  for _, k in ipairs(J.sorted_keys(s.seen_office)) do office[#office + 1] = { k, J.arr(J.sorted_keys(s.seen_office[k])) } end
  local coach = {}
  for _, k in ipairs(J.sorted_keys(s.coach)) do
    local c = s.coach[k]
    local f = {}
    for i, n in ipairs(CSTATS) do f[i] = { n, c[n] } end
    coach[#coach + 1] = { k, J.obj(f) }
  end
  return J.pretty(J.obj({
    { "schema", X.STORE_SCHEMA }, { "version", X.STORE_VERSION }, { "seeded", s.seeded }, { "stats", J.obj(stats) },
    { "latched", J.arr(J.sorted_keys(s.latched)) }, { "unlocked", J.arr(unlocked) },
    { "seen_rogue", J.arr(J.sorted_keys(s.seen_rogue)) }, { "seen_office", J.obj(office) }, { "coach", J.obj(coach) },
    { "beaten", J.arr(J.sorted_keys(s.beaten)) },
  }))
end

local store = nil

-- the global store (loaded once; an unreadable blob is set aside and a new store starts)
function X.store()
  if store then return store end
  local text, why = U.blob_read(X.BLOB, "global")
  if text == false then
    err(X.BLOB .. " unreadable (" .. tostring(why) .. "): a new store for now")
    store = X.new_store()
    return store
  end
  if text then
    local j, e = U.json(text)
    local s
    if j then s, e = X.store_from_json(j) end
    if not s then
      local kept = U.blob_aside(X.BLOB, "global")
      err(string.format("%s: %s; %s; new store", X.BLOB, tostring(e), tostring(kept)))
      s = X.new_store()
    end
    store = s
  else
    store = X.new_store()
  end
  local latched = 0
  for _ in pairs(store.latched) do latched = latched + 1 end
  info(string.format("store loaded: %d unlocked, %d conditions met, best phase %d, wins %d", #store.unlocked, latched,
    store.stats.best_phase, store.stats.wins))
  return store
end

function X.save(why)
  local ok, where = U.blob_write(X.BLOB, X.store_to_json(store), "global")
  if ok then info("saved (" .. why .. ") -> " .. tostring(where)) else err("cannot write the store (" .. why .. "): " .. tostring(where)) end
end

function X.is_unlocked(s, id)
  for _, u in ipairs(s.unlocked) do
    if u.id == id then return true end
  end
  return false
end

function X.seed(s, runs, runs_won, best_phase)
  if s.seeded then return false end
  s.seeded = true
  s.stats.runs = math.max(s.stats.runs, runs)
  s.stats.runs_won = math.max(s.stats.runs_won, runs_won)
  s.stats.best_phase = math.max(s.stats.best_phase, best_phase)
  return true
end

function X.coach_stats(s, id)
  return s.coach[id] or { wins = 0, bosses = 0, best_boss_phase = 0, runs = 0, runs_won = 0 }
end

-- progress of a counter rule: have, need (nil = an event rule)
function X.progress(s, c)
  local st = s.stats
  local ty = c.type
  if ty == "phase" then return st.best_phase, c.phase end
  if ty == "wins" then return st.wins, c.count end
  if ty == "bosses" then return st.bosses, c.count end
  if ty == "runs" then return st.runs, c.count end
  if ty == "runs_won" then return st.runs_won, c.count end
  if ty == "album" then return st.album, c.count end
  if ty == "coach_runs_won" then return X.coach_stats(s, c.coach).runs_won, c.count end
  if ty == "coach_boss_phase" then return X.coach_stats(s, c.coach).best_boss_phase, c.phase end
  if ty == "coach_wins" then return X.coach_stats(s, c.coach).wins, c.count end
  return nil
end

function X.cond_met(s, c)
  local have, need = X.progress(s, c)
  if have == nil then return nil end
  return have >= need
end

local function latch_key(id, i) return id .. "#" .. (i - 1) end

function X.met(s, card, i)
  local c = card.when[i]
  if not c then return false end
  if X.is_event(c) then return s.latched[latch_key(card.id, i)] == true end
  return X.cond_met(s, c) == true
end

function X.hint_with_progress(s, card)
  local h = X.hint_text(card)
  local parts = {}
  for i, c in ipairs(card.when) do
    if not X.met(s, card, i) then
      local have, need = X.progress(s, c)
      if have ~= nil then parts[#parts + 1] = string.format("%d/%d", math.min(have, need), need) end
    end
  end
  if #parts > 0 then h = h .. " (" .. table.concat(parts, ", ") .. ")" end
  return h
end

-- the per-coach counters for one run event of a run led by `coach`
function X.apply_coach(s, coach, ev)
  if coach == "" then return false end
  local c = s.coach[coach]
  if not c then
    c = { wins = 0, bosses = 0, best_boss_phase = 0, runs = 0, runs_won = 0 }
    s.coach[coach] = c
  end
  if ev.win then
    if node_accepts("any", ev.kind) then c.wins = c.wins + 1 end
    if ev.kind == X.KIND_BOSS then
      c.bosses = c.bosses + 1
      c.best_boss_phase = math.max(c.best_boss_phase, ev.phase)
    end
  else
    if ev.result ~= 0 then c.runs = c.runs + 1 end
    if ev.result == 3 then c.runs_won = c.runs_won + 1 end
  end
  return true
end

local function rival_matches(want, rival, row)
  local w = U.trim(want)
  return w ~= "" and (U.eq_ascii(w, row) or U.lower(w) == U.lower(U.trim(rival)))
end

-- apply one run event: ev = { win = true, kind, phase, rival, row, team = { params }, album, guests = {}, era } or
-- { win = false, result, phase, album }. Returns the cards that became unlocked (ids, catalogue order).
function X.apply(s, c, ev, date)
  local st = s.stats
  if ev.win then
    for _, n in ipairs({ ev.rival, ev.row }) do
      n = U.lower(U.trim(n))
      if n ~= "" then s.beaten[n] = true end
    end
    if node_accepts("any", ev.kind) then st.wins = st.wins + 1 end
    st.best_phase = math.max(st.best_phase, ev.phase)
    if ev.kind == X.KIND_BOSS then
      st.bosses = st.bosses + 1
      st.best_boss_phase = math.max(st.best_boss_phase, ev.phase)
      st.best_phase = math.max(st.best_phase, ev.phase + 1)
    end
    st.album = math.max(st.album, ev.album)
    local team = {}
    for _, p in ipairs(ev.team) do team[p] = true end
    local guests = {}
    for _, p in ipairs(ev.guests or {}) do guests[p] = true end
    for _, card in ipairs(c.cards) do
      for i, w in ipairs(card.when) do
        local hit = false
        local ty = w.type
        if ty == "boss_phase" then
          hit = ev.kind == X.KIND_BOSS and ev.phase >= w.phase
        elseif ty == "beat" then
          hit = node_accepts(w.node, ev.kind) and ev.phase >= w.phase and rival_matches(w.rival, ev.rival, ev.row)
        elseif ty == "with_player" then
          if node_accepts(w.node, ev.kind) and ev.phase >= w.phase then
            for _, p in ipairs(w.params) do
              if team[p] then hit = true end
            end
          end
        elseif ty == "rival_with_player" then
          if node_accepts(w.node, ev.kind) and ev.phase >= w.phase and rival_matches(w.rival, ev.rival, ev.row) then
            for _, p in ipairs(w.params) do
              if guests[p] then hit = true end
            end
          end
        elseif ty == "beat_era" then
          hit = node_accepts(w.node, ev.kind) and ev.phase >= w.phase and w.era ~= "" and U.eq_ascii(w.era, ev.era or "")
        end
        if hit then s.latched[latch_key(card.id, i)] = true end
      end
    end
  else
    if ev.result ~= 0 then st.runs = st.runs + 1 end
    if ev.result == 3 then st.runs_won = st.runs_won + 1 end
    st.best_phase = math.max(st.best_phase, ev.phase)
    st.album = math.max(st.album, ev.album)
  end
  -- cards whose conditions all hold now
  local out = {}
  for _, card in ipairs(c.cards) do
    if not X.is_unlocked(s, card.id) and #card.when > 0 then
      local all = true
      for i = 1, #card.when do
        if not X.met(s, card, i) then all = false end
      end
      if all then
        s.unlocked[#s.unlocked + 1] = { id = card.id, param = card.param, date = date, phase = ev.phase }
        out[#out + 1] = card.id
      end
    end
  end
  return out
end

-- unlocked cards not announced yet in INAROGUE / in slot `slot`'s office (marked announced)
function X.take_news_rogue(s, c)
  local out = {}
  for _, k in ipairs(c.cards) do
    if X.is_unlocked(s, k.id) and not s.seen_rogue[k.id] then
      s.seen_rogue[k.id] = true
      out[#out + 1] = k.id
    end
  end
  return out
end

function X.take_news_office(s, c, slot)
  local key = tostring(slot)
  s.seen_office[key] = s.seen_office[key] or {}
  local seen = s.seen_office[key]
  local out = {}
  for _, k in ipairs(c.cards) do
    if X.is_unlocked(s, k.id) and not seen[k.id] then
      seen[k.id] = true
      out[#out + 1] = k.id
    end
  end
  return out
end

return X
