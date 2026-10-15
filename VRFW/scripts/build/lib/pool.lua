-- T2B pool trees: tables where an info list keeps child rows in shared pool lists, each info row followed by one `<INFO>_REF_<X>` entry `(start, count)` per pool
-- (aura_skill_config, passive_skill_config, ability_learning_config, event_tag_word_replace_config).
-- P.set_children writes an info row's children with the fewest changes: nothing if equal, in place if the slice has the same length and is not shared, else an identical run already in the pool, else appended.
-- P.add_info clones a template info row (and its ref entries) after the last info row.
-- Cells: an integer (signed 32-bit), `{ float = x }`, a text or VRFW.null.

local U = require "lib/util"

local P = {}

local function group(info, refs)
  local g = { info = info, refs = refs, hashes = {} }
  for k, r in ipairs(refs) do g.hashes[VRFW.crc32(r[1])] = k end
  return g
end
P.group = group

P.AURA = group("AURA_CMD_INFO", {
  { "AURA_CMD_INFO_REF_UNIQUE_EFFECT", "AURA_CMD_UNIQUE_EFFECT" },
  { "AURA_CMD_INFO_REF_EFFECT", "AURA_CMD_EFFECT" },
  { "AURA_CMD_INFO_REF_CHARA", "AURA_CMD_CHARA" },
})
P.PASSIVE = group("PASSIVE_SKILL_INFO", {
  { "PASSIVE_SKILL_INFO_REF_BUFF_ICON", "PASSIVE_SKILL_BUFF_ICON" },
  { "PASSIVE_SKILL_INFO_REF_EFFECT", "PASSIVE_SKILL_EFFECT" },
})
P.BOARD = group("ABILITY_LEARNING_BOARD_INFO", { { "ABILITY_LEARNING_BOARD_INFO_REF_EFFECT", "ABILITY_LEARNING_BOARD_EFFECT" } })
P.TAG_ASSIGN = group("EVENT_ASSIGN_TAG_WORD_REPLACE_INFO",
  { { "EVENT_ASSIGN_TAG_WORD_REPLACE_INFO_REF_TARGET", "EVENT_ASSIGN_TAG_WORD_REPLACE_TARGET" } })
P.TAG_SND = group("EVENT_ASSIGN_SND_TAG_WORD_REPLACE_INFO",
  { { "EVENT_ASSIGN_SND_TAG_WORD_REPLACE_INFO_REF_TARGET", "EVENT_ASSIGN_SND_TAG_WORD_REPLACE_TARGET" } })

-- ---- cells

-- Two cells equal (as the table would store them).
function P.cell_eq(a, b)
  if type(a) == "table" and type(b) == "table" then return a.float == b.float end
  return a == b
end

