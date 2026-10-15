-- Free match: `[VRFW.FreeMatch]` rules (merged per key in load order), extra tabs `[[VRFW.FreeMatchTab]]` (numbered 9, 10, … and written as the routeType of their pieces), their difficulty rows / clear bits (`VRFW.Difficulties`) and class levels of every free-match game.
local T = require "lib/team_util"
local TC = require "team/tc"
local GAME_DIR = "data/common/gamedata/soccer/game/"
local FM = {}

-- the free-match classes (rows 6..9 of SOCCER_GAME_DIFFICULTY)
local CLASS_LO, CLASS_HI = 6, 9
-- the shared clear-bit number space
local CLEAR_SPACE = "vrfw.clear_bit"

-- `"<atlas>:<sprite>"` (atlas = everything before the last `:`)
local function banner(v)
  local a, s = T.rsplit_once(v, ":")
  if a == nil then return nil end
  if T.starts(a, "#/") and #a > 2 and s ~= "" and not s:find("/", 1, true) then return { a, s } end
  return nil
end

local function same_classes(a, b)
  if #a ~= #b then return false end
  for k = 1, #a do
    local x, y = a[k], b[k]
    if x.class ~= y.class or x.level ~= y.level then return false end
    if (x.banner == nil) ~= (y.banner == nil) then return false end
    if x.banner and (x.banner[1] ~= y.banner[1] or x.banner[2] ~= y.banner[2]) then return false end
  end
  return true
end

