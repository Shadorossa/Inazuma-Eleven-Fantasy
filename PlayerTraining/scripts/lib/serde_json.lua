-- Player Training › JSON text (copy of Inazuma Fantasy's lib\serde_json.lua) in serde_json's pretty layout (2-space indent, `"key": value`, `[]` / `{}` when empty,
-- no final newline), for the blobs the plugin wrote with serde_json::to_string_pretty and still reads in Rust
-- (player sets, training): the same bytes as before, field order included, arrays with null holes kept.
-- VRFW.json.encode cannot keep a key order or an array with nil entries, so the layout is described here:
--
--   J.obj{ { "version", 3 }, { "players", J.obj(list) } }   -- an object, fields in this order
--   J.arr(list, n)                                           -- an array of n entries (nil entries = null)
--   J.NULL                                                   -- null
--   J.raw(text)                                              -- text already encoded (written as it is)
--
-- Numbers with no fraction are written as integers (%.0f: Lua 5.2's %d stops at 2^31).

local J = {}

J.NULL = setmetatable({}, { __tostring = function() return "null" end })

function J.obj(fields) return { __obj = fields } end
function J.arr(list, n) return { __arr = list, n = n or #list } end
function J.raw(text) return { __raw = text } end

local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function str(s)
  return '"' .. s:gsub('[\0-\031"\\]', function(c)
    return ESC[c] or string.format("\\u%04x", c:byte())
  end) .. '"'
end

local function num(v)
  if v ~= v or v == math.huge or v == -math.huge then return "null" end
  if v == math.floor(v) and math.abs(v) < 9.0e15 then return string.format("%.0f", v) end
  return string.format("%.17g", v)
end

local function enc(v, ind, out)
  local t = type(v)
  if v == nil or v == J.NULL then
    out[#out + 1] = "null"
  elseif t == "boolean" then
    out[#out + 1] = v and "true" or "false"
  elseif t == "number" then
    out[#out + 1] = num(v)
  elseif t == "string" then
    out[#out + 1] = str(v)
  elseif t == "table" and v.__raw then
    out[#out + 1] = v.__raw
  elseif t == "table" and v.__obj then
    local f = v.__obj
    if #f == 0 then
      out[#out + 1] = "{}"
      return
    end
    local pad = ind .. "  "
    out[#out + 1] = "{\n"
    for i, kv in ipairs(f) do
      out[#out + 1] = pad .. str(kv[1]) .. ": "
      enc(kv[2], pad, out)
      out[#out + 1] = (i < #f) and ",\n" or "\n"
    end
    out[#out + 1] = ind .. "}"
  elseif t == "table" and v.__arr then
    local n = v.n
    if n == 0 then
      out[#out + 1] = "[]"
      return
    end
    local pad = ind .. "  "
    out[#out + 1] = "[\n"
    for i = 1, n do
      out[#out + 1] = pad
      enc(v.__arr[i], pad, out)
      out[#out + 1] = (i < n) and ",\n" or "\n"
    end
    out[#out + 1] = ind .. "]"
  else
    error("serde_json: cannot encode a " .. t)
  end
end

-- the JSON text of a described value
function J.encode(v)
  local out = {}
  enc(v, "", out)
  return table.concat(out)
end

return J
