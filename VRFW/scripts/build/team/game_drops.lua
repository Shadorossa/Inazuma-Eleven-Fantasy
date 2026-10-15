-- `[[VRFW.GameDrops]]`: in-match drop tables per difficulty row: `item_drop_table` (col 30, rarity -> percent per roll), `item_table_decide` (col 36, rarity -> loot table),
-- player-spirit drops (col 29 added players; cols 31 / 33 spirit rarity -> percent per roll, 0 = engine default) and the first-clear prize (col 34 `FirstClear`, soccer_prize_config ITBL id).
-- Then `[[VRFW.SpiritDrops]]` (cols 29 / 31 / 33 by difficulty for a set of rows) and its `ExcludeRarities` (spirit tables replaced by copies without those rarities).
-- Runs after route nodes, chains and level maps so every team-build game can be named; an id missing from the served soccer_drop_config is an error (row left as it was).
local T = require "lib/team_util"
local GD = {}

local DROP_PREFIX = "data/common/gamedata/soccer/soccer_drop_config_"
-- difficulty rows of the Chronicle board; rows 6-9 of the same games belong to the free match
local CHRONICLE_DIFFS = { [1] = true, [2] = true, [3] = true, [4] = true, [10] = true, [11] = true }

-- spirit drop tables the engine uses for a row whose col 31 / 33 is 0
local function engine_default_spirit_tables(diff)
  if diff == 1 or (diff >= 6 and diff <= 9) then return 0x26F1316F, 0xD3AF6694 end
  if diff == 2 then return 0xBFF860D5, 0x4AA6372E end
  if diff == 4 then return 0x569BC5E0, 0xA3C5921B end
  if diff == 10 or diff == 11 then return 0x219CF576, 0xD4C2A28D end
  return 0xC8FF5043, 0x3DA107B8
end

