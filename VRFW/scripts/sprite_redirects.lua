-- Sprite redirect. Declarations: every active mod's content\sprite_redirects\*.toml (`VRFW.sprite_redirect/1`). The
-- game's sprite setter (hook SpriteRedirects.SetLayerSprite, content\game\sprite_redirects.toml) is answered natively:
-- a declared (game atlas, sprite) pair is taken from the mod's own atlas. Menu scripts load the own atlases at their
-- first menu command (assets\lua\menu\_all\09_image_spill.lua).
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_SPRITE_REDIRECT_ATLASES | 0 / i | n / the i-th own atlas path |

SpriteRedirects = SpriteRedirects or {}

local D = require "lib/declarations"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("sprite_redirects")

local TABLE = "VRFW.SpriteRedirect"
local HOOK = "SpriteRedirects.SetLayerSprite"
local ATLASES = {}   -- own atlas paths, declaration order
local handed_out = false   -- the list was logged at the first menu script that asked for it

local crc = VRFW.crc32

local function atlas_path(s)
  if type(s) ~= "string" then return nil end
  local p = s:match("^%s*(.-)%s*$")
  if not p:match("^#/.+%.g4tx$") then return nil end
  return p
end

local function start()
  local schema, why = D.schema("sprite_redirect")
  if not schema then
    warn(why .. ": no sprite is redirected")
    return
  end
  local pairs_out, seen_atlas, parts = {}, {}, {}
  for _, d in ipairs(D.load(schema, warn)) do
    local game, own = atlas_path(d.v.atlas), atlas_path(d.v.own_atlas)
    if not game or not own then
      warn(string.format("%s: atlas / own_atlas must be #/…/<name>.g4tx: left out", d.key))
    elseif game == own then
      warn(string.format("%s: own_atlas is the game atlas: left out", d.key))
    else
      local g, o = crc(game), crc(own)
      for _, s in ipairs(d.v.sprites) do
        local key = g .. " " .. crc(s)
        local cur = pairs_out[key]
        if cur and cur.own ~= o then
          warn(string.format("%s: sprite %s of %s was redirected by %s: the later declaration wins", d.key, s, game, cur.by))
        end
        pairs_out[key] = { atlas = g, sprite = crc(s), own = o, by = d.key }
      end
      if not seen_atlas[own] then
        seen_atlas[own] = true
        ATLASES[#ATLASES + 1] = own
      end
      parts[#parts + 1] = string.format("%s (%d sprite(s) of %s -> %s)", d.key, #d.v.sprites, game, own)
    end
  end
  if next(pairs_out) == nil then
    info("off: no mod redirects a sprite")
    return
  end
  local ok, done, e = pcall(VRFW.hook.apply, HOOK)
  if not (ok and done == true) then
    ATLASES = {}
    warn(string.format("detour %s not installed (%s): no sprite is redirected", HOOK, tostring(ok and e or done)))
    return
  end
  pcall(VRFW.native.table_clear, TABLE)
  for _, p in pairs(pairs_out) do VRFW.native.table_set(TABLE, { p.atlas, p.sprite }, p.own) end
  info("on: " .. table.concat(parts, ", "))
end

-- CMND_VRFW_SPRITE_REDIRECT_ATLASES(0) -> n; (i) -> the i-th own atlas path
function SpriteRedirects.Atlases(i)
  i = math.floor(tonumber(i) or 0)
  if i <= 0 then
    if not handed_out and #ATLASES > 0 then
      handed_out = true
      info(string.format("%d own atlas(es) loaded by every menu script at its first menu command: %s", #ATLASES,
        table.concat(ATLASES, ", ")))
    end
    return #ATLASES
  end
  return ATLASES[i]
end

start()
