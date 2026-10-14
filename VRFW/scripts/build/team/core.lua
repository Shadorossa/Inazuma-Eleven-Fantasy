-- The team build's context and its core steps (was team_engine build.rs): references, the fields of a new team / an
-- edit (members, loadouts, kit, emblem, texts), new kits and emblems, new teams. Every function returns `nil, err`
-- where the old builder returned `Err` (the caller notes it); positions of teams / members are 0-based.
local T = require "lib/team_util"
local U = require "lib/util"
local TC = require "team/tc"
local C = {}

local CATALOG_BITS = 8192
local CATALOG_SHARED = CATALOG_BITS - 1
local CATALOG_SPACE = "item_catalog"
-- MIGRATION ONLY: the catalog number an emblem had under the engine's OLD rule (the first number from 8150 no item row
-- uses), registered for the migration of old saves, never given out
local LEGACY_CATALOG_FROM = 8150
local SLOT_COACH, SLOT_MANAGER, MAX_SLOT = 19, 20, 20
local LOADOUT_MOVES = 6
local EMBLEM_DIR = "data/dx11/menu/200_icon/01_icon_emblem/"
C.EMBLEM_DIR = EMBLEM_DIR

-- A host call that may raise a Lua error: `true, result` or `nil, message`.
function C.try(f, ...)
  local ok, r = pcall(f, ...)
  if not ok then return nil, tostring(r) end
  return true, r
end

