-- Face icon rules: reads every mod's content/face_icons/*.toml (`VRFW.face_icon/1`) and feeds the native hook FaceIcons.Composite (content/game/face_icons.toml).
-- mode "face_only": a menu face icon drawn with the kit bust (type 9) is drawn face only (type 10) for a declared rarity, or a declared character key when asked without a card.
-- CMND_VRFW_FACE_ICON(hdl[, key]) -> mode (0 = the game's, 10 = face only), live

FaceIcons = FaceIcons or {}

local D = require "lib/declarations"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("face_icons")

local T_RARITY, T_KEY = "VRFW.FaceIcon.Rarity", "VRFW.FaceIcon.Key"
local FACE_ONLY = 10
local MODES = { face_only = FACE_ONLY }

local RARITY, KEY = {}, {}
local LIVE = false

local function start()
  local schema, why = D.schema("face_icon")
  if not schema then
    warn(why .. ": the face icons stay the game's")
    return
  end
  local decls, skipped = D.load(schema, warn)
  local n_r, n_k, keys = 0, 0, {}
  for _, d in ipairs(decls) do
    local m = MODES[d.v.mode]
    if not m then
      warn(string.format("%s: mode %q: \"face_only\": left out", d.where, tostring(d.v.mode)))
    elseif #(d.v.rarities or {}) == 0 and #(d.v.characters or {}) == 0 then
      warn(string.format("%s: neither rarities nor characters: left out", d.where))
    else
      for _, r in ipairs(d.v.rarities or {}) do
        if not RARITY[r] then n_r = n_r + 1 end
        RARITY[r] = m
      end
      for _, k in ipairs(d.v.characters or {}) do
        if not KEY[k] then n_k = n_k + 1 end
        KEY[k] = m
      end
      keys[#keys + 1] = d.key
    end
  end
  if n_r + n_k == 0 then
    if #decls > 0 or (skipped or 0) > 0 then
      info(string.format("off: %d declaration(s) (%d left out by `when`), no rule in force: the game's face icons", #decls, skipped or 0))
    else
      info("off: no mod declares a face icon rule: the game's face icons")
    end
    return
  end
  local ok, done, e = pcall(VRFW.hook.apply, "FaceIcons.Composite")
  LIVE = ok and done == true
  if not LIVE then
    warn(string.format("detour FaceIcons.Composite not installed (%s): the game's face icons", tostring(ok and e or done)))
    return
  end
  pcall(VRFW.native.table_clear, T_RARITY)
  pcall(VRFW.native.table_clear, T_KEY)
  local rs = {}
  for r, m in pairs(RARITY) do
    VRFW.native.table_set(T_RARITY, r, m)
    rs[#rs + 1] = r
  end
  table.sort(rs)
  for k, m in pairs(KEY) do VRFW.native.table_set(T_KEY, k, m) end
  info(string.format("on: face only for rarities %s and %d character key(s) (%s)", #rs > 0 and table.concat(rs, " ") or "none", n_k, table.concat(keys, ", ")))
end

function FaceIcons.Cmd(hdl, key)
  hdl = tonumber(hdl) or 0
  if hdl ~= 0 then
    local ok, r = pcall(VRFW.call, "FaceIcons.GetCharaRarity", hdl)
    if ok and type(r) == "number" and RARITY[r] then return RARITY[r], LIVE end
    return 0, LIVE
  end
  key = tonumber(key) or 0
  return KEY[key % 4294967296] or 0, LIVE
end

start()
