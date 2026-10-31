-- Match EXP, script side (docs/framework/match-exp.md). Declarations: every active mod's content\match_exp\*.toml
-- (`VRFW.match_exp/1`, keys content\types\match_exp.toml).
-- At the end of a match the game's result builder (hook MatchExp.Result, after Match.EndPrizes) has written each
-- player's EXP in the result entries; the result screen shows them and the apply step adds them to the players. When
-- the match's game and difficulty row match a declaration, each entry of the user's team is rewritten:
--   levels = levels × gap rate (player level - rival team level) × rank rate, clamped to min_levels .. max_levels
--   EXP    = the EXP to rise `levels` levels from the player's level and EXP (his rarity's EXP rate), stopped at the
--            rival team's level for a player below it (cap_at_rival), × his share of the game's own EXP (retail_share)
-- One log line per match, and one per player when a rule applies.

MatchExp = MatchExp or {}
-- The result of the last finished match, published at its result builder before the result screen: MatchResult.last =
-- { game, difficulty, won, outcome, score_for, score_against, seq } (the user's side; outcome = "win" | "draw" |
-- "loss", the game's own judge; seq counts the results published this session), then the signal `vrfw.match_result`
-- (VRFW.on("signal:vrfw.match_result", fn)). A match left before its end has no result builder: nothing is published.
MatchResult = MatchResult or {}

local D = require "lib/declarations"
local ExpTable = require "lib/exp_table"

local function info(text) VRFW.log("match_exp: " .. text) end
local function warn(text) VRFW.warn("match_exp: " .. text) end

local HOOK = "MatchExp.Result"
local EXP_MAX = 99999999

-- result block (MatchExpResultBlock): 30 entries of 20 B (+0 match handle, +0xC EXP), the total EXP, the result flags
local ENTRIES, ENTRY_SIZE, ENTRY_COUNT, ENTRY_EXP = 0xAFC, 0x14, 30, 0xC
local TOTAL_EXP = 0xDC8
-- the judge (Match.EndPrizes): +0xDE8 won, +0xDE9 lost, +0xDEA drawn; bit 0 of +0xD74 set = +0xD75 / +0xD76 / +0xD77
local RESULT_OVERRIDE_FLAGS, RESULT_OVERRIDE_WON, RESULT_WON = 0xD74, 0xD75, 0xDE8
local RESULT_OVERRIDE_LOST, RESULT_OVERRIDE_DRAWN, RESULT_LOST, RESULT_DRAWN = 0xD76, 0xD77, 0xDE9, 0xDEA
-- match info (MatchExpInfo)
local INFO_GAME, INFO_DIFFICULTY, INFO_USER_TEAM, INFO_SCORES, INFO_SCORE_SIDE = 4, 0x15, 0x4C, 0x2C26, 0x2C29
-- match teams (MatchExpParty): the team array pointer, the team stride, the member slots (16 B: match handle, saved handle)
local TEAMS, TEAM_SIZE, MEMBERS_FROM, MEMBERS_TO, MEMBER_SIZE = 0x1E0, 0x4A8, 0x80, 0x250, 0x10
-- character record (VRFW.chara.record(hdl).addr): the EXP inside the current level
local RECORD_EXP = 8
-- save flag block (MatchExpFlags): one clear status byte per statusFlagIndex; bit 1 + the difficulty's place below
local CLEAR_STATUS, CLEAR_STATUS_SIZE = 0x15948, 300
local CLEAR_DIFFICULTIES = { 1, 2, 3, 4, 10, 11 }

local RULES = nil         -- the declarations in load order, compiled
local GAME_NAME = nil     -- game id -> name
local PIECE_SLOT = nil    -- pieceId -> statusFlagIndex
local RANKS = nil         -- the match ranks, best first
local LIVE = false
local LAST = nil          -- { block, game, written = { [entry address] = exp } } of the last rewrite

require "VRFW/lib/basics"
local function int(v) return VRFW.value.int(v, 0) end

local Id = require "lib/ids"
local u32 = Id.u32

local hex = Id.hex

local function rd(ty, addr)
  if not addr or addr < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, addr)
  if ok then return v end
  return nil