function C.install(X)
  local TI, TM = X.TI, X.TM

  -- ------------------------------------------------------------------------------------------------ notes, claims

  function X.claim(team, field, m, v, what)
    local by = X.claims[team]
    if not by then by = {} X.claims[team] = by end
    local old = by[field]
    if old and old.by ~= m and old.val ~= v then
      local msg = string.format("team conflict: %s.%s: mod %s = %s, mod %s = %s (winner: %s, loads later)", what, field, old.by, old.val, m, v, m)
      VRFW.log.warn(msg)
      X.conflicts[#X.conflicts + 1] = msg
    end
    by[field] = { by = m, val = v }
  end

  function X.push_text(m, d, t)
    X.texts.push(m, d, t)
  end

  -- ------------------------------------------------------------------------------------------------ tables

  -- `key, nil` of the newest `<prefix><version>.cfg.bin` of the game's and the mods' keys, else `nil, err`
  function X.table_key(prefix)
    return VRFW.team.table_key(prefix)
  end

  function X.games()
    if X.games_t then return X.games_t end
    local k, e = X.table_key("data/common/gamedata/soccer/soccer_game_config_")
    if not k then return nil, e end
    local t, e2 = VRFW.rows.open(k)
    if not t then return nil, e2 end
    X.games_t = t
    X.SG = X.sg_columns(t)
    return t
  end

  local function rd(field, prefix)
    return function()
      if X[field] then return X[field] end
      local k, e = X.table_key(prefix)
      if not k then return nil, e end
      local r, e2 = VRFW.team.rdbn(k)
      if not r then return nil, e2 end
      X[field] = r
      return r
    end
  end
  X.opp = rd("opp_rd", "data/common/gamedata/soccer/soccer_opponent_info_")
  X.route = rd("route_rd", "data/common/gamedata/vsroute/chronicle_vs_route_config_")
  X.uniform = rd("uniform_rd", "data/common/gamedata/character/uniform_config_")
  X.sgbgm = rd("sgbgm_rd", "data/common/sound/soccer_game_bgm_config_")

  function X.item()
    if X.item_t then return X.item_t end
    local k, e = X.table_key("data/common/gamedata/item/item_config_")
    if not k then return nil, e end
    local t, e2 = VRFW.rows.open(k)
    if not t then return nil, e2 end
    X.item_t = t
    local function ic(name, n)
      local ok, c = pcall(t.col, t, "ITEM_EMBLEM_INFO", name)
      if ok and c then return c end
      return n
    end
    X.EM = { ID = ic("id", 0), NAME = ic("name_text", 2), DESC = ic("desc_text", 3), CATALOG = ic("catalog_no", 4),
      KEY = ic("key", 11), BASE = ic("base_item", 14) }
    local ok, c = pcall(t.col, t, "ITEM_FASHION_INFO", "uniform")
    X.FASHION_KIT = (ok and c) or 18
    return t
  end

  -- the pool table `file` of a pool_table list (read once; false = not in the data)
  function X.pool(file)
    if X.pools[file] == nil then
      local t = VRFW.rows.open(file)
      X.pools[file] = t or false
    end
    return X.pools[file] or nil
  end

  function X.shop()
    if X.shop_t == nil then
      local k, e = X.table_key("data/common/gamedata/shop/shop_config_")
      if not k then
        VRFW.log.warn(e .. ": the shop lists are not changed")
        X.shop_t = false
        return nil
      end
      local t, e2 = VRFW.rows.open(k)
      if not t then VRFW.log.warn(e2 .. ": shop_beside lists are not changed") end
      X.shop_t = t or false
    end
    return X.shop_t or nil
  end

  -- every formation id: the teams' own (as read the first time) and formation_config's
  function X.formations()
    if X.formations_set then return X.formations_set end
    local set = {}
    for t = 0, #X.tc.teams - 1 do
      local f = TC.uint(X.tc:info(t), TI.FORMATION)
      if f then set[f] = true end
    end
    local k = X.table_key("data/common/gamedata/formation/formation_config_")
    if k then
      local r = VRFW.team.rdbn(k)
      if r then
        local l = r:list("m_SoccerFormationInfoList")
        if l then
          for i = 0, r:len(l) - 1 do
            local v = r:u32(l, i, 0)
            if v then set[v] = true end
          end
        end
      end
    end
    X.formations_set = set
    return set
  end

  -- the names (NOUN_INFO col 5, variant 0) of text table `table` in language `lang`, read once: the first row of an id
  -- (`last`: the last one); nil = no file
  function X.nouns(lang, table, last)
    local key = "data/common/text/" .. lang .. "/" .. table .. ".cfg.bin"
    local c = X.noun_cache[key]
    if c == nil then
      c = false
      local t = VRFW.rows.open(key)
      if t then
        c = { first = {}, last = {} }
        for _, i in ipairs(t:rows("NOUN_INFO")) do
          if t:int(i, 1) == 0 then
            local id, s = t:uint(i, 0), t:str(i, 5)
            if id and s then
              if c.first[id] == nil then c.first[id] = s end
              c.last[id] = s
            end
          end
        end
      end
      X.noun_cache[key] = c
    end
    if not c then return nil end
    return last and c.last or c.first
  end

  function X.chara_name_es(chara)
    local b = X.ch.base[chara]
    if not b then return nil end
    local names = X.nouns(X.lang.source, "chara_text", true)
    return names and names[b.name_text]
  end

  -- ------------------------------------------------------------------------------------------------ references

  -- a team: a creation key (`<mod>.<name>`, or `<name>` of the same mod), a game key or id → its position
  function X.team_ref(s, m)
    s = T.trim(s)
    local c = X.created[s] or X.created[m .. "." .. s]
    if c then
      local t = X.tc:find(c.id)
      if t == nil then return nil, "team `" .. s .. "`: its row is gone" end
      return t
    end
    if X.deleted_new[s] or X.deleted_new[m .. "." .. s] then
      return nil, "team `" .. s .. "` was deleted by a [[remove]]"
    end
    local t = X.tc:find_key(s)
    if t then return t end
    t = X.tc:find(VRFW.ids.parse(s))
    if t == nil then
      return nil, "team `" .. s .. "` is not in team_config (write a game team key like tm_st_game_0101a, its id, or a mod's <mod>.<name>)"
    end
    return t
  end

  function X.label(t)
    local c = X.created_by_id[X.tc:id_of(t)]
    if c then return c.key end
    return X.tc:key_of(t)
  end

  -- a player: `card` directly, or a character (creation key, internal name, id; a card id also works) → its first card
  function X.player_ref(player, card, m)
    if card ~= nil then
      local id = T.id(card)
      if X.ch.card[id] then return id end
      return nil, "unknown player: card " .. T.idref_text(card) .. " is not in chara_param"
    end
    local p = player and T.trim(player) or ""
    if p == "" then return nil, "a member needs `player` or `card`" end
    local c = X.ch.created[p] or X.ch.created[m .. "." .. p]
    if c then return c.card end
    local id = X.ch.by_name[p] or VRFW.ids.parse(p)
    local cards = X.ch.cards[id]
    if cards and cards[1] then return cards[1] end
    if X.ch.card[id] then return id end
    if X.ch.base[id] then return nil, "unknown player: `" .. p .. "` has no card (chara_param row)" end
    return nil, "unknown player `" .. p .. "` (write a game internal name like c01000010, a character or card id, or a mod's <mod>.<name> from the character engine)"
  end

  function X.chara_of(s, m)
    local c, e = X.player_ref(s, nil, m)
    if not c then return nil, e end
    local x = X.ch.card[c]
    return x and x.chara or 0
  end

  -- ------------------------------------------------------------------------------------------------ members

  function X.member_row(proto, card, mem, same_player, own_loadout)
    local v = TC.copy_row(proto)
    if not same_player then
      for _, c in ipairs { TM.SKILL_CFG, TM.SHOES, TM.EQ2, TM.EQ3, TM.EQ4, TM.TITLE } do TC.set_int(v, c, 0) end
      TC.set_int(v, TM.PARAM, card)
      TC.set_int(v, TM.UID, card)
    end
    TC.set_int(v, TM.SLOT, mem.slot)
    TC.set_int(v, TM.NUMBER, mem.number or (mem.slot + 1))
    TC.set_int(v, TM.CAPTAIN, mem.captain and 1 or 0)
    TC.set_int(v, TM.LV_OFS, 0)
    if own_loadout then TC.set_int(v, TM.SKILL_CFG, own_loadout) end
    return v
  end

  -- a member's `aura` / `mix` (the two Hiper auras of a CPU player: keshin / totem, miximax / mode change; docs
  -- types/team.md): they take the last slots of his loadout, after his `moves`
  local function extras(mem)
    local x = {}
    if mem.aura ~= nil then x[#x + 1] = { T.id(mem.aura), mem.aura_level or 1 } end
    if mem.mix ~= nil then x[#x + 1] = { T.id(mem.mix), mem.mix_level or 1 } end
    return x
  end

  local function move_pairs(mem)
    local pairs_ = {}
    local ex = extras(mem)
    for k = 1, math.min(#(mem.moves or {}), LOADOUT_MOVES - #ex) do
      pairs_[k] = { T.id(mem.moves[k]), (mem.levels or {})[k] or 1 }
    end
    for _, p in ipairs(ex) do pairs_[#pairs_ + 1] = p end
    return pairs_
  end

  -- the loadout id of a member's `loadout` / `moves` (own rows: crc32("<tkey>_te_sk_<slot>")); nil = the card's own
  function X.member_loadout(tkey, mem, errs)
    if mem.loadout ~= nil then
      if mem.moves ~= nil or mem.aura ~= nil or mem.mix ~= nil then
        errs[#errs + 1] = string.format("member slot %d: `loadout` with `moves` / `aura` / `mix` (the loadout is used)", mem.slot)
      end
      local id = T.id(mem.loadout)
      if id ~= 0 and not X.tc:has_loadout(id) then
        errs[#errs + 1] = string.format("member slot %d: loadout %s is not in TEAM_MEMBER_SKILL_CONFIG_INFO (a game loadout id or a [[loadout]] of a mod)", mem.slot, T.idref_text(mem.loadout))
        return nil
      end
      return id
    end
    if mem.moves == nil then
      if mem.aura ~= nil or mem.mix ~= nil then
        errs[#errs + 1] = string.format("member slot %d: `aura` / `mix` need `moves` (left out)", mem.slot)
      end
      return nil
    end
    local room = LOADOUT_MOVES - #extras(mem)
    if #mem.moves > room then
      errs[#errs + 1] = string.format("member slot %d: %d moves, a member takes at most %d with his aura / mix (the rest is left out)", mem.slot, #mem.moves, room)
    end
    local lid = VRFW.crc32(tkey .. "_te_sk_" .. mem.slot)
    local e = X.tc:loadout(lid, move_pairs(mem))
    if not e then return nil end
    X.tc:put_loadout(e)
    return lid
  end

  -- write the cells a member row declares (the ones it gives; `card` already resolved)
  function X.member_cells(e, mem, card, loadout)
    if card then TC.set_int(e, TM.PARAM, card) end
    if mem.uid ~= nil then TC.set_int(e, TM.UID, T.id(mem.uid)) end
    if loadout then TC.set_int(e, TM.SKILL_CFG, loadout) end
    if mem.equipment ~= nil then
      for k, c in ipairs { TM.SHOES, TM.EQ2, TM.EQ3, TM.EQ4 } do
        local x = mem.equipment[k]
        TC.set_int(e, c, x ~= nil and T.id(x) or 0)
      end
    end
    if mem.title ~= nil then TC.set_int(e, TM.TITLE, T.id(mem.title)) end
    if mem.flag ~= nil then TC.set_int(e, TM.FLAG, mem.flag) end
    if mem.number ~= nil then TC.set_int(e, TM.NUMBER, mem.number) end
    if mem.level_offset ~= nil then TC.set_int(e, TM.LV_OFS, mem.level_offset) end
    if mem.rarity_step ~= nil then TC.set_int(e, TM.RARITY_STEP, mem.rarity_step) end
    if mem.c14_19 ~= nil then
      for k = 0, 5 do
        local x = mem.c14_19[k + 1]
        TC.set_int(e, TM.C14 + k, x ~= nil and x or -1)
      end
    end
    if mem.rates ~= nil then
      for k = 0, 7 do
        local x = mem.rates[k + 1]
        local val
        if x == nil then val = 1
        elseif type(x) == "table" then val = { float = x.float }
        else val = T.i32(x) end
        TC.set(e, TM.RATE + k, val)
      end
    end
  end

  -- the roster rows of a `roster = "exact"` team, in the declared order: each row only from its keys
  function X.exact_rows(m, tkey, members, errs)
    local first = X.tc.members[1]
    if not first then
      errs[#errs + 1] = "team_config has no member row to shape a new one"
      return {}
    end
    local seen, out = {}, {}
    local caps = 0
    for _, x in ipairs(members) do if x.captain then caps = caps + 1 end end
    if caps > 1 then errs[#errs + 1] = "more than one captain" end
    for _, mem in ipairs(members) do
      if mem.slot > MAX_SLOT then
        errs[#errs + 1] = string.format("member slot %d out of 0-%d", mem.slot, MAX_SLOT)
      elseif seen[mem.slot] then
        errs[#errs + 1] = string.format("member slot %d given twice", mem.slot)
      else
        seen[mem.slot] = true
        if mem.remove or mem.patch then
          errs[#errs + 1] = string.format("member slot %d: `remove` / `patch` are [[edit.member]] keys", mem.slot)
        else
          if mem.number ~= nil and mem.number > 99 then
            -- the game data has a few (a retail Victoria Vanguard row wears 105): kept, noted
            VRFW.log.info(string.format("%s: member slot %d: shirt number %d above 99 (kept)", tkey, mem.slot, mem.number))
          end
          local bad = (mem.equipment ~= nil and #mem.equipment > 4) or (mem.c14_19 ~= nil and #mem.c14_19 > 6)
            or (mem.rates ~= nil and #mem.rates > 8) or (mem.role ~= nil and #mem.role ~= 2)
          if bad then
            errs[#errs + 1] = string.format("member slot %d: equipment takes ≤ 4 items, c14_19 ≤ 6 numbers, rates ≤ 8, role [start, count]", mem.slot)
          else
            local card, e = X.player_ref(mem.player, mem.card, m)
            if not card then
              errs[#errs + 1] = string.format("member slot %d: %s", mem.slot, e)
            else
              local loadout = X.member_loadout(tkey, mem, errs)
              local c = T.i32(card)
              local row = { c, c, 0, 0, 0, 0, 0, 0, mem.slot, 0, mem.slot + 1, mem.captain and 1 or 0, 0, 0, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1 }
              X.member_cells(row, mem, nil, loadout)
              local role = {}
              local rv = mem.role or { 0, 0 }
              for k, x in ipairs(rv) do role[k] = x end
              out[#out + 1] = { m = row, r = role }
            end
          end
        end
      end
    end
    return out
  end

  -- `card_moves = n`: every player row (slots 0-18) plays the first `n` moves of its card's learn list, level 1
  function X.card_moves(m, what, t, n, members, errs)
    if not (n >= 1 and n <= LOADOUT_MOVES) then
      errs[#errs + 1] = string.format("card_moves %d out of 1-%d", n, LOADOUT_MOVES)
      return
    end
    local tc = X.tc
    local tid, tkey = tc:id_of(t), tc:key_of(t)
    local own = {}
    for _, x in ipairs(members) do
      if x.moves ~= nil or x.loadout ~= nil then own[x.slot] = true end
    end
    local s, e = tc:member_range(t)
    for i = s, e - 1 do
      local row = tc:member(i).m
      local slot = TC.uint(row, TM.SLOT) or 0
      if not (slot >= SLOT_COACH or own[slot]) then
        local card = TC.uint(row, TM.PARAM) or 0
        local mv = {}
        for k, x in ipairs(X.ch.learn[card] or {}) do
          if k > n then break end
          mv[k] = { x, 1 }
        end
        if #mv == 0 then
          VRFW.log.info(string.format("%s: card_moves: slot %d: card %s has no move in its learn list (its loadout is kept)", what, slot, T.hex(card)))
        else
          local lid = VRFW.crc32(tkey .. "_te_sk_" .. slot)
          local l = tc:loadout(lid, mv)
          if l then
            tc:put_loadout(l)
            local r = TC.copy_row(row)
            TC.set_int(r, TM.SKILL_CFG, lid)
            X.claim(tid, "member[" .. slot .. "].moves", m, string.format("card %s x%d", T.hex(card), n), what)
            tc:member(i).m = r
            tc.changed = true
          end
        end
      end
    end
  end

  -- `[[edit.member]] patch = true` rows: only their keys, on the row of their slot, in place
  function X.patch_members(m, what, t, members, errs)
    local tc = X.tc
    local tid, tkey = tc:id_of(t), tc:key_of(t)
    local s, e = tc:member_range(t)
    for _, mem in ipairs(members) do
      local i
      for k = s, e - 1 do
        if TC.uint(tc:member(k).m, TM.SLOT) == mem.slot then i = k break end
      end
      if not i then
        errs[#errs + 1] = string.format("member slot %d: patch: the team has no row in that slot", mem.slot)
      else
        local card, ok = nil, true
        if mem.player ~= nil or mem.card ~= nil then
          local c, err = X.player_ref(mem.player, mem.card, m)
          if not c then
            errs[#errs + 1] = string.format("member slot %d: %s", mem.slot, err)
            ok = false
          else
            card = c
          end
        end
        if ok then
          local loadout = X.member_loadout(tkey, mem, errs)
          local row = TC.copy_row(tc:member(i).m)
          X.member_cells(row, mem, card, loadout)
          if mem.captain then TC.set_int(row, TM.CAPTAIN, 1) end
          if mem.role ~= nil then
            local r = {}
            for k, x in ipairs(mem.role) do r[k] = x end
            tc:member(i).r = r
          end
          X.claim(tid, "member[" .. mem.slot .. "]", m, T.dbg_cells(row), what)
          tc:member(i).m = row
          tc.changed = true
        end
      end
    end
  end

  -- the `member` rows of mod `m` on team `t` (per slot; `replace_all` = a new team's full roster)
  function X.apply_members(m, what, t, all, replace_all, errs)
    local patches, members = {}, {}
    for _, x in ipairs(all) do
      if x.patch then patches[#patches + 1] = x else members[#members + 1] = x end
    end
    if #patches > 0 then X.patch_members(m, what, t, patches, errs) end
    if #members == 0 then return end
    local tc = X.tc
    local tid, tkey = tc:id_of(t), tc:key_of(t)
    local s, e = tc:member_range(t)
    -- slot → row (a later row of the same slot wins, as a BTreeMap insert)
    local cur = {}
    for i = s, e - 1 do
      local row = tc:member(i).m
      -- copies: the captain mark below must not touch the table's rows (another team may share them)
      cur[TC.uint(row, TM.SLOT) or 0] = TC.copy_row(row)
    end
    local proto = tc.members[s + 1] and tc.members[s + 1].m or (tc.members[1] and tc.members[1].m)
    if not proto then
      errs[#errs + 1] = "team_config has no member row to shape a new one"
      return
    end
    local role = tc.members[1].r
    local seen = {}
    local old = T.copy(cur)
    local old_slots = T.keys(old)
    if replace_all then cur = {} end
    for _, mem in ipairs(members) do
      if mem.slot > MAX_SLOT then
        errs[#errs + 1] = string.format("member slot %d out of 0-%d", mem.slot, MAX_SLOT)
      elseif seen[mem.slot] then
        errs[#errs + 1] = string.format("member slot %d given twice (the first is kept)", mem.slot)
      else
        seen[mem.slot] = true
        if mem.remove then
          X.claim(tid, "member[" .. mem.slot .. "]", m, "removed", what)
          cur[mem.slot] = nil
        else
          local card, err = X.player_ref(mem.player, mem.card, m)
          if not card then
            errs[#errs + 1] = string.format("member slot %d: %s", mem.slot, err)
          else
            if mem.number ~= nil and mem.number > 99 then
              errs[#errs + 1] = string.format("member slot %d: shirt number out of 0-99", mem.slot)
            end
            local loadout
            if mem.moves ~= nil then
              if #mem.moves > LOADOUT_MOVES then
                errs[#errs + 1] = string.format("member slot %d: %d moves, a member takes at most %d (the rest is left out)", mem.slot, #mem.moves, LOADOUT_MOVES)
              end
              local lid = VRFW.crc32(tkey .. "_te_sk_" .. mem.slot)
              local l = tc:loadout(lid, move_pairs(mem))
              if l then
                tc:put_loadout(l)
                loadout = lid
              end
            end
            local base = old[mem.slot]
            if base == nil then
              for _, sl in ipairs(old_slots) do
                if TC.uint(old[sl], TM.PARAM) == card then base = old[sl] break end
              end
            end
            local same = base ~= nil and TC.uint(base, TM.PARAM) == card
            local row = X.member_row(base or proto, card, mem, same, loadout)
            X.claim(tid, "member[" .. mem.slot .. "]", m, T.hex(card), what)
            cur[mem.slot] = row
          end
        end
      end
    end
    -- one captain at most: a member row that says captain wins over the older ones
    local cap = {}
    for _, x in ipairs(members) do
      if x.captain and not x.remove then cap[#cap + 1] = x.slot end
    end
    if #cap > 0 then
      if #cap > 1 then errs[#errs + 1] = "more than one captain (slots " .. T.dbg_list(cap) .. "): the last is kept" end
      local keep = cap[#cap]
      for sl, row in pairs(cur) do TC.set_int(row, TM.CAPTAIN, sl == keep and 1 or 0) end
    end
    local rows = {}
    for _, sl in ipairs(T.keys(cur)) do rows[#rows + 1] = cur[sl] end
    tc:set_members(t, rows, role)
  end

  function X.set_info(t, c, v, m, what, field)
    X.claim(X.tc:id_of(t), field, m, T.hexu(v), what)
    TC.set_int(X.tc:info(t), c, v)
    X.tc.changed = true
  end

  -- ------------------------------------------------------------------------------------------------ apply

  -- apply `f` (the fields of mod `m`'s declaration) to team `t`
  function X.apply(m, file, what, t, f, file_default, is_new)
    local errs = {}
    local tc = X.tc
    local tid = tc:id_of(t)
    if f.level ~= nil then
      if f.level >= 1 and f.level <= 999 then
        X.set_info(t, TI.LEVEL, f.level, m, what, "level")
      else
        errs[#errs + 1] = string.format("level %d out of 1-999", f.level)
      end
    end
    if f.formation ~= nil then
      local id = T.id(f.formation)
      if X.formations()[id] then
        X.set_info(t, TI.FORMATION, id, m, what, "formation")
      else
        errs[#errs + 1] = "formation " .. T.idref_text(f.formation) .. ": not a formation of formation_config (a formation id, 0x…, or its key)"
      end
    end
    if f.kit ~= nil then
      if type(f.kit) == "table" then
        local id, e = X.compose_kit(t, f.kit, m)
        if id then X.set_info(t, TI.KIT, id, m, what, "kit") else errs[#errs + 1] = "kit: " .. e end
      else
        local id = T.id(f.kit)
        local ok, e = X.kit_exists(id)
        if ok == nil then
          errs[#errs + 1] = "kit: " .. e
        elseif ok then
          X.set_info(t, TI.KIT, id, m, what, "kit")
        elseif type(f.kit) == "number" then
          -- a number is kept (game teams carry kit ids uniform_config lacks: the game falls back), a name is most
          -- likely a typo
          VRFW.log.warn(what .. ": kit " .. T.idref_text(f.kit) .. " is not in uniform_config: kept as written")
          X.set_info(t, TI.KIT, id, m, what, "kit")
        else
          errs[#errs + 1] = "kit " .. T.idref_text(f.kit) .. ": unknown kit (not in uniform_config; a kit id, 0x…, or its key)"
        end
      end
    end
    if f.emblem ~= nil then
      if type(f.emblem) == "table" then
        local id, e = X.emblem_png(m, t, f.emblem)
        if id then
          X.set_info(t, TI.EMBLEM, id, m, what, "emblem")
        elseif e then
          errs[#errs + 1] = "emblem: " .. e
        else
          VRFW.log.info(what .. ": emblem " .. tostring(f.emblem.png) .. ": that mod is not active, the team keeps its emblem")
        end
      else
        local id = T.id(f.emblem)
        local ok, e = X.emblem_exists(id)
        if ok == nil then
          errs[#errs + 1] = "emblem: " .. e
        elseif ok then
          X.set_info(t, TI.EMBLEM, id, m, what, "emblem")
        else
          errs[#errs + 1] = "emblem " .. T.idref_text(f.emblem) .. ": unknown emblem (not an ITEM_EMBLEM_INFO of item_config; e.g. em010010)"
        end
      end
    end
    if f.emblem_badge ~= nil then
      local id, e = X.emblem_badge(m, t, f.emblem_badge)
      if id then X.set_info(t, TI.EMBLEM, id, m, what, "emblem") else errs[#errs + 1] = "emblem_badge: " .. e end
    end
    -- roster (+ coach / manager rows)
    local members = {}
    for k, x in ipairs(f.member or {}) do members[k] = T.copy(x) end
    for _, sw in ipairs { { SLOT_COACH, f.coach }, { SLOT_MANAGER, f.manager } } do
      local slot, who = sw[1], sw[2]
      if who ~= nil then
        local taken = false
        for _, x in ipairs(members) do if x.slot == slot then taken = true break end end
        if taken then
          errs[#errs + 1] = string.format("slot %d given both as a member and as coach / manager (the member row is kept)", slot)
        else
          members[#members + 1] = { player = who, slot = slot, captain = false, levels = {}, remove = false, patch = false }
        end
      end
    end
    if f.captain ~= nil then
      local card, e = X.player_ref(f.captain, nil, m)
      if card then
        -- the captain must be in the roster (declared here or already there)
        local in_decl
        for _, x in ipairs(members) do
          if not x.remove and X.player_ref(x.player, x.card, m) == card then in_decl = x break end
        end
        if in_decl then
          in_decl.captain = true
        else
          local s, en = tc:member_range(t)
          local slot
          for i = s, en - 1 do
            if TC.uint(tc:member(i).m, TM.PARAM) == card then slot = TC.uint(tc:member(i).m, TM.SLOT) or 0 break end
          end
          if slot ~= nil and not X.full_roster then
            members[#members + 1] = { card = card, slot = slot, captain = true, levels = {}, remove = false, patch = false }
          else
            errs[#errs + 1] = "captain `" .. f.captain .. "` is not a member of the team"
          end
        end
      else
        errs[#errs + 1] = "captain: " .. e
      end
    end
    local full = X.full_roster
    X.full_roster = false
    X.apply_members(m, what, t, members, full, errs)
    if f.card_moves ~= nil then X.card_moves(m, what, t, f.card_moves, members, errs) end
    if f.tactics ~= nil then
      local ids = {}
      for k, x in ipairs(f.tactics) do ids[k] = T.id(x) end
      X.claim(tid, "tactics", m, T.dbg_list(ids), what)
      tc:set_tactics(t, ids)
    end
    -- not team_config cells: the team's games, the match engine, the Lua
    local meta = X.meta[tid] or X.new_meta()
    X.meta[tid] = nil
    if f.stadium ~= nil then
      X.claim(tid, "stadium", m, T.hexu(T.id(f.stadium)), what)
      meta.stadium = T.id(f.stadium)
    end
    -- `stadium_fallback`: the home only when no team of the `based_on` chain declares `stadium` (lists.lua home_stadium)
    if f.stadium_fallback ~= nil then
      X.claim(tid, "stadium_fallback", m, T.hexu(T.id(f.stadium_fallback)), what)
      meta.stadium_fallback = T.id(f.stadium_fallback)
    end
    -- `stadium_image`: the Estadio BB card art of the rows playing at the home this declaration gives
    if f.stadium_image ~= nil then
      X.claim(tid, "stadium_image", m, f.stadium_image, what)
      meta.stadium_image = f.stadium_image
    end
    if f.music ~= nil then
      local want, found = T.trim(f.music):lower(), nil
      for _, x in ipairs(X.music_lib) do
        if x[1]:lower() == want then found = x break end
      end
      if found then
        X.claim(tid, "music", m, found[1], what)
        meta.music = found[2]
      else
        VRFW.log.warn(what .. ": music: unknown track `" .. f.music .. "` (not in the music library: a sounds\\ `[[music]]` with a `category` in an active mod): the game's music is kept")
      end
    end
    if f.ai ~= nil then
      X.claim(tid, "ai", m, T.d(f.ai), what)
      meta.ai = f.ai
    end
    if f.rules ~= nil then
      X.claim(tid, "rules", m, f.rules, what)
      meta.rules = { m, f.rules }
    end
    if f.series ~= nil then meta.series = f.series end
    -- names → team_text (the text type integrates them)
    if not T.is_empty(f.text) then
      local d = U.norm_default(file_default, f.text)
      meta.default_lang = d or meta.default_lang
      for _, l in ipairs(T.keys(f.text)) do
        if VRFW.lang.norm_or_all(l) == nil then
          VRFW.log.warn(what .. ": text." .. l .. ": not a language (" .. table.concat(VRFW.lang.list(), ", ") .. ", all): ignored")
        end
      end
      local names, short = {}, {}
      local any_name = false
      for _, l in ipairs(T.keys(f.text)) do
        local n = VRFW.lang.norm_or_all(l)
        local x = f.text[l]
        if n and x.name ~= nil and T.trim(x.name) ~= "" then names[n] = x.name any_name = true end
        if n and x.short ~= nil and T.trim(x.short) ~= "" then short[n] = x.short end
      end
      if any_name then
        local name_id = TC.uint(tc:info(t), TI.NAME) or 0
        if name_id == 0 then
          VRFW.log.warn(what .. ": the team row has no name text id: its name is not changed")
        else
          X.claim(tid, "name", m, T.dbg_map(names), what)
          X.push_text(m, d, { table = "team_text", id = name_id, variant = 0, texts = names, add = is_new,
            origin = file .. ": " .. what .. " (" .. m .. ")" })
        end
        for k, v in pairs(names) do meta.names[k] = v end
      end
      for k, v in pairs(short) do meta.short[k] = v end
    end
    X.meta[tid] = meta
    VRFW.sort(errs)
    local last
    for _, e in ipairs(errs) do
      if e ~= last then VRFW.log.error(what .. ": " .. e) end
      last = e
    end
  end

  function X.new_meta()
    return { names = {}, short = {} }
  end

  -- ------------------------------------------------------------------------------------------------ kits

  function X.kit_exists(id)
    local u, e = X.uniform()
    if not u then return nil, e end
    local l, e2 = u:list("m_UniformInfoList")
    if not l then return nil, e2 end
    for i = 0, u:len(l) - 1 do
      if u:u32(l, i, 0) == id then return true end
    end
    return false
  end

  -- a new kit: home / away field models and the keeper models of three game kits (a new m_UniformInfoList row with
  -- its own model slice; the kit's m_UniformExInfoList row cloned from `home`'s)
  function X.compose_kit(t, p, m)
    local src_team = t
    if p.of ~= nil then
      local x, e = X.team_ref(p.of, m)
      if not x then return nil, "of: " .. e end
      src_team = x
    end
    local cur = TC.uint(X.tc:info(src_team), TI.KIT) or 0
    local home = p.home ~= nil and T.id(p.home) or cur
    local away = p.away ~= nil and T.id(p.away) or home
    local keeper = p.keeper ~= nil and T.id(p.keeper) or home
    local key = X.tc:key_of(t) .. "_te_kit"
    local u, e = X.uniform()
    if not u then return nil, e end
    local li, e1 = u:list("m_UniformInfoList")
    if not li then return nil, e1 end
    local lm, e2 = u:list("m_UniformModelInfoList")
    if not lm then return nil, e2 end
    local nli = u:len(li)
    local function slice_of(id)
      local r
      for i = 0, nli - 1 do
        if u:u32(li, i, 0) == id then r = i break end
      end
      if not r then return nil, "unknown kit " .. T.hex(id) .. " (not in uniform_config)" end
      local s, n = u:tuple(li, r, 1)
      if not s or n <= 0 then return nil, "kit " .. T.hex(id) .. " has no model rows" end
      return { s, n }
    end
    local home_s, x1 = slice_of(home)
    if not home_s then return nil, x1 end
    local away_s, x2 = slice_of(away)
    if not away_s then return nil, x2 end
    local keeper_s, x3 = slice_of(keeper)
    if not keeper_s then return nil, x3 end
    local fnames = u:fields(lm)
    local keeper_f, type_f = {}, nil
    for i, n in ipairs(fnames) do
      if n:lower():find("keeper", 1, true) then keeper_f[#keeper_f + 1] = i - 1 end
      if type_f == nil and n == "typeId" then type_f = i - 1 end
    end
    -- the model rows by typeId (0 = worn, 1 = the clash alternate), not by position
    local function pick(sl, ty)
      local s, n = sl[1], sl[2]
      if type_f then
        for r = s, s + n - 1 do
          if u:u32(lm, r, type_f) == ty then return r end
        end
      end
      local k = n - 1
      if k < 0 then k = 0 end
      return s + math.min(ty, k)
    end
    local flip = p.flip and 1 or 0
    local out = { u:copy(lm, pick(home_s, 0)), u:copy(lm, pick(away_s, 1)) }
    for k, sc in ipairs(out) do
      local src = pick(keeper_s, k - 1)
      for _, f in ipairs(keeper_f) do u:copy_field(-1, sc, f, lm, src) end
      if type_f then u:set_u32(-1, sc, type_f, bit32.bxor(k - 1, flip)) end
    end
    local ids = {}
    for i = 0, nli - 1 do
      local v = u:u32(li, i, 0)
      if v then ids[v] = true end
    end
    local id = X.probe_id(key, function(i) return ids[i] end)
    local start = u:len(lm)
    u:push(lm, out[1])
    u:push(lm, out[2])
    local info = u:copy(li, 0)
    u:set_u32(-1, info, 0, id)
    u:set_tuple(-1, info, 1, start, 2)
    u:push(li, info)
    -- the ex info (shoes / gloves / extra parts) of the home kit, when it has one
    local le = u:list("m_UniformExInfoList")
    local lx = u:list("m_UniformExModelInfoList")
    if le and lx then
      local r
      for i = 0, u:len(le) - 1 do
        if u:u32(le, i, 0) == home then r = i break end
      end
      if r then
        local s, n = u:tuple(le, r, 2)
        if s then
          local st = u:len(lx)
          u:extend_copy(lx, s, s + n)
          local ex = u:copy(le, r)
          u:set_u32(-1, ex, 0, id)
          u:set_tuple(-1, ex, 2, st, n)
          u:push(le, ex)
        end
      end
    end
    u:touch()
    X.touched.uniform = true
    return id
  end

  -- vr_framework::ids::probe_id: crc32(key), then crc32("<key>#1"), … until not taken (nor 0 / 0xFFFFFFFF)
  function X.probe_id(key, taken)
    local id = VRFW.crc32(key)
    local i = 1
    while taken(id) or id == 0 or id == 4294967295 do
      id = VRFW.crc32(key .. "#" .. i)
      i = i + 1
    end
    return id
  end

  -- ------------------------------------------------------------------------------------------------ emblems

  function X.emblem_exists(id)
    local item, e = X.item()
    if not item then return nil, e end
    return item:find("ITEM_EMBLEM_INFO", X.EM.ID, id) ~= nil
  end

  -- every catalog number (col 4) of the named item rows (ITEM_*_INFO with a key in col 11)
  function X.catalog_numbers(t)
    local out = {}
    for i = 0, t:len() - 1 do
      local n = t:name(i)
      if n and T.starts(n, "ITEM_") and T.ends(n, "_INFO") and (t:width(i) or 0) > 11 and t:str(i, 11) then
        local c = t:int(i, 4)
        if c and c >= 0 then out[c] = true end
      end
    end
    return out
  end

  -- the catalog numbers the item table holds now (read once, then this build's emblems added)
  function X.catalog_now()
    if not X.cat_now then
      local item = X.item()
      X.cat_now = X.catalog_numbers(item)
    end
    return X.cat_now
  end

  -- the game's own numbers: the GAME's item_config catalog numbers / chronicle_vs_route_config slots
  function X.retail()
    if X.retail_v then return X.retail_v end
    local r = {}
    local k, e = X.table_key("data/common/gamedata/item/item_config_")
    if k then
      local g, e2 = VRFW.rows.game(k)
      if g then r.catalog = X.catalog_numbers(g) else r.catalog_err = e2 end
    else
      r.catalog_err = e
    end
    local k2, e3 = X.table_key("data/common/gamedata/vsroute/chronicle_vs_route_config_")
    if k2 then
      local rr, e4 = VRFW.team.rdbn(k2, true)
      if rr then
        local s, e5 = X.board_slots(rr)
        if s then r.route_slots = s else r.route_slots_err = e5 end
      else
        r.route_slots_err = e4
      end
    else
      r.route_slots_err = e3
    end
    X.retail_v = r
    return r
  end

  -- the catalog number of a new emblem item: `shared` = the last bit; `unique` = the deterministic number of `nkey`
  -- in the range above the GAME's item_config, skipping the numbers the merged base uses (as read the first time)
  function X.emblem_catalog(used, mode, nkey)
    if mode == "shared" then return CATALOG_SHARED end
    if not X.cat_used then X.cat_used = T.copy(used) end
    local base = X.cat_used
    local ret = X.retail()
    if not ret.catalog then return nil, "the game's item_config: " .. ret.catalog_err end
    local below = {}
    for n in pairs(ret.catalog) do if n < CATALOG_SHARED then below[n] = true end end
    local lo, hi = VRFW.ids.free_above(below, CATALOG_SHARED)
    local n, w = VRFW.ids.next(CATALOG_SPACE, nkey, base, lo, hi, 1) -- full: the holes below the game's numbers
    if w then VRFW.log.warn(w) end
    if not n then
      return nil, string.format("no free emblem catalog number (%d-%d nor a free one below); a team-only crest can use `catalog = \"shared\"`", lo, (hi > 0) and (hi - 1) or 0)
    end
    -- MIGRATION ONLY: the old rule (8150.., in build order) for old saves
    for c = LEGACY_CATALOG_FROM, CATALOG_SHARED - 1 do
      if not base[c] and not X.cat_legacy[c] then
        X.cat_legacy[c] = true
        VRFW.ids.legacy(CATALOG_SPACE, nkey, c)
        break
      end
    end
    return n
  end

  -- the `<mod>.<name>` key of team `t` for its numbers: a new team's own key, else `<mod>.<game key>`
  function X.number_key(m, t)
    local tkey = X.tc:key_of(t)
    local c = X.created_by_internal[tkey]
    if c then return c.key end
    return m .. "." .. tkey
  end

  -- a new emblem item from a PNG of the mod (its textures = the PNG fitted into every texture file of `base`)
  -- where a PNG emblem's picture is: `png = "<path>"` = a file of the declaring mod; `png = "<mod id>:<path>"` = a
  -- file of another mod (e.g. Chronicles Deluxe's remastered crests). That mod not active -> nil: the team keeps the
  -- emblem it has (its base's / retail crest), never an error; a missing file of an active mod stays an error.
  function X.emblem_png_source(m, png)
    local other, rel = tostring(png):match("^([%w_]+):(.+)$")
    if other == nil then return m, png end
    if VRFW.team.mod_file(other, rel) == nil then return nil end
    return other, rel
  end

  -- returns the item id; nil, err on an error; nil, nil when the picture's mod is absent (keep the emblem)
  function X.emblem_png(m, t, p)
    local src, rel = X.emblem_png_source(m, p.png)
    if src == nil then return nil, nil end
    local img, e = VRFW.team.png(src, rel)
    if not img then return nil, e end
    local base = p.base ~= nil and T.id(p.base) or (TC.uint(X.tc:info(t), TI.EMBLEM) or 0)
    return X.emblem_from_image(t, img, base, false, p.catalog or "unique", X.number_key(m, t) .. "#emblem")
  end

  -- the retail letter-badge crests: the emblem key `<base>` whose one-letter variants are emblems too (the most
  -- letters, then the lowest key) and its letters in order
  function X.badge_crests(item)
    local keys = {}
    for _, i in ipairs(item:rows("ITEM_EMBLEM_INFO")) do
      local k = item:str(i, X.EM.KEY)
      if k then keys[k] = true end
    end
    local by_base = {}
    for _, k in ipairs(T.keys(keys)) do
      local l = k:sub(-1)
      if l:find("^[a-z]$") then
        local base = k:sub(1, -2)
        if keys[base] then
          by_base[base] = by_base[base] or {}
          table.insert(by_base[base], l)
        end
      end
    end
    local best, bl
    for _, b in ipairs(T.keys(by_base)) do
      local n = #by_base[b]
      -- max by (letters, then the LOWER key): the first of equal counts in key order
      if best == nil or n > #bl then best, bl = b, by_base[b] end
    end
    if best == nil then return nil, "item_config has no lettered emblem (`<emblem>a`, `<emblem>b`, …) to take a badge from" end
    return best, bl
  end

  function X.emblem_badge(m, t, letter)
    local base = TC.uint(X.tc:info(t), TI.EMBLEM) or 0
    local item, e = X.item()
    if not item then return nil, e end
    local badge_base, letters = X.badge_crests(item)
    if not badge_base then return nil, letters end
    local l = T.trim(letter):lower()
    if #l ~= 1 or not T.contains(letters, l) then
      return nil, "no badge for `" .. T.trim(letter) .. "` (the game has the letters " .. table.concat(letters, ", "):upper() .. ")"
    end
    local src = badge_base .. l
    local i = item:find("ITEM_EMBLEM_INFO", X.EM.ID, base)
    if not i then return nil, "the team's emblem " .. T.hex(base) .. " is not in item_config" end
    local base_key = item:str(i, X.EM.KEY)
    if not base_key then return nil, "the emblem row has no key" end
    local img, e2 = VRFW.team.badge_image(base_key, badge_base, src)
    if not img then return nil, e2 end
    return X.emblem_from_image(t, img, base, true, "unique", X.number_key(m, t) .. "#badge")
  end

  -- a new emblem item (key `em97NNNN`) whose textures are picture `img` fitted into every texture file of emblem `base`;
  -- `keep_name`: the item keeps `base`'s name text (else the team's, crc32("<key>_emblem"))
  function X.emblem_from_image(t, img, base, keep_name, catalog, nkey)
    local tkey = X.tc:key_of(t)
    local mark = VRFW.crc32(tkey .. "_emblem")
    local item, e = X.item()
    if not item then return nil, e end
    local src = item:find("ITEM_EMBLEM_INFO", X.EM.ID, base)
    if not src then return nil, "base emblem " .. T.hex(base) .. " is not in item_config" end
    local base_key = item:str(src, X.EM.KEY)
    if not base_key then return nil, "the base emblem row has no key" end
    local keys = {}
    for _, i in ipairs(item:rows("ITEM_EMBLEM_INFO")) do
      local k = item:str(i, X.EM.KEY)
      if k then keys[k] = true end
    end
    local n = X.probe_id(tkey .. "#emblem", function(i) return keys["em97" .. T.pad(i % 10000, 4)] end) % 10000
    local new_key = "em97" .. T.pad(n, 4)
    local used_cat = X.catalog_now()
    local cat, e2 = X.emblem_catalog(used_cat, catalog, nkey)
    if not cat then return nil, e2 end
    local hs = VRFW.crc32("ITEM_EMBLEM_INFO_SERIES")
    local j = src + 1
    while j < item:len() and item:hash(j) == hs do j = j + 1 end
    local rows = item:entries(src, j)
    local v = rows[1].values
    TC.set_int(v, X.EM.ID, VRFW.crc32(new_key))
    if not keep_name then TC.set_int(v, X.EM.NAME, mark) end
    TC.set_int(v, X.EM.DESC, 0)
    TC.set_int(v, X.EM.CATALOG, cat)
    v[X.EM.KEY + 1] = new_key
    if #v > 14 then TC.set_int(v, X.EM.BASE, 0) end
    local ok, e3 = C.try(item.append_rows, item, "ITEM_EMBLEM_INFO", { "ITEM_EMBLEM_INFO", "ITEM_EMBLEM_INFO_SERIES" }, rows, 1)
    if not ok then return nil, e3 end
    if cat >= 0 then X.cat_now[cat] = true end
    X.touched.item = true
    -- textures: every file of the base emblem (<key>.g4tx, _s, _s01, a, a_s …), pixels from the picture
    local okt, e4 = VRFW.team.emblem_textures(img, base_key, new_key)
    if not okt then return nil, e4 end
    return VRFW.crc32(new_key)
  end

  -- ------------------------------------------------------------------------------------------------ new teams

  function X.create(m, file, d, file_default)
    local key, e0 = VRFW.ids.own(m, d.name)
    if not key then return e0 end
    if X.created[key] then return "`" .. key .. "` is declared twice (the first is kept)" end
    local tc = X.tc
    local base
    if d.based_on ~= nil then
      local b, e = X.team_ref(d.based_on, m)
      if not b then return "based_on: " .. e end
      base = b
    end
    local tpl = base
    if tpl == nil then
      for t = 0, #tc.teams - 1 do
        local _, n = tc:slice(t, 0)
        if n == X.D.template_rows then tpl = t break end
      end
      if tpl == nil then
        return string.format("team_config has no team with %d member rows (the shape of an empty team)", X.D.template_rows)
      end
    end
    if base == nil and (d.formation == nil or d.kit == nil or d.emblem == nil or #(d.member or {}) == 0) then
      return "a team without `based_on` needs `formation`, `kit`, `emblem` and its `[[team.member]]` rows"
    end
    local exact = d.roster == "exact"
    if exact and #(d.member or {}) == 0 then return "roster = \"exact\" needs its [[team.member]] rows" end
    -- ids: key evt_te_NNNNNN (id = crc32(key), the game's rule), name text crc32(key + "_name"); or the mod's key
    local internal
    if d.key ~= nil then
      local k = T.trim(d.key)
      if k == "" or not k:find("^[A-Za-z0-9_]+$") then return "key `" .. k .. "`: a game key is a-z A-Z 0-9 _" end
      if tc:find_key(k) ~= nil or tc:find(VRFW.crc32(k)) ~= nil then
        return "key `" .. k .. "` (id " .. T.hex(VRFW.crc32(k)) .. ") is already a team of team_config"
      end
      internal = k
    else
      local n = VRFW.team.assign(key .. "#team", function(i)
        local k = "evt_te_" .. T.pad(i % 1000000, 6)
        return tc.by_key[k] ~= nil or tc.by_id[VRFW.crc32(k)] ~= nil
      end)
      internal = "evt_te_" .. T.pad(n % 1000000, 6)
    end
    local tid = VRFW.crc32(internal)
    local name_id = d.name_text ~= nil and T.id(d.name_text) or VRFW.crc32(internal .. "_name")
    local info, refs = tc:team_copy(tpl)
    TC.set_int(info, TI.ID, tid)
    info[TI.KEY + 1] = internal
    TC.set_int(info, TI.NAME, name_id)
    if base == nil then
      TC.set_int(info, TI.DESC, 0)
      refs[2] = { 0, 0 }
      refs[3] = { 0, 0 }
    end
    if d.description ~= nil then TC.set_int(info, TI.DESC, T.id(d.description)) end
    if not (base ~= nil and d.keep_metamorphose == true) then refs[4] = { 0, 0 } end
    local start = #tc.members
    local what = file .. ": " .. key
    if exact then
      -- the declared rows, in order, each from its own keys only
      local errs = {}
      local rows = X.exact_rows(m, internal, d.member, errs)
      if #errs > 0 then return table.concat(errs, "; ") end
      refs[1] = { start, #rows }
      for _, r in ipairs(rows) do tc.members[#tc.members + 1] = r end
    else
      -- its own member slice: the base's rows (a new team's roster replaces them below)
      local s, e = tc:member_range(tpl)
      local rows = {}
      if base ~= nil then
        for i = s, e - 1 do
          local x = tc:member(i)
          rows[#rows + 1] = { m = TC.copy_row(x.m), r = TC.copy_row(x.r) }
        end
      end
      refs[1] = { start, #rows }
      if base == nil then
        -- shape of the new rows: the template's first member (nothing of its occupant is kept)
        local p = tc.members[s + 1]
        if p then
          tc.members[#tc.members + 1] = { m = TC.copy_row(p.m), r = TC.copy_row(p.r) }
          refs[1] = { start, 1 }
        end
      else
        for _, r in ipairs(rows) do tc.members[#tc.members + 1] = r end
      end
    end
    tc:push_team(info, refs)
    local t = #tc.teams - 1
    local c = { key = key, mod_id = m, internal = internal, id = tid, name_text = name_id, emblem = 0, kit = 0, series = "",
      names = {}, short = {} }
    X.created[key] = c
    X.created_by_id[tid] = c
    X.created_by_internal[internal] = c
    if base ~= nil then X.based_on[tid] = tc:id_of(base) end
    -- `same_as` (a team key or a list): the teams this one IS for identity, whatever its roster (the BB unlock rule's
    -- identity match, bb.lua X.bb_roots): a chain rival re-rostered from another game names the BB team it stands for
    -- instead of being matched by its shown name (2026-10-13)
    if d.same_as ~= nil then
      for _, ref in ipairs(type(d.same_as) == "table" and d.same_as or { d.same_as }) do
        local b, e = X.team_ref(ref, m)
        if b then
          X.same_as[tid] = X.same_as[tid] or {}
          table.insert(X.same_as[tid], tc:id_of(b))
        else
          VRFW.log.warn(string.format("mods/%s/%s: team %s: same_as %s: %s (ignored)", m, tostring(file), key, tostring(ref), tostring(e)))
        end
      end
    end
    local fd = d.default_lang or file_default
    X.full_roster = base == nil
    local fields = T.copy(d)
    if exact then
      -- the roster is written: the roster keys only mark / check it
      fields.member = {}
      for _, sw in ipairs { { SLOT_COACH, fields.coach }, { SLOT_MANAGER, fields.manager } } do
        if sw[2] ~= nil then
          VRFW.log.error(string.format("%s: roster = \"exact\": write the coach / manager as a [[team.member]] row of slot %d (`coach` / `manager` ignored)", what, sw[1]))
        end
      end
      if fields.captain ~= nil then
        VRFW.log.error(what .. ": roster = \"exact\": mark the captain with `captain = true` on its [[team.member]] row (`captain` ignored)")
      end
      fields.coach, fields.manager, fields.captain = nil, nil, nil
      X.full_roster = false
    end
    X.apply(m, file, what, t, fields, fd, true)
    t = tc:find(tid)
    if t == nil then return "row gone" end
    local meta = X.meta[tid] or X.new_meta()
    -- a `name_text` (or, with a fixed `key`, its default `<key>_name` row) names the team through a text row the
    -- game or the mod's text rows have
    if T.is_empty(meta.names) and d.name_text == nil and d.key == nil then
      VRFW.log.warn(what .. ": no [team.text.<lang>] name nor name_text: the new team shows no name")
    end
    local emb, kit = TC.uint(tc:info(t), TI.EMBLEM) or 0, TC.uint(tc:info(t), TI.KIT) or 0
    -- a PNG emblem's item name = the team's name
    if type(d.emblem) == "table" and not T.is_empty(meta.names) and X.emblem_png_source(m, d.emblem.png) ~= nil then
      local mark = VRFW.crc32(internal .. "_emblem")
      X.push_text(m, meta.default_lang, { table = "item_text", id = mark, variant = 0, texts = T.copy(meta.names), add = true,
        origin = what .. ": emblem (" .. m .. ")", kind = "noun" })
    end
    c.emblem, c.kit = emb, kit
    c.series = meta.series or ""
    c.names = T.copy(meta.names)
    c.short = T.copy(meta.short)
    return nil
  end
end

return C
