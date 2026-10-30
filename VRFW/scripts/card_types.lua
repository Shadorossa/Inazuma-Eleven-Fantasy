-- Card-type registry (declarations: content\card_types\*.toml; native side: content\game\card_types.toml).
-- Off (no active declaration): nothing is written and the game's tab and filters are unchanged.
-- The rarity tab lists the game's rarities in order; a card type with `filter = false` hides its rarity (hidden ones must be the lowest). One card type above the game's rarities (`filter` true; several: lowest `order`) becomes one extra last item.
-- `every_filter`: these card types' rarities join any specific rarity filter set of the player bank.
-- CMND_VRFW_CARD_TYPE(hdl) -> rarity, listed, every_filter
-- CMND_VRFW_CARD_TYPE_TAB() -> n, rarities of the tab

CardTypes = CardTypes or {}


local D = require "lib/declarations"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("card_types")

-- the four tab loops (content\game\card_types.toml) and the profile site of each loop's end value
local LISTS = {
  { name = "CharaTab", end_site = "Card.RarityCharaTab.End" },
  { name = "CharaRebuild", end_site = "Card.RarityCharaRebuild.End" },
  { name = "SpiritTab", end_site = "Card.RaritySpiritTab.End" },
  { name = "SpiritRebuild", end_site = "Card.RaritySpiritRebuild.End" },
}
-- the player bank filter's rarity set: entries, the set (16 bytes)
local SET_COUNT, SET_LIST, SET_MAX = 0xA44, 0xA48, 16

local ON = false          -- a card type is declared: the tab follows the registry
local GAME_END = nil      -- the game's loop end (it lists rarities 0 .. GAME_END - 1)
local TAB = {}            -- rarities the tab lists, in order (when ON)
local LISTED = {}         -- rarity -> true (when ON)
local EVERY = {}          -- rarities of the every_filter card types, in order
local EVERY_SET = {}

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local function wr(ty, at, v)
  if type(at) ~= "number" or at < 0x10000 then return false end
  return pcall(VRFW.mem.write, ty, at, v)
end

-- the loop end read from the game's code: every list must agree
local function game_end()
  local e
  for _, l in ipairs(LISTS) do
    local ok, at = pcall(VRFW.game.sym, l.end_site)
    local v = ok and rd("u8", at) or nil
    if not v then return nil, l.end_site .. " is not readable on this build" end
    if e and v ~= e then return nil, string.format("%s ends at %d, another list at %d (another mod changed it?)", l.end_site, v, e) end
    e = v
  end
  return e
end

-- ---- declarations

