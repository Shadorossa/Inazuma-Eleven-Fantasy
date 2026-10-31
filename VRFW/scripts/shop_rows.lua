-- Locked shop rows. Declarations: every active mod's content\shop_locks\*.toml (`VRFW.shop_lock/1`); native side: content\game\shop_rows.toml.
-- Rows whose compiled condition fails are normally never listed. For declared shops such a row is shown and recorded as locked when the condition is a real
-- progress gate (none of the declared `keep_hidden` flags), it sells a declared `items` entry (when given), and no other visible row sells the same item.
-- The list item fill records layer instance -> row id so the menu Lua greys locked rows and shows what they wait for.
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_SHOP_LOCK_SHOPS | shop ids (SHOP_INFO col 0); none = ask | live (replaces the shop list until a title return) |
-- | CMND_VRFW_SHOP_LOCKED | inst (layer instance of shop01_02_list_item) | locked, row_id, kind, a, b |
-- | CMND_VRFW_SHOP_LOCKED_ITEM | item (SHOP_INFO_ITEM col 2) | locked, kind, a, b |
-- | CMND_VRFW_SHOP_LOCK_ON | shop id | whether rows of this shop are listed as locked |
-- | CMND_VRFW_SHOP_LOCK_SOURCE | kind, a, b, language code | form, name, number, text id: what a locked row waits for, named from the game's tables |
-- kind, a, b = what the row waits for: 1 story phase (a), 2 Chronicle piece (a, difficulty b), 3 global bit flag (a), 4 soccer game (a, difficulty b), 0 other.
-- A row whose condition mentions the framework's hide flag (VRFW_ROW_HIDDEN) is never listed.

ShopRows = ShopRows or {}

local D = require "lib/declarations"

local band = bit32.band
local KEY_RESETS = "vrfw.game_resets"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("shop_rows")

-- SHOP_INFO_ITEM row layout (stride 0xB8) and SHOP_INFO row fields.
local ROW_STRIDE, ROW_ITEM, ROW_COND, ROW_LINEUP = 0xB8, 0x4, 0x58, 0x60
local SHOP_ROWS, SHOP_COUNT = 0x38, 0x40
local LAYER_INST = 0x110
local MAX_BLOB, MAX_INST = 4096, 64

local KIND_UNKNOWN, KIND_PHASE, KIND_CHRONICLE, KIND_FLAG, KIND_GAME = 0, 1, 2, 3, 4
-- Condition functions the decoder names (crc32 of their names)
local FN_GET_PHASE, FN_CHRONICLE_CLEAR, FN_GLOBAL_BIT, FN_GAME_CLEAR = 0xB91936DA, 0xC9783DBF, 0x2A3D4543, 0xB817C9C5

