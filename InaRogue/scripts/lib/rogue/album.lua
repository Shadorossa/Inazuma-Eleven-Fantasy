-- InaRogue › INAROGUE: the album (docs/game/modes/inarogue.md §14, §14.5): every character card grouped by
-- original team, content\rogue\album.toml (research/scripts/rogue_album_build.py). Was album.rs of the DLL's module rogue. A
-- card is owned when the bank holds ANY row of that character (keyed by character, crc32 of the name).
--
-- Orders: 0 album (team by team), 1 rarity (highest first), 2 only missing, 3 owned by team, 4 newest signing first,
-- 5 highest cost first. The book (evt_rogue_album_menu): 7 rows x 3 stickers per page; a section (team / tier / day /
-- cost) starts with its header row and, when it does not fit in the rows left, at the top of the next page.

local U = require "lib/rogue/util"
local chara = require "lib/rogue/chara"
local info, warn = U.logger("rogue")

local A = {}

A.ORDER_TEAM, A.ORDER_TIER, A.ORDER_MISSING, A.ORDER_OWNED, A.ORDER_RECENT, A.ORDER_COST = 0, 1, 2, 3, 4, 5
A.ORDER_LAST, A.BOOK_ROWS, A.BOOK_COLS = 5, 7, 3

local D = nil -- { teams = { { id, name, emblem, first, count } }, mp, mk (members: param / key, 0-based by card), clubs,
--               variant (param -> key), team_of (card -> team, 0-based) }