local function merged_types()
  local schema, why = D.schema("card_type")
  if not schema then
    warn(why .. ": the card-type service stays off")
    return {}
  end
  local decls, skipped = D.load(schema, warn)
  local by_rarity, order = {}, {}
  for _, d in ipairs(decls) do
    local r = d.v.rarity
    local t = by_rarity[r]
    if not t then
      t = { rarity = r, keys = {} }
      by_rarity[r] = t
      order[#order + 1] = r
      for k, x in pairs(d.v) do t[k] = x end
    else
      -- a later mod's declaration of the same rarity: only the keys it writes
      for k in pairs(d.given) do t[k] = d.v[k] end
    end
    t.keys[#t.keys + 1] = d.key
  end
  local out = {}
  for _, r in ipairs(order) do out[#out + 1] = by_rarity[r] end
  return out, #decls, skipped
end

-- ---- the tab

local function u32_hex(v)
  return string.format("%02X %02X %02X %02X", v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)
end

local function apply(name, arg)
  local ok, r = pcall(VRFW.patch.apply, name, arg)
  if not ok then
    warn(name .. ": " .. tostring(r))
    return false
  end
  return r == true
end

-- write the four lists (first listed rarity, the extra card type); true when every list took it
local function write_tab(first, extra)
  local done = 0
  for _, l in ipairs(LISTS) do
    local p = "CardTypes." .. l.name .. "."
    local ok = true
    if first > 0 then
      ok = apply(p .. "Move") and apply(p .. "First", u32_hex(first)) and apply(p .. "Skip")
    end
    if ok and extra then
      ok = apply(p .. "Extra", { imm = { { at = 2, width = "u8", value = GAME_END }, { at = 6, width = "u32", value = extra } } })
        and apply(p .. "End", string.format("%02X", GAME_END + 1))
    end
    if ok then
      done = done + 1
    else
      VRFW.error("card_types: «Rareza» tab of " .. l.name .. " not fully written (see the patch lines above)")
    end
  end
  return done
end

local function start()
  local types, n_decl, skipped = merged_types()
  if #types == 0 then
    if (skipped or 0) > 0 then
      info(string.format("off: %d card type declaration(s), none whose `when` holds: the game's «Rareza» tab and filters", skipped))
    else
      info("off: no mod declares a card type: the game's «Rareza» tab and filters")
    end
    return
  end
  local e, why = game_end()
  if not e then
    warn("the «Rareza» tab's loops are not readable (" .. tostring(why) .. "): the card-type service stays off")
    return
  end
  GAME_END = e
  local hidden, extras = {}, {}
  for _, t in ipairs(types) do
    if t.rarity < e and t.filter == false then hidden[t.rarity] = t end
    if t.rarity >= e and t.filter ~= false then extras[#extras + 1] = t end
    if t.every_filter then
      EVERY[#EVERY + 1] = t.rarity
      EVERY_SET[t.rarity] = true
    end
  end
  -- the loop starts at `first`: hidden rarities must be the lowest; at least one game rarity stays
  local first = 0
  while first < e - 1 and hidden[first] do first = first + 1 end
  for r = first, e - 1 do
    if hidden[r] then
      warn(string.format("%s: rarity %d hidden, but rarity %d below it is listed: the tab can only leave out the lowest rarities, %d stays listed",
        table.concat(hidden[r].keys, ", "), r, first, r))
    end
  end
  table.sort(extras, function(a, b)
    if (a.order or 0) ~= (b.order or 0) then return (a.order or 0) < (b.order or 0) end
    return a.rarity < b.rarity
  end)
  local extra = extras[1]
  for i = 2, #extras do
    warn(string.format("%s: rarity %d not added to the «Rareza» tab: it has room for one card type above the game's rarities (%s, order %d, has it)",
      table.concat(extras[i].keys, ", "), extras[i].rarity, table.concat(extra.keys, ", "), extra.order or 0))
  end
  ON = true
  TAB, LISTED = {}, {}
  for r = first, e - 1 do
    TAB[#TAB + 1] = r
    LISTED[r] = true
  end
  if extra then
    TAB[#TAB + 1] = extra.rarity
    LISTED[extra.rarity] = true
  end
  local n = 0
  if first > 0 or extra then
    n = write_tab(first, extra and extra.rarity)
  end
  if #EVERY > 0 then
    pcall(VRFW.state.set, "vr_framework.card_types.every_filter", VRFW.is_on("CardTypes.BankFilter") and 1 or 0)
    if not VRFW.is_on("CardTypes.BankFilter") then
      warn("hook CardTypes.BankFilter off (see «Problemas» / console native): `every_filter` card types filter like the others")
    end
  end
  local ev = {}
  for _, r in ipairs(EVERY) do ev[#ev + 1] = tostring(r) end
  info(string.format("on: %d declaration(s) (%d left out by `when`): «Rareza» tab = rarities %s (game %d..%d, first %d%s) on %d of %d lists; every_filter: %s",
    n_decl, skipped or 0, table.concat(TAB, " "), 0, e - 1, first, extra and (", extra " .. extra.rarity .. " from " .. table.concat(extra.keys, ", ")) or "",
    (first > 0 or extra) and n or #LISTS, #LISTS, #ev > 0 and table.concat(ev, " ") or "none"))
end

-- ---- the bank filter

-- Pre-hook: adds the every_filter rarities to a rarity set that has 1 to 15 entries (installed only when a card type declares every_filter).
local function bank_pre(ev)
  local f = ev.args[4]
  if type(f) ~= "number" or f < 0x10000 then return nil end
  local n = rd("u32", f + SET_COUNT) or 0
  if n == 0 or n >= SET_MAX then return nil end
  local have, n0 = {}, n
  for i = 0, n - 1 do
    local r = rd("u8", f + SET_LIST + i)
    if r then have[r] = true end
  end
  for _, r in ipairs(EVERY) do
    if not have[r] and n < SET_MAX then
      if wr("u8", f + SET_LIST + n, r) then
        n = n + 1
        have[r] = true
      end
    end
  end
  if n ~= n0 then wr("u32", f + SET_COUNT, n) end
  return nil
end

-- ---- commands

-- (hdl) -> rarity, listed, every_filter
function CardTypes.CmdType(hdl)
  local ok, r = pcall(VRFW.call, "CardTypes.GetCharaRarity", tonumber(hdl) or 0)
  if not ok or type(r) ~= "number" then return 0, false, false end
  local listed
  if ON then
    listed = LISTED[r] == true
  else
    -- the game's own tab: rarities below its loop end
    GAME_END = GAME_END or game_end()
    listed = GAME_END ~= nil and r < GAME_END
  end
  return r, listed, EVERY_SET[r] == true
end

-- () -> n, then the n rarities of the tab, in order (0: the service is off; the game's own list is used).
function CardTypes.CmdTab()
  if not ON then return 0 end
  return #TAB, table.unpack(TAB)
end

start()

if #EVERY > 0 then
  VRFW.on("hook:CardTypes.BankFilter", bank_pre)
end
