-- menu_engine: the match difficulties that exist with the active mods, VRFW_MatchDifficulty (VR-Framework). Definitions only (this
-- file runs in every script VM, lua\_all; no engine call at load: the set is read at the first use).
-- The difficulties are the active mods' defaults\match_difficulty.toml ([MatchDifficulty.<Id>]: Difficulty, Contexts,
-- Enabled, Badge, BadgeAtlas, Name, Level, Order; merged by Id in load order), served per context by the team type:
-- CMND_VRFW_TEAM_DIFFICULTY_COUNT(ctx) / _GET(ctx, i). Contexts: "route" (normal board pieces), "gate" (gate pieces),
-- "chain", "free_match". Readers: a mod's board rules (e.g. a chronicle redesign: dots, battle-kind rows,
-- team-list orbs) instead of their own copies.
if VRFW_MatchDifficulty == nil then
  local D = {
    LOG = VRFW_Cmd.EVT_LOG,            -- CMND_EVT_LOG
    COUNT = VRFW_Cmd.VRFW_TEAM_DIFFICULTY_COUNT,          -- CMND_VRFW_TEAM_DIFFICULTY_COUNT
    GET = VRFW_Cmd.VRFW_TEAM_DIFFICULTY_GET,            -- CMND_VRFW_TEAM_DIFFICULTY_GET
    sets = {},                   -- ctx -> {[difficulty] = true}, or false = nothing declared (every difficulty exists)
    lists = {},                  -- ctx -> {{difficulty, id, level, atlas, sprite}, ...} in order
  }
  VRFW_MatchDifficulty = D

  local function log(...)
    pcall(funcLuaCommand, D.LOG, "vrfw.MatchDifficulty", ...)
  end

  local function load(ctx)
    if D.sets[ctx] ~= nil then
      return
    end
    local ok, n = pcall(funcLuaCommand, D.COUNT, ctx)
    n = ok and tonumber(n) or -1
    if n < 0 then
      D.sets[ctx], D.lists[ctx] = false, {}
      return
    end
    local set, list = {}, {}
    for i = 0, n - 1 do
      local okG, d, id, level, atlas, sprite = pcall(funcLuaCommand, D.GET, ctx, i)
      d = okG and tonumber(d) or nil
      if d ~= nil then
        set[d] = true
        list[#list + 1] = {difficulty = d, id = id or "", level = tonumber(level) or -1, atlas = atlas or "", sprite = sprite or ""}
      end
    end
    D.sets[ctx], D.lists[ctx] = set, list
    log(ctx, n)
  end

  -- {[difficulty] = true} of context ctx; nil = nothing declared (every difficulty exists: keep the retail behaviour)
  function D.Set(ctx)
    load(ctx)
    return D.sets[ctx] or nil
  end

  -- does difficulty d exist in context ctx (true when nothing is declared)
  function D.Exists(ctx, d)
    local s = D.Set(ctx)
    return s == nil or s[d] == true
  end

  -- the difficulties of context ctx in order ({difficulty, id, level, atlas, sprite}; empty when nothing is declared)
  function D.List(ctx)
    load(ctx)
    return D.lists[ctx]
  end
end
