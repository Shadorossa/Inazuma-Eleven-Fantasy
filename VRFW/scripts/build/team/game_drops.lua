-- `[[VRFW.GameDrops]]` (docs/framework/drops.md): the in-match drop tables of a game's difficulty rows,
-- `item_drop_table` (col 30: rarity -> percent per roll, soccer_drop_config m_itemDropTableList) and
-- `item_table_decide` (col 36: rarity -> loot table, m_itemTableDecideTableList) and the player-spirit drops
-- (col 29 m_spiritCharaTableList: players added to the rival's; cols 31 / 33 m_spiritDropTableList: spirit rarity ->
-- percent per roll, 0 = the engine's default of the difficulty), the first-clear prize (col 34 `FirstClear`, a
-- soccer_prize_config ITBL id; VRFW 2.4.31); then [[VRFW.SpiritDrops]] (cols 31 / 33 by
-- difficulty for every row a GameDrops set; docs/framework/drops.md §1b). Run after the route nodes, the
-- chains and the level maps, so every game the team build makes (`evt_rn_<name>`, `evt_ch_<chain>_<NN>`) can be named.
-- Mechanism only: which tables a game gets is the declaring mod's data (e.g. Chronicles Deluxe's generated
-- content\teams\80_drops\chronicle_drops.toml). The tables themselves are the mods' base tables (soccer_drop_config,
-- win_treasure_lot_table_config); an id the served soccer_drop_config does not hold is an error (row left as it was).
local T = require "lib/team_util"
local GD = {}

local DROP_PREFIX = "data/common/gamedata/soccer/soccer_drop_config_"

-- the ids of the item-drop tables and decide tables of the served soccer_drop_config (nil, err when unreadable)
local function drop_ids(X)
  if X.gd_ids ~= nil then return X.gd_ids, X.gd_err end
  local k, e = X.table_key(DROP_PREFIX)
  local ids
  if k then
    local h, he = VRFW.team.rdbn(k)
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
    else
      e = he
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
  function X.game_drops(files)
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
    X.spirit_drops(files, set_rows, order)
  end

  -- every file's [[VRFW.SpiritDrops]] (load order) over the rows GameDrops set
  function X.spirit_drops(files, set_rows, order)
    local applied, rows_set = 0, 0
    local g, SG = X.games_t, X.SG
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
        if not active then
          VRFW.log.info(what .. ": if_mod " .. req .. " is not active (skipped)")
        elseif rows_kind ~= "game_drops" and rows_kind ~= "all" then
          VRFW.log.error(what .. ": Rows \"" .. rows_kind .. "\": \"game_drops\" or \"all\" (skipped)")
        elseif a == false or b == false or c == false then
          VRFW.log.error(what .. ": " .. tostring(ae or be or ce) .. " (skipped)")
        elseif a == nil and b == nil and c == nil then
          VRFW.log.error(what .. ": none of SpiritChara, SpiritDrop, SpiritDrop2 (skipped)")
        else
          local want
          if d.difficulties and #d.difficulties > 0 then
            want = {}
            for _, x in ipairs(d.difficulties) do want[x] = true end
          end
          local list, own = order, set_rows
          if rows_kind == "all" then list, own = g:rows("SOCCER_GAME_DIFFICULTY"), {} end
          local n = 0
          for _, i in ipairs(list) do
            if want == nil or want[g:int(i, SG.D_DIFF)] then
              local o = own[i] or { false, false }
              if c ~= nil then g:set(i, SG.D_SPIRIT_DROP, T.i32(c)) end
              if a ~= nil and not o[1] then g:set(i, SG.D_SPIRIT_TABLE, T.i32(a)) end
              if b ~= nil and not o[2] then g:set(i, SG.D_SPIRIT_TABLE_2, T.i32(b)) end
              n = n + 1
            end
          end
          if n > 0 then g:touch() end
          applied = applied + 1
          rows_set = rows_set + n
        end
      end
    end
    if applied > 0 then
      VRFW.log.info(string.format("SpiritDrops: %d rule(s), %d difficulty row(s) given spirit tables", applied, rows_set))
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
