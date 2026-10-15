-- Computed values of the type `flag`. Each function gets the [[flag]] fields (`name`, `id`, `bank`, `bit`) plus `mod`, `key`, `file`.
-- `crc32(text)` is the game's name hash.

local M = {}

-- A written id: a number (its 32-bit pattern), "0x…" or a decimal, else a name (its crc32).
local function as_id(v)
  if type(v) == "number" then
    return v % 4294967296
  end
  local n = tonumber(v)
  if n then
    return n % 4294967296
  end
  return crc32(v)
end

-- The flag's id (the row key): crc32(name), or `id`; when both are written they must agree.
function M.id(f)
  local by_name = f.name and crc32(f.name)
  local by_id = f.id and as_id(f.id)
  if by_name and by_id and by_name ~= by_id then
    error(string.format("name %q is 0x%08X, id says 0x%08X", f.name, by_name, by_id), 0)
  end
  local id = by_name or by_id
  if not id then
    error("needs name = \"…\" (or id = 0x…)", 0)
  end
  return id
end

return M