local DECLARED = {}      -- shop id -> { items = set | nil, keep = { flag … }, key }
local DECLARED_ALL = nil -- the rule of `all_shops` declarations (every shop without its own rule)
local shops = {}         -- shop id -> rule in force (the declared ones, or the command's list)
local all_rule = nil     -- the `all_shops` rule in force (nil after CMND_VRFW_SHOP_LOCK_SHOPS replaced the list)
local FLAG_TEXT = {}     -- global bit flag -> text id declared by a [[VRFW.ShopLockText]]
local HIDE_FLAG = nil    -- crc32 of the framework's hide flag
local LIVE = false

-- row id -> cond, item -> cond, layer instance -> row id
local locked_rows, locked_items, inst_row = {}, {}, {}
local hits = 0

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

-- After a title return: nothing listed yet, recorded rows are dropped, declared shops apply again. The framework's
-- event game_reset says it (the title return that counts the state key vrfw.game_resets); a script without events
-- (an older framework) compares that key on each call instead.
local seen_epoch = nil
local reset_by_event = false
-- Per row (address): the row's static verdict for a failed condition; per shop rows block: the rows' items and lineup
-- flags (game data, read once). Dropped with the recorded rows and when the shop list is replaced.
local row_verdicts, shop_lists = {}, {}
local function reset_rows()
  locked_rows, locked_items, inst_row = {}, {}, {}
  row_verdicts, shop_lists = {}, {}
  shops = {}
  for id, r in pairs(DECLARED) do shops[id] = r end
  all_rule = DECLARED_ALL
end
local function check_reset()
  if reset_by_event then return end
  local ok, e = pcall(VRFW.state.get, KEY_RESETS)
  if not ok then e = nil end
  if e ~= seen_epoch then
    if seen_epoch ~= nil then reset_rows() end
    seen_epoch = e
  end
end
reset_by_event = pcall(VRFW.on, "game_reset", function()
  reset_rows()
  return nil
end)

-- ---------------------------------------------------------------------------------------------- conditions

-- Payload bytes of a compiled condition blob (format: u8 0, u16 LE payload length, payload); nil when not compiled
local function payload_of(blob)
  if rd("u8", blob) ~= 0 then return nil end
  local n = rd("u16", blob + 1) or 0
  if n == 0 or n > MAX_BLOB then return nil end
  -- the bytes in one guarded read (one read per byte when the block is not readable at once)
  local ok, arr = pcall(VRFW.mem.read_array, "u8", blob + 3, n)
  if ok and type(arr) == "table" and #arr == n then return arr end
  local p = {}
  for i = 1, n do
    local b = rd("u8", blob + 2 + i)
    if not b then return nil end
    p[i] = b
  end
  return p
end

local function be32(p, i)
  local a, b, c, d = p[i], p[i + 1], p[i + 2], p[i + 3]
  if not (a and b and c and d) then return nil end
  return ((a * 256 + b) * 256 + c) * 256 + d
end

-- The payload references `flag` as a hash literal (34 <crc32 big-endian>)
local function mentions(p, flag)
  for i = 1, #p - 4 do
    if p[i] == 0x34 and be32(p, i + 1) == flag then return true end
  end
  return false
end

-- A literal (32 int / 34 hash, big-endian) at i
local function lit(p, i)
  local t = p[i]
  if t ~= 0x32 and t ~= 0x34 then return nil end
  return be32(p, i + 1)
end

-- Index (1-based) where the RPN tokens start in a payload (format: u16 BE length, nodes, tokens): 4 when that layout is detected, else 2
local function token_start(p)
  if #p >= 4 then
    local be = p[1] * 256 + p[2]
    if be > 0 and be + 2 <= #p and (p[4] == 0x35 or p[4] == 0x8F or p[4] == 0x90) then return 4 end
  end
  return 2
end

-- First group whose function is a known gate gives kind, a, b
local function decode(p)
  local i = token_start(p)
  while i <= #p do
    local t = p[i]
    if t == 0x8F or t == 0x90 then
      i = i + 1
    elseif t == 0x35 then
      local f = be32(p, i + 1)
      local nargs = p[i + 7]
      if not f or not nargs then break end
      i = i + 8
      local args, ok = {}, true
      for k = 1, nargs do
        if p[i] ~= 0x28 or p[i + 1] ~= 0x00 or p[i + 2] ~= 0x06 or p[i + 3] ~= 0x02 then ok = false break end
        local v = lit(p, i + 4)
        if not v then ok = false break end
        if k <= 4 then args[k] = v end
        i = i + 9
      end
      if not ok then break end
      local value = lit(p, i)
      if not value then break end
      i = i + 6
      if f == FN_GET_PHASE and nargs == 0 then return { KIND_PHASE, value, 0 } end
      if f == FN_CHRONICLE_CLEAR and nargs == 2 then return { KIND_CHRONICLE, args[1], args[2] } end
      if f == FN_GLOBAL_BIT and nargs == 1 then return { KIND_FLAG, args[1], 0 } end
      if f == FN_GAME_CLEAR and nargs == 2 then return { KIND_GAME, args[1], args[2] } end
    else
      break
    end
  end
  return { KIND_UNKNOWN, 0, 0 }
end

-- The game's own answer for a compiled condition
local function eval(c)
  local ok, r = pcall(VRFW.hook.original, "ShopRows.Condition", c)
  return ok and r ~= nil and r ~= 0 and r ~= false
end

-- Another row of the shop sells `item` with lineup flag 0 and a holding condition (or none)
local function twin_visible(shop, row, item)
  local rows, n = rd("ptr", shop + SHOP_ROWS), rd("u32", shop + SHOP_COUNT)
  if not rows or not n then return false end
  n = math.min(n, 4096)
  -- every row's item and lineup flag in two reads, kept per rows block (one read per row when not readable at once)
  local items, lineups
  local list = shop_lists[rows]
  if list and list.n == n then
    items, lineups = list.items, list.lineups
  elseif n > 0 then
    local oki, a = pcall(VRFW.mem.read_array, "u32", rows + ROW_ITEM, n, ROW_STRIDE)
    local okl, b = pcall(VRFW.mem.read_array, "u8", rows + ROW_LINEUP, n, ROW_STRIDE)
    if oki and okl and type(a) == "table" and type(b) == "table" then
      items, lineups = a, b
      shop_lists[rows] = { n = n, items = a, lineups = b }
    end
  end
  for i = 0, n - 1 do
    local r = rows + i * ROW_STRIDE
    local it, lu
    if items then
      it, lu = items[i + 1], lineups[i + 1]
    else
      it = r ~= row and rd("u32", r + ROW_ITEM) or nil
      lu = it == item and rd("u8", r + ROW_LINEUP) or nil
    end
    if r ~= row and it == item and lu == 0 then
      local c = rd("ptr", r + ROW_COND)
      if not c or c == 0 then return true end
      if eval(c) then return true end
    end
  end
  return false
end

-- ---------------------------------------------------------------------------------------------- hooks

-- the static part of a failed row's verdict: false = never listed as locked (no rule, another item, not compiled, a
-- hidden or kept flag), else the decoded condition { kind, a, b }
local function row_verdict(blob, shop_id, item)
  local rule = shops[shop_id] or all_rule
  if not rule then return false end
  if rule.items and not rule.items[item] then return false end
  local p = payload_of(blob)
  if not p then return false end
  if HIDE_FLAG and mentions(p, HIDE_FLAG) then return false end
  for _, f in ipairs(rule.keep) do
    if mentions(p, f) then return false end
  end
  return decode(p)
