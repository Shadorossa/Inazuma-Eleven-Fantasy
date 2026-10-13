-- VRFW route_board BEGIN
-- VR-Framework: the Chronicle route board's hook points (docs/framework/route-board.md; Nacho 2026-10-09: the board
-- grafts move to the framework). The framework owns the one patch of vs_route_town_menu (route_nodes, route_chains,
-- this graft: one merged file, so the board's main-chunk locals exist once) and makes the script a VRFW_Host host
-- (the host call at the end of this graft's file). A mod changes the board's rules with VRFW_Host handlers on the
-- hook points below (its own hook file, [[hooks]] stem = "vs_route_town_menu"), never with a second text patch of the
-- script. Without handlers every point keeps the retail behaviour (plus the framework's nodes, chains and badges).
-- Hook points (global functions; `c` = the clear context of a won match, state 10 of PreStep):
--   VRFW_RB_IsCommand(item) -> bool              a command-menu result (parameter 2612514222) that is a mod's item
--   VRFW_RB_Command(item, piece) -> bool         run it (OpenCommandSelect); false = refused (error sound, back to the
--                                                command menu)
--   VRFW_RB_BackOnBoard()                        back on the board after a match (state 8), before the retail result
--   VRFW_RB_Won(piece, slot)                     a won board match (state 10), before the clear handling
--   VRFW_RB_Clear(c)                             the clear handling starts: c = {diff, piece, slot, kind, ok, wait,
--                                                force}; set c.wait (the retail clear is skipped: a mod's event runs
--                                                first, the board waits, state 4) or c.force (cleared again even when
--                                                that difficulty was cleared before)
--   VRFW_RB_Cleared(c)                           the clear bit was set (before the clear effect)
--   VRFW_RB_UnlockNext(c) -> bool                true = the mod unlocked what this clear opens (the retail «next
--                                                difficulty» unlock is skipped)
--   VRFW_RB_OpenEffect(open) -> bool             the route-open effect after the clear (retail: the difficulty-2 clear)
--   VRFW_RB_DotShown(kind, difficulty) -> bool   a cleared difficulty's dot on the piece (kind 0 normal, 5 gate)
--   VRFW_RB_Rank(slot) -> rank Id | nil           the rank badge of a piece's save slot (a VRFW_MatchRank Id, 2.0.49);
--                                                default: a chain node's chain rank (route_chains), else the piece's
--                                                best rank (VRFW_RB_Ranks, recorded by VRFW_RB_Won)
--   VRFW_RB_MatchRank() -> rank Id, for, against the rank of the match just won (pieces and chain tiles); default:
--                                                the declared ranks VRFW_MatchRank (defaults\match_rank.toml, 2.0.49)
-- The board's locals a handler may read / write: VRFW_RB.L.<name> (decompile names of the retail chunk, served by
-- this patch: the locals it promoted). A mod that needs another one asks for it here (one line in VRFW_RB_LOCALS).
-- Retail globals of the script (OnInit, PreStep, ...) are hook points too (VRFW_Host.on(stem, "OnInit", ...)).
VRFW_RB = VRFW_RB or {}
VRFW_RB.STEM = "vs_route_town_menu"
VRFW_RB_LOCALS = {
  n9 = {function() return n9 end, function(v) n9 = v end},       -- the board's menu object (vs_route_town_menu ...)
  n21 = {function() return n21 end, function(v) n21 = v end},    -- PreStep state (4 = an event plays, 6 = clear effect)
  flag5 = {function() return flag5 end, function(v) flag5 = v end},     -- closing for a reserved map jump
  flag16 = {function() return flag16 end, function(v) flag16 = v end}   -- FinalizeMenu sets temp bit 1255964678
}
VRFW_RB.L = setmetatable({}, {
  __index = function(_, k)
    local a = VRFW_RB_LOCALS[k]
    if a == nil then
      error("VRFW_RB.L: the board serves no local " .. tostring(k), 2)
    end
    return a[1]()
  end,
  __newindex = function(_, k, v)
    local a = VRFW_RB_LOCALS[k]
    if a == nil then
      error("VRFW_RB.L: the board serves no local " .. tostring(k), 2)
    end
    a[2](v)
  end
})

function VRFW_RB_IsCommand(item)
  return false
end

function VRFW_RB_Command(item, piece)
  return false
end

function VRFW_RB_BackOnBoard()
end

-- ---- piece ranks (2.0.48: the framework's; Inazuma Fantasy's chronicle_rank graft until then) -----------------------
-- The best rank of every board piece, per save slot: save service owner vr_framework, key rb_ranks, one character per
-- statusFlagIndex (index + 1; "0" none, "1" B, "2" A, "3" S, "r" another rank: its Id in key rb_rank_ids,
-- "<slot>=<Id>;..." (2.0.49, mods' own ranks). Old saves: Inazuma Fantasy kept the same string under
-- owner inazuma_fantasy, key chr_ranks (IF 1.3.0 - 1.21.x); it is read once per slot and merged (the better rank of the
-- two per piece) the first time the framework's string is read, then written as the framework's.
VRFW_RB_RANK_ON = true -- kill switch: false = no piece rank recorded or drawn (a chain node keeps its chain's rank)
VRFW_RB_RANK_SLOTS = 300 -- the board's save status arrays (statusFlagIndex 0-299)
VRFW_RB_RANK_cache = nil

function VRFW_RB_Ranks()
  if VRFW_RB_RANK_cache == nil then
    local ok, s = pcall(funcLuaCommand, 2187277743 --[[CMND_VRFW_SAVE_GET]], "vr_framework", "rb_ranks", "")
    if not ok or type(s) ~= "string" then
      s = ""
    end
    local okI, old = pcall(funcLuaCommand, 2187277743, "inazuma_fantasy", "chr_ranks", "")
    if okI and type(old) == "string" and old ~= "" then
      local merged = {}
      local n = math.max(string.len(s), string.len(old))
      for i = 1, n do
        local a = tonumber(string.sub(s, i, i)) or 0
        local b = tonumber(string.sub(old, i, i)) or 0
        merged[i] = tostring(math.max(a, b))
      end
      local m = table.concat(merged)
      if m ~= s then
        s = m
        pcall(funcLuaCommand, 2574269955 --[[CMND_VRFW_SAVE_SET]], "vr_framework", "rb_ranks", s, 1)
        if PRINT ~= nil then
          pcall(PRINT, "VRFW_RB ranks: merged Inazuma Fantasy's chr_ranks into rb_ranks")
        end
      end
    end
    VRFW_RB_RANK_cache = s
  end
  return VRFW_RB_RANK_cache
end

VRFW_RB_LEGACY = {["1"] = "B", ["2"] = "A", ["3"] = "S"}
VRFW_RB_DIGIT = {B = "1", A = "2", S = "3"}

local function vrfw_rb_id_map()
  local ok, s = pcall(funcLuaCommand, 2187277743 --[[CMND_VRFW_SAVE_GET]], "vr_framework", "rb_rank_ids", "")
  local m = {}
  if ok and type(s) == "string" then
    for k, id in string.gmatch(s, "(%d+)=([^;]+)") do
      m[tonumber(k)] = id
    end
  end
  return m
end

local function vrfw_rb_order(id)
  if id == nil then
    return 0
  end
  local o = VRFW_MatchRank ~= nil and VRFW_MatchRank.Order(id) or 0
  return o > 0 and o or 1
end

-- the piece's best rank Id (nil = none)
function VRFW_RB_RankGet(sfi)
  if sfi == nil or sfi < 0 then
    return nil
  end
  if sfi >= VRFW_RB_RANK_SLOTS then
    return vrfw_rb_id_map()[sfi]   -- an extended slot (route-board.md §5): only in the Id map
  end
  local c = string.sub(VRFW_RB_Ranks(), sfi + 1, sfi + 1)
  if c == "r" then
    return vrfw_rb_id_map()[sfi]
  end
  return VRFW_RB_LEGACY[c]
end

function VRFW_RB_RankSet(sfi, rank)
  if rank == nil or sfi == nil or sfi < 0 or vrfw_rb_order(rank) <= vrfw_rb_order(VRFW_RB_RankGet(sfi)) then
    return false
  end
  local ext = sfi >= VRFW_RB_RANK_SLOTS   -- an extended slot (route-board.md §5): kept in the Id map, not in the string
  local s = VRFW_RB_Ranks()
  if string.len(s) < VRFW_RB_RANK_SLOTS then
    s = s .. string.rep("0", VRFW_RB_RANK_SLOTS - string.len(s))
  end
  local c = VRFW_RB_DIGIT[rank]
  if c == nil or ext then
    c = "r"
    local m = vrfw_rb_id_map()
    m[sfi] = rank
    local parts = {}
    for k, v in pairs(m) do
      parts[#parts + 1] = k .. "=" .. v
    end
    table.sort(parts)
    pcall(funcLuaCommand, 2574269955 --[[CMND_VRFW_SAVE_SET]], "vr_framework", "rb_rank_ids", table.concat(parts, ";"), 1)
  end
  if ext then
    return true
  end
  s = string.sub(s, 1, sfi) .. c .. string.sub(s, sfi + 2)
  VRFW_RB_RANK_cache = s
  pcall(funcLuaCommand, 2574269955 --[[CMND_VRFW_SAVE_SET]], "vr_framework", "rb_ranks", s, 1)
  return true
end

-- a won board match (state 10): the piece's rank by the declared ranks, its best (highest Order) kept
function VRFW_RB_Won(piece, slot)
  if not VRFW_RB_RANK_ON or slot == nil then
    return
  end
  VRFW_RB_RANK_cache = nil -- another save slot may have been loaded since
  local rank, f, a = VRFW_RB_MatchRank()
  if rank == nil then
    -- no declared rank holds (a mod's ranks need more): the lowest declared rank, the piece is won all the same
    local list = VRFW_MatchRank ~= nil and VRFW_MatchRank.List() or {}
    rank = list[#list] and list[#list].id or "B"
  end
  local better = VRFW_RB_RankSet(slot, rank)
  if PRINT ~= nil then
    pcall(PRINT, "VRFW_RB rank piece", piece, "slot", slot, "score", f, a, "rank", rank, "best", VRFW_RB_RankGet(slot), better)
  end
end

function VRFW_RB_Clear(c)
end

function VRFW_RB_Cleared(c)
end

function VRFW_RB_UnlockNext(c)
  return false
end

function VRFW_RB_OpenEffect(open)
  return open
end

function VRFW_RB_DotShown(kind, difficulty)
  return true
end

function VRFW_RB_Rank(slot)
  local r = nil
  if VRFW_RCH_RankOf ~= nil then
    r = VRFW_RCH_RankOf(slot)
  end
  if r == nil and VRFW_RB_RANK_ON then
    r = VRFW_RB_RankGet(slot)
  end
  return r
end

-- the rank of the match just won: the framework's rule (VRFW_MatchRank, menu part); B when it is missing
function VRFW_RB_MatchRank()
  if VRFW_MatchRank ~= nil then
    return VRFW_MatchRank.Last()
  end
  return "B", -1, -1
end

-- The rank badge of a piece (end of UpdatePieceClearIcon(layer, instance, piece)): the clear-icon layer of the piece
-- (vsroute01_06c, attached at the piece's origin) has a 6th difficulty dot (_pos_clear08_01, Legendaria;
-- _pos_clear08_02 on gate pieces). With a rank it becomes the badge: moved over the crest's lower-right corner, its
-- picture = the rank sprite (the framework's sprites vrfw_rank_{b,a,s} in the dots' atlas vsroute01_06b,
-- research/mods/VRFW/images/menu/30_vsroute/vsroute01/vsroute01_06b.toml). Without a rank nothing changes.
VRFW_RB_BADGE_ON = true -- kill switch: false = no badge
VRFW_RB_BADGE_POS = {x = 40, y = -6} -- badge centre, piece coordinates (crest: 128 px centred at (0, 38))
VRFW_RB_BADGE_TEX = 2855820778 --[[crc32("#/menu/30_vsroute/vsroute01/vsroute01_06b/vsroute01_06b.g4tx")]]
VRFW_RB_BADGE_SPRITE = {
  [1] = 813797929, --[[vrfw_rank_b]]
  [2] = 2844312467, --[[vrfw_rank_a]]
  [3] = 1513206491 --[[vrfw_rank_s]]
}
VRFW_RB_BADGE_TEXREF = 516486421 --[[clear_icon08: the picture of both Legendaria dots]]
-- per eventType of the piece: the dot used as badge and the effect / ring meshes kept hidden on it
VRFW_RB_BADGE_DOT = {
  [0] = {pos = 2027773323 --[[_pos_clear08_01]], hide = {760159382 --[[_clear_icon08_01_add01]], 3024506156 --[[_clear_icon08_01_add02]], 3008808285 --[[_clear_ring08_01]]}},
  [5] = {pos = 3788770353 --[[_pos_clear08_02]], hide = {480708107 --[[_clear_icon08_02_add01]], 2242795441 --[[_clear_icon08_02_add02]], 710907111 --[[_clear_ring08_02]]}}
}

function VRFW_RB_Badge(a1, a2, a3)
  if not VRFW_RB_BADGE_ON or a3 == nil or a3 == -1 then
    return
  end
  local okE, evType = GetTownMapResourceEvent(a3, 1, true)
  local dot = okE and VRFW_RB_BADGE_DOT[evType] or nil
  if dot == nil then
    return
  end
  local ok, sfi = funcLuaCommand(126049514, a3, 6)
  if not ok then
    return
  end
  -- the rank's PieceBadge (defaults\match_rank.toml): a sprite of the dots' atlas vsroute01_06b
  local rank = VRFW_RB_Rank(sfi)
  local def = VRFW_MatchRank ~= nil and VRFW_MatchRank.ById(rank) or nil
  local sprite = nil
  if def ~= nil and def.piece ~= "" then
    sprite = CRC32(def.piece)
  elseif type(rank) == "string" then
    sprite = VRFW_RB_BADGE_SPRITE[({B = 1, A = 2, S = 3})[rank] or 0]
  end
  if sprite == nil then
    return -- no rank (or a rank without a piece badge): the retail loop already set the dot
  end
  funcLuaMenuCommand(558735651, a1, VRFW_RB_BADGE_TEX, sprite, VRFW_RB_BADGE_TEXREF, 0, a2)
  funcLuaMenuCommand(1856671416 --[[node translation]], a1, a2, dot.pos, VRFW_RB_BADGE_POS.x, VRFW_RB_BADGE_POS.y, 0)
  funcLuaMenuCommand(2158717427, a1, dot.pos, true, a2)
  for i = 1, #dot.hide do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], a1, dot.hide[i], false, a2)
  end
  funcLuaMenuCommand(629267548 --[[CMND_OPEN_LAYER]], a1, a2)
end

-- The retail invite check at the end of PreStep (CheckAndReserveGeneralWindowForInviteNotJoined, include
-- network_invite_menu_inc) waits with coroutine.yield while a general window is busy (CMND 682363669 false). PreStep is
-- not a coroutine here, so every frame a message window was up logged «LUAERR … attempt to yield from outside a
-- coroutine» (e.g. hundreds of lines in 30 s while the board's lock message showed). Called when it can wait (inside a
-- coroutine) or will not wait (no window busy); otherwise it runs again next frame, as the retail wait would.
function VRFW_RB_InviteCheck()
  local _, main = coroutine.running()
  if main == false or funcLuaCommand(682363669) then
    return CheckAndReserveGeneralWindowForInviteNotJoined()
  end
  return false
end
-- VRFW route_board END
