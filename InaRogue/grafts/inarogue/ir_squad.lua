-- ---- the squad = the retail "Plantilla de equipo" in the INAROGUE save (docs/game/modes/inarogue.md §16) ------------
-- Inserted into evt_inarogue_menu.lua by research/scripts/inarogue_build.py (marker @DOCK@). INAROGUE lives in its own
-- save (slot 4), so the game's own team dock of that save is the run's squad screen (formation, bench, coach,
-- managers, captain, tactics, kit, Ficha, Habilidades, Banco: all retail). The roguelite rules sit on top of it
-- (research/grafts/rogue_dock: only INAROGUE players, points before the run, no team switching) and here:
--   run start: every character of the INAROGUE save except the avatar is deleted (full delete by handle 0x70DBD779:
--       every run starts at Lv 5 and no retail player stays), then every INAROGUE bank player (at most DK.MAX) is
--       created at Lv 5 (CMND_ADD_PARTY, no team set, tag 0x10000000) = the club roster of the retail Banco; a first
--       eleven that fits the points is placed (the user changes it in the dock);
--   the dock opens through the title's own "Mi equipo" request (INAROGUE closes with result 9, the title sends
--       1438851263, title_main reserves soccer_team_dock_menu as in retail); byte flag 606 remembers why (1 run start,
--       2 during the run, 3 before a match) and the dock block adds 10 when it really opened;
--   back from the dock (the title reopens INAROGUE): the VS team is read (positions 0-18 + coach 19) and checked
--       (11 starters, only INAROGUE players, the points before the run). Run start: TEAM_SET per slot + TEAM_COMMIT,
--       the run gets each position (CMND_EVT_RL_RUN_SET_SLOT) and every roster player NOT picked is deleted, so during
--       the run the dock and its Banco hold only the run's players. During the run: the positions are written back.
local DK = {
  DELETE = 1893455737,         -- 0x70DBD779 (hdl): full delete by handle (§12.10 engine facts)
  CHECK_ATTR = 29506568,
  GET_VS = @crc:CMND_GET_VS_USE_TEAM_SET@,         -- CMND_GET_VS_USE_TEAM_SET
  -- the retail SwapChara pair (soccer_formation_menu_inc; docs/game/modes/inarogue.md §26): 1730898405 only CHECKS a
  -- place (nie.exe 0xBEDD50 writes nothing: every earlier DK.PLACE call placed nobody), 193693077 places / moves and
  -- keeps the 11v11 (team 0) and 5v5 (team 1) teams of the dock linked, exactly like the retail «Plantilla 01»
  CHECK = 1730898405,          -- (hdl, set, pos, fromSet, team) -> ok, code
  MOVE = 193693077,            -- (toSet, pos, fromSet, hdl, team); fromSet 16 = from the bank, toSet 16 = to the bank
  POS_IDX = 1721292418,        -- (set, team, posNo) -> ok, member index
  IDX_HDL = 1720957768,        -- (set, team, index, 0) -> ok, handle (index 19 = coach)
  CHARA = 1131797651,          -- (hdl, 4) -> chara_param id
  RL_CHARA = @crc:CMND_EVT_RL_CHARA@,             -- (param) -> tier, cost, inPool, stat, card, element, position (1 GK)
  BANK_COUNT = @crc:CMND_EVT_RL_BANK_COUNT@,      -- () -> count, capacity, slot, budget, rosterLimit (nil = DK.MAX)
  BANK_GET = @crc:CMND_EVT_RL_BANK_GET@,          -- (i, sort) -> ok, uid, param, ...
  PICK_STATE = @crc:CMND_EVT_RL_PICK_STATE@,      -- (uid) -> picked, starter cost (fragments applied)
  TEAM_RESET = @crc:CMND_EVT_RL_TEAM_RESET@,      -- () -> budget
  TEAM_SET = 864556674,          -- (slot, uid) -> code, spent, budget
  TEAM_INFO = 2095182175,        -- () -> starters, bench, managers, coach, spent, budget, form, ready
  TEAM_COMMIT = 3011761431,    -- (seed) -> code, seed
  SET_SLOT = @crc:CMND_EVT_RL_RUN_SET_SLOT@,      -- (slot, uid, hdl) -> code
  GET_BYTE = @crc:CMND_GET_GLOBAL_BYTE_FLAG@, SET_BYTE = @crc:CMND_SET_GLOBAL_BYTE_FLAG@,
  F_DOCK = 4108793520,  -- byte 606 (the unused "layer" byte of §5): why the dock was opened, +10 once it opened
  R_START = 1, R_RUN = 2, R_MATCH = 3,
  R_PLAYED = 23,               -- byte 606: the pre-match dock reserved the match and closed (rogue_dock, §20 M3)
  R_EDIT = 4,                  -- «Plantilla de equipo» row of the INAROGUE menu outside a run (§21): the team persists
  ORIGIN_MAP = {[3] = true, [5] = true},   -- requests opened from the route map / VS preview (the rest: the menu)
  R_PLAY = 5,                  -- §28: «Empezar partido» in the VS preview: the dock opens black and launches the reserved
                               -- match at once (rogue_dock); a team that cannot play falls back to the pre-match dock
  GET_INFO = @crc:CMND_GET_TEAM_SET_INFO@, SET_INFO = @crc:CMND_SET_TEAM_SET_INFO@,   -- CMND_GET / SET_TEAM_SET_INFO (set, team, field, ...)
  UNIFORM = @crc:CMND_EVT_TEAM_UNIFORM@,        -- CMND_EVT_TEAM_UNIFORM (set, team) -> ok, uniformId (away_kit)
  ADD_ITEM = @crc:CMND_ADD_ITEM_ONLY@,       -- CMND_ADD_ITEM_ONLY (item, n)
  -- the generic look of the INAROGUE team (§21): retail «Equipación estándar» (uni_u119101: item 0x9C3F19FC, uniform
  -- 0x9EDB7BFC) and the retail default club emblem em900001 (ball on a shield, no real team's). Given only when the
  -- team has none (a kit / emblem the user picked in the dock stays)
  KIT_ITEM = 2621380092, KIT_UNIFORM = 2665184252, EMBLEM = 3485768072, NAME = "INAROGUE",
  TT = {   -- texts of the 9 languages (research/scripts/rogue_play_text_build.py); the literal is the fallback
    SAVED = {1221739594 --[[evt_ir_team_saved]]},
    FIX = {2464199169 --[[evt_ir_team_fix]]},
    ASK_OPEN = {3589463690 --[[evt_ir_team_ask_open]]},
  },
  AVATAR = 4096,               -- attribute 0x1000: the avatar (kept: the field party needs one member)
  MAX = 1000,                  -- most bank players created for the run start (the save holds ~5,300)
  -- the run team's texts (text\rows\rogue_screens.toml)
  T_NO_PARTY = {3098790352 --[[InaRogue.dock.no_party]]},
  T_NO_PLAYERS = {2329170672 --[[InaRogue.dock.no_players]]},
  T_DONE = {1558461509 --[[InaRogue.dock.done]]},
  T_ROSTER = {790733229 --[[InaRogue.dock.roster]]},
  T_NOT_OPENED = {1558425486 --[[InaRogue.dock.not_opened]]},
  KEY_TRY = 835590157,         -- crc32("evt_inarogue_dock_try"): parameter set by DK.Open (memory only, never saved)
  T_FEW = {3309086172 --[[InaRogue.dock.few]]},
  T_FOREIGN = {2830885825 --[[InaRogue.dock.foreign]]},
  T_OVER = {4164255671 --[[InaRogue.dock.over]]},
  T_BACK = {554114521 --[[InaRogue.dock.back]]},
  T_ASK_START_COACH = {1719593204 --[[InaRogue.dock.ask_start_coach]]},
  T_ASK_START = {2603140556 --[[InaRogue.dock.ask_start]]},
  T_CANCEL = {428788006 --[[InaRogue.dock.cancel]]},
  T_ERROR = {438549202 --[[InaRogue.dock.error]]},
}

local function DK_Byte(v)
  if v == nil then
    return Int(Call(DK.GET_BYTE, DK.F_DOCK))
  end
  Call(DK.SET_BYTE, DK.F_DOCK, v)
  return v
end

-- every owned handle of both lists (normal / story) of the INAROGUE save
local function DK_Handles()
  local out = {}
  for bank = 0, 1 do
    local n = Int(Call(RL_PARTY_COUNT, bank))
    for i = 0, n - 1 do
      local h = Int(Call(RL_PARTY_HDL, bank, i))
      if h ~= 0 then
        table.insert(out, h)
      end
    end
  end
  return out
end

-- the INAROGUE save keeps only the avatar (and `keep[hdl]`)
local function DK_Purge(keep)
  local deleted, kept = 0, 0
  for _, h in ipairs(DK_Handles()) do
    if Call(DK.CHECK_ATTR, h, DK.AVATAR) == true or (keep ~= nil and keep[h]) then
      kept = kept + 1
    else
      Call(DK.DELETE, h)
      deleted = deleted + 1
      if deleted % 20 == 0 then
        coroutine.yield()
      end
    end
  end
  local left = #DK_Handles()
  Log("purge: deleted", deleted, "kept", kept, "owned now", left)
  return deleted
end

-- a run player: InaRogue's one creation path (lua\_all\inarogue_run_players.lua: Lv 5, no team set, tagged, «Sin rol»)
local function DK_Create(param)
  local h, answer = InaRogue_RunPlayers.Create(param)
  if h == 0 then
    Log("create", param, "ADD_PARTY FAILED", tostring(answer))
  end
  return h
end

-- handle at position `pos` of team `team` (0 = 11v11, 1 = 5v5) of `set` (19 = the coach, by index); 0 = empty
local function DK_HdlAt(set, team, pos)
  local idx = pos
  if pos ~= 19 then
    local ok, i = Call(DK.POS_IDX, set, team, pos)
    if ok ~= true or type(i) ~= "number" then
      return 0
    end
    idx = i
  end
  local ok2, h = Call(DK.IDX_HDL, set, team, idx, 0)
  return (ok2 == true and type(h) == "number") and h or 0
end

-- The retail place (SwapChara): the check, then the place / move. `from` = 16 (a player in no team of the set: the
-- bank) or `set` (a player of the dock: a move inside it). What the engine does with the OTHER team of the dock (the
-- retail link, docs/game/modes/inarogue.md §26): a player placed from the bank joins both teams (the other one at its
-- lowest free position), one that replaces somebody takes his place in both teams, a move inside the dock only
-- rearranges `team`, and a player in only one team is added to the other one. true = he is at `pos` now.
local function DK_Place(hdl, set, pos, team, from)
  from = from or 16
  local ok, code = Call(DK.CHECK, hdl, set, pos, from, team)
  if ok ~= true then
    Log("place refused by the retail check: hdl", hdl, "set", set, "pos", pos, "team", team, "from", from, "code", tostring(code))
    return false
  end
  Call(DK.MOVE, set, pos, from, hdl, team)
  local got = DK_HdlAt(set, team, pos)
  if got ~= hdl then
    Log("place did not take: hdl", hdl, "set", set, "pos", pos, "team", team, "from", from, "now", got)
    return false
  end
  return true
end

-- positions 0-18 (+ the coach, index 19) of both teams: {[team] = {pos -> hdl}, where = {hdl -> pos}}
local function DK_Teams(set)
  local T = {[0] = {pos = {}, where = {}}, [1] = {pos = {}, where = {}}}
  for team = 0, 1 do
    for pos = 0, 19 do
      local h = DK_HdlAt(set, team, pos)
      if h ~= 0 then
        T[team].pos[pos] = h
        T[team].where[h] = pos
      end
    end
  end
  return T
end

-- first free position of `team` in [a, b] (nil = none)
local function DK_Free(T, team, a, b)
  for p = a, b do
    if T[team].pos[p] == nil then
      return p
    end
  end
  return nil
end

-- The 11v11 and the 5v5 team of the INAROGUE dock are ONE linked roster, as the retail «Plantilla 01»
-- (docs/game/modes/inarogue.md §26). Every INAROGUE edit already goes through the retail place command, which links
-- them; this pass repairs what is left and chooses the five the retail way:
--   1. the same players in both teams: a member of one team only is added to the other one (retail same-set place,
--      at the lowest free position; managers stay managers), a 5v5-only player with no room in the 11v11 goes back to
--      the bank;
--   2. the five (5v5 positions 0-4) is never left with a hole while the 5v5 bench has players. Retail gives a player
--      added to the 11v11 the lowest free 5v5 position but never position 0 (the goalkeeper) of an empty team (nie.exe
--      0xDA1790 swaps with the entry it has just written), so the auto-copy of a dock has no goalkeeper (seen in slot 2
--      set 1 and in the INAROGUE save of 29/09: 5v5 positions 1-11, 0 empty). The goal hole takes the 11v11
--      goalkeeper (from the bench or from the five, whose place is refilled next); the other holes take 5v5 bench
--      players, the 11v11 starters first in 11v11 position order, then the rest by 5v5 position. With the retail add
--      order the five is then the 11v11 goalkeeper + the first four 11v11 outfield players added (11v11 positions 1-4
--      for the automatic eleven). A five the user arranged (no hole) is never changed.
-- -> number of changes
local function DK_Link5(set)
  if type(set) ~= "number" or set < 0 or set >= 16 then
    return 0
  end
  local T = DK_Teams(set)
  local n = 0
  for h, p in pairs(T[0].where) do
    if p ~= 19 and T[1].where[h] == nil then
      local q = p >= 16 and DK_Free(T, 1, 16, 18) or DK_Free(T, 1, 0, 15)
      if q ~= nil and DK_Place(h, set, q, 1, set) then
        T[1].pos[q], T[1].where[h] = h, q
        n = n + 1
        Log("link: 11v11 pos", p, "hdl", h, "-> 5v5 pos", q)
      end
    end
  end
  for h, p in pairs(T[1].where) do
    if p ~= 19 and T[0].where[h] == nil then
      local q = p >= 16 and DK_Free(T, 0, 16, 18) or DK_Free(T, 0, 0, 15)
      if q ~= nil and DK_Place(h, set, q, 0, set) then
        T[0].pos[q], T[0].where[h] = h, q
        Log("link: 5v5 pos", p, "hdl", h, "-> 11v11 pos", q)
      else
        Call(DK.MOVE, 16, p, set, h, 1)
        T[1].pos[p], T[1].where[h] = nil, nil
        Log("link: 5v5-only hdl", h, "has no room in the 11v11: back to the bank")
      end
      n = n + 1
    end
  end
  for hole = 0, 4 do
    if T[1].pos[hole] == nil then
      local best, rank = nil, nil
      for p = 1, 15 do
        local h = T[1].pos[p]
        local p0 = h ~= nil and T[0].where[h] or nil
        -- the goal: the 11v11 goalkeeper, even from the five (his outfield place is then refilled: holes go 0 -> 4)
        if h ~= nil and (p >= 5 or (hole == 0 and p0 == 0)) then
          local r = 1000 + p                                  -- any other 5v5 bench player, by 5v5 position
          if hole == 0 and p0 == 0 then
            r = 0                                             -- the goalkeeper hole: the 11v11 goalkeeper
          elseif p0 ~= nil and p0 >= 1 and p0 <= 10 then
            r = 100 + p0                                      -- an 11v11 starter, in 11v11 position order
          end
          if rank == nil or r < rank then
            best, rank = h, r
          end
        end
      end
      if best ~= nil then
        local from = T[1].where[best]
        if DK_Place(best, set, hole, 1, set) then
          T[1].pos[from], T[1].pos[hole], T[1].where[best] = nil, best, hole
          n = n + 1
          Log("link: 5v5 hole", hole, "<- 5v5 pos", from, "hdl", best, "11v11 pos", tostring(T[0].where[best]))
        end
      end
    end
  end
  if n > 0 then
    Log("link: 11v11 / 5v5 of set", set, "linked,", n, "change(s)")
  end
  return n
end

-- most bank players created in the INAROGUE save: the bank's own limit ([rogue] debug_all_players), else DK.MAX
local function DK_RosterLimit()
  local limit = select(5, Call(DK.BANK_COUNT))
  if type(limit) == "number" and limit > 0 then
    return limit
  end
  return DK.MAX
end

-- chara_param id -> {uid, cost} of the INAROGUE bank
local function DK_BankMap()
  local m, list = {}, {}
  local n = Int(Call(DK.BANK_COUNT))
  for i = 0, n - 1 do
    local ok, uid, param = Call(DK.BANK_GET, i, 0)
    if ok == true and type(param) == "number" then
      local _, cost = Call(DK.PICK_STATE, uid)
      local e = {uid = Int(uid), param = param, cost = Int(cost)}
      m[param] = e
      table.insert(list, e)
    end
    if i % 200 == 199 then
      coroutine.yield()
    end
  end
  return m, list
end

-- the VS team of the INAROGUE save: positions 0-19 -> {hdl, uid, cost} (uid 0 = not an INAROGUE player)
local function DK_ReadTeam(vs, team, map)
  map = map or DK_BankMap()
  local t = {slots = {}, st = 0, be = 0, ma = 0, co = 0, spent = 0, foreign = 0, n = 0}
  for pos = 0, 19 do
    local idx = pos
    if pos ~= 19 then
      local ok, i = Call(DK.POS_IDX, vs, team or 0, pos)
      idx = (ok == true and type(i) == "number") and i or -1
    end
    local h = 0
    if idx >= 0 then
      local ok2, hh = Call(DK.IDX_HDL, vs, team or 0, idx, 0)
      h = (ok2 == true and type(hh) == "number") and hh or 0
    end
    if h ~= 0 then
      local e = map[Call(DK.CHARA, h, 4) or 0]
      t.slots[pos] = {hdl = h, uid = e and e.uid or 0, cost = e and e.cost or 0}
      t.n = t.n + 1
      if e == nil then
        t.foreign = t.foreign + 1
      else
        t.spent = t.spent + e.cost
      end
      if pos <= 10 then
        t.st = t.st + 1
      elseif pos <= 15 then
        t.be = t.be + 1
      elseif pos <= 18 then
        t.ma = t.ma + 1
      else
        t.co = 1
      end
    end
  end
  return t
end

-- a first eleven that fits the points (the user changes it in the dock): the cheapest goalkeeper, then the cheapest
-- players, defenders first, then midfielders, then forwards (positions 1-10 of the formation)
local function DK_AutoFill(made, vs, budget)
  local gk, field = nil, {}
  for _, e in ipairs(made) do
    local pos = select(7, Call(DK.RL_CHARA, e.param))
    e.role = Int(pos)
    if e.role == 1 then
      if gk == nil or e.cost < gk.cost then
        if gk ~= nil then
          table.insert(field, gk)
        end
        gk = e
      else
        table.insert(field, e)
      end
    else
      table.insert(field, e)
    end
  end
  table.sort(field, function(a, b)
    if a.cost ~= b.cost then
      return a.cost < b.cost
    end
    return a.uid < b.uid
  end)
  local spent, pick = 0, {}
  if gk ~= nil and gk.cost <= budget then
    spent = gk.cost
  else
    gk = nil
  end
  for _, e in ipairs(field) do
    if #pick >= (gk and 10 or 11) then
      break
    end
    if spent + e.cost <= budget then
      spent = spent + e.cost
      table.insert(pick, e)
    end
  end
  local order = {[4] = 1, [3] = 2, [2] = 3}   -- DF, MF, FW
  table.sort(pick, function(a, b)
    return (order[a.role] or 4) < (order[b.role] or 4)
  end)
  if gk == nil and #pick > 0 then
    gk = table.remove(pick, 1)
  end
  -- retail place, 11v11 position by position: the engine adds each player to the 5v5 team too (§26)
  local placed = 0
  for pos, e in ipairs(gk and {gk, table.unpack(pick)} or {}) do
    local ok = DK_Place(e.hdl, vs, pos - 1, 0)
    placed = placed + (ok and 1 or 0)
    Log("auto eleven pos", pos - 1, "uid", e.uid, "cost", e.cost, "role", e.role, "placed", tostring(ok))
  end
  Log("auto eleven:", placed, "placed,", spent, "of", budget, "points")
  DK_Link5(vs)
end

-- run start: the INAROGUE save gets the whole INAROGUE bank as its club roster (Lv 5), and a first eleven
function DK.Roster()
  if not SL.rogue then
    return false
  end
  if Int(Call(RL_PARTY_COUNT, 0)) < 0 then
    Log("roster refused: CMND_EVT_RL_PARTY_COUNT unavailable")
    Message(T(DK.T_NO_PARTY))
    return false
  end
  local deleted = DK_Purge()
  local _, list = DK_BankMap()
  local limit = DK_RosterLimit()
  local made = {}
  for i, e in ipairs(list) do
    if i > limit then
      Log("roster: bank has", #list, "players, only the first", limit, "are created")
      break
    end
    e.hdl = DK_Create(e.param)
    if e.hdl ~= 0 then
      table.insert(made, e)
    end
    if i % 10 == 0 then
      coroutine.yield()
    end
  end
  local vs = Int(Call(DK.GET_VS))
  local budget = Int(Call(RL_STARTER))
  Log("roster: created", #made, "of", #list, "bank players, purged", deleted, "vs set", vs, "budget", budget)
  if #made == 0 then
    Message(T(DK.T_NO_PLAYERS))
    return false
  end
  DK_AutoFill(made, vs, budget)
  Message(T(DK.T_ROSTER, #made, budget))
  return true
end

-- open the retail "Plantilla de equipo" (result 9: the title sends the "Mi equipo" request)
function DK.Open(why)
  DK_Byte(why)
  Call(C.P_SET, DK.KEY_TRY, 0, why, 1)
  Log("open the retail team dock, request", why)
  IRM_FadeClose(9)
end

-- () -> the pending request (0 none; 1-5 asked but the dock never opened; 11-15 back from the dock)
function DK.Pending()
  if not SL.rogue then
    return 0
  end
  return DK_Byte()
end

-- need11 = false: during a run the 11 starters are not required here (the pre-match dock checks the starters of the
-- match's own kind: 5 for a pachanga, 11 for a match; a run with a 5-player team could not go back to the map before)
local function DK_Problem(t, budget_on, need11)
  if t.foreign > 0 then
    return T(DK.T_FOREIGN, t.foreign)
  elseif need11 ~= false and t.st < 11 then
    return T(DK.T_FEW, t.st)
  elseif budget_on and t.spent > t.budget then
    return T(DK.T_OVER, t.spent, t.budget)
  end
  return nil
end

-- §21: the generic look of the INAROGUE team (teams 0 and 1 of the VS dock) where it has none: name, emblem, kit
function DK.Dress(vs)
  for team = 0, 1 do
    local okN, name = Call(DK.GET_INFO, vs, team, 6)
    if okN ~= true or type(name) ~= "string" or name == "" then
      Call(DK.SET_INFO, vs, team, 0, DK.NAME)
    end
    local okE, em = Call(DK.GET_INFO, vs, team, 5, 0)
    if okE ~= true or type(em) ~= "number" or em == 0 then
      Call(DK.SET_INFO, vs, team, 1, DK.EMBLEM)
      local _, em2 = Call(DK.GET_INFO, vs, team, 5, 0)
      Log("dress: team", team, "emblem", tostring(em), "->", tostring(em2))
    end
    local okU, uni = Call(DK.UNIFORM, vs, team)
    if okU == true and uni == 0 then
      Call(DK.SET_INFO, vs, team, 5, DK.KIT_ITEM)          -- field 5: kit item id -> owned handle (away-kit.md §1.2)
      local _, u2 = Call(DK.UNIFORM, vs, team)
      if u2 ~= DK.KIT_UNIFORM then
        Call(DK.ADD_ITEM, DK.KIT_ITEM, 1)                  -- not owned yet in the INAROGUE save: give it, set again
        Call(DK.SET_INFO, vs, team, 5, DK.KIT_ITEM)
        _, u2 = Call(DK.UNIFORM, vs, team)
      end
      if u2 ~= DK.KIT_UNIFORM then
        -- the retail path did not take it (28/09 21:15: kit 0 -> 0): the loader writes the generic kit's uniform id
        -- on a kit-less team of the INAROGUE save (away_kit rogue_generic_allowed); the away kit follows the home one
        local okw, u3 = Call(DK.UNIFORM, vs, team, DK.KIT_UNIFORM)
        Log("dress: team", team, "kit written by the loader", tostring(okw), tostring(u3))
        u2 = u3
      end
      Log("dress: team", team, "kit", tostring(uni), "->", tostring(u2))
    end
  end
end

-- §21: the INAROGUE team persists in the INAROGUE save between runs (the VS dock). Outside a run every bank player
-- that has no character yet is created at Lv 5 (the club roster the retail «Banco» lists); characters of the team and
-- of the roster are KEPT; anything that is not an INAROGUE bank player (and not the avatar) is deleted. An empty team
-- gets the automatic first eleven. Then the generic look where missing.
-- team_only = true (a run starts at once): a team that can play is used as it is and the roster is not created (the
-- run start keeps only the team, so a full roster would be created and deleted again for nothing)
function DK.Prepare(team_only)
  if not SL.rogue then
    return false
  end
  if Int(Call(RL_PARTY_COUNT, 0)) < 0 then
    Log("prepare refused: CMND_EVT_RL_PARTY_COUNT unavailable")
    Message(T(DK.T_NO_PARTY))
    return false
  end
  local map, list = DK_BankMap()
  local have, deleted = {}, 0
  for _, h in ipairs(DK_Handles()) do
    local param = Call(DK.CHARA, h, 4)
    if map[param] ~= nil and have[param] == nil then
      have[param] = h
    elseif Call(DK.CHECK_ATTR, h, DK.AVATAR) ~= true then
      Call(DK.DELETE, h)
      deleted = deleted + 1
    end
  end
  if team_only then
    local vs0 = Int(Call(DK.GET_VS))
    local t0 = DK_ReadTeam(vs0, 0, map)
    t0.budget = Int(Call(RL_STARTER))
    if t0.n > 0 and DK_Problem(t0, true) == nil then
      Log("prepare: team of", t0.n, "members ready, roster not created, deleted", deleted, "vs set", vs0)
      DK_Link5(vs0)
      DK.Dress(vs0)
      return true
    end
  end
  local limit = DK_RosterLimit()
  local made = {}
  for i, e in ipairs(list) do
    if i > limit then
      break
    end
    e.hdl = have[e.param]
    if e.hdl == nil then
      e.hdl = DK_Create(e.param)
      if i % 10 == 0 then
        coroutine.yield()
      end
    end
    if e.hdl ~= 0 then
      table.insert(made, e)
    end
  end
  local vs = Int(Call(DK.GET_VS))
  local t = DK_ReadTeam(vs, 0, map)
  Log("prepare: roster", #made, "of", #list, "bank players, team", t.n, "members, deleted", deleted, "vs set", vs)
  if #made == 0 then
    Message(T(DK.T_NO_PLAYERS))
    return false
  end
  if t.n == 0 then
    DK_AutoFill(made, vs, Int(Call(RL_STARTER)))
  else
    DK_Link5(vs)                           -- §26: a team of an earlier build (5v5 without goalkeeper, 5v5-only players)
  end
  DK.Dress(vs)
  return true
end

-- the INAROGUE menu row «Plantilla de equipo» (§21): outside a run, the persistent team; during a run, the run's
function DK.Edit()
  if Call(RL_RUN_INFO) == true then
    if DK.Materialise() then
      DK.Open(DK.R_RUN)
    end
    return
  end
  if DK.Prepare() then
    DK.Open(DK.R_EDIT)
  end
end

-- Lv 5 again (every run starts at Lv 5): each team member is replaced by a new character of the same player with the
-- retail place from the bank onto his 11v11 position. The engine replaces him in BOTH teams at his own entries (retail
-- link, §26), so the 11v11 position and the 5v5 position are both kept. Only then is the old character (levels of an
-- earlier run, now in no team) deleted. If the engine did not take the new one, the old one stays (no player lost).
local function DK_Rebirth(vs, t)
  local done, kept = 0, 0
  for pos = 0, 19 do
    local s = t.slots[pos]
    if s ~= nil then
      local old = s.hdl
      local param = Call(DK.CHARA, old, 4)
      local h = type(param) == "number" and DK_Create(param) or 0
      if h ~= 0 and DK_Place(h, vs, pos, 0) and DK_HdlAt(vs, 0, pos) == h then
        Call(RL_ROLE_CARRY, old, h)        -- the role the user chose in the squad survives the Lv 5 rebirth
        local T = DK_Teams(vs)
        if T[0].where[old] == nil and T[1].where[old] == nil then
          Call(DK.DELETE, old)
        else
          Log("rebirth pos", pos, "old hdl", old, "still in a team after the replace: not deleted")
        end
        s.hdl = h
        done = done + 1
      else
        if h ~= 0 then
          Call(DK.DELETE, h)                 -- the new character is in no team: nothing else refers to it
        end
        kept = kept + 1
        Log("rebirth pos", pos, "param", tostring(param), "not replaced: the old character stays")
      end
    end
    if pos % 4 == 3 then
      coroutine.yield()
    end
  end
  Log("rebirth: team at Lv 5 again,", done, "replaced,", kept, "kept")
end

-- the run starts with team t (read from the VS dock, checked): the loader squad + seed, Lv 5 characters, the run's
-- positions, the roster players not in the team leave the save, the 5v5 five completed, the generic look. true = ok
function DK.StartRun(t, vs)
  Call(DK.TEAM_RESET)
  for pos = 0, 19 do
    local s = t.slots[pos]
    if s ~= nil then
      local c = Int(Call(DK.TEAM_SET, pos, s.uid))
      if c ~= 0 then
        Log("TEAM_SET pos", pos, "uid", s.uid, "code", c)
      end
    end
  end
  local code, seed = Call(DK.TEAM_COMMIT, 0)
  code = Int(code)
  Log("team commit code", code, "seed", tostring(seed))
  if code ~= 0 then
    Message(T(DK.T_ERROR, code))
    return false
  end
  DK_Rebirth(vs, t)
  local keep = {}
  for pos = 0, 19 do
    local s = t.slots[pos]
    local c = Int(Call(DK.SET_SLOT, pos, s and s.uid or 0, s and s.hdl or 0))
    if c ~= 0 then
      Log("RUN_SET_SLOT pos", pos, "code", c)
    end
    if s ~= nil then
      keep[s.hdl] = true
    end
  end
  local left = DK_Purge(keep)
  DK_Link5(vs)
  DK.Dress(vs)
  Log("team ready:", t.n, "players in the run,", left, "of the bank left out")   -- §28: no window; the map opens next
  return true
end

-- Empezar with no run (§21): the persistent team is used as it is when it is valid (11 starters, only INAROGUE
-- players, within the points); otherwise the reason and the dock. true = the run started (the map opens next)
function DK.QuickStart()
  if not DK.Prepare(true) then
    return false
  end
  local vs = Int(Call(DK.GET_VS))
  local t = DK_ReadTeam(vs, 0)
  t.budget = Int(Call(RL_STARTER))
  local problem = DK_Problem(t, true)
  Log("quick start: starters", t.st, "points", t.spent, "/", t.budget, "problem", tostring(problem))
  if problem ~= nil then
    Message(T(DK.TT.FIX, problem))
    DK.Open(DK.R_START)
    return false
  end
  -- §28 (Nacho, 30/09: «Nueva partida» starts at once): no «¿Empezar con este equipo?» window; the team is edited
  -- beforehand in «Plantilla de equipo». DK.TT.ASK_OPEN stays for the text builder (rogue_play_text_build.py).
  local _ = DK.TT.ASK_OPEN
  return DK.StartRun(t, vs)
end

-- byte 606 is kept in the INAROGUE save: a request 1-5 that no DK.Open of this game session set (no KEY_TRY) was
-- left by an earlier session that ended before the dock opened; it is cleared without a message
function DK.DropStale()
  local p = DK.Pending()
  if p >= 1 and p <= 5 and not Call(P_HAS, DK.KEY_TRY) then
    Log("stale dock request", p, "from the save cleared (not sent in this session)")
    DK_Byte(0)
  end
end

-- back from the dock. -> "map", "match", "closed" (the dock opens again) or nil (stay in the INAROGUE menu)
function DK.Finish()
  local p = DK.Pending()
  DK_Byte(0)
  Call(C.P_CLEAR, DK.KEY_TRY)
  if p >= 1 and p <= 5 then
    Log("dock request", p, "but the dock never opened")
    Message(T(DK.T_NOT_OPENED))
    return nil
  end
  local why = p - 10
  if why < 1 or why > 5 then
    return nil
  end
  local vs = Int(Call(DK.GET_VS))
  DK_Link5(vs)                             -- §26: whatever was edited in the dock, the 5v5 stays the 11v11's roster
  local t = DK_ReadTeam(vs, 0)
  local exists = Call(RL_RUN_INFO) == true
  local start = why == DK.R_START and not exists
  t.budget = Int(Call(RL_STARTER))
  Log("back from the dock: request", why, "run", tostring(exists), "starters", t.st, "bench", t.be, "managers", t.ma,
      "coach", t.co, "points", t.spent, "/", t.budget, "foreign", t.foreign)
  if why == DK.R_EDIT and not exists then
    -- the persistent team was edited (§21): saved with the slot-4 save by the dock's Back; say how it stands
    DK.Dress(vs)
    local problem = DK_Problem(t, true)
    if problem ~= nil then
      if Ask(T(DK.T_BACK, T(DK.TT.FIX, problem))) then
        DK.Open(why)
        return "closed"
      end
      return nil
    end
    Message(T(DK.TT.SAVED, t.st, t.be, t.spent, t.budget))
    return nil
  end
  local problem = DK_Problem(t, start, start)
  if problem ~= nil then
    if Ask(T(DK.T_BACK, problem)) then
      DK.Open(why)
      return "closed"
    end
    if start then
      Message(T(DK.T_CANCEL))
    end
    return nil
  end
  if start then
    if not Ask(T(t.co == 1 and DK.T_ASK_START_COACH or DK.T_ASK_START, t.st, t.be, t.ma, t.spent, t.budget)) then
      if Ask(T(DK.T_BACK, "")) then
        DK.Open(why)
        return "closed"
      end
      Message(T(DK.T_CANCEL))
      return nil
    end
    if not DK.StartRun(t, vs) then
      return nil
    end
    return "map"
  end
  -- the run gets every dock position (rewards and the Fichaje bench slot follow the dock)
  local keep = {}
  for pos = 0, 19 do
    local s = t.slots[pos]
    local c = Int(Call(DK.SET_SLOT, pos, s and s.uid or 0, s and s.hdl or 0))
    if c ~= 0 then
      Log("RUN_SET_SLOT pos", pos, "code", c)
    end
    if s ~= nil then
      keep[s.hdl] = true
    end
  end
  -- §28 (Nacho, 30/09): back to where the dock was opened from. The request byte is the origin: the «Plantilla de
  -- equipo» row of the INAROGUE menu (request 2 during a run) returns to that menu; the pre-match dock of the map /
  -- VS preview (3, 5: being here means «No») returns to the map, where the node is still pending
  return DK.ORIGIN_MAP[why] and "map" or nil
end

-- the pre-match dock reserved the match (byte 606 = 23): true once, then the byte is cleared
function DK.TakePlayed()
  if SL.rogue and DK_Byte() == DK.R_PLAYED then
    DK_Byte(0)
    return true
  end
  return false
end

-- The run's players as real characters of slot 4. Idempotent: slots that already have a handle are skipped, and
-- the purge only runs when the run has no character yet (a run started before §16). Outside slot 4: nothing, true.
function DK.Materialise(quiet)
  if not SL.rogue then
    return true
  end
  local first_ok, _, _, first_hdl = Call(RL_SQUAD, 0)
  if first_ok ~= true then
    Log("materialise: the run has no squad (slot 0 empty): nothing to create")
    return true
  end
  if Int(Call(RL_PARTY_COUNT, 0)) < 0 then
    Log("materialise refused: CMND_EVT_RL_PARTY_COUNT unavailable")
    Message(T(DK.T_NO_PARTY))
    return false
  end
  local deleted = 0
  if Int(first_hdl) == 0 then
    deleted = DK_Purge()
  end
  local vs = Int(Call(DK.GET_VS))
  local made = 0
  for slot = 0, 19 do
    local ok, uid, param, hdl = Call(RL_SQUAD, slot)
    if ok == true and Int(hdl) == 0 and type(param) == "number" and param ~= 0 then
      local h = DK_Create(param)
      if h ~= 0 then
        Call(RL_SET_HDL, slot, h)
        local placed = DK_Place(h, vs, slot, 0)
        Log("create slot", slot, "uid", Int(uid), "param", param, "hdl", h, "placed", tostring(placed))
        made = made + 1
      end
    end
    if slot % 5 == 4 then
      coroutine.yield()
    end
  end
  Log("materialise done: created", made, "purged", deleted, "vs set", vs)
  DK_Link5(vs)
  if made == 0 and Int(first_hdl) == 0 then
    Message(T(DK.T_NO_PLAYERS))
    return false
  end
  if made > 0 and not quiet then
    Message(T(DK.T_DONE, made, vs, deleted))
  end
  return true
end
