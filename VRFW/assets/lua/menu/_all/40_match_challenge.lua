-- menu_engine: match challenges («desafíos», VR-Framework service; docs/framework/match-challenge.md).
-- Definitions only (this file runs in every script VM, lua\_all; no engine call at load time). The ONE place that
-- checks the player's team against a match's challenge (`[[VRFW.MatchChallenge]]` of the team type, named by a route
-- node, a chain tile, a free-match tab or by the challenge's own `Games`). Called where a match is chosen: the
-- Chronicle board's command menu (vs_route_town_command_select_menu/110_match_challenge.lua), the chain board screen
-- (vrfw_chain_board_menu) and the free-match list (soccer_vs_cpu_list_menu/110_match_challenge.lua). Nothing here
-- names a challenge, a team or a mod: the conditions come from the mods' TOML, the texts from the framework's
-- menu_text rows (text\rows\match_challenge.toml) and the mod's own rows (the challenge's Title / Description).
--
--   VRFW_MC.Of(game, diff)         -> challenge index (0-based) of a match game, nil = none. A challenge with
--                                     `Difficulties` applies only to those rows: nil when `diff` (the row's
--                                     difficulty, when the caller knows it) is not listed or not given
--   VRFW_MC.Info(i)                -> {i, name, mod, title, description (text ids), scope, nreq, diffs, required} (cached;
--                                     required = {{count, places = {codes}, until_first_clear, text}, ...})
--   VRFW_MC.TitleOf(game, diff)    -> the challenge's title text of a match, nil = none (guide lines)
--   VRFW_MC.RequiredTexts(i, cleared) -> the text ids of its required starters that apply (a `UntilFirstClear` one
--                                     stops once the row is won), for the match info; generated ones are left out
--   VRFW_MC.Players(scope, tt)     -> the active dock's players in scope: {{hdl, card, level, rarity, pos, place}, ...}
--                                     (place: a starter's formation place, 1 GK / 2 FW / 3 MF / 4 DF, 0 unknown; nil
--                                     on the bench)
--   VRFW_MC.Check(i, tt, cleared)  -> ok, failed {1-based conditions; required starter k = nreq + k}, offenders
--                                     {players}, players
--   VRFW_MC.Refusal(game, tt, diff, cleared) -> nil when the team may play, else the message text (title, description,
--                                     the failed conditions, who breaks them)
--   VRFW_MC.Gate(game, tt, diff, cleared) -> true = play; false = refused (error sound + the message window, fire and
--                                     forget like the retail team check, for OnEnter handlers that return 1)
-- tt = the dock's team (0 = the 11-a-side team, default; 1 = the 5-a-side team). cleared = the launcher knows the
-- match row was won before (true); nil / false = not won or unknown (a `UntilFirstClear` required starter applies).
-- A team the framework cannot read (no DLL, no command) is never refused.
if VRFW_MC == nil then
  local MC = {
    CMD = {
      OF = 721571515,         -- CMND_VRFW_TEAM_CHALLENGE_OF (game) -> i / -1
      GET = 3349286993,       -- CMND_VRFW_TEAM_CHALLENGE_GET (i) -> name, mod, title, description, scope, conditions,
                              --   difficulties ("4", "1,4"; "" = every row)
      REQ = 2904917317,       -- CMND_VRFW_TEAM_CHALLENGE_REQ (i, "2/1") -> kind, at least, at most, text, inner, filter
      CHECK = 3751451304,     -- CMND_VRFW_TEAM_CHALLENGE_CHECK (i, "card:level:rarity[:place];...", cleared 0 / 1)
                              --   -> ok, failed, offenders
      REQUIRED = 754037657,   -- CMND_VRFW_TEAM_CHALLENGE_REQUIRED (i, k) -> characters, places "2,3", until first
                              --   clear, own text id
    },
    VS_SET = 3713813716,      -- CMND_GET_VS_USE_TEAM_SET
    MEMBER = 1720957768,      -- (set, team, i, 0 hdl / 1 position)
    STATUS = 1131797651,      -- (hdl, 0 level / 4 chara_param / 12 rarity)
    TEAM_SET_INFO = 1033065575, -- CMND_GET_TEAM_SET_INFO (set, team, 4) -> ok, formation id
    FORMATION_INFO = 2649030357, -- CMND_GET_SOCCER_FORMATION_INFO (6, formation, place) -> ok, scPosType bits
    -- scPosType bit (16 GK, 32 DF, 64 MF, 128 FW; docs/game/characters/position-cards.md §4c) -> position code
    PLACE_BITS = {{16, 1}, {32, 4}, {64, 3}, {128, 2}},
    NAME = 1915015278,        -- CMND_GET_CHARA_NAME_TEXT (hdl)
    SERIES = 964991930,       -- CMND_GET_CHARA_SERIES_INFO (1, series) -> ok, name (menu VMs)
    TEXT_GET = 4074371074,    -- CMND_TEXT_GET
    MSG_OPEN = 2289627655,
    SE = 1917805374, SE_NG = 2086672038 --[[sy0003]],
    LOG = 3661580131,
    -- the framework's menu_text rows (crc32 of the row id)
    T = {
      HEAD = 2317620035, REFUSED = 1303940226, EVERY = 3039376359, NONE = 1380443408, AT_LEAST = 2356225541,
      AT_MOST = 4270555599, BETWEEN = 1647389433, ANY_OF = 3050005278, ALL_OF = 2831980499, OFFENDERS = 2311040840,
      MORE = 2793740195, STARTERS = 1000104873, ANYONE = 296937077,
      GENDER = {[1] = 1426515113, [2] = 3423581459},
      ELEMENT = {[0] = 2593977113, [1] = 3986408335, [2] = 1955762741, [3] = 60138147, [4] = 2649831168},
      POSITION = {[1] = 1807914029, [2] = 4073440663, [3] = 2244801793, [4] = 464019618},
      F_ELEMENT = 3685919861, F_POSITION = 970726332, F_SERIES = 2001861548, F_TEAM = 3863514637, F_CHARA = 2064652193,
      F_LEVEL_MIN = 2369649544, F_LEVEL_MAX = 2972763345, F_LEVEL = 1769018739, F_RARITY_MIN = 266945921,
      F_RARITY_MAX = 870611672, F_RARITY = 4202775751, F_NOT = 2721797827, OR = 2007264933, AND = 3539978642,
      REQUIRED = 3122860320, REQUIRED_PLACES = 4094007390,
    },
    -- the dock's positions (team 0: 0-10 starters, 11-18 bench, 19 coach, 20-28 reserves; team 1: 0-4, 5-15)
    LAST = {[0] = {starters = 10, squad = 18}, [1] = {starters = 4, squad = 15}},
    MAX_NAMES = 4,
    info = {},
  }
  VRFW_MC = MC

  local function call(cmd, ...)
    local r = table.pack(pcall(funcLuaCommand, cmd, ...))
    if r[1] then
      return table.unpack(r, 2, r.n)
    end
    return nil
  end

  local function u32(v)
    if type(v) ~= "number" then
      return 0
    end
    return math.floor(v) % 4294967296
  end

  function MC.Log(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[#parts + 1] = tostring((select(i, ...)))
    end
    pcall(funcLuaCommand, MC.LOG, "VRFW match_challenge " .. table.concat(parts, " "))
  end

  local function text(id)
    if type(id) ~= "number" or id == 0 then
      return ""
    end
    local ok, s = pcall(funcLuaCommand, MC.TEXT_GET, id)
    if ok and type(s) == "string" then
      return s
    end
    return ""
  end

  local function fmt(id, ...)
    local ok, s = pcall(string.format, text(id), ...)
    if ok then
      return s
    end
    return text(id)
  end

  function MC.Of(game, diff)
    if type(game) ~= "number" or game == 0 then
      return nil
    end
    local i = call(MC.CMD.OF, u32(game))
    if type(i) ~= "number" or i < 0 then
      return nil
    end
    local c = MC.Info(i)
    if c ~= nil and next(c.diffs) ~= nil and not (type(diff) == "number" and c.diffs[diff]) then
      return nil
    end
    return i
  end

  function MC.Info(i)
    if MC.info[i] ~= nil then
      return MC.info[i] or nil
    end
    local name, mod, title, desc, scope, nreq, diffs, nrequired = call(MC.CMD.GET, i)
    if type(name) ~= "string" or name == "" then
      MC.info[i] = false
      return nil
    end
    local set = {}
    for x in string.gmatch(type(diffs) == "string" and diffs or "", "%d+") do
      set[tonumber(x)] = true
    end
    local required = {}
    for k = 1, (type(nrequired) == "number" and nrequired or 0) do
      local count, places, until_first_clear, own = call(MC.CMD.REQUIRED, i, k)
      local codes = {}
      for x in string.gmatch(type(places) == "string" and places or "", "%d+") do
        codes[#codes + 1] = tonumber(x)
      end
      required[k] = {count = count or 0, places = codes, until_first_clear = until_first_clear == true, text = own or 0}
    end
    local c = {i = i, name = name, mod = mod, title = title or 0, description = desc or 0, scope = scope or "squad", nreq = nreq or 0,
               diffs = set, required = required}
    MC.info[i] = c
    return c
  end

  function MC.TitleOf(game, diff)
    local i = MC.Of(game, diff)
    local c = i and MC.Info(i)
    if c == nil then
      return nil
    end
    local t = text(c.title)
    if t == "" then
      t = c.name
    end
    return t
  end

  function MC.RequiredTexts(i, cleared)
    local c = MC.Info(i)
    local out = {}
    for _, r in ipairs(c and c.required or {}) do
      if not (r.until_first_clear and cleared) and type(r.text) == "number" and r.text ~= 0 then
        out[#out + 1] = r.text
      end
    end
    return out
  end

  -- the position code of a scPosType bit set (0 = none of the four)
  local function place_of(bits)
    if type(bits) ~= "number" then
      return 0
    end
    for _, b in ipairs(MC.PLACE_BITS) do
      if math.floor(bits / b[1]) % 2 == 1 then
        return b[2]
      end
    end
    return 0
  end

  function MC.Players(scope, tt)
    tt = tt or 0
    local limits = MC.LAST[tt] or MC.LAST[0]
    local last = limits[scope == "starters" and "starters" or "squad"]
    local set = call(MC.VS_SET)
    local out = {}
    if type(set) ~= "number" then
      return out
    end
    local okF, formation = call(MC.TEAM_SET_INFO, set, tt, 4)
    if not okF then
      formation = nil
    end
    for k = 0, 28 do
      local ok, hdl = call(MC.MEMBER, set, tt, k, 0)
      if ok and type(hdl) == "number" and hdl ~= 0 then
        local okP, pos = call(MC.MEMBER, set, tt, k, 1)
        if okP and type(pos) == "number" and pos >= 0 and pos <= last then
          local place = nil
          if pos <= limits.starters then
            place = 0
            if type(formation) == "number" then
              local okP2, bits = call(MC.FORMATION_INFO, 6, formation, pos)
              if okP2 then
                place = place_of(bits)
              end
            end
          end
          out[#out + 1] = {hdl = hdl, card = u32(call(MC.STATUS, hdl, 4)), level = tonumber(call(MC.STATUS, hdl, 0)) or 0,
                           rarity = tonumber(call(MC.STATUS, hdl, 12)) or -1, pos = pos, place = place}
        end
      end
    end
    return out
  end

  local function csv(s)
    local t = {}
    for x in string.gmatch(s or "", "[^,]+") do
      t[#t + 1] = tonumber(x)
    end
    return t
  end

  function MC.Check(i, tt, cleared)
    local c = MC.Info(i)
    if c == nil then
      return true, {}, {}, {}
    end
    local ps = MC.Players(c.scope, tt)
    local parts = {}
    for _, p in ipairs(ps) do
      -- not "%d": card ids >= 2^31 (32-bit `long`); the place only for starters
      parts[#parts + 1] = string.format("%.0f:%.0f:%.0f:%.0f", p.card, p.level, p.rarity, p.place or -1)
    end
    local ok, failed, bad = call(MC.CMD.CHECK, i, table.concat(parts, ";"), cleared and 1 or 0)
    if ok == nil then
      return true, {}, {}, ps
    end
    return ok == true, csv(failed), csv(bad), ps
  end

  -- ---- descriptions --------------------------------------------------------------------------------------------

  -- split "a=1;b=(x;y);c=(p)|(q)" at top-level `;`
  local function parts_of(s)
    local out, depth, cur = {}, 0, {}
    for ch in string.gmatch(s or "", ".") do
      if ch == "(" then
        depth = depth + 1
      elseif ch == ")" then
        depth = depth - 1
      end
      if ch == ";" and depth == 0 then
        out[#out + 1] = table.concat(cur)
        cur = {}
      else
        cur[#cur + 1] = ch
      end
    end
    if #cur > 0 then
      out[#out + 1] = table.concat(cur)
    end
    return out
  end

  local function inner(s)
    return (s or ""):match("^%((.*)%)$") or s or ""
  end

  local function words(map, list)
    local t = {}
    for _, v in ipairs(csv(list)) do
      t[#t + 1] = text(map[v])
    end
    return table.concat(t, text(MC.T.OR))
  end

  local function series_names(list)
    local t = {}
    for _, v in ipairs(csv(list)) do
      local ok, okc, name = pcall(funcLuaMenuCommand, MC.SERIES, 1, v)
      if ok and okc and type(name) == "string" and name ~= "" then
        t[#t + 1] = name
      end
    end
    return table.concat(t, text(MC.T.OR))
  end

  local function bounds(v)
    local a, z = v:match("^(%-?%d*)%-(%-?%d*)$")
    return tonumber(a), tonumber(z)
  end

  -- the filter description (CMND_VRFW_TEAM_CHALLENGE_REQ's last value) in words
  function MC.Filter(desc)
    local out = {}
    for _, part in ipairs(parts_of(desc)) do
      local k, v = part:match("^(%a+)=(.*)$")
      if k == "gender" then
        out[#out + 1] = text(MC.T.GENDER[tonumber(v)])
      elseif k == "element" then
        out[#out + 1] = fmt(MC.T.F_ELEMENT, words(MC.T.ELEMENT, v))
      elseif k == "position" then
        out[#out + 1] = fmt(MC.T.F_POSITION, words(MC.T.POSITION, v))
      elseif k == "series" then
        local names = series_names(v)
        out[#out + 1] = fmt(MC.T.F_SERIES, names ~= "" and names or tostring(#csv(v)))
      elseif k == "team" then
        out[#out + 1] = fmt(MC.T.F_TEAM, tonumber(v) or 0)
      elseif k == "chara" then
        out[#out + 1] = fmt(MC.T.F_CHARA, tonumber(v) or 0)
      elseif k == "level" or k == "rarity" then
        local a, z = bounds(v)
        local T = MC.T
        local min_id, max_id, both = T.F_LEVEL_MIN, T.F_LEVEL_MAX, T.F_LEVEL
        if k == "rarity" then
          min_id, max_id, both = T.F_RARITY_MIN, T.F_RARITY_MAX, T.F_RARITY
        end
        if a and z then
          out[#out + 1] = fmt(both, a, z)
        elseif a then
          out[#out + 1] = fmt(min_id, a)
        elseif z then
          out[#out + 1] = fmt(max_id, z)
        end
      elseif k == "not" then
        out[#out + 1] = fmt(MC.T.F_NOT, MC.Filter(inner(v)))
      elseif k == "any" then
        local alts = {}
        for alt in string.gmatch(v, "%b()") do
          alts[#alts + 1] = MC.Filter(inner(alt))
        end
        out[#out + 1] = table.concat(alts, text(MC.T.OR))
      end
    end
    if #out == 0 then
      return text(MC.T.ANYONE)
    end
    return table.concat(out, text(MC.T.AND))
  end

  -- the lines of condition `path` ("2", "2/1") of challenge i, indented by depth
  function MC.Lines(i, path, depth, lines)
    lines = lines or {}
    local kind, lo, hi, own, nsub, desc = call(MC.CMD.REQ, i, path)
    if type(kind) ~= "string" or kind == "" then
      return lines
    end
    local pad = string.rep("  ", depth or 0) .. "· "
    if type(own) == "number" and own ~= 0 and text(own) ~= "" then
      lines[#lines + 1] = pad .. text(own)
      return lines
    end
    local what = MC.Filter(desc)
    if kind == "every" then
      lines[#lines + 1] = pad .. fmt(MC.T.EVERY, what)
    elseif kind == "none" then
      lines[#lines + 1] = pad .. fmt(MC.T.NONE, what)
    elseif kind == "count" then
      if lo >= 0 and hi >= 0 then
        lines[#lines + 1] = pad .. fmt(MC.T.BETWEEN, lo, hi, what)
      elseif hi >= 0 then
        lines[#lines + 1] = pad .. fmt(MC.T.AT_MOST, hi, what)
      else
        lines[#lines + 1] = pad .. fmt(MC.T.AT_LEAST, math.max(lo, 0), what)
      end
    elseif kind == "any" or kind == "all" then
      lines[#lines + 1] = pad .. text(kind == "any" and MC.T.ANY_OF or MC.T.ALL_OF)
      for k = 1, nsub or 0 do
        MC.Lines(i, path .. "/" .. k, (depth or 0) + 1, lines)
      end
    end
    return lines
  end

  -- the line of required starter k (1-based) of challenge i
  function MC.RequiredLine(i, k)
    local c = MC.Info(i)
    local r = c and c.required[k]
    if r == nil then
      return nil
    end
    local pad = "· "
    if type(r.text) == "number" and r.text ~= 0 and text(r.text) ~= "" then
      return pad .. text(r.text)
    end
    local who = fmt(MC.T.F_CHARA, r.count)
    if #r.places == 0 then
      return pad .. fmt(MC.T.REQUIRED, who)
    end
    return pad .. fmt(MC.T.REQUIRED_PLACES, who, words(MC.T.POSITION, table.concat(r.places, ",")))
  end

  function MC.Refusal(game, tt, diff, cleared)
    local i = MC.Of(game, diff)
    if i == nil then
      return nil
    end
    local ok, failed, bad, ps = MC.Check(i, tt, cleared)
    local c = MC.Info(i)
    MC.Log("check", c and c.name or i, "game", game, ok and "ok" or "refused", "failed", table.concat(failed, ","), "players", #ps, "offenders", #bad)
    if ok or c == nil then
      return nil
    end
    local t = text(c.title)
    local lines = {fmt(MC.T.HEAD, t ~= "" and t or c.name)}
    local d = text(c.description)
    if d ~= "" then
      lines[#lines + 1] = d
    end
    lines[#lines + 1] = text(MC.T.REFUSED) .. (c.scope == "starters" and (" " .. text(MC.T.STARTERS)) or "")
    for _, k in ipairs(failed) do
      if k > c.nreq then
        lines[#lines + 1] = MC.RequiredLine(i, k - c.nreq)
      else
        MC.Lines(i, tostring(k), 0, lines)
      end
    end
    if #bad > 0 then
      local names = {}
      for n, k in ipairs(bad) do
        if n > MC.MAX_NAMES then
          break
        end
        local p = ps[k]
        local nm = p and call(MC.NAME, p.hdl)
        names[#names + 1] = type(nm) == "string" and nm or "?"
      end
      local s = table.concat(names, text(MC.T.AND))
      if #bad > MC.MAX_NAMES then
        s = fmt(MC.T.MORE, s, #bad - MC.MAX_NAMES)
      end
      lines[#lines + 1] = fmt(MC.T.OFFENDERS, s)
    end
    return table.concat(lines, "\n")
  end

  function MC.Gate(game, tt, diff, cleared)
    local msg = MC.Refusal(game, tt, diff, cleared)
    if msg == nil then
      return true
    end
    pcall(funcLuaCommand, MC.SE, MC.SE_NG)
    pcall(funcLuaCommand, MC.MSG_OPEN, msg, 0, 0, 0, 0, 0, false)
    return false
  end
end
