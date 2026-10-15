-- Helpers for the team build script (scripts/build/team.lua): number formats, stable sorting, sets, text forms of values. Pure Lua.
local T = {}

local TWO32 = 4294967296
T.TWO32 = TWO32

-- ------------------------------------------------------------------------------------------------- numbers

-- A number as an unsigned 32-bit id (the low 32 bits of any spelling).
function T.u32(x)
  return x % TWO32
end

-- A number as the signed 32-bit value a table cell stores (Rust `as i32`).
function T.i32(x)
  x = x % TWO32
  if x >= 2147483648 then return x - TWO32 end
  return x
end

-- Rust `as u16` / `as i16` of an integer.
function T.i16(x)
  x = x % 65536
  if x >= 32768 then return x - 65536 end
  return x
end

-- An id of a declaration: a number (low 32 bits) or a string (`0x...`, decimal, else crc32 of the name).
function T.id(x)
  if type(x) == "number" then return x % TWO32 end
  if type(x) == "string" then return VRFW.ids.parse(x) end
  return 0
end

-- `{IdRef}` (Display): a number in decimal, a string as written.
function T.idref_text(x)
  if type(x) == "number" then return string.format("%.0f", x) end
  return tostring(x)
end

-- Rust `f64::round` (half away from zero).
function T.round(x)
  if x >= 0 then return math.floor(x + 0.5) end
  return -math.floor(-x + 0.5)
end

function T.trunc(x)
  if x >= 0 then return math.floor(x) end
  return -math.floor(-x)
end

function T.clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

function T.min(a, b) if a < b then return a end return b end
function T.max(a, b) if a > b then return a end return b end

-- "0x%08X" (Rust `{:#010X}`), "%08x" (`{:08x}`), "0x%X" (`{:#X}`)
function T.hex(n) return string.format("0x%08X", n % TWO32) end
function T.hex8(n) return string.format("%08x", n % TWO32) end
function T.hexu(n) return string.format("0x%X", n % TWO32) end

-- `{:06}` of `n % 1_000_000`, `{:04}` of `n % 10000`, `{:02}`
function T.pad(n, w) return string.format("%0" .. w .. "d", n) end

-- `{}` of an integer.
function T.d(n) return string.format("%.0f", n) end

-- ------------------------------------------------------------------------------------------------- strings

