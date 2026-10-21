-- `[[VRFW.TeamSelect]]` (the Lua build's mirror of the native team build, crates/plugins/team_engine/src/route.rs): game
-- `Twin` is a copy of board game `Game` (every difficulty row as built, after the level maps and the drop tables) whose
-- fixed line-up (col 5) is `OwnTeam`; the piece that plays `Game` gets a second event (the twin, after the game's own)
-- and `teamSelectType` 1, so the board opens the game's team picker («Equipo Llamarada» = the first event, «Equipo
-- Trueno» = the second). Clear bits stay the game's: a win in either game counts once.
local T = require "lib/team_util"
local TC = require "team/tc"
local R = require "team/route"
local TS = {}

local GAME_DIR = "data/common/gamedata/soccer/game/"
local D_OWN_TEAM = 5

function TS.install(X)
  local function one(m, d)
    local name, twin = T.trim(d.game or ""), T.trim(d.twin or "")
    local gid, twin_id = VRFW.crc32(name), VRFW.crc32(twin)
    local t, te = X.team_ref(d.own_team or "", m)
    if t == nil then return nil, "own_team: " .. tostring(te) end
    local own = X.tc:id_of(t)
    local g, ge = X.games()
    if not g then return nil, ge end
    local SG = X.SG
    local G = X.gcache()
    local game = G.by_id[gid]
    if not game then return nil, "game `" .. name .. "` is not in soccer_game_config" end
    if G.by_id[twin_id] then return nil, "game `" .. twin .. "` already exists" end
    -- the twin: every row of the game; the rows with a fixed line-up play `own_team`
    local rows, swapped = {}, 0
    for _, i in ipairs(X.grows(game)) do
      local en = g:entry(i)
      local o = TC.uint(en.values, D_OWN_TEAM)
      if o ~= nil and o ~= 0 and o ~= 0xFFFFFFFF then
        TC.set_int(en.values, D_OWN_TEAM, own)
        swapped = swapped + 1
      end
      rows[#rows + 1] = en
    end
    if swapped == 0 then return nil, "game `" .. name .. "` has no row with a fixed line-up (col 5): nothing to choose" end
    local info = g:entry(game.info)
    TC.set_int(info.values, SG.G_ID, twin_id)
    info.values[SG.G_NAME + 1] = twin
    local ok, e = X.add_game(info, rows)
    if not ok then return nil, e end
    X.touched.games = true
    local nf, e2 = VRFW.team.files_copy(GAME_DIR .. name .. "_", GAME_DIR .. twin .. "_", name, twin)
    if not nf then return nil, e2 end
    -- the piece: its event slice moved to the end + the twin's event (a copy of the game's), the team picker on
    local piece, pe = X.piece_of_game(gid)
    if piece == nil then return nil, pe end
    if piece == false then return nil, "no board piece plays `" .. name .. "`" end
    local r, re = X.route()
    if not r then return nil, re end
    local F, fe = R.fields(r)
    if not F then return nil, fe end
    local pi = X.piece_row(r, F.pl, F.p_id, piece)
    if pi == nil then return nil, "piece gone" end
    local a, b = r:tuple(F.pl, pi, F.p_event)
    if a == nil then a, b = 0, 0 end
    local k
    for j = a, a + b - 1 do
      if r:u32(F.el, j, F.e_game) == gid then k = j break end
    end
    if k == nil then return nil, "the game's event row is gone" end
    local ev = r:copy(F.el, k)
    r:set_u32(-1, ev, F.e_game, twin_id)
    local start = r:len(F.el)
    r:extend_copy(F.el, a, a + b)
    r:push(F.el, ev)
    r:set_tuple(F.pl, pi, F.p_event, start, b + 1)
    local picker = "no teamSelectType field (older table): no picker"
    local c = r:field(F.pl, "teamSelectType")
    if c then
      if (r:u32(F.pl, pi, c) or 0) == 0 then r:set_u32(F.pl, pi, c, 1) end
      picker = "teamSelectType 1"
    end
    X.touched.route = true
    return string.format("game %s (%s): %d row(s), %d with the line-up %s; piece %s plays %d game(s), %s", twin, T.hex(twin_id),
      #rows, swapped, T.trim(d.own_team or ""), T.hex(piece), b + 1, picker)
  end

  function X.team_selects(files)
    for _, f in ipairs(files) do
      for _, d in ipairs(f.value.vrfw.TeamSelect or {}) do
        local what = f.file .. ": team_select `" .. T.trim(d.twin or "") .. "`"
        local note, e = one(f.mod, d)
        if note then VRFW.log.info(what .. ": " .. note) else VRFW.log.error(what .. ": " .. tostring(e) .. " (skipped)") end
      end
    end
  end
end

return TS
