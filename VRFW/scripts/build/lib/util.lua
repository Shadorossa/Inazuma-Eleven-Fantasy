-- Shared helpers of the build scripts: ids, sorted iteration, texts, notes and row helpers (find / where / clone / add / set / set_where / remove / move_slice).
local U = {}

local TWO32 = 4294967296

-- A 32-bit id: a number (any 64-bit spelling, the low 32 bits) or a name / "0x…" / decimal string (crc32 of a name).
function U.id(x)
  if type(x) == "number" then
    return x % TWO32
  elseif type(x) == "string" then
    return VRFW.ids.parse(x)
  end
  return 0
end

-- A number as the signed 32-bit value the tables store.
function U.i32(n)
  n = n % TWO32
  if n >= 2147483648 then return n - TWO32 end
  return n
end

-- "0x%08X" of an id (Rust `{:#010X}`).
U.hex = VRFW.hex

-- "%08x" of an id (Rust `{:08x}`).
function U.hex8(n)
  return string.format("%08x", n % TWO32)
end

function U.trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- The keys of `t` in byte order (Rust BTreeMap order of string keys; numbers by value).
function U.keys(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  return VRFW.sort(k)
end

-- Iterate `t` in key order.
function U.spairs(t)
  local k = U.keys(t)
  local i = 0
  return function()
    i = i + 1
    if k[i] ~= nil then return k[i], t[k[i]] end
  end
end

function U.contains(list, v)
  for _, x in ipairs(list) do
    if x == v then return true end
  end
  return false
end

function U.copy(t)
  local o = {}
  for k, v in pairs(t) do o[k] = v end
  return o
end

-- Deep copy of an entry table ({ name, hash, values }).
function U.copy_entry(e)
  local v = {}
  for i, x in ipairs(e.values) do v[i] = x end
  return { name = e.name, hash = e.hash, values = v }
end

function U.is_empty(t)
  return t == nil or next(t) == nil
end

-- A Rust `{:?}` of a cell value for notes.
function U.show(v)
  if type(v) == "string" then return '"' .. v .. '"' end
  if v == VRFW.null then return "None" end
  if type(v) == "number" then return string.format("%d", U.i32(v)) end
  return tostring(v)
end

-- Rust `{:?}` of an Option.
function U.opt(v)
  if v == nil then return "None" end
  if type(v) == "string" then return 'Some("' .. v .. '")' end
  return "Some(" .. tostring(v) .. ")"
end

-- The languages of a per-language map: `language = value`, keys normalized (`all` kept), unknown ones dropped.
-- `f` picks the value (nil = skipped); blank strings are skipped.
function U.pick_langs(map, f)
  local out, any = {}, false
  for _, l in ipairs(U.keys(map)) do
    local n = VRFW.lang.norm_or_all(l)
    if n then
      local s = f(map[l])
      if s ~= nil and U.trim(s) ~= "" then
        out[n] = s
        any = true
      end
    end
  end
  return out, any
end

-- The default language of a declaration: `d` normalized, else the first language of `text` in canonical order.
function U.norm_default(d, text)
  if d then
    local n = VRFW.lang.norm(d)
    if n then return n end
  end
  for _, l in ipairs(VRFW.lang.list()) do
    for k in pairs(text or {}) do
      if VRFW.lang.norm(k) == l then return l end
    end
  end
  return nil
end

-- Text groups per (mod, default language) in byte order (no default first), then stable-sorted by mod load order.
function U.text_groups()
  local G = { groups = {}, order = {} }
  function G.push(m, d, row)
    local k = m .. "\0" .. (d and ("1" .. d) or "0")
    local g = G.groups[k]
    if not g then
      g = { mod = m, default = d, rows = {} }
      G.groups[k] = g
    end
    g.rows[#g.rows + 1] = row
    return row
  end
  -- every group with its rows; `load_index(mod)` gives the mod's load index
  function G.sorted(load_index)
    local ks = U.keys(G.groups)
    local list = {}
    for i, k in ipairs(ks) do
      local g = G.groups[k]
      if #g.rows > 0 then list[#list + 1] = { g = g, li = load_index(g.mod), pos = i } end
    end
    table.sort(list, function(a, b)
      if a.li ~= b.li then return a.li < b.li end
      return a.pos < b.pos
    end)
    local out = {}
    for _, x in ipairs(list) do out[#out + 1] = x.g end
    return out
  end
  -- emit the rows (generated texts: table, id, variant, kind, texts, add, origin) to the text type
  function G.emit(load_index)
    local n = 0
    for _, g in ipairs(G.sorted(load_index)) do
      for _, t in ipairs(g.rows) do
        local field = t.kind and (t.kind .. ":" .. (t.variant or 0)) or tostring(t.variant or 0)
        VRFW.text.add { table = t.table, id = t.id, field = field, texts = t.texts, default_lang = g.default, mod = g.mod,
          add = t.add, origin = t.origin }
        n = n + 1
      end
    end
    return n
  end
  return G
end

-- ------------------------------------------------------------------------------------------------- row helpers

-- First row of list `row` whose column `col` holds `value` (an id or a string).
function U.find(t, row, col, value)
  if type(value) == "string" then return t:find_text(row, col, value) end
  return t:find(row, col, value)
end

-- Every row of list `row` matching `cells` ({ column = value }) or the predicate `f(t, i)`.
function U.where(t, row, match)
  local out = {}
  for _, i in ipairs(t:rows(row)) do
    local ok = true
    if type(match) == "function" then
      ok = match(t, i)
    else
      for c, v in pairs(match or {}) do
        local x = t:get(i, c)
        if type(v) == "number" and type(x) == "number" then
          if U.id(x) ~= U.id(v) then ok = false break end
        elseif x ~= v then
          ok = false break
        end
      end
    end
    if ok then out[#out + 1] = i end
  end
  return out
end

-- Copies of entries i..j-1 (j default i + 1).
function U.clone(t, i, j)
  return t:entries(i, j or (i + 1))
end

-- Append `entries` as `n` rows at the end of list `list` (after its last `names` entry; count raised by `n`).
function U.add(t, list, entries, n, names)
  return t:append_rows(list, names or { list }, entries, n or #entries)
end

-- Set several cells of entry `i`: { column = value }.
function U.set(t, i, cells)
  for c, v in pairs(cells) do t:set(i, c, v) end
end

-- Set `cells` on every row of list `row` matching `match` (across every parent / list of the file). Returns how many.
function U.set_where(t, row, match, cells)
  local hits = U.where(t, row, match)
  for _, i in ipairs(hits) do U.set(t, i, cells) end
  return #hits
end

-- Remove entries i..j-1 that were `n` rows of the list whose _LIST_BEG is at `begin`.
function U.remove(t, begin, i, j, n)
  return t:remove_range(begin, i, j, n)
end

-- Move entries i..j-1 to before entry `to` (positions before the move). Returns the new start.
function U.move_slice(t, i, j, to)
  return t:move_slice(i, j, to)
end

-- The end (exclusive) of entry `i` and the entries right after it whose names are in `names`.
function U.block_end(t, i, names)
  local hs = {}
  for _, n in ipairs(names) do hs[VRFW.crc32(n)] = true end
  local j, len = i + 1, t:len()
  while j < len and hs[t:hash(j)] do j = j + 1 end
  return j
end

return U