function P.row_eq(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if not P.cell_eq(a[i], b[i]) then return false end
  end
  return true
end

-- A declared value (number / { float } / text / boolean) as a T2B cell: integers as 32-bit (also unsigned ids).
function P.value(v)
  local t = type(v)
  if t == "number" then
    if v ~= math.floor(v) then return { float = VRFW.technique.f32(v) } end
    if v < -2147483648 or v > 4294967295 then return nil, string.format("%.0f is not a 32-bit value", v) end
    return U.i32(v)
  elseif t == "table" and v.float ~= nil then
    return { float = VRFW.technique.f32(v.float) }
  elseif t == "string" then
    return v
  elseif t == "boolean" then
    return v and 1 or 0
  end
  return nil, tostring(v) .. ": a T2B value is a number or a text"
end

-- A declared row (an array of values) as cells.
function P.row(r)
  local out = {}
  for i, v in ipairs(r or {}) do
    local c, e = P.value(v)
    if c == nil then return nil, e end
    out[i] = c
  end
  return out
end

-- Declared rows; the error names `what[i]` (0-based).
function P.rows(rows, what)
  local out = {}
  for i, r in ipairs(rows) do
    local x, e = P.row(r)
    if x == nil then return nil, string.format("%s[%d]: %s", what, i - 1, e) end
    out[i] = x
  end
  return out
end

-- ---- the tree

function P.infos(t, g)
  return t:rows(g.info)
end

-- First info row whose column `col` is the number `id` (or, `id` nil, the text `key`).
function P.find_info(t, g, col, id, key)
  if id ~= nil then return t:find(g.info, col, id) end
  if key ~= nil then return t:find_text(g.info, col, key) end
  return nil
end

-- Entry index of the k-th (1-based) ref entry of the info row at `info`.
function P.ref_entry(t, g, info, k)
  local r = g.refs[k]
  if not r then return nil end
  local h = VRFW.crc32(r[1])
  local i, n = info + 1, t:len()
  while i < n do
    local x = t:hash(i)
    if x == h then return i end
    if not g.hashes[x] then return nil end
    i = i + 1
  end
  return nil
end

local function slice_of(t, e)
  local a, b = t:int(e, 0) or 0, t:int(e, 1) or 0
  if a < 0 then a = 0 end
  if b < 0 then b = 0 end
  return a, b
end

-- Values of the children of the info row at `info` in pool k.
function P.children(t, g, info, k)
  local r = P.ref_entry(t, g, info, k)
  if not r then return {} end
  local s, c = slice_of(t, r)
  local p = t:rows(g.refs[k][2])
  local out = {}
  for j = s + 1, math.min(s + c, #p) do out[#out + 1] = t:entry(p[j]).values end
  return out
end

-- Insert `rows` at the end of pool list `list` (count raised, sort run regenerated): the pool index of the first.
function P.append_pool(t, list, rows)
  local b, e, err = t:span(list)
  if b == nil then return nil, err end
  local h = VRFW.crc32(list)
  local first = #t:rows(list)
  local at = b + 1
  for i = e - 1, b + 1, -1 do
    if t:hash(i) == h then at = i + 1 break end
  end
  local ents = {}
  for i, v in ipairs(rows) do ents[i] = { name = list, hash = h, values = v } end
  t:splice(at, at, ents)
  if t:int(b, 0) == nil then return nil, t:key() .. ": " .. list .. "_LIST_BEG without a count" end
  t:bump(b, #rows)
  local ok, e2 = t:resort(list)
  if not ok then return nil, e2 end
  return first
end

local function set_ref(t, r, s, c)
  local e = t:entry(r)
  e.values[1], e.values[2] = s, c
  t:splice(r, r + 1, { e })
end

-- Point the info row at `info` at `rows` in pool k. True when something changed; `nil, err`.
function P.set_children(t, g, info, k, rows)
  local r = P.ref_entry(t, g, info, k)
  if not r then return nil, string.format("%s: the %s row has no %s", t:key(), g.info, g.refs[k][1]) end
  local s, c = slice_of(t, r)
  local p = t:rows(g.refs[k][2])
  local cur = {}
  for j = s + 1, math.min(s + c, #p) do cur[#cur + 1] = t:entry(p[j]).values end
  if #cur == #rows then
    local same = true
    for j = 1, #rows do
      if not P.row_eq(cur[j], rows[j]) then same = false break end
    end
    if same then return false end
  end
  local n = #rows
  if n == 0 then
    set_ref(t, r, 0, 0)
    return true
  end
  -- in place: same length, no other info row points into the slice
  if c == n and s + c <= #p then
    local shared = false
    for _, i in ipairs(P.infos(t, g)) do
      if i ~= info then
        local x = P.ref_entry(t, g, i, k)
        if x then
          local a, b = slice_of(t, x)
          if b > 0 and a < s + c and s < a + b then shared = true break end
        end
      end
    end
    if not shared then
      for j = 1, n do
        local idx = p[s + j]
        t:splice(idx, idx + 1, { { name = t:name(idx), hash = t:hash(idx), values = rows[j] } })
      end
      return true
    end
  end
  -- identical run already in the pool
  local vals = {}
  for j, i in ipairs(p) do vals[j] = t:entry(i).values end
  for a = 0, #vals - n do
    local ok = true
    for j = 1, n do
      if not P.row_eq(vals[a + j], rows[j]) then ok = false break end
    end
    if ok then
      set_ref(t, r, a, n)
      return true
    end
  end
  -- appending may move the info row: find it again by its place among the infos
  local ord
  for x, i in ipairs(P.infos(t, g)) do
    if i == info then ord = x break end
  end
  if not ord then return nil, "info row vanished" end
  local at, e = P.append_pool(t, g.refs[k][2], rows)
  if at == nil then return nil, e end
  local info2 = P.infos(t, g)[ord]
  local r2 = P.ref_entry(t, g, info2, k)
  if not r2 then return nil, "ref entry vanished" end
  set_ref(t, r2, at, n)
  return true
end

-- Append a new info row: a clone of the info row at `template` (with its ref entries) with `values`, after the last info row. Returns its entry index.
function P.add_info(t, g, template, values)
  local b, e, err = t:span(g.info)
  if b == nil then return nil, err end
  local hi = VRFW.crc32(g.info)
  local grp = { { name = t:name(template), hash = hi, values = values } }
  local i, n = template + 1, t:len()
  while i < n and g.hashes[t:hash(i)] do
    grp[#grp + 1] = t:entry(i)
    i = i + 1
  end
  local last
  for x = e - 1, b + 1, -1 do
    if t:hash(x) == hi then last = x break end
  end
  if not last then return nil, t:key() .. ": " .. g.info .. " is empty" end
  local at = last + 1
  while at < t:len() and g.hashes[t:hash(at)] do at = at + 1 end
  t:splice(at, at, grp)
  if t:int(b, 0) == nil then return nil, t:key() .. ": " .. g.info .. "_LIST_BEG without a count" end
  t:bump(b, 1)
  local ok, e2 = t:resort(g.info)
  if not ok then return nil, e2 end
  return at
end

-- Write `cells` ({ column = value }; columns by the schema `schema`: names, `#<index>` or numbers) into entry `e`.
-- Returns the column indices written (name order).
function P.set_cells(t, e, schema, cells)
  local done = {}
  for _, k in ipairs(U.keys(cells)) do
    local c, err = t:column(schema, k)
    if c == nil then return nil, err end
    local val, verr = P.value(cells[k])
    if val == nil then return nil, k .. ": " .. verr end
    local w = t:width(e)
    if c >= w then return nil, string.format("%s: column %d beyond the row's %d values", k, c, w) end
    if not P.cell_eq(t:get(e, c), val) then t:set(e, c, val) end
    done[#done + 1] = c
  end
  return done
end

return P
