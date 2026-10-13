-- Utilities › Unlocked formations (feature formations; docs/game/characters/uvr-removal.md §7-§8b).
--
-- Which formations (derived from the tables the game loads, mods' formations included; no id list): a row of
-- formation_config m_SoccerFormationInfoList is unlocked when
--   1. it has 11 placements (an 11-a-side formation);
--   2. its noun_id has a name in item_text (NOUN_INFO);
--   3. no formation item of item_config (ITEM_FORMATION_INFO) points at it (those the game already offers);
--   4. its name is not the name of an offered formation or of an earlier unlocked row;
--   5. its placements are not identical to another candidate's (v7.1.2: 15 rows share one placeholder layout).
-- On v7.1.2 the rule gives exactly UVR's 54 (rows 0-53, «F-Raimon» .. «F-Galaxia», row order).
-- The picker's row count getter is patched to the game's count + N (content\game\formations.toml FormationCount).

local PLACES_11 = 11
local MAX_EXTRA = 248 -- the menu's own row array holds 256 rows; the game's lists have 8 (11v11) and 5 (5v5)
local SEP = "\1"
local TEXT_LANGS = { "ja", "en", "es", "fr", "de", "it", "pt", "zh_hans", "zh_hant" } -- fallback only

local function u32(v)
  return bit32.band(v or 0, 0xFFFFFFFF)
end

local function cell_text(v)
  if type(v) == "table" then
    local parts = {}
    for i = 1, #v do
      parts[i] = cell_text(v[i])
    end
    for k, x in pairs(v) do
      if type(k) == "string" then
        parts[#parts + 1] = k .. "=" .. cell_text(x)
      end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return tostring(v)
end

local function row_text(r)
  local parts = {}
  for i = 1, #r do
    parts[i] = cell_text(r[i])
  end
  return table.concat(parts, SEP)
end

-- the formations in row order: { id, noun, layout = the placement rows as text, n = placement count }
local function formations()
  local rows = VRFW.table.rows("formation/formation")
  local places = VRFW.table.rows("formation/formation_soccer_form_placement_info")
  local out = {}
  for _, r in ipairs(rows) do
    local f = { id = u32(r.form_id), noun = u32(r.noun_id), n = 0, layout = "" }
    local s = r.placement_info
    if type(s) == "table" and s.start and s.count then
      local start, count = s.start % 65536, s.count % 65536
      if start + count <= #places then
        local parts = {}
        for k = start + 1, start + count do
          parts[#parts + 1] = row_text(places[k])
        end
        f.n, f.layout = count, table.concat(parts, SEP .. SEP)
      end
    end
    out[#out + 1] = f
  end
  return out
end

-- item_text NOUN_INFO: noun id -> name, from the first text language that reads (a name's presence is the same in
-- every language)
local function noun_names()
  local keys = VRFW.table.keys("data/common/text/*/item_text.cfg.bin")
  if #keys == 0 then
    for _, l in ipairs(TEXT_LANGS) do
      keys[#keys + 1] = "data/common/text/" .. l .. "/item_text.cfg.bin"
    end
  end
  local last = "no text language"
  for _, k in ipairs(keys) do
    local ok, rows = pcall(VRFW.table.raw, k, "NOUN_INFO")
    if ok then
      local names = {}
      for _, r in ipairs(rows) do
        if type(r[1]) == "number" and type(r[6]) == "string" then
          names[u32(r[1])] = r[6]
        end
      end
      return names
    end
    last = tostring(rows)
  end
  error(last)
end

-- formIds a formation item points at (any int value of ITEM_FORMATION_INFO that is a formId)
local function offered_ids(forms)
  local ids = {}
  for _, f in ipairs(forms) do
    if f.id ~= 0 then
      ids[f.id] = true
    end
  end
  local out = {}
  for _, r in ipairs(VRFW.table.rows("item/item_formation")) do
    for i = 1, #r do
      if type(r[i]) == "number" then
        local h = u32(r[i])
        if ids[h] then
          out[h] = true
        end
      end
    end
  end
  return out
end

local function trim(s)
  return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

local function unlockable(forms, offered, names)
  local function name(f)
    local n = names[f.noun]
    n = n and trim(n) or ""
    return n ~= "" and n or nil
  end
  local seen = {}
  for _, f in ipairs(forms) do
    if offered[f.id] then
      local n = name(f)
      if n then
        seen[n] = true
      end
    end
  end
  local cands, layouts = {}, {}
  for _, f in ipairs(forms) do
    if f.id ~= 0 and f.n == PLACES_11 and not offered[f.id] then
      local n = name(f)
      if n and not seen[n] then
        seen[n] = true
        cands[#cands + 1] = f
        layouts[f.layout] = (layouts[f.layout] or 0) + 1
      end
    end
  end
  local out = {}
  for _, f in ipairs(cands) do
    if layouts[f.layout] == 1 and #out < MAX_EXTRA then
      out[#out + 1] = f.id
    end
  end
  return out
end

-- `mov eax, [rcx+9E0h]; add eax, extra; ret` + int3 padding (the getter and its padding, 16 bytes)
local function getter_bytes(extra)
  local b = { 0x8B, 0x81, 0xE0, 0x09, 0x00, 0x00, 0x05 }
  for k = 0, 3 do
    b[#b + 1] = bit32.band(bit32.rshift(extra, 8 * k), 0xFF)
  end
  b[#b + 1] = 0xC3
  for _ = 1, 4 do
    b[#b + 1] = 0xCC
  end
  return b
end

local unlocked, game = {}, {}

local function build()
  local forms = formations()
  local offered = offered_ids(forms)
  unlocked = unlockable(forms, offered, noun_names())
  game = {}
  for _, f in ipairs(forms) do
    if offered[f.id] then
      game[#game + 1] = f.id
    end
  end
  VRFW.log(string.format("%d formation(s) unlocked, %d offered by the game", #unlocked, #game))
  if #unlocked > 0 then
    local ok, done = pcall(VRFW.patch.apply, "FormationCount", getter_bytes(#unlocked))
    if ok and done then
      VRFW.log("count getter -> game count + " .. #unlocked)
    else
      VRFW.warn("count getter not patched (" .. tostring(done) .. "): the picker shows the game's rows only (the Lua list is longer, harmless)")
    end
  end
end

local ok, err = pcall(build)
if not ok then
  unlocked, game = {}, {}
  VRFW.warn("tables not read (" .. tostring(err) .. "): the formation picker lists the game's own formations")
end

function Utilities.Formation(which, i)
  local l = (which == 1) and game or unlocked
  i = type(i) == "number" and math.floor(i) or 0
  if i <= 0 then
    return #l
  end
  return l[i] or 0
end
