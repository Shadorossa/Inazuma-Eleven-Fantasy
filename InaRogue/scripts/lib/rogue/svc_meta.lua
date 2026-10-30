-- InaRogue › INAROGUE meta progress: unlocks for the office, coaches, Rogue points and avatars, the formation
-- book (was unlocks_rt.rs, coaches_rt.rs, avatars_rt.rs and formations_rt.rs of the DLL's module rogue).
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_EVT_RU_INFO | – | enabled, count, unlockedCount, showLocked, shopCrc, slot, gameCrc, title |
-- | CMND_EVT_RU_CARD | i | ok, param, unlocked, name, hint, price, level, id |
-- | CMND_EVT_RU_STATE | chara_param | true, inCatalogue, unlocked, hint, name |
-- | CMND_EVT_RU_NEWS | 0 INAROGUE / 1 the office of the active slot | n, name x n |
-- | CMND_EVT_RL_COACH_LIST | -1 / i | count, runIndex, pickIndex, enabled / ok, id, name, tagline, face, unlocked, hint, param |
-- | CMND_EVT_RL_COACH_PICK | i | code (0 ok, 4 bad index, 5 locked, 6 off) |
-- | CMND_EVT_RL_COACH_RUN | – | index, id, name, face |
-- | CMND_EVT_RL_COACH_ITEMS | – | n, key, id, count x n |
-- | CMND_EVT_RL_AVATAR_GET | – | texture, prefix, index, unit, name, id |
-- | CMND_EVT_RL_AVATAR_LIST | -1 / i | count, ownedCount, currentIndex, defaultIndex, enabled / ok, id, name, team, texture, prefix, tier, price, owned, current, available, needPhase, unit |
-- | CMND_EVT_RL_AVATAR_TEAM | -1 / t, -1 / t, j | teamCount / ok, teamId, name, tier, captainIndex, memberCount, ownedCount, hasCrest / ok, avatarIndex |
-- | CMND_EVT_RL_AVATAR_UNLOCK / _SELECT | i, paid / i | code |
-- | CMND_EVT_RL_POINTS / _GIVEN | – / n | pending, earned, given, spent, itemKey, itemIdGuess, enabled, rogueActive / code, pendingLeft |
-- | CMND_EVT_RL_FORM_OWNED | formId | locked, owned, rarity, ownedCount, total |
-- | CMND_EVT_RL_FORM_LIST | -1 / i | ownedCount, total, enabled / ok, formId, rarity, owned, name |
--
-- The coach's stat_mult effects act on the match copy of the run's players (content\game\rogue.toml): this script
-- publishes them in the native table InaRogue.CoachMult (coach_sync; the framework's match-build service applies them).

local U = require "lib/rogue/util"
local Core = require "lib/rogue/core"
local X = require "lib/rogue/unlocks"
local Co = require "lib/rogue/coaches"
local E = require "lib/rogue/effects"
local Items = require "lib/rogue/items"
local Av = require "lib/rogue/avatars"
local F = require "lib/rogue/formations"
local album = require "lib/rogue/album"
local chara = require "lib/rogue/chara"
local Blocks = require "lib/rogue/svc_blocks"
local info, warn = U.logger("rogue")

local S = {}

local function cfg() return Core.cfg() end

-- ---------------------------------------------------------------------------------------- unlocks

local function ucat() return X.catalogue(cfg().unlocks) end

local function unlocked(s, id)
  local u = cfg().unlocks
  return u.enabled and (u.unlock_all or X.is_unlocked(s, id))
end

local function album_owned()
  return album.total_owned(album.owned_keys(Core.bank.bank_params()))
end

local function names(ids)
  local o = {}
  for _, id in ipairs(ids) do
    local c = X.card_by_id(ucat(), id)
    if c then o[#o + 1] = c.name end
  end
  return o
end

local function apply(ev, why)
  if not cfg().unlocks.enabled or not U.rogue_active() then return end
  if cfg().debug_all_players then return end -- a run with every player unlocked never counts for the unlocks
  local s = X.store()
  -- seed the lifetime counters from the bank once (a run end already in the bank's counters is not counted twice)
  if not s.seeded then
    local st = Core.bank.bank_run_stats()
    if st and X.seed(s, st[1], st[2], st[3]) and not ev.win then
      if ev.result ~= 0 then s.stats.runs = math.max(s.stats.runs - 1, 0) end
      if ev.result == 3 then s.stats.runs_won = math.max(s.stats.runs_won - 1, 0) end
    end
  end
  X.apply_coach(s, Core.run.run_coach(), ev)
  local new = X.apply(s, ucat(), ev, U.today())
  X.save(why)
  if #new > 0 then info("rogue unlocks: " .. why .. ": UNLOCKED " .. table.concat(names(new), ", ")) end
end

function S.unlocks_on_win(kind, phase, rival, row, uids, guests, era)
  if not cfg().unlocks.enabled or not U.rogue_active() then return end
  local team = {}
  for _, u in ipairs(uids) do
    local p = Core.bank.bank_entry(u)
    if p then team[#team + 1] = p end
  end
  apply({ win = true, kind = kind, phase = phase, rival = rival, row = row, team = team, album = album_owned(), guests = guests,
    era = era }, "node won")
end

function S.unlocks_on_run_end(result, phase)
  if not cfg().unlocks.enabled or not U.rogue_active() then return end
  apply({ win = false, result = result, phase = phase, album = album_owned() }, "run end")
end

function S.beaten_lifetime()
  return U.copy(require("lib/rogue/json").sorted_keys(X.store().beaten))
end

function S.RuInfo()
  local k = ucat()
  local s = X.store()
  local n = 0
  for _, c in ipairs(k.cards) do
    if unlocked(s, c.id) then n = n + 1 end
  end
  return cfg().unlocks.enabled, #k.cards, n, k.office.show_locked, U.crc32(k.office.shop), k.office.slot, U.crc32(k.office.game),
    k.office.title
end

function S.RuCard(i_arg)
  local i = U.int(i_arg, -1)
  local card = i >= 0 and ucat().cards[i + 1] or nil
  if not card then return false end
  local s = X.store()
  return true, card.param, unlocked(s, card.id), card.name, X.hint_with_progress(s, card), card.price, card.level, card.id
end

function S.RuState(p_arg)
  local p = U.u32(p_arg, 0)
  local card = X.card_by_param(ucat(), p)
  if not card then return true, false, true, "", "" end
  local s = X.store()
  return true, true, unlocked(s, card.id), X.hint_with_progress(s, card), card.name
end

function S.RuNews(w_arg)
  local where_ = U.int(w_arg, 0)
  local u = cfg().unlocks
  if not u.enabled or u.unlock_all then return 0 end
  -- the unlocked cards are signed in Inazuma Fantasy's office page «INAROGUE»: no news (kept for later) while that page
  -- is not there (IF absent, or its part inarogue_office not shipped: state key fantasy.office.inarogue_page)
  local okp, page = pcall(VRFW.state.get, "fantasy.office.inarogue_page")
  if not okp or page ~= 1 then return 0 end
  local s = X.store()
  local ids
  if where_ == 0 then
    ids = U.rogue_active() and X.take_news_rogue(s, ucat()) or {}
  else
    ids = U.rogue_active() and {} or X.take_news_office(s, ucat(), U.slot())
  end
  if #ids > 0 then X.save("news") end
  local list = names(ids)
  if #list > 0 then
    info(string.format("rogue unlocks: news (%s) shown: %s", where_ == 0 and "INAROGUE" or "office", table.concat(list, ", ")))
  end
  return #list, table.unpack(list)
end

-- ---------------------------------------------------------------------------------------- coaches

local pick = nil -- the coach picked in the selector for the next run

local function ccat() return Co.catalogue(cfg().coaches) end

local function coaches_on()
  return cfg().coaches.enabled and #ccat().coaches > 0
end

local function coach_unlocked(c)
  return cfg().coaches.unlock_all or #c.unlock == 0 or Co.is_unlocked(c, X.store())
end

function S.coach_default_id()
  if not cfg().coaches.enabled then return "" end
  local d = Co.default_coach(ccat())
  return d and d.id or ""
end

function S.coach_take_pick()
  local p = pick
  pick = nil
  if p and Co.by_id(ccat(), p) then return p end
  return S.coach_default_id()
end

function S.coach_has_start_items(id)
  local c = Co.by_id(ccat(), id)
  return c ~= nil and #Co.start_items(c) > 0
end

function S.coach_content_mults(id)
  local c = Co.by_id(ccat(), id)
  return c and Co.content_mults(c) or nil
end

-- the run coach's multiplier of a reward ("frags" / "points"); 1.0 = none
local function reward_mult(r)
  local m = 1.0
  if cfg().coaches.enabled then
    local c = Co.by_id(ccat(), Core.run.run_coach())
    if c then m = Co.reward_mult(c, r) end
  end
  -- the rogue items of the run in progress (scope outside / both)
  local run = Core.run.run_hdls()
  if run then m = m * E.reward_mult(E.concat(Items.effects(run.items, "outside"), Items.archetype_effects(run.items, "outside")), r) end
  return m
end

function S.coach_scaled(n, r)
  return Co.scaled(n, reward_mult(r))
end

function S.coach_on_run_start(id)
  local c = Co.by_id(ccat(), id)
  if not c then return end
  local pts = Co.start_points(c)
  local got = pts > 0 and S.earn_bonus(pts, "coach " .. id .. " start") or 0
  info(string.format("rogue coaches: run starts with coach %s (%s), start points %d, start items %d", id, c.name, got,
    #Co.start_items(c)))
end

-- ---- the stat multipliers of the run coach on the match copy of the run's own players: the native table
-- InaRogue.CoachMult that content\game\rogue.toml's [[VRFW.MatchStat]] InaRogue.Coach reads (the framework's
-- match-build service): key (handle, stat 0..7) = multiplier of a listed run handle (his position / element applied);
-- key (0, stat) = a player when the run lists no handle (the team-wide effects only). Empty = nothing applies.
local T_COACH = "InaRogue.CoachMult"

-- InaRogue.CoachAdd: the flat additions (stat_bonus) with the same keys, read by the same declaration
local T_COACH_ADD = "InaRogue.CoachAdd"

function S.coach_sync(r)
  local c = r and Co.by_id(ccat(), r.coach) or nil
  -- the coach's effects, the match effects of the run's rogue items and their stat buffs, through one aggregator
  local effects = E.concat(c and c.effects or {}, r and Items.effects(r.items, "match") or {},
    r and Items.archetype_effects(r.items, "match") or {}, r and Blocks.buff_effects(r) or {})
  local entries, adds = {}, {}
  if E.has_stat_mults(effects) then
    local n = 0
    local rc = Blocks.run_ctx(r)
    for k = 0, 19 do
      local h = r.hdls[k + 1] or 0
      if h ~= 0 then
        local uid
        if #r.slots == 0 then uid = r.squad[k + 1] else uid = r.slots[k + 1] end
        local p = Blocks.player_of(k, uid)
        local ctx = Blocks.ctx(rc, p, nil)
        local m = E.stat_mults(effects, p.position, p.element, ctx)
        local a = E.stat_adds(effects, p.position, p.element, ctx)
        for s = 1, 8 do
          entries[#entries + 1] = { { h, s - 1 }, m[s] }
          if a[s] ~= 0 then adds[#adds + 1] = { { h, s - 1 }, a[s] } end
        end
        n = n + 1
      end
    end
    if n == 0 then
      local ctx = Blocks.ctx(rc, nil, nil)
      local any = E.stat_mults(effects, 0, 0, ctx)
      local a = E.stat_adds(effects, 0, 0, ctx)
      for s = 1, 8 do
        entries[#entries + 1] = { { 0, s - 1 }, any[s] }
        if a[s] ~= 0 then adds[#adds + 1] = { { 0, s - 1 }, a[s] } end
      end
    end
  end
  local ok, e = pcall(VRFW.native.table_replace, T_COACH, nil, entries)
  if not ok then VRFW.warn("rogue coaches: " .. tostring(e)) end
  local ok2, e2 = pcall(VRFW.native.table_replace, T_COACH_ADD, nil, adds)
  if not ok2 then VRFW.warn("rogue coaches: " .. tostring(e2)) end
end

function S.CoachList(i_arg)
  local k = ccat()
  local i = U.int(i_arg, -1)
  if i < 0 then
    local run_id = Core.run.current_coach()
    local run_idx = run_id and Co.index_of(k, run_id) or nil
    local pick_idx = (pick and Co.index_of(k, pick)) or (run_id and Co.index_of(k, run_id))
    if pick_idx == nil then
      local d = Co.default_coach(k)
      pick_idx = d and Co.index_of(k, d.id) or 0
    end
    return #k.coaches, run_idx or -1, pick_idx or 0, coaches_on()
  end
  local c = k.coaches[i + 1]
  if not c then return false end
  local open = coach_unlocked(c)
  local hint = open and "" or Co.hint(k, c, X.store())
  return true, c.id, c.name, c.tagline, c.face, open, hint, c.param
end

function S.CoachPick(i_arg)
  local i = U.int(i_arg, -1)
  if not coaches_on() then return 6 end
  local c = i >= 0 and ccat().coaches[i + 1] or nil
  if not c then return 4 end
  if not coach_unlocked(c) then return 5 end
  pick = c.id
  info("rogue coaches: " .. c.id .. " picked for the next run")
  return 0
end

function S.CoachRun()
  local k = ccat()
  local id = Core.run.current_coach()
  local c = id and Co.of_run(k, id) or nil
  if not c then return -1, "", "", "" end
  return Co.index_of(k, c.id) or -1, c.id, c.name, c.face
end

function S.CoachItems()
  local id = Core.run.take_coach_items()
  local c = id and Co.by_id(ccat(), id) or nil
  local items = c and Co.start_items(c) or {}
  if #items > 0 then info(string.format("rogue coaches: %d start item(s) handed to the Lua", #items)) end
  local out = { #items }
  for _, it in ipairs(items) do
    out[#out + 1] = it[1]
    out[#out + 1] = it[2]
    out[#out + 1] = it[3]
  end
  return table.unpack(out, 1, #out)
end

-- ---------------------------------------------------------------------------------------- points and avatars

local function acat() return Av.catalogue(cfg().avatars) end
local function prof() return Av.with_profile(U.slot()) end

local function earn(n, why)
  if n == 0 then return 0 end
  local p = prof()
  Av.earn(p, n)
  if Av.commit(p, string.format("+%d points (%s), pending %d", n, why, p.points.pending)) then return n end
  p.points.pending = p.points.pending - n
  p.points.earned = p.points.earned - n
  return 0
end

function S.earn_bonus(n, why) return earn(n, why) end

function S.earn_win(kind, phase)
  local pc = cfg().points
  return earn(Co.scaled(Av.for_win(pc, kind, phase), reward_mult("points")), string.format("node kind %d won, phase %d", kind, phase))
end

function S.earn_run_end(result, phase)
  local pc = cfg().points
  return earn(Co.scaled(Av.for_run_end(pc, result, phase), reward_mult("points")), string.format("run end %d, phase %d", result, phase))
end

local function best_phase() return Core.bank.best_phase() or 0 end

function S.AvatarGet()
  local k = acat()
  local i = cfg().avatars.enabled and Av.current(k, prof()) or k.default
  local a = k.list[i + 1]
  return a.texture, a.prefix, i, a.unit, a.name, a.id
end

function S.AvatarList(i_arg)
  local k = acat()
  local ac = cfg().avatars
  local i = U.int(i_arg, -1)
  local p = prof()
  if i < 0 then
    local owned = ac.unlock_all and #k.list or Av.owned_count(k, p)
    return #k.list, owned, Av.current(k, p), k.default, ac.enabled
  end
  local a = k.list[i + 1]
  if not a then return false end
  return true, a.id, a.name, a.team, a.texture, a.prefix, a.tier, a.price, ac.unlock_all or Av.is_owned(k, p, a.id),
    Av.current(k, p) == i, best_phase() >= a.best_phase, a.best_phase, a.unit
end

function S.AvatarTeam(t_arg, j_arg)
  local k = acat()
  local t = U.int(t_arg, -1)
  if t < 0 then return #k.teams end
  local team = k.teams[t + 1]
  if not team then return false end
  local j = U.int(j_arg, -1)
  if j < 0 then
    local owned = cfg().avatars.unlock_all and #team.members or Av.team_owned(k, prof(), team)
    return true, team.id, team.name, team.tier, team.captain, #team.members, owned, team.crest
  end
  local m = team.members[j + 1]
  if m == nil then return false end
  return true, m
end

function S.AvatarUnlock(i_arg, paid_arg)
  local k = acat()
  local ac = cfg().avatars
  local i = U.int(i_arg, -1)
  local paid = U.u32(paid_arg, 0)
  local code
  if not ac.enabled then
    code = Av.CODE.OFF
  else
    local a = i >= 0 and k.list[i + 1] or nil
    if not a then
      code = Av.CODE.BAD_INDEX
    elseif best_phase() < a.best_phase and not ac.unlock_all then
      code = Av.CODE.LOCKED
    else
      local p = prof()
      if not Av.unlock(k, p, a.id, paid, U.today()) then
        code = Av.CODE.ALREADY
      elseif Av.commit(p, string.format("%s unlocked for %d points", a.id, paid)) then
        code = Av.CODE.OK
      else
        Av.undo_unlock(p, a.id)
        code = Av.CODE.WRITE_FAILED
      end
    end
  end
  info(string.format("rogue avatars: unlock %d (paid %d) -> code %d", i, paid, code))
  return code
end

function S.AvatarSelect(i_arg)
  local k = acat()
  local ac = cfg().avatars
  local i = U.int(i_arg, -1)
  local a = i >= 0 and k.list[i + 1] or nil
  local code
  if not a then
    code = Av.CODE.BAD_INDEX
  else
    local p = prof()
    if ac.unlock_all and not Av.is_owned(k, p, a.id) then
      code = Av.CODE.NOT_OWNED -- debug: owned for the screen, nothing written
    else
      local before = p.selected
      if not Av.select(k, p, a.id) then
        code = Av.CODE.NOT_OWNED
      elseif Av.commit(p, a.id .. " chosen") then
        code = Av.CODE.OK
      else
        p.selected = before
        code = Av.CODE.WRITE_FAILED
      end
    end
  end
  info(string.format("rogue avatars: select %d -> code %d", i, code))
  return code
end

function S.Points()
  local pc = cfg().points
  local l = prof().points
  return l.pending, l.earned, l.given, l.spent, pc.item, U.crc32(pc.item), pc.enabled, U.rogue_active()
end

function S.PointsGiven(n_arg)
  local n = U.u32(n_arg, 0)
  local p = prof()
  local before = U.copy(p.points)
  local left = Av.given(p, n)
  if Av.commit(p, string.format("%d points handed to the bag, %d pending", n, left)) then return Av.CODE.OK, left end
  p.points = before
  return Av.CODE.WRITE_FAILED, before.pending
end

-- ---------------------------------------------------------------------------------------- formations

local function fcfg() return cfg().formations end

function S.formation_grant(seed, phase, node, kind)
  return F.grant_for_node(fcfg(), U.slot(), seed, phase, node, kind)
end

function S.FormOwned(id_arg)
  local id = U.u32(id_arg, 0)
  local fc = fcfg()
  local b = F.with_book(fc, U.slot())
  local owned = F.is_owned(b, id)
  local l = F.loot(id)
  local locked = fc.enabled and not fc.unlock_all and U.rogue_active() and not owned
  return locked, owned or fc.unlock_all or not fc.enabled, l and l.rarity or 0, F.owned_count(b), F.total()
end

function S.FormList(i_arg)
  local i = U.int(i_arg, -1)
  local fc = fcfg()
  if i < 0 then
    return F.owned_count(F.with_book(fc, U.slot())), F.total(), fc.enabled
  end
  local l = F.data().loot[i + 1]
  if not l then return false end
  return true, l.id, l.rarity, F.is_owned(F.with_book(fc, U.slot()), l.id), l.name
end

Core.on_forget(function(slot)
  F.forget()
  Av.forget()
end)

return S
