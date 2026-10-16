-- InaRogue › INAROGUE: a JSON writer with the key order and layout of the DLL's serde_json files (pretty = two
-- spaces, `"key": value`, one array element per line), so the blobs stay byte-compatible with what the DLL wrote.
-- Reading is VRFW.json.decode.
--
--   J.obj({ { "version", 1 }, { "slot", 4 } })   an object, keys in this order
--   J.arr({ 1, 2, 3 })                            an array (also for an empty list)
--   J.pretty(v) / J.compact(v)

local J = {}

local OBJ, ARR = {}, {}

function J.obj(pairs) return { [OBJ] = true, pairs = pairs } end
function J.arr(list) return { [ARR] = true, list = list or {} } end

local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\b"] = "\\b",
  ["\f"] = "\\f" }

local function str(s)
  return '"' .. s:gsub('[%c"\\]', function(c) return ESC[c] or string.format("\\u%04x", c:byte()) end) .. '"'
end

local function num(n)
  if n ~= n or n == math.huge or n == -math.huge then return "null" end
  if n == math.floor(n) and math.abs(n) < 2 ^ 63 then return string.format("%.0f", n) end
  return string.format("%.17g", n)
end

local function enc(v, out, pretty, ind)
  local t = type(v)
  if v == nil then
    out[#out + 1] = "null"
  elseif t == "boolean" then
    out[#out + 1] = v and "true" or "false"
  elseif t == "number" then
    out[#out + 1] = num(v)
  elseif t == "string" then
    out[#out + 1] = str(v)
  elseif t == "table" and v[OBJ] then
    if #v.pairs == 0 then
      out[#out + 1] = "{}"
      return
    end
    local inner = ind .. "  "
    out[#out + 1] = pretty and "{\n" or "{"
    for i, p in ipairs(v.pairs) do
      if pretty then out[#out + 1] = inner end
      out[#out + 1] = str(p[1])
      out[#out + 1] = pretty and ": " or ":"
      enc(p[2], out, pretty, inner)
      if i < #v.pairs then out[#out + 1] = pretty and ",\n" or "," elseif pretty then out[#out + 1] = "\n" end
    end
    if pretty then out[#out + 1] = ind end
    out[#out + 1] = "}"
  elseif t == "table" then
    local list = v[ARR] and v.list or v
    local n = #list
    if n == 0 then
      out[#out + 1] = "[]"
      return
    end
    local inner = ind .. "  "
    out[#out + 1] = pretty and "[\n" or "["
    for i = 1, n do
      if pretty then out[#out + 1] = inner end
      enc(list[i], out, pretty, inner)
      if i < n then out[#out + 1] = pretty and ",\n" or "," elseif pretty then out[#out + 1] = "\n" end
    end
    if pretty then out[#out + 1] = ind end
    out[#out + 1] = "]"
  else
    out[#out + 1] = "null"
  end
end

function J.pretty(v)
  local out = {}
  enc(v, out, true, "")
  return table.concat(out)
end

function J.compact(v)
  local out = {}
  enc(v, out, false, "")
  return table.concat(out)
end

-- the sorted keys of a set table ({ [k] = true }) as a list (BTreeSet order: byte order of strings)
function J.sorted_keys(set)
  local o = {}
  for k in pairs(set) do o[#o + 1] = k end
  table.sort(o)
  return o
end

return J
