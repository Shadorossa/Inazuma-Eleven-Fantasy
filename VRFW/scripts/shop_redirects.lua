-- Shop redirect. Declarations: every active mod's content\shop_redirects\*.toml (`VRFW.shop_redirect/1`); menu side:
-- assets\lua\menu\_all\70_shop_redirect.lua. A menu opens a shop by handing its id to shop_menu (the param store key
-- 0xCE4A397E); a redirected id is handed as the declared target instead, so every menu entry of the shop opens the target.
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_SHOP_REDIRECTS | | n, from 1, to 1, …: a shop id (number) or a mod's shop key (text) each |

ShopRedirects = ShopRedirects or {}

local D = require "lib/declarations"

local function info(...) VRFW.log("shop_redirects:", ...) end
local function warn(...) VRFW.warn("shop_redirects:", ...) end

local PAIRS = {}  -- { from, to }: a number (shop id) or a text (shop key)

-- "0x…" -> the id; any other text stays a key (a mod's shop, resolved by the menu)
local function ref(s)
  if type(s) ~= "string" then return nil end
  if s:match("^%s*0[xX]%x+%s*$") then return D.id_of(s) end
  local t = s:match("^%s*(.-)%s*$")
  if t == "" then return nil end
  return t
end

local function start()
  local schema, why = D.schema("shop_redirect")
  if not schema then
    warn(why .. ": every menu opens its own shop")
    return
  end
  local seen, parts = {}, {}
  for _, d in ipairs(D.load(schema, warn)) do
    local to = ref(d.v.to)
    if to == nil then
      warn(string.format("%s: `to` is empty: left out", d.key))
    else
      for _, f in ipairs(d.v.from) do
        local from = ref(f)
        if from ~= nil and from ~= to then
          if seen[from] ~= nil and seen[from] ~= to then
            warn(string.format("%s: shop %s is already redirected to %s: the later declaration wins", d.key, tostring(from), tostring(seen[from])))
          end
          seen[from] = to
        end
      end
      parts[#parts + 1] = string.format("%s (%d shop(s) -> %s)", d.key, #d.v.from, tostring(to))
    end
  end
  for from, to in pairs(seen) do PAIRS[#PAIRS + 1] = { from, to } end
  if #PAIRS == 0 then
    info("off: no mod redirects a shop")
  else
    info("on: " .. table.concat(parts, ", "))
  end
end

-- CMND_VRFW_SHOP_REDIRECTS() -> n, from 1, to 1, …
function ShopRedirects.List()
  local out = {}
  for _, p in ipairs(PAIRS) do
    out[#out + 1] = p[1]
    out[#out + 1] = p[2]
  end
  return #PAIRS, table.unpack(out)
end

start()
