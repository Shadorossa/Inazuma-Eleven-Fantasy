-- `[[VRFW.GameRival]]` (the Lua build's mirror of the native team build, crates/plugins/team_engine/src/game_rival.rs): the rival team (col 1),
-- rival level (col 2), fixed own line-up (col 5) and its level (col 6) of a game's difficulty rows. Runs after route nodes, chains and level maps, before the drop tables and the team-select twins.
local T = require "lib/team_util"
local GR = {}

function GR.install(X)
  -- one declaration: the number of rows set, or nil, err
  local function game_rival(d, m)
    if d.team == nil and d.level == nil and d.own_team == nil and d.own_level == nil then return nil, "none of Team, Level, OwnTeam, OwnLevel" end
    if d.level ~= nil and (d.level < 1 or d.level > 999) then return nil, "Level " .. d.level .. ": 1-999" end
    if d.own_level ~= nil and (d.own_level < 1 or d.own_level > 999) then return nil, "OwnLevel " .. d.own_level .. ": 1-999" end
    local tid
    if d.team ~= nil then
      local t, te = X.team_ref(d.team, m)
      if t == nil then return nil, "Team: " .. te end
      tid = X.tc:id_of(t)
    end
    local oid
    if d.own_team ~= nil then
      local t, te = X.team_ref(d.own_team, m)
      if t == nil then return nil, "OwnTeam: " .. te end
      oid = X.tc:id_of(t)
    end
    local rows, e = X.game_rows(T.id(T.trim(d.game)))
    if not rows then return nil, e end
    local want
    if d.difficulties ~= nil and #d.difficulties > 0 then
      want = {}
      for _, x in ipairs(d.difficulties) do want[x] = true end
    end
    local g, SG = X.games_t, X.SG
    local n = 0
    for _, diff in ipairs(T.keys(rows)) do
      if want == nil or want[diff] then
        local i = rows[diff]
        if tid ~= nil then g:set(i, SG.D_TEAM, T.i32(tid)) end
        if d.level ~= nil then g:set(i, SG.D_LEVEL, d.level) end
        if oid ~= nil then g:set(i, SG.D_OWN_TEAM, T.i32(oid)) end
        if d.own_level ~= nil then g:set(i, SG.D_OWN_LEVEL, d.own_level) end
        n = n + 1
      end
    end
    if n == 0 then return nil, "none of its difficulty rows is listed" end
    g:touch()
    return n
  end

  function X.game_rivals(files)
    local applied, rows_set = 0, 0
    for _, f in ipairs(files) do
      for k0, d in ipairs(f.value.vrfw.GameRival or {}) do
        local what = f.file .. ": GameRival[" .. (k0 - 1) .. "] " .. tostring(d.game)
        local req = d.if_mod and T.trim(d.if_mod) or ""
        local active = req == ""
        for _, mo in ipairs(X.mods) do if mo.id == req then active = true break end end
        if not active then
          VRFW.log.info(what .. ": if_mod " .. req .. " is not active (skipped)")
        else
          local n, e = game_rival(d, f.mod)
          if n then
            applied = applied + 1
            rows_set = rows_set + n
          else
            VRFW.log.error(what .. ": " .. e .. " (skipped)")
          end
        end
      end
    end
    if applied > 0 then
      VRFW.log.info(string.format("GameRival: %d declaration(s), %d difficulty row(s) given their rival", applied, rows_set))
    end
  end
end

return GR