function A.data()
  if D then return D end
  D = { teams = {}, mp = {}, mk = {}, clubs = {}, variant = {}, team_of = {}, n = 0 }
  local ok, t = pcall(VRFW.files.toml, "content/rogue/album.toml")
  if not ok or type(t) ~= "table" then
    warn("content/rogue/album.toml not readable (" .. tostring(t) .. "): empty album")
    return D
  end
  for _, x in ipairs(type(t.team) == "table" and t.team or {}) do
    D.teams[#D.teams + 1] = { id = x.id % U.TWO32, name = x.name, emblem = x.emblem % U.TWO32, first = x.first, count = x.count }
  end
  local cards = type(t.cards) == "table" and t.cards or {}
  local m = cards.members or {}
  local n = 0
  for i = 1, #m - 1, 2 do
    D.mp[n] = m[i] % U.TWO32
    D.mk[n] = m[i + 1] % U.TWO32
    n = n + 1
  end
  D.n = n
  for i, c in ipairs(cards.clubs or {}) do D.clubs[i - 1] = c % U.TWO32 end
  local v = cards.variants or {}
  for i = 1, #v - 1, 2 do D.variant[v[i] % U.TWO32] = v[i + 1] % U.TWO32 end
  A.drop_missing(D)
  for t_i, x in ipairs(D.teams) do
    for c = x.first, x.first + x.count - 1 do D.team_of[c] = t_i - 1 end
  end
  return D
end

-- the cards whose param is not in the chara_param the game reads (a card of a mod that is not active) leave the album:
-- teams renumbered, empty teams dropped, variants of missing params forgotten. No chara_param readable = all kept.
function A.drop_missing(d)
  local map = chara.table().map
  if next(map) == nil then return end
  local teams, mp, mk, clubs, n, dropped = {}, {}, {}, {}, 0, 0
  for _, x in ipairs(d.teams) do
    local first = n
    for c = x.first, x.first + x.count - 1 do
      if d.mp[c] ~= nil and map[d.mp[c]] ~= nil then
        mp[n], mk[n], clubs[n] = d.mp[c], d.mk[c], d.clubs[c]
        n = n + 1
      else
        dropped = dropped + 1
      end
    end
    if n > first then
      teams[#teams + 1] = { id = x.id, name = x.name, emblem = x.emblem, first = first, count = n - first }
    end
  end
  for p in pairs(d.variant) do
    if map[p] == nil then d.variant[p] = nil end
  end
  if dropped > 0 then
    info(string.format("album: %d card(s) of mods not active left out (%d of %d kept)", dropped, n, d.n))
  end
  d.teams, d.mp, d.mk, d.clubs, d.n = teams, mp, mk, clubs, n
end

function A.char_key(param) return A.data().variant[param] end
function A.teams() return #A.data().teams end
function A.total_cards() return A.data().n end

function A.team(t)
  local x = A.data().teams[t + 1]
  if not x then return nil end
  return x.id, x.name, x.emblem, x.count
end

function A.team_range(t)
  local x = A.data().teams[t + 1]
  if not x then return nil end
  return x.first, x.count
end

-- card c (0-based, album order): param, character key
function A.card(c)
  local d = A.data()
  if c < 0 or c >= d.n then return nil end
  return d.mp[c], d.mk[c]
end

function A.club_emblem(c) return A.data().clubs[c] or 0 end

-- the team of card c (the last team for an index past the end)
function A.team_of(c)
  local d = A.data()
  return d.team_of[c] or math.max(#d.teams - 1, 0)
end

function A.member(t, k)
  local first, n = A.team_range(t)
  if not first or k < 0 or k >= n then return nil end
  return A.card(first + k)
end

-- owned character keys of a list of params
function A.owned_keys(params)
  local o = {}
  for _, p in ipairs(params) do
    local k = A.char_key(p)
    if k then o[k] = true end
  end
  return o
end

function A.team_owned(t, owned)
  local first, n = A.team_range(t)
  if not first then return 0 end
  local d, c = A.data(), 0
  for i = first, first + n - 1 do
    if owned[d.mk[i]] then c = c + 1 end
  end
  return c
end

function A.total_owned(owned)
  local d, c = A.data(), 0
  for i = 0, d.n - 1 do
    if owned[d.mk[i]] then c = c + 1 end
  end
  return c
end

-- ---------------------------------------------------------------------------------------- orders

-- the album cards (0-based) of an order; owned = { [key] = { uid, runs, added } }; tier(param), cost(param)
function A.book_order(order, owned, tier, cost)
  local d = A.data()
  local o = {}
  if order == A.ORDER_OWNED then
    for c = 0, d.n - 1 do
      if owned[d.mk[c]] then o[#o + 1] = c end
    end
  elseif order == A.ORDER_RECENT then
    local keys = {}
    for c = 0, d.n - 1 do
      local w = owned[d.mk[c]]
      if w then
        -- (added desc, uid desc, card asc) as one string the native sort compares
        -- (%.0f: Lua 5.2's %d stops at 2^31 on Windows)
        keys[#keys + 1] = string.format("%010.0f%010.0f%06.0f", 4294967295 - (w[3] % U.TWO32), 4294967295 - (w[1] % U.TWO32), c)
      end
    end
    table.sort(keys)
    for i, k in ipairs(keys) do o[i] = tonumber(k:sub(21)) end
  elseif order == A.ORDER_COST then
    local keys = {}
    for c = 0, d.n - 1 do
      if owned[d.mk[c]] then keys[#keys + 1] = (99999 - U.clamp(cost(d.mp[c]), 0, 99999)) * 100000 + c end
    end
    table.sort(keys)
    for i, k in ipairs(keys) do o[i] = k % 100000 end
  elseif order == A.ORDER_TIER then
    local keys = {}
    for c = 0, d.n - 1 do keys[#keys + 1] = (255 - U.clamp(tier(d.mp[c]), 0, 255)) * 100000 + c end
    table.sort(keys)
    for i, k in ipairs(keys) do o[i] = k % 100000 end
  elseif order == A.ORDER_MISSING then
    for c = 0, d.n - 1 do
      if not owned[d.mk[c]] then o[#o + 1] = c end
    end
  else
    for c = 0, d.n - 1 do o[#o + 1] = c end
  end
  return o
end

-- the section key of card c in an order: its team, its tier (rarity), its signing day (recent) or its cost
function A.section_key(order, c, owned, tier, cost)
  local d = A.data()
  if order == A.ORDER_TIER then return tier(d.mp[c]) end
  if order == A.ORDER_RECENT then
    local w = owned[d.mk[c]]
    return w and w[3] or 0
  end
  if order == A.ORDER_COST then return cost(d.mp[c]) end
  return A.team_of(c)
end

-- group jump: from position i (0-based) of `list`, the first card of the next group (dir > 0) or the start of the
-- current / previous group
function A.group_jump(list, i, dir, key)
  local n = #list
  if n == 0 then return 0 end
  i = math.min(i, n - 1)
  local function k(p) return key(list[p + 1]) end
  local function start_of(s)
    local kk = k(s)
    while s > 0 and k(s - 1) == kk do s = s - 1 end
    return s
  end
  if dir > 0 then
    local kk = k(i)
    for j = i, n - 1 do
      if k(j) ~= kk then return j end
    end
    return i
  end
  local s = start_of(i)
  if s < i or s == 0 then return s end
  return start_of(s - 1)
end

-- ---------------------------------------------------------------------------------------- the book

-- lays `list` out into pages; key(card) = the section key. Rows: { kind = 0 empty / 1 header / 2 cards, section,
-- first, n } (0-based sections and list positions)
function A.book(list, key)
  local b = { pages = {}, sections = {} }
  local function empty_page()
    local p = {}
    for r = 1, A.BOOK_ROWS do p[r] = { kind = 0 } end
    return p
  end
  local page = empty_page()
  local r, i, n = 0, 0, #list
  while i < n do
    local k = key(list[i + 1])
    local j = i + 1
    while j < n and key(list[j + 1]) == k do j = j + 1 end
    local s = #b.sections
    local need = 1 + math.ceil((j - i) / A.BOOK_COLS)
    if r > 0 and r + need > A.BOOK_ROWS then
      b.pages[#b.pages + 1] = page
      page = empty_page()
      r = 0
    end
    b.sections[#b.sections + 1] = { key = k, first = i, count = j - i, page = #b.pages }
    page[r + 1] = { kind = 1, section = s }
    r = r + 1
    local at = i
    while at < j do
      if r >= A.BOOK_ROWS then
        b.pages[#b.pages + 1] = page
        page = empty_page()
        r = 0
      end
      local c = math.min(j - at, A.BOOK_COLS)
      page[r + 1] = { kind = 2, section = s, first = at, n = c }
      r = r + 1
      at = at + c
    end
    i = j
  end
  if r > 0 or #b.pages == 0 then b.pages[#b.pages + 1] = page end
  return b
end

-- section index (0-based) of list position pos
function A.section_of(b, pos)
  local lo, hi = 1, #b.sections
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    local s = b.sections[mid]
    if pos < s.first then
      hi = mid - 1
    elseif pos >= s.first + s.count then
      lo = mid + 1
    else
      return mid - 1
    end
  end
  return nil
end

-- (page, row, col) of list position pos (0-based)
function A.locate(b, pos)
  local s = A.section_of(b, pos)
  if not s then return nil end
  local sec = b.sections[s + 1]
  for p = sec.page, #b.pages - 1 do
    for r, row in ipairs(b.pages[p + 1]) do
      if row.kind == 2 and pos >= row.first and pos < row.first + row.n then return p, r - 1, pos - row.first end
    end
  end
  return nil
end

return A