end

-- EvalCondition of a shop row (r14 = the row, rbx = SHOP_INFO), after the game's answer
local function row_cond_post(ev)
  check_reset()
  local passed = ev.ret ~= 0 and ev.ret ~= false
  -- a holding condition only clears recorded rows: nothing recorded, nothing to read
  if passed and next(locked_rows) == nil and next(locked_items) == nil then return nil end
  local blob, row, shop = ev.args[1], ev.regs.r14, ev.regs.rbx
  local row_id = rd("u32", row) or 0
  local item = rd("u32", row and row + ROW_ITEM) or 0
  if passed then
    if row_id ~= 0 then
      locked_rows[row_id] = nil
      locked_items[item] = nil
    end
    return nil
  end
  if row_id == 0 then return nil end
  local shop_id = rd("u32", shop) or 0
  local v = row and row_verdicts[row]
  if not v or v.blob ~= blob or v.row_id ~= row_id or v.item ~= item or v.shop_id ~= shop_id then
    v = { blob = blob, row_id = row_id, item = item, shop_id = shop_id, cond = row_verdict(blob, shop_id, item) }
    if row then row_verdicts[row] = v end
  end
  if not v.cond then return nil end
  if item ~= 0 and twin_visible(shop, row, item) then return nil end
  local cond = v.cond
  locked_rows[row_id] = cond
  if item ~= 0 then locked_items[item] = cond end
  hits = hits + 1
  if hits == 1 then
    info(string.format("shop 0x%08X row 0x%08X (item 0x%08X) listed as locked (first hit; %s)", shop_id, row_id, item, (shops[shop_id] or all_rule).key))
  end
  return { ret = 1 }
end

-- List item fill (layerItem, &args, &row): layer instance -> row id
local function row_fill_pre(ev)
  local inst = rd("u32", ev.args[1] and ev.args[1] + LAYER_INST)
  local row = rd("ptr", ev.args[3])
  if inst and row and inst < MAX_INST then inst_row[inst] = rd("u32", row) or 0 end
  return nil
end

-- ---------------------------------------------------------------------------------------------- declarations