-- the id of the copy of spirit table `table` without `rarities` (sorted, unique)
local function spirit_table_without_id(tbl, rarities)
  local parts = {}
  for _, r in ipairs(rarities) do parts[#parts + 1] = string.format("%d", r) end
  return VRFW.ids.parse(string.format("vrfw.spirit_drop_table.%s.without_rarities.%s", T.hex8(tbl), table.concat(parts, "_")))
end

-- the ids of the item-drop tables and decide tables of the served soccer_drop_config (nil, err when unreadable)
-- the served soccer_drop_config (opened once), or nil, err
local function drop_config(X)
  if X.gd_rd ~= nil then return X.gd_rd or nil, X.gd_rd_err end
  local k, e = X.table_key(DROP_PREFIX)
  local h
  if k then h, e = VRFW.team.rdbn(k) end
  X.gd_rd, X.gd_rd_err = h or false, e
  return h, e
end

local function drop_ids(X)
  if X.gd_ids ~= nil then return X.gd_ids, X.gd_err end
  local ids
  local h, e = drop_config(X)
  do
    if h then
      ids = { item = {}, decide = {}, spirit = {}, chara = {} }
      for _, x in ipairs { { "m_itemDropTableList", ids.item }, { "m_itemTableDecideTableList", ids.decide },
          { "m_spiritDropTableList", ids.spirit }, { "m_spiritCharaTableList", ids.chara } } do
        local li = h:list(x[1])
        local f = li and h:field(li, "id")
        if li and f then
          for _, v in ipairs(h:col_u32(li, f)) do
            if v then x[2][v] = true end
          end
        end
      end
    end
  end
  X.gd_ids, X.gd_err = ids or false, e
  return X.gd_ids, X.gd_err
end

-- a table reference of a declaration: nil (absent), the id (0 allowed), or false, err
local function ref(X, s, set, key, list)
  if s == nil then return nil end
  local ids, ie = drop_ids(X)
  if not ids then return false, "soccer_drop_config: " .. tostring(ie) end
  local id = T.id(T.trim(s))
  if id ~= 0 and not ids[set][id] then
    return false, key .. " " .. s .. " (" .. T.hex(id) .. ") is not an " .. list .. " table"
  end
  return id
end

function GD.install(X)
  function X.game_drops(files, chains)
    local applied, rows_set = 0, 0
    local set_rows, order = {}, {}       -- row -> { own SpiritDrop, own SpiritDrop2 }
    for _, f in ipairs(files) do
      for k0, d in ipairs(f.value.vrfw.GameDrops or {}) do
        local what = f.file .. ": GameDrops[" .. (k0 - 1) .. "] " .. tostring(d.game)
        local req = d.if_mod and T.trim(d.if_mod) or ""
        local active = req == ""
        for _, m in ipairs(X.mods) do if m.id == req then active = true break end end
        if not active then
          VRFW.log.info(what .. ": if_mod " .. req .. " is not active (skipped)")
        else
          local ok, e = X.game_drop(d, what)
          if ok then
            applied = applied + 1
            rows_set = rows_set + #ok
            for _, i in ipairs(ok) do
              if not set_rows[i] then set_rows[i] = { false, false } order[#order + 1] = i end
              set_rows[i][1] = set_rows[i][1] or d.spirit_drop ~= nil
              set_rows[i][2] = set_rows[i][2] or d.spirit_drop_2 ~= nil
            end
          else
            VRFW.log.error(what .. ": " .. e .. " (skipped)")
          end
        end
      end
    end
    if applied > 0 then
      VRFW.log.info(string.format("GameDrops: %d declaration(s), %d difficulty row(s) given their drop tables", applied, rows_set))
    end
    X.spirit_drops(files, set_rows, order, chains)
  end

  -- difficulty rows of every Chronicle match: board difficulty rows of every game with a match piece (eventType 0 / 5) in chronicle_vs_route_config,
  -- plus every row of every chain game; sorted row indices, or nil, err
  function X.chronicle_rows(chains)
    local r, pl, el = X.route_lists()
    if not r then return nil, pl end
    local rl, e0 = r:list("m_chronicleVsRouteInfoList")
    if not rl then return nil, e0 end
    local fev, e1 = r:field(pl, "eventType")
    if not fev then return nil, e1 end
    local fref, e2 = r:field(pl, "eventInfoRef")
    if not fref then return nil, e2 end
    local fg, e3 = r:field(el, "paramCrc1")
    if not fg then return nil, e3 end
    local fslice, e4 = r:field(rl, "pieceInfo")
    if not fslice then return nil, e4 end
    local board, chain = {}, {}
    for k = 0, r:len(rl) - 1 do
      local s, n = r:tuple(rl, k, fslice)
      if s ~= nil then
        for i = s, s + n - 1 do
          local ev = r:u32(pl, i, fev)
          if ev == 0 or ev == 5 then
            local a, b = r:tuple(pl, i, fref)
            if a == nil then a, b = 0, 0 end
            for j = a, a + b - 1 do
              local g = r:u32(el, j, fg)
              if g and g ~= 0 then board[g] = true end
            end
          end
        end
      end
    end
    for _, c in ipairs(chains or {}) do
      for _, n in ipairs(c.nodes or {}) do
        if n.game and n.game ~= 0 then chain[n.game] = true end
      end
      for _, t in ipairs(c.board and c.board.tiles or {}) do
        if t.kind == "match" and t.game and t.game ~= 0 then chain[t.game] = true end
      end
    end
    local g, ge = X.games()
    if not g then return nil, ge end
    local out, seen = {}, {}
    local function add(i)
      if not seen[i] then seen[i] = true out[#out + 1] = i end
    end
    for _, gid in ipairs(T.keys(chain)) do
      local rows = X.game_rows(gid)
      for _, i in pairs(rows or {}) do add(i) end
    end
    for _, gid in ipairs(T.keys(board)) do
      if not chain[gid] then
        local rows = X.game_rows(gid)
        for d, i in pairs(rows or {}) do
          if CHRONICLE_DIFFS[d] then add(i) end
        end
      end
    end
    table.sort(out)
    return out
  end

  -- copy of spirit table `tbl` without the entries of `rarities`, added to soccer_drop_config once; false = no such entry; nil, err
  function X.spirit_table_without(tbl, rarities)
    local copy_id = spirit_table_without_id(tbl, rarities)
    local r, re = drop_config(X)
    if not r then return nil, "soccer_drop_config: " .. tostring(re) end
    local tl, e1 = r:list("m_spiritDropTableList")
    if not tl then return nil, e1 end
    local dl, e2 = r:list("m_spiritDropDataList")
    if not dl then return nil, e2 end
    local fid, e3 = r:field(tl, "id")
    if not fid then return nil, e3 end
    local fdata, e4 = r:field(tl, "data")
    if not fdata then return nil, e4 end
    local frarity, e5 = r:field(dl, "rarity")
    if not frarity then return nil, e5 end
    local ids = r:col_u32(tl, fid)
    local t
    for k = 1, #ids do
      if ids[k] == tbl then t = k - 1 break end
    end
    if t == nil then return nil, "spirit drop table " .. T.hex(tbl) .. " is not in m_spiritDropTableList" end
    local excluded = {}
    for _, x in ipairs(rarities) do excluded[x] = true end
    local s, n = r:tuple(tl, t, fdata)
    if s == nil then s, n = 0, 0 end
    local kept = {}
    for k = s, s + n - 1 do
      local x = r:u32(dl, k, frarity)
      if x == nil or not excluded[T.i32(x)] then kept[#kept + 1] = k end
    end
    if #kept == n then return false end
    for k = 1, #ids do
      if ids[k] == copy_id then return copy_id end
    end
    local start = r:len(dl)
    if start + #kept > 30000 then
      return nil, string.format("m_spiritDropDataList would pass 30000 rows (%d + %d)", start, #kept)
    end
    for _, k in ipairs(kept) do r:push(dl, r:copy(dl, k)) end
    local sc = r:copy(tl, t)
    r:set_u32(-1, sc, fid, copy_id)
    if #kept == 0 then r:set_tuple(-1, sc, fdata, 0, 0) else r:set_tuple(-1, sc, fdata, start, #kept) end
    r:push(tl, sc)
    r:touch()
    return copy_id
  end

  -- ExcludeRarities over `rows`: rows changed, tables made ({ table, copy }), or nil, err
  function X.exclude_spirit_rarities(rows, rarities)
    local g, SG = X.games_t, X.SG
    local copies, made, changed = {}, {}, 0
    for _, i in ipairs(rows) do
      local diff = g:int(i, SG.D_DIFF)
      if diff ~= nil then
        local da, db = engine_default_spirit_tables(diff)
        local row_changed = false
        for _, x in ipairs { { SG.D_SPIRIT_TABLE, da }, { SG.D_SPIRIT_TABLE_2, db } } do
          local value = (g:int(i, x[1]) or 0) % 4294967296
          local tbl = value == 0 and x[2] or value
          local copy = copies[tbl]
          if copy == nil then
            local c, ce = X.spirit_table_without(tbl, rarities)
            if c == nil then return nil, ce end
            if c then made[#made + 1] = { tbl, c } end
            copies[tbl] = c
            copy = c
          end
          if copy and copy ~= value then
            g:set(i, x[1], T.i32(copy))
            row_changed = true
          end
        end
        if row_changed then changed = changed + 1 end
      end
    end
    if changed > 0 then g:touch() end
    return changed, made
  end

  -- every file's [[VRFW.SpiritDrops]] (load order): first every rule's tables, then every rule's ExcludeRarities
  function X.spirit_drops(files, set_rows, order, chains)
    local applied, rows_set = 0, 0
    local g, SG = X.games_t, X.SG
    local chronicle, chronicle_err
    local exclusions = {}
    for _, f in ipairs(files) do
      for k0, d in ipairs(f.value.vrfw.SpiritDrops or {}) do
        local what = f.file .. ": SpiritDrops[" .. (k0 - 1) .. "]"
        local req = d.if_mod and T.trim(d.if_mod) or ""
        local active = req == ""
        for _, m in ipairs(X.mods) do if m.id == req then active = true break end end
        local c, ce = ref(X, d.spirit_chara, "chara", "SpiritChara", "m_spiritCharaTableList")
        local a, ae = ref(X, d.spirit_drop, "spirit", "SpiritDrop", "m_spiritDropTableList")
        local b, be = ref(X, d.spirit_drop_2, "spirit", "SpiritDrop2", "m_spiritDropTableList")
        local rows_kind = d.rows and T.trim(d.rows) or "game_drops"
        local exclude = d.exclude_rarities or {}
        local bad_rarity
        for _, x in ipairs(exclude) do
          if type(x) ~= "number" or x < 0 or x > 255 then bad_rarity = x break end
        end
        if not active then
          VRFW.log.info(what .. ": if_mod " .. req .. " is not active (skipped)")
        elseif rows_kind ~= "game_drops" and rows_kind ~= "all" and rows_kind ~= "chronicle" then
          VRFW.log.error(what .. ": Rows \"" .. rows_kind .. "\": \"game_drops\", \"all\" or \"chronicle\" (skipped)")
        elseif a == false or b == false or c == false then
          VRFW.log.error(what .. ": " .. tostring(ae or be or ce) .. " (skipped)")
        elseif a == nil and b == nil and c == nil and #exclude == 0 then
          VRFW.log.error(what .. ": none of SpiritChara, SpiritDrop, SpiritDrop2, ExcludeRarities (skipped)")
        elseif bad_rarity ~= nil then
          VRFW.log.error(what .. ": ExcludeRarities: " .. tostring(bad_rarity) .. " is not a spirit rarity (0-255) (skipped)")
        else
          local want
          if d.difficulties and #d.difficulties > 0 then
            want = {}
            for _, x in ipairs(d.difficulties) do want[x] = true end
          end
          local list, own = order, set_rows
          local list_err
          if rows_kind == "all" then
            list, own = g:rows("SOCCER_GAME_DIFFICULTY"), {}
          elseif rows_kind == "chronicle" then
            if chronicle == nil and chronicle_err == nil then
              chronicle, chronicle_err = X.chronicle_rows(chains)
              if chronicle == nil and chronicle_err == nil then chronicle_err = "no Chronicle rows" end
            end
            list, list_err = chronicle, chronicle_err
          end
          if list == nil then
            VRFW.log.error(what .. ": " .. tostring(list_err) .. " (skipped)")
          else
            local sets_tables = a ~= nil or b ~= nil or c ~= nil
            local n, covered = 0, {}
            for _, i in ipairs(list) do
              if want == nil or want[g:int(i, SG.D_DIFF)] then
                covered[#covered + 1] = i
                if sets_tables then
                  local o = own[i] or { false, false }
                  if c ~= nil then g:set(i, SG.D_SPIRIT_DROP, T.i32(c)) end
                  if a ~= nil and not o[1] then g:set(i, SG.D_SPIRIT_TABLE, T.i32(a)) end
                  if b ~= nil and not o[2] then g:set(i, SG.D_SPIRIT_TABLE_2, T.i32(b)) end
                  n = n + 1
                end
              end
            end
            if n > 0 then g:touch() end
            applied = applied + 1
            rows_set = rows_set + n
            if #exclude > 0 then
              local rarities, seen = {}, {}
              for _, x in ipairs(exclude) do
                if not seen[x] then seen[x] = true rarities[#rarities + 1] = x end
              end
              table.sort(rarities)
              exclusions[#exclusions + 1] = { what = what, rows = covered, rarities = rarities }
            end
          end
        end
      end
    end
    if applied > 0 then
      VRFW.log.info(string.format("SpiritDrops: %d rule(s), %d difficulty row(s) given spirit tables", applied, rows_set))
    end
    for _, x in ipairs(exclusions) do
      local n, made = X.exclude_spirit_rarities(x.rows, x.rarities)
      if n == nil then
        VRFW.log.error(x.what .. ": ExcludeRarities: " .. tostring(made) .. " (skipped)")
      else
        local parts, rs = {}, {}
        for _, m in ipairs(made) do parts[#parts + 1] = T.hex(m[1]) .. " -> " .. T.hex(m[2]) end
        for _, r in ipairs(x.rarities) do rs[#rs + 1] = string.format("%d", r) end
        VRFW.log.info(string.format("%s: spirit rarities [%s] left out of the spirit drops of %d of its %d difficulty row(s) (%d table(s) without them%s)",
          x.what, table.concat(rs, ", "), n, #x.rows, #made, #parts > 0 and (": " .. table.concat(parts, ", ")) or ""))
      end
    end
  end

  -- one declaration: the rows set, or nil, err
  function X.game_drop(d, what)
    if d.item_drop == nil and d.decide == nil and d.spirit_chara == nil and d.spirit_drop == nil and d.spirit_drop_2 == nil and d.first_clear == nil then
      return nil, "none of ItemDrop, Decide, SpiritChara, SpiritDrop, SpiritDrop2, FirstClear"
    end
    local sc, sce = ref(X, d.spirit_chara, "chara", "SpiritChara", "m_spiritCharaTableList")
    if sc == false then return nil, sce end
    local sa, sae = ref(X, d.spirit_drop, "spirit", "SpiritDrop", "m_spiritDropTableList")
    if sa == false then return nil, sae end
    local sb, sbe = ref(X, d.spirit_drop_2, "spirit", "SpiritDrop2", "m_spiritDropTableList")
    if sb == false then return nil, sbe end
    local gid = T.id(T.trim(d.game))
    local rows, e = X.game_rows(gid)
    if not rows then return nil, e end
    local ids, ie = drop_ids(X)
    if not ids then return nil, "soccer_drop_config: " .. tostring(ie) end
    local item = d.item_drop ~= nil and T.id(T.trim(d.item_drop)) or nil
    local decide = d.decide ~= nil and T.id(T.trim(d.decide)) or nil
    -- col 34: the first-clear prize (a soccer_prize_config ITBL id; 0 = none), as a route node's FirstClear
    local first = d.first_clear ~= nil and T.id(T.trim(d.first_clear)) or nil
    if item ~= nil and item ~= 0 and not ids.item[item] then
      return nil, "ItemDrop " .. d.item_drop .. " (" .. T.hex(item) .. ") is not an m_itemDropTableList table"
    end
    if decide ~= nil and decide ~= 0 and not ids.decide[decide] then
      return nil, "Decide " .. d.decide .. " (" .. T.hex(decide) .. ") is not an m_itemTableDecideTableList table"
    end
    local want
    if d.difficulties ~= nil and #d.difficulties > 0 then
      want = {}
      for _, x in ipairs(d.difficulties) do want[x] = true end
    end
    local g = X.games_t
    local SG = X.SG
    local out = {}
    for _, diff in ipairs(T.keys(rows)) do
      if want == nil or want[diff] then
        local i = rows[diff]
        if item ~= nil then g:set(i, SG.D_ITEM_DROP, T.i32(item)) end
        if decide ~= nil then g:set(i, SG.D_DECIDE, T.i32(decide)) end
        if sc ~= nil then g:set(i, SG.D_SPIRIT_DROP, T.i32(sc)) end
        if sa ~= nil then g:set(i, SG.D_SPIRIT_TABLE, T.i32(sa)) end
        if sb ~= nil then g:set(i, SG.D_SPIRIT_TABLE_2, T.i32(sb)) end
        if first ~= nil then g:set(i, SG.D_FIRST_CLEAR, T.i32(first)) end
        out[#out + 1] = i
      end
    end
    if #out == 0 then return nil, "none of its difficulty rows is listed" end
    g:touch()
    return out
  end
end

return GD
