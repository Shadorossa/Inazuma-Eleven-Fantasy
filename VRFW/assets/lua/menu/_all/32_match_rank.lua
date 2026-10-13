-- menu_engine: the ranks of a won match, VRFW_MatchRank (VR-Framework base feature, 2.0.48; DECLARED in TOML since
-- 2.0.49: Nacho 2026-10-09 «mods must be able to add custom ranks»; docs/framework/route-board.md §3). Definitions only
-- (this file runs in every script VM, lua\_all; no engine call at load: the ranks are read at the first use).
-- The ranks are the active mods' defaults\match_rank.toml ([MatchRank.<Id>]: Order, Won, GoalsFor, MaxConceded,
-- GoalDiff, Badge, BadgeAtlas, PieceBadge, Text; merged by Id in load order, so a mod redeclares S / A / B or adds its
-- own), served best first by the team type: CMND_VRFW_TEAM_MATCH_RANK_COUNT() / _GET(i). Framework defaults:
--   S (Order 3) = scored >= 5 and conceded <= 0, A (2) = scored >= 3 and conceded <= 0, B (1) = any other win.
-- A rank is an Id string ("S", "Fantasy.SS"); its Order compares ranks and scales averages. Saves keep Ids; the digits
-- 1 / 2 / 3 of older saves are B / A / S (FromLegacy).
-- The score of the last match: the framework's mod script scripts\match_score.lua (save service, owner vr_framework,
-- mr_last_for / mr_last_against; reset at match_start, set at every goal).
if VRFW_MatchRank == nil then
  local R = {
    OWNER = "vr_framework",
    SAVE_GET = 2187277743,       -- CMND_VRFW_SAVE_GET (owner, key, default)
    LOG = 3661580131,            -- CMND_EVT_LOG
    COUNT = 869174933,           -- CMND_VRFW_TEAM_MATCH_RANK_COUNT
    GET = 2876553236,            -- CMND_VRFW_TEAM_MATCH_RANK_GET
    LEGACY = {[1] = "B", [2] = "A", [3] = "S"},
    list = nil,                  -- best first: {id, order, won, gf, mc, gd, badge, atlas, piece, text}
    by = nil,
  }
  VRFW_MatchRank = R

  local function log(...)
    pcall(funcLuaCommand, R.LOG, "vrfw.MatchRank", ...)
  end

  -- the declared ranks, best first (read once per VM)
  function R.List()
    if R.list ~= nil then
      return R.list
    end
    R.list, R.by = {}, {}
    local ok, n = pcall(funcLuaCommand, R.COUNT)
    n = ok and tonumber(n) or 0
    for i = 0, n - 1 do
      local okG, id, order, won, gf, mc, gd, badge, atlas, piece, text = pcall(funcLuaCommand, R.GET, i)
      if okG and type(id) == "string" and id ~= "" then
        local r = {id = id, order = tonumber(order) or 0, won = won ~= 0, gf = tonumber(gf) or -1, mc = tonumber(mc) or -1,
                   gd = tonumber(gd) or -999, badge = badge or "", atlas = atlas or "", piece = piece or "", text = text or ""}
        R.list[#R.list + 1] = r
        R.by[id] = r
      end
    end
    if #R.list == 0 then
      log("no ranks declared (defaults\\match_rank.toml): wins are unranked")
    end
    return R.list
  end

  function R.ById(id)
    R.List()
    return id ~= nil and R.by[id] or nil
  end

  -- the Order of a rank Id (0 = none / unknown)
  function R.Order(id)
    local r = R.ById(id)
    return r ~= nil and r.order or 0
  end

  -- a save's stored rank: an Id, or a digit 1 / 2 / 3 of an older save (B / A / S)
  function R.FromLegacy(v)
    local n = tonumber(v)
    if n ~= nil then
      return R.LEGACY[n]
    end
    return v
  end

  -- the short label shown in texts: the part of the Id after its last dot ("Fantasy.SS" -> "SS")
  function R.Label(id)
    if id == nil then
      return ""
    end
    return string.match(id, "([^%.]+)$") or id
  end

  local function holds(r, f, a)
    local win = f > a
    if r.won and not win then
      return false
    end
    if r.gf >= 0 and f < r.gf then
      return false
    end
    if r.mc >= 0 and a > r.mc then
      return false
    end
    if r.gd > -999 and f - a < r.gd then
      return false
    end
    return true
  end

  -- the rank Id of a match scoring f and conceding a: the best rank whose conditions hold (nil = none). An unknown
  -- score (-1) of a won match gets the lowest rank that needs no score (B by default).
  function R.Of(f, a)
    f, a = tonumber(f) or -1, tonumber(a) or -1
    local list = R.List()
    if f < 0 or a < 0 then
      for i = #list, 1, -1 do
        local r = list[i]
        if r.gf < 0 and r.mc < 0 and r.gd <= -999 then
          return r.id
        end
      end
      return list[#list] and list[#list].id or nil
    end
    for _, r in ipairs(list) do
      if holds(r, f, a) then
        return r.id
      end
    end
    return nil
  end

  -- the last match's rank Id and score (id, for, against)
  function R.Last()
    local okF, f = pcall(funcLuaCommand, R.SAVE_GET, R.OWNER, "mr_last_for", -1)
    local okA, a = pcall(funcLuaCommand, R.SAVE_GET, R.OWNER, "mr_last_against", -1)
    f = okF and tonumber(f) or -1
    a = okA and tonumber(a) or -1
    return R.Of(f, a), f, a
  end

  -- the rank of an average Order (chains): the best rank whose Order is at most the average rounded half up
  function R.ForOrder(avg)
    local o = math.floor((tonumber(avg) or 0) + 0.5)
    for _, r in ipairs(R.List()) do
      if r.order <= o then
        return r.id
      end
    end
    return nil
  end
end