function T.trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function T.starts(s, p) return s:sub(1, #p) == p end
function T.ends(s, p) return p == "" or s:sub(-#p) == p end
function T.has(s, p) return s:find(p, 1, true) ~= nil end

-- Every occurrence of `a` in `s` replaced by `b` (plain text, Rust `str::replace`).
function T.replace(s, a, b)
  if a == "" then return s end
  local out, i = {}, 1
  while true do
    local j = s:find(a, i, true)
    if not j then out[#out + 1] = s:sub(i) break end
    out[#out + 1] = s:sub(i, j - 1)
    out[#out + 1] = b
    i = j + #a
  end
  return table.concat(out)
end

-- The UTF-8 characters of `s`.
function T.chars(s)
  local out = {}
  for c in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = c end
  return out
end

-- A name of `a-z 0-9 _` (non-empty).
function T.is_word(s)
  return s ~= "" and s:find("^[a-z0-9_]+$") ~= nil
end

-- `s` split at the last `sep` (Rust `rsplit_once`): before, after; nil when absent.
function T.rsplit_once(s, sep)
  local last
  local i = 1
  while true do
    local j = s:find(sep, i, true)
    if not j then break end
    last = j
    i = j + 1
  end
  if not last then return nil end
  return s:sub(1, last - 1), s:sub(last + #sep)
end

-- The part after the last `.` (Rust `rsplit('.').next()`).
function T.last_part(s, sep)
  local a, b = T.rsplit_once(s, sep or ".")
  if a == nil then return s end
  return b
end

-- ------------------------------------------------------------------------------------------------- tables

function T.keys(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  return VRFW.sort(k)
end

function T.spairs(t)
  local k = T.keys(t)
  local i = 0
  return function()
    i = i + 1
    if k[i] ~= nil then return k[i], t[k[i]] end
  end
end

function T.copy(t)
  local o = {}
  for k, v in pairs(t) do o[k] = v end
  return o
end

-- A copy of an array.
function T.acopy(a)
  local o = {}
  for i = 1, #a do o[i] = a[i] end
  return o
end

function T.contains(list, v)
  for _, x in ipairs(list) do
    if x == v then return true end
  end
  return false
end

function T.index_of(list, v)
  for i, x in ipairs(list) do
    if x == v then return i end
  end
  return nil
end

function T.is_empty(t)
  return t == nil or next(t) == nil
end

function T.count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

-- Stable sort of array `a` by `less(x, y)` (Lua's table.sort is not stable).
function T.sort(a, less)
  local n = #a
  if n < 2 then return a end
  local src, dst = a, {}
  local width = 1
  while width < n do
    local i = 1
    while i <= n do
      local mid = math.min(i + width, n + 1)
      local hi = math.min(i + 2 * width, n + 1)
      local l, r, k = i, mid, i
      while l < mid and r < hi do
        if less(src[r], src[l]) then
          dst[k] = src[r]; r = r + 1
        else
          dst[k] = src[l]; l = l + 1
        end
        k = k + 1
      end
      while l < mid do dst[k] = src[l]; l = l + 1; k = k + 1 end
      while r < hi do dst[k] = src[r]; r = r + 1; k = k + 1 end
      i = hi
    end
    src, dst = dst, src
    width = width * 2
  end
  if src ~= a then
    for i = 1, n do a[i] = src[i] end
  end
  return a
end

-- Byte-order comparison of strings / numbers (Rust `Ord` of `String` / integers): -1, 0, 1.
function T.cmp(a, b)
  if a == b then return 0 end
  if VRFW.less(a, b) then return -1 end
  return 1
end

-- A sorted set of numbers / strings as an array (Rust BTreeSet iteration).
function T.sorted_set(set)
  return T.keys(set)
end

-- ------------------------------------------------------------------------------------------------- text forms (notes)

-- Rust `{:?}` of a string.
local DBG_ESC = { ["\\"] = "\\\\", ['"'] = '\\"', ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r", ["\0"] = "\\0" }
function T.dbg_str(s)
  -- ASCII control characters only (non-printable Unicode is not escaped)
  local o = s:gsub("[%c\\\"]", function(c)
    return DBG_ESC[c] or string.format("\\u{%x}", c:byte())
  end)
  return '"' .. o .. '"'
end

-- Rust `{:?}` of an f32 (shortest round-trip digits; `1.0`, `0.1`, `1e-5`, `1.5e16`)
function T.f32_dbg(x)
  if x ~= x then return "NaN" end
  if x == math.huge then return "inf" end
  if x == -math.huge then return "-inf" end
  if x == 0 then return (1 / x < 0) and "-0.0" or "0.0" end
  local ax = math.abs(x)
  local _, ex = math.frexp(ax)
  local half = 2 ^ (math.max(ex, -125) - 25)
  local s
  for p = 1, 9 do
    s = string.format("%." .. (p - 1) .. "e", ax)
    if math.abs(tonumber(s) - ax) < half then break end
  end
  local m, e = s:match("^([%d%.]+)e([-+]%d+)$")
  local digits = m:gsub("%.", ""):gsub("0+$", "")
  if digits == "" then digits = "0" end
  e = tonumber(e)
  local out
  if ax >= 1e-4 and ax < 1e16 then
    if e >= 0 then
      local ip = digits:sub(1, e + 1)
      ip = ip .. string.rep("0", e + 1 - #ip)
      local fp = digits:sub(e + 2)
      out = ip .. "." .. (fp == "" and "0" or fp)
    else
      out = "0." .. string.rep("0", -e - 1) .. digits
    end
  else
    out = digits:sub(1, 1) .. (#digits > 1 and ("." .. digits:sub(2)) or "") .. "e" .. e
  end
  return (x < 0 and "-" or "") .. out
end

-- Rust `{:?}` of a `BTreeMap<String, String>`.
function T.dbg_map(m)
  local p = {}
  for _, k in ipairs(T.keys(m)) do p[#p + 1] = T.dbg_str(k) .. ": " .. T.dbg_str(m[k]) end
  return "{" .. table.concat(p, ", ") .. "}"
end

-- Rust `{:?}` of a list of numbers.
function T.dbg_list(a)
  local p = {}
  for i, x in ipairs(a) do p[i] = string.format("%.0f", x) end
  return "[" .. table.concat(p, ", ") .. "]"
end

-- Rust `{:?}` of a list of `(u32, u32)` pairs.
function T.dbg_pairs(a)
  local p = {}
  for i, x in ipairs(a) do p[i] = string.format("(%.0f, %.0f)", x[1], x[2]) end
  return "[" .. table.concat(p, ", ") .. "]"
end

-- Rust `{:?}` of a row's values (`Int(…)`, `Float(…)`, `String(…)`).
function T.dbg_cells(v, n)
  local p = {}
  for i = 1, n or #v do
    local x = v[i]
    if type(x) == "number" then
      p[i] = string.format("Int(%.0f)", x)
    elseif type(x) == "string" then
      p[i] = "String(Some(" .. T.dbg_str(x) .. "))"
    elseif type(x) == "table" then
      p[i] = "Float(" .. T.f32_dbg(x.float) .. ")"
    else
      p[i] = "String(None)"
    end
  end
  return "[" .. table.concat(p, ", ") .. "]"
end

-- Rust `{}` of an f32 / f64 for notes (shortest form).
function T.num_text(x)
  if x == math.floor(x) and math.abs(x) < 1e15 then return string.format("%.0f", x) end
  local s = string.format("%.7g", x)
  return s
end

return T
