-- Sprite redirect. Declarations: every active mod's content\sprite_redirects\*.toml (`VRFW.sprite_redirect/1`). The
-- game's sprite setter (hook SpriteRedirects.SetLayerSprite, content\game\sprite_redirects.toml) is answered natively:
-- a declared (game atlas, sprite) pair is taken from the mod's own atlas. A menu script loads an own atlas only while
-- one of the game atlases it serves is loaded, or when the script loads one of them
-- (assets\lua\menu\_all\09_image_spill.lua).
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_SPRITE_REDIRECT_ATLASES | 0 / i / i, k | n / the i-th own atlas path (k = 0) or the number of game atlases it serves (k = -1) / the texture id of the k-th one |

SpriteRedirects = SpriteRedirects or {}

local D = require "lib/declarations"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("sprite_redirects")

local TABLE = "VRFW.SpriteRedirect"
local HOOK = "SpriteRedirects.SetLayerSprite"
local ATLASES = {}   -- own atlas paths, declaration order
local GAME_IDS = {}  -- own atlas path -> texture ids of the game atlases it serves (both spellings)
local handed_out = false   -- the list was logged at the first menu script that asked for it

local crc = VRFW.crc32

local function atlas_path(s)
  if type(s) ~= "string" then return nil end
  local p = s:match("^%s*(.-)%s*$")
  if not p:match("^#/.+%.g4tx$") then return nil end
  return p
end

-- The other spelling of a game atlas: the language folder `<LG>/` before the file name added or removed. Game code names
-- an atlas either way (icon_common is asked as `15_icon_common/icon_common.g4tx` and `15_icon_common/<LG>/icon_common.g4tx`),
-- and the two spellings have different ids.
local function other_spelling(p)
  local without = p:gsub("/<LG>/", "/", 1)
  if without ~= p then return without end
  local dir, file = p:match("^(.*)/([^/]+)$")
  if not dir then return nil end
  return dir .. "/<LG>/" .. file
end

local function start()
  local schema, why = D.schema("sprite_redirect")
  if not schema then
    warn(why .. ": no sprite is redirected")
    return
  end
  local pairs_out, seen_atlas, parts, also = {}, {}, {}, {}
  for _, d in ipairs(D.load(schema, warn)) do
    local game, own = atlas_path(d.v.atlas), atlas_path(d.v.own_atlas)
    if not game or not own then
      warn(string.format("%s: atlas / own_atlas must be #/…/<name>.g4tx: left out", d.key))
    elseif game == own then
      warn(string.format("%s: own_atlas is the game atlas: left out", d.key))
    else
      local g, o = crc(game), crc(own)
      local ids = GAME_IDS[own]
      if ids == nil then
        ids = {}
        GAME_IDS[own] = ids
      end
      local alt_game = other_spelling(game)
      for _, id in ipairs({ g, alt_game and crc(alt_game) or nil }) do
        local known = false
        for _, v in ipairs(ids) do
          if v == id then known = true end
        end
        if not known then ids[#ids + 1] = id end
      end
      for _, s in ipairs(d.v.sprites) do
        local key = g .. " " .. crc(s)
        local cur = pairs_out[key]
        if cur and cur.own ~= o then
          warn(string.format("%s: sprite %s of %s was redirected by %s: the later declaration wins", d.key, s, game, cur.by))
        end
        pairs_out[key] = { atlas = g, sprite = crc(s), own = o, by = d.key }
        local alt = other_spelling(game)
        if alt then
          also[#also + 1] = { atlas = crc(alt), sprite = crc(s), own = o, by = d.key }
        end
      end
      if not seen_atlas[own] then
        seen_atlas[own] = true
        ATLASES[#ATLASES + 1] = own
      end
      parts[#parts + 1] = string.format("%s (%d sprite(s) of %s -> %s)", d.key, #d.v.sprites, game, own)
    end
  end
  -- the same sprites asked under the atlas's other spelling; a declaration naming that spelling itself wins
  for _, p in ipairs(also) do
    local key = p.atlas .. " " .. p.sprite
    if pairs_out[key] == nil then pairs_out[key] = p end
  end
  if next(pairs_out) == nil then
    info("off: no mod redirects a sprite")
    return
  end
  local ok, done, e = pcall(VRFW.hook.apply, HOOK)
  if not (ok and done == true) then
    ATLASES = {}
    GAME_IDS = {}
    warn(string.format("detour %s not installed (%s): no sprite is redirected", HOOK, tostring(ok and e or done)))
    return
  end
  pcall(VRFW.native.table_clear, TABLE)
  for _, p in pairs(pairs_out) do VRFW.native.table_set(TABLE, { p.atlas, p.sprite }, p.own) end
  info("on: " .. table.concat(parts, ", "))
end

-- CMND_VRFW_SPRITE_REDIRECT_ATLASES(0) -> n; (i) -> the i-th own atlas path; (i, -1) -> the number of game atlases it
-- serves; (i, k) -> the texture id of the k-th one
function SpriteRedirects.Atlases(i, k)
  i = math.floor(tonumber(i) or 0)
  if i <= 0 then
    if not handed_out and #ATLASES > 0 then
      handed_out = true
      info(string.format("%d own atlas(es), each loaded by a menu script while a game atlas it serves is loaded: %s",
        #ATLASES, table.concat(ATLASES, ", ")))
    end
    return #ATLASES
  end
  k = math.floor(tonumber(k) or 0)
  local ids = ATLASES[i] and GAME_IDS[ATLASES[i]] or {}
  if k < 0 then
    return #ids
  elseif k == 0 then
    return ATLASES[i]
  end
  return ids[k]
end

start()