end

local function global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

-- a name glob (`*` any run, `?` one character) as an anchored Lua pattern
local function glob_pattern(g)
  local out = g:gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0"):gsub("%*", ".*"):gsub("%?", ".")
  return "^" .. out .. "$"
end

local function points(xs, ys)
  local out = {}
  for i = 1, math.min(#xs, #ys) do out[#out + 1] = { xs[i], ys[i] } end
  table.sort(out, function(a, b) return a[1] < b[1] end)
  return out
end

-- the rate at x: straight lines between the points, the end rates beyond the ends (no point = 1)
local function rate_at(pts, x)
  if #pts == 0 then return 1 end
  if x <= pts[1][1] then return pts[1][2] end
  for i = 2, #pts do
    local a, b = pts[i - 1], pts[i]
    if x <= b[1] then
      if b[1] == a[1] then return b[2] end
      return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
    end
  end
  return pts[#pts][2]
end

local function load_rules()
  if RULES ~= nil then return RULES end
  RULES = {}
  local schema, why = D.schema("match_exp")
  if not schema then
    warn(why .. ": the game's match EXP")
    return RULES
  end
  local decls, skipped = D.load(schema, warn)
  for _, d in ipairs(decls) do
    local v = d.v
    if #(v.gap or {}) ~= #(v.gap_rates or {}) then
      warn(string.format("%s: gap has %d value(s), gap_rates %d: left out", d.where, #(v.gap or {}), #(v.gap_rates or {})))
    elseif #(v.rank_ids or {}) ~= #(v.rank_rates or {}) then
      warn(string.format("%s: rank_ids has %d value(s), rank_rates %d: left out", d.where, #(v.rank_ids or {}), #(v.rank_rates or {})))
    else
      local r = { key = d.key, games = {}, globs = v.games, difficulties = {}, any_difficulty = #(v.difficulties or {}) == 0,
        until_pieces = v.until_cleared_pieces or {}, until_difficulty = v.until_cleared_difficulty or 2,
        levels = v.levels, gap = points(v.gap or {}, v.gap_rates or {}), ranks = {}, no_rank_rate = v.no_rank_rate,
        min_levels = v.min_levels, max_levels = v.max_levels, cap_at_rival = v.cap_at_rival, retail_share = v.retail_share }
      for _, g in ipairs(v.games) do r.games[#r.games + 1] = glob_pattern(g) end
      for _, x in ipairs(v.difficulties or {}) do r.difficulties[x] = true end
      for i, id in ipairs(v.rank_ids or {}) do r.ranks[id] = v.rank_rates[i] end
      RULES[#RULES + 1] = r
      info(string.format("rule %s: games %s, difficulties %s, %d level(s) at rate 1, %d gap point(s), %d rank rate(s)%s",
        d.key, table.concat(v.games, " "), r.any_difficulty and "any" or table.concat(v.difficulties, "/"), v.levels,
        #r.gap, #(v.rank_ids or {}), #r.until_pieces > 0 and string.format(", until %d piece(s) cleared at difficulty %d", #r.until_pieces, r.until_difficulty) or ""))
    end
  end
  if #RULES == 0 then
    info(string.format("off: no rule (%d declaration(s) left out by `when`): the game's match EXP", skipped or 0))
  end
  return RULES
end

-- level -> needExp and rarity -> rate (the served chara_exp_table_config: the mods' levels included)
local function exp_tables()
  local need, rates = ExpTable.tables()
  if need == nil then warn(tostring(rates) .. ": the game's match EXP") end
  return need, rates
end

local function game_name(id)
  if GAME_NAME == nil then
    GAME_NAME = {}
    local ok, rows = pcall(VRFW.table.rows, "soccer/soccer_game_info")
    if ok and type(rows) == "table" then
      for _, r in ipairs(rows) do
        local name = r.name or r[2]
        if type(name) == "string" then GAME_NAME[u32(r.id or r[1])] = name end
      end
    else
      warn("soccer_game_info is not readable (" .. tostring(rows) .. "): no match is named")
    end
  end
  return GAME_NAME[id]
end

local function piece_slot(piece)
  if PIECE_SLOT == nil then
    PIECE_SLOT = {}
    local ok, pieces = pcall(VRFW.table.rows, "vsroute/vs_route_piece")
    if ok and type(pieces) == "table" then
      for _, p in ipairs(pieces) do
        local id, sfi = u32(p.pieceId or p[2]), int(tonumber(p.statusFlagIndex or p[4]) or 0)
        if id ~= 0 and sfi > 0 then PIECE_SLOT[id] = sfi end
      end
    else
      warn("the board's pieces are not readable (" .. tostring(pieces) .. "): no piece counts as cleared")
    end
  end
  return PIECE_SLOT[u32(piece)]
end

-- the clear bit of a Chronicle piece at a difficulty in the save in use (nil = unknown)
local function piece_cleared(piece, difficulty)
  local sfi = piece_slot(piece)
  if sfi == nil or sfi >= CLEAR_STATUS_SIZE then return nil end
  local bit = nil
  for i, d in ipairs(CLEAR_DIFFICULTIES) do
    if d == difficulty then bit = i end
  end
  local flags = global("MatchExpFlags")
  if bit == nil or flags == nil then return nil end
  local b = rd("u8", flags + CLEAR_STATUS + sfi)
  if b == nil then return nil end
  return math.floor(b / 2 ^ bit) % 2 == 1
end

-- the declared match ranks (every active mod's defaults\match_rank.toml, merged by Id), best first
local function ranks()
  if RANKS ~= nil then return RANKS end
  RANKS = {}
  local by = {}
  local ok, files = pcall(VRFW.files.declarations, "content/defaults/match_rank.toml")
  if ok and type(files) == "table" then
    for _, f in ipairs(files) do
      local mr = type(f.data) == "table" and f.data.MatchRank or nil
      if type(mr) == "table" then
        for id, t in pairs(mr) do
          if type(t) == "table" then
            by[id] = by[id] or { id = id }
            for k, x in pairs(t) do by[id][k] = x end
          end
        end
      end
    end
  end
  for _, r in pairs(by) do RANKS[#RANKS + 1] = r end
  table.sort(RANKS, function(a, b) return (tonumber(a.Order) or 0) > (tonumber(b.Order) or 0) end)
  return RANKS
end

-- the rank Id of the match (the best rank whose conditions hold), nil = none
local function rank_of(won, f, a)
  for _, r in ipairs(ranks()) do
    local ok = true
    if r.Won ~= false and not won then ok = false end
    if ok and r.GoalsFor and f < r.GoalsFor then ok = false end
    if ok and r.MaxConceded and a > r.MaxConceded then ok = false end
    if ok and r.GoalDiff and f - a < r.GoalDiff then ok = false end
    if ok then return r.id end
  end
  return nil
end

-- the first rule for this game / difficulty whose piece condition holds
local function rule_for(name, difficulty)
  for _, r in ipairs(load_rules()) do
    local hit = false
    for _, p in ipairs(r.games) do
      if name:match(p) then hit = true break end
    end
    if hit and (r.any_difficulty or r.difficulties[difficulty]) then
      local done = false
      for _, piece in ipairs(r.until_pieces) do
        local c = piece_cleared(piece, r.until_difficulty)
        if c == nil then
          warn(string.format("rule %s: the clear of piece %s is not readable: counted as not cleared", r.key, hex(piece)))
        elseif c then
          done = true
          break
        end
      end
      if not done then return r end
    end
  end
  return nil
end

-- the members of a match team: { { match = handle, saved = handle }, … }
local function members(party, team)
  local teams = rd("u64", party + TEAMS)
  if not teams or teams < 0x10000 then return {} end
  local base = teams + team * TEAM_SIZE
  local out = {}
  for at = base + MEMBERS_FROM, base + MEMBERS_TO - 1, MEMBER_SIZE do
    local h, alt = rd("u32", at), rd("u32", at + 4)
    if h and h ~= 0 then out[#out + 1] = { match = h, saved = (alt and alt ~= 0) and alt or h } end
  end
  return out
end

-- the team's level as the game counts it: the rounded-up average level of its members
local function team_level(list)
  local sum, n = 0, 0
  for _, m in ipairs(list) do
    local ok, rec = pcall(VRFW.chara.record, m.match)
    if ok and type(rec) == "table" and tonumber(rec.level) then
      sum, n = sum + rec.level, n + 1
    end
  end
  if n == 0 then return nil end
  return math.ceil(sum / n)
end

-- the EXP to rise `levels` levels from `level` + `now_exp` (each level's own size), stopped at `stop_level` (nil = no stop)
local function exp_to_rise(need, rate, level, now_exp, levels, stop_level)
  local total, lv, have, left = 0, level, now_exp, levels
  while left > 1e-9 do
    if stop_level and lv >= stop_level then break end
    local n = need[lv]
    if not n or n <= 0 then break end
    n = n * rate
    local room = math.max(0, n - have)
    local want = left * n
    if want <= room then
      total = total + want
      break
    end
    total = total + room
    left = left - room / n
    lv, have = lv + 1, 0
  end
  return math.floor(total + 0.5)
end

-- the finished match's result for every mod (MatchResult.last + signal vrfw.match_result)
local function publish()
  local minfo, block = global("MatchExpInfo"), global("MatchExpResultBlock")
  if not minfo or not block then return end
  local user = int(rd("u8", minfo + INFO_USER_TEAM) or 255)
  if user > 1 then return end
  local side = int(rd("u8", minfo + INFO_SCORE_SIDE) or user)
  if side > 1 then side = user end
  local f, a = int(rd("u8", minfo + INFO_SCORES + side) or 0), int(rd("u8", minfo + INFO_SCORES + 1 - side) or 0)
  local override = int(rd("u8", block + RESULT_OVERRIDE_FLAGS) or 0) % 2 == 1
  local function flag(own, overridden)
    return int(rd("u8", block + (override and overridden or own)) or 0) ~= 0
  end
  local won = flag(RESULT_WON, RESULT_OVERRIDE_WON)
  local outcome = won and "win" or (flag(RESULT_DRAWN, RESULT_OVERRIDE_DRAWN) and "draw")
    or (flag(RESULT_LOST, RESULT_OVERRIDE_LOST) and "loss") or (f > a and "win" or (f < a and "loss" or "draw"))
  local game = u32(rd("u32", minfo + INFO_GAME))
  MatchResult.seq = (MatchResult.seq or 0) + 1
  MatchResult.last = { game = game, difficulty = int(rd("u8", minfo + INFO_DIFFICULTY) or -1), won = won,
    outcome = outcome, score_for = f, score_against = a, seq = MatchResult.seq }
  info(string.format("result: game %s, %s %d-%d", hex(game), outcome, f, a))
  pcall(VRFW.signal, "vrfw.match_result")
end

local function rewrite()
  local minfo, block, party = global("MatchExpInfo"), global("MatchExpResultBlock"), global("MatchExpParty")
  if not minfo or not block or not party then return end
  local game, difficulty = u32(rd("u32", minfo + INFO_GAME)), int(rd("u8", minfo + INFO_DIFFICULTY) or -1)
  local name = game_name(game) or hex(game)
  local rule = rule_for(name, difficulty)
  if not rule then
    info(string.format("match %s (difficulty %d): no rule, the game's EXP", name, difficulty))
    return
  end
  -- the same result written again (a second build of the same block): already done
  if LAST and LAST.block == block and LAST.game == game then
    local same = true
    for addr, exp in pairs(LAST.written) do
      if rd("u32", addr) ~= exp then same = false break end
    end
    if same then return end
  end
  local need, rates = exp_tables()
  if not need then return end
  local user = int(rd("u8", minfo + INFO_USER_TEAM) or 255)
  if user > 1 then
    warn(string.format("match %s: the user's team is unknown (%d): the game's EXP", name, user))
    return
  end
  local side = int(rd("u8", minfo + INFO_SCORE_SIDE) or user)
  if side > 1 then side = user end
  local f, a = int(rd("u8", minfo + INFO_SCORES + side) or 0), int(rd("u8", minfo + INFO_SCORES + 1 - side) or 0)
  local override = int(rd("u8", block + RESULT_OVERRIDE_FLAGS) or 0) % 2 == 1
  local won = int(rd("u8", block + (override and RESULT_OVERRIDE_WON or RESULT_WON)) or 0) ~= 0
  local rank = rank_of(won, f, a)
  local rank_rate = (rank and rule.ranks[rank]) or rule.no_rank_rate
  local rival = team_level(members(party, 1 - user))
  if not rival then
    warn(string.format("match %s: the rival team's level is not readable: the game's EXP", name))
    return
  end
  -- the user's entries: match handle -> { address, game EXP }
  local entry = {}
  for i = 0, ENTRY_COUNT - 1 do
    local at = block + ENTRIES + i * ENTRY_SIZE
    local h = rd("u32", at)
    if h and h ~= 0 then entry[h] = { at = at + ENTRY_EXP, exp = rd("u32", at + ENTRY_EXP) or 0 } end
  end
  local list, top = {}, 0
  for _, m in ipairs(members(party, user)) do
    local e = entry[m.match]
    if e then
      list[#list + 1] = { m = m, e = e }
      if e.exp > top then top = e.exp end
    end
  end
  local written, lines, total, old_total = {}, {}, 0, 0
  for _, p in ipairs(list) do
    local ok, rec = pcall(VRFW.chara.record, p.m.saved)
    local exp = p.e.exp
    old_total = old_total + p.e.exp
    if ok and type(rec) == "table" and tonumber(rec.level) and rec.addr then
      local lv = int(rec.level)
      local now = u32(rd("u32", rec.addr + RECORD_EXP) or 0)
      local gap = lv - rival
      local levels = rule.levels * rate_at(rule.gap, gap) * rank_rate
      levels = math.max(rule.min_levels, math.min(rule.max_levels, levels))
      local share = 1
      if rule.retail_share then share = top > 0 and p.e.exp / top or 0 end
      local stop = (rule.cap_at_rival and lv < rival) and rival or nil
      local rate = (rates and rates[int(rec.rarity or -1)]) or 1
      exp = math.min(EXP_MAX, int(exp_to_rise(need, rate, lv, now, levels * share, stop)))
      lines[#lines + 1] = string.format("%s Lv %d (+%d EXP, gap %+d): %.2f level(s)%s -> %d EXP (game %d)", hex(p.m.saved), lv,
        now, gap, levels * share, stop and string.format(" up to Lv %d", stop) or "", exp, p.e.exp)
    else
      lines[#lines + 1] = string.format("%s: record not readable, the game's %d EXP", hex(p.m.saved), exp)
    end
    if exp ~= p.e.exp and not pcall(VRFW.mem.write, "u32", p.e.at, exp) then
      warn(string.format("%s: EXP not writable: the game's %d EXP", hex(p.m.saved), p.e.exp))
      exp = p.e.exp
    end
    written[p.e.at] = exp
    total = total + exp
  end
  pcall(VRFW.mem.write, "u32", block + TOTAL_EXP, math.min(EXP_MAX, total))
  LAST = { block = block, game = game, written = written }
  info(string.format("match %s (difficulty %d), rule %s: rival Lv %d, %s %d-%d, rank %s (rate %.2f): %d player(s), EXP %d -> %d",
    name, difficulty, rule.key, rival, won and "won" or "not won", f, a, rank or "none", rank_rate, #list, old_total, total))
  for _, l in ipairs(lines) do info("  " .. l) end
end

VRFW.on("hook:" .. HOOK .. ":post", function(ev)
  local okp, ep = pcall(publish)
  if not okp then warn("result not published (" .. tostring(ep) .. ")") end
  local ok, e = pcall(rewrite)
  if not ok then warn("rewrite failed (" .. tostring(e) .. "): the game's EXP") end
  return nil
end)

-- the detour always: the match result is published for every mod; the EXP rewrite only where a rule is declared
local function start()
  local ok, done, e = pcall(VRFW.hook.apply, HOOK)
  LIVE = ok and done == true
  if not LIVE then
    warn(string.format("detour %s not installed (%s): the game's match EXP", HOOK, tostring(ok and e or done)))
  else
    info(string.format("on: %d rule(s), match results published", #load_rules()))
  end
end

pcall(start)
