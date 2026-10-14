-- Character Reforged › duplicate players: the ONE adapter over the framework's save tree (VRFW.savetree,
-- docs/framework/native.md §3.2) and the patch list the pass writes through. A copy of Inazuma Fantasy's
-- scripts/lib/save_slots/tree.lua (script VMs are separate: each mod keeps its own copy).
--
-- A path is a dotted record path with 0-based array indices: "block5.m_Permanent.m_saveHumanP.skill_list[3]". The
-- pass reads the tree as it is and queues its writes in a patch list (P), applied at its end in order, so it always
-- reads the save as it was when the pass started. Writes keep every leaf's width: the container never changes size.

local T = {}

local byte, char, sub, concat, floor = string.byte, string.char, string.sub, table.concat, math.floor

-- ------------------------------------------------------------------------------------------------ bytes

-- `v` as `n` little-endian bytes (a negative value as its two's complement).
function T.le(v, n)
  v = v % (2 ^ (8 * n))
  local p = {}
  for i = 1, n do
    p[i] = char(v % 256)
    v = floor(v / 256)
  end
  return concat(p)
end

-- the unsigned little-endian integer of `n` bytes at 0-based offset `off` of `s`
function T.rd(s, off, n)
  local v = 0
  for i = n, 1, -1 do
    v = v * 256 + byte(s, off + i)
  end
  return v
end

-- the u32 words of `s` (1-based array; trailing bytes ignored)
function T.words(s)
  local w = {}
  for i = 0, floor(#s / 4) - 1 do
    local a, b, c, d = byte(s, i * 4 + 1, i * 4 + 4)
    w[i + 1] = a + b * 0x100 + c * 0x10000 + d * 0x1000000
  end
  return w
end

function T.hex(v)
  return string.format("0x%08X", v)
end

-- ------------------------------------------------------------------------------------------------ tree

-- The framework's save tree API, nil when it does not exist (the rules then do not run).
function T.api()
  local v = rawget(_G, "VRFW")
  return v and v.savetree or nil
end

function T.open_bytes(bytes)
  local a = T.api()
  if not a then return nil, "save-tree API not available" end
  return a.open_bytes(bytes)
end

function T.open_slot(n)
  local a = T.api()
  if not a then return nil, "save-tree API not available" end
  return a.open(n)
end

function T.at(path, i)
  return path .. "[" .. i .. "]"
end

-- block `id` is in the save
function T.has_block(t, id)
  for _, b in ipairs(t:blocks()) do
    if b == id then return true end
  end
  return false
end

-- `base.name` when it is a struct, else nil
function T.kids(t, base, name)
  local p = base .. "." .. name
  local g = t:get(p)
  if g and g.kind == "struct" then return p end
  return nil
end

-- `base.wrapper` when it is a struct (m_Permanent / m_InfoPermanent wrappers), else `base`
function T.unwrap(t, base, wrapper)
  return T.kids(t, base, wrapper) or base
end

-- `base.name` when it is an array: its path and element count; else nil
function T.arr(t, base, name)
  if not base then return nil end
  local p = base .. "." .. name
  local g = t:get(p)
  if g and g.kind == "array" then return p, g.len end
  return nil
end

-- the bytes of leaf `base.name`, nil when it is no leaf
function T.leaf(t, base, name)
  if not base then return nil end
  local p = base .. "." .. name
  local g = t:get(p)
  if g and g.kind == "leaf" then return t:bytes(p), p end
  return nil
end

-- leaf `base.name` of 1 / 2 / 4 bytes as an unsigned number (nil otherwise). The rules keep numbers, not paths: a
-- save has thousands of players, and a path string per value would not fit the script's memory.
function T.num(t, base, name)
  if not base then return nil end
  local p = base .. "." .. name
  local g = t:get(p)
  if not g or g.kind ~= "leaf" then return nil end
  local w = g.len
  if w ~= 1 and w ~= 2 and w ~= 4 then return nil end
  return t:int(p)
end

-- leaf `base.name` as a value { path, v, w } (for the few values a pass keeps by path)
function T.val(t, base, name)
  local v = T.num(t, base, name)
  if v == nil then return nil end
  local p = base .. "." .. name
  return { path = p, v = v, w = t:get(p).len }
end

-- every leaf under `path` (a struct or an array element), in record order: { path, ... }
function T.leaves(t, path, out)
  out = out or {}
  for _, name in ipairs(t:children(path)) do
    local p = path .. "." .. name
    local g = t:get(p)
    if g then
      if g.kind == "leaf" then
        out[#out + 1] = p
      elseif g.kind == "struct" then
        T.leaves(t, p, out)
      elseif g.kind == "array" then
        for i = 0, g.len - 1 do T.leaves(t, T.at(p, i), out) end
      end
    end
  end
  return out
end

-- the first record named `name` under `path` in depth-first order (the record itself before its children), as the
-- Rust find_deep: its path and node, nil when none
function T.find_deep(t, path, name)
  t:get(path .. "." .. name) -- the tree learns the name (children() lists it by name, not as 0x…)
  local hex = string.format("0x%08X", VRFW.savetree.hash(name))
  local kids = t:children(path)
  if not kids then
    -- a block itself ("block4"): the tree lists no top records, only the direct one is looked up
    local p = path .. "." .. name
    local g = t:get(p)
    if g then return p, g end
    return nil
  end
  for _, n in ipairs(kids) do
    local p = path .. "." .. n
    local g = t:get(p)
    if g then
      if n == name or n == hex then return p, g end
      if g.kind == "struct" then
        local q, h = T.find_deep(t, p, name)
        if q then return q, h end
      elseif g.kind == "array" then
        for i = 0, g.len - 1 do
          local q, h = T.find_deep(t, T.at(p, i), name)
          if q then return q, h end
        end
      end
    end
  end
  return nil
end

-- ------------------------------------------------------------------------------------------------ patch list

local P = {}
P.__index = P

function T.patches(t)
  return setmetatable({ t = t, list = {}, orig = {} }, P)
end

-- queued writes so far
function P:count()
  return #self.list
end

-- write `s` at byte `off` of leaf `path`; `w` = the width of the part of the leaf the write lies in (an element of an
-- SoA column, or the whole leaf); `orig` = the leaf's bytes when the caller already read them
function P:put(path, off, s, w, orig)
  if orig and not self.orig[path] then self.orig[path] = orig end
  self.list[#self.list + 1] = { path, off, s, w }
end

-- a value `{ path, v, w }` to `new` (only when it differs), at its own width
function P:val(v, new)
  if v and v.v ~= new then self:put(v.path, 0, T.le(new, v.w), v.w) end
end

-- a value to 0 (only when it is not 0)
function P:zero_val(v)
  if v and v.v ~= 0 then self:put(v.path, 0, string.rep("\0", v.w), v.w) end
end

-- leaf `path` (a number leaf whose value is `cur`) to `new` (only when it differs), at its own width
function P:set(path, cur, new)
  if cur ~= new then
    local w = self.t:get(path).len
    self:put(path, 0, T.le(new, w), w)
  end
end

-- a whole leaf to `s` (only when it differs from `cur`)
function P:leaf(path, cur, s)
  if cur ~= s then self:put(path, 0, s, #cur, cur) end
end

-- every leaf of a subtree to zeros (only the leaves that are not zero)
function P:zero(path)
  for _, p in ipairs(T.leaves(self.t, path)) do
    local b = self.t:bytes(p)
    if b:find("[^\0]") then self:put(p, 0, string.rep("\0", #b), #b, b) end
  end
end

-- apply the queued writes in order; returns the bytes that changed (counted at each write, as the Rust passes did)
function P:apply()
  local n, st, order = 0, {}, {}
  for _, e in ipairs(self.list) do
    local path, off, s, w = e[1], e[2], e[3], e[4]
    local L = st[path]
    if not L then
      local o = self.orig[path] or self.t:bytes(path)
      L = { orig = o, w = w, chunks = {} }
      st[path] = L
      order[#order + 1] = path
    end
    local cw = L.w
    local ci = floor(off / cw)
    local co = off - ci * cw
    local c = L.chunks[ci] or sub(L.orig, ci * cw + 1, (ci + 1) * cw)
    for k = 1, #s do
      if byte(c, co + k) ~= byte(s, k) then n = n + 1 end
    end
    L.chunks[ci] = sub(c, 1, co) .. s .. sub(c, co + #s + 1)
  end
  for _, path in ipairs(order) do
    local L = st[path]
    local idx = {}
    for ci in pairs(L.chunks) do idx[#idx + 1] = ci end
    table.sort(idx)
    local parts, pos = {}, 0
    for _, ci in ipairs(idx) do
      parts[#parts + 1] = sub(L.orig, pos + 1, ci * L.w)
      parts[#parts + 1] = L.chunks[ci]
      pos = (ci + 1) * L.w
    end
    parts[#parts + 1] = sub(L.orig, pos + 1)
    local new = concat(parts)
    if new ~= L.orig then self.t:set_bytes(path, new) end
  end
  self.list, self.orig = {}, {}
  return n
end

return T