local function start()
  local schema, why = D.schema("shop_lock")
  if not schema then
    warn(why .. ": the shops list their rows as the game does")
    return
  end
  local decls, skipped = D.load(schema, warn)
  local okh, h = pcall(D.id_of, "VRFW_ROW_HIDDEN")
  HIDE_FLAG = okh and h or nil
  local n_shops, parts = 0, {}
  local function join(r, d, items)
    -- a second declaration of the shop: item filters join (none = every row), kept flags add up
    r.key = r.key .. "+" .. d.key
    if r.items and items then
      for x in pairs(items) do r.items[x] = true end
    else
      r.items = nil
    end
  end
  for _, d in ipairs(decls) do
    if d.entry == "ShopLockText" then
      local tid = D.id_of(d.v.text)
      for _, f in ipairs(d.v.flags) do FLAG_TEXT[f] = tid end
      goto next_decl
    end
    if #(d.v.shops or {}) == 0 and not d.v.all_shops then
      warn(string.format("%s: neither `shops` nor `all_shops = true`: left out", d.where or d.key))
      goto next_decl
    end
    local items
    if d.v.items and #d.v.items > 0 then
      items = {}
      for _, x in ipairs(d.v.items) do items[x] = true end
    end
    if d.v.all_shops then
      if not DECLARED_ALL then
        DECLARED_ALL = { key = d.key, keep = {}, items = items }
      else
        join(DECLARED_ALL, d, items)
      end
      for _, f in ipairs(d.v.keep_hidden or {}) do DECLARED_ALL.keep[#DECLARED_ALL.keep + 1] = f end
    end
    for _, id in ipairs(d.v.shops or {}) do
      local r = DECLARED[id]
      if not r then
        r = { key = d.key, keep = {}, items = items }
        DECLARED[id] = r
        n_shops = n_shops + 1
      else
        join(r, d, items)
      end
      for _, f in ipairs(d.v.keep_hidden or {}) do r.keep[#r.keep + 1] = f end
    end
    parts[#parts + 1] = string.format("%s (%s%s)", d.key, d.v.all_shops and "all shops" or string.format("%d shop(s)", #d.v.shops),
      items and string.format(", %d item(s)", #d.v.items) or "")
    ::next_decl::
  end
  for id, r in pairs(DECLARED) do shops[id] = r end
  all_rule = DECLARED_ALL
  if n_shops == 0 and not DECLARED_ALL then
    if #decls > 0 or (skipped or 0) > 0 then
      info(string.format("off: %d declaration(s) (%d left out by `when`), no shop: the shops list their rows as the game does", #decls, skipped or 0))
    else
      info("off: no mod declares locked shop rows: the shops list their rows as the game does")
    end
    return
  end
  local okc, rc, ec = pcall(VRFW.hook.apply, "ShopRows.Condition")
  local okf, rf, ef = pcall(VRFW.hook.apply, "ShopRows.Fill")
  LIVE = okc and rc == true and okf and rf == true
  if LIVE then
    info(string.format("on: rows with an unmet progress condition listed as locked in %s: %s",
      DECLARED_ALL and "every shop" or string.format("%d shop(s)", n_shops), table.concat(parts, ", ")))
  else
    warn(string.format("detours not installed (condition: %s, fill: %s): the shops list their rows as the game does",
      tostring(okc and (rc == true and "ok" or ec) or rc), tostring(okf and (rf == true and "ok" or ef) or rf)))
  end
end

-- ---------------------------------------------------------------------------------------------- commands

-- CMND_VRFW_SHOP_LOCK_SHOPS(ids...) -> live
function ShopRows.Shops(...)
  check_reset()
  local ids = {}
  for _, v in ipairs({ ... }) do
    v = tonumber(v)
    if v and v ~= 0 then ids[#ids + 1] = band(v, 0xFFFFFFFF) end
  end
  if #ids > 0 then
    shops = {}
    all_rule = nil
    row_verdicts = {}
    for _, id in ipairs(ids) do shops[id] = DECLARED[id] or { key = "CMND_VRFW_SHOP_LOCK_SHOPS", keep = {}, items = nil } end
    info(string.format("CMND_VRFW_SHOP_LOCK_SHOPS: %d shop(s) until the title (live %s)", #ids, tostring(LIVE)))
  end
  return LIVE
end

-- CMND_VRFW_SHOP_LOCKED(inst) -> locked, row_id, kind, a, b
function ShopRows.Locked(inst)
  check_reset()
  inst = tonumber(inst) or -1
  local row = (inst >= 0 and inst < MAX_INST) and (inst_row[math.floor(inst)] or 0) or 0
  local c = row ~= 0 and locked_rows[row] or nil
  local k = c or { 0, 0, 0 }
  return c ~= nil, row, k[1], k[2], k[3]
end

-- CMND_VRFW_SHOP_LOCKED_ITEM(item) -> locked, kind, a, b
function ShopRows.LockedItem(item)
  check_reset()
  item = tonumber(item) or 0
  if item ~= 0 then item = band(item, 0xFFFFFFFF) end
  local c = item ~= 0 and locked_items[item] or nil
  local k = c or { 0, 0, 0 }
  return c ~= nil, k[1], k[2], k[3]
end

-- CMND_VRFW_SHOP_LOCK_ON(shop id) -> whether rows of this shop are listed as locked
function ShopRows.On(shop)
  check_reset()
  shop = tonumber(shop) or 0
  if shop ~= 0 then shop = band(shop, 0xFFFFFFFF) end
  return LIVE and (shops[shop] ~= nil or all_rule ~= nil)
end

-- ---------------------------------------------------------------------------------------------- what a row waits for

local Id = require "lib/ids"
local u32 = Id.u32

local function slice(v)
  if type(v) ~= "table" then return nil end
  local s, n = tonumber(v.start or v[1]), tonumber(v.count or v[2])
  if s == nil or n == nil then return nil end
  return s, n
end

local function rows_of(id)
  local ok, t = pcall(VRFW.table.rows, id)
  if ok and type(t) == "table" then return t end
  warn(string.format("table %s not readable (%s): its names are left out", id, tostring(t)))
  return {}
end

-- Games, pieces and chapters as text ids, read once on the first locked row that is named
local SOURCES = nil
local function sources()
  if SOURCES then return SOURCES end
  local t0 = VRFW.now()
  local S = { game = {}, piece = {}, chapter = {} }
  -- soccer game id -> { title = text id, teams = { [difficulty] = team id }, first = team id }
  local games = rows_of("soccer/soccer_game_info")
  local refs = rows_of("soccer/soccer_game_info_ref_difficulty")
  local diffs = rows_of("soccer/soccer_game_difficulty")
  for i, g in ipairs(games) do
    local id = u32(g.id or g[1])
    if id ~= 0 then
      local e = { title = u32(g.title_text or g[5]), teams = {}, first = 0 }
      local r = refs[i]
      local st, n = tonumber(r and (r.start or r[1])), tonumber(r and (r.count or r[2]))
      if st and n then
        for k = st, st + n - 1 do
          local d = diffs[k + 1]
          if type(d) == "table" then
            local team = u32(d.opponent_team or d[2])
            local lvl = tonumber(d.difficulty or d[1]) or 0
            if team ~= 0 then
              e.teams[lvl] = e.teams[lvl] or team
              if e.first == 0 then e.first = team end
            end
          end
        end
      end
      S.game[id] = e
    end
  end
  -- team id -> name text id
  S.team = {}
  for _, t in ipairs(rows_of("team/team")) do
    local id = u32(t.id or t[1])
    if id ~= 0 then S.team[id] = u32(t.name_text or t[4]) end
  end
  -- Chronicle piece id -> its games in order
  local events = rows_of("vsroute/vs_route_piece_event")
  for _, p in ipairs(rows_of("vsroute/vs_route_piece")) do
    local id = u32(p.pieceId or p[2])
    local st, n = slice(p.eventInfoRef or p[24])
    if id ~= 0 and st then
      local list = {}
      for k = st, st + n - 1 do
        local ev = events[k + 1]
        local g = type(ev) == "table" and u32(ev.paramCrc1 or ev[1]) or 0
        if g ~= 0 and S.game[g] then list[#list + 1] = g end
      end
      if #list > 0 then S.piece[id] = list end
    end
  end
  -- chapter -> title text id
  for _, c in ipairs(rows_of("phase/phase_title")) do
    local ch = tonumber(c.chapter or c[1])
    if ch then S.chapter[ch] = u32(c.title_text or c[2]) end
  end
  SOURCES = S
  local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
  info(string.format("sources: %d game(s), %d Chronicle piece(s) with games, %d chapter(s), read in %d ms",
    count(S.game), count(S.piece), count(S.chapter), math.floor(VRFW.now() - t0)))
  return S
end

local function lang_of(code)
  code = tonumber(code)
  if code and code >= 0 and type(VRFW.files.game_languages) == "function" then
    local ok, t = pcall(VRFW.files.game_languages)
    local l = ok and type(t) == "table" and t[math.floor(code) + 1] or nil
    if type(l) == "string" then return l end
  end
  return "en"
end

-- A game text in a language (English when that language has no such file), kept per file and language
local TEXTS = {}
local function text_of(file, lang, id)
  if not id or id == 0 then return nil end
  local key = file .. "/" .. lang
  local t = TEXTS[key]
  if t == nil then
    local ok, rows = pcall(VRFW.files.text_rows, "data/common/text/" .. lang .. "/" .. file .. ".cfg.bin")
    if (not ok or type(rows) ~= "table") and lang ~= "en" then
      ok, rows = pcall(VRFW.files.text_rows, "data/common/text/en/" .. file .. ".cfg.bin")
    end
    t = (ok and type(rows) == "table") and rows or {}
    TEXTS[key] = t
  end
  local r = t[id]
  local s = r and r[0]
  if type(s) ~= "string" then return nil end
  s = s:gsub("\n", " "):gsub("\n", " ")
  if s == "" then return nil end
  return s
end

local function game_title(S, g, lang)
  local e = S.game[g]
  return e and text_of("soccer_game_title", lang, e.title) or nil
end

-- The opponent of a game at difficulty d (else the most common story / Chronicle difficulties, else its first)
local function game_team(S, g, d, lang)
  local e = S.game[g]
  if not e then return nil end
  local team = e.teams[tonumber(d) or -1] or e.teams[2] or e.teams[1] or e.first
  return text_of("team_text", lang, S.team[team]) or nil
end

local SOURCE_CACHE = {}

-- CMND_VRFW_SHOP_LOCK_SOURCE(kind, a, b, language code) -> form, name, number, text id
-- form: "chapter" (number = chapter, name = its title or ""), "match" (name = the game's title), "beat_chronicle" / "beat"
-- (name = the opponent), "chronicle", "text" (text id = a [[VRFW.ShopLockText]] text) or "later" (nothing known)
function ShopRows.Source(kind, a, b, code)
  kind, a, b = tonumber(kind) or 0, u32(a), tonumber(b) or 0
  local lang = lang_of(code)
  local ck = string.format("%d/%d/%d/%s", kind, a, b, lang)
  local c = SOURCE_CACHE[ck]
  if c then return c[1], c[2], c[3], c[4] end
  local form, name, number, text = "later", nil, 0, 0
  local ok, err = pcall(function()
    if kind == KIND_FLAG then
      if FLAG_TEXT[a] then form, text = "text", FLAG_TEXT[a] end
    elseif kind == KIND_PHASE then
      local ch = math.floor(a / 10000)
      if ch >= 1 then
        form, number = "chapter", ch
        name = text_of("quest_title_text", lang, sources().chapter[ch])
      end
    elseif kind == KIND_CHRONICLE then
      local S = sources()
      local list = S.piece[a] or {}
      for _, g in ipairs(list) do
        name = game_title(S, g, lang)
        if name then form = "match" break end
      end
      if not name and list[1] then
        name = game_team(S, list[1], b, lang)
        if name then form = "beat_chronicle" end
      end
      if not name then form = "chronicle" end
    elseif kind == KIND_GAME then
      local S = sources()
      name = game_title(S, a, lang)
      if name then
        form = "match"
      else
        name = game_team(S, a, b, lang)
        if name then form = "beat" end
      end
    end
  end)
  if not ok then
    warn("source: " .. tostring(err))
    form, name, number, text = "later", nil, 0, 0
  end
  SOURCE_CACHE[ck] = { form, name or "", number, text }
  return form, name or "", number, text
end

start()

if LIVE then
  VRFW.on("hook:ShopRows.Condition:post", row_cond_post)
  VRFW.on("hook:ShopRows.Fill", row_fill_pre)
end