-- `[7 (Nv. 50), 8 (Nv. 125, banner atlas:sprite), 9]` for logs
local function describe(classes)
  local parts = {}
  for _, c in ipairs(classes) do
    local x = {}
    if c.level ~= nil then x[#x + 1] = "Nv. " .. c.level end
    if c.banner ~= nil then x[#x + 1] = "banner " .. c.banner[1] .. ":" .. c.banner[2] end
    if #x == 0 then parts[#parts + 1] = T.d(c.class) else parts[#parts + 1] = T.d(c.class) .. " (" .. table.concat(x, ", ") .. ")" end
  end
  return "[" .. table.concat(parts, ", ") .. "]"
end

-- ---- rules

function FM.install_rules(X)
  local function default_rules()
    local r = { difficulties = {}, classes = {}, clear_ticks = true, orb_best = false, direct = false, unlock_together = false,
      preview_top = false, preview_class = true, copy = {}, mods = {} }
    for c = CLASS_LO, CLASS_HI do
      r.difficulties[#r.difficulties + 1] = c
      r.classes[#r.classes + 1] = { class = c }
    end
    return r
  end

  local function word(file, key, v, w0, w1)
    if v == w0 then return false end
    if v == w1 then return true end
    VRFW.log.error(string.format("%s: [vrfw.FreeMatch] %s = \"%s\": must be \"%s\" or \"%s\" (ignored)", file, key, v, w0, w1))
    return nil
  end

  -- classes of `v`: 6..9 only, unique (first declaration wins), ascending
  local function classes(file, v)
    local out = {}
    for _, c in ipairs(v) do
      local d = type(c) == "table" and c.class or c
      local dup = false
      for _, x in ipairs(out) do if x.class == d then dup = true break end end
      if d < CLASS_LO or d > CLASS_HI or dup then
        VRFW.log.warn(string.format("%s: [vrfw.FreeMatch] Difficulties: class %d: only rows %d..%d once each are classes (left out)", file, d, CLASS_LO, CLASS_HI))
      else
        local level, bn
        local lv = type(c) == "table" and c.level or nil
        if lv ~= nil then
          if lv >= 1 and lv <= 999 then
            level = lv
          else
            VRFW.log.error(string.format("%s: [vrfw.FreeMatch] Difficulties: class %d: Level %d must be 1..999 (the rows keep their level)", file, d, lv))
          end
        end
        local b = type(c) == "table" and c.banner or nil
        if b ~= nil then
          bn = banner(b)
          if not bn then
            VRFW.log.error(string.format("%s: [vrfw.FreeMatch] Difficulties: class %d: Banner `%s` must be `#/<atlas path>:<sprite>` (the retail title is shown)", file, d, b))
          end
        end
        out[#out + 1] = { class = d, level = level, banner = bn }
      end
    end
    T.sort(out, function(a, b) return a.class < b.class end)
    if #out == 0 then
      VRFW.log.error(file .. ": [vrfw.FreeMatch] Difficulties: no class left (ignored)")
      return nil
    end
    return out
  end

  -- every file's `[VRFW.FreeMatch]` merged (also files that declare nothing else)
  function X.fm_rules(files)
    local order = {}
    for _, f in ipairs(files) do
      if f.value.vrfw and f.value.vrfw.FreeMatch ~= nil then order[#order + 1] = f end
    end
    T.sort(order, function(a, b) return a.load_index < b.load_index end)
    local r = default_rules()
    local owner = {}
    local function set(key, m, changed, file)
      local old = owner[key]
      if old and old ~= m and changed then
        VRFW.log.info(file .. ": [vrfw.FreeMatch] " .. key .. " replaces the value of " .. old)
      end
      owner[key] = m
    end
    for _, f in ipairs(order) do
      local d = f.value.vrfw.FreeMatch
      local file, m = f.file, f.mod
      local empty = d.Difficulties == nil and d.ClearTicks == nil and d.Orb == nil and d.Direct == nil and d.Unlock == nil
        and d.Preview == nil and d.PreviewClass == nil and d.Copy == nil
      if not empty then
        if not T.contains(r.mods, m) then r.mods[#r.mods + 1] = m end
        if d.Difficulties ~= nil then
          local v = classes(file, d.Difficulties)
          if v then
            set("Difficulties", m, not same_classes(v, r.classes), file)
            r.difficulties = {}
            for k, c in ipairs(v) do r.difficulties[k] = c.class end
            r.classes = v
          end
        end
        if d.ClearTicks ~= nil then
          set("ClearTicks", m, d.ClearTicks ~= r.clear_ticks, file)
          r.clear_ticks = d.ClearTicks
        end
        if d.Orb ~= nil then
          local v = word(file, "Orb", d.Orb, "retail", "best")
          if v ~= nil then
            set("Orb", m, v ~= r.orb_best, file)
            r.orb_best = v
          end
        end
        if d.Direct ~= nil then
          set("Direct", m, d.Direct ~= r.direct, file)
          r.direct = d.Direct
        end
        if d.Unlock ~= nil then
          local v = word(file, "Unlock", d.Unlock, "retail", "together")
          if v ~= nil then
            set("Unlock", m, v ~= r.unlock_together, file)
            r.unlock_together = v
          end
        end
        if d.Preview ~= nil then
          local v = word(file, "Preview", d.Preview, "lowest", "top")
          if v ~= nil then
            set("Preview", m, v ~= r.preview_top, file)
            r.preview_top = v
          end
        end
        if d.PreviewClass ~= nil then
          set("PreviewClass", m, d.PreviewClass ~= r.preview_class, file)
          r.preview_class = d.PreviewClass
        end
        if d.Copy ~= nil then
          -- class rows that take another row's content; a later mod's entry for a class replaces the earlier
          for _, c in ipairs(d.Copy) do
            if c.class < CLASS_LO or c.class > CLASS_HI or c.from == c.class or c.from < 1 then
              VRFW.log.warn(string.format("%s: [vrfw.FreeMatch] Copy { Class = %d, From = %d }: Class must be %d..%d and From another row (left out)", file, c.class, c.from, CLASS_LO, CLASS_HI))
            else
              local at = #r.copy + 1
              for k, x in ipairs(r.copy) do if x.class == c.class then at = k break end end
              r.copy[at] = { class = c.class, from = c.from }
            end
          end
          set("Copy", m, true, file)
        end
      end
    end
    if #r.mods == 0 then
      VRFW.log.info("[vrfw.FreeMatch]: no mod declares rules: «Competir contra bots» keeps the retail classes, marks and orbs")
    else
      VRFW.log.info(string.format("[vrfw.FreeMatch] (%s): Difficulties %s, ClearTicks %s, Orb %s, Direct %s, Unlock %s, Preview %s, PreviewClass %s",
        table.concat(r.mods, ", "), describe(r.classes), tostring(r.clear_ticks), r.orb_best and "best" or "retail", tostring(r.direct),
        r.unlock_together and "together" or "retail", r.preview_top and "top" or "lowest", tostring(r.preview_class)))
    end
    return r
  end
end

-- ---- tabs, rows

function FM.install(X)
  local D = X.D.free_match_tabs
  local FIRST_TAB, RETAIL_EXTRA, MAX_TABS = D.first_tab, D.retail_extra, D.max_tabs
  local LIM = (X.input.limits or {})
  local NATIVE_CLEAR_BITS, CLEAR_BITS = LIM.native_clear_bits or 2560, LIM.clear_bits or 32768

  -- `"<atlas>:<sprite>"` -> crc32 atlas, crc32 sprite
  local function split_icon(s)
    local a, b = T.rsplit_once(s, ":")
    if a == nil then return nil end
    a, b = T.trim(a), T.trim(b)
    if a == "" or b == "" then return nil end
    return VRFW.crc32(a), VRFW.crc32(b)
  end

  -- tab-bar layouts declared by mods (later mods win per tab count)
  function X.free_match_bars(files)
    local by = {}
    for _, f in ipairs(files) do
      for _, b in ipairs(f.value.vrfw.FreeMatchTabBar or {}) do
        if not (b.tabs >= FIRST_TAB + 2 and b.tabs <= MAX_TABS) or not b.attach:find("{nn}", 1, true) then
          VRFW.log.error(string.format("%s: free_match_tab_bar tabs = %d: `tabs` must be %d..=%d and `attach` hold {nn} (skipped)", f.file, b.tabs, FIRST_TAB + 2, MAX_TABS))
        else
          local old = by[b.tabs]
          if old and (old.attach ~= b.attach or old.bar ~= b.bar) then
            VRFW.log.info(string.format("%s: free_match_tab_bar tabs = %d replaces the one of %s", f.file, b.tabs, old.mod))
          end
          by[b.tabs] = { mod = f.mod, attach = b.attach, bar = b.bar }
        end
      end
    end
    local out = {}
    for _, n in ipairs(T.keys(by)) do
      local d = by[n]
      local attach = {}
      for k = 1, n do attach[k] = VRFW.crc32(T.replace(d.attach, "{nn}", T.pad(k, 2))) end
      out[#out + 1] = { tabs = n, attach = attach, bar = d.bar ~= nil and VRFW.crc32(d.bar) or 0 }
    end
    return out
  end

  -- free-match tabs (bar order) and layouts; writes the routeType of the kept tabs' pieces
  function X.free_match_tabs(files)
    local bars = X.free_match_bars(files)
    local decls = {}
    for _, f in ipairs(files) do
      for _, d in ipairs(f.value.vrfw.FreeMatchTab or {}) do
        if not T.is_word(d.id) then
          VRFW.log.error(f.file .. ": free_match_tab `" .. d.id .. "`: id must be a-z 0-9 _ (skipped)")
        else
          local pieces = {}
          for k, p in ipairs(d.pieces or {}) do pieces[k] = T.id(p) end
          local hit
          for _, x in ipairs(decls) do if x.d.id == d.id then hit = x break end end
          if hit then
            local first, b = hit.d, hit.b
            local same = first.text == d.text and first.icon == d.icon and first.icon_off == d.icon_off and first.icon_type == d.icon_type
              and first.order == d.order and first.series == d.series
            if not same then
              VRFW.log.info(string.format("%s: free_match_tab `%s`: name / icon / order of %s kept, only the pieces are added", f.file, d.id, b.mods[1]))
            end
            if not T.contains(b.mods, f.mod) then b.mods[#b.mods + 1] = f.mod end
            for _, p in ipairs(pieces) do
              if not T.contains(b.pieces, p) then b.pieces[#b.pieces + 1] = p end
            end
            -- first declaration's `VRFW.Difficulties`, else the first later one that has them
            local dd = (d.vrfw or {}).Difficulties or {}
            if #hit.diffs == 0 and #dd > 0 then hit.diffs = dd end
          else
            if d.text == nil and d.series == nil then
              VRFW.log.warn(f.file .. ": free_match_tab `" .. d.id .. "`: no `text` / `series`: the tab has no name")
            end
            local icon_atlas, icon = 0, 0
            if d.icon ~= nil then
              local a, s = split_icon(d.icon)
              if a then icon_atlas, icon = a, s
              else VRFW.log.warn(f.file .. ": free_match_tab `" .. d.id .. "`: icon `" .. d.icon .. "` is not \"<atlas>:<sprite>\" (no icon)") end
            end
            local icon_off = icon
            if d.icon_off ~= nil then
              local a, s = split_icon(d.icon_off)
              if a and a == icon_atlas then
                icon_off = s
              else
                VRFW.log.warn(f.file .. ": free_match_tab `" .. d.id .. "`: icon_off `" .. d.icon_off .. "` must name a sprite of the icon's atlas (the lit icon is used)")
              end
            end
            if icon == 0 and d.icon_type == nil then
              VRFW.log.warn(f.file .. ": free_match_tab `" .. d.id .. "`: no `icon` / `icon_type`: the tab has no icon")
            end
            if #pieces == 0 then
              VRFW.log.warn(f.file .. ": free_match_tab `" .. d.id .. "`: no `pieces`: the tab lists nothing (another mod may add them)")
            end
            local b = { id = d.id, mods = { f.mod }, index = 0, text = d.text ~= nil and VRFW.crc32(d.text) or 0,
              series = d.series ~= nil and T.id(d.series) or 0, icon_atlas = icon_atlas,
              icon = (d.icon_type ~= nil and icon == 0) and 0 or icon, icon_off = icon_off,
              icon_type = d.icon_type ~= nil and d.icon_type or -1, pieces = pieces }
            decls[#decls + 1] = { li = f.load_index, d = d, b = b, diffs = (d.vrfw or {}).Difficulties or {} }
          end
        end
      end
    end
    if #decls == 0 then return {}, bars end
    T.sort(decls, function(a, b)
      local oa, ob = a.d.order or 100, b.d.order or 100
      if oa ~= ob then return oa < ob end
      if a.li ~= b.li then return a.li < b.li end
      return VRFW.less(a.d.id, b.d.id)
    end)
    -- how many fit: one on the retail 10-tab bar, more only with a layout for that count
    local n = #decls
    local function fits(k)
      if k <= RETAIL_EXTRA then return true end
      for _, b in ipairs(bars) do if b.tabs == FIRST_TAB + k then return true end end
      return false
    end
    local keep = 0
    for k = math.min(n, MAX_TABS - FIRST_TAB), 0, -1 do
      if fits(k) then keep = k break end
    end
    if keep < n then
      local left = {}
      for k = keep + 1, n do left[#left + 1] = decls[k].d.id end
      VRFW.log.warn(string.format("free-match tabs: %d declared, %d shown (no [[vrfw.FreeMatchTabBar]] for %d tabs, at most %d); left out: %s",
        n, keep, FIRST_TAB + n, MAX_TABS, table.concat(left, ", ")))
    end
    local out, owner, ladders = {}, {}, {}
    for k = 1, keep do
      local x = decls[k]
      local b = x.b
      b.index = FIRST_TAB + k - 1
      local set = 0
      for _, p in ipairs(b.pieces) do
        if owner[p] then
          VRFW.log.warn(string.format("free-match tab `%s`: piece %s is already the tab `%s`'s (kept there)", b.id, T.hex(p), owner[p]))
        else
          local ok, e = X.piece_route_type(p, b.index)
          if ok ~= nil then
            owner[p] = b.id
            set = set + 1
          else
            VRFW.log.warn("free-match tab `" .. b.id .. "`: " .. e .. " (skipped)")
          end
        end
      end
      VRFW.log.info(string.format("free-match tab `%s` = tab %d (%d piece(s); %s)", b.id, b.index, set, table.concat(b.mods, ", ")))
      if #x.diffs > 0 then ladders[#ladders + 1] = { b.id, T.acopy(b.pieces), x.diffs } end
      out[#out + 1] = b
    end
    -- VRFW.Difficulties: difficulty rows and clear bits of the kept tabs' games
    for _, l in ipairs(ladders) do X.free_match_difficulties(l[1], l[2], l[3]) end
    return out, bars
  end

  -- `[[VRFW.GameTab]]`: files a retail game under another retail tab of the free-match list and the office. The game is copied (name `<game>_t<tab>`), the original's list rows point at the copy, and the copy sits in a hidden piece of the wanted tab. -> { {copy, original, tab} }
  function X.game_tabs(files)
    local out, done = {}, {}
    for _, f in ipairs(files) do
      for _, d in ipairs(f.value.vrfw.GameTab or {}) do
        local what = f.file .. ": GameTab `" .. tostring(d.game) .. "`"
        local function fail(e) VRFW.log.error(what .. ": " .. e .. " (skipped)") end
        if d.tab > FIRST_TAB - 1 then
          fail(string.format("tab %d: only the retail tabs 0..%d (IE1 … Victory Road)", d.tab, FIRST_TAB - 1))
        elseif done[d.game] then
          VRFW.log.warn(what .. ": already filed by " .. done[d.game] .. " (kept there)")
        else
          local g, e = X.games()
          if not g then fail(e) goto next end
          local tg = X.gcache().by_name[d.game]
          if not tg then fail("not a game of soccer_game_config") goto next end
          local o, eo = X.opp()
          if not o then fail(eo) goto next end
          local fb = o:field(0, "battleId")
          local bat = o:col_u32(0, fb)
          local rows = {}
          for i = 1, #bat do if bat[i] == tg.id then rows[#rows + 1] = i - 1 end end
          if #rows == 0 then fail("no row in the free-match / office list") goto next end
          local r, pl, el = X.route_lists()
          if not r then fail(pl) goto next end
          local fid, fref, fg, frt = r:field(pl, "pieceId"), r:field(pl, "eventInfoRef"), r:field(el, "paramCrc1"), r:field(pl, "routeType")
          -- board piece holding the game (the first)
          local src, ev
          local ids = r:col_u32(pl, fid)
          for p = 0, #ids - 1 do
            local a, b = r:tuple(pl, p, fref)
            for j = a or 0, (a or 0) + (b or 0) - 1 do
              if r:u32(el, j, fg) == tg.id then src, ev = p, j break end
            end
            if src then break end
          end
          if not src then fail("no piece of chronicle_vs_route_config holds it") goto next end
          local name = d.game .. "_t" .. d.tab
          local gid = VRFW.crc32(name)
          local G = X.gcache()
          if G.by_id[gid] then fail("game id of `" .. name .. "` already used") goto next end
          -- game copy: every difficulty row as is (rival, level, clear bit), info row renamed
          local drows = {}
          for _, i in ipairs(X.grows(tg)) do drows[#drows + 1] = g:entry(i) end
          local info = g:entry(tg.info)
          TC.set_int(info.values, X.SG.G_ID, gid)
          info.values[X.SG.G_NAME + 1] = name
          local ok, e3 = X.add_game(info, drows)
          if not ok then fail(e3) goto next end
          X.touched.games = true
          local nf, e4 = VRFW.team.files_copy(GAME_DIR .. d.game .. "_", GAME_DIR .. name .. "_", d.game, name)
          if not nf then fail(e4) goto next end
          -- list rows (free match and office) now play the copy
          for _, i in ipairs(rows) do o:set_u32(0, i, fb, gid) end
          -- `After`: each row moves right after the row of that game nearest in sortOrder (free-match and office rows are two blocks with their own sortOrder range)
          if d.after ~= nil then
            local ag = X.gcache().by_name[d.after]
            if not ag then
              VRFW.log.warn(what .. ": After `" .. d.after .. "` is not a game (the rows keep their place)")
            else
              local so = o:col_u32(0, o:field(0, "sortOrder"))
              local bat2 = o:col_u32(0, fb)
              local moved = {}
              for _, i in ipairs(rows) do moved[i] = true end
              local order = {}
              for i = 0, #bat2 - 1 do if not moved[i] then order[#order + 1] = i end end
              local n_moved = 0
              for _, i in ipairs(rows) do
                local at, best
                for k, j in ipairs(order) do
                  if bat2[j + 1] == ag.id and so[i + 1] and so[j + 1] then
                    local dist = math.abs(so[j + 1] - so[i + 1])
                    if best == nil or dist < best then at, best = k, dist end
                  end
                end
                if at then
                  table.insert(order, at + 1, i)
                  n_moved = n_moved + 1
                else
                  -- no row of that game in this list: the row stays where it was
                  local pos = #order + 1
                  for k, j in ipairs(order) do if j > i then pos = k break end end
                  table.insert(order, pos, i)
                end
              end
              o:keep(0, order)
              VRFW.log.info(what .. ": " .. n_moved .. " list row(s) placed after `" .. d.after .. "`")
            end
          end
          o:touch()
          X.touched.opp = true
          -- hidden piece: the board piece's row, no moves / unlocks, one event (the game's row, the copy's id)
          local ev_row = r:copy(el, ev)
          r:set_u32(-1, ev_row, fg, gid)
          local start = r:len(el)
          r:push(el, ev_row)
          local prow = r:copy(pl, src)
          r:set_u32(-1, prow, fid, VRFW.crc32("vrfw_game_tab_" .. name))
          r:set_u32(-1, prow, frt, d.tab)
          r:set_u32(-1, prow, r:field(pl, "eventType"), 0)
          r:set_tuple(-1, prow, fref, start, 1)
          for _, n in ipairs { "moveRouteInfo", "unlockPieceInfo" } do
            local fx = r:field(pl, n)
            if fx then r:set_tuple(-1, prow, fx, 0, 0) end
          end
          local ft = r:field(pl, "opponentListTab")
          if ft then r:set_u32(-1, prow, ft, 255) end
          r:push(pl, prow)
          r:touch()
          X.touched.route = true
          done[d.game] = f.mod
          out[#out + 1] = { gid, tg.id, d.tab }
          VRFW.log.info(string.format("%s: tab %d (%d list row(s) now play %s, hidden piece %s)", what, d.tab, #rows, name, T.hex(VRFW.crc32("vrfw_game_tab_" .. name))))
        end
        ::next::
      end
    end
    return out
  end

  -- set the routeType of piece `piece` (true = changed, false = already)
  function X.piece_route_type(piece, route_type)
    local r, e0 = X.route()
    if not r then return nil, e0 end
    local pl, e00 = r:list("m_pieceInfoList")
    if not pl then return nil, e00 end
    local fid, e1 = r:field(pl, "pieceId")
    if not fid then return nil, e1 end
    local frt, e2 = r:field(pl, "routeType")
    if not frt then return nil, e2 end
    local p = X.piece_row(r, pl, fid, piece)
    if p == nil then return nil, "piece " .. T.hex(piece) .. " is not in chronicle_vs_route_config" end
    if r:u32(pl, p, frt) == route_type then return false end
    r:set_u32(pl, p, frt, route_type)
    r:touch()
    X.touched.route = true
    return true
  end

  -- clear bit for `key`: a free native one first, else an extended one
  local function clear_bit(key, used)
    local n, w = VRFW.ids.next(CLEAR_SPACE, key, used, 1, NATIVE_CLEAR_BITS)
    if n then return n, w end
    -- native bits full: the "no free number" note of that range is expected
    return VRFW.ids.next(CLEAR_SPACE, key, used, NATIVE_CLEAR_BITS, CLEAR_BITS)
  end

  -- most common (c3, opponent_ai) per difficulty over `rows` ({difficulty, c3, ai}); ties: the lower pair
  local function class_ai(rows)
    local count = {}
    for _, r in ipairs(rows) do
      local d = r[1]
      count[d] = count[d] or {}
      local k = r[2] .. ":" .. r[3]
      local c = count[d][k]
      if not c then c = { r[2], r[3], 0 } count[d][k] = c end
      c[3] = c[3] + 1
    end
    local out = {}
    for d, m in pairs(count) do
      local best
      for _, c in pairs(m) do
        if best == nil or c[3] > best[3] or (c[3] == best[3] and (c[1] < best[1] or (c[1] == best[1] and c[2] < best[2]))) then best = c end
      end
      out[d] = { best[1], best[2] }
    end
    return out
  end

  -- `VRFW.Difficulties` of tab `tab` over the games of `pieces`
  function X.free_match_difficulties(tab, pieces, decl)
    if #decl == 0 then return end
    local wanted = {}
    for _, d in ipairs(decl) do
      local dup = false
      for _, w in ipairs(wanted) do if w.difficulty == d.difficulty then dup = true break end end
      if d.difficulty == 0 or dup then
        VRFW.log.warn(string.format("free-match tab `%s`: vrfw.Difficulties: difficulty %d is 0 or given twice (skipped)", tab, d.difficulty))
      else
        if d.level ~= nil and not (d.level >= 1 and d.level <= 999) then
          VRFW.log.warn(string.format("free-match tab `%s`: vrfw.Difficulties: difficulty %d level must be 1..999 (row level kept)", tab, d.difficulty))
        end
        wanted[#wanted + 1] = d
      end
    end
    local games = {}
    for _, p in ipairs(pieces) do
      local g, e = X.piece_games(p)
      if g then
        for _, x in ipairs(g) do if not T.contains(games, x) then games[#games + 1] = x end end
      else
        VRFW.log.warn("free-match tab `" .. tab .. "`: vrfw.Difficulties: " .. e)
      end
    end
    local g, added, bits = X.fm_difficulty_rows(tab, games, wanted)
    if g then
      local ds = {}
      for k, w in ipairs(wanted) do ds[k] = w.difficulty end
      VRFW.log.info(string.format("free-match tab `%s`: vrfw.Difficulties %s: %d game(s) of %d, %d row(s) added, %d clear bit(s) given", tab, T.dbg_list(ds), g, #games, added, bits))
    else
      VRFW.log.error("free-match tab `" .. tab .. "`: vrfw.Difficulties: " .. added .. " (no row changed)")
    end
  end

  function X.fm_difficulty_rows(tab, games, wanted)
    local t, te = X.games()
    if not t then return nil, te end
    local SG = X.SG
    local diff_rows = t:rows("SOCCER_GAME_DIFFICULTY")
    local triples = {}
    for _, i in ipairs(diff_rows) do
      local d, c3, ai = t:int(i, SG.D_DIFF), t:int(i, SG.D_AI), t:int(i, SG.D_AI_DATA)
      if d and c3 and ai then triples[#triples + 1] = { d, c3, ai } end
    end
    local ai = class_ai(triples)
    local used = {}
    for _, i in ipairs(diff_rows) do
      local b = t:uint(i, SG.D_CLEAR_BIT)
      if b and b ~= 0 then used[b] = true end
    end
    local n_games, added, nbits = 0, 0, 0
    local warns = {}
    local wanted_d = {}
    for _, w in ipairs(wanted) do wanted_d[w.difficulty] = true end
    for _, gid in ipairs(games) do
      local G = X.gcache()
      local g = G.by_id[gid]
      if not g then
        warns[#warns + 1] = "free-match tab `" .. tab .. "`: game " .. T.hex(gid) .. " of its pieces is not in soccer_game_config"
      else
        local old_rows = X.grows(g)
        local rows = {}
        for k, i in ipairs(old_rows) do rows[k] = t:entry(i) end
        local proto
        local best
        for _, e in ipairs(rows) do
          local d = TC.int(e.values, SG.D_DIFF) or 0
          if best == nil or d >= best then best, proto = d, e end
        end
        if proto then proto = { name = proto.name, hash = proto.hash, values = TC.copy_row(proto.values) } end
        if not proto then
          warns[#warns + 1] = "free-match tab `" .. tab .. "`: game " .. g.name .. " has no difficulty row"
        else
          local changed = false
          for _, w in ipairs(wanted) do
            local d = w.difficulty
            local lv = (w.level ~= nil and w.level >= 1 and w.level <= 999) and w.level or nil
            local k
            for kk, e in ipairs(rows) do
              if TC.int(e.values, SG.D_DIFF) == d then k = kk break end
            end
            if k then
              if lv ~= nil and TC.int(rows[k].values, SG.D_LEVEL) ~= lv then
                TC.set_int(rows[k].values, SG.D_LEVEL, lv)
                changed = true
              end
            else
              local e = { name = proto.name, hash = proto.hash, values = TC.copy_row(proto.values) }
              TC.set_int(e.values, SG.D_DIFF, d)
              if lv ~= nil then TC.set_int(e.values, SG.D_LEVEL, lv) end
              local a = ai[d]
              if a then
                TC.set_int(e.values, SG.D_AI, a[1])
                TC.set_int(e.values, SG.D_AI_DATA, a[2])
              else
                warns[#warns + 1] = string.format("free-match tab `%s`: no row of difficulty %d in the table: %s's new row keeps the copied AI", tab, d, g.name)
              end
              TC.set_int(e.values, SG.D_FIRST_CLEAR, 0)
              TC.set_int(e.values, SG.D_CLEAR_BIT, 0)
              rows[#rows + 1] = e
              added = added + 1
              changed = true
            end
          end
          -- clear bits for the declared rows that have none
          for _, e in ipairs(rows) do
            local d = TC.int(e.values, SG.D_DIFF) or 0
            if wanted_d[d] and (TC.uint(e.values, SG.D_CLEAR_BIT) or 0) == 0 then
              local key = tab .. "." .. g.name .. "." .. d
              local n, w = clear_bit(key, used)
              if w then warns[#warns + 1] = w end
              if n then
                used[n] = true
                TC.set_int(e.values, SG.D_CLEAR_BIT, n)
                nbits = nbits + 1
                changed = true
              else
                warns[#warns + 1] = string.format("free-match tab `%s`: no free clear bit below %d for %s difficulty %d (the row is never marked won)", tab, CLEAR_BITS, g.name, d)
              end
            end
          end
          if changed then
            T.sort(rows, function(a, b) return (TC.int(a.values, SG.D_DIFF) or 0) < (TC.int(b.values, SG.D_DIFF) or 0) end)
            -- old rows' bits move to the new block (unless another game's slice shares a row)
            local shared = {}
            for _, o in ipairs(G.list) do
              if o.id ~= gid then
                for _, i in ipairs(X.grows(o)) do shared[i] = true end
              end
            end
            for _, i in ipairs(old_rows) do
              if not shared[i] then t:set(i, SG.D_CLEAR_BIT, 0) end
            end
            -- rows as one new block at the end of the list; the game's slice points there
            local start = #G.diffs
            local n = #rows
            local ok, e = X.g_append("SOCCER_GAME_DIFFICULTY", { "SOCCER_GAME_DIFFICULTY" }, rows, n)
            if not ok then return nil, e end
            if g.info + 1 >= t:len() or t:hash(g.info + 1) ~= VRFW.crc32("SOCCER_GAME_INFO_REF_DIFFICULTY") then
              return nil, "game " .. g.name .. ": no REF_DIFFICULTY entry after its info row"
            end
            X.g_set_slice(g, start, n)
            t:touch()
            n_games = n_games + 1
          end
        end
      end
    end
    for _, w in ipairs(warns) do VRFW.log.warn(w) end
    if n_games > 0 then X.touched.games = true end
    return n_games, added, nbits
  end

  -- `[VRFW.FreeMatch]` class levels on every free-match game (every battleId of soccer_opponent_info)
  function X.free_match_levels(rules)
    local levels = {}
    for _, c in ipairs(rules.classes) do
      if c.level ~= nil then levels[#levels + 1] = { c.class, c.level } end
    end
    if #levels == 0 then return end
    local g, n, rows = X.fm_level_rows(levels)
    if g then
      local p = {}
      for k, x in ipairs(levels) do p[k] = x[1] .. " = Nv. " .. x[2] end
      VRFW.log.info(string.format("[vrfw.FreeMatch] class levels %s: %d row(s) of %d free-match game(s) re-levelled (%d game(s) on the list)", table.concat(p, ", "), rows, g, n))
    else
      VRFW.log.error("[vrfw.FreeMatch] class levels: " .. n .. " (no row changed)")
    end
  end

  -- `[VRFW.FreeMatch] Copy`: on every free-match game the class row takes the content of its `From` row (all columns but the difficulty number and clear bit); a game without the `From` row keeps its class row
  function X.free_match_copy(rules)
    for _, c in ipairs(rules.copy or {}) do
      local o, oe = X.opp()
      local t, te = X.games()
      local fb = o and o:field(0, "battleId")
      if not (o and t and fb) then
        VRFW.log.error("[vrfw.FreeMatch] Copy: " .. tostring(oe or te or "no battleId column") .. " (no row changed)")
        return
      end
      local SG = X.SG
      local listed = {}
      for _, x in ipairs(o:col_u32(0, fb)) do if x and x ~= 0 then listed[x] = true end end
      local copied, kept, cells = 0, 0, 0
      local done = {}
      for _, g in ipairs(X.games_list()) do
        if listed[g.id] then
          local src, dst
          for _, i in ipairs(X.grows(g)) do
            local d = t:int(i, SG.D_DIFF)
            if d == c.from then src = src or i elseif d == c.class then dst = dst or i end
          end
          if src and dst and src ~= dst then
            if not done[dst] then
              done[dst] = true
              local sv = t:entry(src).values
              for col = 0, #sv - 1 do
                if col ~= SG.D_DIFF and col ~= SG.D_CLEAR_BIT and t:entry(dst).values[col + 1] ~= sv[col + 1] then
                  t:set(dst, col, sv[col + 1])
                  cells = cells + 1
                end
              end
            end
            copied = copied + 1
          else
            kept = kept + 1
          end
        end
      end
      if copied > 0 then
        t:touch()
        X.touched.games = true
      end
      VRFW.log.info(string.format("[vrfw.FreeMatch] Copy { Class = %d, From = %d }: %d free-match game(s) took their row %d, %d kept their own (no row %d); %d cell(s) changed",
        c.class, c.from, copied, c.from, kept, c.from, cells))
    end
  end

  function X.fm_level_rows(levels)
    local o, oe = X.opp()
    if not o then return nil, oe end
    local fb, fe = o:field(0, "battleId")
    if not fb then return nil, fe end
    local listed = {}
    local nlisted = 0
    for _, x in ipairs(o:col_u32(0, fb)) do
      if x and x ~= 0 and not listed[x] then listed[x] = true nlisted = nlisted + 1 end
    end
    local t, te = X.games()
    if not t then return nil, te end
    local SG = X.SG
    local n_games, n_rows = 0, 0
    local seen = {}
    for _, g in ipairs(X.games_list()) do
      if listed[g.id] then
        local hit = false
        for _, i in ipairs(X.grows(g)) do
          if not seen[i] then
            seen[i] = true
            local d = t:int(i, SG.D_DIFF)
            if d then
              local l
              for _, x in ipairs(levels) do if x[1] == d then l = x[2] break end end
              if l ~= nil and t:int(i, SG.D_LEVEL) ~= l then
                t:set(i, SG.D_LEVEL, l)
                n_rows = n_rows + 1
                hit = true
              end
            end
          end
        end
        if hit then n_games = n_games + 1 end
      end
    end
    if n_rows > 0 then
      t:touch()
      X.touched.games = true
    end
    return n_games, nlisted, n_rows
  end
end

return FM
