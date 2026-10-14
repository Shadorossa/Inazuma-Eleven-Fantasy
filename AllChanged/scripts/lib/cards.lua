-- All Changed › the cards a mode change works on: owned cards (VRFW.chara.saved), their chara_param facts (the
-- chara_param the game reads: VRFW.table.raw) and the framework's fusion store (VRFW.miximax.call). Pure Lua over the
-- framework; no game data written. (The same helpers as Inazuma Fantasy's lib\transform\cards.lua, reduced to what a
-- mode change needs; candidates for Character Reforged once its shared card helpers land, docs/refactor/aura-mods-split.md.)

local M = {}

function M.u32(v)
  if type(v) == "boolean" then return v and 1 or 0 end
  v = tonumber(v) or 0
  if v < 0 then v = v + 4294967296 end
  return math.floor(v) % 4294967296
end

-- an id / handle as hex text: never "%X" on a value >= 2^31 (the scripts' Lua 5.2 formats it through a 32-bit long)
function M.hex(v)
  v = M.u32(v)
  local hi, lo = math.floor(v / 65536), v % 65536
  return string.format("0x%04X%04X", hi, lo)
end

-- the save record of a character handle (nil = none)
function M.record(hdl)
  if not hdl or hdl == 0 then return nil end
  local ok, r = pcall(VRFW.chara.record, hdl)
  if ok and type(r) == "table" and r.addr then return r end
  return nil
end

function M.param_of(hdl)
  local r = M.record(hdl)
  return r and M.u32(r.param) or nil
end

-- chara_param rows { chara_base, rarity, element, main position } by param id, read once
local ROWS = nil
local function rows()
  if ROWS then return ROWS end
  local out = {}
  local ok, t = pcall(VRFW.table.raw, "data/common/gamedata/character/chara_param_*.cfg.bin", "CHARA_PARAM_INFO", { 1, 2, 42, 3, 4 })
  for _, r in ipairs(ok and type(t) == "table" and t or {}) do
    local id = M.u32(r[1])
    if id ~= 0 then out[id] = { M.u32(r[2]), tonumber(r[42]) or 0, tonumber(r[3]) or 0, tonumber(r[4]) or 0 } end
  end
  if next(out) == nil then
    VRFW.warn("all_changed: chara_param rows not readable: no card facts")
    return out
  end
  ROWS = out
  return ROWS
end

function M.param_row(p)
  if not p or p == 0 then return nil end
  return rows()[p]
end

function M.chara_of_param(p)
  local r = M.param_row(p)
  return r and r[1] or 0
end

-- every owned card { hdl, param }
function M.owned()
  local out = {}
  local ok, v = pcall(VRFW.chara.saved)
  if not ok or type(v) ~= "table" then return out end
  for _, r in ipairs(v) do
    local h, p = M.u32(r.handle), M.u32(r.param)
    if h ~= 0 and p ~= 0 then out[#out + 1] = { h, p } end
  end
  return out
end

-- a card argument: a character handle, or a chara_param id (the first owned card of that param)
function M.card_arg(v)
  v = M.u32(v)
  if M.param_of(v) then return v end
  for _, c in ipairs(M.owned()) do
    if c[2] == v then return c[1] end
  end
  return v
end

-- the cards the framework's fusion store (any mod's miximax) uses as a PARTNER: { [hdl] = base }
function M.fusion_partners()
  local out = {}
  local ok, s = pcall(VRFW.miximax.call, { op = "store" })
  local st = ok and type(s) == "table" and type(s[2]) == "table" and s[2] or nil
  for _, f in ipairs(st and st.fusions or {}) do
    local p = M.u32(f.partner_hdl)
    if p ~= 0 then out[p] = M.u32(f.base_hdl) end
  end
  return out
end

function M.slot()
  if VRFW.slots.ready() then return VRFW.slots.active() end
  return 1
end

return M
