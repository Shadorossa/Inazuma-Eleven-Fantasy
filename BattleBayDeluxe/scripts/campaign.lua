-- Battle Bay Campaign: the 7 rivals drawn from the WHOLE enjoy_mode_team_config table instead of the 28 slots of the
-- page the grid shows (docs/game/modes/estadio-bb.md §6 A+, §10). The player still picks his team in the grid. Since
-- 1.3.0 it replaces bb_chronicle_teams.dll's campaign.rs / campaign_rt.rs with the same behaviour. Declarations:
-- content\game\campaign.toml (the vtable hook `Decide`, slot 43 of EnjoySelectTeamMenu, chained on top of the
-- VR-Framework's BB pages service). This is the mod's only entry script (scripts.toml): the Draft (draft.lua) runs in
-- this VM, so the hook and the Draft share their state.
--
-- With the button 0x140980D9 the retail Decide builds the pool from the unlocked grid slots minus the player's team,
-- shuffles it, resizes it to 7 (zero padded), writes Session +0x2CA6F0[7] AND starts match 1 at once with rival [0];
-- a pure post-hook would come too late for match 1, so:
-- * pre (button + campaign menu only): draw the 7 rivals from every enjoy row that is unlocked (grid slots: their
--   unlocked byte; other rows: their own condition, evaluated with the game's EvalCondition) and is not the player's
--   team, then make the grid pool hold ONLY rival 1 (one slot that is not the player's carries it, every other slot
--   is marked locked): the game "draws" exactly that team, writes [rival1, 0 x 6] and starts match 1 against it;
-- * post: every slot back (team + unlocked byte); when the session block holds player, rival 1, 0 x 6 (the campaign
--   really started) rivals 2-7 are written. Every later match reads Session[match index] and finds its row by hash.
-- Order: with [campaign] progression = true and a rating table (data/common/gamedata/team/evt_bb_team_rating.cfg.bin,
-- any mod may ship it) the candidates are sorted by rating (unknown = the median) and split into 7 bands, one rival
-- per band (match 1 one of the weakest seventh, match 7 one of the strongest); else a plain shuffle. Fewer than 7
-- candidates: each once, the ladder completed by repeating them (never a 0 rival). No candidate: the retail draw. The
-- Draft team is never a rival, and a decide on its tile outside the Campaña is refused. 1.5.61: the «Active team» tile
-- (active_team.lua) is never a rival either, and only the player's side may pick it. The VR-Framework's «win it
-- to unlock it» rule (docs/framework/bb-pages.md §8) only stops the PLAYER from picking a team: its teams stay CPU
-- rivals.

local U = require "lib/util"
local G = require "lib/game"
local Draft = require "draft"
local Tourn = require "tournament"
local Active = require "active_team"
-- a tournament started with the Draft team keeps the drafted squad (as a Campaña started with it)
Tourn.on_started = function(run)
  if run.player_team == Draft.team() then
    Draft.campaign_started()
  end
end
-- 1.5.42: a running Torneo with the Draft team owns the drafted squad (the top-menu sync keeps it, a restart brings it
-- back) and every one of its matches checks it on the rows first (draft.lua, «runs that play the Draft»)
Draft.tournament_team = Tourn.player_team
Tourn.before_match = function(run)
  local team = Draft.team()
  if team ~= 0 and run.player_team == team then
    Draft.before_run_match("Torneo match")
  end
end

local floor = math.floor

local RATING_KEY = "data/common/gamedata/team/evt_bb_team_rating.cfg.bin"
local RATING_VERSION = 1

local CFG = {
  progression = U.config("campaign.progression", true) ~= false,
  seed = tonumber(U.config("campaign.seed", 0)) or 0,
}

local function info(...)
  VRFW.log("campaign:", ...)
end
local function warn(...)
  VRFW.warn("campaign:", ...)
end
local function err(...)
  VRFW.error("campaign:", ...)
end

info(string.format("rivals from the whole enjoy table (progression %s, seed %s)", tostring(CFG.progression),
  tostring(CFG.seed)))
if not VRFW.is_on("EvalCondition") then
  warn("unlock-condition evaluator not resolved: conditioned rows off the grid are never campaign rivals")
end

-- ------------------------------------------------------------------------------------------------ ratings

local RATINGS = nil

-- team -> rating from the rating table (EVT_BB_RATING_HEADER version, EVT_BB_RATING(team, rating, row)), read once
local function ratings()
  if RATINGS then
    return RATINGS
  end
  RATINGS = {}
  local okk, keys = pcall(VRFW.table.keys, RATING_KEY)
  if not okk or type(keys) ~= "table" or #keys == 0 then
    info("no rating table (" .. RATING_KEY .. " in no mod): rivals drawn without progression")
    return RATINGS
  end
  local ok, res = pcall(function()
    local head = VRFW.table.raw(RATING_KEY, "EVT_BB_RATING_HEADER")
    if #head == 0 then
      error("no EVT_BB_RATING_HEADER row", 0)
    end
    for _, h in ipairs(head) do
      local ver = type(h[1]) == "number" and h[1] or 0
      if ver < 1 or ver > RATING_VERSION then
        error(string.format("file version %d (this mod reads 1..%d)", ver, RATING_VERSION), 0)
      end
    end
    local out, n = {}, 0
    for _, r in ipairs(VRFW.table.raw(RATING_KEY, "EVT_BB_RATING")) do
      local team = type(r[1]) == "number" and U.u32(r[1]) or 0
      local v = type(r[2]) == "number" and floor(r[2]) or 0
      if team ~= 0 and v > 0 then
        if out[team] == nil then
          n = n + 1
        end
        out[team] = v
      end
    end
    return { map = out, n = n }
  end)
  if ok then
    RATINGS = res.map
    info(res.n .. " team ratings from " .. RATING_KEY)
  else
    warn(RATING_KEY .. " unreadable (" .. tostring(res) .. "): rivals drawn without progression")
  end
  return RATINGS
end

-- ------------------------------------------------------------------------------------------------ the draw

-- the candidates: every row (table order) whose team is not the player's, not 0, not repeated, and unlocked: a row
-- whose team sits in a grid slot takes that slot's unlocked flag, any other row its own state (free / cond_true)
local function candidates(rows, grid, player)
  local on_grid = {}
  for _, g in ipairs(grid) do
    if on_grid[g.team] == nil then
      on_grid[g.team] = g.unlocked
    end
  end
  local out, locked, seen = {}, 0, {}
  for _, r in ipairs(rows) do
    if r.team ~= 0 and r.team ~= player and not seen[r.team] then
      seen[r.team] = true
      local unlocked = on_grid[r.team]
      if unlocked == nil then
        unlocked = r.lock == "free" or r.lock == "cond_true"
      end
      if unlocked then
        out[#out + 1] = r.team
      else
        locked = locked + 1
      end
    end
  end
  return out, locked
end

-- the n rivals of one campaign, in match order: with progression and at least one known rating the candidates
-- sorted by rating (unknown = the median of the known ones, ties in random order), split into n equal bands, one
-- random pick per band; otherwise a shuffle, the first n. Fewer than n candidates: each once, the ladder completed by
-- repeating them (in rating order with progression).
local function draw(cands, n, progression, rng)
  local m = #cands
  if m == 0 or n == 0 then
    return {}
  end
  local v = {}
  for i, c in ipairs(cands) do
    v[i] = c
  end
  rng:shuffle(v)
  local known = {}
  for _, c in ipairs(v) do
    if c.rating then
      known[#known + 1] = c.rating
    end
  end
  local out = {}
  if progression and #known > 0 then
    table.sort(known)
    local med = known[floor(#known / 2) + 1]
    -- stable after the shuffle: equal ratings stay in random order
    U.stable_sort(v, function(c)
      return c.rating or med
    end)
    if m >= n then
      for k = 0, n - 1 do
        local lo, hi = floor(k * m / n), floor((k + 1) * m / n)
        out[#out + 1] = v[lo + rng:below(hi - lo) + 1].team
      end
    else
      for k = 0, n - 1 do
        out[#out + 1] = v[floor(k * m / n) + 1].team
      end
    end
    return out
  end
  for k = 0, n - 1 do
    out[#out + 1] = v[k % m + 1].team
  end
  return out
end

-- ------------------------------------------------------------------------------------------------ the Decide hook

local CAMPAIGNS = 0
local PREP = nil -- what the pre-phase changed, for the post-phase of the same decide

local function slot_struct(menu, i)
  return U.struct("GridSlot", G.slot_addr(menu, i))
end

-- The Draft outside the Campaña (1.5.42, owner: «el Draft no funciona en el 1 vs 1»). Where the Draft may be played is
-- data: config.toml [draft] modes ("campaign" always; "free_match" = the 1 vs 1 grid, enjoy_team_select_menu_offline,
-- whose screen is the graft bb_draft's same block). In the free match the retail Decide of a grid tile only records
-- the 1P / CPU slot and never calls the menu's Lua (GameDecide returns before the base Decide), so the Draft screen
-- could not open there. A decide on the Draft tile:
--   * a network session (online Battle Bay): refused (the peer has no drafted squad);
--   * a complete draft on the rows (or a run's drafted squad): the retail decide (1P / CPU = the Draft team);
--   * else: for this one call the menu is flagged as the Campaña's (GridMenu.campaign), so the retail Decide goes on to
--     the base Decide, which calls the Lua OnDecideFocus(grid, slot): the graft opens the Draft screen as in the
--     Campaña (no 1P / CPU recorded). The flag is put back in the post-phase (or by the next decide when that never ran).
--     When the 16 are drafted the graft asks CMND_BBD_DRAFT_DECIDE: the retail decide of the tile, called directly
--     (not through this hook), records the Draft team as 1P / CPU.
local DRAFT_MODES = {}
do
  local m = U.config("draft.modes", { "campaign", "free_match" })
  if type(m) ~= "table" then
    m = { m }
  end
  for _, v in ipairs(m) do
    DRAFT_MODES[U.trim(tostring(v))] = true
  end
end
local FREE = nil       -- the free-match menu whose campaign flag this decide raised ({ menu, was })
local FREE_MENU = nil  -- { menu, slot }: the free-match grid whose Draft screen is open (CMND_BBD_DRAFT_DECIDE)

local function network_session()
  if not VRFW.is_on("Net.IsSession") then
    return nil
  end
  local ok, v = U.call("Net.IsSession")
  if not ok then
    return nil
  end
  return U.truthy(v)
end

-- the Draft tile decided outside the Campaña: nil (not the Draft tile / the Campaña), "refuse", "pass" or "open"
local function draft_gate(menu, btn, idx)
  local team = Draft.team()
  if team == 0 or idx >= G.SLOTS or U.rd("u32", btn) ~= G.GRID_LAYER then
    return nil
  end
  if U.get(U.struct("GridMenu", menu), "campaign") ~= 0 or U.get(slot_struct(menu, idx), "team") ~= team then
    return nil
  end
  local why = nil
  if not DRAFT_MODES.free_match then
    why = "config.toml [draft] modes has no \"free_match\""
  else
    local net = network_session()
    if net == nil then
      why = "the network check (IsNetworkSession) is off"
    elseif net then
      why = "network session"
    end
  end
  if why then
    VRFW.log("draft: the Draft tile (slot " .. idx .. ") outside the Campaña refused (" .. why .. ")")
    return "refuse"
  end
  if Draft.ready_to_play() then
    VRFW.log("draft: free match: the Draft tile (slot " .. idx .. ") decided with the drafted squad")
    return "pass"
  end
  return "open"
end

-- 1.5.61: a decide on the Active team tile (active_team.lua): nil = not that tile or allowed, "refuse" = refused
local function active_gate(menu, btn, idx)
  local team = Active.team()
  if team == 0 or idx >= G.SLOTS or U.rd("u32", btn) ~= G.GRID_LAYER then
    return nil
  end
  if U.get(slot_struct(menu, idx), "team") ~= team then
    return nil
  end
  local m = U.struct("GridMenu", menu)
  local campaign = (U.get(m, "campaign") or 0) ~= 0
  local player_one_decided = (U.get(m, "player_one_decided") or 0) ~= 0
  local why = Active.refusal(campaign, player_one_decided, network_session())
  if why then
    VRFW.log("active team: the Active team tile (slot " .. idx .. ") refused (" .. why .. ")")
    return "refuse"
  end
  return nil
end

local function free_back(why)
  local f = FREE
  FREE = nil
  if f then
    local ok = pcall(function()
      U.struct("GridMenu", f.menu).campaign = f.was
    end)
    if not ok then
      warn("free match: the grid's campaign flag NOT put back (" .. why .. ")")
    end
  end
end

-- CMND_BBD_DRAFT_DECIDE slot: the graft's free-match Draft screen is done (16 drafted): the retail decide of the
-- tile records the Draft team as 1P / CPU. -> ok
function BattleBayDeluxe.DraftDecide(slot)
  slot = U.int(slot, -1)
  local f = FREE_MENU
  FREE_MENU = nil
  if not f or (slot >= 0 and slot ~= f.slot) then
    warn("free match: no Draft screen to decide (slot " .. tostring(slot) .. ")")
    return false
  end
  local menu = f.menu
  local team = Draft.team()
  if team == 0 or not Draft.ready_to_play() then
    warn("free match: the draft is not complete: nothing decided")
    return false
  end
  local m = U.struct("GridMenu", menu)
  if not m or U.get(m, "campaign") ~= 0 or U.get(slot_struct(menu, f.slot), "team") ~= team then
    warn("free match: the grid changed (slot " .. f.slot .. " no longer the Draft tile): nothing decided")
    return false
  end
  local okb, lb = pcall(VRFW.mem.buffer, "bbd_layer_decide", 4)
  if not okb or not U.wr("u32", lb, G.GRID_LAYER) then
    return false
  end
  local ok, e = U.call("GameDecide", menu, lb, f.slot)
  if not ok then
    warn("free match: the retail decide failed: " .. tostring(e))
    return false
  end
  VRFW.log("draft: free match: the drafted Draft team decided (slot " .. f.slot .. ")")
  return true
end

local function restore_grid(p)
  for i, g in ipairs(p.grid) do
    local s = slot_struct(p.menu, i - 1)
    if s then
      pcall(function()
        s.team = g.team
        s.unlocked = g.raw
      end)
    end
  end
end

local function prepare(menu, btn)
  if U.rd("u32", btn) ~= G.BTN_CAMPAIGN_START then
    return nil
  end
  local m = U.struct("GridMenu", menu)
  local camp = U.get(m, "campaign")
  if not camp or camp == 0 then
    return nil
  end
  -- from here on a nil is the game's own draw (only the visible page's slots): every such case says why
  local okb, lb = pcall(VRFW.mem.buffer, "bbd_layer", 4)
  if not okb or not U.wr("u32", lb, G.GRID_LAYER) then
    warn("layer buffer not writable: game campaign draw (visible page only)")
    return nil
  end
  local okc, child = U.call("FindChildByHash", menu, lb, 0)
  if not okc then
    warn("grid layer not found: game campaign draw (visible page only)")
    return nil
  end
  local cursor = U.get(U.struct("GridChild", child), "cursor")
  if not cursor then
    warn("cursor slot not readable: game campaign draw (visible page only)")
    return nil
  end
  if cursor < 0 or cursor >= G.SLOTS then
    warn("cursor slot " .. cursor .. " out of range: game campaign draw")
    return nil
  end
  local grid = {}
  for i = 0, G.SLOTS - 1 do
    local s = slot_struct(menu, i)
    local team, un = U.get(s, "team"), U.get(s, "unlocked")
    if team == nil or un == nil then
      warn("grid slot " .. i .. " not readable (slot base " .. tostring(G.slot_base()) .. "): game campaign draw "
        .. "(visible page only)")
      return nil
    end
    grid[i + 1] = { team = team, raw = un }
  end
  local player = grid[cursor + 1].team
  if player == 0 then
    warn("cursor slot " .. cursor .. " holds no team: game campaign draw (visible page only)")
    return nil
  end
  -- what the game's own draw would take: the visible page's unlocked slots minus the player's team
  local page_pool = 0
  for _, x in ipairs(grid) do
    if x.team ~= 0 and x.team ~= player and x.raw ~= 0 then
      page_pool = page_pool + 1
    end
  end
  local raw = G.enjoy_rows()
  if not raw then
    warn("enjoy table not readable: game campaign draw")
    return nil
  end
  -- the Active team tile is never a rival (its players are placeholders: only the player's side plays the active team)
  local active_team = Active.team()
  if active_team ~= 0 then
    local keep = {}
    for _, r in ipairs(raw) do
      if r.team ~= active_team then
        keep[#keep + 1] = r
      end
    end
    raw = keep
    if player == active_team then
      info("the campaign plays the player's active team (the Active team tile)")
    end
  end
  -- the Draft team is never a rival; as the player's team it needs a complete draft
  local draft_team = Draft.team()
  if draft_team ~= 0 then
    local keep = {}
    for _, r in ipairs(raw) do
      if r.team ~= draft_team then
        keep[#keep + 1] = r
      end
    end
    raw = keep
    if player == draft_team then
      if not Draft.ready_to_play() then
        VRFW.warn("draft: campaign started with the Draft team but no complete draft: it plays the placeholders")
      end
      -- the campaign scene looks the enjoy row's leader up among the team's member rows: it must be a member
      Draft.before_campaign()
    end
  end
  -- the «win it to unlock it» rule only stops the PLAYER from picking a team: its rows (a Chronicle-clear condition
  -- the framework wrote) stay CPU rivals and do not count as conditioned rows in the layout check below
  local rule, nrule = {}, 0
  local function rule_check(t)
    if t ~= 0 and rule[t] == nil then
      local r = G.unlock_rule(t)
      rule[t] = r ~= nil and r >= 0
      if rule[t] then
        nrule = nrule + 1
      end
    end
  end
  for _, r in ipairs(raw) do
    rule_check(r.team)
  end
  for _, g in ipairs(grid) do
    rule_check(g.team)
  end
  -- sanity of the "+0x10 = unlock condition, null = none" layout: only a handful of rows have one (8 in the game's
  -- table). If most rows read as conditioned the layout guess is wrong: then every row off the grid counts as
  -- unlocked (and nothing is handed to the evaluator)
  local free_rows = 0
  for _, r in ipairs(raw) do
    if r.cond == 0 or rule[r.team] then
      free_rows = free_rows + 1
    end
  end
  local layout_ok = free_rows > 0 and (#raw - free_rows) * 2 <= #raw
  if not layout_ok then
    warn(string.format("%d of %d rows without unlock condition (layout?): rows outside the grid taken as unlocked",
      free_rows, #raw))
  end
  local eval_on = VRFW.is_on("EvalCondition")
  local rows, cond_open, cond_shut = {}, 0, 0
  for _, r in ipairs(raw) do
    local lock
    if r.cond == 0 or not layout_ok or rule[r.team] then
      lock = "free"
    elseif not eval_on then
      lock = "unknown"
    else
      local v = G.eval(r.cond)
      if v == nil then
        lock = "unknown"
      elseif v then
        lock = "cond_true"
      else
        lock = "cond_false"
      end
    end
    if lock == "cond_true" then
      cond_open = cond_open + 1
    elseif lock == "cond_false" or lock == "unknown" then
      cond_shut = cond_shut + 1
    end
    rows[#rows + 1] = { team = r.team, lock = lock }
  end
  local g = {}
  for i, x in ipairs(grid) do
    g[i] = { team = x.team, unlocked = x.raw ~= 0 or rule[x.team] == true }
  end
  local pool, locked = candidates(rows, g, player)
  -- the player's team in another version (another row with the same team name text) is never a rival either
  local player_name = Tourn.name_text(player)
  local variants = 0
  if player_name ~= 0 then
    local keep = {}
    for _, t in ipairs(pool) do
      if Tourn.name_text(t) == player_name then
        variants = variants + 1
      else
        keep[#keep + 1] = t
      end
    end
    pool = keep
  end
  Tourn.note_pool(#pool) -- 1.5.15: the Torneo's options offer only the team counts this pool fills
  if #pool == 0 then
    warn("no unlocked team besides the player's in " .. #rows .. " rows: game campaign draw")
    return nil
  end
  local n = CAMPAIGNS
  CAMPAIGNS = CAMPAIGNS + 1
  local h, l
  if CFG.seed ~= 0 then
    h, l = U.split64(CFG.seed)
    l = bit32.bxor(l, player)
  else
    h, l = U.entropy(menu, n)
    l = bit32.bxor(l, player)
  end
  local rt = ratings()
  local cands = {}
  for i, t in ipairs(pool) do
    cands[i] = { team = t, rating = rt[t] }
  end
  if Tourn.armed() then
    -- «Torneo» (tournament.lua, 1.5.4): the bracket is drawn from the same candidates and the game's own start is
    -- refused (the grid unchanged); the grid's Lua sends the difficulty, the tournament writes the campaign block and
    -- shows the bracket first; match 1 is the top menu's «next match» (the game's campaign «continue»)
    local trun, why = Tourn.begin(pool, player, rt, h, l)
    if not trun then
      warn("tournament not started (" .. tostring(why) .. "): the start refused")
      Tourn.fail(why)
    else
      Tourn.pend(trun)
    end
    return { tournament_pending = true, menu = menu }
  end
  local rivals = draw(cands, G.RIVALS, CFG.progression, U.rng(h, l))
  if #rivals ~= G.RIVALS then
    return nil
  end
  if #pool < G.RIVALS then
    warn("only " .. #pool .. " candidate(s): the 7 matches repeat rivals")
  end
  -- the grid pool = rival 1 only: one slot that is not the player's carries it, every other slot is locked
  local p = { menu = menu, grid = grid, rivals = rivals, player = player, seed = U.hex(h) .. ":" .. U.hex(l),
    pool = #pool }
  local carrier = cursor == 0 and 1 or 0
  for i = 0, G.SLOTS - 1 do
    if i ~= cursor then
      local s = slot_struct(menu, i)
      if s then
        pcall(function()
          if i == carrier then
            s.team = rivals[1]
            s.unlocked = 1
          else
            s.unlocked = 0
          end
        end)
      end
    end
  end
  info(string.format("start, player %s (slot %d), pool %d teams from every page (%d enjoy rows; the visible page alone "
    .. "gives %d; %d version(s) of the player's team left out; %d locked; rows without condition %d (%d of the unlock "
    .. "rule: CPU rivals), conditioned unlocked %d / locked %d), seed %s", U.hex(player), cursor, #pool, #rows,
    page_pool, variants, locked, free_rows, nrule, cond_open, cond_shut, p.seed))
  return p
end

-- ---- the campaign load check (estadio-bb.md §14.15): match 1's two teams as the game reads them

-- one team of match 1: a summary; nil, the step that fails
local function check_team(team)
  if team == 0 then
    return nil, "team hash 0 (empty pool slot)"
  end
  local rows, why = G.enjoy_rows()
  if not rows then
    return nil, why
  end
  local idx, row
  for i, r in ipairs(rows) do
    if r.team == team then
      idx, row = i - 1, r.addr
      break
    end
  end
  if not row then
    return nil, "enjoy row: none of the " .. #rows .. " enjoy_mode_team_config rows names it"
  end
  local er = U.struct("EnjoyRow", row)
  local leader = U.get(er, "leader") or 0
  local stadium = U.get(er, "stadium") or 0
  local bgm = U.get(er, "bgm") or 0
  local members, merr = Draft.roster(team)
  if not members then
    return nil, "team_config record: " .. tostring(merr)
  end
  local players, member = 0, false
  for _, m in ipairs(members) do
    if m[1] < 19 then
      players = players + 1
    end
    if m[2] == leader then
      member = true
    end
  end
  if players < 11 then
    return nil, string.format("team_config record: %d players (slots 0-18) of %d rows, 11 needed", players, #members)
  end
  if leader == 0 or not member then
    return nil, string.format("enjoy row %d: leader %s is not one of its %d member rows", idx, U.hex(leader), #members)
  end
  if stadium == 0 then
    return nil, string.format("enjoy row %d: no stadium (col 4)", idx)
  end
  return string.format("row %d, %d members, leader %s member, stadium %s, bgm %s", idx, #members, U.hex(leader),
    U.hex(stadium), U.hex(bgm))
end

local function check_match(sess, player, rival)
  local s = U.struct("Session", sess)
  local game = U.get(s, "game") or 0
  local diff = U.get(s, "difficulty") or 0
  local idx = U.get(s, "match") or 0xFF
  local bad, parts = {}, {}
  for _, e in ipairs({ { "player", player }, { "rival 1", rival } }) do
    local d, why = check_team(e[2])
    if d then
      parts[#parts + 1] = e[1] .. " " .. U.hex(e[2]) .. " [" .. d .. "]"
    else
      err(string.format("match %d check FAILED: %s team %s: %s", idx + 1, e[1], U.hex(e[2]), tostring(why)))
      bad[#bad + 1] = e[1]
      parts[#parts + 1] = e[1] .. " " .. U.hex(e[2]) .. " [FAILED]"
    end
  end
  info(string.format("match %d request: game %s, difficulty %d, map = rival stadium; %s%s", idx + 1, U.hex(game), diff,
    table.concat(parts, " vs "), #bad == 0 and "" or " (" .. table.concat(bad, " + ") .. " failed: the load may never finish)"))
end

local function finish(p)
  restore_grid(p)
  local sess = U.global("session")
  if not sess then
    warn("session block not readable: rivals 2-7 left as the game wrote them")
    return
  end
  local got = {}
  for k = 0, G.RIVALS - 1 do
    local v = U.rd("u32", sess + G.S_RIVALS + 4 * k)
    if v == nil then
      return
    end
    got[k + 1] = v
  end
  local player = U.get(U.struct("Session", sess), "player")
  if player == nil then
    return
  end
  local zero = true
  for k = 2, G.RIVALS do
    if got[k] ~= 0 then
      zero = false
    end
  end
  if player ~= p.player or got[1] ~= p.rivals[1] or not zero then
    local shown = {}
    for k, v in ipairs(got) do
      shown[k] = string.format("%08X", v)
    end
    info(string.format("not started by this decide (block player %s, rivals [%s]): nothing written", U.hex(player),
      table.concat(shown, ", ")))
    return
  end
  for k = 2, G.RIVALS do
    U.wr("u32", sess + G.S_RIVALS + 4 * (k - 1), p.rivals[k])
  end
  if p.player == Draft.team() then
    Draft.campaign_started()
    VRFW.log(string.format("draft: match 1 requested (player %s vs %s): the campaign scene loads next", U.hex(p.player),
      U.hex(p.rivals[1])))
  end
  local rt = ratings()
  local desc = {}
  for k, t in ipairs(p.rivals) do
    desc[k] = rt[t] and (U.hex(t) .. " (Nv." .. rt[t] .. ")") or U.hex(t)
  end
  info(string.format("rivals (seed %s, %d candidates): %s", p.seed, p.pool, table.concat(desc, ", ")))
  check_match(sess, p.player, p.rivals[1])
end

-- the Campaña / Torneo grid of the last team decide (the start without the difficulty window decides on it)
local CAMPAIGN_GRID = nil

-- the pre-phase of a decide (the Decide hook, and the start without the difficulty window): nil = the game's Decide
-- runs, { skip = true, ret = 0 } = it does not
local function decide_pre(menu, btn, idx)
  pcall(function()
    if U.rd("u32", btn) == G.GRID_LAYER and (U.get(U.struct("GridMenu", menu), "campaign") or 0) ~= 0 then
      CAMPAIGN_GRID = menu
    end
  end)
  if PREP then
    -- a post-phase that never ran (the scripts were busy on another thread then): the grid back first
    if PREP.menu == menu then
      restore_grid(PREP)
    end
    PREP = nil
  end
  if FREE then
    free_back("a post-phase that never ran")
  end
  local oka, active = pcall(active_gate, menu, btn, idx)
  if not oka then
    warn("Active team tile check failed: " .. tostring(active))
  elseif active == "refuse" then
    return { skip = true, ret = 0 }
  end
  local ok, gate = pcall(draft_gate, menu, btn, idx)
  if not ok then
    warn("Draft tile check failed: " .. tostring(gate))
  elseif gate == "refuse" then
    return { skip = true, ret = 0 }
  elseif gate == "open" then
    local m = U.struct("GridMenu", menu)
    local was = U.get(m, "campaign")
    if was ~= nil and pcall(function()
      m.campaign = 1
    end) then
      FREE = { menu = menu, was = was }
      FREE_MENU = { menu = menu, slot = idx }
      VRFW.log("draft: free match: the Draft tile (slot " .. idx .. ") opens the Draft screen")
    else
      warn("free match: the grid's campaign flag not writable: the Draft tile refused")
      return { skip = true, ret = 0 }
    end
    return nil
  end
  local okp, p = pcall(prepare, menu, btn)
  if not okp then
    warn("pre-phase failed (" .. tostring(p) .. "): game campaign draw")
    return nil
  end
  if p and p.tournament_pending then
    -- the tournament's start: the game's own campaign start does not run (tournament.lua writes the block)
    PREP = nil
    return { skip = true, ret = 0 }
  end
  PREP = p
  return nil
end

-- the post-phase of a decide on `menu`
local function decide_post(menu)
  if FREE and FREE.menu == menu then
    free_back("post-phase")
  end
  local p = PREP
  PREP = nil
  if not p or p.menu ~= menu then
    return nil
  end
  local ok, e = pcall(finish, p)
  if not ok then
    warn("post-phase failed: " .. tostring(e))
    pcall(restore_grid, p)
  end
  return nil
end

VRFW.on("hook:Decide", function(ev)
  return decide_pre(ev.args[1], ev.args[2], ev.args[3])
end)

VRFW.on("hook:Decide:post", function(ev)
  return decide_post(ev.args[1])
end)

-- ------------------------------------------------------------------------------------------------ the owned difficulty
-- A mod that sets the CPU's AI itself publishes the game's difficulty index (0-3) as a game_state key; config.toml
-- [difficulty] owner_states lists the keys read. While one answers, the Battle Bay asks for no difficulty (graft
-- bb_draft bbd_difficulty.lua): the menus' GetSelectDifficultyIdx answers it, the Campaña / Torneo team decide starts
-- at once (StartWithoutDifficulty) and the 1 vs 1's match settings hide their difficulty row.

local DIFFICULTY_LEVELS = 4 -- the game's difficulty windows: 4 levels, index 0-3
local DIFFICULTY_STATES = {}
do
  local keys = U.config("difficulty.owner_states", {})
  if type(keys) ~= "table" then
    keys = { keys }
  end
  for _, k in ipairs(keys) do
    k = U.trim(tostring(k))
    if k ~= "" then
      DIFFICULTY_STATES[#DIFFICULTY_STATES + 1] = k
    end
  end
end
local difficulty_shown = nil
local difficulty_bad = {}

-- the owned difficulty: index, key; nil = no key answers
local function owned_difficulty()
  for _, key in ipairs(DIFFICULTY_STATES) do
    local ok, v = pcall(VRFW.state.get, key)
    v = ok and tonumber(v) or nil
    if v ~= nil then
      v = floor(v)
      if v >= 0 and v < DIFFICULTY_LEVELS then
        return v, key
      end
      if not difficulty_bad[key] then
        difficulty_bad[key] = true
        warn(string.format("difficulty: game_state %s = %d is not a difficulty index (0-%d): ignored", key, v,
          DIFFICULTY_LEVELS - 1))
      end
    end
  end
  return nil
end

-- CMND_BBD_DIFFICULTY_OWNED -> the owned difficulty index, -1 = none (logged when it changes)
function BattleBayDeluxe.OwnedDifficulty()
  local ok, idx, key = pcall(owned_difficulty)
  if not ok then
    warn("difficulty: owner check failed: " .. tostring(idx))
    return -1
  end
  local shown = idx and (key .. "=" .. idx) or "none"
  if shown ~= difficulty_shown then
    difficulty_shown = shown
    if idx then
      info(string.format("difficulty: owned (game_state %s): index %d of 0-%d for every Battle Bay match, no "
        .. "difficulty asked", key, idx, DIFFICULTY_LEVELS - 1))
    else
      info("difficulty: no mod owns it (config.toml [difficulty] owner_states): the player picks it")
    end
  end
  return idx or -1
end

local function start_without_difficulty()
  local idx = owned_difficulty()
  if idx == nil then
    warn("difficulty start: no mod owns the difficulty: nothing started")
    return false
  end
  local menu = CAMPAIGN_GRID
  CAMPAIGN_GRID = nil
  if not menu or (U.get(U.struct("GridMenu", menu), "campaign") or 0) == 0 then
    warn("difficulty start: no Campaña grid decided: nothing started")
    return false
  end
  local okb, lb = pcall(VRFW.mem.buffer, "bbd_layer_start", 4)
  if not okb or not U.wr("u32", lb, G.BTN_CAMPAIGN_START) then
    warn("difficulty start: layer buffer not writable: nothing started")
    return false
  end
  local r = decide_pre(menu, lb, 0)
  if type(r) == "table" and r.skip then
    info("difficulty start: the game's start not run (the Torneo draws its run): difficulty index " .. idx)
    return true
  end
  local ok, e = U.call("GameDecide", menu, lb, 0)
  decide_post(menu)
  if not ok then
    warn("difficulty start: the game's start failed: " .. tostring(e))
    return false
  end
  info("difficulty start: the Campaña started without the difficulty window, difficulty index " .. idx)
  return true
end

-- CMND_BBD_DIFFICULTY_START -> true = started (or the Torneo's run drawn), false = nothing started
function BattleBayDeluxe.StartWithoutDifficulty()
  local ok, done = pcall(start_without_difficulty)
  if not ok then
    warn("difficulty start failed: " .. tostring(done))
    return false
  end
  return done == true
end
